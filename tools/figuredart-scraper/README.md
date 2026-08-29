# Figured'Art Product Scraper

This isolated Node.js workflow extracts the authoritative product-code checklist from a purchase-order PDF, discovers each product independently on the public Figured'Art UK storefront, confirms the exact Shopify variant SKU, saves listing-ready text and JSON, and downloads the official gallery images as Cromartie-compatible JPEG files at no more than 1000 x 1000px. It does not modify the BOTZ scraper or the Cromartie CMS automation.

## Architecture

```text
Purchase-order PDF
        |
        v
Position-aware manifest extraction
        |
        v
Public storefront search data (one exact-code query per PDF row)
        |
        v
Canonical product JSON + page SKU verification
        |
        v
Description / How Does It Work DOM parsing
        |
        v
Official gallery download + dedupe + resize
        |
        v
Atomic product output, state, manual-review report, summary
```

The scraper uses the public JSONP search endpoint loaded by Figured'Art's own search page. Search results are candidates only. A match is accepted only when exactly one candidate reports the requested SKU and the canonical product `.js` payload contains exactly one variant with the same SKU. Product-page JSON-LD is checked as a third source when present. Names and the purchase-order description are logged for review but never replace exact SKU matching.

## Prerequisites

- Windows 10 or 11
- Node.js 20 or newer
- Internet access to `https://uk.figuredart.com`, its Shopify CDN, and the public storefront search service
- Optional: AutoHotkey v2 for `figuredart-scraper-launcher.ahk`

Install the pinned dependencies:

```powershell
cd tools\figuredart-scraper
npm.cmd install
```

## Staged commands

Run these from `tools\figuredart-scraper` and replace the PDF path if needed:

```powershell
node figuredart-scraper.js --pdf "C:\Users\Charl\Downloads\9950 Figured Art.pdf" --manifest-only
node figuredart-scraper.js --pdf "C:\Users\Charl\Downloads\9950 Figured Art.pdf" --product-code SFA137-Y
node figuredart-scraper.js --pdf "C:\Users\Charl\Downloads\9950 Figured Art.pdf" --limit 5
node figuredart-scraper.js --pdf "C:\Users\Charl\Downloads\9950 Figured Art.pdf"
node figuredart-scraper.js --pdf "C:\Users\Charl\Downloads\9950 Figured Art.pdf" --retry-attention
node figuredart-scraper.js --pdf "C:\Users\Charl\Downloads\9950 Figured Art.pdf" --force --product-code SFA137-Y
node figuredart-scraper.js --pdf "C:\path\order.pdf" --output "D:\FiguredArt"
node figuredart-scraper.js --help
```

The default output root is `C:\FiguredArt`. `--limit N` counts queued products, so verified `SUCCESS` folders do not consume the limit.

## PDF manifest extraction

`pdfjs-dist` reads every PDF page. Text is kept with its X/Y coordinates so values are selected from the Product Code and Product Description columns rather than from unrelated quantities, prices, totals, or supplier details. Wrapped descriptions are joined within the same table row. Duplicate codes are collapsed only when their descriptions agree; conflicting duplicates fail manifest extraction rather than silently choosing one.

`pdf-manifest.json` records the PDF path, SHA-256 checksum, page count, every unique code, purchase-order description, source page, and current status.

## Product statuses

Every unique PDF code ends in one of these persisted states after a full run:

- `SUCCESS` - exact SKU verified and complete output validated
- `PARTIAL` - exact SKU verified, but description or one or more images were incomplete
- `NOT_FOUND` - no search candidate contained the exact SKU
- `AMBIGUOUS_MATCH` - multiple exact product matches or duplicate exact variants require review
- `SCRAPE_FAILED` - HTTP, redirect, data-validation, parsing, or file-processing failure

`PENDING` and `PROCESSING` are internal resumable states. A stale `PROCESSING` record is reset to `PENDING` at the next start.

## Content boundaries

The canonical product page's product Description tab and How Does It Work tab are parsed. Paragraphs, headings, and lists are retained. Label/value facts are moved into Specifications; checkbox-style kit rows are retained as What's Included. Navigation, footer content, payment/shipping tabs, reviews, recommendations, and generic site sections outside the product tabs are excluded.

Raw source HTML for both accepted tabs is kept inside `product.json` so future automation can re-interpret the supplier content without another request.

## Images

Only the canonical product JSON's official gallery array is used. This naturally excludes logos, payment graphics, review avatars, and recommendation thumbnails. Shopify transform-query variants are normalised, and duplicate binary content is removed by SHA-256.

Images are inspected with Sharp and always saved with real JPEG content and a `.jpg` extension. Existing JPEG sources within 1000 x 1000px are copied byte-for-byte; other formats are converted once, with transparent pixels flattened onto white. Larger images are auto-oriented and resized with `fit: inside`, preserving aspect ratio, and smaller images are never upscaled. The saved dimensions, conversion state, source/final content types, and source/final checksums are recorded in `product.json` and revalidated before a `SUCCESS` folder is skipped.

A rerun treats older WebP output as incomplete, replaces it with verified JPEG output, and removes only stale files recorded by the previous `product.json`. Untracked user-added files in an image folder are left alone.

## Output

```text
C:\FiguredArt\
|-- pdf-manifest.json
|-- scrape-state.json
|-- scrape-log.txt
|-- summary.json
|-- manual-review.json
|-- image-optimization.json
`-- SFA137-Y Mini Paint by numbers Travel Poster Santorini Sunrise 20x20cm already framed\
    |-- product.md
    |-- product.json
    `-- images\
        |-- SFA137-Y_mini-paint-by-numbers-travel-poster-santorini-sunrise_01.jpg
        `-- ...
```

## Retry, resume, and blocking behavior

Requests use at most three attempts with exponential backoff for timeouts, 408/425/429, and server errors. Permanent HTTP errors and redirects are not retried endlessly. Three consecutive 403/429 responses stop the batch safely; the scraper does not bypass access controls, authentication, CAPTCHAs, or rate limits.

The manifest and state are written atomically before product processing. State is saved before and after each product. A normal rerun verifies and skips valid `SUCCESS` folders. Incomplete output is repaired with deterministic filenames and partial-file writes; reusable already-valid images are not downloaded again. `Ctrl+C` stops after the current product and preserves state.

## Reports and logs

The text log records the code, PO description, search URL and candidates, matched product/URL, confirmed SKU sources, description/How Does It Work state, image counts, resize/reuse counts, output folder, warnings, errors, and final status.

`summary.json` reports total PDF products; counts for Success, Partial, Not Found, Ambiguous, Failed, and Pending; and counts of saved images over 200 KB and over 300 KB. `image-optimization.json` lists each flagged image largest-first with its product, exact relative and absolute path, byte size, readable KB size, and threshold band. KB uses 1,024 bytes, the thresholds are strictly greater-than, and the over-300 KB count is included in the over-200 KB count. `manual-review.json` lists every completed non-success item with its reason.

## PDF visual verification utility

The PDF renderer is for checking that text extraction agrees with the visible table:

```powershell
npm.cmd run render-pdf -- "C:\Users\Charl\Downloads\9950 Figured Art.pdf" ".\tmp-pdf-pages"
```

Inspect every emitted PNG before relying on a new purchase-order layout.

## Tests

Offline tests cover CLI validation, position-aware PDF row reconstruction, JSONP parsing, product-content boundaries, image URL dedupe, 1000px resizing/no-upscale behavior, completed-output validation, and Markdown output:

```powershell
npm.cmd test
```

Successful technical retrieval does not itself grant permission to republish supplier text or images. Confirm the applicable Figured'Art terms and licensing before publication.
