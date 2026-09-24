# Cromartie SEO Automation

Run `cromartie-seo-automation.ahk` from the repository root. Keep the relative folder layout intact because the automation resolves its templates, state and UIA dependency from the script directory.

## Repository structure

- `cromartie-seo-automation.ahk` — main automation entry point
- `Core/` — configuration, mutable runtime state, settings, persisted workflow state, diagnostics and run artifacts
- `Browser/` — clipboard/input primitives, ChatGPT interaction and Windows file-picker transfers
- `CMS/` — product fields, catalogue traversal, image handling, UIA controls and Matrix discovery/navigation
- `Helpers/` — text and supplier-file helpers
- `SEO/` — ChatGPT output parsing and validation
- `Modes/` — ordinary, BOTZ, promotion and Matrix mode implementations
- `Workflows/` — product dispatch, automatic completion, Department batching and CMS-to-ChatGPT image transfer
- `UI/` — commands, settings GUI and static hotkey declarations
- `prompts/` — ChatGPT prompt templates used by each automation mode
- `docs/` — configuration notes and SEO guidance
- `state/` — persisted settings and recoverable supplier/Matrix workflow snapshots
- `tools/` — standalone AutoHotkey helper and diagnostic scripts
- `test/` — small test scripts
- `UIA-v2/` — UI Automation dependency
- `logs/` — generated run logs
- `backups/` — generated copies of source CMS fields
- `debug/` — generated accessibility-tree diagnostics

The automation creates `logs/`, `backups/`, `state/` and `debug/` when needed. Generated logs, backups and diagnostics are ignored by Git.

The root script is intentionally only a bootstrap. It owns the directives, vendor and application include list, thread defaults, settings initialization, error/exit callback registration and final hotkey include. Application modules do not recursively include one another; AutoHotkey resolves their functions globally through the explicit central include list. Keep the entry point at the repository root because configuration and resource paths use `A_ScriptDir`.

## Main controls

| Key | Action |
| --- | --- |
| `NumpadEnter` | Open the selected catalogue product and dispatch its configured workflow |
| `Numpad4` | Dispatch the configured workflow from an already-open product |
| `Numpad6` | Copy and insert the latest ChatGPT response manually |
| `Ctrl+Alt+I` | Copy the current product's CMS images into ChatGPT |
| `Ctrl+Alt+N` | Toggle recommended product-name insertion |
| `Ctrl+Alt+A` | Toggle automatic ChatGPT completion and CMS insertion |
| `Ctrl+Alt+D` | Toggle Department batch availability |
| `Ctrl+Numpad4` | Start Department batch processing |
| `Ctrl+Numpad6` | Stop the Department/reference batch after the current product |
| `Ctrl+Shift+NumLock` | Open SEO prompt settings |
| `Ctrl+0` … `Ctrl+9` | Set the current prompt/CMS image count |
| `Ctrl+Alt+T` | Show current runtime/test status |
| `Ctrl+Alt+W` | Copy the active window title |
| `Ctrl+Alt+C` | Copy the current mouse coordinates |
| `F8` | Show the last Matrix Edit-control locations |
| `F9` | Reacquire the CMS document and dump its accessibility tree |
| `Ctrl+Alt+R` | Reload the script |
| `Escape` | Exit the script |

## Supplier scraper

- `tools/botz-scraper/` — the existing BOTZ supplier workflow

## Department automation

Department automation uses whichever standard `SeoAutomationMode` is selected (`full`, `department`, `metadata`, `image`, `matrix_image`, `matrix_full`, `botz`, `promotion_text`, or `display_on_website_app`) and runs that mode's complete workflow only for its matching catalogue product type. `matrix_image` and `matrix_full` process `Matrix Product` rows and skip `Matrix SKU`, `Simple Product`, and `Department` rows; matrix parents are identified exclusively by Product Name because they do not have stock codes. The other standard modes process `Simple Product` rows. Press `Ctrl+Alt+D` to enable it, open the first matching product, and press `Ctrl+Numpad4` to start. Press `Ctrl+Numpad6` to stop safely after the current product. `promotion_text_reference` is a separate catalogue-search batch and does not use the department toggle.

## SEO prompt settings

Press `Ctrl+Shift+NumLock` to select `SeoAutomationMode`, then select one of the prompts registered exclusively to that mode. The prompt dropdown updates with the mode, and both selections are persisted. Existing settings files without a saved prompt continue with the mode's original/default prompt. Full mode offers **Standard full product** (`prompts/prompt-template.md`) and **Tools product optimisation** (`prompts/prompt-template-tools-products.md`); both use the same CMS inputs and automation output fields.

In `promotion_text` mode, enter the promotional text in the dedicated box; `NumpadEnter` applies it after opening a selected product and `Numpad4` applies it to an already-open product. Leave the box empty to clear the promotional fields in both Description and Custom. In `promotion_text_reference`, start on the catalogue product list and press either `NumpadEnter` or `Numpad4`. The automation scans the accessibility tree for every `Simple Product (Reference)`, stores their stock codes, searches each code in turn, double-clicks the exact matching result, fills or clears both promotional-text fields, and saves before continuing. Press `Ctrl+Numpad6` to stop safely after the current reference product. Both modes require `promotionTextSaveEnabled := true` for automatic saving. These modes have no ChatGPT step, so their prompt dropdown is disabled. Settings are stored in the existing `state/botz-prompt-settings.txt` compatibility file.

In `display_on_website_app` mode, `NumpadEnter` opens the selected catalogue product, clicks **Display on Website** and **Display on App**, then saves it. `Numpad4` performs the same clicks on an already-open product. This mode has no ChatGPT prompt step and can also be used by department automation.

`department` mode follows the same ordinary product content workflow as `full` but uses `prompts/prompt-template-department.md`, which can be edited independently. It identifies the open product by Product Name and does not read the Stock Code field. Its ChatGPT window match is separately configured as `Tools`. Department products are assumed to have exactly one image: the mode bypasses GO b2b Image Gallery accessibility-tree discovery and uses the configured first-image and Details coordinates. Its `Numpad4` + `Numpad6` automation is optional and uses the existing `Ctrl+Alt+A` toggle. When the toggle is on, pressing `Numpad4` builds the prompt, attaches the image, submits it to ChatGPT, waits for the completed response and inserts the returned fields. When the toggle is off, `Numpad4` only prepares the prompt and image, so press `Numpad6` manually when the response is ready. Both paths deliberately skip the final main-product Save, leaving the populated product open for review and manual saving. The one image's Details save still occurs because GO b2b requires it to leave the image record. Because products remain unsaved for review, this mode cannot be started as a department-wide `Ctrl+Numpad4` batch.

The same menu has a persistent **Testing mode** checkbox. When enabled, the automation writes a timestamped session trace, image-gallery count samples, relevant UIA element dumps, full accessibility trees at accepted image counts and failures, window state, coordinate actions, field verification results, and error details to `debug/`. Leave it off for normal runs; enable it before reproducing an intermittent problem and retain the matching `testing-session-*.log.txt` plus `testing-*-accessibility-tree.txt`/`testing-*-uia-element.txt` files.

All modes process a maximum of 11 GO b2b image records per product. BOTZ attaches every supported image in the supplier folder to ChatGPT with `Ctrl+A`, avoiding fragile long filename lists. Its prompt requests image fields only for the naturally sorted first 11 images, and only those first 11 are parsed, uploaded and edited in GO b2b. Later attachments are reference context only. Ordinary and matrix modes likewise cap detected gallery work at the first 11 image records.

Ordinary and matrix modes actively visit each available five-image carousel page while counting, because GO b2b can omit an unvisited third page from the accessibility tree. The detector keeps the highest realised total instead of summing retained pages. Each count sample checks the four expected control groups and re-verifies every returned element's localised UIA control type; Chrome exposes an Image control as `graphic`. Keep this explicit verification when changing gallery discovery, because the stable-count decision depends on those control counts agreeing. Attachment batches then open the gallery once, traverse sequentially, wait one second before each copy, and use Chrome's context-menu **Copy image** action on the high-quality preview. Each ChatGPT paste is confirmed from the draft's accessibility-tree attachment count before the batch continues. GO b2b image-metadata insertion verifies every carousel transition, opens the visible **Details** control through UIA, confirms the Title and Alt fields appeared before pasting, and waits for the gallery to return after every image Save.

Every automatic ChatGPT submission leaves the prepared draft untouched for ten seconds before refocusing the composer and pressing Enter. Department catalogue scans only parse ordinary products of the selected type. They skip child departments, reference tiles, and other non-target tiles, including GO b2b's non-editable `Simple Product (Reference)` and `Matrix SKU (Reference)` rows.

## Persisted state and recovery

State files are workflow contracts rather than general-purpose configuration. Loaders may return an already-populated in-memory `Map` before reading disk, and supplier upload functions mutate that same object as progress is saved. Do not clone or reconstruct these maps during recovery work.

Current persisted formats are:

- `state/botz-prompt-settings.txt` — `CROMARTIE_BOTZ_PROMPT_SETTINGS_V1`
- `state/botz-product-state.txt` — writer uses `CROMARTIE_BOTZ_STATE_V3`; loader also supports V2
- `state/matrix-image-state.txt` — current writer and loader use `CROMARTIE_MATRIX_STATE_V3`
- `state/matrix-full-state.txt` — `CROMARTIE_MATRIX_FULL_STATE_V3`

The checked-in `state/matrix-image-state.txt` is a historical V1 snapshot for the Wallie Christmas Tree matrix parent. Current code neither generates nor loads V1. It contains only the old shared image count and parent/child discovery context, with no completion or upload-progress record. Archive or retire that stale snapshot separately if it is no longer required; do not make the V3 loader accept its header without an explicit schema conversion, because V1 lacks the current parent-image count, per-child image counts and connected-size fields.

State encoding is order-sensitive: `%`, tab, carriage return and line feed are escaped and decoded in the established order. If a state schema must change, introduce a new version header, preserve child/image record order, decide explicitly which previous versions remain supported, and test against copies rather than active recovery files.

## Developing the application

Make each change in the narrowest module that owns the behavior. Functions remain global AutoHotkey functions, so a caller does not require a module-to-module include. Add any new production module once to the central include list in `cromartie-seo-automation.ahk`, after Configuration and RuntimeState and before settings initialization or hotkey registration.

Use these ownership boundaries:

- Put startup constants, paths, timings and coordinates in `Core/Configuration.ahk`.
- Put mutable global initial values in `Core/RuntimeState.ahk`; keep them at global scope.
- Put mode IDs, prompt ownership and prompt labels in `Core/ModeRegistry.ahk`.
- Put prompt assembly in `prompts/Builders.ahk`, parsing in `SEO/OutputParsing.ahk`, and field rules in `SEO/Validation.ahk`.
- Put CMS discovery and physical CMS interaction in the relevant `CMS/` module.
- Put reusable browser/clipboard/file-picker operations in `Browser/` while preserving each helper's existing clipboard contract.
- Put end-to-end mode behavior in `Modes/` and coordination between modes in `Workflows/`.
- Put user commands and literal static hotkeys in `UI/`; do not add module startup side effects.

When adding a mode:

1. Register its stable mode ID and prompt choices in `Core/ModeRegistry.ahk`. A mode with no prompt should return an empty prompt-option list.
2. Add only immutable configuration to `Core/Configuration.ahk` and only mutable startup state to `Core/RuntimeState.ahk`.
3. Implement the mode in the appropriate `Modes/` or `Workflows/` file and add the smallest required dispatch branch in `Workflows/ProductDispatch.ahk`.
4. If it uses ChatGPT, keep its prompt labels, parser acceptance rules and validation behavior aligned without consolidating intentionally different parsers.
5. If it persists recovery state, version the complete schema and define compatibility before writing the first new-format file.
6. Add or change a hotkey only in `UI/Hotkeys.ahk`, keeping bindings literal unless dynamic scope is a deliberate feature.

Several implementation details are intentional reliability contracts:

- UIA elements are reacquired after navigation because Chrome controls become stale. Avoid extra accessibility-tree scans and avoid caching controls across page changes.
- Some controls are discovered with UIA and then clicked physically. Do not replace physical clicks with `Invoke()` without live regression testing.
- Text clipboard helpers normally restore the prior clipboard; successful CMS image copies deliberately leave image data available for the next ChatGPT paste.
- Matrix child ordering, supplier natural image ordering, attachment baselines, no-retry-after-ambiguous-upload behavior, and stop-after-current handling are recovery safeguards.
- Delays and polling intervals are configuration with observable workflow effects. Change them independently and test the relevant live path.
- Diagnostics must remain non-fatal. Logging or UIA-dump failures must not stop product automation.

### Validation

Run the non-destructive checks from the repository root after every change:

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /ErrorStdOut /Validate '.\cromartie-seo-automation.ahk'
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /ErrorStdOut /Validate '.\test\test.ahk'
Push-Location '.\tools\botz-scraper'
npm.cmd test
Pop-Location

git diff --check
git status --short
```

Use Testing mode for browser/CMS investigation and retain the matching files from `debug/`. Test prompt, parser and state changes with deterministic fixtures where possible. Keep live product writes as a separate manual verification step, using a known disposable/test product and reviewing the selected mode, product identity and Save behavior before running it.
