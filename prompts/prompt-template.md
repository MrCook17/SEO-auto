I want to optimise this Colour & Glaze product page using the project source files.

Use:

- `cromartie_colour_glaze_product_page_seo_guidance_workbook.xlsx`
- `cromartie_colour_glaze_product_page_seo_strategy_workbook_aligned.md`
- `cromartie_flexible_cms_styling_guidance_updated.md`
- `cromartie_colour_glaze_product_page_recurring_fixes_v16.md`

Important styling instruction:
You must use `cromartie_flexible_cms_styling_guidance_updated.md` as the HTML styling source of truth.

The CMS-ready HTML snippet should follow the flexible Cromartie CMS structure and must include a product specifications table when verified structured product facts are provided.

The response should stay similar to the usual format I already get, but the HTML snippet now needs to include a styled product specification table inside the snippet.

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

Recommended internal links — manual input:

Use the following manually supplied internal links in the HTML snippet where genuinely useful:

===RECOMMENDED_INLINKS_START===
{{REQUIRED_INTERNAL_LINKS}}
===RECOMMENDED_INLINKS_END===

This area may contain one internal link, two internal links, `NONE` or `N/A`.

Important:

- These links are navigation recommendations, not factual product sources
- Never use an inlink destination to infer extra product facts
- Do not browse for replacement links
- If `NONE` or `N/A`, do not invent links
- Use a maximum of two supplied links
- Every `<a>` must have a descriptive `title` attribute
- Prefer the purple CTA/inlink button styling from the flexible CMS guidance when links sit after the specification table
- Do not create an extra paragraph solely to hold an internal link
- Where two useful links are supplied, two CTA buttons are acceptable
- Do not force an inline paragraph link when a post-table CTA is cleaner

Image notes:
{{IMAGE_NOTES}}

Additional notes — manual input:

Use the following manually supplied notes where relevant. They may contain product facts, editorial context or instructions. Do not extend them with unsupported assumptions or let them override the current product information supplied above.

===ADDITIONAL_NOTES_START===
{{ADDITIONAL_PRODUCT_NOTES}}
===ADDITIONAL_NOTES_END===

If this area contains `NONE` or `N/A`, there are no additional notes.

Task:
Create:

1. SEO-optimised meta title
2. SEO-optimised meta description
3. CMS-ready HTML snippet description
4. Product name recommendation if the name should be edited
5. Image title text and image alt text for every attached image

Important:

- Use the workbook as the main guidance source
- Match this product to the correct department/range guidance row
- Use the strategy guide for keyword ownership and cannibalisation decisions
- Use `cromartie_flexible_cms_styling_guidance_updated.md` for the HTML snippet
- Keep the product page exact-product focused
- Do not target broad department keywords unless the workbook clearly allows it
- Keep wording natural, human, useful and enjoyable to read
- Make the HTML snippet clear and customer-friendly
- Do not invent facts
- Do not include unsupported firing temperatures, finishes, effects, food safety, application or suitability claims
- Keep the meta title under 60 characters where possible
- Keep the meta description under 160 characters where possible
- Use UK English
- Use “colour”, not “color”, unless it is part of an official product or brand name
- Make image SEO accurately describe what is visible
- Include supplied recommended internal links where they fit naturally
- Every link in the HTML must include a descriptive `title` attribute
- Do not over-link
- Do not provide a full page rewrite outside the CMS snippet
- Do not include citations, source tokens or placeholder text inside the HTML

HTML snippet requirements:

- Start with the standard Cromartie wrapper from `cromartie_flexible_cms_styling_guidance_updated.md`
- Use inline CSS only
- Include one clear styled `<h2>`
- Include at least one natural, SEO-friendly `<p>` paragraph
- When mentioning the product naturally in text dont include its size on the end
- Use a `<ul>` for practical product features, uses, benefits, suitability notes or application guidance where useful
- Include a product specifications table inside the HTML snippet when structured verified product facts are available
- The specification table should use the purple Cromartie table styling from `cromartie_flexible_cms_styling_guidance_updated.md`
- Put structured facts in the table, such as product type, bottle size, format, finish, base, use, suitability, safety, firing range, material, capacity, compatibility or technical details where supplied
- Do not repeat the exact same detail in both the `<ul>` and the specification table
- Use the `<ul>` for user benefits, uses, practical guidance or short feature-led points
- Use the table for clean product specifications
- Do not add filler table rows just to make the table look complete
- Do not invent missing specifications
- Include CTA buttons only where useful and relevant
- Keep the structure flexible rather than over-templated

Preferred HTML structure:

```html
<div
  style="font-family: Open Sans, sans-serif; font-size:15px; line-height:1.7; color:#444;"
>
  <h2
    style="color:#76689A; font-size:1.7em; font-weight:bold; margin-bottom:12px;"
  >
    [Descriptive product-led heading]
  </h2>

  <p>[Natural SEO-friendly intro paragraph.]</p>

  <p>
    [Helpful second paragraph with product use, application or buying context.]
  </p>

  <ul>
    <li>[Feature, use, suitability or practical benefit]</li>
    <li>[Feature, use, suitability or practical benefit]</li>
    <li>[Feature, use, suitability or practical benefit]</li>
  </ul>

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
        <tr>
          <th
            scope="row"
            style="text-align:left; padding:9px 12px; border:1px solid #ddd; background:#f7f4fb; color:#76689A; font-weight:bold;"
          >
            Product type
          </th>
          <td style="padding:9px 12px; border:1px solid #ddd;">
            [Verified product type]
          </td>
        </tr>
        <tr>
          <th
            scope="row"
            style="text-align:left; padding:9px 12px; border:1px solid #ddd; background:#f7f4fb; color:#76689A; font-weight:bold;"
          >
            Size
          </th>
          <td style="padding:9px 12px; border:1px solid #ddd;">
            [Verified size/capacity if supplied]
          </td>
        </tr>
      </tbody>
    </table>
  </div>

  [Optional note or CTA buttons where useful.]
</div>
```

Only include table rows that are supported by the product information. Rename the row labels naturally to suit the product.

Output format:

Only return the following visible sections before the automation block:

**Workbook / Guidance Row Used:**
[Guidance row ID, source row ID, department/range name, or explain if not confidently found]

**Product Name Recommendation:**
[Keep current product name OR recommended new product name with reason]

**Notes:**

- Keyword ownership followed:
- Cannibalisation avoided by:
- Internal links used:
- Product specification table used:
- Content facts used:
- Any uncertainty:

Do not output separate visible sections for Meta Title, Meta Description, HTML Snippet or Image SEO above the automation block.

However, you must still create the meta title, meta description, CMS-ready HTML snippet, image title text and image alt text to the same quality and accuracy as before.

Put those final usable outputs inside the automation block only.

At the very end, include this exact automation block with no extra commentary inside it:

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
