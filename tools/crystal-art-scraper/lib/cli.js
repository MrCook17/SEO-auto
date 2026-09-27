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

function positiveInteger(value, optionName) {
  if (!/^\d+$/.test(value) || Number(value) < 1) {
    throw new CliError(`${optionName} must be a positive integer.`);
  }
  return Number(value);
}

export function validateProductCode(value) {
  const code = String(value ?? '').trim();
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{1,79}$/.test(code)) {
    throw new CliError(`Invalid product code: ${code || '(empty)'}`);
  }
  return code;
}

export function parseArguments(argumentsList) {
  const options = {
    input: undefined,
    output: undefined,
    productCode: undefined,
    limit: undefined,
    force: false,
    retryFailed: false,
    resume: false,
    help: false,
    delayMinMs: undefined,
    delayMaxMs: undefined,
  };

  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    switch (argument) {
      case '--input':
        options.input = requireValue(argumentsList, index, argument);
        index += 1;
        break;
      case '--output':
        options.output = requireValue(argumentsList, index, argument);
        index += 1;
        break;
      case '--product-code':
        options.productCode = validateProductCode(
          requireValue(argumentsList, index, argument),
        );
        index += 1;
        break;
      case '--limit':
        options.limit = positiveInteger(requireValue(argumentsList, index, argument), argument);
        index += 1;
        break;
      case '--delay-min-ms':
        options.delayMinMs = positiveInteger(
          requireValue(argumentsList, index, argument),
          argument,
        );
        index += 1;
        break;
      case '--delay-max-ms':
        options.delayMaxMs = positiveInteger(
          requireValue(argumentsList, index, argument),
          argument,
        );
        index += 1;
        break;
      case '--force':
        options.force = true;
        break;
      case '--retry-failed':
        options.retryFailed = true;
        break;
      case '--resume':
        options.resume = true;
        break;
      case '--help':
      case '-h':
        options.help = true;
        break;
      default:
        throw new CliError(`Unknown option: ${argument}`);
    }
  }

  if (options.productCode && options.retryFailed) {
    throw new CliError('--product-code cannot be combined with --retry-failed.');
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
  return `Craft Buddy Crystal Art scraper

Usage:
  node crystal-art-scraper.js [options]

Options:
  --input PATH           One-product-code-per-line file (default: product-codes.txt)
  --output PATH          Output folder (default: C:\\Crystal Art)
  --product-code CODE    Process one code without changing the input file
  --limit N              Process at most N non-complete selected products
  --resume               Explicit resume alias; completed folders are always verified/skipped
  --retry-failed         Retry only failed codes still present in the input file
  --force                Reprocess selected products
  --delay-min-ms N       Minimum delay between products
  --delay-max-ms N       Maximum delay between products
  --help                 Show this help
`;
}
