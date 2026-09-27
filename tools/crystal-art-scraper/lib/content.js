import crypto from 'node:crypto';

const WINDOWS_RESERVED_NAME = /^(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$/i;

export function normalizeWhitespace(value) {
  return String(value ?? '')
    .replace(/\u00a0/g, ' ')
    .replace(/[\t\r\n ]+/g, ' ')
    .trim();
}

export function sanitizeWindowsName(value, maximumLength = 180) {
  let safeName = normalizeWhitespace(value)
    .replace(/[<>:"/\\|?*\u0000-\u001f]/g, '_')
    .replace(/[. ]+$/g, '')
    .trim();
  if (!safeName) safeName = 'unnamed';
  if (WINDOWS_RESERVED_NAME.test(safeName)) safeName = `_${safeName}`;
  if (safeName.length > maximumLength) {
    safeName = safeName.slice(0, maximumLength).replace(/[. ]+$/g, '');
  }
  return safeName || 'unnamed';
}

export function makeProductFolderName(productCode, productName) {
  return sanitizeWindowsName(`${productCode} ${productName}`);
}

export function makeImageSlug(productName) {
  return (
    normalizeWhitespace(productName)
      .normalize('NFKD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 60)
      .replace(/-+$/g, '') || 'product'
  );
}

export function stableUrlSuffix(url, length = 8) {
  return crypto.createHash('sha256').update(String(url)).digest('hex').slice(0, length);
}

const ENTITIES = Object.freeze({
  amp: '&',
  apos: "'",
  gt: '>',
  hellip: '…',
  laquo: '«',
  ldquo: '“',
  lsquo: '‘',
  lt: '<',
  nbsp: ' ',
  ndash: '–',
  mdash: '—',
  quot: '"',
  raquo: '»',
  rdquo: '”',
  reg: '®',
  rsquo: '’',
  trade: '™',
});

export function decodeHtmlEntities(value) {
  return String(value ?? '').replace(
    /&(#(?:x[0-9a-f]+|\d+)|[a-z][a-z0-9]+);/gi,
    (match, entity) => {
      if (entity[0] === '#') {
        const hexadecimal = entity[1]?.toLowerCase() === 'x';
        const number = Number.parseInt(entity.slice(hexadecimal ? 2 : 1), hexadecimal ? 16 : 10);
        if (Number.isInteger(number) && number >= 0 && number <= 0x10ffff) {
          return String.fromCodePoint(number);
        }
        return match;
      }
      return ENTITIES[entity.toLowerCase()] ?? match;
    },
  );
}

export function htmlToMarkdown(html) {
  let text = String(html ?? '')
    .replace(/<!--[^]*?-->/g, '')
    .replace(/<(script|style)\b[^>]*>[^]*?<\/\1\s*>/gi, '')
    .replace(/<meta\b[^>]*>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<li\b[^>]*>/gi, '\n- ')
    .replace(/<\/li\s*>/gi, '\n')
    .replace(/<h([1-6])\b[^>]*>/gi, '\n\n### ')
    .replace(/<\/h[1-6]\s*>/gi, '\n\n')
    .replace(/<\/(?:p|div|section|ul|ol|table|tr)\s*>/gi, '\n\n')
    .replace(/<[^>]+>/g, '');

  text = decodeHtmlEntities(text)
    .replace(/\r/g, '')
    .split('\n')
    .map((line) => line.replace(/[\t ]+/g, ' ').trim())
    .join('\n')
    .replace(/\n[ \t]*-\s*\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  return text;
}

export function buildMarkdown(product) {
  const lines = [
    `# ${product.productName}`,
    '',
    `- Product code: ${product.productCode}`,
    `- Source URL: ${product.sourceUrl}`,
    `- Scraped at UTC: ${product.scrapedAtUtc}`,
    '',
    '## Product description',
    '',
    product.descriptionMarkdown || 'Not provided on the source page.',
    '',
    '## Images',
    '',
  ];
  product.images.forEach((image, index) => {
    lines.push(`${index + 1}. \`${image.localFile.replaceAll('\\', '/')}\``);
  });
  lines.push('');
  return lines.join('\n');
}
