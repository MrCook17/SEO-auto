import fs from 'node:fs/promises';
import path from 'node:path';

const KILOBYTE = 1_024;
export const IMAGE_SIZE_THRESHOLDS = Object.freeze({
  over200Kb: 200 * KILOBYTE,
  over300Kb: 300 * KILOBYTE,
});

function containedPath(parentDirectory, ...segments) {
  const parent = path.resolve(parentDirectory);
  const target = path.resolve(parent, ...segments);
  const relative = path.relative(parent, target);
  if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) return null;
  return target;
}

function portableRelativePath(from, to) {
  return path.relative(from, to).split(path.sep).join('/');
}

async function readProductOutput(productDirectory, productCode) {
  try {
    const product = JSON.parse(
      await fs.readFile(path.join(productDirectory, 'product.json'), 'utf8'),
    );
    return product.productCode === productCode ? product : null;
  } catch {
    return null;
  }
}

export async function buildImageOptimizationReport({
  manifest,
  state,
  outputDirectory,
}) {
  const flaggedImages = [];
  for (const manifestProduct of manifest.products) {
    const stateEntry = state.products[manifestProduct.productCode];
    if (!stateEntry?.folderName) continue;
    const productDirectory = containedPath(outputDirectory, path.basename(stateEntry.folderName));
    if (!productDirectory) continue;
    const product = await readProductOutput(productDirectory, manifestProduct.productCode);
    if (!Array.isArray(product?.images)) continue;

    for (const image of product.images) {
      if (!image?.localFile) continue;
      const imagePath = containedPath(productDirectory, image.localFile);
      if (!imagePath) continue;
      let stat;
      try {
        stat = await fs.stat(imagePath);
      } catch {
        continue;
      }
      if (!stat.isFile() || stat.size <= IMAGE_SIZE_THRESHOLDS.over200Kb) continue;
      flaggedImages.push({
        productCode: manifestProduct.productCode,
        productName: product.productName ?? stateEntry.productName ?? '',
        thresholdBand:
          stat.size > IMAGE_SIZE_THRESHOLDS.over300Kb ? 'OVER_300_KB' : 'OVER_200_KB',
        sizeBytes: stat.size,
        sizeKb: Number((stat.size / KILOBYTE).toFixed(1)),
        relativePath: portableRelativePath(outputDirectory, imagePath),
        absolutePath: imagePath,
      });
    }
  }

  flaggedImages.sort(
    (left, right) =>
      right.sizeBytes - left.sizeBytes || left.relativePath.localeCompare(right.relativePath),
  );
  const over300Kb = flaggedImages.filter(
    (image) => image.sizeBytes > IMAGE_SIZE_THRESHOLDS.over300Kb,
  ).length;
  return {
    version: 1,
    generatedAtUtc: new Date().toISOString(),
    sizeUnit: 'KB uses 1,024 bytes.',
    thresholds: {
      over200KbBytes: IMAGE_SIZE_THRESHOLDS.over200Kb,
      over300KbBytes: IMAGE_SIZE_THRESHOLDS.over300Kb,
    },
    counts: {
      over200Kb: flaggedImages.length,
      over300Kb,
    },
    note: 'The over-300 KB count is a subset of the over-200 KB count.',
    images: flaggedImages,
  };
}
