GetDefaultImageNotes() {
    global imageCountToProcess
    return "Attached images. Number of product images: " imageCountToProcess "."
}

ReadPromptTemplateFile(templatePath) {
    return FileRead(templatePath, "UTF-8")
}

BuildPromptFromTemplate(template, pageUrl, productName, currentMetaTitle, currentMetaDescription, currentHtmlSnippet, requiredInternalLinks, imageNotes, additionalProductNotes) {
    prompt := template
    prompt := StrReplace(prompt, "{{PAGE_URL}}", CleanText(pageUrl))
    prompt := StrReplace(prompt, "{{PRODUCT_NAME}}", CleanText(productName))
    prompt := StrReplace(prompt, "{{CURRENT_META_TITLE}}", EmptyToNA(currentMetaTitle))
    prompt := StrReplace(prompt, "{{CURRENT_META_DESCRIPTION}}", EmptyToNA(currentMetaDescription))
    prompt := StrReplace(prompt, "{{CURRENT_HTML_SNIPPET}}", CleanText(currentHtmlSnippet))
    prompt := StrReplace(prompt, "{{REQUIRED_INTERNAL_LINKS}}", requiredInternalLinks)
    prompt := StrReplace(prompt, "{{IMAGE_NOTES}}", imageNotes)
    prompt := StrReplace(prompt, "{{ADDITIONAL_PRODUCT_NOTES}}", additionalProductNotes)

    return prompt
}

EnsurePromptSupportsImageCount(prompt, imageCount) {
    if imageCount = 0 {
        ; Remove the template's default IMAGE_1 fields when this run has no
        ; configured images. The ordinary-output parser then ends the preceding
        ; field at the end of the automation block.
        return RegExReplace(
            prompt,
            "is)IMAGE_1_TITLE:\s*[\r\n]+.*?===AUTOMATION_OUTPUT_END===",
            "===AUTOMATION_OUTPUT_END==="
        )
    }

    if imageCount <= 1
        return prompt

    imageOutputBlock := BuildAutomationImageOutputBlock(imageCount)

    ; Replace the image section inside the automation block so ChatGPT returns
    ; IMAGE_1_TITLE/ALT, IMAGE_2_TITLE/ALT, etc.
    prompt := RegExReplace(
        prompt,
        "is)IMAGE_1_TITLE:\s*[\r\n]+.*?===AUTOMATION_OUTPUT_END===",
        imageOutputBlock "===AUTOMATION_OUTPUT_END==="
    )

    ; Add a plain instruction as a fallback in case the exact prompt template changes later.
    if !InStr(prompt, "IMAGE_" imageCount "_ALT:") {
        prompt .= "`n`nImportant automation note: this product has " imageCount " attached images. The final automation block must include IMAGE_1_TITLE and IMAGE_1_ALT through IMAGE_" imageCount "_TITLE and IMAGE_" imageCount "_ALT."
    }

    return prompt
}

BuildAutomationImageOutputBlock(imageCount, includeImageNames := false) {
    global maximumImagesPerProduct
    if imageCount < 0 || imageCount > maximumImagesPerProduct
        throw Error("Automation image output count must be between 0 and " maximumImagesPerProduct ".")
    block := ""

    Loop imageCount {
        i := A_Index

        if includeImageNames {
            block .= "IMAGE_" i "_NAME:`n"
            block .= "[clean CMS image name, not a filename, title or alt text]`n`n"
        }
        block .= "IMAGE_" i "_TITLE:`n"
        block .= "[exact image " i " title only]`n`n"
        block .= "IMAGE_" i "_ALT:`n"
        block .= "[exact image " i " alt text only]"

        if i < imageCount
            block .= "`n`n"
        else
            block .= "`n"
    }

    return block
}

BuildBotzRecommendedInlinks(settings) {
    sections := []
    Loop 2 {
        index := A_Index
        name := settings["inlink" index "Name"]
        url := settings["inlink" index "Url"]
        if name != ""
            sections.Push("Inlink " index ":`nName: " name "`nURL: " url)
    }
    if settings["inlinkExtra"] != ""
        sections.Push("Extra inlink information:`n" settings["inlinkExtra"])
    if sections.Length = 0
        return "NONE"

    text := ""
    for _, section in sections
        text .= (text = "" ? "" : "`n`n") section
    return text
}

BuildSupplierProductPromptFromSource(template, pageUrl, productName, productMd, imageFiles, promptSettings := 0, attachmentImageFiles := 0, supplierName := "supplier") {
    if !IsObject(promptSettings)
        promptSettings := CreateDefaultBotzPromptSettings()
    if !IsObject(attachmentImageFiles)
        attachmentImageFiles := imageFiles

    requiredMarkers := [
        "{{PAGE_URL}}",
        "{{PRODUCT_NAME}}",
        "{{PRODUCT_MD_CONTENT}}",
        "{{IMAGE_COUNT}}",
        "{{ATTACHMENT_IMAGE_COUNT}}",
        "{{IMAGE_ORDER}}",
        "{{RECOMMENDED_INLINKS}}",
        "{{ADDITIONAL_NOTES}}",
        "{{IMAGE_AUTOMATION_OUTPUT_FIELDS}}"
    ]
    for _, marker in requiredMarkers {
        if !InStr(template, marker)
            throw Error("The " supplierName " prompt template is missing the required marker " marker ".")
    }

    imageOrder := ""
    Loop attachmentImageFiles.Length {
        SplitPath attachmentImageFiles[A_Index], &fileName
        imageRole := A_Index <= imageFiles.Length
            ? "GO b2b image " A_Index
            : "reference only - do not return CMS image fields"
        imageOrder .= "Attachment " A_Index " of " attachmentImageFiles.Length ": " fileName " (" imageRole ")`n"
    }

    outputFields := BuildAutomationImageOutputBlock(imageFiles.Length, true)
    replacements := Map(
        "{{PAGE_URL}}", CleanText(pageUrl),
        "{{PRODUCT_NAME}}", productName,
        "{{PRODUCT_MD_CONTENT}}", productMd,
        "{{IMAGE_COUNT}}", imageFiles.Length,
        "{{ATTACHMENT_IMAGE_COUNT}}", attachmentImageFiles.Length,
        "{{IMAGE_ORDER}}", Trim(imageOrder),
        "{{RECOMMENDED_INLINKS}}", BuildBotzRecommendedInlinks(promptSettings),
        "{{ADDITIONAL_NOTES}}", promptSettings["additionalNotes"] != "" ? promptSettings["additionalNotes"] : "NONE",
        "{{IMAGE_AUTOMATION_OUTPUT_FIELDS}}", outputFields
    )
    prompt := template
    for marker, value in replacements
        prompt := StrReplace(prompt, marker, value)
    return prompt
}

BuildBotzPromptFromSource(template, pageUrl, productName, productMd, imageFiles, promptSettings := 0, attachmentImageFiles := 0) {
    return BuildSupplierProductPromptFromSource(template, pageUrl, productName, productMd, imageFiles, promptSettings, attachmentImageFiles, "BOTZ")
}

InjectImageOnlyOutputFields(prompt, imageCount) {
    fields := BuildAutomationImageOutputBlock(imageCount, true)
    return StrReplace(StrReplace(prompt, "{{IMAGE_COUNT}}", imageCount), "{{IMAGE_AUTOMATION_OUTPUT_FIELDS}}", fields)
}

BuildMatrixPromptFromState(template, pageUrl, metaTitle, metaDescription, firstHtml, state) {
    global additionalProductNotesDefault
    productsText := "", mapping := "", outputFields := "", attachment := 0
    parentCount := state["parentImageCount"]
    if parentCount {
        Loop parentCount {
            i := A_Index, attachment += 1
            mapping .= "Attached image " attachment " = Parent matrix product, Image " i "`n"
            outputFields .= "PARENT_IMAGE_" i "_TITLE:`n[one-line value]`n`nPARENT_IMAGE_" i "_ALT:`n[one-line value]`n`n"
        }
    }
    for p, product in state["products"] {
        imageCount := product["imageCount"]
        imageSummary := imageCount = 0 ? "No images are configured for this product." : "Attached images: Product " p " Image 1 through Product " p " Image " imageCount
        productsText .= "Product " p ":`nExact product name: " product["productName"] "`nVariant, size or colour difference: " product["variantContext"] "`nSKU row context: " EmptyToNA(product["skuRowText"]) "`n" imageSummary "`n`n"
        outputFields .= "PRODUCT_" p "_NAME:`n[exact input product name unchanged]`n`nPRODUCT_" p "_IMAGE_COUNT:`n" imageCount "`n`n"
        Loop imageCount {
            i := A_Index, attachment += 1
            mapping .= "Attached image " attachment " = Product " p ", Image " i "`n"
            outputFields .= "PRODUCT_" p "_IMAGE_" i "_TITLE:`n[one-line value]`n`nPRODUCT_" p "_IMAGE_" i "_ALT:`n[one-line value]`n`n"
        }
    }
    prompt := template
    replacements := Map("{{PAGE_URL}}", pageUrl, "{{MATRIX_PRODUCT_NAME}}", state["parentProductName"], "{{CURRENT_META_TITLE}}", EmptyToNA(metaTitle), "{{CURRENT_META_DESCRIPTION}}", EmptyToNA(metaDescription), "{{FIRST_CHILD_HTML_SNIPPET}}", EmptyToNA(firstHtml), "{{PRODUCT_COUNT}}", state["productCount"], "{{PARENT_IMAGE_COUNT}}", parentCount, "{{TOTAL_IMAGE_COUNT}}", GetMatrixTotalImageCount(state), "{{MATRIX_PRODUCTS}}", Trim(productsText), "{{ATTACHMENT_ORDER}}", EmptyToNA(Trim(mapping)), "{{IMAGE_NOTES}}", BuildMatrixImageCountSummary(state), "{{ADDITIONAL_PRODUCT_NOTES}}", additionalProductNotesDefault, "{{MATRIX_AUTOMATION_OUTPUT_FIELDS}}", outputFields)
    for token, value in replacements
        prompt := StrReplace(prompt, token, value)
    return prompt
}

BuildMatrixFullPromptFromState(template, pageUrl, metaTitle, metaDescription, state) {
    global requiredInternalLinksDefault, additionalProductNotesDefault
    productsText := "", mapping := "", outputFields := "", attachment := 0, bt := Chr(96)
    parentCount := state["parentImageCount"]
    Loop parentCount {
        i := A_Index, attachment += 1
        mapping .= "Attached image " attachment " = Parent matrix product, Image " i "`n"
        outputFields .= "PARENT_IMAGE_" i "_TITLE:`n[one-line image title]`n`nPARENT_IMAGE_" i "_ALT:`n[one-line image alt text]`n`n"
    }
    for p, product in state["products"] {
        imageCount := product["imageCount"]
        imageSummary := imageCount = 0 ? "No images are configured for this product." : "Attached images: Product " p " Image 1 through Product " p " Image " imageCount
        productsText .= "Product " p ":`nExact child product name (audit identifier): " product["productName"] "`nConnected SKU size (from the same accessibility row): " EmptyToNA(product["connectedSize"]) "`nVariant context: " product["variantContext"] "`nFull SKU row context: " EmptyToNA(product["skuRowText"]) "`nCurrent child HTML/product description snippet:`n" bt bt bt "html`n" product["originalHtmlSnippet"] "`n" bt bt bt "`n" imageSummary "`n`n"
        outputFields .= "PRODUCT_" p "_NAME:`n[exact original child name unchanged]`n`nPRODUCT_" p "_IMAGE_COUNT:`n" imageCount "`n`nPRODUCT_" p "_HTML_SNIPPET:`n" bt bt bt "html`n[complete multiline child HTML]`n" bt bt bt "`n`n"
        Loop imageCount {
            i := A_Index, attachment += 1
            mapping .= "Attached image " attachment " = Product " p ", Image " i "`n"
            outputFields .= "PRODUCT_" p "_IMAGE_" i "_TITLE:`n[one-line image title]`n`nPRODUCT_" p "_IMAGE_" i "_ALT:`n[one-line image alt text]`n`n"
        }
    }
    replacements := Map(
        "{{PAGE_URL}}", pageUrl,
        "{{MATRIX_PRODUCT_NAME}}", state["parentProductName"],
        "{{CURRENT_META_TITLE}}", EmptyToNA(metaTitle),
        "{{CURRENT_META_DESCRIPTION}}", EmptyToNA(metaDescription),
        "{{PRODUCT_COUNT}}", state["productCount"],
        "{{PARENT_IMAGE_COUNT}}", parentCount,
        "{{TOTAL_IMAGE_COUNT}}", GetMatrixTotalImageCount(state),
        "{{MATRIX_PRODUCTS}}", Trim(productsText),
        "{{ATTACHMENT_ORDER}}", Trim(mapping),
        "{{IMAGE_NOTES}}", BuildMatrixImageCountSummary(state),
        "{{REQUIRED_INTERNAL_LINKS}}", requiredInternalLinksDefault,
        "{{ADDITIONAL_PRODUCT_NOTES}}", additionalProductNotesDefault,
        "{{MATRIX_AUTOMATION_OUTPUT_FIELDS}}", outputFields
    )
    prompt := template
    for token, value in replacements
        prompt := StrReplace(prompt, token, value)
    return prompt
}

BuildMatrixImageCountSummary(state) {
    summary := "Parent matrix product: " state["parentImageCount"] " image(s)."
    for p, product in state["products"]
        summary .= "`nProduct " p ": " product["imageCount"] " image(s)."
    summary .= "`nTotal attachments: " GetMatrixTotalImageCount(state) "."
    return summary
}

