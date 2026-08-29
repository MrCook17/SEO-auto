#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArguments, usageText, CliError } from './lib/cli.js';
import { buildConfig, EXIT_CODES } from './lib/config.js';
import {
  ConfigurationError,
  ManifestError,
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

  let siteConfig;
  try {
    siteConfig = JSON.parse(
      await fs.readFile(path.join(scriptDirectory, 'site-config.json'), 'utf8'),
    );
  } catch (error) {
    console.error(`site-config.json could not be loaded: ${error.message}`);
    return EXIT_CODES.configurationError;
  }

  try {
    const result = await runScraper({ options, config: buildConfig(options), siteConfig });
    return result.exitCode;
  } catch (error) {
    if (error instanceof ManifestError) {
      console.error(`PDF manifest extraction failed: ${error.message}`);
      return EXIT_CODES.manifestFailure;
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
