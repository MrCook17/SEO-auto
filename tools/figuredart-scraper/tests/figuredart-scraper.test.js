import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import sharp from 'sharp';
import { parseArguments } from '../lib/cli.js';
import { buildMarkdown, parseProductPage } from '../lib/content.js';
import { validateCompletedProduct } from '../lib/files.js';
import {
  buildImageOptimizationReport,
  IMAGE_SIZE_THRESHOLDS,
} from '../lib/image-optimization.js';
import {
  constrainImageBuffer,
  dedupeImageSources,
  removeStaleProductImages,
} from '../lib/images.js';
import { manifestFromPositionedPages } from '../lib/pdf-manifest.js';
import { parseSearchJsonp } from '../lib/site.js';

test('requires a PDF and accepts FiguredArt product-code forms', () => {
  assert.throws(() => parseArguments([]), /--pdf is required/);
  assert.deepEqual(
    parseArguments(['--pdf', 'order.pdf', '--product-code', 'sfa137-y']),
    {
      pdf: 'order.pdf',
      output: undefined,
      productCode: 'SFA137-Y',
      limit: undefined,
      force: false,
      retryAttention: false,
      manifestOnly: false,
      delayMinMs: undefined,
      delayMaxMs: undefined,
      help: false,
    },
  );
  assert.throws(
    () => parseArguments(['--pdf', 'order.pdf', '--product-code', 'not a code']),
    /valid supplier product code/,
  );
});

test('extracts unique PDF rows by column positions and joins wrapped descriptions', () => {
  const manifest = manifestFromPositionedPages([
    {
      pageNumber: 1,
      items: [
        { text: 'Product Code', x: 70, y: 700 },
        { text: 'Product Description', x: 180, y: 700 },
        { text: 'Unit Price', x: 410, y: 700 },
        { text: 'SFA137-Y', x: 70, y: 660 },
        { text: 'Santorini Sunrise - 20x20cm canvas', x: 180, y: 660 },
        { text: 'SFA130-Y', x: 70, y: 630 },
        { text: 'Travel Poster New York Statue of Liberty - 20x20cm', x: 180, y: 630 },
        { text: 'Canvas', x: 180, y: 621 },
        { text: 'SFA129-Y', x: 70, y: 610 },
        { text: 'Travel Poster New York City - 20x20cm Framed Canvas', x: 180, y: 610 },
      ],
    },
  ]);
  assert.deepEqual(manifest, [
    {
      productCode: 'SFA137-Y',
      poDescription: 'Santorini Sunrise - 20x20cm canvas',
      pdfPage: 1,
    },
    {
      productCode: 'SFA130-Y',
      poDescription: 'Travel Poster New York Statue of Liberty - 20x20cm Canvas',
      pdfPage: 1,
    },
    {
      productCode: 'SFA129-Y',
      poDescription: 'Travel Poster New York City - 20x20cm Framed Canvas',
      pdfPage: 1,
    },
  ]);
});

test('parses search JSONP and rejects an unexpected wrapper', () => {
  const parsed = parseSearchJsonp(
    "/**/ typeof CB === 'function' && CB({\"products\":[],\"total_product\":0});",
    'CB',
  );
  assert.equal(parsed.total_product, 0);
  assert.throws(() => parseSearchJsonp('{}', 'CB'), /unrecognised JSONP/);
});

test('extracts product-only description, specifications, kit contents, and how-to structure', () => {
  const page = parseProductPage({
    pageHtml: `
      <html><head>
        <link rel="canonical" href="https://uk.figuredart.com/products/example">
        <script type="application/ld+json">{"@type":"Product","sku":"SFA137-Y"}</script>
      </head><body><main><h1>Example Product</h1>
        <div id="home" class="tab-pane">
          <p>Model: <strong>Example Product</strong><br>Method: <strong>Paint by numbers</strong><br>Size: <strong>20x20cm</strong></p>
          <p>This kit contains everything necessary to create your masterpiece:</p>
          <p><img src="checkbox.png"> 1 Numbered linen canvas</p>
          <p><img src="checkbox.png"> 3 Brushes</p>
          <p>Exclusive rights © Example Artist.</p>
        </div>
        <div id="tab1" class="tab-pane">
          <p><strong>What is Paint by Numbers?</strong></p>
          <p>1) Choose a kit.</p><p>2) Paint the numbered areas.</p>
        </div>
        <div class="reviews">Unrelated reviews</div>
      </main></body></html>`,
    productDescriptionHtml: '',
    descriptionSelectors: ['#home'],
    howItWorksSelectors: ['#tab1'],
  });
  assert.equal(page.canonicalUrl, 'https://uk.figuredart.com/products/example');
  assert.deepEqual(page.specifications, [
    { name: 'Model', value: 'Example Product' },
    { name: 'Method', value: 'Paint by numbers' },
    { name: 'Size', value: '20x20cm' },
  ]);
  assert.deepEqual(page.whatsIncluded, ['1 Numbered linen canvas', '3 Brushes']);
  assert.match(page.description[0].text, /contains everything necessary/);
  assert.equal(page.howItWorks[0].type, 'heading');
  assert.equal(page.howItWorks[1].type, 'listItem');
  assert.deepEqual(page.jsonLdSkus, ['SFA137-Y']);
  assert.doesNotMatch(JSON.stringify(page), /Unrelated reviews/);
});

test('deduplicates image variants while retaining versioned official sources', () => {
  assert.deepEqual(
    dedupeImageSources(
      [
        '//cdn.shopify.com/files/image.jpg?v=2&width=500',
        'https://cdn.shopify.com/files/image.jpg?width=1000&v=2',
        '/files/other.png',
      ],
      'https://uk.figuredart.com',
    ),
    [
      'https://cdn.shopify.com/files/image.jpg?v=2',
      'https://uk.figuredart.com/files/other.png',
    ],
  );
});

test('creates JPEG output, resizes large images, and does not upscale smaller images', async () => {
  const large = await sharp({
    create: { width: 1600, height: 1200, channels: 3, background: '#336699' },
  })
    .jpeg()
    .toBuffer();
  const resized = await constrainImageBuffer(large, 1_000);
  assert.equal(resized.resized, true);
  assert.equal(resized.converted, false);
  assert.equal(resized.format, 'jpeg');
  assert.equal(resized.width, 1_000);
  assert.equal(resized.height, 750);

  const small = await sharp({
    create: { width: 800, height: 600, channels: 3, background: '#663399' },
  })
    .png()
    .toBuffer();
  const unchanged = await constrainImageBuffer(small, 1_000);
  assert.equal(unchanged.resized, false);
  assert.equal(unchanged.converted, true);
  assert.equal(unchanged.format, 'jpeg');
  assert.equal(unchanged.width, 800);
  assert.equal(unchanged.height, 600);
  assert.notEqual(Buffer.compare(small, unchanged.buffer), 0);
});

test('removes only stale images recorded by the previous product output', async (context) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'figuredart-test-'));
  context.after(() => fs.rm(directory, { recursive: true, force: true }));
  const imagesDirectory = path.join(directory, 'images');
  await fs.mkdir(imagesDirectory);
  await fs.writeFile(path.join(imagesDirectory, 'old.webp'), 'old');
  await fs.writeFile(path.join(imagesDirectory, 'current.jpg'), 'current');
  await fs.writeFile(path.join(imagesDirectory, 'user-note.txt'), 'keep');

  const removed = await removeStaleProductImages({
    previousImages: [
      { localFile: 'images/old.webp' },
      { localFile: 'images/current.jpg' },
      { localFile: '../outside.webp' },
    ],
    currentImages: [{ localFile: 'images/current.jpg' }],
    productDirectory: directory,
    productCode: 'SFA137-Y',
  });
  assert.equal(removed, 1);
  await assert.rejects(fs.stat(path.join(imagesDirectory, 'old.webp')));
  assert.equal((await fs.stat(path.join(imagesDirectory, 'current.jpg'))).isFile(), true);
  assert.equal((await fs.stat(path.join(imagesDirectory, 'user-note.txt'))).isFile(), true);
});

test('validates a completed product including image dimensions and checksum', async (context) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'figuredart-test-'));
  context.after(() => fs.rm(directory, { recursive: true, force: true }));
  await fs.mkdir(path.join(directory, 'images'));
  const image = await sharp({
    create: { width: 1000, height: 750, channels: 3, background: '#abcdef' },
  })
    .jpeg()
    .toBuffer();
  const imagePath = path.join(directory, 'images', 'SFA137-Y_01.jpg');
  await fs.writeFile(imagePath, image);
  const { createHash } = await import('node:crypto');
  const checksum = createHash('sha256').update(image).digest('hex');
  const product = {
    status: 'SUCCESS',
    productCode: 'SFA137-Y',
    productName: 'Santorini Sunrise',
    canonicalUrl: 'https://uk.figuredart.com/products/example',
    images: [{ localFile: 'images/SFA137-Y_01.jpg', sha256: checksum }],
  };
  await fs.writeFile(
    path.join(directory, 'product.json'),
    JSON.stringify(product),
    'utf8',
  );
  await fs.writeFile(
    path.join(directory, 'product.md'),
    '# Product\n\nProduct Code: SFA137-Y\nName: Santorini Sunrise\n',
    'utf8',
  );
  const result = await validateCompletedProduct(directory, { productCode: 'SFA137-Y' });
  assert.equal(result.valid, true);

  const webp = await sharp(image).webp().toBuffer();
  const webpPath = path.join(directory, 'images', 'SFA137-Y_01.webp');
  await fs.writeFile(webpPath, webp);
  product.images = [{ localFile: 'images/SFA137-Y_01.webp' }];
  await fs.writeFile(
    path.join(directory, 'product.json'),
    JSON.stringify(product),
    'utf8',
  );
  const incompatible = await validateCompletedProduct(directory, {
    productCode: 'SFA137-Y',
  });
  assert.equal(incompatible.valid, false);
  assert.match(incompatible.reason, /not saved as \.jpg/i);
});

test('reports exact images over 200 KB and 300 KB, largest first', async (context) => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'figuredart-report-test-'));
  context.after(() => fs.rm(directory, { recursive: true, force: true }));
  const productDirectory = path.join(directory, 'SFA137-Y Santorini Sunrise');
  await fs.mkdir(path.join(productDirectory, 'images'), { recursive: true });
  await fs.writeFile(
    path.join(productDirectory, 'images', 'small.jpg'),
    Buffer.alloc(IMAGE_SIZE_THRESHOLDS.over200Kb),
  );
  await fs.writeFile(
    path.join(productDirectory, 'images', 'medium.jpg'),
    Buffer.alloc(IMAGE_SIZE_THRESHOLDS.over200Kb + 1),
  );
  await fs.writeFile(
    path.join(productDirectory, 'images', 'large.jpg'),
    Buffer.alloc(IMAGE_SIZE_THRESHOLDS.over300Kb + 1),
  );
  await fs.writeFile(
    path.join(productDirectory, 'product.json'),
    JSON.stringify({
      productCode: 'SFA137-Y',
      productName: 'Santorini Sunrise',
      images: [
        { localFile: 'images/small.jpg' },
        { localFile: 'images/medium.jpg' },
        { localFile: 'images/large.jpg' },
        { localFile: '../outside.jpg' },
      ],
    }),
  );

  const report = await buildImageOptimizationReport({
    manifest: { products: [{ productCode: 'SFA137-Y' }] },
    state: {
      products: {
        'SFA137-Y': { folderName: 'SFA137-Y Santorini Sunrise' },
      },
    },
    outputDirectory: directory,
  });
  assert.deepEqual(report.counts, { over200Kb: 2, over300Kb: 1 });
  assert.deepEqual(
    report.images.map((image) => [image.relativePath, image.thresholdBand]),
    [
      ['SFA137-Y Santorini Sunrise/images/large.jpg', 'OVER_300_KB'],
      ['SFA137-Y Santorini Sunrise/images/medium.jpg', 'OVER_200_KB'],
    ],
  );
});

test('generates Markdown only for populated content sections', () => {
  const markdown = buildMarkdown({
    productCode: 'RFA013',
    productName: 'Lavender Wood Slice',
    canonicalUrl: 'https://uk.figuredart.com/products/lavender',
    poDescription: 'Lavender - 30cm wood slice',
    status: 'SUCCESS',
    description: [{ type: 'paragraph', text: 'A wooden painting kit.' }],
    howItWorks: [],
    specifications: [{ name: 'Size', value: '30cm' }],
    matchedVariant: { options: [] },
    whatsIncluded: ['Wood slice'],
    additionalInformation: [],
    images: [{ localFile: 'images/RFA013_01.jpg' }],
    warnings: [],
  });
  assert.match(markdown, /## Description/);
  assert.match(markdown, /## Specifications/);
  assert.match(markdown, /## What's Included/);
  assert.doesNotMatch(markdown, /## How Does It Work/);
  assert.doesNotMatch(markdown, /## Scrape Warnings/);
});
