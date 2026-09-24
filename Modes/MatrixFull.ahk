BuildMatrixFullPrompt(pageUrl) {
    global cmsWinTitle, chatgptWinTitle, imageCountToProcess, matrixFullState
    global activeMatrixParentProductName
    ValidateImageTargetConfig()
    ClearActiveCmsProductCode()
    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    parentName := SetActiveMatrixParentName()
    activeMatrixParentProductName := parentName
    ClickPoint("description_tab", 600)
    parentTitle := CopyOptionalFromPoint("meta_title")
    parentDescription := CopyOptionalFromPoint("meta_description")
    parentImageCount := DetectAndSetImageCountFromImagesTab()
    if parentImageCount
        if !TryCopyCmsImagesToChatGPT(false) && IsAutomaticWorkflowExecutionEnabled()
            throw Error("Full workflow automation stopped because the matrix parent images were not pasted into ChatGPT successfully.")
    ; Rebuild the parent after inspecting its Images tab. The reopen helper
    ; returns on a fresh Matrix SKUs tab, ready for the first UIA lookup.
    ActivateWindow(cmsWinTitle)
    FullyReopenActiveMatrixParent()
    initial := ReacquireMatrixSkuControls(0)
    productCount := initial["buttons"].Length
    products := []
    Loop productCount {
        p := A_Index
        rowText := NormaliseMatrixRowText(initial["buttons"][p].RowText)
        exactName := ExtractMatrixProductNameFromRow(rowText, p)
        connectedSize := ExtractConnectedMatrixSkuSize(rowText)
        products.Push(Map("index", p, "productName", exactName, "connectedSize", connectedSize, "variantContext", ExtractMatrixVariantFromRow(rowText, exactName), "skuRowText", rowText, "originalHtmlSnippet", "", "imageCount", 0))
    }

    ; Visit every child separately. As in matrix_image, fully close and reopen
    ; the parent after every child return because GO b2b otherwise leaves
    ; Chrome's accessibility tree in a broken/stale state.
    Loop productCount {
        p := A_Index
        ; Do not build a second tree in the same SKU menu before child 1.
        controls := p = 1 ? initial : ReacquireAndValidateMatrixOrder(products)
        ClickMatrixEditButton(controls["buttons"][p])
        WaitForChildProductPage(p, productCount)
        ClickPoint("overview_tab", 400)
        currentName := CopyFromPoint("product_name")
        if NormaliseHarmlessWhitespace(currentName) != NormaliseHarmlessWhitespace(products[p]["productName"])
            throw Error("Matrix-full collection opened the wrong child at product " p ". Expected '" products[p]["productName"] "', found '" currentName "'.")
        ClickPoint("description_tab", 600)
        products[p]["originalHtmlSnippet"] := CopyOptionalFromPoint("html_snippet")
        products[p]["imageCount"] := DetectAndSetImageCountFromImagesTab()
        if products[p]["imageCount"]
            if !TryCopyCmsImagesToChatGPT(false) && IsAutomaticWorkflowExecutionEnabled()
                throw Error("Full workflow automation stopped because images for matrix product " p " were not pasted into ChatGPT successfully.")
        ActivateWindow(cmsWinTitle)
        LogText("matrix_full-child-context", "Product " p ": " products[p]["productName"] "`nConnected SKU size: " products[p]["connectedSize"] "`nVariant: " products[p]["variantContext"] "`nSKU row: " products[p]["skuRowText"] "`nHTML:`n" products[p]["originalHtmlSnippet"])
        ClickPoint("matrix_child_cancel_button", 300)
        WaitForMatrixSkuPage(p, productCount)
    }

    matrixFullState := Map("mode", "matrix_full", "parentProductName", parentName, "productCount", productCount, "parentImageCount", parentImageCount, "products", products)
    SaveMatrixState(matrixFullState)
    promptTemplatePath := GetPromptTemplatePath()
    if !FileExist(promptTemplatePath)
        throw Error("The selected matrix-full prompt template was not found: " promptTemplatePath)
    prompt := BuildMatrixFullPromptFromState(FileRead(promptTemplatePath, "UTF-8"), pageUrl, parentTitle, parentDescription, matrixFullState)
    LogText("matrix_full-parent-context", "Parent: " parentName "`nURL: " pageUrl "`nMeta title: " parentTitle "`nMeta description: " parentDescription "`nChildren: " productCount "`nParent images: " parentImageCount "`nTotal images: " GetMatrixTotalImageCount(matrixFullState))
    LogText("matrix_full-prompt", prompt)
    PastePromptToChatGPT(prompt)

    ActivateWindow(GetChatGptWinTitle())
    FocusChatGptInputForPaste()
    Flash("Matrix-full prompt and attachments are ready for manual review.", 3000)
}

PasteMatrixFullOutputToCms() {
    global cmsWinTitle, imageCountToProcess, imageTargets, activeMatrixParentProductName, useRecommendedProductName
    global departmentAutomationActive
    state := LoadMatrixState("matrix_full")
    activeMatrixParentProductName := state["parentProductName"]
    ValidateMatrixStateImageTargets(state, imageTargets.Length)
    ClearActiveCmsProductCode()
    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    activeMatrixParentProductName := SetActiveMatrixParentName(state["parentProductName"])
    response := A_Clipboard
    block := ExtractBetween(response, "===AUTOMATION_OUTPUT_START===", "===AUTOMATION_OUTPUT_END===")
    if block = ""
        throw Error("A complete matrix-full automation block is not on the clipboard.")

    ; Parsing and validation finish before the first CMS field is changed.
    output := ParseMatrixFullOutput(block, state)
    LogText("matrix_full-chatgpt-output", response)
    LogText("matrix_full-automation-block", block)
    LogText("matrix_full-parsed-output", BuildMatrixFullParsedLog(output))
    if useRecommendedProductName && IsUsableProductNameRecommendation(output["parentProductNameRecommendation"]) {
        InsertProductNameRecommendation(output["parentProductNameRecommendation"])
        ; Read the value back from GO b2b and use that exact CMS value for the
        ; catalogue lookup. The pasted recommendation may contain whitespace
        ; or characters which the input normalises when it accepts the value.
        activeMatrixParentProductName := CopyFromPoint("product_name")
        if Trim(activeMatrixParentProductName) = ""
            throw Error("The renamed matrix parent could not be read back from the Product Name field.")
        LogText("matrix_full-update", "Parent reopen name after rename: " activeMatrixParentProductName)
    }
    InsertMatrixParentMetaFields(output["parentMetaTitle"], output["parentMetaDescription"])
    if state["parentImageCount"] {
        BeginSequentialImageMetadataInsertion(state["parentImageCount"])
        Loop state["parentImageCount"]
            PasteImageMetadataToCms(A_Index, output["parentImageTitles"][A_Index], output["parentImageAlts"][A_Index])
    }

    ; GO b2b invalidates/stales the matrix accessibility tree after any parent
    ; field is changed. Save and fully reopen the exact parent before opening
    ; Matrix SKUs, using the same recovery path as child return transitions.
    FullyReopenActiveMatrixParent()

    Loop state["productCount"] {
        p := A_Index
        try {
            controls := ReacquireAndValidateMatrixOrder(state["products"])
            ClickMatrixEditButton(controls["buttons"][p])
            WaitForChildProductPage(p, state["productCount"])
            ClickPoint("overview_tab", 400)
            currentName := CopyFromPoint("product_name")
            if NormaliseHarmlessWhitespace(currentName) != NormaliseHarmlessWhitespace(state["products"][p]["productName"])
                throw Error("current child name no longer matches saved product '" state["products"][p]["productName"] "'; found '" currentName "'.")
            childImageCount := state["products"][p]["imageCount"]
            ClickPoint("description_tab", 600)
            ; Child matrix SKUs must inherit metadata from the parent matrix
            ; page. Explicitly clear any legacy child-level metadata before
            ; replacing the child's HTML description.
            PasteToPoint("meta_title", "")
            PasteToPoint("meta_description", "")
            PasteToPoint("html_snippet", output["products"][p]["htmlSnippet"])
            if childImageCount
                BeginSequentialImageMetadataInsertion(childImageCount)
            Loop childImageCount {
                i := A_Index
                ToolTip "Matrix-full product " p " of " state["productCount"] "`nPasting image SEO " i " of " childImageCount
                PasteImageMetadataToCms(i, output["products"][p]["imageTitles"][i], output["products"][p]["imageAlts"][i])
            }
            ClickPoint("matrix_child_save_button", 300)
            WaitForMatrixSkuPage(p, state["productCount"])
            LogText("matrix_full-update", "Product " p ": " state["products"][p]["productName"] "; child metadata cleared, HTML and " childImageCount " image record(s) updated.")
        } catch as err {
            LogText("matrix_full-error", "Product " p " ('" state["products"][p]["productName"] "'): " err.Message)
            throw Error("Matrix-full product " p " of " state["productCount"] " ('" state["products"][p]["productName"] "'):`n" err.Message "`n`nProcessing stopped to avoid updating the wrong child.")
        }
    }
    ToolTip()
    totalImages := GetMatrixTotalImageCount(state)
    nameStatus := useRecommendedProductName && IsUsableProductNameRecommendation(output["parentProductNameRecommendation"]) ? "Parent product name recommendation and metadata were pasted." : "Parent metadata was pasted; parent product name was left unchanged."
    completionMessage := "Matrix-full SEO complete.`nChild products: " state["productCount"] "`nParent images: " state["parentImageCount"] "`nChild HTML snippets updated: " state["productCount"] "`nTotal image records updated: " totalImages "`n" nameStatus "`nThe parent was saved/reopened by the matrix accessibility-tree recovery workflow."
    if !departmentAutomationActive
        MsgBox completionMessage
}

BuildMatrixFullParsedLog(output) {
    text := "Mode: " output["mode"] "`nParent recommendation: " output["parentProductNameRecommendation"] "`nParent meta title: " output["parentMetaTitle"] "`nParent meta description: " output["parentMetaDescription"] "`nProducts: " output["productCount"] "`n"
    Loop output["parentImageTitles"].Length
        text .= "Parent image " A_Index " title: " output["parentImageTitles"][A_Index] "`nParent image " A_Index " alt: " output["parentImageAlts"][A_Index] "`n"
    for p, product in output["products"] {
        text .= "`nProduct " p ": " product["productName"] "`nHTML:`n" product["htmlSnippet"] "`n"
        Loop product["imageTitles"].Length
            text .= "Image " A_Index " title: " product["imageTitles"][A_Index] "`nImage " A_Index " alt: " product["imageAlts"][A_Index] "`n"
    }
    return text
}

