import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import sharp from 'sharp';
import { parseArguments } from '../lib/cli.js';
import { htmlToMarkdown, makeProductFolderName } from '../lib/content.js';
import { readProductCodes } from '../lib/files.js';
import { convertToCappedJpeg } from '../lib/images.js';
import { findProductByCode } from '../lib/site.js';

test('CLI accepts list-oriented and one-product options', () => {
  assert.deepEqual(parseArguments(['--input', 'codes.txt', '--limit', '2', '--force']), {
    input: 'codes.txt',
    output: undefined,
    productCode: undefined,
    limit: 2,
    force: true,
    retryFailed: false,
    resume: false,
    help: false,
    delayMinMs: undefined,
    delayMaxMs: undefined,
  });
  assert.equal(
    parseArguments(['--product-code', 'CAFGR-34GEN138']).productCode,
    'CAFGR-34GEN138',
  );
});

test('input file ignores comments, blanks, and case-insensitive duplicates', async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'crystal-art-codes-'));
  const inputPath = path.join(directory, 'codes.txt');
  try {
    await fs.writeFile(
      inputPath,
      '# codes\nCAFGR-34GEN138\n\nabc-123\ncafgr-34gen138\n',
      'utf8',
    );
    const result = await readProductCodes(inputPath);
    assert.deepEqual(result.codes, ['CAFGR-34GEN138', 'abc-123']);
    assert.deepEqual(result.duplicates, ['cafgr-34gen138']);
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
});

test('HTML description becomes readable Markdown without discarding list items', () => {
  const markdown = htmlToMarkdown(
    '<section><p>Hello <strong>Crystal Art&reg;</strong>.</p><ul><li>Tray</li><li>Wax &amp; pen</li></ul></section>',
  );
  assert.match(markdown, /Hello Crystal Art®\./);
  assert.match(markdown, /- Tray/);
  assert.match(markdown, /- Wax & pen/);
});

test('Windows product folders retain the code while removing unsafe characters', () => {
  assert.equal(
    makeProductFolderName('ABC-1', 'Bear: Red/Green?'),
    'ABC-1 Bear_ Red_Green_',
  );
});

test('search uses the first result and verifies its exact variant SKU', async () => {
  const requests = [];
  const mockFetch = async (url) => {
    requests.push(String(url));
    if (String(url).includes('/search/suggest.json')) {
      return new Response(
        JSON.stringify({
          resources: {
            results: {
              products: [
                {
                  title: 'Festive Bear',
                  url: '/products/festive-bear?_pos=1&_sid=test&_ss=r',
                },
              ],
            },
          },
        }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      );
    }
    return new Response(
      JSON.stringify({
        title: 'Festive Bear',
        description: '<p>Bear description</p>',
        variants: [{ sku: 'CAFGR-34GEN138' }],
        images: ['//cdn.example.test/bear.jpg'],
      }),
      { status: 200, headers: { 'content-type': 'application/json' } },
    );
  };
  const logger = { log: async () => {} };
  const config = {
    baseUrl: 'https://craftbuddyltd.co.uk',
    maximumRetries: 1,
    requestTimeoutMs: 1_000,
    retryBaseDelayMs: 1,
    userAgent: 'test',
  };
  const product = await findProductByCode('CAFGR-34GEN138', config, logger, mockFetch);
  assert.equal(product.productName, 'Festive Bear');
  assert.equal(product.sourceUrl, 'https://craftbuddyltd.co.uk/products/festive-bear');
  assert.equal(product.imageUrls[0], 'https://cdn.example.test/bear.jpg');
  assert.match(requests[0], /resources%5Btype%5D=product/);
  assert.equal(requests[1], 'https://craftbuddyltd.co.uk/products/festive-bear.js');
});

test('image conversion always emits a JPEG strictly below the configured cap', async () => {
  const noise = Buffer.alloc(1_200 * 1_200 * 3);
  for (let index = 0; index < noise.length; index += 1) noise[index] = index % 251;
  const png = await sharp(noise, { raw: { width: 1_200, height: 1_200, channels: 3 } })
    .png({ compressionLevel: 0 })
    .toBuffer();
  const result = await convertToCappedJpeg(png, {
    maximumImageBytes: 50_000,
    resizeStartPixels: 1_000,
  });
  assert.equal(result.buffer[0], 0xff);
  assert.equal(result.buffer[1], 0xd8);
  assert.ok(result.buffer.length < 50_000);
  assert.ok(Math.max(result.width, result.height) <= 1_000);
});
