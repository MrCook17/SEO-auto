# Cromartie Tools Department Page Optimisation

Optimise this **Cromartie Potters' Tools & Accessories department page**.

This prompt is **only for department/category pages**. Never treat the page as an individual product page.

This request is part of an automated workflow.

**Do not remove, rename, reorder or move any existing automation input or output field.**

The existing `PRODUCT_NAME` / `PRODUCT_NAME_RECOMMENDATION` fields must remain for automation compatibility, but in this prompt they mean:

- `PRODUCT_NAME` = current department name / H1
- `PRODUCT_NAME_RECOMMENDATION` = recommended department name / H1

---

# Required guidance files — read these first

Before writing anything, read all three files:

## SEO source of truth

- `cromartie_tools_department_seo_workbook_usage_guide.md`
- `cromartie_tools_department_seo_workbook.xlsx`

## HTML styling source of truth

- `cromartie_colour_glaze_cms_style_guide.md`

The Colour & Glaze name of the styling guide is irrelevant here. Use it as the **styling and HTML-formatting source of truth for Tools department pages**.

Do not substitute older prompts, remembered CSS or invented styling when the guide provides a rule.

---

# SEO workbook workflow — mandatory

Use `{{PAGE_URL}}` to identify the exact department.

Then follow the workbook workflow:

1. Match the exact URL in `Department Inventory`.
2. Identify its `TOOLS-###` Department ID.
3. Read the matching row in `Department SEO Guidance`.
4. Read **all** matching rows in `Keyword Map`, including:
   - Primary
   - Secondary
   - Supporting
   - Avoid

5. Check every relevant entry in `Cannibalisation`.
6. Check `SERP Analysis` for search intent and terminology.
7. Check `Internal Linking`.
8. Use `Optimisation Priority` only as context, not to override ownership.

If guidance appears to conflict:

- verify the exact URL and Department ID first
- `Keyword Map` and `Cannibalisation` take precedence for keyword ownership

Do not assign another department's primary keyword to this page.

Do not turn `Avoid` keywords into H1, title or primary targets.

---

# Important SEO rules

The SEO needs to be strong, but natural.

Use:

- the assigned **Primary** keyword as the main targeting direction
- **Secondary** keywords selectively
- **Supporting** terminology naturally
- `Avoid` terms only where unavoidable in normal language and never as a targeting focus

Do not flatten all workbook keywords into one list.

Do not keyword-stuff.

The page must satisfy the actual department's commercial search intent rather than merely maximise keyword usage.

Department pages should target:

- category intent
- tool-type intent
- relevant broader buying intent assigned to that page

They should **not** target:

- exact individual product names
- model numbers
- sizes/SKUs belonging to products
- another department's primary theme

Keep parent/child ownership clear.

---

# Factual source policy

SEO evidence is **not automatically product/category fact evidence**.

Use these as factual sources:

1. Current department name
2. Current meta data
3. Current HTML/content supplied below
4. Additional product/department notes
5. Image notes and what is genuinely visible in supplied images
6. Clearly factual approved category information contained in the supplied inputs

The SEO workbook may tell you:

- what customers search for
- keyword ownership
- search intent
- content topics to cover
- useful terminology
- internal-link direction

It must **not** be used to invent:

- materials
- dimensions
- compatibility
- pack sizes
- brands stocked
- exact tool uses
- manufacturing details
- technical specifications
- safety information
- product availability

If a workbook topic suggests useful content but the supplied factual information does not support the claim, omit or phrase it at a suitably general category level.

Do not browse `{{PAGE_URL}}`. It is used to match the correct workbook row only.

---

# Automated inputs — keep exactly as supplied

PAGE URL:
{{PAGE_URL}}

PRODUCT NAME:
{{PRODUCT_NAME}}

CURRENT META TITLE:
{{CURRENT_META_TITLE}}

CURRENT META DESCRIPTION:
{{CURRENT_META_DESCRIPTION}}

CURRENT HTML/PRODUCT DESCRIPTION:

```html
{{CURRENT_HTML_SNIPPET}}
```

RECOMMENDED INTERNAL LINKS:

===RECOMMENDED_INLINKS_START===
{{REQUIRED_INTERNAL_LINKS}}
===RECOMMENDED_INLINKS_END===

IMAGE NOTES:
{{IMAGE_NOTES}}

ADDITIONAL PRODUCT NOTES:

===ADDITIONAL_NOTES_START===
{{ADDITIONAL_PRODUCT_NOTES}}
===ADDITIONAL_NOTES_END===

---

# Required outputs

Create:

1. Department name / H1 recommendation
2. SEO meta title
3. SEO meta description
4. Complete CMS-ready department HTML
5. Accurate department image title
6. Accurate department image alt text

Do not add new automation fields.

---

# Department name recommendation

Treat `PRODUCT_NAME_RECOMMENDATION` as the recommended **department name/H1**.

The recommendation should:

- match the page's assigned primary keyword where natural
- accurately describe the department
- remain customer-friendly
- avoid unnecessary repetition
- avoid forcing secondary keywords into the H1
- preserve the existing name if it is already the best option

Return:

`KEEP CURRENT`

when the existing department name should remain unchanged.

---

# Meta title

Create a strong ecommerce category title.

Requirements:

- align with the workbook's primary keyword ownership
- accurately describe this department
- distinguish it from neighbouring Tools departments
- do not target another page's primary keyword
- use secondary terminology only when genuinely useful
- no keyword stuffing
- do not include SKUs or individual products
- ideally no more than 60 characters
- never more than 65 characters unless unavoidable

Do not append `Cromartie` unless there is a clear project-specific reason.

---

# Meta description

Create a natural commercial meta description that explains:

- what type of tools/products the department contains
- the customer use or buying context
- a useful differentiator where factual

Requirements:

- target the actual search intent
- use the primary keyword naturally where practical
- include a secondary term only if it improves the copy
- make it useful enough to encourage a click
- do not produce a list of keywords
- do not invent range facts
- ideally no more than 160 characters
- never more than 170 characters

Make it sound human rather than formulaic.

---

# CMS HTML — department page only

Follow `cromartie_colour_glaze_cms_style_guide.md`.

Use this wrapper:

```html
<div
  style="font-family: Open Sans, sans-serif; font-size:15px; line-height:1.65; color:#444;"
></div>
```

Use inline CSS only.

Do not include:

- `<html>`
- `<head>`
- `<body>`
- `<style>`
- `<h1>`

The department/H1 recommendation is returned through `PRODUCT_NAME_RECOMMENDATION`.

Inside the snippet, use a styled `<h2>` based on the CMS guide:

```html
<h2
  style="color:#76689A; text-align:center; margin-bottom:14px; font-size:2rem; font-weight:700;"
>
  [Useful department-level heading]
</h2>
```

The H2 should support the page topic without simply duplicating the H1 word-for-word.

---

# Main copy quality

The department description must be:

- useful
- specific
- enjoyable to read
- human-sounding
- factually accurate
- SEO-aware without sounding SEO-written

The customer should understand:

- what type of tools are in this department
- what they are generally used for
- which types of pottery/ceramic tasks they help with where factual
- how different tool types within the department differ where useful
- what to consider when choosing between them
- how this department relates to broader or neighbouring tool categories where appropriate

Do not write vague filler such as:

> Explore our great range of high-quality pottery tools for all your creative needs.

Prefer practical customer information.

---

# Recommended content structure

Keep the structure flexible.

A strong department page will commonly use:

1. One styled H2
2. Two or three useful introductory/customer paragraphs
3. One additional buying/use section where the category benefits from it
4. A concise list or panel where genuinely useful
5. One or two internal-link CTAs

Do not add elements just because the template supports them.

A simple department may only need:

- H2
- two strong paragraphs
- useful CTA(s)

A technically broader department may benefit from:

- `Choosing the Right...`
- `What Are ... Used For?`
- `Types of ...`
- short practical buyer guidance

Only add headings whose content genuinely helps the customer.

---

# Intro paragraphs

Use the centred paragraph style from the CMS guide where appropriate:

```html
<p style="max-width:900px; margin:0 auto 14px; text-align:center;">...</p>
```

## Paragraph 1

Introduce:

- the department
- its main purpose
- the workbook's primary keyword naturally

It must immediately tell the customer what they will find on the page.

## Paragraph 2

Give useful category context, such as:

- common uses
- differences between tool types
- stages of pottery making they support
- selection considerations

Use only facts supported by the supplied information.

## Paragraph 3

Optional.

Use it only when it adds:

- useful buying guidance
- application context
- a natural internal-link lead-in
- another genuinely helpful distinction

Do not add a third paragraph merely for word count.

---

# Useful customer content

Where supported, favour useful department-level information such as:

- what the tool category is used for
- differences between common tool formats
- which type may suit a particular pottery task
- practical choosing considerations
- how related tool categories differ

Keep this at **department level**.

Do not turn the page into:

- a long tutorial
- an individual product description
- an SEO article

Unless the workbook specifically identifies a useful informational question that naturally supports buying intent.

---

# Lists

Use lists only where they make information easier to scan.

Follow the style guide:

```html
<ul style="max-width:850px; margin:0 auto 18px; padding-left:24px;">
  <li>...</li>
</ul>
```

Good list uses include:

- common tool uses
- buyer considerations
- types available within the category
- practical differences

Do not repeat the same information already explained in paragraphs.

---

# Soft purple information panel

Use at most one where a useful piece of buying advice deserves emphasis.

Follow the exact style direction from the CMS guide.

Do not add one merely for decoration.

---

# Specification tables

This is a **department page**, so do not automatically create a product-style specification table.

Only use a table when there are genuinely useful facts that are:

- verified
- consistent across the entire department
- useful for comparing/understanding the category

Do not invent a table from keyword research.

If there are no meaningful department-wide specifications, omit it.

---

# Internal links

First inspect:

===RECOMMENDED_INLINKS_START===
{{REQUIRED_INTERNAL_LINKS}}
===RECOMMENDED_INLINKS_END===

Use these manually supplied links first when relevant.

Also check the workbook's `Internal Linking` sheet.

Rules:

- use no more than two links in normal circumstances
- do not invent URLs
- exact URLs present in the workbook may be used when they are clearly assigned to this department
- manually supplied links take priority where relevant
- reinforce correct parent/child/sibling ownership
- do not create cannibalisation
- do not repeat child category links already handled by the CMS unless there is a strong customer reason
- every `<a>` must have a descriptive `title`
- avoid generic `click here` wording

Prefer the purple CTA styling from the style guide for links near the end.

---

# CTA styling

Use the style guide's CTA structure.

Primary:

```html
<a
  href="[URL]"
  title="[descriptive title]"
  style="flex:1 1 260px; display:block; padding:16px 0;
         background:linear-gradient(90deg,#76689A 0%, #9d8dc2 100%);
         color:#fff; text-align:center; font-weight:700; font-size:1.05rem;
         border-radius:8px; text-decoration:none;"
>
  [CTA text]
</a>
```

Use the reversed gradient for a second CTA where appropriate.

Do not add CTA buttons without a genuine navigation purpose.

---

# Existing content

Do not discard useful current content merely to make the page look newly written.

Preserve and improve:

- factual category explanations
- genuinely useful customer guidance
- relevant terminology
- important distinctions

Remove/rewrite:

- generic filler
- keyword stuffing
- duplicated wording
- obsolete SEO-style copy
- product-level content that does not belong on a department page
- content targeting another department's keyword ownership

The final page should read as one coherent human-written description.

---

# Additional notes

Use:

===ADDITIONAL_NOTES_START===
{{ADDITIONAL_PRODUCT_NOTES}}
===ADDITIONAL_NOTES_END===

as approved factual/editorial input.

Despite the automation field being called `ADDITIONAL_PRODUCT_NOTES`, treat it as **additional department notes** in this prompt.

Do not extend supplied facts through unsupported assumptions.

---

# Image SEO

This prompt must **not generate, edit or recreate images**.

Only create text metadata.

Use:

{{IMAGE_NOTES}}

and what is genuinely visible in the supplied department image.

## Image title

Create a natural department-level image title.

It should:

- accurately identify the visible subject
- use relevant department terminology naturally
- avoid keyword stuffing
- not simply duplicate the alt text

## Image alt

Write accessibility-first alt text.

Describe what is genuinely visible.

Do not:

- list SEO keywords
- invent tool types not visible
- infer materials/specifications
- claim the image represents the full department if it only shows certain items

Title and alt must be meaningfully different.

---

# Human writing rules

The final copy must not read like templated AI SEO content.

Avoid repeated phrases such as:

- Explore our range...
- Whether you're a beginner or professional...
- Perfect for...
- Ideal for...
- Elevate your pottery...
- Take your creativity to the next level...
- Everything you need...
- High-quality tools...

unless the wording is genuinely justified.

Prefer:

- specific terminology
- practical explanations
- natural sentence variation
- clear customer value
- concise buying context

SEO should come from correct topic coverage and keyword ownership, not repetition.

---

# Final SEO QA

Before producing the automation block, internally verify:

- exact `PAGE_URL` matched one workbook department
- correct `TOOLS-###` ID was used
- correct Primary keyword was identified
- Secondary terms were used selectively
- Supporting terms were natural
- no Avoid keyword became a primary target
- relevant Cannibalisation guidance was followed
- SERP intent matches a department/category page
- title, description and H2 do not compete with another department
- current factual content was preserved where useful
- no product/category facts were invented from SEO data
- content is useful to actual customers
- content reads naturally in UK English
- HTML follows the CMS style guide
- no `<h1>` is inside HTML
- links are limited and useful
- every link has a `title` attribute
- no source citations/tokens appear in HTML
- image title/alt describe the actual image
- no image was generated or modified

---

# Automation output contract — keep exactly as-is

Return only the following automation block.

Do not add commentary before or after it.

Do not:

- rename fields
- reorder fields
- add fields
- remove fields

`PRODUCT_NAME_RECOMMENDATION` is the **department name/H1 recommendation** for this department-page workflow.

===AUTOMATION_OUTPUT_START===
PRODUCT_NAME_RECOMMENDATION:
[exact department name recommendation or KEEP CURRENT]

META_TITLE:
[exact meta title only]

META_DESCRIPTION:
[exact meta description only]

HTML_SNIPPET:

```html
[exact CMS-ready department HTML snippet only]
```

IMAGE_1_TITLE:
[exact image title only]

IMAGE_1_ALT:
[exact image alt text only]
===AUTOMATION_OUTPUT_END===
