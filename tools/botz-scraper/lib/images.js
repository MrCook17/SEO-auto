import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import {
  cleanImageUrl,
  dedupeImageUrls,
  detectImageExtension,
  extensionFromContentType,
  extensionFromUrl,
  isImageContentType,
  makeImageSlug,
  selectLargestSrcset,
} from './content.js';

export class SiteBlockedError extends Error {
  constructor(message, status) {
    super(message);
    this.name = 'SiteBlockedError';
    this.status = status;
  }
}

export class BlockingResponseGuard {
  constructor(limit) {
    this.limit = limit;
    this.consecutiveBlockingResponses = 0;
  }

  observe(status, url) {
    if (status === 403 || status === 429) {
      this.consecutiveBlockingResponses += 1;
      if (this.consecutiveBlockingResponses >= this.limit) {
        throw new SiteBlockedError(
          `BOTZ returned ${status} ${this.consecutiveBlockingResponses} consecutive times; stopping without evasion. URL: ${url}`,
          status,
        );
      }
      return;
    }
    this.consecutiveBlockingResponses = 0;
  }
}

function looksLikeProductImageUrl(value) {
  if (!value || /^data:/i.test(value) || /^javascript:/i.test(value) || value === '#') {
    return false;
  }
  try {
    const url = new URL(value, 'https://www.botz-glasuren.de/');
    return (
      /\/fileadmin\/media\/produkte\//i.test(url.pathname) ||
      /\.(?:jpe?g|png|webp|gif|bmp|tiff?|avif|svg)$/i.test(url.pathname)
    );
  } catch {
    return false;
  }
}

function bestCandidateFromGroup(group, baseUrl) {
  const ranked = [];
  const add = (value, score) => {
    if (!value) {
      return;
    }
    try {
      ranked.push({ url: cleanImageUrl(value, baseUrl), score });
    } catch {
      // A malformed candidate does not invalidate other sources for the same image.
    }
  };

  for (const href of group.anchorHrefs ?? []) {
    if (looksLikeProductImageUrl(href)) {
      add(href, 100_000);
    }
  }
  for (const source of group.sources ?? []) {
    const largest = selectLargestSrcset(source.srcset);
    if (largest) {
      add(largest.url, 95_000 + largest.score);
    }
    add(source.src, 72_000);
    add(source.dataSrc, 84_000);
    add(source.dataLazySrc, 85_000);
  }
  for (const image of group.images ?? []) {
    const largest = selectLargestSrcset(image.srcset);
    if (largest) {
      add(largest.url, 90_000 + largest.score);
    }
    add(image.dataLazySrc, 85_000);
    add(image.dataSrc, 84_000);
    add(image.currentSrc, 80_000);
    add(image.src, 70_000);
  }
  for (const dataThumb of group.dataThumbs ?? []) {
    add(dataThumb, 65_000);
  }
  for (const background of group.backgrounds ?? []) {
    add(background, 60_000);
  }

  ranked.sort((left, right) => right.score - left.score);
  return ranked[0]?.url ?? '';
}

export async function extractProductImageUrls(page, productSelectors) {
  const root = page.locator(productSelectors.imageRoot).first();
  await root.waitFor({ state: 'attached' });
  await root.scrollIntoViewIfNeeded().catch(() => {});

  const extracted = await page.evaluate((selectors) => {
    const absolute = (value) => {
      if (!value) return '';
      try {
        return new URL(value, document.baseURI).href;
      } catch {
        return value;
      }
    };
    const backgroundUrls = (element) => {
      const values = [];
      const backgrounds = [element.style?.backgroundImage, getComputedStyle(element).backgroundImage];
      for (const background of backgrounds) {
        if (!background || background === 'none') continue;
        const matches = background.matchAll(/url\((['"]?)(.*?)\1\)/g);
        for (const match of matches) values.push(absolute(match[2]));
      }
      return values;
    };
    const describeGroup = (element) => {
      const images = element.matches('img') ? [element] : [...element.querySelectorAll('img')];
      const sources = element.matches('source')
        ? [element]
        : [...element.querySelectorAll('source')];
      const anchors = element.matches('a[href]') ? [element] : [...element.querySelectorAll('a[href]')];
      const thumbElements = [element, ...element.querySelectorAll('[data-thumb]')];
      const styledElements = [element, ...element.querySelectorAll('[style*="background"]')];
      return {
        images: images.map((image) => ({
          src: absolute(image.getAttribute('src')),
          currentSrc: image.currentSrc || '',
          dataSrc: absolute(image.getAttribute('data-src')),
          dataLazySrc: absolute(image.getAttribute('data-lazy-src')),
          srcset: image.getAttribute('srcset') || '',
        })),
        sources: sources.map((source) => ({
          src: absolute(source.getAttribute('src')),
          dataSrc: absolute(source.getAttribute('data-src')),
          dataLazySrc: absolute(source.getAttribute('data-lazy-src')),
          srcset: source.getAttribute('srcset') || '',
        })),
        anchorHrefs: anchors.map((anchor) => anchor.href || absolute(anchor.getAttribute('href'))),
        dataThumbs: thumbElements
          .map((thumb) => absolute(thumb.getAttribute('data-thumb')))
          .filter(Boolean),
        backgrounds: styledElements.flatMap(backgroundUrls),
      };
    };

    const roots = selectors.imageAreas.flatMap((selector) => [...document.querySelectorAll(selector)]);
    if (roots.length === 0) {
      const fallbackRoot = document.querySelector(selectors.imageRoot);
      if (fallbackRoot) roots.push(fallbackRoot);
    }

    const groups = [];
    const seenElements = new Set();
    for (const imageArea of roots) {
      let items = [...imageArea.querySelectorAll(':scope > li')];
      if (items.length === 0) {
        items = [...imageArea.querySelectorAll('img, picture, a[href], [data-thumb], [style*="background"]')];
      }
      for (const item of items) {
        if (seenElements.has(item)) continue;
        seenElements.add(item);
        groups.push(describeGroup(item));
      }
    }

    const fallback = document.querySelector(selectors.fallbackImage)?.getAttribute('content') || '';
    return { baseUrl: document.baseURI, groups, fallback: absolute(fallback) };
  }, productSelectors);

  const candidates = extracted.groups
    .map((group) => bestCandidateFromGroup(group, extracted.baseUrl))
    .filter(Boolean);
  if (candidates.length === 0 && extracted.fallback) {
    candidates.push(extracted.fallback);
  }
  return dedupeImageUrls(candidates, extracted.baseUrl);
}

function contentTypeForExtension(extension) {
  return new Map([
    ['.jpg', 'image/jpeg'],
    ['.jpeg', 'image/jpeg'],
    ['.png', 'image/png'],
    ['.webp', 'image/webp'],
    ['.gif', 'image/gif'],
    ['.bmp', 'image/bmp'],
    ['.tif', 'image/tiff'],
    ['.tiff', 'image/tiff'],
    ['.avif', 'image/avif'],
    ['.svg', 'image/svg+xml'],
  ]).get(extension) ?? 'application/octet-stream';
}

function randomDelay(minimumMs, maximumMs) {
  const span = Math.max(0, maximumMs - minimumMs);
  return minimumMs + Math.floor(Math.random() * (span + 1));
}

async function writeDownloadedImage(finalPath, buffer) {
  await fs.mkdir(path.dirname(finalPath), { recursive: true });
  const partialPath = `${finalPath}.partial`;
  let handle;
  try {
    handle = await fs.open(partialPath, 'w');
    await handle.writeFile(buffer);
    await handle.sync();
    await handle.close();
    handle = undefined;
    await fs.rename(partialPath, finalPath);
  } catch (error) {
    if (handle) await handle.close().catch(() => {});
    await fs.rm(partialPath, { force: true }).catch(() => {});
    throw error;
  }
}

async function downloadSingleImage({
  request,
  sourceUrl,
  referer,
  productDirectory,
  fileStem,
  index,
  config,
  logger,
  blockGuard,
  seenHashes,
}) {
  let lastError;
  for (let attempt = 1; attempt <= config.maximumRetries; attempt += 1) {
    try {
      const response = await request.get(sourceUrl, {
        timeout: config.downloadTimeoutMs,
        failOnStatusCode: false,
        headers: {
          Accept: 'image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8,*/*;q=0.5',
          Referer: referer,
        },
      });
      const status = response.status();
      blockGuard.observe(status, sourceUrl);
      if (!response.ok()) {
        throw new Error(`Image request returned HTTP ${status}.`);
      }

      const buffer = await response.body();
      const declaredContentType = response.headers()['content-type'] ?? '';
      const detectedExtension = detectImageExtension(buffer);
      if (!detectedExtension) {
        throw new Error(
          `Response did not contain a recognised image signature (Content-Type: ${declaredContentType || 'missing'}).`,
        );
      }

      const extension =
        detectedExtension ||
        extensionFromContentType(declaredContentType) ||
        extensionFromUrl(sourceUrl);
      const contentType = isImageContentType(declaredContentType)
        ? declaredContentType.split(';', 1)[0].trim().toLowerCase()
        : contentTypeForExtension(extension);
      const checksum = crypto.createHash('sha256').update(buffer).digest('hex');
      if (seenHashes.has(checksum)) {
        await logger.log(
          'INFO',
          `Duplicate image content skipped | ${sourceUrl} | matches ${seenHashes.get(checksum)}`,
        );
        return { duplicate: true };
      }

      const sequence = String(index).padStart(2, '0');
      const fileName = `${fileStem}_${sequence}${extension}`;
      const localFile = path.posix.join('images', fileName);
      const finalPath = path.join(productDirectory, 'images', fileName);
      await writeDownloadedImage(finalPath, buffer);
      seenHashes.set(checksum, localFile);
      return {
        duplicate: false,
        image: {
          sourceUrl,
          localFile,
          contentType,
          bytes: buffer.length,
          sha256: checksum,
        },
      };
    } catch (error) {
      if (error instanceof SiteBlockedError) {
        throw error;
      }
      lastError = error;
      if (attempt < config.maximumRetries) {
        const delay = config.retryBaseDelayMs * 2 ** (attempt - 1);
        await logger.log(
          'WARNING',
          `Image retry ${attempt}/${config.maximumRetries} | ${sourceUrl} | ${error.message}`,
        );
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }
  throw new Error(
    `Image download failed after ${config.maximumRetries} attempts: ${sourceUrl} | ${lastError?.message ?? 'Unknown error'}`,
  );
}

export async function downloadProductImages({
  context,
  imageUrls,
  productDirectory,
  productCode,
  productName,
  productUrl,
  config,
  logger,
  blockGuard,
}) {
  const images = [];
  const seenHashes = new Map();
  const slug = makeImageSlug(productCode, productName);
  const fileStem = `${productCode}_${slug}`;

  for (const sourceUrl of imageUrls) {
    const result = await downloadSingleImage({
      request: context.request,
      sourceUrl,
      referer: productUrl,
      productDirectory,
      fileStem,
      index: images.length + 1,
      config,
      logger,
      blockGuard,
      seenHashes,
    });
    if (!result.duplicate) {
      images.push(result.image);
    }
    await new Promise((resolve) =>
      setTimeout(resolve, randomDelay(80, 180)),
    );
  }
  return images;
}
