import fs from 'node:fs/promises';
import path from 'node:path';
import { stableUrlSuffix } from './content.js';
import { validateProductCode } from './cli.js';

export async function pathExists(targetPath) {
  try {
    await fs.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

function temporaryPathFor(targetPath) {
  const random = Math.random().toString(16).slice(2);
  return path.join(
    path.dirname(targetPath),
    `.${path.basename(targetPath)}.${process.pid}.${Date.now()}.${random}.tmp`,
  );
}

export async function atomicWriteFile(targetPath, content) {
  await fs.mkdir(path.dirname(targetPath), { recursive: true });
  const temporaryPath = temporaryPathFor(targetPath);
  let handle;
  try {
    handle = await fs.open(temporaryPath, 'wx');
    await handle.writeFile(content);
    await handle.sync();
    await handle.close();
    handle = undefined;
    await fs.rename(temporaryPath, targetPath);
  } catch (error) {
    if (handle) await handle.close().catch(() => {});
    await fs.rm(temporaryPath, { force: true }).catch(() => {});
    throw error;
  }
}

export async function atomicWriteJson(targetPath, value) {
  await atomicWriteFile(targetPath, `${JSON.stringify(value, null, 2)}\n`);
}

function newState() {
  return { version: 1, updatedAtUtc: new Date().toISOString(), products: {} };
}

function corruptBackupPath(targetPath) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const extension = path.extname(targetPath);
  const stem = path.basename(targetPath, extension);
  return path.join(path.dirname(targetPath), `${stem}.corrupt-${timestamp}${extension}`);
}

export async function loadState(statePath, logger) {
  if (!(await pathExists(statePath))) return newState();
  try {
    const state = JSON.parse(await fs.readFile(statePath, 'utf8'));
    if (!state?.products || typeof state.products !== 'object') {
      throw new Error('State has no products object.');
    }
    for (const entry of Object.values(state.products)) {
      if (entry?.status === 'processing') {
        entry.status = 'pending';
        entry.interrupted = true;
        entry.lastError = 'Previous run ended during this product.';
      }
    }
    return state;
  } catch (error) {
    const backup = corruptBackupPath(statePath);
    await fs.rename(statePath, backup);
    await logger.log('WARNING', `Invalid state preserved as ${backup} | ${error.message}`);
    return newState();
  }
}

export async function saveState(statePath, state) {
  state.updatedAtUtc = new Date().toISOString();
  await atomicWriteJson(statePath, state);
}

export async function readProductCodes(inputPath) {
  const text = await fs.readFile(inputPath, 'utf8');
  const seen = new Set();
  const codes = [];
  const duplicates = [];
  for (const rawLine of text.replace(/^\uFEFF/, '').split(/\r?\n/)) {
    const trimmed = rawLine.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const code = validateProductCode(trimmed);
    const key = code.toUpperCase();
    if (seen.has(key)) {
      duplicates.push(code);
      continue;
    }
    seen.add(key);
    codes.push(code);
  }
  if (codes.length === 0) throw new Error('The input file contains no product codes.');
  return { codes, duplicates };
}

function isInside(parentDirectory, targetPath) {
  const relative = path.relative(parentDirectory, targetPath);
  return relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative);
}

export async function validateCompletedProduct(productDirectory, expected, maximumImageBytes) {
  try {
    const [markdown, html, source] = await Promise.all([
      fs.readFile(path.join(productDirectory, 'product.md'), 'utf8'),
      fs.readFile(path.join(productDirectory, 'description.html'), 'utf8'),
      fs.readFile(path.join(productDirectory, 'source.json'), 'utf8').then(JSON.parse),
    ]);
    if (source.productCode?.toUpperCase() !== expected.productCode.toUpperCase()) {
      return { valid: false, reason: 'Product code mismatch.' };
    }
    if (!source.productName || !source.sourceUrl || !source.descriptionHtml) {
      return { valid: false, reason: 'Source metadata is incomplete.' };
    }
    if (!markdown.includes(source.productCode) || html !== source.descriptionHtml) {
      return { valid: false, reason: 'Saved description files do not match source metadata.' };
    }
    if (!Array.isArray(source.images) || source.images.length === 0) {
      return { valid: false, reason: 'No image records were saved.' };
    }
    for (const image of source.images) {
      const imagePath = path.resolve(productDirectory, image.localFile ?? '');
      if (!isInside(productDirectory, imagePath) || path.extname(imagePath).toLowerCase() !== '.jpg') {
        return { valid: false, reason: `Invalid image path: ${image.localFile}` };
      }
      const stat = await fs.stat(imagePath);
      if (!stat.isFile() || stat.size < 4 || stat.size >= maximumImageBytes) {
        return { valid: false, reason: `Image is empty or over the size cap: ${image.localFile}` };
      }
      const signature = await fs.readFile(imagePath).then((buffer) => buffer.subarray(0, 3));
      if (!(signature[0] === 0xff && signature[1] === 0xd8 && signature[2] === 0xff)) {
        return { valid: false, reason: `Image is not a JPEG: ${image.localFile}` };
      }
    }
    return { valid: true, reason: '', source };
  } catch (error) {
    return { valid: false, reason: error.message };
  }
}

async function existingSourceMatches(productDirectory, productCode) {
  try {
    const source = JSON.parse(await fs.readFile(path.join(productDirectory, 'source.json'), 'utf8'));
    return source.productCode?.toUpperCase() === productCode.toUpperCase();
  } catch {
    return null;
  }
}

export async function chooseProductDirectory({
  outputDirectory,
  baseFolderName,
  preferredFolderName,
  productCode,
  sourceUrl,
}) {
  const preferred = preferredFolderName ? path.basename(preferredFolderName) : '';
  for (const folderName of [...new Set([preferred, baseFolderName].filter(Boolean))]) {
    const productDirectory = path.join(outputDirectory, folderName);
    if (!(await pathExists(productDirectory))) {
      return { folderName, productDirectory, collision: false };
    }
    const match = await existingSourceMatches(productDirectory, productCode);
    if (match === true || (match === null && folderName === preferred)) {
      return { folderName, productDirectory, collision: false };
    }
  }
  const folderName = `${baseFolderName}--${stableUrlSuffix(sourceUrl)}`;
  return {
    folderName,
    productDirectory: path.join(outputDirectory, folderName),
    collision: true,
  };
}
