export class CliError extends Error {
  constructor(message) {
    super(message);
    this.name = 'CliError';
  }
}

function requireValue(argumentsList, index, optionName) {
  const value = argumentsList[index + 1];
  if (!value || value.startsWith('--')) {
    throw new CliError(`${optionName} requires a value.`);
  }
  return value;
}

function parsePositiveInteger(value, optionName) {
  if (!/^\d+$/.test(value) || Number(value) < 1) {
    throw new CliError(`${optionName} must be a positive integer.`);
  }
  return Number(value);
}

export function isProductCode(value) {
  return /^[A-Z][A-Z0-9]*\d[A-Z0-9]*(?:-[A-Z0-9]+)?$/i.test(String(value ?? '').trim());
}

export function parseArguments(argumentsList) {
  const options = {
    pdf: undefined,
    output: undefined,
    productCode: undefined,
    limit: undefined,
    force: false,
    retryAttention: false,
    manifestOnly: false,
    delayMinMs: undefined,
    delayMaxMs: undefined,
    help: false,
  };

  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    switch (argument) {
      case '--pdf':
        options.pdf = requireValue(argumentsList, index, argument);
        index += 1;
        break;
      case '--output':
        options.output = requireValue(argumentsList, index, argument);
        index += 1;
        break;
      case '--product-code': {
        const value = requireValue(argumentsList, index, argument).toUpperCase();
        if (!isProductCode(value)) {
          throw new CliError('--product-code is not a valid supplier product code.');
        }
        options.productCode = value;
        index += 1;
        break;
      }
      case '--limit':
        options.limit = parsePositiveInteger(
          requireValue(argumentsList, index, argument),
          argument,
        );
        index += 1;
        break;
      case '--delay-min-ms':
        options.delayMinMs = parsePositiveInteger(
          requireValue(argumentsList, index, argument),
          argument,
        );
        index += 1;
        break;
      case '--delay-max-ms':
        options.delayMaxMs = parsePositiveInteger(
          requireValue(argumentsList, index, argument),
          argument,
        );
        index += 1;
        break;
      case '--force':
        options.force = true;
        break;
      case '--retry-attention':
        options.retryAttention = true;
        break;
      case '--manifest-only':
        options.manifestOnly = true;
        break;
      case '--help':
      case '-h':
        options.help = true;
        break;
      default:
        throw new CliError(`Unknown option: ${argument}`);
    }
  }

  if (!options.help && !options.pdf) {
    throw new CliError('--pdf is required.');
  }
  if (options.retryAttention && options.productCode) {
    throw new CliError('--retry-attention cannot be combined with --product-code.');
  }
  if (options.manifestOnly && (options.productCode || options.retryAttention || options.force)) {
    throw new CliError('--manifest-only cannot be combined with processing options.');
  }
  if (
    options.delayMinMs !== undefined &&
    options.delayMaxMs !== undefined &&
    options.delayMinMs > options.delayMaxMs
  ) {
    throw new CliError('--delay-min-ms cannot exceed --delay-max-ms.');
  }

  return options;
}

export function usageText() {
  return `Figured'Art purchase-order product scraper

Usage:
  node figuredart-scraper.js --pdf PATH [options]

Options:
  --pdf PATH              Purchase-order PDF containing product codes/descriptions
  --output PATH           Output root (default: C:\\FiguredArt)
  --product-code CODE     Process one code from the PDF manifest
  --limit N               Process the first N eligible manifest products
  --manifest-only         Extract/write the PDF manifest without network access
  --retry-attention       Retry all non-SUCCESS manifest entries
  --force                 Reprocess selected SUCCESS entries
  --delay-min-ms N        Override minimum delay between products
  --delay-max-ms N        Override maximum delay between products
  --help                  Show this help
`;
}
