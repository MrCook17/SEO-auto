# Cromartie Figured'Art Product Creation

Create accurate Cromartie product content and image metadata for one Figured'Art product.

This request is part of an automated workflow. Follow the output contract exactly.

## Factual source policy

Use only these sources for product facts:

1. The exact GO b2b product name supplied below.
2. The complete current Figured'Art `product.md` supplied below.
3. What is genuinely visible in the attached images.
4. The manually supplied additional notes below.

Do not browse Figured'Art, Cromartie or the wider web during this automation.

The `product.md` was created from the exact supplier SKU and may contain:

- Product Code
- Name
- Source URL
- Purchase Order Description
- Description
- How Does It Work?
- Specifications
- What's Included
- Additional Product Information
- an old Images list

Treat factual values in those populated sections as product-specific. Consolidate repeated facts naturally, but do not add facts that are absent.

The Source URL is provenance only. Do not browse it and do not include it in the customer-facing copy.

If `product.md` contains an Images section, ignore that section completely. The actual attachments and attachment order in this request are authoritative.

Do not invent or infer unsupported:

- dimensions or finished size
- framed or unframed state
- canvas, support or wood-slice material
- wood-slice diameter
- paint type, colours or number of paint pots
- brushes, tools, hooks, screws or other kit contents
- difficulty level
- recommended age
- safety or non-toxicity claims
- skill or experience requirements
- packaging
- mounting method
- artist attribution or licensing
- suitability for children
- drying time
- completion time
- design details not visible or stated
- stock, availability, price or delivery claims

Visible subject matter, colours and composition may be described from an attachment when genuinely clear. Do not turn visual observations into unsupported technical claims.

## Automated product inputs

Configured Cromartie page URL (context only; do not browse it):

{{PAGE_URL}}

Exact GO b2b product name:

{{PRODUCT_NAME}}

Complete current Figured'Art `product.md`:

===PRODUCT_MD_START===
{{PRODUCT_MD_CONTENT}}
===PRODUCT_MD_END===

Actual ChatGPT attachment count:

{{ATTACHMENT_IMAGE_COUNT}}

GO b2b image count to process (the first attachments only):

{{IMAGE_COUNT}}

Attachment order:

{{IMAGE_ORDER}}

## Recommended internal links — manual input

Use only the following manually supplied internal links when genuinely useful:

===RECOMMENDED_INLINKS_START===
{{RECOMMENDED_INLINKS}}
===RECOMMENDED_INLINKS_END===

This area may contain up to two links or `NONE`.

Rules:

- These links are navigation suggestions, not factual product sources.
- Do not browse them or infer product facts from their destinations.
- Do not invent replacement links.
- If `NONE`, do not add links.
- Use no more than two supplied links.
- Every `<a>` must have a descriptive `title` attribute.
- Use natural customer-facing anchor or CTA wording.
- Prefer the established purple Cromartie CTA styling where appropriate.
- Do not add an otherwise unnecessary paragraph solely to hold a link.

## Additional notes — manual input

===ADDITIONAL_NOTES_START===
{{ADDITIONAL_NOTES}}
===ADDITIONAL_NOTES_END===

Use relevant supplied facts or editorial instructions without extending them through assumptions. If this area contains `NONE`, there are no additional notes.

## Required content

Create:

- Product name recommendation
- SEO meta title
- SEO meta description
- Complete CMS-ready HTML product description
- A distinct CMS Name, Title and Alt value for each of the first `{{IMAGE_COUNT}}` attachments that will be entered into GO b2b

Use UK English throughout. Use `colour`, not `color`, except where an exact supplied proper name requires otherwise.

## Product terminology

Identify the exact product type from `product.md`.

Possible products include mini paint-by-numbers kits on framed canvas and paint-by-numbers kits on wood slices, but these are examples rather than universal facts.

Use the most accurate supported wording, such as:

- paint by numbers
- paint-by-numbers kit
- framed canvas
- wood slice
- acrylic paint

Do not call a wood-slice product a canvas kit. Do not call a canvas product a wood-slice kit. Do not describe a product as framed unless that exact product is stated to be framed.

`Figured'Art` is the supplier/brand spelling. Use it only where natural and useful; do not force it into every field.

## Product name recommendation

Recommend a clear, customer-friendly Cromartie name using the exact design and product type.

Where supported, useful patterns may include:

- `[Design] Mini Paint by Numbers Kit 20 x 20cm - Framed`
- `[Design] Paint by Numbers Wood Slice Kit`

These are examples, not mandatory templates.

Rules:

- Preserve the exact design identity.
- Make product type and size clear when verified.
- Include framed state only when verified.
- Do not include the product code by default.
- Do not invent a size or format.
- Avoid awkward supplier-style word order.
- If the current name is already best, return `KEEP CURRENT PRODUCT NAME`.

The recommendation applies only to `PRODUCT_NAME_RECOMMENDATION`. Do not mechanically repeat its punctuation or word order in every other field.

## Metadata

### Meta title

- Focus on the exact product.
- Use the design name and product type naturally.
- Include size or framed state only when verified and useful.
- Do not include the SKU by default.
- Do not append `Cromartie`.
- Keep under 60 characters where practical.
- Avoid repetitive keyword strings.

### Meta description

- Describe the exact product and its most useful verified buying detail.
- Keep under 160 characters where practical.
- Prefer a natural complete sentence.
- Mention kit contents, format, ease, framing or support only when supplied for the exact product.
- Do not mention stock, price, popularity, delivery or unsupported age suitability.
- Vary wording naturally between products.

## CMS HTML

Use the normal Cromartie visual language from `cromartie_flexible_cms_styling_guidance_updated.md` where available. Use inline CSS only.

Use this outer wrapper:

```html
<div style="font-family: Open Sans, sans-serif; font-size:15px; line-height:1.7; color:#444;"></div>
```

Do not include an `<h1>`.

Create a useful, customer-facing page rather than copying `product.md` mechanically. Preserve all genuinely useful supplied information without padding the page with unsupported claims.

A strong structure normally includes:

1. One descriptive `<h2>` that does not simply repeat the product name
2. One or two focused introductory paragraphs
3. A concise `How Does It Work?` section when instructions are supplied
4. A clear `What's Included` list when kit contents are supplied
5. A purple Cromartie specification table when enough structured facts exist
6. Up to two supplied internal-link CTAs where useful

Omit a section when its facts are not supplied. Do not create empty headings or filler copy.

### Main copy

Explain:

- what the exact product is
- the design or visible subject
- its verified format and size
- what the customer receives
- how the activity works where instructions are supplied
- useful verified framing, mounting or support information

Keep sentences straightforward and welcoming. Avoid exaggerated claims such as `perfect for everyone`, `guaranteed masterpiece`, `professional result` or unsupported therapeutic/educational benefits.

You may retain a modest customer-facing benefit already present in the supplied source, but do not amplify it into a guarantee.

### How Does It Work?

When `product.md` supplies the section:

- preserve all meaningful steps
- present them in a clear ordered list
- correct obvious encoding artefacts or minor grammar without changing meaning
- avoid duplicating the same instructions elsewhere
- do not add preparation, drying, sealing, cleaning or safety instructions that were not supplied

### What's Included

When supplied, use a concise `<ul>` and preserve the exact quantities and materials.

Do not generalise contents from another kit. For example, do not assume every product includes the same number of brushes, wall fixings, reference picture, paints or packaging.

### Specification table

When enough verified structured information is present, use the purple Cromartie specification-table styling.

Potential rows include:

- Product code
- Product type or method
- Design/model
- Finished size
- Support/material
- Frame
- Paint type
- Difficulty level
- Packaging
- Wood-slice diameter
- Other exact factual specifications

Include only useful rows supported for the exact product. The product code may appear in the table even when it is omitted from metadata and prose.

Consolidate duplicate source rows, such as the same size stated twice. Do not show conflicting or redundant rows merely because both appear in `product.md`.

### Artist or rights information

If exact attribution is supplied and useful, preserve it accurately in a restrained form near the end. Do not add rights claims, URLs or artist details that were not supplied.

## Image rules

Process the first `{{IMAGE_COUNT}}` images in the exact attachment order supplied above.

For every processed GO b2b image return:

- `IMAGE_n_NAME`
- `IMAGE_n_TITLE`
- `IMAGE_n_ALT`

### IMAGE_n_NAME

Create a clean, human-readable CMS image name. It is not a filename or path and must not contain a file extension.

Start every image name with the verified Figured'Art product code from `product.md`.

Useful patterns include:

- `SFA137-Y Santorini Sunrise Paint by Numbers Artwork`
- `SFA137-Y Santorini Sunrise Kit Contents`
- `RFA013 Lavender Wood Slice Paint by Numbers Design`

Use a description such as `Kit Contents`, `Framed Canvas`, `Paint Pots`, `Brushes`, `Packaging`, `Reference Image`, `Wood Slice` or `Finished Artwork` only when that feature is genuinely visible.

Make each image name distinct enough to identify multiple images for the same product.

### IMAGE_n_TITLE

- Write concise, natural title text.
- Match the visible image.
- Include design and product type where useful.
- Use size, framed state or kit-content wording only when supported and relevant to that image.
- Do not force the SKU into every title.

### IMAGE_n_ALT

- Prioritise accessibility and describe what is actually visible.
- Identify the artwork/design, product format and visible kit components naturally.
- Keep concise.
- Do not keyword-stuff.
- Do not infer technical specifications from appearance.
- Do not call something packaging, a framed canvas, a wood slice, paint pots, brushes, wall fixings or finished artwork unless it is genuinely visible.

### Image distinctness

For every processed GO b2b image:

- Name, Title and Alt must all be present.
- Name, Title and Alt must be meaningfully distinct.
- Title and Alt must not be exact duplicates.
- Do not create artificial variation by inventing details.

## Attachment authority

There are `{{ATTACHMENT_IMAGE_COUNT}}` actual ChatGPT attachments. `IMAGE_COUNT` must still equal `{{IMAGE_COUNT}}`, because GO b2b accepts only the first `{{IMAGE_COUNT}}` image records.

Use later attachments as product-reference context only. Do not return `IMAGE_n_NAME`, `IMAGE_n_TITLE` or `IMAGE_n_ALT` fields for an attachment numbered above `{{IMAGE_COUNT}}`.

The attachment order is:

{{IMAGE_ORDER}}

Return image fields for exactly the first `{{IMAGE_COUNT}}` attachments. Do not use the Images list inside `product.md` or any reference-only attachment to change the output count, order, filenames or fields.

## Final QA

Internally verify:

- `PRODUCT_NAME` exactly echoes the GO b2b input.
- `IMAGE_COUNT` is unchanged.
- Product code and product type match `product.md`.
- Canvas, frame and wood-slice terminology are not mixed up.
- Size, contents, difficulty and materials are used only when supplied.
- Instructions retain their full useful meaning.
- Duplicate specifications are consolidated.
- No supplier URL, citations, source tokens or editorial notes appear in CMS copy.
- Metadata fits the requested limits where practical.
- HTML has no `<h1>`, placeholder or code fence after parsing.
- Only supplied internal links are used.
- Every `<a>` has a descriptive `title`.
- Each of the first `{{IMAGE_COUNT}}` attachments has Name, Title and Alt in exact order.
- Every processed image Name starts with the verified product code.
- Image Title and Alt are not identical.
- No automation fields are missing, renamed, duplicated or reordered.

## Automation output contract — do not alter

Return exactly one automation block and no text before or after it.

Do not omit, rename, reorder or duplicate any field.

`PRODUCT_NAME` must echo the exact GO b2b product name unchanged.

`IMAGE_COUNT` must be exactly `{{IMAGE_COUNT}}`.

Put the complete multiline CMS HTML only inside `HTML_SNIPPET`. A single `html` code fence is allowed around that field's value.

===AUTOMATION_OUTPUT_START===
MODE:
FIGUREDART_PRODUCT_CREATION

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
