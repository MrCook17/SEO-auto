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

export function parseArguments(argumentsList) {
  const options = {
    dryRun: false,
    resume: false,
    retryFailed: false,
    headed: false,
    force: false,
    help: false,
    limit: undefined,
    productCode: undefined,
    output: undefined,
    delayMinMs: undefined,
    delayMaxMs: undefined,
  };

  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    switch (argument) {
      case '--dry-run':
        options.dryRun = true;
        break;
      case '--resume':
        options.resume = true;
        break;
      case '--retry-failed':
        options.retryFailed = true;
        break;
      case '--headed':
        options.headed = true;
        break;
      case '--force':
        options.force = true;
        break;
      case '--help':
      case '-h':
        options.help = true;
        break;
      case '--limit': {
        const value = requireValue(argumentsList, index, argument);
        options.limit = parsePositiveInteger(value, argument);
        index += 1;
        break;
      }
      case '--product-code': {
        const value = requireValue(argumentsList, index, argument);
        if (!/^\d{4}$/.test(value)) {
          throw new CliError('--product-code must contain exactly four digits.');
        }
        options.productCode = value;
        index += 1;
        break;
      }
      case '--output':
        options.output = requireValue(argumentsList, index, argument);
        index += 1;
        break;
      case '--delay-min-ms': {
        const value = requireValue(argumentsList, index, argument);
        options.delayMinMs = parsePositiveInteger(value, argument);
        index += 1;
        break;
      }
      case '--delay-max-ms': {
        const value = requireValue(argumentsList, index, argument);
        options.delayMaxMs = parsePositiveInteger(value, argument);
        index += 1;
        break;
      }
      default:
        throw new CliError(`Unknown option: ${argument}`);
    }
  }

  if (options.retryFailed && options.productCode) {
    throw new CliError('--retry-failed cannot be combined with --product-code.');
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
  return `BOTZ earthenware product scraper

Usage:
  node botz-scraper.js [options]

Options:
  --dry-run              Discover and validate without product folders or downloads
  --limit N              Process the first N uncompleted selected products
  --resume               Verify completed products and continue incomplete work
  --retry-failed         Process only entries in failed-products.json
  --product-code CODE    Process one four-digit product code
  --output PATH          Override the default C:\\BOTZ output directory
  --headed               Show Chromium for debugging
  --force                Reprocess selected products and replace owned artifact files
  --delay-min-ms N       Override the minimum inter-product delay
  --delay-max-ms N       Override the maximum inter-product delay
  --help                 Show this help
`;
}
