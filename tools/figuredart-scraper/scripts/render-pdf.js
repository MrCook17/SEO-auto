#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { createCanvas, DOMMatrix, ImageData, Path2D } from '@napi-rs/canvas';

globalThis.DOMMatrix ??= DOMMatrix;
globalThis.ImageData ??= ImageData;
globalThis.Path2D ??= Path2D;

const pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
const input = process.argv[2];
const outputDirectory = process.argv[3];
const singlePage = process.argv[4] === '--single-page' ? Number(process.argv[5]) : 0;
if (!input || !outputDirectory) {
  console.error('Usage: node scripts/render-pdf.js PDF_PATH OUTPUT_DIRECTORY');
  process.exitCode = 2;
} else {
  const sourceBuffer = await fs.readFile(path.resolve(input));
  const standardFontDataUrl =
    path.resolve(
      path.dirname(fileURLToPath(import.meta.url)),
      '..',
      'node_modules',
      'pdfjs-dist',
      'standard_fonts',
    ).replaceAll('\\', '/') + '/';
  const openDocument = async () =>
    pdfjs.getDocument({
      data: new Uint8Array(sourceBuffer),
      disableWorker: true,
      isEvalSupported: false,
      standardFontDataUrl,
    }).promise;
  await fs.mkdir(path.resolve(outputDirectory), { recursive: true });
  const renderPage = async (pageNumber) => {
    const document = await openDocument();
    try {
      if (!Number.isInteger(pageNumber) || pageNumber < 1 || pageNumber > document.numPages) {
        throw new Error(`Invalid page number ${pageNumber}.`);
      }
      const page = await document.getPage(pageNumber);
      const viewport = page.getViewport({ scale: 2 });
      const canvas = createCanvas(Math.ceil(viewport.width), Math.ceil(viewport.height));
      const context = canvas.getContext('2d');
      await page.render({
        canvasContext: context,
        viewport,
        canvas,
        annotationMode: pdfjs.AnnotationMode.DISABLE,
      }).promise;
      const outputPath = path.join(
        path.resolve(outputDirectory),
        `page-${String(pageNumber).padStart(2, '0')}.png`,
      );
      await fs.writeFile(outputPath, canvas.toBuffer('image/png'));
      console.log(outputPath);
    } finally {
      await document.destroy();
    }
  };

  if (singlePage) {
    await renderPage(singlePage);
  } else {
    const inspectionDocument = await openDocument();
    const pageCount = inspectionDocument.numPages;
    await inspectionDocument.destroy();
    const runFile = promisify(execFile);
    for (let pageNumber = 1; pageNumber <= pageCount; pageNumber += 1) {
      const result = await runFile(process.execPath, [
        fileURLToPath(import.meta.url),
        path.resolve(input),
        path.resolve(outputDirectory),
        '--single-page',
        String(pageNumber),
      ]);
      process.stdout.write(result.stdout);
      process.stderr.write(result.stderr);
    }
  }
}
