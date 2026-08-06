#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildConfig, EXIT_CODES } from './lib/config.js';
import { CliError, parseArguments, usageText } from './lib/cli.js';
import {
  ConfigurationError,
  DiscoveryError,
  runScraper,
} from './lib/run.js';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  let options;
  try {
    options = parseArguments(process.argv.slice(2));
  } catch (error) {
    if (error instanceof CliError) {
      console.error(`Configuration error: ${error.message}\n`);
      console.error(usageText());
      return EXIT_CODES.configurationError;
    }
    throw error;
  }

  if (options.help) {
    console.log(usageText());
    return EXIT_CODES.success;
  }

  let chromium;
  try {
    ({ chromium } = await import('playwright'));
  } catch (error) {
    console.error(
      `Playwright is not installed. Run "npm install" in ${scriptDirectory}. ${error.message}`,
    );
    return EXIT_CODES.configurationError;
  }

  let selectors;
  try {
    selectors = JSON.parse(
      await fs.readFile(path.join(scriptDirectory, 'selectors.json'), 'utf8'),
    );
  } catch (error) {
    console.error(`selectors.json could not be loaded: ${error.message}`);
    return EXIT_CODES.configurationError;
  }

  const config = buildConfig(options);
  try {
    const result = await runScraper({ chromium, selectors, options, config });
    return result.exitCode;
  } catch (error) {
    if (error instanceof DiscoveryError) {
      console.error(`Discovery failed: ${error.message}`);
      return EXIT_CODES.discoveryFailure;
    }
    if (error instanceof ConfigurationError || error instanceof CliError) {
      console.error(`Configuration error: ${error.message}`);
      return EXIT_CODES.configurationError;
    }
    console.error(`Unexpected scraper failure: ${error.stack ?? error.message}`);
    return EXIT_CODES.productFailure;
  }
}

process.exitCode = await main();
