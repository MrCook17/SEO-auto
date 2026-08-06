import fs from 'node:fs/promises';
import path from 'node:path';
import {
  buildMarkdown,
  extractCodeFromProductUrl,
  makeProductFolderName,
  normalizeUrl,
} from './content.js';
import {
  atomicWriteFile,
  atomicWriteJson,
  chooseProductDirectory,
  loadFailedProducts,
  loadState,
  pathExists,
  readJsonIfExists,
  saveState,
  validateCompletedProduct,
} from './files.js';
import {
  BlockingResponseGuard,
  downloadProductImages,
  SiteBlockedError,
} from './images.js';
import { Logger } from './logger.js';
import { discoverEarthenwareProducts, DiscoveryError, extractProduct } from './site.js';
import { EXIT_CODES } from './config.js';

export class ConfigurationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ConfigurationError';
  }
}

function outputPaths(outputDirectory) {
  return {
    manifest: path.join(outputDirectory, 'manifest.json'),
    dryRunManifest: path.join(outputDirectory, 'dry-run-manifest.json'),
    state: path.join(outputDirectory, 'scrape-state.json'),
    failed: path.join(outputDirectory, 'failed-products.json'),
    diagnostics: path.join(outputDirectory, 'diagnostics'),
  };
}

function randomDelay(minimumMs, maximumMs) {
  const span = Math.max(0, maximumMs - minimumMs);
  return minimumMs + Math.floor(Math.random() * (span + 1));
}

function normaliseManifest(manifest, overviewUrl) {
  if (!manifest || !Array.isArray(manifest.products) || manifest.products.length === 0) {
    throw new Error('Manifest has no products.');
  }
  const products = manifest.products.map((product) => {
    const url = normalizeUrl(product.url, overviewUrl);
    const productCode = product.productCode || extractCodeFromProductUrl(url);
    if (!/^\d{4}$/.test(productCode)) {
      throw new Error(`Manifest product URL has no four-digit code: ${url}`);
    }
    return {
      productCode,
      productName: String(product.productName ?? '').trim(),
      url,
    };
  });
  return { ...manifest, products };
}

async function manifestForRun({ page, paths, options, selectors, config, logger, blockGuard }) {
  if (options.productCode && !options.dryRun && (await pathExists(paths.manifest))) {
    try {
      const existing = normaliseManifest(await readJsonIfExists(paths.manifest), config.overviewUrl);
      if (existing.products.some((product) => product.productCode === options.productCode)) {
        await logger.log(
          'INFO',
          `Using existing manifest for product code ${options.productCode}`,
        );
        return { manifest: existing, discoveredNow: false };
      }
    } catch (error) {
      await logger.log(
        'WARNING',
        `Existing manifest could not be used; rediscovering products | ${error.message}`,
      );
    }
  }

  const manifest = await discoverEarthenwareProducts({
    page,
    selectors,
    config,
    logger,
    blockGuard,
  });
  return { manifest, discoveredNow: true };
}

function selectedProducts(manifest, options, failedProducts) {
  if (options.productCode) {
    const match = manifest.products.find(
      (product) => product.productCode === options.productCode,
    );
    if (!match) {
      throw new ConfigurationError(
        `Product code ${options.productCode} does not exist in the earthenware manifest.`,
      );
    }
    return [match];
  }
  if (options.retryFailed) {
    const failedCodes = new Set(
      failedProducts.map((entry) => entry.productCode).filter(Boolean),
    );
    return manifest.products.filter((product) => failedCodes.has(product.productCode));
  }
  return manifest.products;
}

function upsertFailed(failedProducts, failure) {
  const existingIndex = failedProducts.findIndex(
    (entry) => entry.productCode === failure.productCode,
  );
  if (existingIndex >= 0) failedProducts[existingIndex] = failure;
  else failedProducts.push(failure);
}

function removeFailed(failedProducts, productCode) {
  const index = failedProducts.findIndex((entry) => entry.productCode === productCode);
  if (index >= 0) failedProducts.splice(index, 1);
}

async function captureDiagnostics(page, diagnosticsDirectory, productCode, logger) {
  const safeCode = /^\d{4}$/.test(productCode ?? '') ? productCode : 'unknown-product';
  await fs.mkdir(diagnosticsDirectory, { recursive: true });
  const screenshotPath = path.join(diagnosticsDirectory, `${safeCode}-failure.png`);
  const screenshotPartial = `${screenshotPath}.partial`;
  const htmlPath = path.join(diagnosticsDirectory, `${safeCode}-failure.html`);
  try {
    await page.screenshot({
      path: screenshotPartial,
      type: 'png',
      fullPage: true,
      timeout: 15_000,
    });
    await fs.rename(screenshotPartial, screenshotPath);
  } catch (error) {
    await fs.rm(screenshotPartial, { force: true }).catch(() => {});
    await logger.log(
      'WARNING',
      `${safeCode} failure screenshot could not be saved | ${error.message}`,
    );
  }
  try {
    await atomicWriteFile(htmlPath, await page.content());
  } catch (error) {
    await logger.log(
      'WARNING',
      `${safeCode} failure HTML could not be saved | ${error.message}`,
    );
  }
}

function reconcileStateWithManifest(state, manifest) {
  for (const product of manifest.products) {
    const entry = state.products[product.productCode] ?? {
      status: 'pending',
      attempts: 0,
      updatedAtUtc: new Date().toISOString(),
    };
    entry.productCode = product.productCode;
    entry.productName ||= product.productName;
    entry.url = product.url;
    state.products[product.productCode] = entry;
  }
}

async function prepareQueue({
  products,
  options,
  state,
  outputDirectory,
  logger,
  summary,
  failedProducts,
}) {
  const queue = [];
  for (const product of products) {
    const stateEntry = state.products[product.productCode] ?? {
      status: 'pending',
      attempts: 0,
    };
    stateEntry.productCode = product.productCode;
    stateEntry.productName = product.productName;
    stateEntry.url = product.url;
    state.products[product.productCode] = stateEntry;

    if (!options.force && stateEntry.status !== 'failed' && !stateEntry.interrupted) {
      const folderName =
        stateEntry.folderName ||
        (product.productName
          ? makeProductFolderName(product.productCode, product.productName)
          : '');
      if (folderName) {
        const productDirectory = path.join(outputDirectory, path.basename(folderName));
        const verification = await validateCompletedProduct(productDirectory, {
          productCode: product.productCode,
          sourceUrl: product.url,
        });
        if (verification.valid) {
          stateEntry.folderName = path.basename(folderName);
          stateEntry.productName = verification.source.productName;
          stateEntry.status = verification.source.warnings?.length ? 'warning' : 'complete';
          stateEntry.imageCount = verification.source.images.length;
          stateEntry.updatedAtUtc = new Date().toISOString();
          summary.skipped += 1;
          removeFailed(failedProducts, product.productCode);
          await logger.log(
            'SKIPPED',
            `${verification.source.productName} | Already complete and verified`,
          );
          continue;
        }
        if (await pathExists(productDirectory)) {
          await logger.log(
            'INFO',
            `${product.productCode} will be repaired | ${verification.reason}`,
          );
        }
      }
    }

    if (options.limit !== undefined && queue.length >= options.limit) {
      break;
    }
    queue.push(product);
  }
  return queue;
}

async function processOneProduct({
  page,
  context,
  manifestProduct,
  selectors,
  config,
  logger,
  blockGuard,
  paths,
  state,
  failedProducts,
  summary,
}) {
  const stateEntry = state.products[manifestProduct.productCode];
  stateEntry.status = 'processing';
  delete stateEntry.interrupted;
  stateEntry.attempts = (stateEntry.attempts ?? 0) + 1;
  stateEntry.lastError = '';
  stateEntry.updatedAtUtc = new Date().toISOString();
  await saveState(paths.state, state);
  await logger.log(
    'PROCESSING',
    manifestProduct.productName || manifestProduct.productCode,
  );

  try {
    const extracted = await extractProduct({
      page,
      manifestProduct,
      selectors,
      config,
      logger,
      blockGuard,
    });
    const baseFolderName = makeProductFolderName(
      extracted.productCode,
      extracted.productName,
    );
    const directory = await chooseProductDirectory({
      outputDirectory: config.outputDirectory,
      baseFolderName,
      preferredFolderName: stateEntry.folderName,
      productCode: extracted.productCode,
      sourceUrl: extracted.sourceUrl,
    });
    if (directory.collision) {
      const warning = `Folder-name collision; using ${directory.folderName}`;
      extracted.warnings.push(warning);
      await logger.log('WARNING', `${extracted.productName} | ${warning}`);
    }
    stateEntry.folderName = directory.folderName;
    stateEntry.productName = extracted.productName;
    stateEntry.updatedAtUtc = new Date().toISOString();
    await saveState(paths.state, state);
    await fs.mkdir(path.join(directory.productDirectory, 'images'), {
      recursive: true,
    });

    const images = await downloadProductImages({
      context,
      imageUrls: extracted.imageUrls,
      productDirectory: directory.productDirectory,
      productCode: extracted.productCode,
      productName: extracted.productName,
      productUrl: extracted.sourceUrl,
      config,
      logger,
      blockGuard,
    });
    if (images.length === 0) {
      throw new Error('All discovered image sources resolved to duplicate or empty content.');
    }

    const source = {
      productCode: extracted.productCode,
      productName: extracted.productName,
      category: config.category,
      sourceUrl: extracted.sourceUrl,
      scrapedAtUtc: new Date().toISOString(),
      sections: extracted.sections,
      discoveredImageUrls: extracted.imageUrls,
      images,
      warnings: extracted.warnings,
    };
    await atomicWriteFile(
      path.join(directory.productDirectory, 'product.md'),
      buildMarkdown(source),
    );
    await atomicWriteJson(
      path.join(directory.productDirectory, 'source.json'),
      source,
    );

    const verification = await validateCompletedProduct(directory.productDirectory, {
      productCode: extracted.productCode,
      sourceUrl: extracted.sourceUrl,
    });
    if (!verification.valid) {
      throw new Error(`Completion verification failed: ${verification.reason}`);
    }

    stateEntry.productName = extracted.productName;
    stateEntry.folderName = directory.folderName;
    stateEntry.status = extracted.warnings.length > 0 ? 'warning' : 'complete';
    stateEntry.imageCount = images.length;
    stateEntry.warnings = extracted.warnings;
    stateEntry.completedAtUtc = source.scrapedAtUtc;
    stateEntry.updatedAtUtc = new Date().toISOString();
    await saveState(paths.state, state);
    removeFailed(failedProducts, extracted.productCode);
    await atomicWriteJson(paths.failed, failedProducts);

    summary.totalImagesDownloaded += images.length;
    if (extracted.warnings.length > 0) {
      summary.completedWithWarnings += 1;
      for (const warning of extracted.warnings) {
        await logger.log('WARNING', `${extracted.productName} | ${warning}`);
      }
      await logger.log(
        'WARNING',
        `${extracted.productName} | Completed with ${images.length} images`,
      );
    } else {
      summary.completed += 1;
      await logger.log('COMPLETE', `${extracted.productName} | ${images.length} images`);
    }
    return { blocked: false };
  } catch (error) {
    await captureDiagnostics(
      page,
      paths.diagnostics,
      manifestProduct.productCode,
      logger,
    );
    stateEntry.status = 'failed';
    stateEntry.lastError = error.message;
    stateEntry.updatedAtUtc = new Date().toISOString();
    await saveState(paths.state, state);
    upsertFailed(failedProducts, {
      productCode: manifestProduct.productCode,
      productName: manifestProduct.productName,
      url: manifestProduct.url,
      error: error.message,
      lastFailedAtUtc: new Date().toISOString(),
    });
    await atomicWriteJson(paths.failed, failedProducts);
    summary.failed += 1;
    summary.failedProductCodes.push(manifestProduct.productCode);
    await logger.log(
      'FAILED',
      `${manifestProduct.productName || manifestProduct.productCode} | ${error.message}`,
    );
    return { blocked: error instanceof SiteBlockedError };
  }
}

async function logSummary(logger, summary, config) {
  await logger.log('INFO', 'Scrape summary');
  await logger.log('INFO', `Detected products: ${summary.detectedProducts}`);
  await logger.log('INFO', `Unique collected URLs: ${summary.uniqueCollectedUrls}`);
  await logger.log('INFO', `Completed: ${summary.completed}`);
  await logger.log(
    'INFO',
    `Completed with warnings: ${summary.completedWithWarnings}`,
  );
  await logger.log('INFO', `Skipped: ${summary.skipped}`);
  await logger.log('INFO', `Failed: ${summary.failed}`);
  await logger.log('INFO', `Total images downloaded: ${summary.totalImagesDownloaded}`);
  await logger.log('INFO', `Output path: ${config.outputDirectory}`);
  await logger.log('INFO', `Log path: ${logger.logPath}`);
  await logger.log(
    'INFO',
    `Failed product codes: ${summary.failedProductCodes.join(', ') || 'None'}`,
  );
}

export async function runScraper({ chromium, selectors, options, config }) {
  if (config.delayMinMs > config.delayMaxMs) {
    throw new ConfigurationError('Minimum product delay cannot exceed maximum product delay.');
  }

  let logger;
  try {
    logger = await Logger.create(config.outputDirectory);
  } catch (error) {
    throw new ConfigurationError(
      `Output directory could not be created or written: ${config.outputDirectory} | ${error.message}`,
    );
  }

  const paths = outputPaths(config.outputDirectory);
  const summary = {
    detectedProducts: 0,
    uniqueCollectedUrls: 0,
    completed: 0,
    completedWithWarnings: 0,
    skipped: 0,
    failed: 0,
    totalImagesDownloaded: 0,
    failedProductCodes: [],
  };
  const blockGuard = new BlockingResponseGuard(config.blockingResponseLimit);
  let browser;
  let stopRequested = false;
  let stopSignal = '';
  const onSignal = (signal) => {
    stopRequested = true;
    stopSignal = signal;
    console.warn(`[${new Date().toISOString()}] [WARNING] ${signal} received; stopping safely after the current product.`);
  };
  const onSigint = () => onSignal('SIGINT');
  const onSigterm = () => onSignal('SIGTERM');
  process.once('SIGINT', onSigint);
  process.once('SIGTERM', onSigterm);

  try {
    try {
      browser = await chromium.launch({ headless: config.headless });
    } catch (error) {
      throw new ConfigurationError(
        `Chromium could not be launched. Run "npx playwright install chromium". ${error.message}`,
      );
    }
    const context = await browser.newContext({
      userAgent: config.userAgent,
      viewport: { width: 1440, height: 1000 },
      acceptDownloads: false,
    });
    const page = await context.newPage();
    page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
    page.setDefaultTimeout(config.selectorTimeoutMs);

    const { manifest } = await manifestForRun({
      page,
      paths,
      options,
      selectors,
      config,
      logger,
      blockGuard,
    });
    summary.detectedProducts = manifest.detectedCount;
    summary.uniqueCollectedUrls = manifest.products.length;

    if (options.dryRun) {
      await atomicWriteJson(paths.dryRunManifest, {
        ...manifest,
        diagnosticOnly: true,
      });
      for (const product of manifest.products) {
        await logger.log(
          'INFO',
          `DRY-RUN ${product.productCode} ${product.productName.replace(/^\d{4}\s+/, '')} | ${product.url}`,
        );
      }
      await logger.log(
        'INFO',
        `Dry run only; diagnostic manifest written to ${paths.dryRunManifest}`,
      );
      await logSummary(logger, summary, config);
      return { exitCode: EXIT_CODES.success, summary };
    }

    await atomicWriteJson(paths.manifest, manifest);
    await logger.log('INFO', `Manifest written before product processing: ${paths.manifest}`);

    const loadedState = await loadState(paths.state, logger);
    const state = loadedState.state;
    if (loadedState.recoveredProcessingCount > 0) {
      await logger.log(
        'WARNING',
        `Reset ${loadedState.recoveredProcessingCount} interrupted processing item(s) to pending.`,
      );
    }
    reconcileStateWithManifest(state, manifest);
    const failedProducts = await loadFailedProducts(paths.failed, logger);
    const selected = selectedProducts(manifest, options, failedProducts);
    if (options.retryFailed && selected.length === 0) {
      await logger.log('INFO', 'No failed products are currently eligible for retry.');
    }
    const queue = await prepareQueue({
      products: selected,
      options,
      state,
      outputDirectory: config.outputDirectory,
      logger,
      summary,
      failedProducts,
    });
    await saveState(paths.state, state);
    await atomicWriteJson(paths.failed, failedProducts);

    for (let index = 0; index < queue.length; index += 1) {
      if (stopRequested) break;
      const result = await processOneProduct({
        page,
        context,
        manifestProduct: queue[index],
        selectors,
        config,
        logger,
        blockGuard,
        paths,
        state,
        failedProducts,
        summary,
      });
      if (result.blocked) {
        await logger.log(
          'FAILED',
          'Repeated access-blocking responses detected; stopping safely without evasion.',
        );
        break;
      }
      if (stopRequested) break;
      if (index < queue.length - 1) {
        await page.waitForTimeout(randomDelay(config.delayMinMs, config.delayMaxMs));
      }
    }

    if (stopRequested) {
      await logger.log(
        'WARNING',
        `${stopSignal || 'Interrupt'} handled safely; completed state has been preserved.`,
      );
    }
    await logSummary(logger, summary, config);
    return {
      exitCode: stopRequested
        ? EXIT_CODES.interrupted
        : summary.failed > 0
          ? EXIT_CODES.productFailure
          : EXIT_CODES.success,
      summary,
    };
  } finally {
    process.removeListener('SIGINT', onSigint);
    process.removeListener('SIGTERM', onSigterm);
    if (browser) await browser.close().catch(() => {});
  }
}

export { DiscoveryError };
