# Cromartie Figured'Art Product Creation

Create high-quality Cromartie product content and image metadata for one **Figured'Art paint-by-numbers product**.

This request is part of an automated workflow.

**Do not remove, rename, reorder or alter any automated input or output field.**

## Critical instruction — do not generate images

The supplied images are **reference images only**.

You must:

- inspect the attached images
- use them to understand what the product and artwork genuinely look like
- create text-only CMS image Name, Title and Alt metadata

You must **never**:

- generate a new image
- edit an image
- recreate an image
- enhance an image
- call an image-generation tool
- return image files
- return visual mock-ups

The only image-related output required is the existing text metadata:

- `IMAGE_n_NAME`
- `IMAGE_n_TITLE`
- `IMAGE_n_ALT`

---

# Factual source policy

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

Treat populated factual sections as authoritative for this exact product.

Consolidate repeated information naturally rather than copying supplier text mechanically.

The Source URL is provenance only. Do not browse it and do not include it in customer-facing content.

If `product.md` contains an Images section, **ignore it completely**. The actual attachments and attachment order in this request are authoritative.

Do not invent or infer unsupported:

- dimensions or finished size
- framed or unframed state
- canvas, support or wood-slice material
- wood-slice diameter
- paint type
- number of paint colours or pots
- brushes or tools
- hooks or screws
- kit contents
- difficulty
- recommended age
- safety or non-toxicity
- skill requirements
- packaging
- mounting method
- artist attribution
- copyright/licensing
- suitability for children
- drying time
- completion time
- stock
- price
- availability
- delivery

Visible subject matter, colours and composition **may** be described when genuinely clear in the supplied images.

For example, if the image clearly shows a parrot among tropical leaves, describe that visual scene naturally.

Do not turn a visual observation into a technical claim.

---

# Automated product inputs — do not alter

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

# Recommended internal links — manual input

Use only the following manually supplied internal links when genuinely useful:

===RECOMMENDED_INLINKS_START===

{{RECOMMENDED_INLINKS}}

===RECOMMENDED_INLINKS_END===

This area may contain up to two links or `NONE`.

Rules:

- These links are navigation suggestions, not factual product sources.
- Do not browse them.
- Do not infer product facts from their destinations.
- Do not invent replacement links.
- If `NONE`, do not add links.
- Use no more than two supplied links.
- Every `<a>` must have a descriptive `title` attribute.
- Use natural customer-facing CTA wording.
- Prefer the established purple Cromartie CTA styling.
- Do not add an unnecessary paragraph solely to contain a link.

# Additional notes — manual input

===ADDITIONAL_NOTES_START===

{{ADDITIONAL_NOTES}}

===ADDITIONAL_NOTES_END===

Use relevant supplied facts or editorial instructions without extending them through assumptions.

If this area contains `NONE`, there are no additional notes.

---

# Required content

Create:

- Product name recommendation
- SEO meta title
- SEO meta description
- Complete CMS-ready HTML product description
- A distinct CMS Name, Title and Alt value for each of the first `{{IMAGE_COUNT}}` attachments that will be entered into GO b2b

Use UK English throughout.

Use `colour`, not `color`, except where an exact proper name requires otherwise.

---

# Primary writing objective

The product description must be **interesting, useful, product-specific and commercially helpful**.

It should resemble the quality and depth of this approach:

> Explain exactly what the customer will paint, what physical kit they receive, what the supplied format is, how paint by numbers works, what the finished artwork looks like, and how it can be displayed where supported.

Do **not** produce thin descriptions where the first paragraph simply lists:

`subject + dimensions + easy difficulty`

and the second paragraph simply repeats the kit contents.

The page should help a customer answer:

- What am I buying?
- What does the artwork look like?
- What makes this particular design appealing?
- What format is supplied?
- What does the kit include?
- How do I actually use it?
- What can I do with the finished piece?
- Is it framed or display-ready, if verified?

Use the supplied images to make the **design-specific visual description** meaningful.

---

# Product terminology

Identify the exact product type from `product.md`.

Common Figured'Art products in this workflow include:

- mini framed paint-by-numbers kits
- framed canvas paint-by-numbers kits
- paint-by-numbers wood slice kits

These are examples, not universal facts.

Use accurate supported terminology such as:

- paint by numbers
- paint-by-numbers kit
- numbered canvas
- linen canvas
- framed canvas
- wooden frame
- wood slice
- acrylic paint
- numbered paint pots
- nylon brushes

Do not:

- call a wood-slice product a canvas kit
- call a canvas product a wood-slice kit
- describe a product as framed unless verified
- assume every Figured'Art product contains identical components

`Figured'Art` is the correct brand spelling.

Use the brand naturally. Do not force `Figured'Art` into every sentence.

---

# Product name recommendation

Recommend a clear, customer-friendly Cromartie product name based on the exact design and verified product format.

Useful patterns where supported include:

### Mini framed canvas

`[Design] Mini Paint by Numbers Kit 20 x 20cm - Framed`

### Wood slice

`[Design] Paint by Numbers Wood Slice Kit 30cm`

These are patterns, not mandatory templates.

Rules:

- Preserve the recognisable design identity.
- Make the product type obvious.
- Include size where verified and useful.
- Include framed state only where verified.
- Do not include the SKU by default.
- Avoid awkward supplier-style wording.
- Do not unnecessarily repeat `Figured'Art` if the cleaner customer-facing name works without it.
- If the current product name is already strongest, return `KEEP CURRENT PRODUCT NAME`.

The recommendation applies only to `PRODUCT_NAME_RECOMMENDATION`.

Do not mechanically copy its punctuation or word order into metadata, headings or image tags.

---

# SEO metadata

The product page should target the **exact design + paint-by-numbers product type + useful verified format/size information**.

Avoid turning every product into generic wording such as:

`paint by numbers kit`

without clearly identifying the exact design.

## Meta title

Create a concise, useful exact-product title.

Prioritise:

1. Design name
2. Paint by numbers
3. Important format such as framed/wood slice
4. Size where useful

Rules:

- Keep under 60 characters where practical.
- Do not include the SKU by default.
- Do not append `Cromartie`.
- Avoid keyword stuffing.
- Do not create an awkward list of synonyms.
- Make neighbouring Figured'Art products distinguishable in search results.

Possible natural patterns:

`Santorini Sunrise Mini Paint by Numbers Kit`

`Tropical Parrot Framed Paint by Numbers Kit`

`Lavender Paint by Numbers Wood Slice Kit`

Adapt naturally to the exact product.

## Meta description

Create a genuinely useful product-specific description.

Aim for roughly 140–155 characters where practical and remain under 160 characters where possible.

Use one or two strong verified selling points.

Possible angles include:

- the specific artwork/design
- framed canvas format
- wood-slice format
- numbered acrylic paints
- supplied brushes
- display-ready nature
- reference image
- straightforward paint-by-number process
- wall fixings

Do not try to fit every specification into the meta description.

Avoid repetitive range-wide formulas.

Do not start every product with `Shop`.

Avoid generic filler such as:

- perfect
- ideal
- stunning
- premium
- must-have
- endless creativity
- unleash your creativity
- fun for everyone

unless directly supported and genuinely useful.

The meta description should sound like it was written for **this artwork**, not generated from a single template for 30 products.

---

# CMS HTML styling

Use `cromartie_flexible_cms_styling_guidance_updated.md` where available as the HTML styling reference.

Use inline CSS only.

Use this wrapper:

```html
<div
  style="font-family: Open Sans, sans-serif; font-size:15px; line-height:1.7; color:#444;"
></div>
```

Do not include an `<h1>`.

The preferred structure is:

1. Product-specific `<h2>`
2. Two substantial product-specific paragraphs
3. `How Does Paint by Numbers Work?`
4. `What's Included`
5. Purple product specification table
6. Artist/rights note where supplied
7. Up to two supplied internal-link CTA buttons

Omit a section only when the required facts genuinely are not supplied.

---

# H2 quality

The H2 must explain the **product and design**, not merely describe the image poetically.

Prefer headings such as:

`Mini Framed Paint by Numbers Kit with Santorini Travel Poster Design`

`Mini Framed Paint by Numbers Kit with Tropical Parrot Design`

`Paint by Numbers Wood Slice Kit with Lavender Design`

Avoid weak headings such as:

`Paint a Colourful Parrot Among Tropical Leaves`

`Create Your Own Beautiful Artwork`

`Discover Tropical Creativity`

The H2 should immediately tell a customer **what the product is**.

Useful pattern:

`[Format/Product Type] with [Design/Subject]`

Do not simply repeat the H1/product name word-for-word.

---

# Main description — exactly two strong paragraphs

Write **two substantial `<p>` tags** before the instructional sections.

Each paragraph should do a different job.

Do not create a third normal description paragraph.

## Paragraph 1 — product, design and what the customer receives

The first paragraph should naturally introduce:

- Figured'Art where useful
- exact design name
- paint-by-numbers format
- verified size
- verified canvas/wood-slice/frame format
- the main activity
- one or two important verified kit components

Then help the customer picture the product.

A good opening style is:

> Bring [specific scene/design] to life with the Figured'Art [design] paint-by-numbers kit.

or another natural variation.

Do not use that exact sentence for every product.

The paragraph should feel specific to the artwork.

For example, when clearly visible, describe:

- architecture
- animals
- landscape
- flowers
- travel-poster styling
- recognisable landmarks
- dominant colours
- composition

Do not invent details that cannot genuinely be seen.

### Avoid

Thin wording like:

> Create a tropical scene. This is a 20 x 20cm paint-by-numbers kit with an easy difficulty level.

This wastes the paragraph on specifications without explaining why the design is interesting.

## Paragraph 2 — visual result, process and display

Use the second paragraph to expand on:

- what the finished artwork visibly depicts
- how the numbered system works
- use of the reference image
- matching numbered paint to numbered sections
- display/hanging details where verified

This should add useful buying context rather than repeating the first paragraph.

Where wall fixings are supplied, explain naturally that they can be used to display the finished artwork.

Where the product is a wood slice rather than framed canvas, adapt the paragraph accordingly.

Do not force framed-canvas wording onto other product formats.

---

# Design-specific writing

One of the most important requirements is that each Figured'Art description must feel specific to its artwork.

Use attached product images to identify visible details such as:

- main subject
- setting
- art style
- dominant visual features
- recognisable landmarks
- animals
- flowers/plants
- composition
- significant colours

For example, a Santorini design may genuinely support wording about:

- white buildings
- pink buildings
- blue domes
- sea
- pale sun
- travel-poster composition

A Tropical Parrot design should instead describe the actual parrot, foliage, branch, colour palette and composition visible in that artwork.

Do not reduce every design to:

`a colourful scene`

when more useful visible information exists.

Do not invent a story, location, species, landmark or object that is not clear.

---

# How Does Paint by Numbers Work?

When `product.md` supplies instructions, include:

```html
<h3
  style="color:#76689A; font-size:1.25em; font-weight:bold; margin:20px 0 10px;"
>
  How Does Paint by Numbers Work?
</h3>
```

Then use an ordered list.

Aim for approximately 3–5 useful steps.

Preserve the full practical meaning of the supplier information.

A strong structure is:

1. Familiarise yourself with the numbered design/reference image.
2. Match a numbered section to its corresponding numbered paint.
3. Paint the sections using the supplied brushes.
4. Complete and display the artwork where supported.

Make the wording natural and specific to the verified kit contents.

Do not add unsupported:

- preparation instructions
- drying instructions
- varnishing
- sealing
- cleaning
- safety guidance
- painting techniques

Avoid rewriting the steps into vague filler such as:

`Enjoy painting your masterpiece.`

The section should genuinely explain the process.

---

# What's Included

When supplied, use:

```html
<h3
  style="color:#76689A; font-size:1.25em; font-weight:bold; margin:20px 0 10px;"
>
  What's Included
</h3>
```

Then a concise `<ul>`.

Preserve exact supplied quantities.

For example, only where verified:

- 1 numbered linen canvas
- 3 different-sized nylon brushes
- numbered pots of acrylic paint
- miniature image/reference image
- 2 screws
- 2 wall hooks

Do not assume those contents apply to every Figured'Art product.

Do not include packaging here merely to make the list longer.

---

# Product specification table

When structured facts are available, include the purple Cromartie specification table.

For the common mini framed range, useful verified rows may include:

- Product code
- Method
- Design
- Size
- Support
- Frame
- Paint type
- Difficulty level
- Packaging

For wood-slice products, adapt the rows appropriately.

For example:

- Product code
- Method
- Design
- Diameter
- Support/material
- Paint type
- Difficulty
- Packaging

Do not use canvas-specific fields for a wood-slice product.

Do not create filler rows.

Do not duplicate the same value under several labels.

Use this styling:

```html
<div style="width:100%; overflow-x:auto; margin:0 0 18px;">
  <table
    style="width:100%; border-collapse:collapse; font-family:Open Sans, sans-serif; font-size:15px; line-height:1.6; color:#444; border:1px solid #ddd;"
  >
    <thead>
      <tr>
        <th
          style="background:#76689A; color:#fff; text-align:left; padding:10px 12px; border:1px solid #76689A; font-weight:bold;"
        >
          Specification
        </th>
        <th
          style="background:#76689A; color:#fff; text-align:left; padding:10px 12px; border:1px solid #76689A; font-weight:bold;"
        >
          Details
        </th>
      </tr>
    </thead>
    <tbody>
      [verified product-specific rows]
    </tbody>
  </table>
</div>
```

Row-label cells should follow this style:

```html
<th
  scope="row"
  style="text-align:left; padding:9px 12px; border:1px solid #ddd; background:#f7f4fb; color:#76689A; font-weight:bold;"
></th>
```

Value cells:

```html
<td style="padding:9px 12px; border:1px solid #ddd;"></td>
```

---

# Artist / artwork rights

When exact artist or rights information is supplied in `product.md`, preserve it.

Use the clearer format:

```html
<div style="margin:0 0 18px; font-size:0.95rem; color:#555;">
  <strong>Artwork rights:</strong> Exclusive rights © [exact supplied name].
</div>
```

Do not use an extra `<p>` solely for this note.

Do not invent:

- artist names
- copyright owners
- rights statements
- dates
- URLs

---

# Internal links

Use only supplied links.

Where one or two relevant destinations are supplied, prefer the established purple CTA buttons near the end.

Primary CTA style:

```html
<a
  href="[URL]"
  title="[descriptive title]"
  style="display:block; text-align:center; background:linear-gradient(135deg,#8B7CC8,#76689A); padding:12px 16px; border-radius:6px; color:#fff; text-decoration:none; margin-bottom:12px; font-weight:bold;"
>
  [CTA text]
</a>
```

Secondary CTA may use:

```text
linear-gradient(315deg,#8B7CC8,#76689A)
```

Do not:

- invent links
- browse destinations
- create a long list
- insert unnecessary paragraphs just to contain links
- use generic anchor text such as `Click Here`

---

# Copy quality rules

The finished HTML should be comparable in usefulness to a carefully written ecommerce product page.

Before finalising, ask internally:

### Could the first two paragraphs be reused almost unchanged for another Figured'Art design?

If yes, they are too generic. Rewrite them.

### Does the H2 explain what the product actually is?

If no, rewrite it.

### Have specifications replaced useful customer-facing copy?

If yes, move routine facts into the table and strengthen the paragraphs.

### Does the page explain the visible artwork?

If images clearly support more detail, use that detail.

### Does it explain the paint-by-numbers workflow?

If instructions are supplied, make the ordered list genuinely useful.

### Does the page answer why someone would choose this design?

Use the distinctive visible subject/style rather than generic claims.

---

# Avoid deteriorating/template-like copy

Avoid repeated structures such as:

> Create a [colour] scene featuring [subject]. This Figured'Art kit uses a 20 x 20cm canvas and has an easy difficulty level.

Avoid making `difficulty level` a major selling sentence unless there is a product-specific reason.

Avoid:

> The kit includes paints and brushes. Once completed, it can be displayed.

when substantially richer supplied information allows a better explanation.

Instead combine the verified facts into natural buying context.

Do not artificially lengthen the page.

The goal is **specificity and usefulness**, not word count.

---

# Image metadata

Process the first `{{IMAGE_COUNT}}` images in the exact attachment order.

Do **not generate, recreate or modify any images**.

For every processed GO b2b image return:

- `IMAGE_n_NAME`
- `IMAGE_n_TITLE`
- `IMAGE_n_ALT`

## IMAGE_n_NAME

Create a clean human-readable CMS image name.

It must:

- start with the verified Figured'Art product code from `product.md`
- contain no file extension
- identify the design
- distinguish what the image actually shows

Examples:

`SFA137-Y Santorini Sunrise Paint by Numbers Artwork`

`SFA137-Y Santorini Sunrise Kit Contents`

`RFA013 Lavender Wood Slice Paint by Numbers Design`

Use terms such as:

- Artwork
- Kit Contents
- Framed Canvas
- Paint Pots
- Brushes
- Packaging
- Reference Image
- Wood Slice
- Finished Design

only when genuinely visible.

## IMAGE_n_TITLE

Create concise natural image title text.

- Describe the visible image.
- Include the design name.
- Include product format where useful.
- Do not force the SKU into every title.
- Do not simply duplicate the image name.

## IMAGE_n_ALT

Write accessibility-first alt text describing the actual visible image.

Where useful describe:

- artwork subject
- visible format
- visible colours
- kit components
- frame
- wood slice
- numbered design

Do not keyword-stuff.

Do not add unsupported specifications.

Do not call something:

- packaging
- canvas
- framed
- wood slice
- paint pots
- brushes
- fixings
- finished artwork

unless genuinely visible.

## Distinctness

For every processed image:

- Name must be present.
- Title must be present.
- Alt must be present.
- All three must be meaningfully distinct.
- Title and Alt must not be exact duplicates.

---

# Attachment authority — do not alter

There are `{{ATTACHMENT_IMAGE_COUNT}}` actual ChatGPT attachments.

`IMAGE_COUNT` must still equal `{{IMAGE_COUNT}}`, because GO b2b accepts only the first `{{IMAGE_COUNT}}` image records.

Use later attachments as product-reference context only.

Do not return `IMAGE_n_NAME`, `IMAGE_n_TITLE` or `IMAGE_n_ALT` for attachments numbered above `{{IMAGE_COUNT}}`.

The attachment order is:

{{IMAGE_ORDER}}

Return image fields for exactly the first `{{IMAGE_COUNT}}` attachments.

Do not use an Images list inside `product.md` to change:

- output count
- order
- filenames
- fields

---

# Final QA

Internally verify:

- `PRODUCT_NAME` exactly echoes the GO b2b input.
- `IMAGE_COUNT` is unchanged.
- No image has been generated, edited or recreated.
- Product code matches `product.md`.
- Correct product type is used.
- Canvas and wood-slice terminology are never mixed.
- Framed state is used only when verified.
- Size is used only when supplied.
- Kit contents are exact.
- Design-specific visual details come only from clear image evidence or supplied text.
- H2 states what the product is rather than using a vague creative slogan.
- First two paragraphs are specific to this design.
- First two paragraphs contain useful buying information rather than mostly specifications.
- How Does It Work is included when supplied.
- What's Included is included when supplied.
- Specification table contains only verified facts.
- Artist/rights information is accurate where supplied.
- No supplier URL appears in customer-facing copy.
- No citations or source tokens appear in the HTML.
- Metadata fits requested limits where practical.
- Only supplied internal links are used.
- Every `<a>` contains a descriptive `title`.
- Each of the first `{{IMAGE_COUNT}}` attachments has Name, Title and Alt in exact order.
- Every processed image Name starts with the verified product code.
- Image Title and Alt are not identical.
- No automation fields are missing, renamed, duplicated or reordered.

---

# Automation output contract — DO NOT ALTER

Return exactly one automation block and **no text before or after it**.

Do not omit, rename, reorder or duplicate any field.

`PRODUCT_NAME` must echo the exact GO b2b product name unchanged.

`IMAGE_COUNT` must be exactly `{{IMAGE_COUNT}}`.

Put the complete multiline CMS HTML only inside `HTML_SNIPPET`.

A single `html` code fence is allowed around that field's value.

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
