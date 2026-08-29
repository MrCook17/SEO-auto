import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import sharp from 'sharp';

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

export async function readJsonIfExists(targetPath) {
  if (!(await pathExists(targetPath))) return null;
  return JSON.parse(await fs.readFile(targetPath, 'utf8'));
}

function corruptBackupPath(targetPath) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const extension = path.extname(targetPath);
  const stem = path.basename(targetPath, extension);
  return path.join(path.dirname(targetPath), `${stem}.corrupt-${timestamp}${extension}`);
}

export async function loadState(statePath, logger) {
  const fresh = { version: 1, updatedAtUtc: new Date().toISOString(), products: {} };
  if (!(await pathExists(statePath))) {
    return { state: fresh, recoveredProcessingCount: 0 };
  }
  let state;
  try {
    state = JSON.parse(await fs.readFile(statePath, 'utf8'));
    if (!state || typeof state !== 'object' || typeof state.products !== 'object') {
      throw new Error('State JSON does not contain a products object.');
    }
  } catch (error) {
    const backupPath = corruptBackupPath(statePath);
    await fs.rename(statePath, backupPath);
    await logger?.log('WARNING', `Invalid state preserved as ${backupPath}`, {
      error: error.message,
    });
    return { state: fresh, recoveredProcessingCount: 0 };
  }

  let recoveredProcessingCount = 0;
  for (const entry of Object.values(state.products)) {
    if (entry?.status === 'PROCESSING') {
      entry.status = 'PENDING';
      entry.interrupted = true;
      entry.lastError = 'Previous run ended while this product was processing.';
      entry.updatedAtUtc = new Date().toISOString();
      recoveredProcessingCount += 1;
    }
  }
  state.version ??= 1;
  return { state, recoveredProcessingCount };
}

export async function saveState(statePath, state) {
  state.updatedAtUtc = new Date().toISOString();
  await atomicWriteJson(statePath, state);
}

export function sanitizeWindowsName(value, maximumLength = 170) {
  let safe = String(value ?? '')
    .replace(/\u00a0/g, ' ')
    .replace(/[\t\r\n ]+/g, ' ')
    .trim()
    .replace(/[<>:"/\\|?*\u0000-\u001f]/g, '_')
    .replace(/[. ]+$/g, '');
  if (!safe) safe = 'unnamed';
  if (/^(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$/i.test(safe)) {
    safe = `_${safe}`;
  }
  if (safe.length > maximumLength) {
    safe = safe.slice(0, maximumLength).replace(/[. ]+$/g, '');
  }
  return safe || 'unnamed';
}

export function makeProductFolderName(productCode, productName) {
  const name = String(productName ?? '')
    .replace(new RegExp(`^${productCode}\\s+`, 'i'), '')
    .trim();
  return sanitizeWindowsName(`${productCode} ${name || 'unnamed'}`);
}

function isInsideDirectory(parentDirectory, targetPath) {
  const relative = path.relative(parentDirectory, targetPath);
  return relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative);
}

export async function validateCompletedProduct(productDirectory, expected = {}) {
  try {
    const markdown = await fs.readFile(path.join(productDirectory, 'product.md'), 'utf8');
    const product = JSON.parse(
      await fs.readFile(path.join(productDirectory, 'product.json'), 'utf8'),
    );
    if (!product.productCode || product.productCode !== expected.productCode) {
      return { valid: false, reason: 'product.json code does not match.' };
    }
    if (product.status !== 'SUCCESS') {
      return { valid: false, reason: `Existing status is ${product.status ?? 'missing'}.` };
    }
    if (!product.productName || !product.canonicalUrl) {
      return { valid: false, reason: 'Core product fields are missing.' };
    }
    if (!markdown.includes(product.productCode) || !markdown.includes(product.productName)) {
      return { valid: false, reason: 'product.md is missing the code or product name.' };
    }
    if (!Array.isArray(product.images) || product.images.length === 0) {
      return { valid: false, reason: 'No images are recorded.' };
    }
    for (const image of product.images) {
      if (path.extname(image.localFile ?? '').toLowerCase() !== '.jpg') {
        return { valid: false, reason: `Image is not saved as .jpg: ${image.localFile}` };
      }
      const imagePath = path.resolve(productDirectory, image.localFile ?? '');
      if (!isInsideDirectory(productDirectory, imagePath)) {
        return { valid: false, reason: 'An image points outside the product folder.' };
      }
      const stat = await fs.stat(imagePath);
      if (!stat.isFile() || stat.size < 1) {
        return { valid: false, reason: `Image is empty: ${image.localFile}` };
      }
      const metadata = await sharp(imagePath).metadata();
      if (metadata.format !== 'jpeg') {
        return { valid: false, reason: `Image content is not JPEG: ${image.localFile}` };
      }
      if ((metadata.width ?? 0) > 1_000 || (metadata.height ?? 0) > 1_000) {
        return { valid: false, reason: `Image exceeds 1000px: ${image.localFile}` };
      }
      if (image.sha256) {
        const checksum = crypto
          .createHash('sha256')
          .update(await fs.readFile(imagePath))
          .digest('hex');
        if (checksum !== image.sha256) {
          return { valid: false, reason: `Image checksum differs: ${image.localFile}` };
        }
      }
    }
    return { valid: true, reason: '', product };
  } catch (error) {
    return { valid: false, reason: error.message };
  }
}
