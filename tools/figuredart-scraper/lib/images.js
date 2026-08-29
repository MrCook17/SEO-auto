import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';
import { atomicWriteFile, pathExists } from './files.js';
import { makeImageSlug } from './content.js';
import { requestBufferWithRetry, SiteBlockedError } from './http.js';

const OUTPUT_IMAGE_FORMAT = 'jpeg';
const OUTPUT_IMAGE_EXTENSION = '.jpg';
const OUTPUT_IMAGE_CONTENT_TYPE = 'image/jpeg';

function randomDelay(minimumMs, maximumMs) {
  const span = Math.max(0, maximumMs - minimumMs);
  return minimumMs + Math.floor(Math.random() * (span + 1));
}

function normalizeImageUrl(value, baseUrl) {
  const url = new URL(String(value), baseUrl);
  url.protocol = 'https:';
  url.hash = '';
  for (const parameter of ['width', 'height', 'crop', 'format']) {
    url.searchParams.delete(parameter);
  }
  return url.href;
}

export function dedupeImageSources(values, baseUrl) {
  const unique = new Map();
  for (const value of values ?? []) {
    try {
      const normalized = normalizeImageUrl(value, baseUrl);
      if (!unique.has(normalized)) unique.set(normalized, normalized);
    } catch {
      // Other valid gallery URLs remain usable.
    }
  }
  return [...unique.values()];
}

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

async function imageMetadata(bufferOrPath) {
  const metadata = await sharp(bufferOrPath, { animated: true }).metadata();
  if (!metadata.format || !metadata.width || !metadata.height) {
    throw new Error('Image metadata did not contain format and dimensions.');
  }
  const logicalHeight = metadata.pageHeight ?? metadata.height;
  return { ...metadata, logicalHeight };
}

async function jpegOutputBuffer(buffer, metadata, maximumDimension) {
  const needsResize = metadata.width > maximumDimension || metadata.logicalHeight > maximumDimension;
  const needsConversion = metadata.format !== OUTPUT_IMAGE_FORMAT;
  if (!needsResize && !needsConversion) {
    return { buffer, resized: false, converted: false };
  }

  let pipeline = sharp(buffer)
    .rotate()
    .flatten({ background: '#ffffff' })
    .toColourspace('srgb');
  if (needsResize) {
    pipeline = pipeline.resize({
        width: maximumDimension,
        height: maximumDimension,
        fit: 'inside',
        withoutEnlargement: true,
      });
  }
  pipeline = pipeline.jpeg({
    quality: 92,
    progressive: true,
    mozjpeg: true,
    chromaSubsampling: '4:4:4',
  });
  return {
    buffer: await pipeline.toBuffer(),
    resized: needsResize,
    converted: needsConversion,
  };
}

export async function constrainImageBuffer(buffer, maximumDimension = 1_000) {
  const original = await imageMetadata(buffer);
  const processed = await jpegOutputBuffer(buffer, original, maximumDimension);
  const final = await imageMetadata(processed.buffer);
  if (final.width > maximumDimension || final.logicalHeight > maximumDimension) {
    throw new Error('Processed image still exceeds the configured maximum dimensions.');
  }
  if (final.format !== OUTPUT_IMAGE_FORMAT) {
    throw new Error(`Processed image format is ${final.format}, not JPEG.`);
  }
  return {
    buffer: processed.buffer,
    resized: processed.resized,
    converted: processed.converted,
    originalWidth: original.width,
    originalHeight: original.logicalHeight,
    width: final.width,
    height: final.logicalHeight,
    format: final.format,
  };
}

async function reusableImage(previous, productDirectory, maximumDimension) {
  if (!previous?.localFile || !previous?.sourceUrl) return null;
  const target = path.resolve(productDirectory, previous.localFile);
  const relative = path.relative(productDirectory, target);
  if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) return null;
  if (!(await pathExists(target))) return null;
  const buffer = await fs.readFile(target);
  if (previous.sha256 && sha256(buffer) !== previous.sha256) return null;
  const metadata = await imageMetadata(buffer);
  if (metadata.width > maximumDimension || metadata.logicalHeight > maximumDimension) return null;
  if (metadata.format !== OUTPUT_IMAGE_FORMAT) return null;
  if (path.extname(target).toLowerCase() !== OUTPUT_IMAGE_EXTENSION) return null;
  return {
    ...previous,
    bytes: buffer.length,
    width: metadata.width,
    height: metadata.logicalHeight,
    format: OUTPUT_IMAGE_FORMAT,
    contentType: OUTPUT_IMAGE_CONTENT_TYPE,
    converted: Boolean(previous.converted),
  };
}

function recordedImagePath(productDirectory, localFile) {
  if (!localFile) return null;
  const imagesDirectory = path.resolve(productDirectory, 'images');
  const target = path.resolve(productDirectory, localFile);
  const relative = path.relative(imagesDirectory, target);
  if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) return null;
  return target;
}

export async function removeStaleProductImages({
  previousImages,
  currentImages,
  productDirectory,
  productCode,
  logger,
}) {
  const retained = new Set(
    (currentImages ?? [])
      .map((image) => recordedImagePath(productDirectory, image.localFile))
      .filter(Boolean)
      .map((target) => target.toLowerCase()),
  );
  let removed = 0;
  for (const previous of previousImages ?? []) {
    const target = recordedImagePath(productDirectory, previous?.localFile);
    if (!target || retained.has(target.toLowerCase()) || !(await pathExists(target))) continue;
    await fs.rm(target);
    removed += 1;
    await logger?.log('INFO', `${productCode} stale image removed`, {
      localFile: previous.localFile,
    });
  }
  return removed;
}

export async function downloadProductImages({
  imageUrls,
  previousImages,
  productDirectory,
  productCode,
  productName,
  canonicalUrl,
  baseUrl,
  config,
  logger,
  blockGuard,
}) {
  const sources = dedupeImageSources(imageUrls, baseUrl);
  const previousBySource = new Map(
    (previousImages ?? []).map((image) => [image.sourceUrl, image]),
  );
  const images = [];
  const warnings = [];
  const seenSourceHashes = new Map();
  const seenFinalHashes = new Map();
  const slug = makeImageSlug(productName);
  let downloaded = 0;
  let resized = 0;
  let converted = 0;
  let reused = 0;
  let duplicates = 0;

  await fs.mkdir(path.join(productDirectory, 'images'), { recursive: true });
  for (const sourceUrl of sources) {
    try {
      const previous = previousBySource.get(sourceUrl);
      const reusable = await reusableImage(
        previous,
        productDirectory,
        config.maximumImageDimension,
      );
      if (reusable && !seenFinalHashes.has(reusable.sha256)) {
        images.push(reusable);
        seenFinalHashes.set(reusable.sha256, reusable.localFile);
        reused += 1;
        await logger.log('INFO', `${productCode} image reused`, {
          sourceUrl,
          localFile: reusable.localFile,
        });
        continue;
      }

      const response = await requestBufferWithRetry({
        url: sourceUrl,
        description: `${productCode} image download`,
        config,
        logger,
        blockGuard,
        accept: 'image/jpeg,image/png;q=0.9,*/*;q=0.1',
        referer: canonicalUrl,
      });
      const sourceHash = sha256(response.buffer);
      if (seenSourceHashes.has(sourceHash)) {
        duplicates += 1;
        await logger.log('INFO', `${productCode} duplicate image content skipped`, {
          sourceUrl,
          matches: seenSourceHashes.get(sourceHash),
        });
        continue;
      }
      seenSourceHashes.set(sourceHash, sourceUrl);

      const processed = await constrainImageBuffer(
        response.buffer,
        config.maximumImageDimension,
      );
      const finalHash = sha256(processed.buffer);
      if (seenFinalHashes.has(finalHash)) {
        duplicates += 1;
        continue;
      }
      const sequence = String(images.length + 1).padStart(2, '0');
      const fileName = `${productCode}_${slug}_${sequence}${OUTPUT_IMAGE_EXTENSION}`;
      const localFile = path.posix.join('images', fileName);
      await atomicWriteFile(
        path.join(productDirectory, 'images', fileName),
        processed.buffer,
      );
      const record = {
        sourceUrl,
        localFile,
        sourceContentType: response.contentType.split(';', 1)[0],
        contentType: OUTPUT_IMAGE_CONTENT_TYPE,
        format: OUTPUT_IMAGE_FORMAT,
        sourceBytes: response.buffer.length,
        bytes: processed.buffer.length,
        sourceSha256: sourceHash,
        sha256: finalHash,
        originalWidth: processed.originalWidth,
        originalHeight: processed.originalHeight,
        width: processed.width,
        height: processed.height,
        resized: processed.resized,
        converted: processed.converted,
      };
      images.push(record);
      seenFinalHashes.set(finalHash, localFile);
      downloaded += 1;
      if (processed.resized) resized += 1;
      if (processed.converted) converted += 1;
      await logger.log('INFO', `${productCode} image saved`, record);
    } catch (error) {
      if (error instanceof SiteBlockedError) throw error;
      const warning = `Image failed: ${sourceUrl} | ${error.message}`;
      warnings.push(warning);
      await logger.log('WARNING', `${productCode} ${warning}`);
    }
    await new Promise((resolve) =>
      setTimeout(resolve, randomDelay(config.imageDelayMinMs, config.imageDelayMaxMs)),
    );
  }

  return {
    images,
    warnings,
    metrics: {
      discovered: sources.length,
      downloaded,
      resized,
      converted,
      reused,
      duplicates,
      staleRemoved: 0,
    },
  };
}
