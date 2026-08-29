import { parseProductPage, normalizeWhitespace } from './content.js';
import { requestTextWithRetry } from './http.js';

export class ProductDataError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ProductDataError';
  }
}

export function parseSearchJsonp(text, callbackName) {
  const marker = `${callbackName}(`;
  const start = text.indexOf(marker);
  const end = text.lastIndexOf(');');
  if (start < 0 || end <= start + marker.length) {
    throw new ProductDataError('The storefront search service returned unrecognised JSONP.');
  }
  try {
    return JSON.parse(text.slice(start + marker.length, end));
  } catch (error) {
    throw new ProductDataError(`The storefront search JSON could not be parsed: ${error.message}`);
  }
}

function candidateSkus(product) {
  return new Set(
    [
      ...(Array.isArray(product?.skus) ? product.skus : []),
      ...(Array.isArray(product?.variants)
        ? product.variants.map((variant) => variant?.sku)
        : []),
    ]
      .map((value) => String(value ?? '').trim().toUpperCase())
      .filter(Boolean),
  );
}

function searchUrlFor(productCode, siteConfig) {
  const url = new URL(siteConfig.searchEndpoint);
  const parameters = {
    shop: siteConfig.searchShop,
    q: productCode,
    page: '1',
    limit: '24',
    sort: 'relevance',
    collection_scope: '0',
    product_available: 'false',
    variant_available: 'false',
    build_filter_tree: 'true',
    check_cache: 'false',
    fuzzy: '1',
    locale: 'en',
    callback: siteConfig.searchCallback,
    event_type: 'init',
  };
  for (const [name, value] of Object.entries(parameters)) url.searchParams.set(name, value);
  return url.href;
}

export async function discoverExactCandidates({
  productCode,
  poDescription,
  siteConfig,
  config,
  logger,
  blockGuard,
}) {
  const searchUrl = searchUrlFor(productCode, siteConfig);
  await logger.log('SEARCH', `${productCode} discovery attempt`, {
    poDescription,
    searchUrl,
  });
  const response = await requestTextWithRetry({
    url: searchUrl,
    description: `${productCode} storefront search`,
    config,
    logger,
    blockGuard,
    accept: 'text/javascript,application/json;q=0.9,*/*;q=0.2',
    referer: `${siteConfig.storefrontBaseUrl}/search?q=${encodeURIComponent(productCode)}`,
  });
  const parsed = parseSearchJsonp(response.text, siteConfig.searchCallback);
  if (!Array.isArray(parsed.products)) {
    throw new ProductDataError('The storefront search response has no products array.');
  }
  const allCandidates = parsed.products.map((product) => ({
    id: product.id,
    handle: String(product.handle ?? '').trim(),
    title: normalizeWhitespace(product.title),
    skus: [...candidateSkus(product)],
  }));
  const exactByHandle = new Map();
  for (const product of parsed.products) {
    const handle = String(product.handle ?? '').trim();
    if (!handle || !candidateSkus(product).has(productCode.toUpperCase())) continue;
    if (!exactByHandle.has(handle)) exactByHandle.set(handle, product);
  }
  const exactCandidates = [...exactByHandle.values()];
  await logger.log('SEARCH', `${productCode} discovery result`, {
    reportedResults: Number(parsed.total_product ?? parsed.products.length),
    returnedCandidates: allCandidates.length,
    exactSkuCandidates: exactCandidates.length,
    candidates: allCandidates,
  });
  return {
    searchUrl,
    reportedResults: Number(parsed.total_product ?? parsed.products.length),
    allCandidates,
    exactCandidates,
  };
}

function normalizedCanonical(value) {
  const url = new URL(value);
  url.hash = '';
  url.search = '';
  url.hostname = url.hostname.toLowerCase();
  url.pathname = url.pathname.replace(/\/$/, '');
  return url.href.replace(/\/$/, '');
}

function variantOptions(productJson, variant) {
  const optionNames = Array.isArray(productJson.options) ? productJson.options : [];
  const values = Array.isArray(variant.options)
    ? variant.options
    : [variant.option1, variant.option2, variant.option3];
  return optionNames
    .map((option, index) => ({
      name: normalizeWhitespace(option?.name ?? `Option ${index + 1}`),
      value: normalizeWhitespace(values[index]),
    }))
    .filter((option) => option.value);
}

export async function verifyAndScrapeCandidate({
  productCode,
  candidate,
  siteConfig,
  config,
  logger,
  blockGuard,
}) {
  const canonicalCandidate = new URL(
    `/products/${encodeURIComponent(candidate.handle)}`,
    siteConfig.storefrontBaseUrl,
  ).href;
  const productJsonUrl = `${canonicalCandidate}.js`;
  const jsonResponse = await requestTextWithRetry({
    url: productJsonUrl,
    description: `${productCode} product JSON`,
    config,
    logger,
    blockGuard,
    accept: 'application/json,text/javascript;q=0.9,*/*;q=0.2',
    referer: canonicalCandidate,
  });
  let productJson;
  try {
    productJson = JSON.parse(jsonResponse.text);
  } catch (error) {
    throw new ProductDataError(`Product JSON could not be parsed: ${error.message}`);
  }
  const exactVariants = (productJson.variants ?? []).filter(
    (variant) => String(variant?.sku ?? '').trim().toUpperCase() === productCode.toUpperCase(),
  );
  if (exactVariants.length !== 1) {
    throw new ProductDataError(
      `Product JSON has ${exactVariants.length} variants with exact SKU ${productCode}; exactly one is required.`,
    );
  }

  const pageResponse = await requestTextWithRetry({
    url: canonicalCandidate,
    description: `${productCode} product page`,
    config,
    logger,
    blockGuard,
    accept: 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.2',
    referer: `${siteConfig.storefrontBaseUrl}/search?q=${encodeURIComponent(productCode)}`,
  });
  const page = parseProductPage({
    pageHtml: pageResponse.text,
    productDescriptionHtml: productJson.description,
    descriptionSelectors: siteConfig.descriptionSelectors,
    howItWorksSelectors: siteConfig.howItWorksSelectors,
  });
  if (!page.canonicalUrl) {
    throw new ProductDataError('Product page has no canonical URL.');
  }
  const canonicalUrl = normalizedCanonical(page.canonicalUrl);
  if (canonicalUrl !== normalizedCanonical(canonicalCandidate)) {
    throw new ProductDataError(
      `Product canonical URL differs from the discovered handle: ${page.canonicalUrl}`,
    );
  }
  if (page.jsonLdSkus.length > 0 && !page.jsonLdSkus.includes(productCode.toUpperCase())) {
    throw new ProductDataError(
      `Product page structured data does not contain confirmed SKU ${productCode}.`,
    );
  }

  const matchedVariant = exactVariants[0];
  const warnings = [];
  if (page.pageTitle && page.pageTitle !== normalizeWhitespace(productJson.title)) {
    warnings.push(`Page heading differs from product JSON title: ${page.pageTitle}`);
  }
  if (page.jsonLdSkus.length === 0) {
    warnings.push('Product page contains no readable JSON-LD SKU; product JSON verification succeeded.');
  }
  const searchImageAltByPath = new Map(
    (candidate.images_info ?? []).map((image) => {
      try {
        return [new URL(image.src).pathname, normalizeWhitespace(image.alt)];
      } catch {
        return ['', ''];
      }
    }),
  );
  const imageUrls = (productJson.images ?? []).map((value) =>
    new URL(String(value), siteConfig.storefrontBaseUrl).href,
  );

  await logger.log('MATCHED', `${productCode} product confirmed`, {
    matchedProduct: productJson.title,
    matchedUrl: canonicalUrl,
    confirmedSku: matchedVariant.sku,
    variantId: matchedVariant.id,
    skuSources: [
      'storefront-search-product-data',
      'canonical-product-json',
      ...(page.jsonLdSkus.includes(productCode.toUpperCase()) ? ['product-page-json-ld'] : []),
    ],
  });

  return {
    productCode,
    productName: normalizeWhitespace(productJson.title),
    canonicalUrl,
    productId: productJson.id,
    handle: productJson.handle,
    vendor: normalizeWhitespace(productJson.vendor),
    productType: normalizeWhitespace(productJson.type),
    tags: Array.isArray(productJson.tags) ? productJson.tags : [],
    matchedVariant: {
      id: matchedVariant.id,
      sku: matchedVariant.sku,
      title: normalizeWhitespace(matchedVariant.title),
      available: Boolean(matchedVariant.available),
      options: variantOptions(productJson, matchedVariant),
    },
    skuVerification: {
      requestedCode: productCode,
      searchEndpointConfirmed: true,
      productJsonConfirmed: true,
      productJsonUrl,
      productPageJsonLdConfirmed: page.jsonLdSkus.includes(productCode.toUpperCase()),
      productPageJsonLdSkus: page.jsonLdSkus,
    },
    description: page.description,
    specifications: page.specifications,
    whatsIncluded: page.whatsIncluded,
    additionalInformation: page.additionalInformation,
    howItWorks: page.howItWorks,
    descriptionSource: page.descriptionSource,
    rawDescriptionHtml: page.rawDescriptionHtml,
    rawHowItWorksHtml: page.rawHowItWorksHtml,
    imageUrls,
    imageMetadata: imageUrls.map((url) => {
      const pathname = new URL(url).pathname;
      return { sourceUrl: url, alt: searchImageAltByPath.get(pathname) || '' };
    }),
    warnings,
  };
}
