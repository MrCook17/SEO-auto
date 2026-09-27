import fs from 'node:fs/promises';
import path from 'node:path';
import { buildMarkdown, htmlToMarkdown, makeProductFolderName } from './content.js';
import { EXIT_CODES } from './config.js';
import {
  atomicWriteFile,
  atomicWriteJson,
  chooseProductDirectory,
  loadState,
  pathExists,
  readProductCodes,
  saveState,
  validateCompletedProduct,
} from './files.js';
import { downloadProductImages } from './images.js';
import { Logger } from './logger.js';
import { findProductByCode, SiteBlockedError } from './site.js';

export class ConfigurationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ConfigurationError';
  }
}

function randomDelay(minimumMs, maximumMs) {
  return minimumMs + Math.floor(Math.random() * (Math.max(0, maximumMs - minimumMs) + 1));
}

function outputPaths(outputDirectory) {
  return {
    manifest: path.join(outputDirectory, 'manifest.json'),
    state: path.join(outputDirectory, 'scrape-state.json'),
    failures: path.join(outputDirectory, 'failed-products.json'),
  };
}

function upsertFailure(failures, failure) {
  const index = failures.findIndex(
    (entry) => entry.productCode.toUpperCase() === failure.productCode.toUpperCase(),
  );
  if (index >= 0) failures[index] = failure;
  else failures.push(failure);
}

function removeFailure(failures, productCode) {
  const index = failures.findIndex(
    (entry) => entry.productCode.toUpperCase() === productCode.toUpperCase(),
  );
  if (index >= 0) failures.splice(index, 1);
}

async function loadFailures(failurePath) {
  if (!(await pathExists(failurePath))) return [];
  try {
    const value = JSON.parse(await fs.readFile(failurePath, 'utf8'));
    return Array.isArray(value) ? value : [];
  } catch {
    return [];
  }
}

async function processProduct({ code, config, state, failures, paths, logger }) {
  const key = code.toUpperCase();
  const entry = state.products[key] ?? { productCode: code, attempts: 0 };
  state.products[key] = entry;
  entry.status = 'processing';
  entry.attempts += 1;
  entry.updatedAtUtc = new Date().toISOString();
  delete entry.interrupted;
  await saveState(paths.state, state);
  await logger.log('PROCESSING', code);

  try {
    const product = await findProductByCode(code, config, logger);
    const directory = await chooseProductDirectory({
      outputDirectory: config.outputDirectory,
      baseFolderName: makeProductFolderName(code, product.productName),
      preferredFolderName: entry.folderName,
      productCode: code,
      sourceUrl: product.sourceUrl,
    });
    await fs.mkdir(directory.productDirectory, { recursive: true });
    const images = await downloadProductImages({
      product,
      productDirectory: directory.productDirectory,
      config,
      logger,
    });
    const source = {
      ...product,
      descriptionMarkdown: htmlToMarkdown(product.descriptionHtml),
      scrapedAtUtc: new Date().toISOString(),
      images,
      warnings: directory.collision
        ? [`Folder-name collision; used ${directory.folderName}.`]
        : [],
    };
    await atomicWriteFile(
      path.join(directory.productDirectory, 'description.html'),
      source.descriptionHtml,
    );
    await atomicWriteFile(
      path.join(directory.productDirectory, 'product.md'),
      buildMarkdown(source),
    );
    await atomicWriteJson(path.join(directory.productDirectory, 'source.json'), source);

    const verification = await validateCompletedProduct(
      directory.productDirectory,
      { productCode: code },
      config.maximumImageBytes,
    );
    if (!verification.valid) throw new Error(`Completion verification failed: ${verification.reason}`);

    entry.productName = product.productName;
    entry.sourceUrl = product.sourceUrl;
    entry.folderName = directory.folderName;
    entry.status = source.warnings.length ? 'warning' : 'complete';
    entry.imageCount = images.length;
    entry.completedAtUtc = source.scrapedAtUtc;
    entry.updatedAtUtc = new Date().toISOString();
    delete entry.lastError;
    removeFailure(failures, code);
    await Promise.all([
      saveState(paths.state, state),
      atomicWriteJson(paths.failures, failures),
    ]);
    await logger.log('COMPLETE', `${code} ${product.productName} | ${images.length} JPEG images`);
    return { failed: false, blocked: false, imageCount: images.length };
  } catch (error) {
    entry.status = 'failed';
    entry.lastError = error.message;
    entry.updatedAtUtc = new Date().toISOString();
    upsertFailure(failures, {
      productCode: code,
      error: error.message,
      lastFailedAtUtc: entry.updatedAtUtc,
    });
    await Promise.all([
      saveState(paths.state, state),
      atomicWriteJson(paths.failures, failures),
    ]);
    await logger.log('FAILED', `${code} | ${error.message}`);
    return { failed: true, blocked: error instanceof SiteBlockedError, imageCount: 0 };
  }
}

export async function runScraper({ options, config }) {
  if (config.delayMinMs > config.delayMaxMs) {
    throw new ConfigurationError('Minimum delay cannot exceed maximum delay.');
  }
  let logger;
  try {
    logger = await Logger.create(config.outputDirectory);
  } catch (error) {
    throw new ConfigurationError(`Output folder is not writable: ${config.outputDirectory} | ${error.message}`);
  }

  let codes;
  if (options.productCode) {
    codes = [options.productCode];
  } else {
    try {
      const loaded = await readProductCodes(config.inputPath);
      codes = loaded.codes;
      if (loaded.duplicates.length) {
        await logger.log('WARNING', `Ignored duplicate input codes: ${loaded.duplicates.join(', ')}`);
      }
    } catch (error) {
      throw new ConfigurationError(`Input file could not be loaded: ${config.inputPath} | ${error.message}`);
    }
  }

  const paths = outputPaths(config.outputDirectory);
  const state = await loadState(paths.state, logger);
  const failures = await loadFailures(paths.failures);
  if (options.retryFailed) {
    const failedCodes = new Set(failures.map((entry) => entry.productCode.toUpperCase()));
    codes = codes.filter((code) => failedCodes.has(code.toUpperCase()));
  }
  await atomicWriteJson(paths.manifest, {
    inputPath: options.productCode ? null : config.inputPath,
    collectedAtUtc: new Date().toISOString(),
    productCodes: codes,
  });

  const queue = [];
  let skipped = 0;
  for (const code of codes) {
    const entry = state.products[code.toUpperCase()];
    if (!options.force && entry?.folderName && entry.status !== 'failed') {
      const verification = await validateCompletedProduct(
        path.join(config.outputDirectory, path.basename(entry.folderName)),
        { productCode: code },
        config.maximumImageBytes,
      );
      if (verification.valid) {
        skipped += 1;
        await logger.log('SKIPPED', `${code} | Already complete and verified`);
        continue;
      }
      await logger.log('INFO', `${code} will be repaired | ${verification.reason}`);
    }
    if (options.limit !== undefined && queue.length >= options.limit) break;
    queue.push(code);
  }

  let completed = 0;
  let failed = 0;
  let totalImages = 0;
  let interrupted = false;
  let stopRequested = false;
  const requestStop = () => {
    stopRequested = true;
  };
  process.once('SIGINT', requestStop);
  process.once('SIGTERM', requestStop);
  try {
    for (let index = 0; index < queue.length; index += 1) {
      if (stopRequested) {
        interrupted = true;
        break;
      }
      const result = await processProduct({
        code: queue[index],
        config,
        state,
        failures,
        paths,
        logger,
      });
      if (result.failed) failed += 1;
      else completed += 1;
      totalImages += result.imageCount;
      if (result.blocked) break;
      if (index < queue.length - 1) {
        await new Promise((resolve) =>
          setTimeout(resolve, randomDelay(config.delayMinMs, config.delayMaxMs)),
        );
      }
    }
  } finally {
    process.removeListener('SIGINT', requestStop);
    process.removeListener('SIGTERM', requestStop);
  }

  await logger.log(
    'INFO',
    `Summary | selected ${codes.length}, completed ${completed}, skipped ${skipped}, failed ${failed}, images ${totalImages}`,
  );
  return {
    exitCode: interrupted
      ? EXIT_CODES.interrupted
      : failed > 0
        ? EXIT_CODES.productFailure
        : EXIT_CODES.success,
    summary: { selected: codes.length, completed, skipped, failed, totalImages },
  };
}
