import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';
import { atomicWriteFile } from './files.js';
import { makeImageSlug } from './content.js';
import { fetchWithRetry } from './site.js';

function isJpeg(buffer) {
  return buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
}

export async function convertToCappedJpeg(input, config) {
  const metadata = await sharp(input, { animated: false }).metadata();
  if (!metadata.width || !metadata.height) throw new Error('Image dimensions could not be read.');

  if (isJpeg(input) && input.length < config.maximumImageBytes) {
    return {
      buffer: input,
      width: metadata.width,
      height: metadata.height,
      quality: null,
      resized: false,
    };
  }

  const originalMaximum = Math.max(metadata.width, metadata.height);
  let targetMaximum = Math.min(originalMaximum, config.resizeStartPixels);
  const qualities = [88, 82, 76, 70, 64, 58, 52, 46, 40, 34];
  let smallest;

  while (targetMaximum >= 160) {
    for (const quality of qualities) {
      const result = await sharp(input, { animated: false })
        .rotate()
        .flatten({ background: '#ffffff' })
        .resize({
          width: Math.round(targetMaximum),
          height: Math.round(targetMaximum),
          fit: 'inside',
          withoutEnlargement: true,
        })
        .jpeg({ quality, mozjpeg: true })
        .toBuffer({ resolveWithObject: true });
      smallest = { ...result, quality };
      if (result.data.length < config.maximumImageBytes) {
        return {
          buffer: result.data,
          width: result.info.width,
          height: result.info.height,
          quality,
          resized:
            result.info.width !== metadata.width || result.info.height !== metadata.height,
        };
      }
    }
    targetMaximum = Math.floor(targetMaximum * 0.8);
  }
  throw new Error(
    `Image could not be reduced below ${config.maximumImageBytes} bytes; smallest result was ${smallest?.data.length ?? 'unknown'} bytes.`,
  );
}

export async function downloadProductImages({
  product,
  productDirectory,
  config,
  logger,
  fetchImpl = fetch,
}) {
  const imagesDirectory = path.join(productDirectory, 'images');
  await fs.mkdir(imagesDirectory, { recursive: true });
  const slug = makeImageSlug(product.productName);
  const records = [];
  const hashes = new Set();

  for (let index = 0; index < product.imageUrls.length; index += 1) {
    const sourceUrl = product.imageUrls[index];
    const response = await fetchWithRetry(
      sourceUrl,
      config,
      logger,
      `${product.productCode} image ${index + 1}`,
      fetchImpl,
    );
    const contentType = response.headers.get('content-type') ?? '';
    if (!contentType.toLowerCase().startsWith('image/')) {
      throw new Error(`Image ${index + 1} returned non-image content type ${contentType || '(missing)'}.`);
    }
    const original = Buffer.from(await response.arrayBuffer());
    if (original.length === 0) throw new Error(`Image ${index + 1} was empty.`);
    const converted = await convertToCappedJpeg(original, config);
    const hash = crypto.createHash('sha256').update(converted.buffer).digest('hex');
    if (hashes.has(hash)) {
      await logger.log('WARNING', `${product.productCode} image ${index + 1} duplicated earlier content; skipped.`);
      continue;
    }
    hashes.add(hash);

    const sequence = String(records.length + 1).padStart(2, '0');
    const filename = `${product.productCode}_${slug}_${sequence}.jpg`;
    const targetPath = path.join(imagesDirectory, filename);
    await atomicWriteFile(targetPath, converted.buffer);
    records.push({
      sourceUrl,
      localFile: path.join('images', filename),
      originalBytes: original.length,
      finalBytes: converted.buffer.length,
      width: converted.width,
      height: converted.height,
      jpegQuality: converted.quality,
      resized: converted.resized,
      sha256: hash,
    });
  }

  if (records.length === 0) throw new Error('No unique images were saved.');

  const retained = new Set(records.map((record) => path.basename(record.localFile).toLowerCase()));
  const ownedPrefix = `${product.productCode}_`.toLowerCase();
  for (const entry of await fs.readdir(imagesDirectory, { withFileTypes: true })) {
    const lower = entry.name.toLowerCase();
    if (
      entry.isFile() &&
      lower.startsWith(ownedPrefix) &&
      lower.endsWith('.jpg') &&
      !retained.has(lower)
    ) {
      await fs.rm(path.join(imagesDirectory, entry.name));
    }
  }
  return records;
}
