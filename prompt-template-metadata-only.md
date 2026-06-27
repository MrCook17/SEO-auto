I want to optimise this Colour & Glaze product page metadata using the project source files.

Use:

- `cromartie_colour_glaze_product_page_seo_guidance_workbook.xlsx`
- `cromartie_colour_glaze_product_page_seo_strategy_workbook_aligned.md`
- `cromartie_colour_glaze_keyword_map_clean_final_reference.xlsx` where useful for keyword ownership, department hierarchy and cannibalisation checks
- `cromartie_colour_glaze_product_page_recurring_fixes_v1.md` if available, especially for naming, metadata and image SEO rules

Metadata-only mode:

- This task is for metadata and image SEO only.
- Do not create a CMS-ready HTML snippet.
- Do not create product description HTML.
- Do not create a specification table.
- Do not create CTA buttons or visible HTML blocks.
- The flexible CMS styling guide is not needed for this mode because no HTML should be returned.

Page URL:
{{PAGE_URL}}

Current page/product name:
{{PRODUCT_NAME}}

Current meta title:
{{CURRENT_META_TITLE}}

Current meta description:
{{CURRENT_META_DESCRIPTION}}

Current HTML/product description snippet, for product-fact context only:

```html
{{CURRENT_HTML_SNIPPET}}
```

Image notes:
{{IMAGE_NOTES}}

Additional product notes:
{{ADDITIONAL_PRODUCT_NOTES}}

Task:
Create:

1. Product name recommendation if the name should be edited
2. SEO-optimised meta title
3. SEO-optimised meta description
4. Image title text and image alt text for every attached image
5. Notes explaining keyword ownership, cannibalisation and uncertainty

Important:

- Use the product-page SEO guidance workbook as the main guidance source.
- Match this product to the correct department/range guidance row where possible.
- Use the strategy guide for keyword ownership and cannibalisation decisions.
- Use the keyword map/workbook only to support the correct page hierarchy and exact-product targeting.
- Keep product pages exact-product focused.
- Avoid broad department keyword cannibalisation.
- Do not target broad terms such as pottery glazes, ceramic glazes, underglazes or colour and glaze unless the workbook clearly allows that exact product page to support them.
- Keep wording natural, useful and commercially realistic.
- Do not invent product facts.
- Do not include unsupported firing temperatures, cone ranges, finishes, effects, food safety, application methods, material suitability, stock status or compatibility claims.
- Use only facts visible in the supplied product/page data, attached images, source files or product notes.
- Keep the meta title under 60 characters where possible.
- Keep the meta description under 160 characters where possible.
- Use UK English.
- Use “colour”, not “color”, unless it is part of an official brand/product name.
- Make image SEO accurately describe what is visible in each attached image.
- Image title text should be concise and product-led.
- Image alt text should describe the visible product/image accurately, without keyword stuffing.
- Do not add citations, source tokens, placeholder text or unsupported notes inside the automation output values.
- Keep the automation block easy for AutoHotkey to parse.

Product name recommendation rules:

- If the current product name is already clear, return `Keep current product name` in the visible section and automation block.
- If the product name should be edited, recommend one clean product name only.
- Prefer colour-first naming where it improves scanability for colour-variant products, for example `Yellow Duncan...` rather than every similar item starting with the brand.
- Do not include product codes, SKUs or item codes in the product name unless they are genuinely part of the official product name or needed for identification.

Meta title rules:

- Lead with the exact product/range intent.
- Include brand, colour/range and product type where useful.
- Avoid adding `Cromartie` at the end if the CMS/template already adds the brand automatically.
- Do not stuff multiple near-duplicate keywords.

Meta description rules:

- Summarise the exact product and useful buying context.
- Avoid unsupported claims.
- Do not include product codes, SKUs or item codes by default because the CMS/product template already displays product codes.
- Keep it under 160 characters where possible.

Image SEO rules:

- Create one image title and one image alt text for every attached image.
- If multiple images show different views, describe each view accurately.
- If the image is a product bottle, jar, pot, packet, label or colour sample, say what is visible.
- Do not describe an effect, fired result, colour outcome or use case unless it is visible or verified.

Output format:

Only return the following visible sections before the automation block:

**Workbook / Guidance Row Used:**
[Guidance row ID, source row ID, department/range name, or explain if not confidently found]

**Product Name Recommendation:**
[Keep current product name OR recommended new product name with brief reason]

**Notes:**

- Keyword ownership followed:
- Cannibalisation avoided by:
- Content facts used:
- Any uncertainty:

Do not output separate visible sections for Meta Title, Meta Description or Image SEO above the automation block.

Put the final usable fields inside the automation block only.

At the very end, include this exact automation block with no extra commentary inside it:

===AUTOMATION_OUTPUT_START===
PRODUCT_NAME_RECOMMENDATION:
[exact product name recommendation only]

META_TITLE:
[exact meta title only]

META_DESCRIPTION:
[exact meta description only]

IMAGE_1_TITLE:
[exact image title only]

IMAGE_1_ALT:
[exact image alt text only]
===AUTOMATION_OUTPUT_END===
