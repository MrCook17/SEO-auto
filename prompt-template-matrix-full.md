Optimise this Cromartie matrix product using the project source files:

- `cromartie_colour_glaze_product_page_seo_guidance_workbook.xlsx`
- `cromartie_colour_glaze_product_page_seo_strategy_workbook_aligned.md`
- `cromartie_flexible_cms_styling_guidance_updated.md`
- the latest relevant Cromartie recurring-fixes guidance

Use the workbook for the correct department/range guidance, the strategy for keyword ownership and cannibalisation, and the flexible CMS styling guide as the HTML styling source of truth. Apply only guidance relevant to this page; page-specific verified information below takes precedence.

Page URL: {{PAGE_URL}}

Parent matrix product name: {{MATRIX_PRODUCT_NAME}}
Current parent meta title: {{CURRENT_META_TITLE}}
Current parent meta description: {{CURRENT_META_DESCRIPTION}}
Detected child products: {{PRODUCT_COUNT}}
Parent matrix-product images: {{PARENT_IMAGE_COUNT}}
Total attached images: {{TOTAL_IMAGE_COUNT}}

The parent matrix page owns the parent product name and parent metadata. Create one parent product-name recommendation, one parent meta title and one parent meta description. Do not create parent HTML: the automation will not replace it.

Every child needs its own complete CMS-ready HTML/product-description snippet and image title plus alt text for every attached child image. The parent also needs title and alt text for every attached parent image. Child names are exact audit identifiers: echo each unchanged. Do not create child product-name recommendations or child metadata because the automation will not paste them.

Products in stable CMS order:

{{MATRIX_PRODUCTS}}

Attachment order (follow exactly):

{{ATTACHMENT_ORDER}}

Image notes:

{{IMAGE_NOTES}}

Additional product notes:

Glaze type: liquid cone 6 stoneware glaze
Firing: cone 6, around 1230°C
Application: suitable for dipping and layering
Clay bodies: suitable for porcelain and stoneware pieces
Finish: atmospheric mid-fire glaze effects with colour depth and surface variation

Fired results can vary depending on clay body, application thickness, layering and kiln conditions. Use test tiles to compare results before applying a new glaze or combination across a full batch of work.

Manually recommended internal links:

C6 Pro Series Stoneware Glazes (Liquid) (https://www.cromartiehobbycraft.co.uk/Catalogue/Ceramic-Glazes-Ceramic-Underglazes-for-Pottery-Painting/Fired-Colour-Pottery-Glazes-Underglazes/Pro-Series-Glazes/Cone-6-Pro-Series-Stoneware-Glazes) and C6 Pro Series Glazes (https://www.cromartiehobbycraft.co.uk/Catalogue/Ceramic-Glazes-Ceramic-Underglazes-for-Pottery-Painting/Fired-Colour-Pottery-Glazes-Underglazes/Pro-Series-Glazes) and any other inlinks that may exist which are relevant

Accuracy and SEO requirements:

- Treat each child as an independent exact product. Never copy a size, colour, shape, capacity, specification or other fact from one child to another unless it is independently verified for both.
- Use UK English and natural, useful wording. Do not invent facts, applications, dimensions, finishes, materials, firing details, safety claims, compatibility or suitability.
- Keep the parent meta title under 60 characters where practical and its meta description under 160 characters where practical.
- Each child HTML snippet must use flexible Cromartie inline-CSS structure, include one useful `<h2>`, natural paragraphs, and a practical `<ul>` where useful.
- Add the styled purple Cromartie product-specification table when verified structured facts exist. Include only supported rows and do not duplicate the same facts in the list.
- Treat the manually recommended links as candidates, not mandatory insertions. Include a supplied internal link only in the parent-facing recommendation context or a child's HTML when it is relevant and natural for that exact product. Never assign a child-specific link to a different child. Every HTML link must use the supplied destination URL exactly and have a descriptive `title` attribute. Do not invent URLs or over-link.
- Put no citations, source tokens, commentary or placeholders in CMS-ready HTML.
- Inspect every attachment according to the mapping. Create an accurate, concise title and alt text for each image. A corresponding image title and alt must be different.
- Output exactly {{PRODUCT_COUNT}} children in the supplied order. Use each product's stated image count; counts can differ between children. Keep parent images separate from child images. Product names and all counts must exactly match the supplied state.

Before the automation block, you may briefly identify the guidance row used and factual uncertainties. Do not repeat the final CMS values outside the block.

At the very end, return one complete block in exactly this structure. Keep scalar values on one line. Keep each child HTML value inside its labelled multiline `html` fence. Do not add, omit, rename or reorder fields.

===AUTOMATION_OUTPUT_START===
MODE:
MATRIX_FULL

PRODUCT_COUNT:
{{PRODUCT_COUNT}}

PARENT_IMAGE_COUNT:
{{PARENT_IMAGE_COUNT}}

TOTAL_IMAGE_COUNT:
{{TOTAL_IMAGE_COUNT}}

PARENT_PRODUCT_NAME_RECOMMENDATION:
[one-line parent recommendation, or the exact current parent name when no change is recommended]

PARENT_META_TITLE:
[one-line parent meta title]

PARENT_META_DESCRIPTION:
[one-line parent meta description]

{{MATRIX_AUTOMATION_OUTPUT_FIELDS}}
===AUTOMATION_OUTPUT_END===
