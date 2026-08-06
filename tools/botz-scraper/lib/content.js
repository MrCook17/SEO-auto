import crypto from 'node:crypto';
import path from 'node:path';

const WINDOWS_RESERVED_NAME = /^(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$/i;
const TRACKING_PARAMETERS = new Set([
  'fbclid',
  'gclid',
  'dclid',
  'msclkid',
  'mc_cid',
  'mc_eid',
]);

const CONTENT_TYPE_EXTENSIONS = new Map([
  ['image/jpeg', '.jpg'],
  ['image/jpg', '.jpg'],
  ['image/png', '.png'],
  ['image/webp', '.webp'],
  ['image/gif', '.gif'],
  ['image/bmp', '.bmp'],
  ['image/tiff', '.tif'],
  ['image/avif', '.avif'],
  ['image/svg+xml', '.svg'],
]);

const SUPPORTED_IMAGE_EXTENSIONS = new Set([
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.gif',
  '.bmp',
  '.tif',
  '.tiff',
  '.avif',
  '.svg',
]);

export function normalizeWhitespace(value) {
  return String(value ?? '')
    .replace(/\u00a0/g, ' ')
    .replace(/[\t\r\n ]+/g, ' ')
    .trim();
}

export function parseProductHeading(heading) {
  const productName = normalizeWhitespace(heading);
  const match = /^(\d{4})\s+(.+)$/.exec(productName);
  if (!match) {
    throw new Error(
      `Product heading does not start with a four-digit code: ${productName || '(empty)'}`,
    );
  }
  return {
    productCode: match[1],
    productName,
    nameWithoutCode: match[2],
  };
}

export function sanitizeWindowsName(value, maximumLength = 180) {
  let safeName = normalizeWhitespace(value)
    .replace(/[<>:"/\\|?*\u0000-\u001f]/g, '_')
    .replace(/[. ]+$/g, '')
    .trim();

  if (!safeName) {
    safeName = 'unnamed';
  }
  if (WINDOWS_RESERVED_NAME.test(safeName)) {
    safeName = `_${safeName}`;
  }
  if (safeName.length > maximumLength) {
    safeName = safeName.slice(0, maximumLength).replace(/[. ]+$/g, '');
  }
  return safeName || 'unnamed';
}

export function makeProductFolderName(productCode, productName) {
  const withoutDuplicatedCode = normalizeWhitespace(productName).replace(
    new RegExp(`^${productCode}\\s+`),
    '',
  );
  return sanitizeWindowsName(`${productCode} ${withoutDuplicatedCode}`);
}

export function makeImageSlug(productCode, productName) {
  const withoutCode = normalizeWhitespace(productName).replace(
    new RegExp(`^${productCode}\\s+`),
    '',
  );
  const slug = withoutCode
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60)
    .replace(/-+$/g, '');
  return slug || 'product';
}

export function stableUrlSuffix(url, length = 8) {
  return crypto.createHash('sha256').update(String(url)).digest('hex').slice(0, length);
}

export function normalizeUrl(value, baseUrl) {
  const url = new URL(String(value), baseUrl);
  url.hash = '';
  return url.href;
}

export function cleanImageUrl(value, baseUrl) {
  const url = new URL(String(value), baseUrl);
  url.hash = '';
  for (const key of [...url.searchParams.keys()]) {
    if (key.toLowerCase().startsWith('utm_') || TRACKING_PARAMETERS.has(key.toLowerCase())) {
      url.searchParams.delete(key);
    }
  }
  return url.href;
}

export function dedupeImageUrls(values, baseUrl) {
  const unique = new Map();
  for (const value of values) {
    if (!value) {
      continue;
    }
    try {
      const cleaned = cleanImageUrl(value, baseUrl);
      if (!unique.has(cleaned)) {
        unique.set(cleaned, cleaned);
      }
    } catch {
      // Invalid candidates are ignored; valid candidates from the same image group remain.
    }
  }
  return [...unique.values()];
}

export function selectLargestSrcset(srcset) {
  const candidates = String(srcset ?? '')
    .split(',')
    .map((candidate) => candidate.trim())
    .filter(Boolean)
    .map((candidate) => {
      const parts = candidate.split(/\s+/);
      const descriptor = parts.at(-1);
      let score = 1;
      if (/^\d+(?:\.\d+)?w$/.test(descriptor)) {
        score = Number.parseFloat(descriptor);
      } else if (/^\d+(?:\.\d+)?x$/.test(descriptor)) {
        score = Number.parseFloat(descriptor) * 10_000;
      }
      const hasDescriptor = /^[\d.]+[wx]$/.test(descriptor);
      return {
        url: hasDescriptor ? parts.slice(0, -1).join(' ') : candidate,
        descriptor: hasDescriptor ? descriptor : '',
        score,
      };
    })
    .filter((candidate) => candidate.url);

  candidates.sort((left, right) => right.score - left.score);
  return candidates[0] ?? null;
}

export function extensionFromContentType(contentType) {
  const normalised = String(contentType ?? '').split(';', 1)[0].trim().toLowerCase();
  return CONTENT_TYPE_EXTENSIONS.get(normalised) ?? '';
}

export function extensionFromUrl(url) {
  try {
    const extension = path.posix.extname(new URL(url).pathname).toLowerCase();
    return SUPPORTED_IMAGE_EXTENSIONS.has(extension) ? extension : '';
  } catch {
    return '';
  }
}

export function detectImageExtension(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 4) {
    return '';
  }
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return '.jpg';
  }
  if (buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return '.png';
  }
  if (buffer.subarray(0, 6).toString('ascii') === 'GIF87a' || buffer.subarray(0, 6).toString('ascii') === 'GIF89a') {
    return '.gif';
  }
  if (
    buffer.subarray(0, 4).toString('ascii') === 'RIFF' &&
    buffer.subarray(8, 12).toString('ascii') === 'WEBP'
  ) {
    return '.webp';
  }
  if (buffer.subarray(0, 2).toString('ascii') === 'BM') {
    return '.bmp';
  }
  if (
    buffer.subarray(0, 4).equals(Buffer.from([0x49, 0x49, 0x2a, 0x00])) ||
    buffer.subarray(0, 4).equals(Buffer.from([0x4d, 0x4d, 0x00, 0x2a]))
  ) {
    return '.tif';
  }
  if (buffer.length >= 12 && buffer.subarray(4, 12).toString('ascii').startsWith('ftyp')) {
    const brand = buffer.subarray(8, 16).toString('ascii').toLowerCase();
    if (brand.includes('avif') || brand.includes('avis')) {
      return '.avif';
    }
  }
  const textStart = buffer.subarray(0, Math.min(buffer.length, 1_024)).toString('utf8').trimStart();
  if (/^(?:<\?xml[^>]*>\s*)?<svg\b/i.test(textStart)) {
    return '.svg';
  }
  return '';
}

export function isImageContentType(contentType) {
  return String(contentType ?? '').split(';', 1)[0].trim().toLowerCase().startsWith('image/');
}

export function extractCodeFromProductUrl(productUrl) {
  try {
    const url = new URL(productUrl);
    for (const [key, value] of url.searchParams.entries()) {
      if ((key === 'productno' || key.endsWith('[productno]')) && /^\d{4}$/.test(value)) {
        return value;
      }
    }
  } catch {
    return '';
  }
  return '';
}

function normaliseMarkdownText(value) {
  return String(value ?? '').replace(/\r\n?/g, '\n').trim();
}

function renderEntries(entries, missingText) {
  if (!Array.isArray(entries) || entries.length === 0) {
    return missingText;
  }
  const lines = [];
  for (const entry of entries) {
    const text = normaliseMarkdownText(entry?.text ?? entry);
    if (!text) {
      continue;
    }
    if (entry?.type === 'listItem') {
      lines.push(`- ${text.replace(/\n+/g, ' ')}`);
    } else {
      if (lines.length > 0 && lines.at(-1) !== '') {
        lines.push('');
      }
      lines.push(text);
      lines.push('');
    }
  }
  while (lines.at(-1) === '') {
    lines.pop();
  }
  return lines.join('\n') || missingText;
}

export function buildMarkdown(product) {
  const lines = [
    `# ${product.productName}`,
    '',
    `- Product code: ${product.productCode}`,
    `- Product name: ${product.productName}`,
    `- Category: ${product.category}`,
    `- Source URL: ${product.sourceUrl}`,
    `- Scraped at UTC: ${product.scrapedAtUtc}`,
    '',
    '## Description',
    '',
    renderEntries(product.sections.description, 'Not provided on the source page.'),
    '',
    '## Notes/Application',
    '',
    renderEntries(product.sections.notesApplication, 'Not provided on the source page.'),
    '',
    '## Properties',
    '',
    renderEntries(product.sections.properties, 'Not provided on the source page.'),
  ];

  for (const section of product.sections.additional ?? []) {
    if (!section?.heading || !Array.isArray(section.content) || section.content.length === 0) {
      continue;
    }
    lines.push('', `## ${section.heading}`, '', renderEntries(section.content, ''));
  }

  lines.push('', '## Images', '');
  if (product.images.length === 0) {
    lines.push('No product images were downloaded.');
  } else {
    product.images.forEach((image, index) => {
      lines.push(`${index + 1}. \`${image.localFile.replaceAll('\\', '/')}\``);
    });
  }
  lines.push('');
  return lines.join('\n');
}
