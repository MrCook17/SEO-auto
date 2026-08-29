import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as pdfjs from 'pdfjs-dist/legacy/build/pdf.mjs';

const PRODUCT_CODE_PATTERN = /^[A-Z]{2,8}\d{2,8}(?:-[A-Z0-9]+)?$/i;

function normalizeWhitespace(value) {
  return String(value ?? '')
    .replace(/\u00a0/g, ' ')
    .replace(/[\t\r\n ]+/g, ' ')
    .trim();
}

function groupItemsIntoLines(items, tolerance = 2) {
  const lines = [];
  for (const item of [...items].sort((left, right) => right.y - left.y || left.x - right.x)) {
    if (!normalizeWhitespace(item.text)) continue;
    let line = lines.find((candidate) => Math.abs(candidate.y - item.y) <= tolerance);
    if (!line) {
      line = { y: item.y, items: [] };
      lines.push(line);
    }
    line.items.push(item);
    line.y = line.items.reduce((total, current) => total + current.y, 0) / line.items.length;
  }
  for (const line of lines) line.items.sort((left, right) => left.x - right.x);
  return lines.sort((left, right) => right.y - left.y);
}

function findColumnX(items, label) {
  const exact = items.find(
    (item) => normalizeWhitespace(item.text).toLowerCase() === label.toLowerCase(),
  );
  if (exact) return exact.x;
  const expectedTokens = label.toLowerCase().split(/\s+/);
  for (const line of groupItemsIntoLines(items)) {
    const tokens = line.items
      .map((item) => ({ item, text: normalizeWhitespace(item.text).toLowerCase() }))
      .filter((entry) => entry.text);
    for (let start = 0; start <= tokens.length - expectedTokens.length; start += 1) {
      const matches = expectedTokens.every(
        (token, offset) => tokens[start + offset].text === token,
      );
      if (matches) return tokens[start].item.x;
    }
  }
  return Number.NaN;
}

function joinDescriptionItems(items) {
  const lines = groupItemsIntoLines(items, 1.5);
  return normalizeWhitespace(
    lines
      .map((line) => line.items.map((item) => normalizeWhitespace(item.text)).join(' '))
      .join(' '),
  );
}

export function manifestFromPositionedPages(pages) {
  const extractedRows = [];

  for (const page of pages) {
    const items = page.items.filter((item) => normalizeWhitespace(item.text));
    const codeColumnX = findColumnX(items, 'Product Code');
    const descriptionColumnX = findColumnX(items, 'Product Description');
    const priceColumnX = findColumnX(items, 'Unit Price');
    if (![codeColumnX, descriptionColumnX, priceColumnX].every(Number.isFinite)) {
      throw new Error(`Page ${page.pageNumber} is missing a required purchase-order column heading.`);
    }

    const codeItems = items
      .filter(
        (item) =>
          PRODUCT_CODE_PATTERN.test(normalizeWhitespace(item.text)) &&
          Math.abs(item.x - codeColumnX) < 24,
      )
      .sort((left, right) => right.y - left.y);

    for (let index = 0; index < codeItems.length; index += 1) {
      const current = codeItems[index];
      const next = codeItems[index + 1];
      const upperY = current.y + 2;
      const lowerY = next ? next.y + 2 : current.y - 24;
      const descriptionItems = items.filter(
        (item) =>
          item.y <= upperY &&
          item.y > lowerY &&
          item.x >= descriptionColumnX - 8 &&
          item.x < priceColumnX - 8,
      );
      const description = joinDescriptionItems(descriptionItems);
      if (!description) {
        throw new Error(
          `No purchase-order description was found for ${normalizeWhitespace(current.text)} on page ${page.pageNumber}.`,
        );
      }
      extractedRows.push({
        productCode: normalizeWhitespace(current.text).toUpperCase(),
        poDescription: description,
        pdfPage: page.pageNumber,
      });
    }
  }

  if (extractedRows.length === 0) {
    throw new Error('No product codes were found in the purchase-order table.');
  }

  const unique = new Map();
  for (const row of extractedRows) {
    const existing = unique.get(row.productCode);
    if (existing && existing.poDescription !== row.poDescription) {
      throw new Error(
        `Product code ${row.productCode} has conflicting purchase-order descriptions.`,
      );
    }
    if (!existing) unique.set(row.productCode, row);
  }
  return [...unique.values()];
}

export async function extractPdfManifest(pdfPath) {
  const absolutePath = path.resolve(pdfPath);
  const buffer = await fs.readFile(absolutePath);
  const loadingTask = pdfjs.getDocument({
    data: new Uint8Array(buffer),
    disableWorker: true,
    isEvalSupported: false,
    standardFontDataUrl:
      path.resolve(
        path.dirname(fileURLToPath(import.meta.url)),
        '..',
        'node_modules',
        'pdfjs-dist',
        'standard_fonts',
      ).replaceAll('\\', '/') + '/',
  });
  const document = await loadingTask.promise;
  const pageCount = document.numPages;
  const pages = [];
  try {
    for (let pageNumber = 1; pageNumber <= pageCount; pageNumber += 1) {
      const page = await document.getPage(pageNumber);
      const content = await page.getTextContent({ includeMarkedContent: false });
      pages.push({
        pageNumber,
        items: content.items
          .filter((item) => typeof item.str === 'string')
          .map((item) => ({
            text: item.str,
            x: Number(item.transform?.[4] ?? 0),
            y: Number(item.transform?.[5] ?? 0),
            width: Number(item.width ?? 0),
            height: Number(item.height ?? 0),
          })),
      });
    }
  } finally {
    await document.destroy();
  }

  const products = manifestFromPositionedPages(pages).map((product, index) => ({
    sequence: index + 1,
    ...product,
    status: 'PENDING',
  }));
  const stat = await fs.stat(absolutePath);
  return {
    version: 1,
    sourcePdf: absolutePath,
    sourcePdfBytes: stat.size,
    sourcePdfSha256: crypto.createHash('sha256').update(buffer).digest('hex'),
    pdfPageCount: pageCount,
    extractedAtUtc: new Date().toISOString(),
    uniqueProductCount: products.length,
    products,
  };
}
