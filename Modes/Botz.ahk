BuildBotzPrompt(pageUrl) {
    global cmsWinTitle, botzState, botzPromptSettings, maximumImagesPerProduct

    try {
        ClearActiveCmsProductCode()
        ActivateWindow(cmsWinTitle)
        ClickPoint("overview_tab", 500)
        stockCode := SetActiveCmsProductCode(CopyFromPoint("stock_code"))
        productName := CleanText(CopyFromPoint("product_name"))
        if productName = ""
            throw Error("The GO b2b product name is blank.")

        matchCode := TransformBotzStockCode(stockCode)
        productFolder := FindUniqueBotzProductFolder(matchCode)
        productMdPath := productFolder "\product.md"
        imagesDir := productFolder "\images"
        if !FileExist(productMdPath)
            throw Error("The matched BOTZ folder has no product.md file: " productMdPath)
        if !DirExist(imagesDir)
            throw Error("The matched BOTZ folder has no images folder: " imagesDir)

        productMd := FileRead(productMdPath, "UTF-8")
        if CleanText(productMd) = ""
            throw Error("The matched product.md file is empty: " productMdPath)

        ; This scan deliberately happens immediately before request creation.
        ; product.md image lists are never read or trusted by the automation.
        attachmentImageFiles := EnumerateBotzImageFiles(imagesDir)
        if attachmentImageFiles.Length = 0
            throw Error("The matched BOTZ images folder contains no supported image files: " imagesDir)
        imageFiles := TakeFirstBotzImageFiles(attachmentImageFiles, maximumImagesPerProduct)
        imageManifest := BuildBotzImageManifest(imageFiles)

        promptTemplatePath := GetPromptTemplatePath()
        if !FileExist(promptTemplatePath)
            throw Error("The selected BOTZ prompt template was not found: " promptTemplatePath)
        if !IsObject(botzPromptSettings)
            InitialiseSeoPromptSettings()
        prompt := BuildBotzPromptFromSource(
            FileRead(promptTemplatePath, "UTF-8"),
            pageUrl,
            productName,
            productMd,
            imageFiles,
            botzPromptSettings,
            attachmentImageFiles
        )

        botzState := Map(
            "mode", "botz",
            "productName", productName,
            "stockCode", stockCode,
            "matchCode", matchCode,
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
        SaveBotzState(botzState)

        LogText("botz-source", BuildBotzSourceLog(botzState))
        LogSupplierChatGptImagePlan("BOTZ", "botz", attachmentImageFiles.Length, imageFiles.Length)
        LogText("botz-chatgpt-request", prompt)
        PastePromptToChatGPT(prompt)
        ValidateBotzSourcesUnchanged(botzState)
        AttachBotzImagesToChatGpt(attachmentImageFiles)
        Flash("BOTZ prompt and " attachmentImageFiles.Length " image attachment(s) were submitted to ChatGPT.`nGO b2b remains limited to the first " imageFiles.Length " image(s).", 3000)
    } catch as err {
        if HasActiveCmsProductCode() {
            LogText("botz-error", "Prompt build stopped: " err.Message)
            LogText("botz-skipped-product", "BOTZ product was not requested or changed: " err.Message)
        }
        throw
    }
}

TransformBotzStockCode(stockCode) {
    stockCode := CleanText(stockCode)
    LogText("botz-stock-code", "GO b2b stock code: " stockCode)
    if !RegExMatch(stockCode, "^[A-Za-z][0-9]{2,}$")
        throw Error("Invalid GO b2b stock code '" stockCode "'. Expected one leading letter followed by digits, similar to B91018.")

    matchCode := SubStr(stockCode, 2, StrLen(stockCode) - 2)
    if !RegExMatch(matchCode, "^[0-9]+$")
        throw Error("Removing the first and final stock-code characters did not produce a numeric BOTZ folder code.")
    LogText("botz-match-code", "Stock code " stockCode " transformed to exact folder code " matchCode ".")
    return matchCode
}

FindUniqueBotzProductFolder(matchCode) {
    global botzRootDir
    if !DirExist(botzRootDir)
        throw Error("BOTZ source root was not found: " botzRootDir)

    prefix := matchCode " "
    matches := []
    Loop Files botzRootDir "\*", "D" {
        if SubStr(A_LoopFileName, 1, StrLen(prefix)) = prefix
            matches.Push(A_LoopFileFullPath)
    }

    if matches.Length = 0
        throw Error("No BOTZ folder begins with the exact numeric prefix '" prefix "' under " botzRootDir ".")
    if matches.Length > 1 {
        matchList := ""
        for _, path in matches
            matchList .= (matchList = "" ? "" : "`n") path
        throw Error("Multiple BOTZ folders begin with the exact numeric prefix '" prefix "':`n" matchList)
    }

    LogText("botz-folder-match", "Exact prefix '" prefix "' matched: " matches[1])
    return matches[1]
}

BuildBotzSourceLog(state) {
    text := "Product name: " state["productName"]
    text .= "`nGO b2b stock code: " state["stockCode"]
    text .= "`nTransformed matching code: " state["matchCode"]
    text .= "`nMatched BOTZ folder: " state["productFolder"]
    text .= "`nproduct.md path: " state["productMdPath"]
    text .= "`nDiscovered image count: " state["imageCount"]
    for index, imagePath in state["images"]
        text .= "`nImage " index ": " imagePath
    return text
}

PasteBotzOutputToCms() {
    global cmsWinTitle, useRecommendedProductName
    global lastSavedNonMatrixProductIdentity

    try {
        ClearActiveCmsProductCode()
        response := A_Clipboard
        state := LoadBotzState()
        SetActiveCmsProductCode(state["stockCode"])
        ValidateBotzSourcesUnchanged(state)
        block := ExtractValidatedAutomationBlock(response)
        output := ParseBotzAutomationOutput(block, state)
        LogText("botz-chatgpt-output", response)
        LogText("botz-parsed-output", BuildBotzParsedOutputLog(output))

        ActivateWindow(cmsWinTitle)
        VerifyBotzCmsProduct(state, output)
        UploadAndPopulateBotzImages(state, output)

        completedProductName := state["productName"]
        if useRecommendedProductName && IsUsableProductNameRecommendation(output["productNameRecommendation"]) {
            InsertProductNameRecommendation(output["productNameRecommendation"])
            completedProductName := CleanText(CopyFromPoint("product_name"))
            if completedProductName = ""
                throw Error("The updated BOTZ Product Name could not be read back from GO b2b.")
        }
        InsertMetaFields(output["metaTitle"], output["metaDescription"], output["htmlSnippet"])
        lastSavedNonMatrixProductIdentity := Map(
            "productName", completedProductName,
            "productCode", state["stockCode"]
        )
        ClickPoint("product_save_button", 1000)

        LogText("botz-product-complete", "Completed BOTZ Product Creation for '" state["productName"] "' (" state["stockCode"] ") with " state["imageCount"] " image(s).")
        Flash("BOTZ product created and saved with " state["imageCount"] " image(s).", 3000)
    } catch as err {
        if HasActiveCmsProductCode() {
            LogText("botz-error", "Product update stopped: " err.Message)
            LogText("botz-skipped-product", "BOTZ product was not completed: " err.Message)
        }
        throw
    }
}

ValidateBotzSourcesUnchanged(state) {
    global maximumImagesPerProduct
    if !FileExist(state["productMdPath"])
        throw Error("The saved BOTZ product.md no longer exists: " state["productMdPath"])
    if FileGetSize(state["productMdPath"]) != state["productMdSize"] || FileGetTime(state["productMdPath"], "M") != state["productMdModified"]
        throw Error("product.md changed after the ChatGPT request was built. Rebuild the BOTZ prompt before continuing.")

    matchedFolder := FindUniqueBotzProductFolder(state["matchCode"])
    if StrLower(matchedFolder) != StrLower(state["productFolder"])
        throw Error("The exact BOTZ folder match changed after the request was built. Rebuild the BOTZ prompt.")

    currentImages := EnumerateBotzImageFiles(state["productFolder"] "\images", maximumImagesPerProduct)
    if !BotzPathArraysMatch(currentImages, state["images"])
        throw Error("The BOTZ images folder changed after the ChatGPT request was built. Rebuild the prompt so image order and output fields remain aligned.")
    Loop currentImages.Length {
        imagePath := currentImages[A_Index]
        savedItem := state["imageManifest"][A_Index]
        if FileGetSize(imagePath) != savedItem["size"] || FileGetTime(imagePath, "M") != savedItem["modified"]
            throw Error("BOTZ image " A_Index " changed after the ChatGPT request was built: " imagePath ". Rebuild the prompt before uploading.")
    }
}

VerifyBotzCmsProduct(state, output) {
    ClickPoint("overview_tab", 500)
    currentProductName := CleanText(CopyFromPoint("product_name"))
    currentStockCode := CleanText(CopyFromPoint("stock_code"))
    if currentStockCode != state["stockCode"]
        throw Error("The open GO b2b stock code changed. Expected '" state["stockCode"] "', found '" currentStockCode "'.")
    if TransformBotzStockCode(currentStockCode) != state["matchCode"]
        throw Error("The open GO b2b product no longer maps to the saved BOTZ folder code.")

    originalMatches := NormaliseHarmlessWhitespace(currentProductName) = NormaliseHarmlessWhitespace(state["productName"])
    recommendedMatches := IsUsableProductNameRecommendation(output["productNameRecommendation"])
        && NormaliseHarmlessWhitespace(currentProductName) = NormaliseHarmlessWhitespace(output["productNameRecommendation"])
    if !originalMatches && !recommendedMatches
        throw Error("The open GO b2b product name does not match the saved BOTZ run. Expected '" state["productName"] "', found '" currentProductName "'.")
    LogText("botz-product-verified", "Product name: " currentProductName "`nStock code: " currentStockCode "`nFolder code: " state["matchCode"])
}

UploadAndPopulateBotzImages(state, output) {
    if state["pendingImageIndex"]
        throw Error("A previous BOTZ run stopped while image " state["pendingImageIndex"] " was being added. Inspect that image manually before retrying; no image was uploaded twice.")
    if state["uploadedCount"] = state["imageCount"] {
        LogText("botz-upload-recovery", "Saved BOTZ progress already marks all " state["imageCount"] " image detail record(s) complete; uploads were skipped.")
        return true
    }

    startIndex := state["uploadedCount"] + 1
    remaining := state["imageCount"] - state["uploadedCount"]
    LogText("botz-upload-recovery", "Starting/resuming BOTZ upload at image " startIndex " of " state["imageCount"] ".")

    Loop remaining {
        imageIndex := startIndex + A_Index - 1
        imagePath := state["images"][imageIndex]
        try {
            UploadAndPopulateSingleBotzImage(state, imagePath, imageIndex, state["imageCount"], output)
            state["uploadedCount"] := imageIndex
            state["pendingImageIndex"] := 0
            SaveBotzState(state)
        } catch as err {
            LogText("botz-upload-error", "Image " imageIndex " of " state["imageCount"] ": " imagePath "`n" err.Message)
            throw Error("BOTZ image upload/details stopped at image " imageIndex " of " state["imageCount"] ": " err.Message)
        }
    }
    return true
}

UploadAndPopulateSingleBotzImage(state, imagePath, imageIndex, totalImages, output) {
    global botzFilePickerTimeoutMs, botzImagesTabLoadMs, botzImageDetailsLoadMs
    if !FileExist(imagePath)
        throw Error("Image source no longer exists: " imagePath)

    ; Give the Images tab time to render before clicking its Add button.
    ClickPoint("images_tab", botzImagesTabLoadMs)
    LogText("botz-image-upload", "Starting image " imageIndex " of " totalImages ": " imagePath)
    ClickPoint("image_add_button", 500)
    picker := WinWaitActive("ahk_class #32770", , botzFilePickerTimeoutMs / 1000)
    if !picker
        throw Error("The GO b2b Add button did not open the Windows file picker.")
    ChooseSingleFileInPicker(imagePath)

    ; The file has been submitted. Persist an ambiguous in-progress state before
    ; touching the detail form so recovery cannot upload the same image twice.
    state["pendingImageIndex"] := imageIndex
    SaveBotzState(state)

    ToolTip "Waiting for image " imageIndex " detail fields..."
    Sleep botzImageDetailsLoadMs
    PasteToPoint("image_name", output["imageNames"][imageIndex])
    PasteToPoint("image_title", output["imageTitles"][imageIndex])
    PasteToPoint("image_alt", output["imageAlts"][imageIndex])
    ClickPoint("image_save_button", 1200)

    LogText(
        "botz-image-metadata",
        "Uploaded and saved image " imageIndex " of " totalImages ": " imagePath
        . "`nName: " output["imageNames"][imageIndex]
        . "`nTitle: " output["imageTitles"][imageIndex]
        . "`nAlt/tag: " output["imageAlts"][imageIndex]
    )
}

