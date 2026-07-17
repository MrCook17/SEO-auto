I want to optimise metadata and image SEO for a product within the following department:

**Ceramic Bisque, Bisqueware and Dinnerware Shapes**
https://www.cromartiehobbycraft.co.uk/Catalogue/Ceramic-Bisque-Bisqueware-Shapes-for-Pottery-Painting/Coming-Soon

This may include products such as:

- ceramic bisque
- bisqueware
- bisque plates
- bisque bowls
- bisque dishes
- bisque mugs and cups
- bisque dinnerware
- bisque serving pieces
- bisque ornaments and shapes
- other pottery-painting bisque products

Do not access or rely on project source files, keyword-map workbooks or external guidance documents.

Use only:

- the supplied product name
- the current metadata
- the current product description
- the additional product notes
- the attached product images
- clearly visible and verifiable information in those images

## Metadata-only mode

This task is for metadata and image SEO only.

Do not create:

- a product name recommendation
- a CMS-ready HTML snippet
- product description HTML
- a specification table
- CTA buttons
- internal links
- keyword ownership notes
- cannibalisation notes
- visible HTML
- content outside the required automation output

## Product information

Page URL:
{{PAGE_URL}}

Current product name:
{{PRODUCT_NAME}}

Current meta title:
{{CURRENT_META_TITLE}}

Current meta description:
{{CURRENT_META_DESCRIPTION}}

Current product description, for factual context only:

```html
{{CURRENT_HTML_SNIPPET}}
```

Image notes:
{{IMAGE_NOTES}}

Additional product notes:
{{ADDITIONAL_PRODUCT_NOTES}}

## Task

Create:

1. An SEO-optimised meta title.
2. An SEO-optimised meta description.
3. One image title and one image alt text for every attached image.

## Product targeting

Keep the metadata focused on the exact product.

Use relevant wording where accurate, such as:

- ceramic bisque
- bisqueware
- bisque pottery
- pottery-painting bisque
- bisque plate
- bisque bowl
- bisque dish
- bisque dinnerware
- bisque mug
- bisque cup
- bisque serving dish
- ceramic shape for decorating
- product shape
- product dimensions

Only use terms that accurately describe the supplied product.

Do not force every related keyword into the metadata.

Do not make an individual product page target the whole ceramic bisque department broadly.

Use the most specific recognised product type available. For example, use `bisque bowl` rather than the broader `ceramic bisque` when the product is clearly a bowl.

## Accuracy rules

- Do not invent product facts.
- Do not guess dimensions, capacity, shape, material, finish or intended use.
- Do not call an item a plate, bowl, dish, mug, cup, vase, ornament or serving piece unless this is confirmed by the product information or clearly visible.
- Do not describe a product as porcelain, earthenware, stoneware or another ceramic body unless confirmed.
- Do not claim the item is handmade, slip-cast, British-made or manufactured by a particular brand unless confirmed.
- Do not invent firing temperatures, cone ranges, decorating methods or glaze compatibility.
- Do not claim that the item is food-safe, dinnerware-safe, dishwasher-safe, microwave-safe, oven-safe or waterproof.
- The word `dinnerware` may describe the product category or shape, but it must not imply that an undecorated or unfinished item is safe for serving food.
- Do not claim that the item becomes food-safe after glazing or firing unless verified instructions explicitly confirm this.
- Do not claim that paint, glaze or decorating materials are included unless confirmed.
- Do not include unsupported claims about durability, professional quality, ease of decorating or suitability for children or beginners.
- Do not include stock status, delivery information or price.
- Do not include product codes, SKUs or item codes unless genuinely required to identify the product.
- Include dimensions or capacity only when supplied and useful.
- Use UK English.
- Do not include citations, source references, explanations or placeholder text in the final values.

## Meta title rules

- Lead with the exact product name, shape or recognised bisque product type.
- Include `Ceramic Bisque` or `Bisqueware` where it helps identify the product and remains natural.
- Use the most specific product phrase available, such as:
  - `Bisque Plate`
  - `Ceramic Bisque Bowl`
  - `Bisque Serving Dish`
  - `Bisque Mug`

- Include the confirmed size where useful and where the title remains readable.
- Keep the title under 60 characters where possible.
- Do not add `Cromartie` at the end if the CMS already adds the website name.
- Do not repeat near-identical phrases such as `bisque ceramic bisqueware`.
- Do not use a generic title such as `Ceramic Bisque for Pottery Painting` when a more specific product type is known.

Suitable general patterns may include:

```text
[Product Name/Shape] Ceramic Bisque [Size]
```

```text
[Shape] Bisque Plate [Size]
```

```text
[Shape] Ceramic Bisque Bowl [Size]
```

```text
[Product Name] Bisqueware Shape [Size]
```

Choose the pattern that most accurately describes the supplied product.

## Meta description rules

- Describe the exact ceramic bisque product.
- Include the verified shape, product type and size where useful.
- Mention pottery painting or ceramic decorating only when this accurately reflects the supplied information.
- Make the description useful to someone deciding whether it is the correct bisque shape or dinnerware piece.
- Keep the description under 160 characters where possible.
- Avoid generic descriptions repeated across every bisque product.
- Vary the wording according to the product’s verified shape, dimensions, design details and decorating purpose.
- Do not use unsupported promotional or safety claims.
- Do not imply that an undecorated bisque item is ready for food use.
- Do not list several similar keyword variations unnaturally.

Example direction where verified:

```text
Decorate this [shape] ceramic bisque [product type], supplied in [size]. A practical pottery-painting shape for personalised ceramic projects.
```

Do not copy this wording mechanically for every product. Adapt the structure naturally using only verified facts.

## Image SEO rules

Create one image title and one image alt text for every attached image.

For each image:

- describe only what is visibly shown
- include the exact product or shape name where known
- include `ceramic bisque` or `bisqueware` where useful
- identify the view where relevant, such as:
  - front view
  - top view
  - side view
  - angled view
  - inside view
  - base view
  - rim detail
  - handle detail
  - dimensions diagram
  - group image
  - decorated example

- include the size only when confirmed and useful
- keep the image title concise and product-led
- make the alt text naturally descriptive
- do not keyword-stuff
- do not make the image title and alt text identical
- do not say the item is white unless the visible colour is clear and colour wording is useful
- do not describe decoration, glaze or colour that is not visible
- do not call an undecorated product a finished ceramic piece
- do not say the item is food-safe or suitable for serving food
- do not claim a ceramic material or body type beyond `ceramic bisque` unless confirmed
- if a decorated example is shown, clearly distinguish it from the undecorated product
- if several images show the same item from different angles, make each title and alt text specific to that view

Example image-title directions:

```text
Round Ceramic Bisque Plate Top View
```

```text
Ceramic Bisque Bowl Angled Product View
```

Example alt-text directions:

```text
Top view of a round ceramic bisque plate with a plain undecorated surface
```

```text
Angled view showing the inside and rim of the ceramic bisque bowl
```

Only use wording supported by the actual image and product information.

## Output rules

Return only the automation block below.

Do not include introductory text, explanations, notes or separate visible metadata sections.

Repeat the image fields for every attached image using sequential numbering.

Return this exact structure:

===AUTOMATION_OUTPUT_START===
META_TITLE:
[exact meta title only]

META_DESCRIPTION:
[exact meta description only]

IMAGE_1_TITLE:
[exact image title only]

IMAGE_1_ALT:
[exact image alt text only]
===AUTOMATION_OUTPUT_END===

For additional images, insert the fields before `===AUTOMATION_OUTPUT_END===`, for example:

```text
IMAGE_2_TITLE:
[exact image title only]

IMAGE_2_ALT:
[exact image alt text only]
```

Do not output image fields for images that were not attached.
