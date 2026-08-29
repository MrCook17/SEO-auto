# Cromartie SEO Automation

Run `cromartie-seo-automation.ahk` from the repository root. Keep the relative folder layout intact because the automation resolves its templates, state and UIA dependency from the script directory.

## Repository structure

- `cromartie-seo-automation.ahk` — main automation entry point
- `prompts/` — ChatGPT prompt templates used by each automation mode
- `docs/` — configuration notes and SEO guidance
- `state/` — saved matrix workflow state used when a run is resumed
- `tools/` — standalone AutoHotkey helper and diagnostic scripts
- `test/` — small test scripts
- `UIA-v2/` — UI Automation dependency
- `logs/` — generated run logs
- `backups/` — generated copies of source CMS fields
- `debug/` — generated accessibility-tree diagnostics

The automation creates `logs/`, `backups/`, `state/` and `debug/` when needed. Generated logs, backups and diagnostics are ignored by Git.

## Supplier scrapers

- `tools/botz-scraper/` — the existing BOTZ supplier workflow
- `tools/figuredart-scraper/` — the separate PDF-driven Figured'Art workflow; see its README for installation, staged validation, full-run, retry, and resume commands

## Department automation

Department automation uses whichever `SeoAutomationMode` is selected (`full`, `metadata`, `image`, `matrix_image`, `matrix_full`, `botz`, `figuredart`, or `promotion_text`) and runs that mode's complete workflow only for its matching catalogue product type. `matrix_image` and `matrix_full` process `Matrix Product` rows and skip `Matrix SKU`, `Simple Product`, and `Department` rows; matrix parents are identified exclusively by Product Name because they do not have stock codes. The other modes process `Simple Product` rows. Press `Ctrl+Alt+D` to enable it, open the first matching product, and press `Ctrl+Numpad4` to start. Press `Ctrl+Numpad6` to stop safely after the current product.

## SEO prompt settings

Press `Ctrl+Shift+NumLock` to select `SeoAutomationMode` from a dropdown and edit the shared settings. In `promotion_text` mode, enter the promotional text in the dedicated box; `NumpadEnter` applies it after opening a selected product and `Numpad4` applies it to an already-open product. The text is pasted into the bottom Description field and the Custom field. Saving is initially disabled for testing by `promotionTextSaveEnabled := false` near the top of the script; change that one line to `true` to save products and enable department-wide runs. Save writes the settings to the existing `state/botz-prompt-settings.txt` compatibility file.

`figuredart` follows the BOTZ product-creation sequence using `C:\FiguredArt`: it matches the open GO b2b stock code to an exact Figured'Art product-code folder, validates the successful `product.md`, attaches every current image in filename order, requests the Figured'Art-specific automation output, uploads the images with their generated CMS metadata, fills the product content and safely resumes from its own state file.

All modes process a maximum of 11 GO b2b image records per product. BOTZ and Figured'Art attach every supported image in the supplier folder to ChatGPT with `Ctrl+A`, avoiding fragile long filename lists. Their prompts request image fields only for the naturally sorted first 11 images, and only those first 11 are parsed, uploaded and edited in GO b2b. Later attachments are reference context only. Ordinary and matrix modes likewise cap detected gallery work at the first 11 image records.
