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

## Department automation

Department automation uses whichever `SeoAutomationMode` is selected (`full`, `metadata`, `image`, `matrix_image`, `matrix_full`, or `botz`) and runs that mode's complete workflow for each catalogue product. Press `Ctrl+Alt+D` to enable it, open the first product, and press `Ctrl+Numpad4` to start. Press `Ctrl+Numpad6` to stop safely after the current product.

## BOTZ prompt settings

While `SeoAutomationMode` is set to `botz`, press `Ctrl+Shift+NumLock` to edit the saved Cromartie page URL, up to two recommended internal links, extra inlink information and additional notes. Save writes the values to `state/botz-prompt-settings.txt`; they are loaded automatically when the script starts and inserted into the BOTZ prompt.
