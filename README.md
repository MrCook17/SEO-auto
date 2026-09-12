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

Department automation uses whichever standard `SeoAutomationMode` is selected (`full`, `department`, `metadata`, `image`, `matrix_image`, `matrix_full`, `botz`, `figuredart`, or `promotion_text`) and runs that mode's complete workflow only for its matching catalogue product type. `matrix_image` and `matrix_full` process `Matrix Product` rows and skip `Matrix SKU`, `Simple Product`, and `Department` rows; matrix parents are identified exclusively by Product Name because they do not have stock codes. The other standard modes process `Simple Product` rows. Press `Ctrl+Alt+D` to enable it, open the first matching product, and press `Ctrl+Numpad4` to start. Press `Ctrl+Numpad6` to stop safely after the current product. `promotion_text_reference` is a separate catalogue-search batch and does not use the department toggle.

## SEO prompt settings

Press `Ctrl+Shift+NumLock` to select `SeoAutomationMode` from a dropdown and edit the shared settings. In `promotion_text` mode, enter the promotional text in the dedicated box; `NumpadEnter` applies it after opening a selected product and `Numpad4` applies it to an already-open product. In `promotion_text_reference`, start on the catalogue product list and press either `NumpadEnter` or `Numpad4`. The automation scans the accessibility tree for every `Simple Product (Reference)`, stores their stock codes, searches each code in turn, double-clicks the exact matching result, fills both promotional-text fields, and saves before continuing. Press `Ctrl+Numpad6` to stop safely after the current reference product. Both modes paste the configured text into the bottom Description field and the Custom field, and both require `promotionTextSaveEnabled := true` for automatic saving. Settings are stored in the existing `state/botz-prompt-settings.txt` compatibility file.

`department` mode follows the same ordinary product content workflow as `full` but uses `prompts/prompt-template-department.md`, which can be edited independently. It identifies the open product by Product Name and does not read the Stock Code field. Its ChatGPT window match is separately configured as `Tools`. Department products are assumed to have exactly one image: the mode bypasses GO b2b Image Gallery accessibility-tree discovery and uses the configured first-image and Details coordinates. Its `Numpad4` + `Numpad6` automation is optional and uses the existing `Ctrl+Alt+A` toggle. When the toggle is on, pressing `Numpad4` builds the prompt, attaches the image, submits it to ChatGPT, waits for the completed response and inserts the returned fields. When the toggle is off, `Numpad4` only prepares the prompt and image, so press `Numpad6` manually when the response is ready. Both paths deliberately skip the final main-product Save, leaving the populated product open for review and manual saving. The one image's Details save still occurs because GO b2b requires it to leave the image record. Because products remain unsaved for review, this mode cannot be started as a department-wide `Ctrl+Numpad4` batch.

The same menu has a persistent **Testing mode** checkbox. When enabled, the automation writes a timestamped session trace, image-gallery count samples, relevant UIA element dumps, full accessibility trees at accepted image counts and failures, window state, coordinate actions, field verification results, and error details to `debug/`. Leave it off for normal runs; enable it before reproducing an intermittent problem and retain the matching `testing-session-*.log.txt` plus `testing-*-accessibility-tree.txt`/`testing-*-uia-element.txt` files.

`figuredart` follows the BOTZ product-creation sequence using `C:\FiguredArt`: it matches the open GO b2b stock code to an exact Figured'Art product-code folder, validates the successful `product.md`, attaches every current image in filename order, requests the Figured'Art-specific automation output, uploads the images with their generated CMS metadata, fills the product content and safely resumes from its own state file.

All modes process a maximum of 11 GO b2b image records per product. BOTZ and Figured'Art attach every supported image in the supplier folder to ChatGPT with `Ctrl+A`, avoiding fragile long filename lists. Their prompts request image fields only for the naturally sorted first 11 images, and only those first 11 are parsed, uploaded and edited in GO b2b. Later attachments are reference context only. Ordinary and matrix modes likewise cap detected gallery work at the first 11 image records.

Ordinary and matrix modes actively visit each available five-image carousel page while counting, because GO b2b can omit an unvisited third page from the accessibility tree. The detector keeps the highest realised total instead of summing retained pages. Attachment batches then open the gallery once, traverse sequentially, wait one second before each copy, and use Chrome's context-menu **Copy image** action on the high-quality preview. Each ChatGPT paste is confirmed from the draft's accessibility-tree attachment count before the batch continues. GO b2b image-metadata insertion verifies every carousel transition, opens the visible **Details** control through UIA, confirms the Title and Alt fields appeared before pasting, and waits for the gallery to return after every image Save.

Every automatic ChatGPT submission leaves the prepared draft untouched for ten seconds before refocusing the composer and pressing Enter. Matrix department catalogue scans classify and discard non-target SKU rows before parsing full identities, including GO b2b's non-editable `Matrix SKU (Reference)` tiles.
