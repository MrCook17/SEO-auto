Create the complete Cromartie CMS product content for this BOTZ product.

## Required project guidance

You must use these project files:

- `cromartie_colour_glaze_product_page_seo_guidance_workbook.xlsx`
- `cromartie_colour_glaze_product_page_seo_guidance_updated.md`
- `cromartie_flexible_cms_styling_guidance_updated.md`
- `cromartie_colour_glaze_product_page_recurring_fixes_v16.md`

Use them as follows:

- **SEO guidance workbook:** match this product to the correct department/range guidance, allowed product-page targeting, blocked broad terms, metadata guidance, image SEO guidance and cannibalisation rules.
- **SEO strategy:** keep the page exact-product focused and protect parent department/range keyword ownership.
- **Recurring fixes v15:** use as the product-page editorial and QA checklist.
- **Flexible CMS styling guidance:** use as the HTML styling source of truth.

If guidance conflicts, use this priority:

1. Factual product sources supplied in this prompt
2. `cromartie_colour_glaze_product_page_recurring_fixes_v15.md`
3. Matching row(s) in `cromartie_colour_glaze_product_page_seo_guidance_updated.xlsx`
4. `cromartie_colour_glaze_product_page_seo_strategy_workbook_aligned.md`
5. `cromartie_flexible_cms_styling_guidance_updated.md` for presentation/styling

The project guidance controls **SEO, wording, structure and styling**. It must not be treated as a source of unsupported product facts.

## Factual source restrictions

Treat only the following as factual product sources:

1. The exact GO b2b product name below.
2. The complete current `product.md` contents below.
3. What is genuinely visible in the attached images.
4. The manually supplied additional notes below.

Do not browse the GO b2b product page or the wider web for extra product facts.

Do not invent or infer unsupported:

- specifications
- firing details
- colour results
- finish or surface behaviour
- application methods
- suitability
- compatibility
- food safety or dinnerware suitability
- safety claims
- size
- availability
- stock
- performance
- packaging type
- use cases that require factual support

A creative-use suggestion is allowed only where it is a reasonable editorial suggestion based on verified appearance/product facts and does not imply unsupported technical suitability.

If `product.md` contains an old image list, **ignore that list completely**. The actual attachments and attachment order supplied in this request are authoritative.

## Automated product inputs

Configured Cromartie page URL (context only; do not browse it):

{{PAGE_URL}}

Exact GO b2b product name:

{{PRODUCT_NAME}}

Complete current `product.md` contents:

===PRODUCT_MD_START===
{{PRODUCT_MD_CONTENT}}
===PRODUCT_MD_END===

Actual attached image count:

{{IMAGE_COUNT}}

Attachment order:

{{IMAGE_ORDER}}

## Recommended internal links — manual input

Use the following manually supplied internal links in the HTML snippet where genuinely useful:

===RECOMMENDED_INLINKS_START===
{{RECOMMENDED_INLINKS}}
===RECOMMENDED_INLINKS_END===

This area may contain:

- one internal link
- two internal links
- `NONE`

Important:

- These links are navigation recommendations, not factual product sources.
- Never use an inlink destination to infer extra product facts.
- Do not browse for replacement links.
- If `NONE`, do not invent links.
- Use a maximum of two supplied links.
- Every `<a>` must have a descriptive `title` attribute.
- Prefer the purple CTA/inlink button styling from the flexible CMS guidance when links sit after the specification table.
- Do not create an extra paragraph solely to hold an internal link.
- Where two useful links are supplied, two CTA buttons are acceptable.
- Do not force an inline paragraph link when a post-table CTA is cleaner.

## Additional notes — manual input

Use the following manually supplied notes where relevant. They may contain product facts, editorial context or instructions. Do not extend them with unsupported assumptions, and do not let them override the exact GO b2b name, `product.md` or visible image evidence.

===ADDITIONAL_NOTES_START===
{{ADDITIONAL_NOTES}}
===ADDITIONAL_NOTES_END===

If this area contains `NONE`, there are no additional notes.

## Required content

Create the normal full-product workflow values:

- Product name recommendation
- SEO meta title
- SEO meta description
- Complete CMS-ready HTML product description
- A distinct CMS Name, Title and Alt text value for every attached image

## Product-page SEO rules

Keep this page exact-product focused.

Before drafting, internally:

1. Match the product to the best applicable guidance row in the SEO workbook.
2. Check the relevant product-page targeting approach.
3. Check allowed keyword patterns.
4. Check broad/blocked terms.
5. Check range/parent cannibalisation guidance.
6. Check the relevant image SEO guidance.
7. Apply recurring fixes v15.

Do not expose this internal SEO analysis in the automation output.

Do not put phrases such as:

- keyword ownership
- search intent
- cannibalisation
- parent owns
- product page targets

into customer-facing CMS copy.

Broad phrases such as `ceramic glazes`, `pottery glazes`, `underglazes`, `earthenware glazes` or similar should not become the product's primary targeting simply because they have search value. Protect the range/department page according to the workbook.

## Product name recommendation

Follow recurring fixes v15.

For colour-heavy product ranges, where the supplied facts support it, prefer:

`[Colour] - [Brand/Range/Product Type] [Verified Size]`

Important:

- The hyphenated format applies **only** to `PRODUCT_NAME_RECOMMENDATION`.
- Do not automatically copy that format into metadata, headings, paragraphs, image fields, links or CTA text.
- Put the colour first where appropriate.
- Do not add the product code/SKU to the recommendation unless genuinely required.
- Do not invent a brand, range, product type or size not supported by the factual sources.
- If there is no justified improvement, return `KEEP CURRENT PRODUCT NAME`.

## Metadata

Use UK English.

### Meta title

- Product-led and exact-product focused.
- Colour first where useful.
- Use range/type/size only where supported.
- Do not include product codes/SKUs by default.
- Do not append `Cromartie`.
- Keep under 60 characters where possible.
- Avoid broad department keyword targeting.
- Write naturally; do not force the hyphenated product-name format.

### Meta description

- Describe the exact product rather than the whole range.
- Keep under 160 characters where possible.
- Aim for a natural complete sentence rather than cutting wording to hit a character count.
- Prefer roughly 140–155 characters where practical.
- Include a clear exact-product identifier.
- Use one strong verified angle rather than trying to include every fact.
- Vary openings naturally.
- Do not default to `Shop...`.
- Avoid generic filler such as `perfect`, `ideal`, `premium`, `stunning`, `vibrant`, `versatile` or `easy to use` unless directly supported.
- Do not mention stock, price, delivery, popularity or availability.
- Do not repeat a formula likely to produce near-identical descriptions across the BOTZ range.

## CMS HTML rules

Follow `cromartie_colour_glaze_product_page_recurring_fixes_v15.md` and `cromartie_flexible_cms_styling_guidance_updated.md`.

Use the standard wrapper:

```html
<div
  style="font-family: Open Sans, sans-serif; font-size:15px; line-height:1.7; color:#444;"
></div>
```

### Required structure

The complete snippet should contain:

1. One purpose-led `<h2>`
2. Exactly two substantial `<p>` tags in total
3. A short `<ul>` only where it adds useful practical information not duplicated elsewhere
4. A purple Cromartie product specification table whenever verified structured product facts are available
5. Up to two supplied internal-link CTA/inlink buttons where useful

Do not include an `<h1>`.

### H2

- Do not merely repeat the product name/H1.
- Use it to explain the product's purpose, appearance, format or buyer context.
- Keep it natural and customer-facing.
- Do not force a broad SEO phrase.

### First paragraph

Use the first paragraph primarily for:

- the product name mentioned naturally
- verified appearance/colour/finish/surface character
- useful creative context supported by the product facts or visible fired sample

The first sentence must be easy to read on its own.

Do not overload it with every product fact.

Do not repeat the size awkwardly when the H1/product name already contains it.

### Second paragraph

Use the second paragraph primarily for:

- why a maker may choose this exact product/type
- useful buying context
- one important application/firing/variation point where verified

Do not turn this into an unsupported superiority comparison.

Routine technical details belong in the specification table.

### Two-paragraph rule

There must be **exactly two `<p>` tags in the complete HTML snippet**.

Normally aim for approximately 90–140 words across the two paragraphs, but this is guidance rather than a hard limit. Do not count words mechanically or remove useful supported content solely to hit the range.

Do not add a third paragraph for:

- links
- notes
- safety
- colour variation
- application guidance
- CTA wording

Use a styled `<div>` for a genuinely necessary standalone note.

### Bullet list

Use a `<ul>` only when useful.

It should contain practical guidance, uses or short facts that are not already better represented in the table.

Do not duplicate table rows in the bullets.

Do not repeat the full product name unnecessarily.

### Specification table

When `product.md` provides structured verified facts, include the responsive purple Cromartie specification table from the flexible styling guide.

Suitable rows may include only verified facts such as:

- product type
- range
- colour
- finish
- size/volume
- format
- application
- firing range
- surface/clay body
- safety
- compatibility

Do not add empty/filler rows.

Do not invent missing specifications.

Do not repeat routine structured facts extensively in the paragraphs.

### Content after the specification table

Do not place ordinary explanatory paragraphs/body copy after the specification table.

Anything below the table should be limited to:

- supplied CTA/inlink buttons
- a genuinely important styled note

If internal links are supplied, CTA buttons after the table are normally preferred.

## Internal links

Use only the manually supplied links from the Recommended internal links section above.

- Maximum two.
- Use only when genuinely useful.
- Do not invent destinations.
- Do not browse for destinations.
- Every link needs a descriptive `title`.
- Use natural visible anchor/CTA text.
- Do not keyword-stuff anchors.
- Prefer the established purple gradient CTA styling.
- Keep links below the specification table where that creates the cleanest snippet.
- Two CTAs are acceptable when two recommended links are supplied.
- If no links are supplied, simply omit links rather than adding placeholders.

## Product factual accuracy

Only include a fact when it is supplied by the GO b2b name, `product.md`, or genuinely visible in an attachment.

Be especially strict with:

- fired colour
- finish
- transparency/opacity
- firing temperature/range
- tableware/dinnerware suitability
- food safety
- glaze compatibility
- clay-body suitability
- application method
- coat count
- layering
- surface variation
- performance
- packaging format

Do not infer a fired result from an unfired liquid, packaging or product name.

## Image rules

Process images in the **exact attachment order** supplied above.

For every image return:

- `IMAGE_n_NAME`
- `IMAGE_n_TITLE`
- `IMAGE_n_ALT`

### IMAGE_n_NAME

This is a clean, human-readable **CMS image name**.

It is not:

- the source filename
- a filesystem path
- a filename with an extension
- the image title
- the alt text

When a verified product code is supplied in `product.md`, put that product code at the start of the CMS image name.

Example pattern:

`9101 Glossy White BOTZ Glaze Fired Sample`

Do not include an extension.

Make the name specific enough to distinguish multiple images of the same product.

### IMAGE_n_TITLE

- Concise image title text.
- Natural wording.
- Product/image specific.
- Do not force the hyphenated product-name format.
- Mention colour, range/type and size only where useful and supported.
- Describe the actual image type where visible.

### IMAGE_n_ALT

- Accessibility-first description of what is genuinely visible.
- Lead with the colour where appropriate for colour variants.
- Keep concise and natural.
- Do not keyword-stuff.
- Do not infer technical/product claims from the image.

### Image accuracy

Do not call an image:

- fired sample
- colour tile
- bottle
- jar
- tub
- packaging
- label
- group image
- decorated pottery

unless that is genuinely visible.

Packaging-only images must describe packaging rather than a fired result.

Fired/sample images should describe the visible sample and not imply packaging is shown.

### Distinctness

For every image:

- Name, Title and Alt must all be present.
- They must be meaningfully distinct.
- Title and Alt must not be exact duplicates.
- Do not create variation by inventing additional facts.

## Attachment authority

`IMAGE_COUNT` must equal:

{{IMAGE_COUNT}}

Process exactly that many images.

The attachment order is:

{{IMAGE_ORDER}}

Do not use an image list inside `product.md` to:

- change the count
- change the order
- invent a missing image
- omit an attachment

The actual attachments are authoritative.

## Final QA before responding

Internally verify all of the following:

- Exact GO b2b `PRODUCT_NAME` is echoed unchanged.
- `IMAGE_COUNT` is unchanged.
- Correct SEO workbook guidance has been applied.
- Product content remains exact-product focused.
- Broad parent/range keyword ownership is protected.
- Product code/SKU is not unnecessarily included in metadata/body copy.
- Product-name recommendation follows the v15 colour-first convention where justified.
- Hyphenated recommendation wording has not been forced into other fields.
- Meta title is under 60 characters where practical.
- Meta description is under 160 characters where practical and ends naturally.
- CMS HTML has one purpose-led H2.
- CMS HTML has exactly two `<p>` tags total.
- First sentence is natural and not overloaded.
- Structured verified facts appear in the purple specification table.
- Bullet list, if present, does not duplicate the table.
- No ordinary body copy appears after the specification table.
- Recommended inlinks are used only if supplied and useful.
- Every `<a>` has a descriptive `title`.
- HTML uses inline CSS only.
- No unsupported facts have been added.
- No internal SEO terminology appears in customer-facing copy.
- Every attached image has Name, Title and Alt.
- Every image field matches the correct attachment number.
- Image Title and Alt are not identical.
- IMAGE_n_NAME begins with the verified product code where available.
- No stale `product.md` image-list information has affected processing.
- No citations, source tokens or analysis notes appear in CMS content.
- No automation fields are missing, renamed, duplicated or reordered.

## Automation output contract — do not alter

Return **exactly one automation block**.

Do not add any text before or after it.

Do not omit, rename, reorder or duplicate any automated field.

`PRODUCT_NAME` must echo the exact GO b2b product name unchanged.

`IMAGE_COUNT` must be exactly `{{IMAGE_COUNT}}`.

Put the complete multiline CMS HTML only inside `HTML_SNIPPET`.

A single `html` code fence is allowed around that field's value.

===AUTOMATION_OUTPUT_START===
MODE:
BOTZ_PRODUCT_CREATION

PRODUCT_NAME:
{{PRODUCT_NAME}}

IMAGE_COUNT:
{{IMAGE_COUNT}}

PRODUCT_NAME_RECOMMENDATION:
[exact recommended product name, or KEEP CURRENT PRODUCT NAME]

META_TITLE:
[exact meta title only]

META_DESCRIPTION:
[exact meta description only]

HTML_SNIPPET:

```html
[complete CMS-ready HTML snippet only]
```

{{IMAGE_AUTOMATION_OUTPUT_FIELDS}}

===AUTOMATION_OUTPUT_END===
