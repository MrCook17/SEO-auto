import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {
  buildMarkdown,
  cleanImageUrl,
  dedupeImageUrls,
  extensionFromContentType,
  makeProductFolderName,
  normalizeUrl,
  parseProductHeading,
  sanitizeWindowsName,
  selectLargestSrcset,
} from '../lib/content.js';
import { loadState, validateCompletedProduct } from '../lib/files.js';

test('parses the four-digit code without removing it from the product name', () => {
  assert.deepEqual(parseProductHeading('  9101   Glossy white  '), {
    productCode: '9101',
    productName: '9101 Glossy white',
    nameWithoutCode: 'Glossy white',
  });
  assert.throws(() => parseProductHeading('Glossy white'), /four-digit code/);
});

test('sanitises Windows names and reserved device names', () => {
  assert.equal(sanitizeWindowsName('A <B>: C. '), 'A _B__ C');
  assert.equal(sanitizeWindowsName('CON'), '_CON');
  assert.equal(makeProductFolderName('9101', '9101 Glossy white'), '9101 Glossy white');
});

test('normalises relative URLs', () => {
  assert.equal(
    normalizeUrl('/en/product?id=1#top', 'https://www.botz-glasuren.de/en/productoverview'),
    'https://www.botz-glasuren.de/en/product?id=1',
  );
});

test('removes only safe tracking parameters and deduplicates image URLs', () => {
  const base = 'https://www.botz-glasuren.de/en/productoverview';
  assert.equal(
    cleanImageUrl('/image.jpg?v=2&utm_source=test#top', base),
    'https://www.botz-glasuren.de/image.jpg?v=2',
  );
  assert.deepEqual(
    dedupeImageUrls(
      [
        '/image.jpg?v=2&utm_source=a',
        'https://www.botz-glasuren.de/image.jpg?v=2&utm_medium=b',
        '/other.png',
      ],
      base,
    ),
    [
      'https://www.botz-glasuren.de/image.jpg?v=2',
      'https://www.botz-glasuren.de/other.png',
    ],
  );
});

test('selects the largest srcset candidate', () => {
  assert.deepEqual(
    selectLargestSrcset('small.jpg 320w, medium.jpg 800w, large.jpg 1600w'),
    { url: 'large.jpg', descriptor: '1600w', score: 1600 },
  );
  assert.equal(selectLargestSrcset('one.jpg 1x, three.jpg 3x').url, 'three.jpg');
});

test('maps image Content-Types to file extensions', () => {
  assert.equal(extensionFromContentType('image/jpeg; charset=binary'), '.jpg');
  assert.equal(extensionFromContentType('image/png'), '.png');
  assert.equal(extensionFromContentType('text/html'), '');
});

test('recovers a corrupt state file without discarding it', async (context) => {
  const temporaryDirectory = await fs.mkdtemp(path.join(os.tmpdir(), 'botz-state-test-'));
  context.after(() => fs.rm(temporaryDirectory, { recursive: true, force: true }));
  const statePath = path.join(temporaryDirectory, 'scrape-state.json');
  await fs.writeFile(statePath, '{broken', 'utf8');
  const messages = [];
  const logger = { log: async (level, message) => messages.push({ level, message }) };

  const recovered = await loadState(statePath, logger);

  assert.deepEqual(recovered.state.products, {});
  assert.ok(recovered.corruptBackup.endsWith('.json'));
  assert.equal(await fs.readFile(recovered.corruptBackup, 'utf8'), '{broken');
  assert.equal(messages[0].level, 'WARNING');
});

test('marks an interrupted processing item for reprocessing', async (context) => {
  const temporaryDirectory = await fs.mkdtemp(path.join(os.tmpdir(), 'botz-interrupt-test-'));
  context.after(() => fs.rm(temporaryDirectory, { recursive: true, force: true }));
  const statePath = path.join(temporaryDirectory, 'scrape-state.json');
  await fs.writeFile(
    statePath,
    JSON.stringify({
      version: 1,
      products: { '9101': { status: 'processing' } },
    }),
    'utf8',
  );

  const loaded = await loadState(statePath);

  assert.equal(loaded.recoveredProcessingCount, 1);
  assert.equal(loaded.state.products['9101'].status, 'pending');
  assert.equal(loaded.state.products['9101'].interrupted, true);
});

test('validates an existing completed product and its non-empty images', async (context) => {
  const productDirectory = await fs.mkdtemp(path.join(os.tmpdir(), 'botz-product-test-'));
  context.after(() => fs.rm(productDirectory, { recursive: true, force: true }));
  await fs.mkdir(path.join(productDirectory, 'images'));
  await fs.writeFile(path.join(productDirectory, 'images', '9101_01.jpg'), Buffer.from([1, 2, 3]));
  const source = {
    productCode: '9101',
    productName: '9101 Glossy white',
    sourceUrl: 'https://www.botz-glasuren.de/product?productno=9101',
    warnings: [],
    images: [{ localFile: 'images/9101_01.jpg' }],
  };
  await fs.writeFile(
    path.join(productDirectory, 'source.json'),
    JSON.stringify(source),
    'utf8',
  );
  await fs.writeFile(
    path.join(productDirectory, 'product.md'),
    '# 9101 Glossy white\n\n- Product code: 9101\n',
    'utf8',
  );

  const result = await validateCompletedProduct(productDirectory, {
    productCode: '9101',
    sourceUrl: source.sourceUrl,
  });

  assert.equal(result.valid, true);
});

test('generates Markdown with preserved list boundaries and image paths', () => {
  const markdown = buildMarkdown({
    productCode: '9101',
    productName: '9101 Glossy white',
    category: 'Earthenware',
    sourceUrl: 'https://example.test/9101',
    scrapedAtUtc: '2026-08-06T00:00:00.000Z',
    sections: {
      description: [],
      notesApplication: [{ type: 'listItem', text: 'First note' }],
      properties: [{ type: 'listItem', text: 'glossy' }],
      additional: [],
    },
    images: [{ localFile: 'images\\9101_01_glossy-white.jpg' }],
  });

  assert.match(markdown, /^# 9101 Glossy white/m);
  assert.match(markdown, /## Description\n\nNot provided on the source page\./);
  assert.match(markdown, /## Notes\/Application\n\n- First note/);
  assert.match(markdown, /1\. `images\/9101_01_glossy-white\.jpg`/);
});
