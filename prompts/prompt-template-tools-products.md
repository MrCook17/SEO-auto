# Cromartie Tools Product Page Optimisation — Full Automation Mode

Optimise this **individual Cromartie Potters' Tools & Accessories product page**.

This prompt is only for **Tools product pages**, not department pages.

## Critical automation rule

Keep every automated input and output field exactly as supplied.

Do not rename, remove, add or reorder automation fields.

---

# Required project files — read first

Read these every time before writing:

### Department SEO authority

- `cromartie_tools_department_seo_workbook.xlsx`
- `cromartie_tools_department_seo_workbook_usage_guide.md`

### Product SEO authority

- `cromartie_tools_product_page_seo_guidance_workbook.xlsx`
- `cromartie_tools_product_page_seo_guidance_workbook_usage_guide.md`

### CMS styling authority

- `cromartie_flexible_cms_styling_guidance_updated.md`

The CMS styling guide is the **source of truth for HTML structure and formatting**. Follow it closely rather than improvising markup.

---

# Source precedence

## SEO

```text id="tc5l3z"
Tools Department Workbook
↓
Tools Product Workbook
↓
Exact Product Guidance
```

The department workbook owns broad category intent.

The product workbook owns narrower exact-product targeting.

Never make an individual product compete with its parent department for the broad department keyword.

## Facts

```text id="9qfvpm"
Current supplied product information
↓
Additional verified notes
↓
Visible image evidence / image notes
↓
SEO guidance
```

SEO keywords do not prove product specifications.

---

# Required SEO workflow

Use `{{PAGE_URL}}` to locate the exact product in the project workbooks. Do not browse the configured Cromartie URL.

Before writing:

1. Find the product in `Product Inventory`.
2. Identify its Product ID, Parent Department ID and Cluster ID.
3. Check the parent department's keyword ownership.
4. Read the product's `Product SEO Map` row.
5. Read its `Product Type Guidance`.
6. Read relevant `Keyword Research`.
7. Check `Cannibalisation`.
8. Check relevant `SERP Analysis`.
9. Check `Internal Linking`.
10. Check `Review Queue` where applicable.

Use:

- `Primary Candidate` as the exact-product direction
- `Secondary` selectively
- `Supporting` naturally
- `Avoid` as terms not to target

Do not invent SEO metrics.

If product and department guidance conflict, preserve the department's broad ownership.

---

# Automated inputs — do not alter

Configured Cromartie page URL (context only; do not browse it):

{{PAGE_URL}}

Current page/product name:

{{PRODUCT_NAME}}

Current meta title:

{{CURRENT_META_TITLE}}

Current meta description:

{{CURRENT_META_DESCRIPTION}}

Current HTML/product description snippet:

```html id="s84hvn"
{{CURRENT_HTML_SNIPPET}}
```

Recommended internal links:

===RECOMMENDED_INLINKS_START===
{{REQUIRED_INTERNAL_LINKS}}
===RECOMMENDED_INLINKS_END===

Image notes:

{{IMAGE_NOTES}}

Additional notes:

===ADDITIONAL_NOTES_START===
{{ADDITIONAL_PRODUCT_NOTES}}
===ADDITIONAL_NOTES_END===

---

# Task

Create:

1. SEO-optimised meta title
2. SEO-optimised meta description
3. CMS-ready HTML product description
4. Product name recommendation where worthwhile
5. Image title and alt text for every image required by the automation output

---

# SEO objective

Optimise the **exact tool being sold**.

The page should clearly explain:

- what the product is
- its practical job
- its strongest verified differentiator
- how that differentiator affects its use
- useful buying or selection context
- important verified specifications
- how it differs from nearby alternatives where supported

Useful differentiators may include verified:

- size
- material
- shape
- profile
- model
- pattern
- capacity
- grit
- pack quantity
- measurement range
- mechanism

Do not use a modifier purely because it makes a good keyword.

Broad department terms may appear naturally for context but must not become the product's main SEO focus.

---

# Product name

Recommend a change only where it improves:

- clarity
- exact-product search intent
- differentiation
- consistency

Keep genuine model/range/manufacturer terminology.

Do not add unsupported materials, uses, compatibility or marketing claims.

If the current product name is already suitable, keep it.

---

# Metadata

## Meta title

- exact-product focused
- based on Product SEO Map
- respect department ownership
- distinguish from sibling products
- use the strongest useful verified modifier
- no keyword stuffing
- no SKU unless specifically justified
- do not append `Cromartie`
- aim for under **60 characters**

## Meta description

- identify the exact product
- explain its main practical use
- mention a useful verified differentiator
- include another meaningful buying point where space permits
- factual and natural
- aim for under **160 characters**

---

# Writing style — important

The product description must read like useful ecommerce copy written by a knowledgeable person, not like an SEO template.

A good description should answer:

> What is this tool, what does it help me do, and why might I choose this particular version?

Use factual information to explain **purpose and practical value**, not merely repeat specifications.

### Good style example

A strong paragraph might read like:

> The Foam Backed Abrasive Scrubber 150 Grit is designed for cleaning, smoothing and refining clay pieces. Its abrasive surface can be used to remove excess slip, glaze or clay build-up, while the foam-backed format distinguishes it from standard pottery sponges and stipplers.

This works because it:

- immediately explains what the product does
- gives several genuine uses
- explains the significance of the product format
- differentiates it from nearby alternatives
- uses natural sentences rather than a list of SEO phrases

A useful second paragraph can then add another supported use, limitation, pack detail or selection point:

> The scrubber can also be used on wood where a 150 grit abrasive is required. Priced individually.

Do **not** copy this wording onto unrelated products. Match this level of usefulness and specificity.

---

# Paragraph rules

For most products, use **two useful paragraphs** when enough factual information exists.

## Paragraph 1

Usually cover:

- exact product type
- practical purpose
- strongest verified differentiator
- what tasks it helps with

Do not simply state:

> This is a pottery tool used for pottery.

Explain what the customer can actually do with it.

## Paragraph 2

Use for useful additional context such as:

- another verified use
- how this version differs from another type
- selection guidance
- size/material/profile relevance
- pack quantity
- compatibility
- practical limitation

Do not force two paragraphs when the available facts only support one strong paragraph.

Do not create dry filler simply to reach a paragraph count.

---

# HTML styling rules — follow strictly

Use `cromartie_flexible_cms_styling_guidance_updated.md` as the styling authority.

Start with:

```html id="w9fmpm"
<div
  style="font-family: Open Sans, sans-serif; font-size:15px; line-height:1.7; color:#444;"
></div>
```

Use inline CSS only.

Do not include:

- `<html>`
- `<head>`
- `<body>`
- `<style>`
- `<h1>`

Use one useful product-led `<h2>` with the exact styling from the CMS guide.

---

# Do not over-format normal paragraphs

Normal product copy should normally be plain `<p>` text.

**Do not put `<strong>` or `<b>` tags inside ordinary paragraphs unless there is a genuine semantic reason.**

Do not write things like:

```html id="dtjtuc"
<p><strong>Perfect for:</strong> smoothing pottery...</p>
```

or:

```html id="n4bs6h"
<p><b>Key benefit:</b> helps remove excess clay...</p>
```

Instead write natural prose:

```html id="xkb11w"
<p>
  This abrasive scrubber can be used to smooth clay surfaces and remove excess
  material before finishing.
</p>
```

Use `<strong>` only where the CMS styling guide specifically supports it, such as a genuine short note:

```html id="1adkf6"
<p style="margin-top:10px; font-size:0.95rem; color:#555;">
  <strong>Note:</strong> [important verified note]
</p>
```

Do not use bold formatting as a substitute for good sentence structure.

---

# H2

Use one descriptive product-led H2.

It should add context rather than merely repeating the exact product name.

For example:

```html id="u4s4he"
<h2
  style="color:#76689A; font-size:1.7em; font-weight:bold; margin-bottom:12px;"
>
  150 Grit Foam Backed Abrasive Scrubber for Clay Finishing
</h2>
```

Only include facts verified for the actual product.

Avoid headings such as:

- Product Details
- More Information
- Pottery Tool
- Key Features

---

# Lists

Use a `<ul>` only where it genuinely makes information easier to scan.

Useful cases include:

- set contents
- several distinct uses
- several compatibility points
- several selection considerations

Do not automatically create a list for every product.

If there are only one or two useful points, put them naturally into the paragraphs instead.

Do not duplicate paragraph or table information in a list.

---

# Specification table

Use the Cromartie purple specification table from the styling guide when **useful structured specifications are available**.

Potential rows include:

- Product type
- Size
- Dimensions
- Material
- Shape/profile
- Grit
- Model/range
- Capacity
- Measurement range
- Pack quantity
- Compatibility

Only include facts actually supplied or verified.

Do not add filler rows.

The specification table should support the prose, not replace it.

The prose should explain **why the product is useful**.
The table should make **structured facts easy to check**.

---

# Factual restrictions

Do not infer unverified:

- dimensions
- size
- material
- construction
- capacity
- grit
- graduations
- weight
- power/voltage
- fitting/thread
- handedness
- pack quantity
- accessories
- compatibility

Do not call a product:

- professional
- heavy-duty
- ergonomic
- durable
- precision-made
- stainless steel
- rust-resistant

unless supported.

Do not invent safety, care, maintenance or cleaning advice.

If source information is sparse, keep the copy concise.

---

# Internal links

Use only the manually supplied links where useful:

===RECOMMENDED_INLINKS_START===
{{REQUIRED_INTERNAL_LINKS}}
===RECOMMENDED_INLINKS_END===

Rules:

- maximum two
- `NONE` / `N/A` means do not invent links
- links are navigation, not factual evidence
- every `<a>` must have a descriptive `title`
- normally favour the parent department or relevant product family
- avoid unnecessary sibling-product links
- use the purple CTA styling from the CMS guide

Do not create filler copy simply to introduce a link.

---

# Existing content

Preserve useful verified details from the current page.

Improve:

- usefulness
- clarity
- SEO targeting
- natural flow
- differentiation
- grammar

Do not rewrite accurate useful content simply to make it sound different.

The finished description should be **more informative and engaging**, not merely longer.

---

# Image SEO

Create metadata only. Do not generate or edit images.

Use:

{{IMAGE_NOTES}}

and genuine visible evidence.

### Image title

Natural product-specific title.

### Alt

Concise description of what is genuinely visible.

Do not:

- keyword-stuff
- start with `image of`
- invent size/material/compatibility
- add sales claims

---

# Final quality check

Before responding verify:

- correct Product ID / Parent Department / Cluster used
- product keyword does not steal parent ownership
- sibling cannibalisation considered
- useful verified differentiator used
- no invented facts or SEO metrics
- paragraphs explain practical customer value
- copy is not dry or specification-only
- paragraphs do not contain unnecessary `<strong>` or `<b>`
- HTML follows the CMS styling guide
- lists/tables are used only where useful
- no duplicated paragraph/list/table information
- links have `title` attributes
- image metadata is accurate
- UK English is used

---

# Output format

Only return these visible sections before the automation block:

**Workbook / Guidance Row Used:**

- Product ID:
- Parent Department:
- Cluster:
- Primary product SEO direction:
- Manual Review status:

**Product Name Recommendation:**

[Keep current product name OR recommended new product name with reason]

**Notes:**

- Keyword ownership followed:
- Cannibalisation avoided by:
- Internal links used:
- Product specification table used:
- Content facts used:
- Any uncertainty:

Do not separately output Meta Title, Meta Description, HTML or Image SEO above the automation block.

---

# Automation output contract — DO NOT ALTER

Return this exact block at the end:

===AUTOMATION_OUTPUT_START===

PRODUCT_NAME_RECOMMENDATION:

[exact product name recommendation only]

META_TITLE:

[exact meta title only]

META_DESCRIPTION:

[exact meta description only]

HTML_SNIPPET:

```html id="xzi4n5"
[exact CMS-ready HTML snippet only]
```

IMAGE_1_TITLE:

[exact image title only]

IMAGE_1_ALT:

[exact image alt text only]

===AUTOMATION_OUTPUT_END===
