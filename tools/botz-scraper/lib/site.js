import {
  extractCodeFromProductUrl,
  normalizeUrl,
  normalizeWhitespace,
  parseProductHeading,
} from './content.js';
import { extractProductImageUrls, SiteBlockedError } from './images.js';

export class DiscoveryError extends Error {
  constructor(message) {
    super(message);
    this.name = 'DiscoveryError';
  }
}

function parseDisplayedCount(value) {
  const match = /\d+/.exec(String(value ?? '').replaceAll(',', ''));
  return match ? Number(match[0]) : Number.NaN;
}

async function delay(milliseconds) {
  await new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export async function navigateWithRetry({
  page,
  url,
  requiredSelector,
  description,
  config,
  logger,
  blockGuard,
}) {
  let lastError;
  for (let attempt = 1; attempt <= config.maximumRetries; attempt += 1) {
    try {
      const response = await page.goto(url, {
        waitUntil: 'domcontentloaded',
        timeout: config.navigationTimeoutMs,
      });
      if (response) {
        const status = response.status();
        blockGuard.observe(status, url);
        if (status >= 400) {
          throw new Error(`Navigation returned HTTP ${status}.`);
        }
      }
      if (requiredSelector) {
        await page.locator(requiredSelector).first().waitFor({
          state: 'attached',
          timeout: config.selectorTimeoutMs,
        });
      }
      return response;
    } catch (error) {
      if (error instanceof SiteBlockedError) {
        throw error;
      }
      lastError = error;
      if (attempt < config.maximumRetries) {
        await logger.log(
          'WARNING',
          `${description} navigation retry ${attempt}/${config.maximumRetries} | ${error.message}`,
        );
        await delay(config.retryBaseDelayMs * 2 ** (attempt - 1));
      }
    }
  }
  throw new Error(
    `${description} navigation failed after ${config.maximumRetries} attempts | ${lastError?.message ?? 'Unknown error'}`,
  );
}

async function waitForStableResultLinks(page, selector, timeoutMs) {
  const started = Date.now();
  let previousCount = -1;
  let stableObservations = 0;
  while (Date.now() - started < timeoutMs) {
    const count = await page.locator(selector).count();
    if (count > 0 && count === previousCount) {
      stableObservations += 1;
      if (stableObservations >= 3) {
        return count;
      }
    } else {
      stableObservations = 0;
      previousCount = count;
    }
    await page.waitForTimeout(250);
  }
  throw new DiscoveryError('Filtered product links did not stabilise before timeout.');
}

export async function discoverEarthenwareProducts({
  page,
  selectors,
  config,
  logger,
  blockGuard,
}) {
  await navigateWithRetry({
    page,
    url: config.overviewUrl,
    requiredSelector: selectors.overview.earthenwareFilter,
    description: 'Overview',
    config,
    logger,
    blockGuard,
  });

  const filter = page.locator(selectors.overview.earthenwareFilter);
  if ((await filter.count()) !== 1) {
    throw new DiscoveryError(
      `Earthenware filter selector matched ${await filter.count()} elements instead of one.`,
    );
  }

  const labelCountText = await page
    .locator(selectors.overview.earthenwareLabelCount)
    .first()
    .textContent()
    .catch(() => '');
  const filterResponsePromise = page
    .waitForResponse(
      (response) =>
        response.request().method() === 'POST' &&
        response.url().toLowerCase().includes('filtersearch'),
      { timeout: config.navigationTimeoutMs },
    )
    .then(
      (response) => ({ response, error: null }),
      (error) => ({ response: null, error }),
    );

  try {
    await filter.check({ force: true });
  } catch (error) {
    throw new DiscoveryError(`Earthenware filter could not be selected: ${error.message}`);
  }
  const filterOutcome = await filterResponsePromise;
  if (filterOutcome.error) {
    throw new DiscoveryError(
      `Earthenware filter response was not observed: ${filterOutcome.error.message}`,
    );
  }
  const filterResponse = filterOutcome.response;
  blockGuard.observe(filterResponse.status(), filterResponse.url());
  if (!filterResponse.ok()) {
    throw new DiscoveryError(
      `Earthenware filter request returned HTTP ${filterResponse.status()}.`,
    );
  }

  await page.waitForFunction(
    ({ countSelector, linkSelector }) => {
      const countText = document.querySelector(countSelector)?.textContent ?? '';
      const count = Number.parseInt(countText.replace(/\D/g, ''), 10);
      return Number.isFinite(count) && count > 0 && document.querySelectorAll(linkSelector).length > 0;
    },
    {
      countSelector: selectors.overview.resultCount,
      linkSelector: selectors.overview.productLinks,
    },
    { timeout: config.selectorTimeoutMs },
  );
  await waitForStableResultLinks(
    page,
    selectors.overview.productLinks,
    config.selectorTimeoutMs,
  );

  const resultCountText = await page
    .locator(selectors.overview.resultCount)
    .first()
    .textContent();
  const detectedCount = parseDisplayedCount(resultCountText);
  if (!Number.isFinite(detectedCount) || detectedCount < 1) {
    throw new DiscoveryError(`Could not parse the displayed result count: ${resultCountText}`);
  }

  const rawLinks = await page.locator(selectors.overview.productLinks).evaluateAll((anchors) =>
    anchors.map((anchor) => ({
      url: anchor.href,
      name:
        anchor.closest('.card')?.querySelector('h4')?.textContent?.replace(/\s+/g, ' ').trim() ||
        anchor.textContent?.replace(/\s+/g, ' ').trim() ||
        '',
    })),
  );

  const uniqueByUrl = new Map();
  for (const raw of rawLinks) {
    let url;
    try {
      url = normalizeUrl(raw.url, config.overviewUrl);
    } catch {
      continue;
    }
    if (!uniqueByUrl.has(url)) {
      uniqueByUrl.set(url, { url, name: normalizeWhitespace(raw.name) });
    }
  }

  const products = [];
  const codeToUrl = new Map();
  for (const product of uniqueByUrl.values()) {
    const productCode = extractCodeFromProductUrl(product.url);
    if (!productCode) {
      throw new DiscoveryError(`Product URL has no four-digit product code: ${product.url}`);
    }
    if (codeToUrl.has(productCode) && codeToUrl.get(productCode) !== product.url) {
      throw new DiscoveryError(
        `Duplicate product code ${productCode} has multiple URLs.`,
      );
    }
    codeToUrl.set(productCode, product.url);
    products.push({
      productCode,
      productName: product.name,
      url: product.url,
    });
  }

  if (products.length === 0) {
    throw new DiscoveryError('No earthenware product URLs were detected.');
  }
  if (products.length !== detectedCount) {
    throw new DiscoveryError(
      `Displayed count is ${detectedCount}, but ${products.length} unique product URLs were collected.`,
    );
  }

  const labelCount = parseDisplayedCount(labelCountText);
  if (Number.isFinite(labelCount) && labelCount !== detectedCount) {
    await logger.log(
      'WARNING',
      `Earthenware filter label reports ${labelCount}, while filtered results report ${detectedCount}.`,
    );
  }
  await logger.log('INFO', `Detected ${detectedCount} earthenware products`);
  if (detectedCount !== config.expectedReferenceCount) {
    await logger.log(
      'WARNING',
      `Current earthenware count ${detectedCount} differs from reference count ${config.expectedReferenceCount}.`,
    );
  }

  return {
    sourceUrl: config.overviewUrl,
    category: config.category,
    expectedReferenceCount: config.expectedReferenceCount,
    detectedCount,
    collectedAtUtc: new Date().toISOString(),
    products,
  };
}

function normaliseSectionLabel(value) {
  return normalizeWhitespace(value).toLowerCase().replace(/[：:]+$/g, '');
}

async function extractProductText(page, productSelectors) {
  return page.locator(productSelectors.detailsContainer).first().evaluate(
    (container, selectors) => {
      const normalise = (value) =>
        String(value ?? '')
          .replace(/\u00a0/g, ' ')
          .replace(/[\t\r\n ]+/g, ' ')
          .trim();
      const contentFrom = (element) => {
        if (element.matches('ul, ol')) {
          return [...element.querySelectorAll(':scope > li')]
            .map((item) => ({ type: 'listItem', text: normalise(item.textContent) }))
            .filter((item) => item.text);
        }
        if (element.matches('p')) {
          const text = normalise(element.textContent);
          return text ? [{ type: 'paragraph', text }] : [];
        }
        const semanticChildren = [...element.querySelectorAll(':scope > p, :scope > ul, :scope > ol')];
        if (semanticChildren.length > 0) {
          return semanticChildren.flatMap(contentFrom);
        }
        const text = normalise(element.textContent);
        return text ? [{ type: 'paragraph', text }] : [];
      };
      const keyForHeading = (heading) => {
        const label = normalise(heading).toLowerCase().replace(/[：:]+$/g, '');
        if (/^notes?\s*\/\s*application$/.test(label)) return 'notesApplication';
        if (/^properties$/.test(label)) return 'properties';
        if (/^(?:product\s+)?description$/.test(label)) return 'description';
        return 'additional';
      };

      const sections = {
        description: [],
        notesApplication: [],
        properties: [],
        additional: [],
      };
      const heading = normalise(container.querySelector(selectors.headingWithin)?.textContent);
      let activeKey = 'description';
      let activeAdditional = null;

      for (const child of [...container.children]) {
        if (child.matches('h1')) continue;
        if (child.matches(selectors.sectionHeadings)) {
          const sectionHeading = normalise(child.textContent);
          activeKey = keyForHeading(sectionHeading);
          if (activeKey === 'additional') {
            activeAdditional = { heading: sectionHeading, content: [] };
            sections.additional.push(activeAdditional);
          } else {
            activeAdditional = null;
          }
          continue;
        }
        if (
          child.matches('.btn, .product-buttons, a[href*="merkliste"], a[href*="haendlersuche"]') ||
          child.closest('.product-buttons')
        ) {
          continue;
        }
        const entries = contentFrom(child);
        if (entries.length === 0) continue;
        if (activeKey === 'additional' && activeAdditional) {
          activeAdditional.content.push(...entries);
        } else {
          sections[activeKey].push(...entries);
        }
      }

      return {
        heading,
        sections,
        unavailable: Boolean(
          container.querySelector('.fa-ban') ||
          /nicht mehr lieferbar|no longer available/i.test(container.textContent),
        ),
      };
    },
    {
      headingWithin: 'h1',
      sectionHeadings: productSelectors.sectionHeadings,
    },
  );
}

export async function extractProduct({
  page,
  manifestProduct,
  selectors,
  config,
  logger,
  blockGuard,
}) {
  await navigateWithRetry({
    page,
    url: manifestProduct.url,
    requiredSelector: selectors.product.heading,
    description: manifestProduct.productCode || 'Product',
    config,
    logger,
    blockGuard,
  });

  let lastError;
  for (let attempt = 1; attempt <= config.maximumRetries; attempt += 1) {
    try {
      const extracted = await extractProductText(page, selectors.product);
      const parsed = parseProductHeading(extracted.heading);
      if (
        manifestProduct.productCode &&
        parsed.productCode !== manifestProduct.productCode
      ) {
        throw new Error(
          `URL/code mismatch: manifest ${manifestProduct.productCode}, page ${parsed.productCode}.`,
        );
      }

      const imageUrls = await extractProductImageUrls(page, selectors.product);
      if (imageUrls.length === 0) {
        throw new Error('No product images were detected in the product image areas.');
      }

      const warnings = [];
      if (extracted.sections.description.length === 0) {
        warnings.push('Description section missing');
      }
      if (extracted.sections.notesApplication.length === 0) {
        warnings.push('Notes/Application section missing');
      }
      if (extracted.sections.properties.length === 0) {
        warnings.push('Properties section missing');
      }
      if (extracted.unavailable) {
        warnings.push('Source page marks this product as unavailable');
      }
      if (
        manifestProduct.productName &&
        normalizeWhitespace(manifestProduct.productName) !== parsed.productName
      ) {
        warnings.push(
          `Overview name differs from product heading: ${normalizeWhitespace(manifestProduct.productName)}`,
        );
      }

      return {
        ...parsed,
        sourceUrl: manifestProduct.url,
        sections: extracted.sections,
        imageUrls,
        warnings,
      };
    } catch (error) {
      if (error instanceof SiteBlockedError) throw error;
      lastError = error;
      if (attempt < config.maximumRetries) {
        await logger.log(
          'WARNING',
          `${manifestProduct.productCode} extraction retry ${attempt}/${config.maximumRetries} | ${error.message}`,
        );
        await page.waitForTimeout(config.retryBaseDelayMs * 2 ** (attempt - 1));
        const response = await page.reload({
          waitUntil: 'domcontentloaded',
          timeout: config.navigationTimeoutMs,
        });
        if (response) blockGuard.observe(response.status(), response.url());
      }
    }
  }
  throw new Error(
    `Product extraction failed after ${config.maximumRetries} attempts | ${lastError?.message ?? 'Unknown error'}`,
  );
}
