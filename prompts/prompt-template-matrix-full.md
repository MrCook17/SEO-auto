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

Every child needs its own complete CMS-ready HTML/product-description snippet and image title plus alt text for every attached child image. The parent also needs title and alt text for every attached parent image. Child names are exact audit identifiers: echo each unchanged. Do not create child product-name recommendations or child metadata: the automation clears child meta titles and meta descriptions so metadata is owned by the parent matrix page.

Products in stable CMS order:

{{MATRIX_PRODUCTS}}

Attachment order (follow exactly):

{{ATTACHMENT_ORDER}}

Image notes:

{{IMAGE_NOTES}}

Additional product notes:

===ADDITIONAL_NOTES_START===
{{ADDITIONAL_PRODUCT_NOTES}}
===ADDITIONAL_NOTES_END===

If this area contains `NONE` or `N/A`, there are no additional notes.

Manually recommended internal links:

===RECOMMENDED_INLINKS_START===
{{REQUIRED_INTERNAL_LINKS}}
===RECOMMENDED_INLINKS_END===

If this area contains `NONE` or `N/A`, do not invent internal links.

Accuracy and SEO requirements:

- Treat each child as an independent exact product. Never copy a size, colour, shape, capacity, specification or other fact from one child to another unless it is independently verified for both.
- Treat each child's connected SKU size as verified structured data for that child only. Preserve both metric and imperial wording when supplied, and use it naturally in that child's HTML/specifications where relevant. Never infer another child's size from it.
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
