import fs from 'node:fs/promises';
import path from 'node:path';
import { stableUrlSuffix } from './content.js';

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
    if (handle) {
      await handle.close().catch(() => {});
    }
    await fs.rm(temporaryPath, { force: true }).catch(() => {});
    throw error;
  }
}

export async function atomicWriteJson(targetPath, value) {
  await atomicWriteFile(targetPath, `${JSON.stringify(value, null, 2)}\n`);
}

export async function readJsonIfExists(targetPath) {
  if (!(await pathExists(targetPath))) {
    return null;
  }
  return JSON.parse(await fs.readFile(targetPath, 'utf8'));
}

function newState() {
  return {
    version: 1,
    updatedAtUtc: new Date().toISOString(),
    products: {},
  };
}

function corruptBackupPath(targetPath) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const extension = path.extname(targetPath);
  const stem = path.basename(targetPath, extension);
  return path.join(path.dirname(targetPath), `${stem}.corrupt-${timestamp}${extension}`);
}

export async function loadState(statePath, logger) {
  if (!(await pathExists(statePath))) {
    return { state: newState(), recoveredProcessingCount: 0, corruptBackup: '' };
  }

  let state;
  try {
    state = JSON.parse(await fs.readFile(statePath, 'utf8'));
    if (!state || typeof state !== 'object' || !state.products || typeof state.products !== 'object') {
      throw new Error('State JSON does not contain a products object.');
    }
  } catch (error) {
    const backupPath = corruptBackupPath(statePath);
    await fs.rename(statePath, backupPath);
    if (logger) {
      await logger.log(
        'WARNING',
        `Invalid state file preserved as ${backupPath} | ${error.message}`,
      );
    }
    return { state: newState(), recoveredProcessingCount: 0, corruptBackup: backupPath };
  }

  let recoveredProcessingCount = 0;
  for (const entry of Object.values(state.products)) {
    if (entry?.status === 'processing') {
      entry.status = 'pending';
      entry.interrupted = true;
      entry.lastError = 'Previous run ended while this product was processing.';
      entry.updatedAtUtc = new Date().toISOString();
      recoveredProcessingCount += 1;
    }
  }
  state.version ??= 1;
  state.updatedAtUtc = new Date().toISOString();
  return { state, recoveredProcessingCount, corruptBackup: '' };
}

export async function saveState(statePath, state) {
  state.updatedAtUtc = new Date().toISOString();
  await atomicWriteJson(statePath, state);
}

export async function loadFailedProducts(failedPath, logger) {
  if (!(await pathExists(failedPath))) {
    return [];
  }
  try {
    const parsed = JSON.parse(await fs.readFile(failedPath, 'utf8'));
    if (!Array.isArray(parsed)) {
      throw new Error('Expected a JSON array.');
    }
    return parsed;
  } catch (error) {
    const backupPath = corruptBackupPath(failedPath);
    await fs.rename(failedPath, backupPath);
    if (logger) {
      await logger.log(
        'WARNING',
        `Invalid failed-products file preserved as ${backupPath} | ${error.message}`,
      );
    }
    return [];
  }
}

function isInsideDirectory(parentDirectory, targetPath) {
  const relative = path.relative(parentDirectory, targetPath);
  return relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative);
}

export async function validateCompletedProduct(productDirectory, expected = {}) {
  try {
    const productMarkdownPath = path.join(productDirectory, 'product.md');
    const sourcePath = path.join(productDirectory, 'source.json');
    const [markdown, source] = await Promise.all([
      fs.readFile(productMarkdownPath, 'utf8'),
      fs.readFile(sourcePath, 'utf8').then(JSON.parse),
    ]);

    if (!/^\d{4}$/.test(source.productCode ?? '')) {
      return { valid: false, reason: 'source.json has no valid product code.' };
    }
    if (!String(source.productName ?? '').trim()) {
      return { valid: false, reason: 'source.json has no product name.' };
    }
    if (expected.productCode && source.productCode !== expected.productCode) {
      return { valid: false, reason: 'Existing product code does not match.' };
    }
    if (expected.sourceUrl && source.sourceUrl !== expected.sourceUrl) {
      return { valid: false, reason: 'Existing source URL does not match.' };
    }
    if (!markdown.includes(source.productCode) || !markdown.includes(source.productName)) {
      return { valid: false, reason: 'product.md is missing the product code or name.' };
    }
    if (!Array.isArray(source.images) || source.images.length === 0) {
      return { valid: false, reason: 'source.json contains no downloaded images.' };
    }

    for (const image of source.images) {
      if (!image?.localFile) {
        return { valid: false, reason: 'An image record has no local file.' };
      }
      const imagePath = path.resolve(productDirectory, image.localFile);
      if (!isInsideDirectory(productDirectory, imagePath)) {
        return { valid: false, reason: 'An image record points outside the product folder.' };
      }
      const stat = await fs.stat(imagePath);
      if (!stat.isFile() || stat.size < 1) {
        return { valid: false, reason: `Image is empty: ${image.localFile}` };
      }
    }

    return { valid: true, reason: '', source };
  } catch (error) {
    return { valid: false, reason: error.message };
  }
}

async function existingSourceMatches(productDirectory, productCode, sourceUrl) {
  try {
    const source = JSON.parse(
      await fs.readFile(path.join(productDirectory, 'source.json'), 'utf8'),
    );
    return source.productCode === productCode && source.sourceUrl === sourceUrl;
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
  const candidates = [...new Set([baseFolderName, preferred].filter(Boolean))];

  for (const folderName of candidates) {
    const productDirectory = path.join(outputDirectory, folderName);
    if (!(await pathExists(productDirectory))) {
      return { folderName, productDirectory, collision: false };
    }
    const match = await existingSourceMatches(productDirectory, productCode, sourceUrl);
    if (match === true || (match === null && folderName === preferred)) {
      return { folderName, productDirectory, collision: false };
    }
  }

  const folderName = `${baseFolderName}--${stableUrlSuffix(sourceUrl)}`;
  const productDirectory = path.join(outputDirectory, folderName);
  if (await pathExists(productDirectory)) {
    const match = await existingSourceMatches(productDirectory, productCode, sourceUrl);
    if (match !== true) {
      throw new Error(`Stable collision folder is already used by an unverifiable product: ${folderName}`);
    }
  }
  return { folderName, productDirectory, collision: true };
}
