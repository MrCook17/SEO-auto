# Crystal Art Product Creation Automation — SEO & CMS Optimised

Create complete Cromartie CMS content for this exact Crystal Art product.

This is an automated workflow. **Keep every existing automation input and output field exactly as supplied. Do not rename, remove, reorder or replace them.**

## Guidance

Use:

- `cromartie_flexible_cms_styling_guidance_updated.md`

as the **HTML styling and formatting source of truth** if it is available in the project sources.

Do **not** use any SEO workbook files.

Use general ecommerce SEO knowledge together with the exact supplied product evidence. The configured Cromartie URL is context only; **do not browse it**.

---

# Exact product identity

Current GO b2b product name:

{{PRODUCT_NAME}}

Cromartie page/category URL:

{{PAGE_URL}}

`PRODUCT_NAME` in the final automation block must reproduce the current GO b2b name **exactly**. It is an audit field, not the recommended customer-facing name.

---

# Supplier product record

The following `product.md` content came from the uniquely matched product folder:

```markdown
{{PRODUCT_MD_CONTENT}}
```

Treat it as the main factual source for this exact product.

It may contain:

- product/design name
- product code
- dimensions
- format
- kit contents
- age guidance
- artwork/licensing information
- packaging details
- other verified product-specific information

Only use facts supported by this record, supplied notes or clearly visible images.

Correct obvious character-encoding errors such as `â€™`, `Â®` or similar mojibake in customer-facing copy.

Do not expose:

- scraping information
- supplier URLs
- timestamps
- wholesale information
- barcodes
- internal notes
- SKU/product code

unless Additional Notes explicitly requires it.

---

# Attached images

Total attachments supplied:

{{ATTACHMENT_IMAGE_COUNT}}

GO b2b image records required:

{{IMAGE_COUNT}}

Attachment order:

{{IMAGE_ORDER}}

The first `{{IMAGE_COUNT}}` attachments correspond exactly to the CMS image fields in the same order.

Later attachments are reference-only.

Describe only what is genuinely visible.

Do not infer hidden:

- materials
- dimensions
- contents
- licensing
- construction
- characters
- colours
- included accessories

from filenames or assumptions.

---

# Recommended internal links

{{RECOMMENDED_INLINKS}}

Use only relevant supplied links.

Rules:

- links are navigation aids, never factual sources
- never invent a URL
- if `NONE` or `N/A`, add no internal links
- normally use no more than two
- every `<a>` must have a descriptive `title` attribute
- use the purple Cromartie CTA styling from the CMS guidance where suitable
- place CTAs naturally near the end of the description
- do not create filler paragraphs just to introduce a link

---

# Additional notes

{{ADDITIONAL_NOTES}}

Use supported additional notes where relevant.

Do not allow them to override stronger product-specific evidence or the automation contract.

---

# Task

Create:

1. Product name recommendation
2. SEO meta title
3. SEO meta description
4. CMS-ready HTML product description
5. Image Name, Title and Alt for every requested CMS image

---

# SEO strategy

Optimise for the **exact product and design**, not broad Crystal Art category terms.

First identify from the supplied evidence:

- exact Crystal Art product type
- design/character/theme
- format
- verified size
- important included contents
- useful distinguishing feature

Use the clearest exact-product search phrase naturally across:

- recommended product name
- meta title
- meta description
- H2
- first paragraph

Do not repeat the same exact keyword unnaturally.

Use relevant secondary terminology naturally where supported, such as the product format, activity type, design theme or display format.

Do not target broad terms such as `craft kits`, `art kits` or `Crystal Art` repeatedly simply for SEO.

The copy should satisfy **commercial product intent**: a customer should quickly understand what they are buying, what the finished design is, how the activity works and what is included.

---

# Product name recommendation

Recommend a concise customer-facing name that clearly identifies:

- the design/character/theme
- the exact Crystal Art product type
- size or format only where useful and verified

Preserve supported:

- licensed brand
- character
- collection/series
- official product-format terminology

Do not add unsupported:

- age ranges
- contents
- materials
- marketing claims

Avoid keyword stuffing.

---

# Meta title

Create a strong exact-product SEO title.

Requirements:

- identify the design/product clearly
- include the Crystal Art/product-type context
- include size/format only where it adds useful distinction
- avoid generic filler
- do not include SKU/product code
- do not append `Cromartie` unless it genuinely fits
- aim for **50–60 characters**
- remain natural if slightly shorter

---

# Meta description

Write approximately **140–160 characters** where practical.

It should:

- identify the exact product/design
- explain what type of creative kit it is
- mention one or two useful verified selling points
- read naturally and encourage a relevant click

Do not use vague descriptions that could apply to every Crystal Art product.

Avoid unsupported phrases such as:

- perfect gift
- hours of fun
- easy for everyone
- high quality
- premium
- official
- exclusive

unless specifically supported.

---

# Customer-facing writing quality

The HTML must read like a **useful product description written by a knowledgeable person**, not an SEO template.

The reader should understand:

- what the product is
- what design they will create
- what makes this particular product visually distinctive
- how the creative process works
- what is included
- how the finished item can be used/displayed where supported

Use specific visual details from the supplied product record/images where appropriate.

Avoid dry copy that merely lists specifications.

Avoid generic filler such as:

- unleash your creativity
- bring your creativity to life
- perfect for craft lovers
- ideal for beginners and experts
- create a stunning masterpiece
- take your crafting to the next level

Prefer concrete descriptions of the actual product and artwork.

---

# CMS HTML requirements

Follow `cromartie_flexible_cms_styling_guidance_updated.md`.

Use the standard wrapper:

```html
<div
  style="font-family: Open Sans, sans-serif; font-size:15px; line-height:1.7; color:#444;"
></div>
```

Use inline CSS only.

Do not use:

- `<html>`
- `<head>`
- `<body>`
- `<style>`
- `<h1>`
- scripts
- forms
- iframes
- comments

Use one product-specific styled `<h2>`:

```html
<h2
  style="color:#76689A; font-size:1.7em; font-weight:bold; margin-bottom:12px;"
>
  [Descriptive exact-product heading]
</h2>
```

---

# Paragraph structure

Where enough verified information exists, use **two substantial natural paragraphs** before structured information.

## Paragraph 1

Explain:

- what the exact product is
- its format/size where useful
- the design or character
- important supplied contents where naturally relevant

Make the design description specific enough that the paragraph could not simply be reused for another Crystal Art product.

## Paragraph 2

Explain useful customer context such as:

- what is visible in the finished artwork
- how the Crystal Art process works
- how numbered/symbol matching is used where supported
- how the finished piece is displayed or used where supported
- another meaningful product-specific detail

Do not simply repeat the specification table.

### Formatting rule

Normal paragraphs should normally contain plain text.

**Do not use `<strong>` or `<b>` inside ordinary `<p>` tags unless there is a genuine reason for emphasis.**

Do not use bold labels such as:

```html
<p><strong>Perfect for:</strong> ...</p>
```

Write the information naturally instead.

---

# Useful sections

Keep the structure proportional to the product.

Where supported, useful sections may include:

## How Does Crystal Art Work?

Use a short `<h3>` and a concise ordered/unordered list explaining the verified process.

Do not invent application techniques, completion times or difficulty.

## What's Included

Use a `<h3>` and `<ul>` when exact contents are supplied.

List exact quantities where known.

Do not assume all Crystal Art kits contain the same items.

---

# Product specifications table

When useful structured product facts are supplied, include a purple Cromartie specification table using the styling guidance.

Useful rows may include:

- Product type
- Design
- Size
- Format
- Finished dimensions
- Included contents
- Age guidance
- Packaging
- Artist/licence information

Only include rows supported by the exact product evidence.

Do not create filler rows.

Do not repeat every table value in the paragraphs or lists.

---

# Artwork / licensing information

If the supplier record provides an artist, artwork-rights or licensing statement, include it accurately and concisely where useful.

Do not invent:

- exclusivity
- official licensing
- copyright ownership
- trademark status

Preserve supplied wording where legally meaningful.

---

# Internal links

Use supplied links only when they genuinely help the customer continue browsing.

Use a maximum of two.

Prefer the Cromartie purple CTA button styles from the CMS guidance.

Do not over-link or use generic anchors such as `click here`.

---

# Factual safeguards

Do not invent:

- dimensions
- materials
- contents
- frame/support type
- adhesive type
- crystal quantity
- colours included
- age suitability
- difficulty
- completion time
- safety information
- sustainability claims
- mounting method
- licensing
- stock status
- packaging
- display method

If information is missing, omit it.

Sparse evidence should result in **shorter accurate copy**, not fabricated detail.

---

# Image metadata

Return one **Name, Title and Alt** value for each of the first `{{IMAGE_COUNT}}` images.

## Name

A clean CMS display name:

- no filename extension
- product-specific
- useful
- concise

## Title

Describe the product/view naturally.

## Alt

Accessibility-focused description of what is genuinely visible.

Name, Title and Alt must be meaningfully different for the same image.

Where multiple images exist, distinguish them using genuine visible differences such as:

- finished design
- packaging
- supplied kit contents
- close-up detail
- framed/display view
- reverse/side view

Do not mechanically label them `Image 1`, `Image 2`, etc.

Do not use:

- `image of`
- `picture of`
- `product image`
- unsupported copyright/licence claims

---

# Final verification

Before answering, internally verify:

- all factual claims are supported
- exact `PRODUCT_NAME` audit value is unchanged
- exact `IMAGE_COUNT` is preserved
- every requested image has exactly one Name/Title/Alt group
- product name/title/description target the exact product rather than a broad category
- design-specific wording is included where evidence supports it
- copy is useful and human rather than generic
- normal paragraphs do not contain unnecessary `<strong>`/`<b>`
- HTML follows the Cromartie CMS styling guidance
- structured facts use the specification table where useful
- lists and tables do not unnecessarily duplicate each other
- links are supplied links only
- every `<a>` contains a descriptive `title`
- no citations, source tokens, placeholders or internal notes remain
- UK English is used

---

# Strict automation output

Return exactly one block between the markers below.

Do not put the complete automation block inside a Markdown code fence.

Do not write anything before or after it.

===AUTOMATION_OUTPUT_START===

MODE:
CRYSTAL_ART_PRODUCT_CREATION

PRODUCT_NAME:
{{PRODUCT_NAME}}

IMAGE_COUNT:
{{IMAGE_COUNT}}

PRODUCT_NAME_RECOMMENDATION:
[one-line recommended customer-facing product name]

META_TITLE:
[one-line SEO meta title]

META_DESCRIPTION:
[one-line SEO meta description]

HTML_SNIPPET:
[complete multiline CMS-ready HTML]

{{IMAGE_AUTOMATION_OUTPUT_FIELDS}}

===AUTOMATION_OUTPUT_END===
