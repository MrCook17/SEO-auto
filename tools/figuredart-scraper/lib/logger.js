import fs from 'node:fs/promises';
import path from 'node:path';

export class Logger {
  constructor(logPath) {
    this.logPath = logPath;
  }

  static async create(outputDirectory) {
    await fs.mkdir(outputDirectory, { recursive: true });
    const logger = new Logger(path.join(outputDirectory, 'scrape-log.txt'));
    await fs.appendFile(logger.logPath, '', 'utf8');
    return logger;
  }

  async log(level, message, details = null) {
    const suffix = details ? ` | ${JSON.stringify(details)}` : '';
    const entry = `[${new Date().toISOString()}] [${level}] ${message}${suffix}`;
    console.log(entry);
    await fs.appendFile(this.logPath, `${entry}\n`, 'utf8');
  }
}
