# BOTZ Earthenware Product Scraper

This isolated tool uses Node.js and Playwright to discover the public BOTZ earthenware catalogue, save a manifest, extract structured product text, and download product images beneath `C:\BOTZ`. It does not use screen coordinates and does not modify the existing Cromartie CMS automation.

## Prerequisites

- Windows 10 or 11
- Node.js 20 or newer (development was performed with Node.js 24.15.0)
- Internet access to `https://www.botz-glasuren.de`
- Optional: AutoHotkey v2 for `botz-scraper-launcher.ahk`

## Installation

From the repository root in Windows PowerShell:

```powershell
cd tools\botz-scraper
npm install
npx playwright install chromium
```

If PowerShell blocks `npm.ps1`, use the Windows command shims:

```powershell
npm.cmd install
npx.cmd playwright install chromium
```

The exact Playwright dependency is pinned in `package.json` and `package-lock.json`.

## Commands

Run commands from `tools\botz-scraper`:

```powershell
node botz-scraper.js --dry-run
node botz-scraper.js --headed --limit 1
node botz-scraper.js --headed --limit 5
node botz-scraper.js --limit 20
node botz-scraper.js --resume
node botz-scraper.js --retry-failed
node botz-scraper.js --product-code 9101
node botz-scraper.js --output "C:\BOTZ"
node botz-scraper.js --force --product-code 9101
node botz-scraper.js --help
```

`--limit N` counts uncompleted products, so verified completed products do not consume the limit. `--headed` displays Chromium; otherwise Chromium is headless. The optional `--delay-min-ms` and `--delay-max-ms` switches override the default random 750–1500 ms delay between products.

### Dry run

`--dry-run` applies the live earthenware filter, waits for the AJAX results to stabilise, validates the displayed count against unique product URLs, and writes `C:\BOTZ\dry-run-manifest.json`. It does not create product folders or download images.

### Resume and existing output

Completed product folders are verified before being skipped, even without `--resume`. Verification checks `product.md`, `source.json`, core product fields, every recorded image path, and non-zero image sizes. Incomplete products are repaired. A state entry left as `processing` after interruption is reset and reprocessed on the next run.

`--force` reprocesses only selected products. It replaces this scraper's deterministic `product.md`, `source.json`, and image filenames through partial/atomic writes; it never deletes `C:\BOTZ` or unrelated files.

### Retry behaviour and blocking responses

Navigation, extraction, and each image download use at most three attempts with increasing waits. Products that still fail are recorded in `failed-products.json`, and extraction failures receive a screenshot and HTML file under `diagnostics\`.

Three consecutive HTTP 403 or 429 responses stop the run safely. The scraper does not bypass authentication, CAPTCHAs, rate limits, or other access controls.

## Output structure

```text
C:\BOTZ\
├── manifest.json
├── dry-run-manifest.json
├── scrape-log.txt
├── scrape-state.json
├── failed-products.json
├── diagnostics\
└── 9101 Glossy white\
    ├── product.md
    ├── source.json
    └── images\
        ├── 9101_glossy-white_01.jpg
        └── 9101_glossy-white_02.jpg
```

The manifest is written atomically before product processing starts. State is updated atomically before and after each product. Image responses are checked for a recognised image signature, saved with `.partial` filenames, hashed to prevent duplicate files, and renamed only after a successful write.

## AutoHotkey launcher

Run `botz-scraper-launcher.ahk` with AutoHotkey v2. Its tray menu provides:

- one-product and five-product headed tests;
- a specific product-code test;
- resume and retry-failed runs;
- a confirmed full resumable run;
- output-folder and log shortcuts.

The launcher checks for Node.js and the local Playwright dependency, runs only the Node scraper, and reports the Node exit code. It does not register global hotkeys or alter the CMS script.

## Exit codes

- `0`: completed successfully (warnings may have been recorded)
- `1`: one or more product failures
- `2`: command-line, dependency, browser, or output configuration error
- `3`: discovery failure
- `4`: interruption handled safely

## Updating selectors

Page-specific selectors are centralised in `selectors.json`.

1. Run `node botz-scraper.js --headed --dry-run`.
2. Inspect the public overview and a product page in Chromium.
3. Prefer headings, form names/values, IDs, content relationships, and product URL parameters.
4. Update only the affected entries in `selectors.json`.
5. Run `npm test`, then repeat dry-run, one-product, and five-product tests.

Current selector assumptions:

- earthenware is `input[name="productgroup"][value="1"]`;
- filtered HTML is inserted into `#filterresults` and the count into `#filterresultsCount`;
- product headings and labelled sections are inside `.content.product-details`;
- original slide images are in `.left-content.product-details .flexslider .slides`;
- the FlexSlider thumbnail area is also inspected and deduplicated.

The extractor also understands anchor `href`, `src`, `data-src`, `data-lazy-src`, `srcset`, `picture source`, `data-thumb`, and CSS `background-image` sources inside the product image areas. The current sampled pages did not require thumbnail clicks, lazy-load scrolling beyond the image root, or a lightbox.

## Troubleshooting

- **Playwright is missing:** run `npm install`.
- **Chromium executable is missing:** run `npx playwright install chromium`.
- **Filter not found or zero products:** run a headed dry run and review `selectors.json`; do not start a bulk run.
- **403/429:** leave the saved state intact and retry later; do not increase concurrency or attempt evasion.
- **Corrupt state JSON:** the invalid file is preserved with a `.corrupt-<timestamp>.json` suffix and a fresh state is created.
- **Product failure:** inspect `scrape-log.txt`, `failed-products.json`, and that product's diagnostic screenshot/HTML.

## Tests

Unit tests are offline and never scrape BOTZ:

```powershell
npm test
```

Live tests must be run deliberately in the documented staged order. Do not start a full scrape until discovery, one-product, five-product, and larger limited checks are satisfactory.

## Asset permission

Confirm BOTZ's permission and licensing terms before republishing downloaded product text or images. Successful technical download does not grant republication rights.
