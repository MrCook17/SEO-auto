#!/usr/bin/env node

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArguments, usageText } from './lib/cli.js';
import { buildConfig, EXIT_CODES } from './lib/config.js';
import { ConfigurationError, runScraper } from './lib/run.js';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  let options;
  try {
    options = parseArguments(process.argv.slice(2));
  } catch (error) {
    console.error(`Configuration error: ${error.message}\n`);
    console.error(usageText());
    return EXIT_CODES.configurationError;
  }

  if (options.help) {
    console.log(usageText());
    return EXIT_CODES.success;
  }

  try {
    const config = buildConfig(options, scriptDirectory);
    const result = await runScraper({ options, config });
    return result.exitCode;
  } catch (error) {
    if (error instanceof ConfigurationError) {
      console.error(`Configuration error: ${error.message}`);
      return EXIT_CODES.configurationError;
    }
    console.error(`Unexpected scraper failure: ${error.stack ?? error.message}`);
    return EXIT_CODES.productFailure;
  }
}

process.exitCode = await main();
