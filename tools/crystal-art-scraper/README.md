# Craft Buddy Trade Crystal Art Product Scraper

This isolated Node.js tool reads Craft Buddy product codes from `product-codes.txt`, searches the Craft Buddy trade site at `craftbuddyltd.co.uk`, selects the first product result, and verifies the exact SKU on the product before saving any content. It uses the trade site's public Shopify search and product-data endpoints, so no login details or browser session are required for descriptions and images.

For every verified product it saves the complete source description and every product image. Images are always real JPEG files and are kept strictly below 299,000 bytes, which safely satisfies a 300 KB limit. Oversized images begin resizing at a maximum dimension of 1,000 pixels and are reduced further only when required.

## Setup

From PowerShell:

```powershell
cd tools\crystal-art-scraper
npm.cmd install
```

Node.js 20 or newer is required. No browser installation is needed.

## Product-code file

Edit `product-codes.txt` and put one product code on each line:

```text
CAFGR-34GEN138
ANOTHER-CODE
```

Blank lines and lines beginning with `#` are ignored. Duplicate codes are ignored case-insensitively while retaining the first occurrence and the original list order.

## Run it

```powershell
node crystal-art-scraper.js
node crystal-art-scraper.js --resume
node crystal-art-scraper.js --product-code CAFGR-34GEN138
node crystal-art-scraper.js --limit 5
node crystal-art-scraper.js --retry-failed
node crystal-art-scraper.js --force --product-code CAFGR-34GEN138
node crystal-art-scraper.js --output "C:\Crystal Art Test"
node crystal-art-scraper.js --help
```

The default output folder is `C:\Crystal Art`. Resume behaviour is automatic: a completed folder is verified before it is skipped, even when `--resume` is omitted. Interrupted or incomplete items are repaired on the next run. `--force` reprocesses the selected items.

You can alternatively launch `crystal-art-scraper-launcher.ahk` with AutoHotkey v2 and use its tray menu.

## Output

```text
C:\Crystal Art\
|-- manifest.json
|-- scrape-state.json
|-- failed-products.json
|-- scrape-log.txt
`-- CAFGR-34GEN138 Festive Bear Crystal Art Festive Buddies Kit Series 7\
    |-- product.md
    |-- description.html
    |-- source.json
    `-- images\
        |-- CAFGR-34GEN138_festive-bear-crystal-art-festive-buddies-kit-series-7_01.jpg
        `-- ...
```

- `product.md` contains a readable version of the description plus the ordered image list.
- `description.html` preserves the exact description HTML supplied by Craft Buddy.
- `source.json` records source URLs, image dimensions, before/after byte sizes, hashes, and resize details.
- State, failures, and the log are written outside the product folders so a long run can safely resume.

The scraper is sequential, uses a short delay between products, retries transient failures up to three times, and stops attempting a request after repeated 403/429 responses. It does not bypass access controls.

## Tests

```powershell
npm.cmd test
```

The automated tests are offline. A deliberate one-product run is the live integration test.

Confirm that you have permission to reuse Craft Buddy's trade descriptions and images. Downloading accessible assets does not itself grant republication rights.
