Optimise image SEO only for every child product belonging to the configured Cromartie matrix page.

This task is specifically for the GR Pottery Forms Clay Tools and Formers page and its child products. Keep the wording focused on the exact pottery form, clay tool or former represented by each child product and attached image.

Of the project source files, use only the latest recurring fixes file, and only where its guidance is relevant to image SEO, naming consistency, UK English, factual accuracy or avoiding recurring mistakes. Do not use the product-page SEO guidance workbook, product-page SEO strategy, keyword map, CMS styling guidance or other project source files for this temporary task.

Configured target page URL:
{{PAGE_URL}}

Matrix product name: {{MATRIX_PRODUCT_NAME}}
Parent meta title (context only): {{CURRENT_META_TITLE}}
Parent meta description (context only): {{CURRENT_META_DESCRIPTION}}

First-child HTML context (context only; it may contain a size or variant detail that does not apply to the other children):
{{FIRST_CHILD_HTML_SNIPPET}}

Detected products: {{PRODUCT_COUNT}}
Parent matrix-product images: {{PARENT_IMAGE_COUNT}}
Total attached images: {{TOTAL_IMAGE_COUNT}}

Products in stable CMS order:
{{MATRIX_PRODUCTS}}

Attachment order:
{{ATTACHMENT_ORDER}}

Image notes:
{{IMAGE_NOTES}}

Additional product notes:
{{ADDITIONAL_PRODUCT_NOTES}}

Inspect every image and create one concise product-led title and one accurate alt text for it. Follow the attachment map exactly: parent images belong to the main matrix product, while child images belong only to their mapped child. Tailor each set to the correct product and the GR Pottery Forms Clay Tools and Formers page. Preserve verified shape, size, form and other variant distinctions, but never assume one child’s details apply to another child or to the parent. Use UK English and “colour”, except in official names. Keep title and alt different, avoid keyword stuffing, and do not invent visual, material, dimensional, compatibility, usage or technical details.

Do not produce parent metadata, descriptions or HTML. Echo each exact child name unchanged in its audit field. Keep every automation value on one line. Include no citations, source tokens, commentary, placeholders or code fences. Return only this block:

===AUTOMATION_OUTPUT_START===
MODE:
MATRIX_IMAGE

PRODUCT_COUNT:
{{PRODUCT_COUNT}}

PARENT_IMAGE_COUNT:
{{PARENT_IMAGE_COUNT}}

TOTAL_IMAGE_COUNT:
{{TOTAL_IMAGE_COUNT}}

{{MATRIX_AUTOMATION_OUTPUT_FIELDS}}===AUTOMATION_OUTPUT_END===
