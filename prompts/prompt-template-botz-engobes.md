# BOTZ Engobes Product Creation Automation Prompt

Create the complete Cromartie CMS product content for this **BOTZ Earthenware Engobe** product.

This automation is specifically for products from the BOTZ **Engobes 900°–1100°C** range.

Use this file as a source of truth:

- `cromartie_botz_earthenware_engobes_recurring_fixes_v2.md`

## Project guidance — advisory only

Use only these project guidance files:

- `cromartie_flexible_cms_styling_guidance_updated.md`
- `cromartie_colour_glaze_product_page_recurring_fixes_v16.md`

These files were primarily written for glaze product pages, not BOTZ engobes.

Therefore:

- Treat them as **useful editorial, CMS, formatting and quality guidance**, not strict rules.
- Apply general principles where they improve readability, SEO, HTML structure, image SEO and customer usefulness.
- Do **not** blindly apply glaze-specific wording, assumptions, product structures or comparison rules to engobes.
- Where engobe-specific product facts or requirements conflict with glaze-oriented guidance, the engobe facts and this prompt take priority.
- Do not use any SEO guidance workbook, keyword-map workbook or separate product-page SEO strategy file for this workflow.

Priority:

1. Factual product sources supplied in this prompt
2. `cromartie_botz_earthenware_engobes_recurring_fixes_v2.md`
3. Engobe-specific instructions in this prompt
4. `cromartie_colour_glaze_product_page_recurring_fixes_v16.md` where relevant
5. `cromartie_flexible_cms_styling_guidance_updated.md` for useful CMS presentation/styling guidance

The two project files must never be treated as factual sources for the BOTZ product itself.

## Critical terminology rule

This product is an **engobe**, not a ceramic glaze or underglaze unless the supplied factual sources explicitly describe a separate product or process that way.

Use terminology accurately.

Prefer:

- BOTZ engobe
- ceramic engobe
- engobe colour
- engobe decoration
- fired engobe
- engobe surface

where appropriate and supported.

Do not casually substitute:

- glaze
- ceramic glaze
- earthenware glaze
- underglaze
- slip

for `engobe`.

The word `glaze` may still appear when the supplied product information specifically discusses:

- overglazing the engobe
- using a transparent glaze over the engobe
- mixing an engobe with a glaze
- another genuine glaze-related application instruction

Do not turn those instructions into a claim that the engobe itself is a glaze.

## Factual source restrictions

Treat only the following as factual product sources:

1. The exact GO b2b product name below.
2. The complete current `product.md` contents below.
3. What is genuinely visible in the attached images.
4. The manually supplied additional notes below.
5. The fixed range context that this automation processes BOTZ Engobes from the 900°–1100°C category.

Do not browse the GO b2b page, BOTZ website or wider web for additional product facts during the automation.

Do not invent or infer unsupported:

- specifications
- application methods
- application surfaces/stages
- firing details beyond supplied facts
- fired colour
- finish
- opacity/transparency
- overglazing behaviour
- mixing behaviour
- suitability
- compatibility
- frost resistance
- food safety or dinnerware suitability
- safety claims
- size
- availability
- stock
- performance
- packaging type
- sgraffito suitability
- marbling suitability
- pouring/casting suitability
- coat count
- use cases requiring factual support

Creative suggestions about forms, textures or decorative styles may be included only when they are reasonable from verified appearance or visible fired examples and do not imply unsupported technical suitability.

If `product.md` contains an old image list, **ignore that image list completely**.

The actual attachments and attachment order supplied in this request are authoritative.

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
- Prefer the purple CTA/inlink styling from the flexible CMS guidance where appropriate.
- Do not create an unnecessary paragraph solely for an internal link.
- Where two useful links are supplied, two CTA buttons are acceptable.
- Do not force an inline paragraph link when a CTA is cleaner.

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

## General product-page SEO approach

Keep the page focused on the exact BOTZ engobe product.

Use natural combinations of supported terms such as:

- colour/product name
- BOTZ
- engobe
- size where verified
- exact application/effect terminology where verified

Do not force broad terms repeatedly simply for SEO.

In particular, do not make the product sound like a glaze product merely to introduce phrases such as `pottery glaze` or `ceramic glaze`.

Keep customer-facing wording accurate first and SEO-friendly second.

Do not expose internal editorial or SEO reasoning in the automation output.

## Product name recommendation

For this colour-led range, where the supplied facts support it, normally prefer:

`[Colour] - BOTZ Engobe [Verified Size]`

Example:

`White - BOTZ Engobe 200ml`

This is a preferred pattern, not a requirement when the supplied product facts justify a different name.

Important:

- The hyphenated format applies **only** to `PRODUCT_NAME_RECOMMENDATION`.
- Do not automatically copy the hyphenated format into metadata, headings, paragraphs, image fields, links or CTA text.
- Put the colour first where it improves scanning.
- Do not include the product code/SKU in the recommendation unless genuinely useful.
- Do not invent a size.
- Do not rename the product as a glaze or underglaze.
- If there is no justified improvement, return `KEEP CURRENT PRODUCT NAME`.

## Metadata

Use UK English.

Use `colour`, not `color`, except where an official supplied product name requires otherwise.

### Meta title

- Product-led and exact-product focused.
- Use `BOTZ Engobe` naturally.
- Colour first where useful.
- Include size only when verified and helpful.
- Do not include the product code/SKU by default.
- Do not append `Cromartie`.
- Keep under 60 characters where possible.
- Do not call the product a glaze.
- Write naturally rather than forcing the product-name recommendation format.

A likely pattern where supported is:

`[Colour] BOTZ Engobe [Size]`

### Meta description

- Describe the exact engobe product.
- Keep under 160 characters where possible.
- Prefer roughly 140–155 characters when it produces a natural complete sentence.
- Include a clear exact-product identifier.
- Use one useful verified angle rather than listing every technical fact.
- Vary wording naturally across the BOTZ Engobe range.
- Do not default every description to `Shop...`.
- Do not force glaze-related search wording.
- Do not mention stock, price, delivery, popularity or availability.
- Do not invent application, firing, finish or technique claims.
- Do not reuse an almost identical template across every colour with only the colour changed.

Useful angles, when actually supported, may include:

- colour
- surface appearance
- matt character
- application stage
- overglazing behaviour
- decorative technique
- firing range
- creative surface use

Use only one or two rather than cramming all supplied instructions into the metadata.

## CMS HTML approach

Use `cromartie_flexible_cms_styling_guidance_updated.md` for the normal Cromartie visual language.

Use `cromartie_colour_glaze_product_page_recurring_fixes_v16.md` for useful general writing/QA ideas, but adapt them for engobes.

Do not force a glaze-specific template simply because it appears in that file.

Use the standard wrapper:

```html
<div
  style="font-family: Open Sans, sans-serif; font-size:15px; line-height:1.7; color:#444;"
></div>
```

Use inline CSS only.

Do not include an `<h1>`.

## Recommended HTML structure

Normally aim for:

1. One useful `<h2>`
2. Two focused customer-facing paragraphs
3. A short `<ul>` where practical engobe guidance genuinely helps
4. A purple Cromartie specification table when enough verified structured information is available
5. Up to two supplied CTA/inlink buttons

Unlike the glaze-specific recurring-fixes guidance, this structure is **recommended rather than absolute** for BOTZ engobes.

Prioritise a useful, accurate engobe page over mechanically following a glaze template.

Do not add unnecessary sections simply to make the description longer.

## H2

Use one descriptive, customer-facing H2.

Do not simply repeat the product name/H1.

Where supported, strengthen the heading with useful engobe context, for example:

- `[Colour] Engobe for Decorative Ceramic Surfaces`
- `Matt Engobe Colour for Sgraffito and Surface Decoration`
- `BOTZ Engobe Colour for Leather-Hard and Biscuit-Fired Clay`

These are structural examples only.

Never use an application, finish or technique in the H2 unless the supplied factual sources support it.

Do not use `earthenware glaze` or `ceramic glaze` as the product type.

## Main paragraphs

Normally use two focused paragraphs.

### Paragraph 1

Primarily explain:

- what the exact BOTZ engobe is
- its verified colour/appearance
- its verified fired or surface character
- useful creative context where justified

Mention the product naturally.

Keep the first sentence straightforward and readable.

Do not cram colour, application, firing, technique and every other specification into the opening sentence.

### Paragraph 2

Primarily explain useful buying/application context such as:

- why a maker may choose this engobe
- the type of decorative result it provides
- an important application stage
- overglazing behaviour
- a decorative technique
- firing/variation guidance

Only use details supported by `product.md`, additional notes or visible evidence.

Do not make unsupported superiority claims.

Do not compare the engobe to conventional glazes unless that comparison is genuinely useful and supported.

## Engobe-specific practical information

BOTZ engobe product information may contain details such as:

- number of coats
- brush application
- leather-hard clay
- dried clay
- unfired clay
- biscuit-fired clay
- finish without overglazing
- transparent overglazing
- marbling
- sgraffito
- mixing with another product
- pouring/casting use
- firing temperature
- firing range
- frost resistance

These are **examples of possible engobe information, not universal range claims**.

Only include each item when it is actually present in the supplied factual product sources.

Do not assume instructions from one BOTZ Engobe apply to another.

## Bullet list

Use a `<ul>` when it genuinely makes application or creative guidance easier to scan.

It may be particularly useful for verified:

- application stages
- techniques
- handling guidance
- overglazing notes
- practical instructions

Do not duplicate the specification table unnecessarily.

Do not turn the list into a repeat of every sentence in `product.md`.

## Specification table

When enough structured verified information is supplied, use the purple Cromartie specification-table styling from the flexible CMS guidance.

For BOTZ engobes, appropriate rows may include:

- Product type
- Colour
- Size
- Firing range
- Finish
- Application
- Application surface/stage
- Coat guidance
- Overglazing
- Decorative techniques
- Mixing guidance
- Other verified technical information

Include only rows supported for the exact product.

Do not insert filler rows.

Do not automatically use glaze-specific fields that do not make sense for an engobe.

## Internal links

Use only the manually supplied links from the Recommended internal links section above.

- Maximum two.
- Do not invent destinations.
- Do not browse for alternatives.
- Every link needs a descriptive `title`.
- Use natural visible CTA/anchor wording.
- Do not keyword-stuff.
- Prefer the established purple styling where appropriate.
- If `NONE`, omit links completely.

## Product factual accuracy

Be especially strict about:

- engobe versus glaze terminology
- exact colour
- fired appearance
- matt/gloss/surface description
- opacity/transparency
- firing range
- application stage
- brush/application method
- coat count
- overglazing
- sgraffito
- marbling
- mixing
- pouring/casting
- frost resistance
- clay-body suitability
- food safety
- packaging format
- size

Do not generalise information across the BOTZ Engobe range.

Do not infer fired appearance from:

- packaging
- unfired liquid
- product name alone

Where an attached image genuinely shows a fired sample or decorated ceramic piece, you may describe what is visibly present without inventing technical causes.

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

Example patterns:

`9041 White BOTZ Engobe Product Image`

`9041 White BOTZ Engobe Fired Sample`

`9041 White BOTZ Engobe Decorated Ceramic Example`

Use the correct image description only when genuinely visible.

Do not include a file extension.

Make each name specific enough to distinguish multiple images for the same product.

Do not use `BOTZ Glaze` where the product is an engobe.

### IMAGE_n_TITLE

- Concise image title text.
- Natural wording.
- Specific to the visible image.
- Use `engobe`, not `glaze`, for the product type.
- Do not force the hyphenated product-name format.
- Mention colour, BOTZ, product type and size only where useful and supported.
- Include image type only when genuinely visible.

### IMAGE_n_ALT

- Accessibility-first description of what is actually visible.
- Lead with the colour where useful.
- Keep concise and natural.
- Use accurate engobe terminology.
- Do not keyword-stuff.
- Do not infer application, firing or performance claims from the image.

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
- sgraffito example
- marbled example

unless that is genuinely visible.

Packaging-only images must describe the packaging/product container rather than inventing a fired engobe result.

Fired/sample images should describe the visible surface/sample and should not imply packaging is shown.

### Distinctness

For every image:

- Name, Title and Alt must all be present.
- They must be meaningfully distinct.
- Title and Alt must not be exact duplicates.
- Do not create artificial variation by inventing extra details.

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

Internally verify:

- Exact GO b2b `PRODUCT_NAME` is echoed unchanged.
- `IMAGE_COUNT` is unchanged.
- No SEO workbook or SEO strategy file has been used.
- Only the styling guidance and recurring-fixes file have been used as advisory guidance.
- Glaze-specific guidance has not been blindly applied to an engobe.
- The product is consistently identified as an engobe.
- `glaze` appears only where genuinely supported by a glaze/overglaze/mixing instruction.
- Product code/SKU is not unnecessarily included in metadata/body copy.
- Product-name recommendation is natural and colour-led where useful.
- The hyphenated product-name format has not been forced into other fields.
- Meta title is under 60 characters where practical.
- Meta description is under 160 characters where practical and ends naturally.
- HTML uses the Cromartie inline styling appropriately.
- H2 is useful and does not simply repeat the H1.
- Main copy is customer-facing and easy to read.
- Structured technical information is presented clearly where useful.
- No unsupported product facts have been added.
- No information has been generalised from another BOTZ Engobe.
- Recommended inlinks are used only if supplied and useful.
- Every `<a>` has a descriptive `title`.
- Every attached image has Name, Title and Alt.
- Every image field corresponds to the correct attachment number.
- Image Title and Alt are not identical.
- `IMAGE_n_NAME` begins with the verified product code where available.
- Image wording uses `engobe` rather than incorrectly calling the product a glaze.
- No stale `product.md` image-list information has affected processing.
- No citations, source tokens or analysis notes appear in the CMS content.
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
