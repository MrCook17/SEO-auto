import path from 'node:path';

export const EXIT_CODES = Object.freeze({
  success: 0,
  productFailure: 1,
  configurationError: 2,
  interrupted: 4,
});

export const DEFAULT_CONFIG = Object.freeze({
  baseUrl: 'https://craftbuddyltd.co.uk',
  outputDirectory: 'C:\\Crystal Art',
  requestTimeoutMs: 30_000,
  maximumRetries: 3,
  retryBaseDelayMs: 1_000,
  delayMinMs: 750,
  delayMaxMs: 1_500,
  maximumImageBytes: 299_000,
  resizeStartPixels: 1_000,
  userAgent:
    'Cromartie-Crystal-Art-Trade-Product-Scraper/1.1 (respectful sequential scraper; https://www.cromartiehobbycraft.co.uk/)',
});

export function buildConfig(options, scriptDirectory) {
  return {
    ...DEFAULT_CONFIG,
    inputPath: path.resolve(options.input ?? path.join(scriptDirectory, 'product-codes.txt')),
    outputDirectory: path.resolve(options.output ?? DEFAULT_CONFIG.outputDirectory),
    delayMinMs: options.delayMinMs ?? DEFAULT_CONFIG.delayMinMs,
    delayMaxMs: options.delayMaxMs ?? DEFAULT_CONFIG.delayMaxMs,
  };
}
