BuildPromptFromCurrentProductPage(pageUrl, forceAutomaticCompletion := false) {
    global cmsWinTitle, chatgptWinTitle, SeoAutomationMode
    global requiredInternalLinksDefault, additionalProductNotesDefault
    global attemptImageCopyAfterPrompt, imageCountToProcess

    ValidateSeoAutomationMode()
    if IsDepartmentMode()
        imageCountToProcess := 1
    ClearActiveCmsProductCode()
    ActivateWindow(cmsWinTitle)
    ValidateImageTargetConfig()

    ; Overview tab: exact GO b2b identity and product name. Department review
    ; mode intentionally identifies the product by name and never reads Stock Code.
    ClickPoint("overview_tab", 500)
    productName := CopyFromPoint("product_name")
    if IsDepartmentMode()
        SetActiveCmsProductCode(productName)
    else
        SetActiveCmsProductCode(CopyFromPoint("stock_code"))
    TestingLog(
        "product-workflow-start",
        "Product name=" productName "; mode=" GetSeoAutomationMode() "; page_url=" pageUrl "."
    )

    ; Description tab: meta and HTML fields
    ClickPoint("description_tab", 600)
    ; These fields are allowed to be blank on unoptimised/new CMS pages.
    ; They should return an empty string instead of failing the whole hotkey.
    currentMetaTitle := CopyOptionalFromPoint("meta_title")
    currentHtmlSnippet := CopyOptionalFromPoint("html_snippet")
    currentMetaDescription := CopyOptionalFromPoint("meta_description")

    originalFields := "PAGE_URL:`n" pageUrl "`n`n"
    originalFields .= "PRODUCT_NAME:`n" productName "`n`n"
    originalFields .= "CURRENT_META_TITLE:`n" currentMetaTitle "`n`n"
    originalFields .= "CURRENT_META_DESCRIPTION:`n" currentMetaDescription "`n`n"
    originalFields .= "CURRENT_HTML_SNIPPET:`n" currentHtmlSnippet

    LogText("original-fields", originalFields)
    BackupText("original-fields", originalFields)

    ; Department review products always have one image, so avoid reading the GO
    ; b2b gallery tree and use the configured first-image coordinates instead.
    if IsDepartmentMode()
        TestingLog("department-image-count", "Using fixed image count=1 and configured coordinates; gallery UIA detection was skipped.")
    else {
        ; Count actual gallery cards from their exact Remove buttons. Image labels
        ; are deliberately ignored because GO B2B can skip label numbers.
        DetectAndSetImageCountFromImagesTab()
    }

    templatePath := GetPromptTemplatePath()

    if !FileExist(templatePath) {
        throw Error("Prompt template was not found beside this script for SEO mode '" SeoAutomationMode "': " templatePath)
    }

    template := ReadPromptTemplateFile(templatePath)
    imageNotes := GetDefaultImageNotes()

    prompt := BuildPromptFromTemplate(
        template,
        pageUrl,
        productName,
        currentMetaTitle,
        currentMetaDescription,
        currentHtmlSnippet,
        requiredInternalLinksDefault,
        imageNotes,
        additionalProductNotesDefault
    )
    prompt := IsImageOnlyMode() ? InjectImageOnlyOutputFields(prompt, imageCountToProcess) : EnsurePromptSupportsImageCount(prompt, imageCountToProcess)

    LogText("prompt", prompt)

    PastePromptToChatGPT(prompt)

    if attemptImageCopyAfterPrompt {
        imagesReady := TryCopyCmsImagesToChatGPT(false)
        if (IsAutomaticWorkflowExecutionEnabled() || forceAutomaticCompletion) && !imagesReady
            throw Error("Automatic workflow stopped before sending because one or more CMS images could not be pasted into ChatGPT.")
        Flash("Prompt pasted. Image copy attempted.")
        return
    }

    Flash("Prompt pasted. Attach image manually.")
}

PasteCopiedChatGPTOutputToCms(copyLatestResponse := true) {
    global cmsWinTitle, useRecommendedProductName, imageCountToProcess
    global lastSavedNonMatrixProductIdentity

    try {
        EnsureFolders()
        ValidateSeoAutomationMode()
        if copyLatestResponse
            CopyLatestChatGptResponseToClipboard()

        if IsBotzMode() {
            PasteBotzOutputToCms()
            return true
        }

        if IsFiguredArtMode() {
            PasteFiguredArtOutputToCms()
            return true
        }

        ValidateImageTargetConfig()

        if IsMatrixFullMode() {
            PasteMatrixFullOutputToCms()
            return true
        }

        if IsMatrixImageMode() {
            PasteMatrixImageOutputToCms()
            return true
        }

        ActivateWindow(cmsWinTitle)
        ClearActiveCmsProductCode()
        ClickPoint("overview_tab", 500)
        completedProductName := CleanText(CopyFromPoint("product_name"))
        if completedProductName = ""
            throw Error("The current GO b2b Product Name is blank, so the completed product cannot be identified safely.")
        if IsDepartmentMode() {
            SetActiveCmsProductCode(completedProductName)
            currentProductCode := ""
        } else
            currentProductCode := SetActiveCmsProductCode(CopyFromPoint("stock_code"))
        response := A_Clipboard

        if !InStr(response, "===AUTOMATION_OUTPUT_START===") {
            MsgBox "The automated ChatGPT copy did not place an automation block on the clipboard. No CMS fields were changed."
            return false
        }

        block := ExtractBetween(response, "===AUTOMATION_OUTPUT_START===", "===AUTOMATION_OUTPUT_END===")

        if block = "" {
            MsgBox "Automation markers were found, but the block could not be extracted."
            return false
        }

        output := IsImageOnlyMode() ? ParseImageOnlyOutput(block, imageCountToProcess) : ParseAutomationOutput(block, imageCountToProcess, IsMetadataOnlyMode())
        productNameRecommendation := output["productNameRecommendation"]
        metaTitle := output["metaTitle"]
        metaDescription := output["metaDescription"]
        htmlSnippet := output["htmlSnippet"]
        imageTitles := output["imageTitles"]
        imageAlts := output["imageAlts"]
        imageNames := output["imageNames"]
        TestingLog(
            "chatgpt-output-parsed",
            "Expected image count=" imageCountToProcess
            . "; parsed names=" imageNames.Length
            . "; parsed titles=" imageTitles.Length
            . "; parsed alts=" imageAlts.Length "."
        )

        LogText("chatgpt-output", response)
        LogText("automation-block", block)

        ; The strict image-only parser has already validated every required image
        ; field; metadata is intentionally absent in this mode.
        warnings := IsImageOnlyMode() ? "" : ValidateGeneratedFields(metaTitle, metaDescription, htmlSnippet, imageTitles, imageAlts, IsFullContentMode())

        if warnings != "" {
            MsgBox "Warnings found. No fields were pasted.`n`n" warnings
            return false
        }

        ActivateWindow(cmsWinTitle)

        ; Optional Overview tab: paste product name recommendation
        if !IsImageOnlyMode() && useRecommendedProductName && IsUsableProductNameRecommendation(productNameRecommendation) {
            InsertProductNameRecommendation(productNameRecommendation)
            ; Keep the exact value accepted by GO b2b. Department automation
            ; must find the renamed catalogue row, not the pre-update name that
            ; was captured before the ChatGPT workflow began.
            completedProductName := CleanText(CopyFromPoint("product_name"))
            if completedProductName = ""
                throw Error("The updated Product Name could not be read back from GO b2b.")
        }

        ; Description tab: paste meta fields. Full mode also pastes the HTML/product description field.
        if !IsImageOnlyMode()
            InsertMetaFields(metaTitle, metaDescription, htmlSnippet)

        ; Images tab: open each image details page and paste image metadata
        InsertImageSeoFields(imageTitles, imageAlts, imageNames)

        ; Save every ordinary workflow after all metadata and requested image
        ; records have been updated.
        if IsFullMode() || IsMetadataOnlyMode() || IsImageOnlyMode() {
            lastSavedNonMatrixProductIdentity := Map(
                "productName", completedProductName,
                "productCode", currentProductCode
            )
            ClickPoint("product_save_button", 1000)
        }

        if IsDepartmentMode()
            Flash("SEO fields pasted. Review the product, then save it manually.", 3000)
        else if IsFullMode()
            Flash("SEO fields pasted and product saved.")
        else if IsMetadataOnlyMode()
            Flash("Metadata and image SEO fields pasted and product saved.")
        else if IsImageOnlyMode()
            Flash("Image SEO fields pasted and product saved.")
        else
            Flash("SEO fields pasted; main product was not saved.")
        return true
    } catch as err {
        ReportTestingError("paste-chatgpt-output-to-cms", err)
        MsgBox "PasteCopiedChatGPTOutputToCms failed:`n`n" err.Message
        return false
    }
}

