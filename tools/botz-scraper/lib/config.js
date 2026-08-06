import path from 'node:path';

export const EXIT_CODES = Object.freeze({
  success: 0,
  productFailure: 1,
  configurationError: 2,
  discoveryFailure: 3,
  interrupted: 4,
});

export const DEFAULT_CONFIG = Object.freeze({
  overviewUrl: 'https://www.botz-glasuren.de/en/productoverview',
  category: 'Earthenware',
  outputDirectory: 'C:\\BOTZ',
  expectedReferenceCount: 136,
  navigationTimeoutMs: 30_000,
  downloadTimeoutMs: 30_000,
  selectorTimeoutMs: 15_000,
  delayMinMs: 750,
  delayMaxMs: 1_500,
  maximumRetries: 3,
  retryBaseDelayMs: 1_000,
  blockingResponseLimit: 3,
  headless: true,
  userAgent:
    'Cromartie-BOTZ-Public-Product-Scraper/1.0 (respectful sequential scraper; https://www.cromartiehobbycraft.co.uk/)',
});

export function buildConfig(options = {}) {
  const outputDirectory = path.resolve(
    options.output ?? DEFAULT_CONFIG.outputDirectory,
  );

  return {
    ...DEFAULT_CONFIG,
    outputDirectory,
    headless: !options.headed,
    delayMinMs: options.delayMinMs ?? DEFAULT_CONFIG.delayMinMs,
    delayMaxMs: options.delayMaxMs ?? DEFAULT_CONFIG.delayMaxMs,
  };
}
