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

### Product content and customer-usefulness authority

- `cromartie_pottery_tools_product_page_optimisation_rules.md`

Read this document **in full every time before drafting the response**, even when the product appears simple.

It is the source of truth for:

- deciding how much content the product actually needs
- customer usefulness and practical-use coverage
- purpose-led H2s
- whether a specification table is justified
- pottery-stage and application wording
- recognised alternative terminology
- avoiding circular explanations, filler and repeated CMS information
- keeping secondary uses secondary

Do not rely only on the shortened rules in this prompt. Use the full document as additional context before returning any product optimisation.

### CMS styling authority

- `cromartie_flexible_cms_styling_guidance_updated.md`

The CMS styling guide is the **source of truth for HTML structure and formatting**. Follow it closely rather than improvising markup.

---

# Source precedence

## SEO

```text
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

```text
Current supplied product information
↓
Additional verified notes
↓
Visible image evidence / image notes
↓
SEO guidance
```

SEO keywords do not prove product specifications.

## Content structure and usefulness

The `cromartie_pottery_tools_product_page_optimisation_rules.md` document governs content depth, customer usefulness, H2 purpose, specification-table decisions, terminology, ambiguity and when concise copy is preferable.

If an example elsewhere in this prompt conflicts with that document on those points, follow the product optimisation rules document.

The CMS styling guide remains the authority for HTML structure and formatting.

The automation input/output contract in this prompt must still be followed exactly.

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
11. Read `cromartie_pottery_tools_product_page_optimisation_rules.md` in full and classify the product's required content depth before drafting.

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

```html
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

The page should clearly explain, where the verified information genuinely supports it:

- what the product is
- its practical job
- when or at what pottery stage it is used, where relevant and verified
- its strongest useful verified differentiator
- how that differentiator affects use or selection **only when that relationship is supported**
- useful buying or selection context
- important verified specifications
- important limitations or compatibility information
- how it differs from nearby alternatives where supported

Do not force every point into every product. A simple tool with sparse verified information may only need a clear purpose-led H2 and one or two useful paragraphs.

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

### Core writing test

Every sentence should do at least one useful job:

- explain what the tool helps the customer do
- clarify when or how it is used
- explain a verified selection difference
- provide a useful verified specification
- state a relevant limitation or compatibility point
- introduce recognised terminology that helps the customer identify the tool

Avoid circular wording.

Weak:

> The 150 grit grade clearly identifies this as the 150 grit version.

Better, **only where the practical relationship is verified**:

> The 150 grit abrasive surface is intended for smoothing and refining the relevant surface by hand.

Do not describe a feature's supposed benefit merely because the feature exists. If the practical significance is not verified, state the feature once and move on.

Do not automatically repeat pack quantity, price-per-item or other information already made clear by the CMS. Repeat it only when it prevents genuine purchasing confusion.

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
- relevant pottery stage or working condition
- recognised alternative terminology
- compatibility
- practical limitation
- pack quantity only where it prevents confusion or materially affects the buying decision

Do not force two paragraphs when the available facts only support one strong paragraph.

Do not create dry filler simply to reach a paragraph count.

---

# HTML styling rules — follow strictly

Use `cromartie_flexible_cms_styling_guidance_updated.md` as the styling authority.

Start with:

```html
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

Use one useful **purpose-led** `<h2>` with the exact styling from the CMS guide. It should normally explain the job, use or application rather than restating the product name.

---

# Do not over-format normal paragraphs

Normal product copy should normally be plain `<p>` text.

**Do not put `<strong>` or `<b>` tags inside ordinary paragraphs unless there is a genuine semantic reason.**

Do not write things like:

```html
<p><strong>Perfect for:</strong> smoothing pottery...</p>
```

or:

```html
<p><b>Key benefit:</b> helps remove excess clay...</p>
```

Instead write natural prose:

```html
<p>
  This abrasive scrubber can be used to smooth clay surfaces and remove excess
  material before finishing.
</p>
```

Use `<strong>` only where the CMS styling guide specifically supports it, such as a genuine short note:

```html
<p style="margin-top:10px; font-size:0.95rem; color:#555;">
  <strong>Note:</strong> [important verified note]
</p>
```

Do not use bold formatting as a substitute for good sentence structure.

---

# H2

Use one descriptive **purpose-led** H2.

The H1/product name already answers **what is it?**

The H2 should normally answer **what is it useful for?**

Good patterns include:

- `For Smoothing and Surface Clean-Up`
- `For Trimming and Shaping Clay`
- `For Applying and Controlling Glaze`
- `For Fine Detail and Decorative Work`
- `For Cutting and Working Clay`

Only include uses verified for the actual product.

Do not create a second keyword-heavy version of the product title.

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

A specification table is **optional, not mandatory**.

Use the Cromartie purple specification table from the styling guide only when structured facts genuinely help the customer understand, compare or select the product.

As a general guideline, use a table when there are **at least three useful independently verified specifications**. This is not an absolute rule:

- two rows may justify a table if both are especially important to selection
- four or more rows may still not justify a table if they merely repeat obvious information

Potential useful rows include:

- Size
- Dimensions
- Material
- Shape/profile
- Grit
- Model/range
- Capacity
- Measurement range
- Compatibility
- Tool type where it adds useful clarification
- Pack quantity where it materially affects selection or prevents confusion

Do not create a table merely because other Cromartie products have one.

Do not create filler rows.

Do not repeat information already obvious from the product name or prominently displayed by the CMS unless repeating it genuinely improves purchasing clarity.

Only include facts actually supplied or verified.

The prose should explain **why or when the product is useful**.

The table should make **meaningful structured facts easy to check**.

If there are too few useful verified specifications, omit the table and keep the page clean.

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

Do not infer an unverified pottery stage, working condition or suitability such as wet clay, leather-hard clay, greenware, bisque, glazed ware or fired ceramic.

Avoid ambiguous claims such as `removes glaze`, `for finishing pottery` or `suitable for ceramics` when the verified source supports a more precise description.

Where the stage or condition is verified, state it clearly.

Do not invent the practical benefit of a material, shape, grit, mechanism or other attribute. Explain its significance only when supported or objectively established by the supplied information.

If source information is sparse, keep the copy concise.

---

# Product complexity and content depth

Classify the product before drafting.

## Level 1 — Minimal

Use for very simple products with little verified information.

Typical output:

- purpose-led H2
- one or two concise useful paragraphs
- no specification table unless genuinely justified

## Level 2 — Standard

Use when several useful verified facts or selection points are available.

Typical output:

- purpose-led H2
- two or three concise paragraphs
- specification table if it adds real value
- relevant compatibility, stage or selection information where supported

## Level 3 — Detailed

Use when the product is technical or incorrect selection is plausible.

Typical output:

- fuller practical explanation
- useful specification table
- selection or compatibility guidance
- verified limitations

## Level 4 — Technical Equipment

Use for complex or high-value equipment where technical specifications, setup, compatibility or safety materially affect purchase.

Do not make a simple inexpensive hand tool look artificially complex merely to match the structure of a technical product.

---

# Recognised terminology, repetition and secondary uses

Use genuine alternative pottery terminology naturally where it helps recognition or search understanding.

Do not stack synonyms or repeat them for keyword density.

Avoid circular explanations that merely restate an attribute.

Do not automatically repeat CMS information such as pack size, price per item or stock status.

Keep valid non-pottery uses secondary to the main pottery application.

Do not add generic closing boilerplate such as:

- A useful addition to any pottery studio.
- Ideal for beginners and professionals.
- A must-have tool for ceramic artists.

Finish the description when the useful information is complete.

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

The finished description should be **more useful, clear and natural**, not merely longer.

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

- `cromartie_pottery_tools_product_page_optimisation_rules.md` was read in full
- correct Product ID / Parent Department / Cluster used
- product keyword does not steal parent ownership
- sibling cannibalisation considered
- product complexity/content depth is appropriate
- useful verified differentiator used where one genuinely exists
- no invented facts or SEO metrics
- paragraphs explain practical customer value
- relevant pottery stage or working condition is precise where verified
- no ambiguous use claim has been made more specific than the evidence supports
- H2 is purpose-led rather than a rewritten product title
- recognised terminology is used naturally, not stuffed
- copy contains no circular or obvious filler
- CMS information is not repeated without a reason
- copy is not dry or specification-only
- paragraphs do not contain unnecessary `<strong>` or `<b>`
- HTML follows the CMS styling guide
- lists are used only where useful
- a specification table is used only when it adds genuine purchasing value
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
- Product specification table used: [Yes/No + brief reason]
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

```html
[exact CMS-ready HTML snippet only]
```

IMAGE_1_TITLE:

[exact image title only]

IMAGE_1_ALT:

[exact image alt text only]

===AUTOMATION_OUTPUT_END===
