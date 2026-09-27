GetSupplierProductProfile(submodeId := "") {
    global botzRootDir, crystalArtRootDir

    if submodeId = ""
        submodeId := GetSeoSubmodeId()
    submodeId := StrLower(Trim(submodeId))
    switch submodeId {
        case "botz":
            return Map(
                "submode", "botz",
                "displayName", "BOTZ",
                "logPrefix", "botz",
                "rootDir", botzRootDir,
                "outputMode", "BOTZ_PRODUCT_CREATION"
            )
        case "crystal_art":
            return Map(
                "submode", "crystal_art",
                "displayName", "Crystal Art",
                "logPrefix", "crystal-art",
                "rootDir", crystalArtRootDir,
                "outputMode", "CRYSTAL_ART_PRODUCT_CREATION"
            )
    }
    throw Error("Unsupported supplier-product submode '" submodeId "'.")
}

BuildSupplierProductPrompt(pageUrl) {
    global cmsWinTitle, botzState, botzPromptSettings, maximumImagesPerProduct

    profile := GetSupplierProductProfile()
    supplierName := profile["displayName"]
    logPrefix := profile["logPrefix"]
    try {
        ClearActiveCmsProductCode()
        ActivateWindow(cmsWinTitle)
        ClickPoint("overview_tab", 500)
        stockCode := SetActiveCmsProductCode(CopyFromPoint("stock_code"))
        productName := CleanText(CopyFromPoint("product_name"))
        if productName = ""
            throw Error("The GO b2b product name is blank.")

        matchCode := TransformSupplierStockCode(stockCode, profile["submode"])
        productFolder := FindUniqueSupplierProductFolder(matchCode, profile)
        productMdPath := productFolder "\product.md"
        imagesDir := productFolder "\images"
        if !FileExist(productMdPath)
            throw Error("The matched " supplierName " folder has no product.md file: " productMdPath)
        if !DirExist(imagesDir)
            throw Error("The matched " supplierName " folder has no images folder: " imagesDir)

        productMd := FileRead(productMdPath, "UTF-8")
        if CleanText(productMd) = ""
            throw Error("The matched product.md file is empty: " productMdPath)

        ; The image directory is the source of truth. The image list embedded
        ; in product.md is intentionally not trusted by the automation.
        attachmentImageFiles := EnumerateBotzImageFiles(imagesDir)
        if attachmentImageFiles.Length = 0
            throw Error("The matched " supplierName " images folder contains no supported image files: " imagesDir)
        imageFiles := TakeFirstBotzImageFiles(attachmentImageFiles, maximumImagesPerProduct)
        imageManifest := BuildBotzImageManifest(imageFiles)

        promptTemplatePath := GetPromptTemplatePath()
        if !FileExist(promptTemplatePath)
            throw Error("The selected " supplierName " prompt template was not found: " promptTemplatePath)
        if !IsObject(botzPromptSettings)
            InitialiseSeoPromptSettings()
        prompt := BuildSupplierProductPromptFromSource(
            FileRead(promptTemplatePath, "UTF-8"),
            pageUrl,
            productName,
            productMd,
            imageFiles,
            botzPromptSettings,
            attachmentImageFiles,
            supplierName
        )

        botzState := Map(
            "mode", "supplier_product",
            "submode", profile["submode"],
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

        LogText(logPrefix "-source", BuildSupplierProductSourceLog(botzState, profile))
        LogSupplierChatGptImagePlan(supplierName, logPrefix, attachmentImageFiles.Length, imageFiles.Length)
        LogText(logPrefix "-chatgpt-request", prompt)
        PastePromptToChatGPT(prompt)
        ValidateSupplierProductSourcesUnchanged(botzState)
        AttachBotzImagesToChatGpt(attachmentImageFiles, supplierName, logPrefix)
        Flash(supplierName " prompt and " attachmentImageFiles.Length " image attachment(s) were submitted to ChatGPT.`nGO b2b remains limited to the first " imageFiles.Length " image(s).", 3000)
    } catch as err {
        if HasActiveCmsProductCode() {
            LogText(logPrefix "-error", "Prompt build stopped: " err.Message)
            LogText(logPrefix "-skipped-product", supplierName " product was not requested or changed: " err.Message)
        }
        throw
    }
}

; Retained as a compatibility entry point for any personal hotkey overrides.
BuildBotzPrompt(pageUrl) {
    return BuildSupplierProductPrompt(pageUrl)
}

TransformSupplierStockCode(stockCode, submodeId) {
    stockCode := CleanText(stockCode)
    profile := GetSupplierProductProfile(submodeId)
    LogText(profile["logPrefix"] "-stock-code", "GO b2b stock code: " stockCode)

    if submodeId = "botz" {
        if !RegExMatch(stockCode, "^[A-Za-z][0-9]{2,}$")
            throw Error("Invalid GO b2b BOTZ stock code '" stockCode "'. Expected one leading letter followed by digits, similar to B91018.")
        matchCode := SubStr(stockCode, 2, StrLen(stockCode) - 2)
        if !RegExMatch(matchCode, "^[0-9]+$")
            throw Error("Removing the first and final stock-code characters did not produce a numeric BOTZ folder code.")
    } else if submodeId = "crystal_art" {
        if !RegExMatch(stockCode, "i)^[a-z0-9]+(?:-[a-z0-9]+)*$")
            throw Error("Invalid GO b2b Crystal Art product code '" stockCode "'. Expected a complete hyphenated code similar to CAFGR-34DNY126.")
        matchCode := stockCode
    } else
        throw Error("Unsupported supplier-product submode '" submodeId "'.")

    LogText(profile["logPrefix"] "-match-code", "Stock code " stockCode " maps to exact folder code " matchCode ".")
    return matchCode
}

TransformBotzStockCode(stockCode) {
    return TransformSupplierStockCode(stockCode, "botz")
}

FindUniqueSupplierProductFolder(matchCode, profile) {
    rootDir := profile["rootDir"]
    supplierName := profile["displayName"]
    if !DirExist(rootDir)
        throw Error(supplierName " source root was not found: " rootDir)

    prefix := matchCode " "
    matches := []
    Loop Files rootDir "\*", "D" {
        if StrLower(SubStr(A_LoopFileName, 1, StrLen(prefix))) = StrLower(prefix)
            matches.Push(A_LoopFileFullPath)
    }

    if matches.Length = 0
        throw Error("No " supplierName " folder begins with the exact product-code prefix '" prefix "' under " rootDir ".")
    if matches.Length > 1 {
        matchList := ""
        for _, path in matches
            matchList .= (matchList = "" ? "" : "`n") path
        throw Error("Multiple " supplierName " folders begin with the exact product-code prefix '" prefix "':`n" matchList)
    }

    LogText(profile["logPrefix"] "-folder-match", "Exact prefix '" prefix "' matched: " matches[1])
    return matches[1]
}

FindUniqueBotzProductFolder(matchCode) {
    return FindUniqueSupplierProductFolder(matchCode, GetSupplierProductProfile("botz"))
}

BuildSupplierProductSourceLog(state, profile) {
    text := "Supplier submode: " state["submode"]
    text .= "`nProduct name: " state["productName"]
    text .= "`nGO b2b stock code: " state["stockCode"]
    text .= "`nFolder matching code: " state["matchCode"]
    text .= "`nMatched " profile["displayName"] " folder: " state["productFolder"]
    text .= "`nproduct.md path: " state["productMdPath"]
    text .= "`nDiscovered CMS image count: " state["imageCount"]
    for index, imagePath in state["images"]
        text .= "`nImage " index ": " imagePath
    return text
}

BuildBotzSourceLog(state) {
    return BuildSupplierProductSourceLog(state, GetSupplierProductProfile("botz"))
}

PasteSupplierProductOutputToCms() {
    global cmsWinTitle, useRecommendedProductName
    global lastSavedNonMatrixProductIdentity

    state := LoadBotzState()
    profile := GetSupplierProductProfile(state["submode"])
    supplierName := profile["displayName"]
    logPrefix := profile["logPrefix"]
    try {
        if !IsSupplierProductCreationMode() || GetSeoSubmodeId() != state["submode"]
            throw Error("The saved run uses the " supplierName " submode. Select that same supplier-product submode before inserting its output.")
        ClearActiveCmsProductCode()
        response := A_Clipboard
        SetActiveCmsProductCode(state["stockCode"])
        ValidateSupplierProductSourcesUnchanged(state)
        block := ExtractValidatedAutomationBlock(response)
        output := ParseSupplierProductAutomationOutput(block, state, profile)
        LogText(logPrefix "-chatgpt-output", response)
        LogText(logPrefix "-parsed-output", BuildBotzParsedOutputLog(output))

        ActivateWindow(cmsWinTitle)
        VerifySupplierProductInCms(state, output, profile)
        UploadAndPopulateSupplierProductImages(state, output, profile)

        completedProductName := state["productName"]
        if useRecommendedProductName && IsUsableProductNameRecommendation(output["productNameRecommendation"]) {
            InsertProductNameRecommendation(output["productNameRecommendation"])
            completedProductName := CleanText(CopyFromPoint("product_name"))
            if completedProductName = ""
                throw Error("The updated " supplierName " Product Name could not be read back from GO b2b.")
        }
        InsertMetaFields(output["metaTitle"], output["metaDescription"], output["htmlSnippet"])
        lastSavedNonMatrixProductIdentity := Map(
            "productName", completedProductName,
            "productCode", state["stockCode"]
        )
        ClickPoint("product_save_button", 1000)

        LogText(logPrefix "-product-complete", "Completed " supplierName " product creation for '" state["productName"] "' (" state["stockCode"] ") with " state["imageCount"] " image(s).")
        Flash(supplierName " product created and saved with " state["imageCount"] " image(s).", 3000)
    } catch as err {
        if HasActiveCmsProductCode() {
            LogText(logPrefix "-error", "Product update stopped: " err.Message)
            LogText(logPrefix "-skipped-product", supplierName " product was not completed: " err.Message)
        }
        throw
    }
}

PasteBotzOutputToCms() {
    return PasteSupplierProductOutputToCms()
}

ValidateSupplierProductSourcesUnchanged(state) {
    global maximumImagesPerProduct
    profile := GetSupplierProductProfile(state["submode"])
    supplierName := profile["displayName"]
    if !FileExist(state["productMdPath"])
        throw Error("The saved " supplierName " product.md no longer exists: " state["productMdPath"])
    if FileGetSize(state["productMdPath"]) != state["productMdSize"] || FileGetTime(state["productMdPath"], "M") != state["productMdModified"]
        throw Error("product.md changed after the ChatGPT request was built. Rebuild the " supplierName " prompt before continuing.")

    matchedFolder := FindUniqueSupplierProductFolder(state["matchCode"], profile)
    if StrLower(matchedFolder) != StrLower(state["productFolder"])
        throw Error("The exact " supplierName " folder match changed after the request was built. Rebuild the prompt.")

    currentImages := EnumerateBotzImageFiles(state["productFolder"] "\images", maximumImagesPerProduct)
    if !BotzPathArraysMatch(currentImages, state["images"])
        throw Error("The " supplierName " images folder changed after the ChatGPT request was built. Rebuild the prompt so image order and output fields remain aligned.")
    Loop currentImages.Length {
        imagePath := currentImages[A_Index]
        savedItem := state["imageManifest"][A_Index]
        if FileGetSize(imagePath) != savedItem["size"] || FileGetTime(imagePath, "M") != savedItem["modified"]
            throw Error(supplierName " image " A_Index " changed after the ChatGPT request was built: " imagePath ". Rebuild the prompt before uploading.")
    }
}

ValidateBotzSourcesUnchanged(state) {
    return ValidateSupplierProductSourcesUnchanged(state)
}

VerifySupplierProductInCms(state, output, profile) {
    ClickPoint("overview_tab", 500)
    currentProductName := CleanText(CopyFromPoint("product_name"))
    currentStockCode := CleanText(CopyFromPoint("stock_code"))
    if currentStockCode != state["stockCode"]
        throw Error("The open GO b2b stock code changed. Expected '" state["stockCode"] "', found '" currentStockCode "'.")
    if TransformSupplierStockCode(currentStockCode, state["submode"]) != state["matchCode"]
        throw Error("The open GO b2b product no longer maps to the saved " profile["displayName"] " folder code.")

    originalMatches := NormaliseHarmlessWhitespace(currentProductName) = NormaliseHarmlessWhitespace(state["productName"])
    recommendedMatches := IsUsableProductNameRecommendation(output["productNameRecommendation"])
        && NormaliseHarmlessWhitespace(currentProductName) = NormaliseHarmlessWhitespace(output["productNameRecommendation"])
    if !originalMatches && !recommendedMatches
        throw Error("The open GO b2b product name does not match the saved " profile["displayName"] " run. Expected '" state["productName"] "', found '" currentProductName "'.")
    LogText(profile["logPrefix"] "-product-verified", "Product name: " currentProductName "`nStock code: " currentStockCode "`nFolder code: " state["matchCode"])
}

VerifyBotzCmsProduct(state, output) {
    return VerifySupplierProductInCms(state, output, GetSupplierProductProfile("botz"))
}

UploadAndPopulateSupplierProductImages(state, output, profile) {
    supplierName := profile["displayName"]
    logPrefix := profile["logPrefix"]
    if state["pendingImageIndex"]
        throw Error("A previous " supplierName " run stopped while image " state["pendingImageIndex"] " was being added. Inspect that image manually before retrying; no image was uploaded twice.")
    if state["uploadedCount"] = state["imageCount"] {
        LogText(logPrefix "-upload-recovery", "Saved progress already marks all " state["imageCount"] " image detail record(s) complete; uploads were skipped.")
        return true
    }

    startIndex := state["uploadedCount"] + 1
    remaining := state["imageCount"] - state["uploadedCount"]
    LogText(logPrefix "-upload-recovery", "Starting/resuming " supplierName " upload at image " startIndex " of " state["imageCount"] ".")

    Loop remaining {
        imageIndex := startIndex + A_Index - 1
        imagePath := state["images"][imageIndex]
        try {
            UploadAndPopulateSingleSupplierProductImage(state, imagePath, imageIndex, state["imageCount"], output, profile)
            state["uploadedCount"] := imageIndex
            state["pendingImageIndex"] := 0
            SaveBotzState(state)
        } catch as err {
            LogText(logPrefix "-upload-error", "Image " imageIndex " of " state["imageCount"] ": " imagePath "`n" err.Message)
            throw Error(supplierName " image upload/details stopped at image " imageIndex " of " state["imageCount"] ": " err.Message)
        }
    }
    return true
}

UploadAndPopulateBotzImages(state, output) {
    return UploadAndPopulateSupplierProductImages(state, output, GetSupplierProductProfile(state["submode"]))
}

UploadAndPopulateSingleSupplierProductImage(state, imagePath, imageIndex, totalImages, output, profile) {
    global botzFilePickerTimeoutMs, botzImagesTabLoadMs, botzImageDetailsLoadMs
    if !FileExist(imagePath)
        throw Error("Image source no longer exists: " imagePath)

    ClickPoint("images_tab", botzImagesTabLoadMs)
    LogText(profile["logPrefix"] "-image-upload", "Starting image " imageIndex " of " totalImages ": " imagePath)
    ClickPoint("image_add_button", 500)
    picker := WinWaitActive("ahk_class #32770", , botzFilePickerTimeoutMs / 1000)
    if !picker
        throw Error("The GO b2b Add button did not open the Windows file picker.")
    ChooseSingleFileInPicker(imagePath)

    ; Persist the ambiguous in-progress state before touching the detail form,
    ; ensuring recovery cannot upload the same image twice.
    state["pendingImageIndex"] := imageIndex
    SaveBotzState(state)

    ToolTip "Waiting for image " imageIndex " detail fields..."
    Sleep botzImageDetailsLoadMs
    PasteToPoint("image_name", output["imageNames"][imageIndex])
    PasteToPoint("image_title", output["imageTitles"][imageIndex])
    PasteToPoint("image_alt", output["imageAlts"][imageIndex])
    ClickPoint("image_save_button", 1200)

    LogText(
        profile["logPrefix"] "-image-metadata",
        "Uploaded and saved image " imageIndex " of " totalImages ": " imagePath
        . "`nName: " output["imageNames"][imageIndex]
        . "`nTitle: " output["imageTitles"][imageIndex]
        . "`nAlt/tag: " output["imageAlts"][imageIndex]
    )
}

UploadAndPopulateSingleBotzImage(state, imagePath, imageIndex, totalImages, output) {
    return UploadAndPopulateSingleSupplierProductImage(state, imagePath, imageIndex, totalImages, output, GetSupplierProductProfile(state["submode"]))
}
