import path from 'node:path';
import { load } from 'cheerio';

export function normalizeWhitespace(value) {
  return String(value ?? '')
    .replace(/\u00a0/g, ' ')
    .replace(/[\t\r\n ]+/g, ' ')
    .trim();
}

function textWithBreaks($, element) {
  const clone = $(element).clone();
  clone.find('script, style, noscript').remove();
  clone.find('br').replaceWith('\n');
  return clone
    .text()
    .split('\n')
    .map(normalizeWhitespace)
    .filter(Boolean);
}

function findFirst($, selectors) {
  for (const selector of selectors) {
    const element = $(selector).first();
    if (element.length) return element;
  }
  return null;
}

function directContentElements($, container) {
  const output = [];
  const visit = (element) => {
    const tag = element.tagName?.toLowerCase();
    if (['h1', 'h2', 'h3', 'h4', 'p', 'ul', 'ol', 'table'].includes(tag)) {
      output.push(element);
      return;
    }
    $(element)
      .children()
      .each((_, child) => visit(child));
  };
  container.children().each((_, child) => visit(child));
  return output;
}

function specificationFromLine(line) {
  const match = /^([^:]{2,60}):\s*(.+)$/.exec(normalizeWhitespace(line));
  if (!match) return null;
  return { name: normalizeWhitespace(match[1]), value: normalizeWhitespace(match[2]) };
}

function pushUnique(list, value, key = (entry) => JSON.stringify(entry)) {
  if (!value || !key(value)) return;
  if (!list.some((existing) => key(existing) === key(value))) list.push(value);
}

function parseDescriptionContainer($, container) {
  const description = [];
  const specifications = [];
  const whatsIncluded = [];
  const additionalInformation = [];
  let includedMode = false;

  for (const element of directContentElements($, container)) {
    const tag = element.tagName.toLowerCase();
    if (/^h[1-4]$/.test(tag)) {
      const text = normalizeWhitespace($(element).text());
      if (text) description.push({ type: 'heading', text });
      continue;
    }
    if (tag === 'ul' || tag === 'ol') {
      const items = $(element)
        .find(':scope > li')
        .toArray()
        .map((item) => normalizeWhitespace($(item).text()))
        .filter(Boolean);
      for (const text of items) {
        if (includedMode) pushUnique(whatsIncluded, text, String);
        else description.push({ type: 'listItem', text });
      }
      continue;
    }
    if (tag === 'table') {
      $(element)
        .find('tr')
        .each((_, row) => {
          const cells = $(row)
            .find('th,td')
            .toArray()
            .map((cell) => normalizeWhitespace($(cell).text()))
            .filter(Boolean);
          if (cells.length >= 2) {
            pushUnique(specifications, { name: cells[0], value: cells.slice(1).join(' | ') });
          }
        });
      continue;
    }

    const lines = textWithBreaks($, element);
    if (lines.length === 0) continue;
    const pairs = lines.map(specificationFromLine).filter(Boolean);
    if (pairs.length >= Math.max(1, Math.ceil(lines.length * 0.6))) {
      for (const pair of pairs) pushUnique(specifications, pair);
      const unmatched = lines.filter((line) => !specificationFromLine(line));
      for (const text of unmatched) description.push({ type: 'paragraph', text });
      continue;
    }

    const text = normalizeWhitespace(lines.join(' '));
    const hasInlineImage = $(element).find('img').length > 0;
    if (/contains (?:everything|all|the following|the necessary materials|everything necessary)/i.test(text)) {
      description.push({ type: 'paragraph', text });
      includedMode = true;
      continue;
    }
    if (/exclusive rights|all rights reserved|copyright|\bwww\./i.test(text)) {
      pushUnique(additionalInformation, { type: 'paragraph', text });
      includedMode = false;
      continue;
    }
    if (includedMode && hasInlineImage) {
      pushUnique(whatsIncluded, text, String);
      continue;
    }
    if (includedMode && /^\d+\s+/.test(text)) {
      pushUnique(whatsIncluded, text, String);
      continue;
    }
    includedMode = false;
    description.push({ type: 'paragraph', text });
  }

  return { description, specifications, whatsIncluded, additionalInformation };
}

function parseGenericContainer($, container) {
  const entries = [];
  for (const element of directContentElements($, container)) {
    const tag = element.tagName.toLowerCase();
    if (/^h[1-4]$/.test(tag)) {
      const text = normalizeWhitespace($(element).text());
      if (text) entries.push({ type: 'heading', text });
      continue;
    }
    if (tag === 'ul' || tag === 'ol') {
      $(element)
        .find(':scope > li')
        .each((_, item) => {
          const text = normalizeWhitespace($(item).text());
          if (text) entries.push({ type: 'listItem', text });
        });
      continue;
    }
    if (tag === 'table') continue;
    const text = normalizeWhitespace(textWithBreaks($, element).join(' '));
    if (!text) continue;
    const strongText = normalizeWhitespace($(element).find('strong').first().text());
    if (strongText === text && text.length <= 120) {
      entries.push({ type: 'heading', text });
    } else if (/^\d+[).]\s+/.test(text)) {
      entries.push({ type: 'listItem', text });
    } else {
      entries.push({ type: 'paragraph', text });
    }
  }
  return entries;
}

function jsonLdProductSkus($) {
  const skus = new Set();
  $('script[type="application/ld+json"]').each((_, element) => {
    try {
      const parsed = JSON.parse($(element).text());
      const visit = (value) => {
        if (!value || typeof value !== 'object') return;
        if (typeof value.sku === 'string') skus.add(value.sku.trim().toUpperCase());
        for (const nested of Object.values(value)) {
          if (nested && typeof nested === 'object') visit(nested);
        }
      };
      visit(parsed);
    } catch {
      // A malformed unrelated JSON-LD block does not invalidate valid product data.
    }
  });
  return [...skus];
}

export function parseProductPage({
  pageHtml,
  productDescriptionHtml,
  descriptionSelectors,
  howItWorksSelectors,
}) {
  const $ = load(pageHtml);
  let descriptionContainer = findFirst($, descriptionSelectors);
  let descriptionSource = 'product-page';
  let fallback$;
  if (!descriptionContainer || !normalizeWhitespace(descriptionContainer.text())) {
    fallback$ = load(`<div id="description-fallback">${productDescriptionHtml ?? ''}</div>`);
    descriptionContainer = fallback$('#description-fallback');
    descriptionSource = 'product-json-fallback';
  }
  const description = parseDescriptionContainer(
    fallback$ ?? $,
    descriptionContainer,
  );
  const howContainer = findFirst($, howItWorksSelectors);
  const howItWorks = howContainer ? parseGenericContainer($, howContainer) : [];
  const canonicalUrl = $('link[rel="canonical"]').first().attr('href') ?? '';
  const pageTitle = normalizeWhitespace($('main h1').first().text() || $('h1').first().text());
  return {
    canonicalUrl,
    pageTitle,
    descriptionSource,
    ...description,
    howItWorks,
    rawDescriptionHtml: descriptionContainer.html() ?? '',
    rawHowItWorksHtml: howContainer?.html() ?? '',
    jsonLdSkus: jsonLdProductSkus($),
  };
}

function renderEntries(entries) {
  const lines = [];
  for (const entry of entries ?? []) {
    const text = normalizeWhitespace(entry?.text ?? entry);
    if (!text) continue;
    if (entry?.type === 'heading') {
      if (lines.length && lines.at(-1) !== '') lines.push('');
      lines.push(`### ${text}`, '');
    } else if (entry?.type === 'listItem') {
      lines.push(`- ${text}`);
    } else {
      if (lines.length && lines.at(-1) !== '') lines.push('');
      lines.push(text, '');
    }
  }
  while (lines.at(-1) === '') lines.pop();
  return lines;
}

export function buildMarkdown(product) {
  const lines = [
    '# Product',
    '',
    `Product Code: ${product.productCode}`,
    `Name: ${product.productName}`,
    `Source URL: ${product.canonicalUrl}`,
    `Purchase Order Description: ${product.poDescription}`,
    `Final Status: ${product.status}`,
  ];
  if (product.description?.length) {
    lines.push('', '## Description', '', ...renderEntries(product.description));
  }
  if (product.howItWorks?.length) {
    lines.push('', '## How Does It Work?', '', ...renderEntries(product.howItWorks));
  }
  if (product.specifications?.length || product.matchedVariant?.options?.length) {
    lines.push('', '## Specifications', '');
    for (const specification of product.specifications ?? []) {
      lines.push(`- ${specification.name}: ${specification.value}`);
    }
    for (const option of product.matchedVariant?.options ?? []) {
      lines.push(`- ${option.name}: ${option.value}`);
    }
  }
  if (product.whatsIncluded?.length) {
    lines.push('', "## What's Included", '');
    for (const item of product.whatsIncluded) lines.push(`- ${normalizeWhitespace(item)}`);
  }
  if (product.additionalInformation?.length) {
    lines.push(
      '',
      '## Additional Product Information',
      '',
      ...renderEntries(product.additionalInformation),
    );
  }
  if (product.images?.length) {
    lines.push('', '## Images', '');
    product.images.forEach((image, index) => {
      lines.push(`${index + 1}. \`${image.localFile.replaceAll('\\', '/')}\``);
    });
  }
  if (product.warnings?.length) {
    lines.push('', '## Scrape Warnings', '');
    for (const warning of product.warnings) lines.push(`- ${warning}`);
  }
  lines.push('');
  return lines.join('\n');
}

export function makeImageSlug(productName) {
  const slug = normalizeWhitespace(productName)
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60)
    .replace(/-+$/g, '');
  return slug || 'product';
}

export function extensionForFormat(format) {
  return new Map([
    ['jpeg', '.jpg'],
    ['png', '.png'],
    ['webp', '.webp'],
    ['gif', '.gif'],
    ['avif', '.avif'],
    ['tiff', '.tif'],
  ]).get(String(format ?? '').toLowerCase()) ?? path.extname(String(format ?? ''));
}
