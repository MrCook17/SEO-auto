; ==========================================================
; FIGURED'ART PRODUCT CREATION
; Supplier-specific source matching, prompt/state handling and
; CMS insertion. Safe file-picker and image-order helpers are
; shared with the established BOTZ product-creation workflow.
; ==========================================================

BuildFiguredArtPrompt(pageUrl) {
    global cmsWinTitle, FiguredArtPromptTemplatePath, figuredArtState, botzPromptSettings, maximumImagesPerProduct

    try {
        ClearActiveCmsProductCode()
        ActivateWindow(cmsWinTitle)
        ClickPoint("overview_tab", 500)
        stockCode := SetActiveCmsProductCode(CopyFromPoint("stock_code"))
        productName := CleanText(CopyFromPoint("product_name"))
        if productName = ""
            throw Error("The GO b2b product name is blank.")

        productCode := NormaliseFiguredArtProductCode(stockCode)
        LogText("figuredart-stock-code", "GO b2b stock code: " stockCode "`nExact Figured'Art product code: " productCode)
        productFolder := FindUniqueFiguredArtProductFolder(productCode)
        productMdPath := productFolder "\product.md"
        imagesDir := productFolder "\images"
        if !FileExist(productMdPath)
            throw Error("The matched Figured'Art folder has no product.md file: " productMdPath)
        if !DirExist(imagesDir)
            throw Error("The matched Figured'Art folder has no images folder: " imagesDir)

        productMd := FileRead(productMdPath, "UTF-8")
        if CleanText(productMd) = ""
            throw Error("The matched Figured'Art product.md file is empty: " productMdPath)
        ValidateFiguredArtProductMarkdown(productMd, productCode, productMdPath)

        ; The live folder scan is authoritative for attachment count and order.
        ; Any image list embedded in product.md is deliberately ignored.
        attachmentImageFiles := EnumerateBotzImageFiles(imagesDir)
        if attachmentImageFiles.Length = 0
            throw Error("The matched Figured'Art images folder contains no supported image files: " imagesDir)
        imageFiles := TakeFirstBotzImageFiles(attachmentImageFiles, maximumImagesPerProduct)
        imageManifest := BuildBotzImageManifest(imageFiles)

        if !FileExist(FiguredArtPromptTemplatePath)
            throw Error("The Figured'Art prompt template was not found: " FiguredArtPromptTemplatePath)
        if !IsObject(botzPromptSettings)
            InitialiseSeoPromptSettings()
        prompt := BuildFiguredArtPromptFromSource(
            FileRead(FiguredArtPromptTemplatePath, "UTF-8"),
            pageUrl,
            productName,
            productMd,
            imageFiles,
            botzPromptSettings,
            attachmentImageFiles
        )

        figuredArtState := Map(
            "mode", "figuredart",
            "productName", productName,
            "stockCode", stockCode,
            "matchCode", productCode,
            "productFolder", productFolder,
            "productMdPath", productMdPath,
            "productMdSize", FileGetSize(productMdPath),
            "productMdModified", FileGetTime(productMdPath, "M"),
            "initialGalleryCount", 0,
            "uploadedCount", 0,
            "pendingImageIndex", 0,
            "imageCount", imageFiles.Length,
            "images", imageFiles,
            "imageManifest", imageManifest
        )
        SaveFiguredArtState(figuredArtState)

        LogText("figuredart-source", BuildFiguredArtSourceLog(figuredArtState))
        LogSupplierChatGptImagePlan("Figured'Art", "figuredart", attachmentImageFiles.Length, imageFiles.Length)
        LogText("figuredart-chatgpt-request", prompt)
        PastePromptToChatGPT(prompt)
        ValidateFiguredArtSourcesUnchanged(figuredArtState)
        AttachBotzImagesToChatGpt(attachmentImageFiles, "Figured'Art", "figuredart")
        Flash("Figured'Art prompt and " attachmentImageFiles.Length " image attachment(s) were submitted to ChatGPT.`nGO b2b remains limited to the first " imageFiles.Length " image(s).", 3000)
    } catch as err {
        if HasActiveCmsProductCode() {
            LogText("figuredart-error", "Prompt build stopped: " err.Message)
            LogText("figuredart-skipped-product", "Figured'Art product was not requested or changed: " err.Message)
        }
        throw
    }
}

NormaliseFiguredArtProductCode(stockCode) {
    productCode := StrUpper(CleanText(stockCode))
    if !RegExMatch(productCode, "^(SFA[0-9]{3}-Y|RFA[0-9]{3})$")
        throw Error("Invalid GO b2b stock code '" stockCode "'. Figured'Art mode requires the exact supplier SKU, such as SFA137-Y or RFA013.")
    return productCode
}

FindUniqueFiguredArtProductFolder(productCode) {
    global figuredArtRootDir
    if !DirExist(figuredArtRootDir)
        throw Error("Figured'Art source root was not found: " figuredArtRootDir)

    prefix := StrLower(productCode " ")
    matches := []
    Loop Files figuredArtRootDir "\*", "D" {
        if StrLower(SubStr(A_LoopFileName, 1, StrLen(prefix))) = prefix
            matches.Push(A_LoopFileFullPath)
    }

    if matches.Length = 0
        throw Error("No Figured'Art folder begins with the exact product-code prefix '" productCode " ' under " figuredArtRootDir ".")
    if matches.Length > 1 {
        matchList := ""
        for _, folderPath in matches
            matchList .= (matchList = "" ? "" : "`n") folderPath
        throw Error("Multiple Figured'Art folders begin with the exact product-code prefix '" productCode " ':`n" matchList)
    }

    LogText("figuredart-folder-match", "Exact prefix '" productCode " ' matched: " matches[1])
    return matches[1]
}

ValidateFiguredArtProductMarkdown(productMd, expectedProductCode, productMdPath := "product.md") {
    if !RegExMatch(productMd, "im)^Product Code:[ `t]*([A-Z0-9-]+)[ `t]*\r?$", &codeMatch)
        throw Error("The Figured'Art product.md has no readable Product Code field: " productMdPath)
    sourceCode := NormaliseFiguredArtProductCode(codeMatch[1])
    if sourceCode != expectedProductCode
        throw Error("The Figured'Art product.md code does not match the open GO b2b product. Expected '" expectedProductCode "', found '" sourceCode "'.")
    if !RegExMatch(productMd, "im)^Final Status:[ `t]*SUCCESS[ `t]*\r?$")
        throw Error("The Figured'Art product.md is not marked Final Status: SUCCESS, so it was not used for automatic product creation.")
    return true
}

BuildFiguredArtPromptFromSource(template, pageUrl, productName, productMd, imageFiles, promptSettings := 0, attachmentImageFiles := 0) {
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
            throw Error("The Figured'Art prompt template is missing the required marker " marker ".")
    }

    imageOrder := ""
    Loop attachmentImageFiles.Length {
        SplitPath attachmentImageFiles[A_Index], &fileName
        imageRole := A_Index <= imageFiles.Length
            ? "GO b2b image " A_Index
            : "reference only - do not return CMS image fields"
        imageOrder .= "Attachment " A_Index " of " attachmentImageFiles.Length ": " fileName " (" imageRole ")`n"
    }

    replacements := Map(
        "{{PAGE_URL}}", CleanText(pageUrl),
        "{{PRODUCT_NAME}}", productName,
        "{{PRODUCT_MD_CONTENT}}", productMd,
        "{{IMAGE_COUNT}}", imageFiles.Length,
        "{{ATTACHMENT_IMAGE_COUNT}}", attachmentImageFiles.Length,
        "{{IMAGE_ORDER}}", Trim(imageOrder),
        "{{RECOMMENDED_INLINKS}}", BuildBotzRecommendedInlinks(promptSettings),
        "{{ADDITIONAL_NOTES}}", promptSettings["additionalNotes"] != "" ? promptSettings["additionalNotes"] : "NONE",
        "{{IMAGE_AUTOMATION_OUTPUT_FIELDS}}", BuildAutomationImageOutputBlock(imageFiles.Length, true)
    )
    prompt := template
    for marker, value in replacements
        prompt := StrReplace(prompt, marker, value)
    return prompt
}

BuildFiguredArtSourceLog(state) {
    text := "Product name: " state["productName"]
    text .= "`nGO b2b stock code: " state["stockCode"]
    text .= "`nExact Figured'Art product code: " state["matchCode"]
    text .= "`nMatched Figured'Art folder: " state["productFolder"]
    text .= "`nproduct.md path: " state["productMdPath"]
    text .= "`nDiscovered image count: " state["imageCount"]
    for index, imagePath in state["images"]
        text .= "`nImage " index ": " imagePath
    return text
}

SaveFiguredArtState(state) {
    global figuredArtStateFilePath
    text := "CROMARTIE_FIGUREDART_STATE_V1`n"
    text .= "product_name`t" EncodeStateValue(state["productName"]) "`n"
    text .= "stock_code`t" EncodeStateValue(state["stockCode"]) "`n"
    text .= "match_code`t" state["matchCode"] "`n"
    text .= "folder`t" EncodeStateValue(state["productFolder"]) "`n"
    text .= "product_md`t" EncodeStateValue(state["productMdPath"]) "`n"
    text .= "product_md_size`t" state["productMdSize"] "`n"
    text .= "product_md_modified`t" state["productMdModified"] "`n"
    text .= "initial_gallery_count`t" state["initialGalleryCount"] "`n"
    text .= "uploaded_count`t" state["uploadedCount"] "`n"
    text .= "pending_image`t" state["pendingImageIndex"] "`n"
    text .= "image_count`t" state["imageCount"] "`n"
    for index, imagePath in state["images"] {
        item := state["imageManifest"][index]
        text .= "image`t" index "`t" EncodeStateValue(imagePath) "`t" item["size"] "`t" item["modified"] "`n"
    }

    temporaryPath := figuredArtStateFilePath ".tmp"
    if FileExist(temporaryPath)
        FileDelete temporaryPath
    FileAppend text, temporaryPath, "UTF-8"
    FileMove temporaryPath, figuredArtStateFilePath, 1
}

LoadFiguredArtState() {
    global figuredArtStateFilePath, figuredArtState, maximumImagesPerProduct
    if figuredArtState
        return figuredArtState
    if !FileExist(figuredArtStateFilePath)
        throw Error("No saved Figured'Art run exists. Build the Figured'Art prompt with Numpad4 first.")

    lines := StrSplit(StrReplace(FileRead(figuredArtStateFilePath, "UTF-8"), "`r", ""), "`n")
    if lines.Length < 10 || lines[1] != "CROMARTIE_FIGUREDART_STATE_V1"
        throw Error("The saved Figured'Art state file is invalid or unsupported.")

    values := Map(), images := [], imageManifest := []
    Loop lines.Length - 1 {
        line := lines[A_Index + 1]
        if line = ""
            continue
        parts := StrSplit(line, "`t")
        if parts[1] = "image" {
            if parts.Length != 5 || !IsInteger(parts[2]) || Integer(parts[2]) != images.Length + 1 || !IsInteger(parts[4])
                throw Error("The saved Figured'Art image order is invalid.")
            imagePath := DecodeStateValue(parts[3])
            images.Push(imagePath)
            imageManifest.Push(Map("path", imagePath, "size", Integer(parts[4]), "modified", parts[5]))
        } else {
            if parts.Length != 2
                throw Error("The saved Figured'Art state contains an invalid record: " line)
            values[parts[1]] := parts[2]
        }
    }

    required := ["product_name", "stock_code", "match_code", "folder", "product_md", "product_md_size", "product_md_modified", "initial_gallery_count", "uploaded_count", "pending_image", "image_count"]
    for _, key in required {
        if !values.Has(key)
            throw Error("The saved Figured'Art state is missing: " key ".")
    }
    if !IsInteger(values["image_count"]) || Integer(values["image_count"]) < 1 || Integer(values["image_count"]) != images.Length
        throw Error("The saved Figured'Art image count is invalid.")
    if Integer(values["image_count"]) > maximumImagesPerProduct
        throw Error("The saved Figured'Art image count exceeds the GO b2b limit of " maximumImagesPerProduct ". Rebuild the prompt to select only the first " maximumImagesPerProduct " images.")
    if !IsInteger(values["uploaded_count"]) || !IsInteger(values["pending_image"])
        throw Error("The saved Figured'Art upload progress is invalid.")

    uploadedCount := Integer(values["uploaded_count"])
    pendingImageIndex := Integer(values["pending_image"])
    imageCount := Integer(values["image_count"])
    if uploadedCount < 0 || uploadedCount > imageCount
        throw Error("The saved Figured'Art uploaded-image progress is invalid.")
    if pendingImageIndex < 0 || pendingImageIndex > imageCount
        throw Error("The saved Figured'Art pending-image progress is invalid.")

    figuredArtState := Map(
        "mode", "figuredart",
        "productName", DecodeStateValue(values["product_name"]),
        "stockCode", DecodeStateValue(values["stock_code"]),
        "matchCode", NormaliseFiguredArtProductCode(values["match_code"]),
        "productFolder", DecodeStateValue(values["folder"]),
        "productMdPath", DecodeStateValue(values["product_md"]),
        "productMdSize", Integer(values["product_md_size"]),
        "productMdModified", values["product_md_modified"],
        "initialGalleryCount", Integer(values["initial_gallery_count"]),
        "uploadedCount", uploadedCount,
        "pendingImageIndex", pendingImageIndex,
        "imageCount", imageCount,
        "images", images,
        "imageManifest", imageManifest
    )
    return figuredArtState
}

ValidateFiguredArtSourcesUnchanged(state) {
    global maximumImagesPerProduct
    if !FileExist(state["productMdPath"])
        throw Error("The saved Figured'Art product.md no longer exists: " state["productMdPath"])
    if FileGetSize(state["productMdPath"]) != state["productMdSize"] || FileGetTime(state["productMdPath"], "M") != state["productMdModified"]
        throw Error("Figured'Art product.md changed after the ChatGPT request was built. Rebuild the prompt before continuing.")

    productMd := FileRead(state["productMdPath"], "UTF-8")
    ValidateFiguredArtProductMarkdown(productMd, state["matchCode"], state["productMdPath"])
    matchedFolder := FindUniqueFiguredArtProductFolder(state["matchCode"])
    if StrLower(matchedFolder) != StrLower(state["productFolder"])
        throw Error("The exact Figured'Art folder match changed after the request was built. Rebuild the prompt.")

    currentImages := EnumerateBotzImageFiles(state["productFolder"] "\images", maximumImagesPerProduct)
    if !BotzPathArraysMatch(currentImages, state["images"])
        throw Error("The Figured'Art images folder changed after the ChatGPT request was built. Rebuild the prompt so image order and output fields remain aligned.")
    Loop currentImages.Length {
        imagePath := currentImages[A_Index]
        savedItem := state["imageManifest"][A_Index]
        if FileGetSize(imagePath) != savedItem["size"] || FileGetTime(imagePath, "M") != savedItem["modified"]
            throw Error("Figured'Art image " A_Index " changed after the ChatGPT request was built: " imagePath ". Rebuild the prompt before uploading.")
    }
}

PasteFiguredArtOutputToCms() {
    global cmsWinTitle, useRecommendedProductName
    global lastSavedNonMatrixProductIdentity

    try {
        ClearActiveCmsProductCode()
        response := A_Clipboard
        state := LoadFiguredArtState()
        SetActiveCmsProductCode(state["stockCode"])
        ValidateFiguredArtSourcesUnchanged(state)
        block := ExtractValidatedAutomationBlock(response)
        output := ParseFiguredArtAutomationOutput(block, state)
        LogText("figuredart-chatgpt-output", response)
        LogText("figuredart-parsed-output", BuildBotzParsedOutputLog(output))

        ActivateWindow(cmsWinTitle)
        VerifyFiguredArtCmsProduct(state, output)
        UploadAndPopulateFiguredArtImages(state, output)

        completedProductName := state["productName"]
        if useRecommendedProductName && IsUsableProductNameRecommendation(output["productNameRecommendation"]) {
            InsertProductNameRecommendation(output["productNameRecommendation"])
            completedProductName := CleanText(CopyFromPoint("product_name"))
            if completedProductName = ""
                throw Error("The updated Figured'Art Product Name could not be read back from GO b2b.")
        }
        InsertMetaFields(output["metaTitle"], output["metaDescription"], output["htmlSnippet"])
        lastSavedNonMatrixProductIdentity := Map(
            "productName", completedProductName,
            "productCode", state["stockCode"]
        )
        ClickPoint("product_save_button", 1000)

        LogText("figuredart-product-complete", "Completed Figured'Art Product Creation for '" state["productName"] "' (" state["stockCode"] ") with " state["imageCount"] " image(s).")
        Flash("Figured'Art product created and saved with " state["imageCount"] " image(s).", 3000)
    } catch as err {
        if HasActiveCmsProductCode() {
            LogText("figuredart-error", "Product update stopped: " err.Message)
            LogText("figuredart-skipped-product", "Figured'Art product was not completed: " err.Message)
        }
        throw
    }
}

ParseFiguredArtAutomationOutput(block, state) {
    expected := ["MODE", "PRODUCT_NAME", "IMAGE_COUNT", "PRODUCT_NAME_RECOMMENDATION", "META_TITLE", "META_DESCRIPTION", "HTML_SNIPPET"]
    Loop state["imageCount"] {
        expected.Push("IMAGE_" A_Index "_NAME")
        expected.Push("IMAGE_" A_Index "_TITLE")
        expected.Push("IMAGE_" A_Index "_ALT")
    }
    fields := ParseOrderedAutomationFields(block, expected)

    mode := ValidateMatrixFullOneLine(fields["MODE"], "Figured'Art mode")
    if mode != "FIGUREDART_PRODUCT_CREATION"
        throw Error("Figured'Art output MODE must be FIGUREDART_PRODUCT_CREATION.")
    echoedName := ValidateMatrixFullOneLine(fields["PRODUCT_NAME"], "Figured'Art product name")
    if NormaliseHarmlessWhitespace(echoedName) != NormaliseHarmlessWhitespace(state["productName"])
        throw Error("The Figured'Art output product name does not match the saved GO b2b product name.")
    if !IsInteger(fields["IMAGE_COUNT"]) || Integer(fields["IMAGE_COUNT"]) != state["imageCount"]
        throw Error("The Figured'Art output image count does not match the current Figured'Art images folder.")

    recommendation := ValidateMatrixFullOneLine(fields["PRODUCT_NAME_RECOMMENDATION"], "Product name recommendation")
    metaTitle := ValidateMatrixFullOneLine(fields["META_TITLE"], "Meta title")
    metaDescription := ValidateMatrixFullOneLine(fields["META_DESCRIPTION"], "Meta description")
    htmlSnippet := StripCodeFence(fields["HTML_SNIPPET"])
    ValidateFiguredArtHtml(htmlSnippet)

    imageNames := [], imageTitles := [], imageAlts := []
    Loop state["imageCount"] {
        i := A_Index
        imageName := ValidateCmsImageName(fields["IMAGE_" i "_NAME"], i)
        imageTitle := ValidateImageOutputValue(fields["IMAGE_" i "_TITLE"], "Image " i " title")
        imageAlt := ValidateImageOutputValue(fields["IMAGE_" i "_ALT"], "Image " i " alt text")
        if NormaliseHarmlessWhitespace(imageName) = NormaliseHarmlessWhitespace(imageTitle) || NormaliseHarmlessWhitespace(imageName) = NormaliseHarmlessWhitespace(imageAlt)
            throw Error("Image " i " Name must be distinct from its Title and Alt text.")
        if NormaliseHarmlessWhitespace(imageTitle) = NormaliseHarmlessWhitespace(imageAlt)
            throw Error("Image " i " Title and Alt text are identical.")
        imageNames.Push(imageName), imageTitles.Push(imageTitle), imageAlts.Push(imageAlt)
    }

    warnings := ValidateGeneratedFields(metaTitle, metaDescription, htmlSnippet, imageTitles, imageAlts, true)
    if warnings != ""
        throw Error("Figured'Art generated-field validation failed:`n" warnings)

    return Map(
        "mode", mode,
        "productName", echoedName,
        "productNameRecommendation", recommendation,
        "metaTitle", metaTitle,
        "metaDescription", metaDescription,
        "htmlSnippet", htmlSnippet,
        "imageNames", imageNames,
        "imageTitles", imageTitles,
        "imageAlts", imageAlts
    )
}

ValidateFiguredArtHtml(htmlSnippet) {
    if CleanText(htmlSnippet) = ""
        throw Error("Figured'Art HTML snippet is empty.")
    if !InStr(htmlSnippet, "<")
        throw Error("Figured'Art HTML snippet does not look like HTML.")
    if InStr(htmlSnippet, "{{") || InStr(htmlSnippet, "}}")
        throw Error("Figured'Art HTML snippet contains placeholder text.")
    if RegExMatch(htmlSnippet, "i)(oaicite|contentReference|:source\[|\[citation)")
        throw Error("Figured'Art HTML snippet contains citation/source-token text.")
    if InStr(htmlSnippet, Chr(96) Chr(96) Chr(96))
        throw Error("Figured'Art HTML snippet still contains a code fence.")
}

VerifyFiguredArtCmsProduct(state, output) {
    ClickPoint("overview_tab", 500)
    currentProductName := CleanText(CopyFromPoint("product_name"))
    currentStockCode := CleanText(CopyFromPoint("stock_code"))
    currentProductCode := NormaliseFiguredArtProductCode(currentStockCode)
    if currentProductCode != state["matchCode"]
        throw Error("The open GO b2b product no longer matches the saved Figured'Art code. Expected '" state["matchCode"] "', found '" currentProductCode "'.")

    originalMatches := NormaliseHarmlessWhitespace(currentProductName) = NormaliseHarmlessWhitespace(state["productName"])
    recommendedMatches := IsUsableProductNameRecommendation(output["productNameRecommendation"])
        && NormaliseHarmlessWhitespace(currentProductName) = NormaliseHarmlessWhitespace(output["productNameRecommendation"])
    if !originalMatches && !recommendedMatches
        throw Error("The open GO b2b product name does not match the saved Figured'Art run. Expected '" state["productName"] "', found '" currentProductName "'.")
    LogText("figuredart-product-verified", "Product name: " currentProductName "`nStock code: " currentStockCode "`nFigured'Art code: " currentProductCode)
}

UploadAndPopulateFiguredArtImages(state, output) {
    if state["pendingImageIndex"]
        throw Error("A previous Figured'Art run stopped while image " state["pendingImageIndex"] " was being added. Inspect that image manually before retrying; no image was uploaded twice.")
    if state["uploadedCount"] = state["imageCount"] {
        LogText("figuredart-upload-recovery", "Saved Figured'Art progress already marks all " state["imageCount"] " image detail record(s) complete; uploads were skipped.")
        return true
    }

    startIndex := state["uploadedCount"] + 1
    remaining := state["imageCount"] - state["uploadedCount"]
    LogText("figuredart-upload-recovery", "Starting/resuming Figured'Art upload at image " startIndex " of " state["imageCount"] ".")

    Loop remaining {
        imageIndex := startIndex + A_Index - 1
        imagePath := state["images"][imageIndex]
        try {
            UploadAndPopulateSingleFiguredArtImage(state, imagePath, imageIndex, state["imageCount"], output)
            state["uploadedCount"] := imageIndex
            state["pendingImageIndex"] := 0
            SaveFiguredArtState(state)
        } catch as err {
            LogText("figuredart-upload-error", "Image " imageIndex " of " state["imageCount"] ": " imagePath "`n" err.Message)
            throw Error("Figured'Art image upload/details stopped at image " imageIndex " of " state["imageCount"] ": " err.Message)
        }
    }
    return true
}

UploadAndPopulateSingleFiguredArtImage(state, imagePath, imageIndex, totalImages, output) {
    global botzFilePickerTimeoutMs, botzImagesTabLoadMs, botzImageDetailsLoadMs
    if !FileExist(imagePath)
        throw Error("Image source no longer exists: " imagePath)

    ClickPoint("images_tab", botzImagesTabLoadMs)
    LogText("figuredart-image-upload", "Starting image " imageIndex " of " totalImages ": " imagePath)
    ClickPoint("image_add_button", 500)
    picker := WinWaitActive("ahk_class #32770", , botzFilePickerTimeoutMs / 1000)
    if !picker
        throw Error("The GO b2b Add button did not open the Windows file picker.")
    ChooseSingleFileInPicker(imagePath)

    state["pendingImageIndex"] := imageIndex
    SaveFiguredArtState(state)

    ToolTip "Waiting for Figured'Art image " imageIndex " detail fields..."
    Sleep botzImageDetailsLoadMs
    PasteToPoint("image_name", output["imageNames"][imageIndex])
    PasteToPoint("image_title", output["imageTitles"][imageIndex])
    PasteToPoint("image_alt", output["imageAlts"][imageIndex])
    ClickPoint("image_save_button", 1200)

    LogText(
        "figuredart-image-metadata",
        "Uploaded and saved image " imageIndex " of " totalImages ": " imagePath
        . "`nName: " output["imageNames"][imageIndex]
        . "`nTitle: " output["imageTitles"][imageIndex]
        . "`nAlt/tag: " output["imageAlts"][imageIndex]
    )
}
