export class SiteBlockedError extends Error {
  constructor(message) {
    super(message);
    this.name = 'SiteBlockedError';
  }
}

function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export async function fetchWithRetry(url, config, logger, purpose, fetchImpl = fetch) {
  let lastError;
  for (let attempt = 1; attempt <= config.maximumRetries; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.requestTimeoutMs);
    try {
      const response = await fetchImpl(url, {
        headers: {
          Accept: '*/*',
          'User-Agent': config.userAgent,
        },
        redirect: 'follow',
        signal: controller.signal,
      });
      if (response.status === 403 || response.status === 429) {
        throw new SiteBlockedError(`${purpose} returned HTTP ${response.status}.`);
      }
      if (!response.ok) throw new Error(`${purpose} returned HTTP ${response.status}.`);
      return response;
    } catch (error) {
      lastError = error;
      if (attempt < config.maximumRetries) {
        await logger.log(
          'WARNING',
          `${purpose} retry ${attempt}/${config.maximumRetries} | ${error.message}`,
        );
        await delay(config.retryBaseDelayMs * 2 ** (attempt - 1));
      }
    } finally {
      clearTimeout(timeout);
    }
  }
  if (lastError instanceof SiteBlockedError) {
    throw new SiteBlockedError(
      `${purpose} was blocked after ${config.maximumRetries} attempts; stopping without evasion.`,
    );
  }
  throw new Error(
    `${purpose} failed after ${config.maximumRetries} attempts | ${lastError?.message ?? 'Unknown error'}`,
  );
}

function productEndpoint(productUrl) {
  const url = new URL(productUrl);
  url.search = '';
  url.hash = '';
  url.pathname = `${url.pathname.replace(/\/$/, '')}.js`;
  return url.href;
}

export async function findProductByCode(productCode, config, logger, fetchImpl = fetch) {
  const search = new URL('/search/suggest.json', config.baseUrl);
  search.searchParams.set('q', productCode);
  search.searchParams.set('resources[type]', 'product');
  search.searchParams.set('resources[limit]', '10');
  search.searchParams.set('resources[options][unavailable_products]', 'show');

  const searchResponse = await fetchWithRetry(
    search,
    config,
    logger,
    `${productCode} search`,
    fetchImpl,
  );
  const searchData = await searchResponse.json();
  const results = searchData?.resources?.results?.products;
  if (!Array.isArray(results) || results.length === 0) {
    throw new Error(`Search returned no products for ${productCode}.`);
  }

  const first = results[0];
  const sourceUrl = new URL(first.url, config.baseUrl);
  sourceUrl.search = '';
  sourceUrl.hash = '';
  const productResponse = await fetchWithRetry(
    productEndpoint(sourceUrl),
    config,
    logger,
    `${productCode} product data`,
    fetchImpl,
  );
  const product = await productResponse.json();
  const skus = (product.variants ?? []).map((variant) => String(variant.sku ?? '').trim());
  if (!skus.some((sku) => sku.toUpperCase() === productCode.toUpperCase())) {
    throw new Error(
      `First search result did not contain exact SKU ${productCode}; found ${skus.filter(Boolean).join(', ') || 'no SKU'}.`,
    );
  }
  if (!String(product.description ?? '').trim()) {
    throw new Error(`Product ${productCode} has no description.`);
  }
  if (!Array.isArray(product.images) || product.images.length === 0) {
    throw new Error(`Product ${productCode} has no images.`);
  }

  const imageUrls = [...new Set(product.images.map((value) => new URL(value, config.baseUrl).href))];
  return {
    productCode,
    productName: String(product.title ?? first.title ?? '').trim(),
    sourceUrl: sourceUrl.href,
    searchUrl: new URL(`/pages/search-results-page?q=${encodeURIComponent(productCode)}`, config.baseUrl).href,
    descriptionHtml: String(product.description),
    imageUrls,
    matchedVariantSkus: skus,
  };
}
