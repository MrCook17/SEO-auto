import path from 'node:path';

export const EXIT_CODES = Object.freeze({
  success: 0,
  productFailure: 1,
  configurationError: 2,
  manifestFailure: 3,
  interrupted: 4,
});

export const STATUSES = Object.freeze({
  success: 'SUCCESS',
  notFound: 'NOT_FOUND',
  ambiguous: 'AMBIGUOUS_MATCH',
  scrapeFailed: 'SCRAPE_FAILED',
  partial: 'PARTIAL',
  pending: 'PENDING',
  processing: 'PROCESSING',
});

export const DEFAULT_CONFIG = Object.freeze({
  outputDirectory: 'C:\\FiguredArt',
  requestTimeoutMs: 30_000,
  maximumRetries: 3,
  retryBaseDelayMs: 1_000,
  delayMinMs: 750,
  delayMaxMs: 1_500,
  imageDelayMinMs: 80,
  imageDelayMaxMs: 180,
  blockingResponseLimit: 3,
  maximumImageDimension: 1_000,
  userAgent:
    "Cromartie-FiguredArt-Public-Product-Scraper/1.0 (respectful sequential scraper; https://www.cromartiehobbycraft.co.uk/)",
});

export function buildConfig(options = {}) {
  return {
    ...DEFAULT_CONFIG,
    pdfPath: path.resolve(options.pdf),
    outputDirectory: path.resolve(options.output ?? DEFAULT_CONFIG.outputDirectory),
    delayMinMs: options.delayMinMs ?? DEFAULT_CONFIG.delayMinMs,
    delayMaxMs: options.delayMaxMs ?? DEFAULT_CONFIG.delayMaxMs,
  };
}
