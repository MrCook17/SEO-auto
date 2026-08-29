import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { buildMarkdown } from './content.js';
import { EXIT_CODES, STATUSES } from './config.js';
import {
  atomicWriteFile,
  atomicWriteJson,
  loadState,
  makeProductFolderName,
  pathExists,
  readJsonIfExists,
  saveState,
  validateCompletedProduct,
} from './files.js';
import { BlockingResponseGuard, SiteBlockedError } from './http.js';
import { buildImageOptimizationReport } from './image-optimization.js';
import { downloadProductImages, removeStaleProductImages } from './images.js';
import { Logger } from './logger.js';
import { extractPdfManifest } from './pdf-manifest.js';
import {
  discoverExactCandidates,
  ProductDataError,
  verifyAndScrapeCandidate,
} from './site.js';

export class ConfigurationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ConfigurationError';
  }
}

export class ManifestError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ManifestError';
  }
}

function outputPaths(outputDirectory) {
  return {
    manifest: path.join(outputDirectory, 'pdf-manifest.json'),
    state: path.join(outputDirectory, 'scrape-state.json'),
    manualReview: path.join(outputDirectory, 'manual-review.json'),
    summary: path.join(outputDirectory, 'summary.json'),
    imageOptimization: path.join(outputDirectory, 'image-optimization.json'),
  };
}

function randomDelay(minimumMs, maximumMs) {
  const span = Math.max(0, maximumMs - minimumMs);
  return minimumMs + Math.floor(Math.random() * (span + 1));
}

function terminalStatus(value) {
  return [
    STATUSES.success,
    STATUSES.partial,
    STATUSES.notFound,
    STATUSES.ambiguous,
    STATUSES.scrapeFailed,
  ].includes(value);
}

function reconcileState(state, manifest) {
  for (const product of manifest.products) {
    const entry = state.products[product.productCode] ?? {
      productCode: product.productCode,
      status: STATUSES.pending,
      attempts: 0,
    };
    entry.sequence = product.sequence;
    entry.poDescription = product.poDescription;
    entry.pdfPage = product.pdfPage;
    entry.updatedAtUtc ??= new Date().toISOString();
    state.products[product.productCode] = entry;
    product.status = terminalStatus(entry.status) ? entry.status : STATUSES.pending;
    if (entry.productName) product.productName = entry.productName;
    if (entry.canonicalUrl) product.canonicalUrl = entry.canonicalUrl;
    if (entry.lastError) product.error = entry.lastError;
  }
}

function applyStateToManifest(manifest, state) {
  for (const product of manifest.products) {
    const entry = state.products[product.productCode];
    product.status = terminalStatus(entry?.status) ? entry.status : STATUSES.pending;
    for (const key of ['productName', 'canonicalUrl', 'folderName', 'lastError', 'warnings']) {
      if (entry?.[key]) product[key === 'lastError' ? 'error' : key] = entry[key];
      else delete product[key === 'lastError' ? 'error' : key];
    }
  }
  manifest.updatedAtUtc = new Date().toISOString();
}

function selectedProducts(manifest, options, state) {
  if (options.productCode) {
    const match = manifest.products.find(
      (product) => product.productCode === options.productCode,
    );
    if (!match) {
      throw new ConfigurationError(
        `Product code ${options.productCode} is not present in the PDF manifest.`,
      );
    }
    return [match];
  }
  if (options.retryAttention) {
    return manifest.products.filter(
      (product) => state.products[product.productCode]?.status !== STATUSES.success,
    );
  }
  return manifest.products;
}

async function prepareQueue({ products, options, state, config, logger }) {
  const queue = [];
  let skipped = 0;
  for (const product of products) {
    const entry = state.products[product.productCode];
    if (!options.force && entry.status === STATUSES.success && entry.folderName) {
      const productDirectory = path.join(config.outputDirectory, path.basename(entry.folderName));
      const verification = await validateCompletedProduct(productDirectory, {
        productCode: product.productCode,
      });
      if (verification.valid) {
        skipped += 1;
        entry.productName = verification.product.productName;
        entry.canonicalUrl = verification.product.canonicalUrl;
        entry.updatedAtUtc = new Date().toISOString();
        await logger.log('SKIPPED', `${product.productCode} already complete and verified`, {
          productName: entry.productName,
          folderName: entry.folderName,
          images: verification.product.images.length,
        });
        continue;
      }
      await logger.log('WARNING', `${product.productCode} existing output will be repaired`, {
        reason: verification.reason,
      });
    }
    if (options.limit !== undefined && queue.length >= options.limit) break;
    queue.push(product);
  }
  return { queue, skipped };
}

async function chooseProductDirectory({ config, stateEntry, scraped }) {
  const preferred = stateEntry.folderName ? path.basename(stateEntry.folderName) : '';
  const base = makeProductFolderName(scraped.productCode, scraped.productName);
  const candidates = [...new Set([preferred, base].filter(Boolean))];
  for (const folderName of candidates) {
    const productDirectory = path.join(config.outputDirectory, folderName);
    if (!(await pathExists(productDirectory))) return { folderName, productDirectory };
    const existing = await readJsonIfExists(path.join(productDirectory, 'product.json')).catch(
      () => null,
    );
    if (!existing || existing.productCode === scraped.productCode) {
      return { folderName, productDirectory };
    }
  }
  const suffix = crypto.createHash('sha256').update(scraped.canonicalUrl).digest('hex').slice(0, 8);
  const folderName = `${base}--${suffix}`;
  return { folderName, productDirectory: path.join(config.outputDirectory, folderName) };
}

function summaryFromManifest(manifest, skipped = 0, imageOptimization) {
  const count = (status) => manifest.products.filter((product) => product.status === status).length;
  const pendingCodes = manifest.products
    .filter((product) => !terminalStatus(product.status))
    .map((product) => product.productCode);
  const manualAttentionCodes = manifest.products
    .filter((product) => product.status !== STATUSES.success && terminalStatus(product.status))
    .map((product) => product.productCode);
  return {
    generatedAtUtc: new Date().toISOString(),
    totalPdfProducts: manifest.products.length,
    successful: count(STATUSES.success),
    partial: count(STATUSES.partial),
    notFound: count(STATUSES.notFound),
    ambiguous: count(STATUSES.ambiguous),
    failed: count(STATUSES.scrapeFailed),
    pending: pendingCodes.length,
    skippedThisRun: skipped,
    imagesOver200Kb: imageOptimization.counts.over200Kb,
    imagesOver300Kb: imageOptimization.counts.over300Kb,
    imageOptimizationReport: imageOptimization.reportPath,
    manualAttentionCodes,
    pendingCodes,
  };
}

function manualReviewFromManifest(manifest) {
  return manifest.products
    .filter((product) => product.status !== STATUSES.success && terminalStatus(product.status))
    .map((product) => ({
      productCode: product.productCode,
      poDescription: product.poDescription,
      status: product.status,
      productName: product.productName ?? '',
      canonicalUrl: product.canonicalUrl ?? '',
      warnings: product.warnings ?? [],
      error: product.error ?? '',
    }));
}

async function writeRunReports(paths, manifest, state, skipped = 0) {
  applyStateToManifest(manifest, state);
  const imageOptimization = await buildImageOptimizationReport({
    manifest,
    state,
    outputDirectory: path.dirname(paths.summary),
  });
  imageOptimization.reportPath = paths.imageOptimization;
  const summary = summaryFromManifest(manifest, skipped, imageOptimization);
  await Promise.all([
    atomicWriteJson(paths.manifest, manifest),
    atomicWriteJson(paths.manualReview, manualReviewFromManifest(manifest)),
    atomicWriteJson(paths.imageOptimization, imageOptimization),
    atomicWriteJson(paths.summary, summary),
  ]);
  return summary;
}

async function finalizeWithoutProduct({
  status,
  product,
  state,
  stateEntry,
  paths,
  manifest,
  logger,
  error,
  warnings = [],
}) {
  stateEntry.status = status;
  stateEntry.lastError = error;
  stateEntry.warnings = warnings;
  stateEntry.updatedAtUtc = new Date().toISOString();
  await saveState(paths.state, state);
  await writeRunReports(paths, manifest, state);
  await logger.log('FINAL', `${product.productCode} ${status}`, {
    poDescription: product.poDescription,
    warnings,
    error,
  });
}

async function processOneProduct({
  product,
  manifest,
  state,
  paths,
  siteConfig,
  config,
  logger,
  blockGuard,
}) {
  const stateEntry = state.products[product.productCode];
  stateEntry.status = STATUSES.processing;
  stateEntry.attempts = (stateEntry.attempts ?? 0) + 1;
  stateEntry.lastError = '';
  stateEntry.warnings = [];
  delete stateEntry.interrupted;
  stateEntry.updatedAtUtc = new Date().toISOString();
  await saveState(paths.state, state);
  await logger.log('PROCESSING', `${product.productCode}`, {
    poDescription: product.poDescription,
    attempt: stateEntry.attempts,
  });

  try {
    const discovery = await discoverExactCandidates({
      productCode: product.productCode,
      poDescription: product.poDescription,
      siteConfig,
      config,
      logger,
      blockGuard,
    });
    if (discovery.exactCandidates.length === 0) {
      await finalizeWithoutProduct({
        status: STATUSES.notFound,
        product,
        state,
        stateEntry,
        paths,
        manifest,
        logger,
        error: `No storefront search candidate had exact SKU ${product.productCode}.`,
        warnings:
          discovery.allCandidates.length > 0
            ? ['Search returned products, but none had the exact authoritative SKU.']
            : [],
      });
      return { blocked: false };
    }
    if (discovery.exactCandidates.length > 1) {
      await finalizeWithoutProduct({
        status: STATUSES.ambiguous,
        product,
        state,
        stateEntry,
        paths,
        manifest,
        logger,
        error: `${discovery.exactCandidates.length} distinct products reported exact SKU ${product.productCode}.`,
        warnings: discovery.exactCandidates.map(
          (candidate) => `${candidate.title} | ${candidate.handle}`,
        ),
      });
      return { blocked: false };
    }

    const scraped = await verifyAndScrapeCandidate({
      productCode: product.productCode,
      candidate: discovery.exactCandidates[0],
      siteConfig,
      config,
      logger,
      blockGuard,
    });
    const directory = await chooseProductDirectory({ config, stateEntry, scraped });
    stateEntry.folderName = directory.folderName;
    stateEntry.productName = scraped.productName;
    stateEntry.canonicalUrl = scraped.canonicalUrl;
    await saveState(paths.state, state);
    await fs.mkdir(directory.productDirectory, { recursive: true });
    const previous = await readJsonIfExists(
      path.join(directory.productDirectory, 'product.json'),
    ).catch(() => null);
    const imageResult = await downloadProductImages({
      imageUrls: scraped.imageUrls,
      previousImages: previous?.images,
      productDirectory: directory.productDirectory,
      productCode: product.productCode,
      productName: scraped.productName,
      canonicalUrl: scraped.canonicalUrl,
      baseUrl: siteConfig.storefrontBaseUrl,
      config,
      logger,
      blockGuard,
    });

    const warnings = [...scraped.warnings, ...imageResult.warnings];
    const partialReasons = [];
    if (scraped.description.length === 0) partialReasons.push('Main description was empty.');
    if (scraped.imageUrls.length === 0) partialReasons.push('No official gallery images were discovered.');
    if (imageResult.images.length === 0) partialReasons.push('No product images were saved.');
    if (imageResult.warnings.length > 0) {
      partialReasons.push(`${imageResult.warnings.length} image(s) failed.`);
    }
    const status = partialReasons.length > 0 ? STATUSES.partial : STATUSES.success;
    warnings.push(...partialReasons);
    const productOutput = {
      version: 2,
      status,
      productCode: product.productCode,
      poDescription: product.poDescription,
      pdfPage: product.pdfPage,
      productName: scraped.productName,
      canonicalUrl: scraped.canonicalUrl,
      productId: scraped.productId,
      handle: scraped.handle,
      vendor: scraped.vendor,
      productType: scraped.productType,
      tags: scraped.tags,
      matchedVariant: scraped.matchedVariant,
      skuVerification: scraped.skuVerification,
      description: scraped.description,
      descriptionSource: scraped.descriptionSource,
      howItWorks: scraped.howItWorks,
      specifications: scraped.specifications,
      whatsIncluded: scraped.whatsIncluded,
      additionalInformation: scraped.additionalInformation,
      rawSource: {
        descriptionHtml: scraped.rawDescriptionHtml,
        howItWorksHtml: scraped.rawHowItWorksHtml,
      },
      discoveredImageUrls: scraped.imageUrls,
      imageMetadata: scraped.imageMetadata,
      images: imageResult.images,
      imageMetrics: imageResult.metrics,
      warnings,
      scrapedAtUtc: new Date().toISOString(),
    };
    await atomicWriteFile(
      path.join(directory.productDirectory, 'product.md'),
      buildMarkdown(productOutput),
    );
    await atomicWriteJson(
      path.join(directory.productDirectory, 'product.json'),
      productOutput,
    );

    if (status === STATUSES.success) {
      const verification = await validateCompletedProduct(directory.productDirectory, {
        productCode: product.productCode,
      });
      if (!verification.valid) {
        throw new Error(`Completion verification failed: ${verification.reason}`);
      }
    }
    imageResult.metrics.staleRemoved = await removeStaleProductImages({
      previousImages: previous?.images,
      currentImages: imageResult.images,
      productDirectory: directory.productDirectory,
      productCode: product.productCode,
      logger,
    });
    if (imageResult.metrics.staleRemoved > 0) {
      await atomicWriteJson(
        path.join(directory.productDirectory, 'product.json'),
        productOutput,
      );
    }
    stateEntry.status = status;
    stateEntry.productName = scraped.productName;
    stateEntry.canonicalUrl = scraped.canonicalUrl;
    stateEntry.folderName = directory.folderName;
    stateEntry.imageCount = imageResult.images.length;
    stateEntry.warnings = warnings;
    stateEntry.lastError = '';
    stateEntry.completedAtUtc = productOutput.scrapedAtUtc;
    stateEntry.updatedAtUtc = new Date().toISOString();
    await saveState(paths.state, state);
    await writeRunReports(paths, manifest, state);
    await logger.log('CONTENT', `${product.productCode} extraction status`, {
      description: scraped.description.length > 0 ? 'captured' : 'missing',
      howDoesItWork: scraped.howItWorks.length > 0 ? 'captured' : 'not present',
      specifications: scraped.specifications.length,
      whatsIncluded: scraped.whatsIncluded.length,
    });
    await logger.log('IMAGES', `${product.productCode} image status`, {
      ...imageResult.metrics,
      saved: imageResult.images.length,
    });
    await logger.log('FINAL', `${product.productCode} ${status}`, {
      matchedProduct: scraped.productName,
      matchedUrl: scraped.canonicalUrl,
      confirmedSku: scraped.matchedVariant.sku,
      outputFolder: directory.productDirectory,
      warnings,
    });
    return { blocked: false };
  } catch (error) {
    const status =
      error instanceof ProductDataError && /exactly one is required/.test(error.message)
        ? STATUSES.ambiguous
        : STATUSES.scrapeFailed;
    await finalizeWithoutProduct({
      status,
      product,
      state,
      stateEntry,
      paths,
      manifest,
      logger,
      error: error.message,
    });
    return { blocked: error instanceof SiteBlockedError };
  }
}

async function logSummary(logger, summary, config, paths) {
  await logger.log('SUMMARY', 'Figured\'Art scrape summary', {
    totalPdfProducts: summary.totalPdfProducts,
    successful: summary.successful,
    partial: summary.partial,
    notFound: summary.notFound,
    ambiguous: summary.ambiguous,
    failed: summary.failed,
    pending: summary.pending,
    imagesOver200Kb: summary.imagesOver200Kb,
    imagesOver300Kb: summary.imagesOver300Kb,
    imageOptimizationReport: summary.imageOptimizationReport,
    manualAttentionCodes: summary.manualAttentionCodes,
    outputPath: config.outputDirectory,
    summaryPath: paths.summary,
  });
}

export async function runScraper({ options, config, siteConfig }) {
  if (config.delayMinMs > config.delayMaxMs) {
    throw new ConfigurationError('Minimum product delay cannot exceed maximum product delay.');
  }
  if (!(await pathExists(config.pdfPath))) {
    throw new ConfigurationError(`PDF does not exist: ${config.pdfPath}`);
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
  let manifest;
  try {
    manifest = await extractPdfManifest(config.pdfPath);
  } catch (error) {
    throw new ManifestError(error.message);
  }
  await logger.log('MANIFEST', 'PDF product manifest extracted', {
    pdf: manifest.sourcePdf,
    pages: manifest.pdfPageCount,
    uniqueProducts: manifest.uniqueProductCount,
    codes: manifest.products.map((product) => product.productCode),
  });

  const loaded = await loadState(paths.state, logger);
  const state = loaded.state;
  if (loaded.recoveredProcessingCount > 0) {
    await logger.log('WARNING', 'Interrupted products reset to PENDING', {
      count: loaded.recoveredProcessingCount,
    });
  }
  reconcileState(state, manifest);
  await saveState(paths.state, state);
  let summary = await writeRunReports(paths, manifest, state);
  if (options.manifestOnly) {
    await logger.log('FINAL', 'Manifest-only run complete', {
      manifestPath: paths.manifest,
      products: manifest.uniqueProductCount,
    });
    await logSummary(logger, summary, config, paths);
    return { exitCode: EXIT_CODES.success, summary };
  }

  const selected = selectedProducts(manifest, options, state);
  const prepared = await prepareQueue({
    products: selected,
    options,
    state,
    config,
    logger,
  });
  await saveState(paths.state, state);
  const blockGuard = new BlockingResponseGuard(config.blockingResponseLimit);
  let stopRequested = false;
  let stopSignal = '';
  const onSignal = (signal) => {
    stopRequested = true;
    stopSignal = signal;
    console.warn(
      `[${new Date().toISOString()}] [WARNING] ${signal} received; stopping safely after the current product.`,
    );
  };
  const onSigint = () => onSignal('SIGINT');
  const onSigterm = () => onSignal('SIGTERM');
  process.once('SIGINT', onSigint);
  process.once('SIGTERM', onSigterm);

  try {
    for (let index = 0; index < prepared.queue.length; index += 1) {
      if (stopRequested) break;
      const result = await processOneProduct({
        product: prepared.queue[index],
        manifest,
        state,
        paths,
        siteConfig,
        config,
        logger,
        blockGuard,
      });
      if (result.blocked) {
        await logger.log(
          'FAILED',
          'Repeated access-blocking responses detected; stopping without evasion.',
        );
        break;
      }
      if (stopRequested) break;
      if (index < prepared.queue.length - 1) {
        await new Promise((resolve) =>
          setTimeout(resolve, randomDelay(config.delayMinMs, config.delayMaxMs)),
        );
      }
    }
    summary = await writeRunReports(paths, manifest, state, prepared.skipped);
    if (stopRequested) {
      await logger.log('WARNING', `${stopSignal} handled; completed state was preserved.`);
    }
    await logSummary(logger, summary, config, paths);
    return {
      exitCode: stopRequested
        ? EXIT_CODES.interrupted
        : summary.manualAttentionCodes.length > 0
          ? EXIT_CODES.productFailure
          : EXIT_CODES.success,
      summary,
    };
  } finally {
    process.removeListener('SIGINT', onSigint);
    process.removeListener('SIGTERM', onSigterm);
  }
}
