BuildMatrixImagePrompt(pageUrl) {
    global cmsWinTitle, chatgptWinTitle, imageCountToProcess, matrixState
    global additionalProductNotesDefault, activeMatrixParentProductName
    ValidateImageTargetConfig()
    ClearActiveCmsProductCode()
    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    parentName := SetActiveMatrixParentName()
    activeMatrixParentProductName := parentName
    ClickPoint("description_tab", 600)
    parentTitle := CopyOptionalFromPoint("meta_title")
    firstHtml := ""
    parentDescription := CopyOptionalFromPoint("meta_description")
    parentImageCount := DetectAndSetImageCountFromImagesTab()
    if parentImageCount
        if !TryCopyCmsImagesToChatGPT(false) && IsAutomaticWorkflowExecutionEnabled()
            throw Error("Full workflow automation stopped because the matrix parent images were not pasted into ChatGPT successfully.")
    ; Visiting the parent Images tab can leave Chromium's matrix-SKU UIA tree
    ; stale. Close and reopen the complete parent before the first SKU scan so
    ; ReacquireMatrixSkuControls reads a newly built accessibility tree.
    ActivateWindow(cmsWinTitle)
    FullyReopenActiveMatrixParent()
    initial := ReacquireMatrixSkuControls(0)
    productCount := initial["buttons"].Length
    products := []
    Loop productCount {
        p := A_Index
        rowText := NormaliseMatrixRowText(initial["buttons"][p].RowText)
        exactName := ExtractMatrixProductNameFromRow(rowText, p)
        variantContext := ExtractMatrixVariantFromRow(rowText, exactName)
        products.Push(Map("index", p, "productName", exactName, "variantContext", variantContext, "skuRowText", rowText, "imageCount", 0))
    }

    ; Collect and attach each child's images during the same visit. Counts are
    ; read independently because matrix children need not share an image count.
    Loop productCount {
        p := A_Index
        ; The initial discovery tree is still fresh for child 1. Every later
        ; child gets one new tree after the parent has been fully reopened.
        controls := p = 1 ? initial : ReacquireAndValidateMatrixOrder(products)
        ClickMatrixEditButton(controls["buttons"][p])
        WaitForChildProductPage(p, productCount)
        if p = 1 {
            ClickPoint("description_tab", 600)
            firstHtml := CopyOptionalFromPoint("html_snippet")
        }
        products[p]["imageCount"] := DetectAndSetImageCountFromImagesTab()
        if products[p]["imageCount"]
            if !TryCopyCmsImagesToChatGPT(false) && IsAutomaticWorkflowExecutionEnabled()
                throw Error("Full workflow automation stopped because images for matrix product " p " were not pasted into ChatGPT successfully.")
        ActivateWindow(cmsWinTitle)
        ClickPoint("matrix_child_cancel_button", 300)
        WaitForMatrixSkuPage(p, productCount)
    }
    matrixState := Map("mode", "matrix_image", "parentProductName", parentName, "productCount", productCount, "parentImageCount", parentImageCount, "products", products)
    SaveMatrixState(matrixState)
    promptTemplatePath := GetPromptTemplatePath()
    if !FileExist(promptTemplatePath)
        throw Error("The selected matrix-image prompt template was not found: " promptTemplatePath)
    prompt := BuildMatrixPromptFromState(FileRead(promptTemplatePath, "UTF-8"), pageUrl, parentTitle, parentDescription, firstHtml, matrixState)
    LogText("matrix_image-parent-context", "Parent: " parentName "`nURL: " pageUrl "`nChildren: " productCount "`nParent images: " parentImageCount "`nTotal images: " GetMatrixTotalImageCount(matrixState))
    LogText("matrix_image-prompt", prompt)
    PastePromptToChatGPT(prompt)
    ActivateWindow(GetChatGptWinTitle())
    FocusChatGptInputForPaste()
    Flash("Matrix prompt and attachments are ready for manual review.", 3000)
}

PasteMatrixImageOutputToCms() {
    global cmsWinTitle, imageCountToProcess, imageTargets, activeMatrixParentProductName
    global departmentAutomationActive
    state := LoadMatrixState()
    activeMatrixParentProductName := state["parentProductName"]
    ValidateMatrixStateImageTargets(state, imageTargets.Length)
    ClearActiveCmsProductCode()
    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    activeMatrixParentProductName := SetActiveMatrixParentName(state["parentProductName"])
    response := A_Clipboard
    block := ExtractBetween(response, "===AUTOMATION_OUTPUT_START===", "===AUTOMATION_OUTPUT_END===")
    if block = ""
        throw Error("A complete matrix automation block is not on the clipboard.")
    output := ParseMatrixImageOutput(block, state)
    LogText("matrix_image-chatgpt-output", response)
    if state["parentImageCount"] {
        BeginSequentialImageMetadataInsertion(state["parentImageCount"])
        Loop state["parentImageCount"]
            PasteImageMetadataToCms(A_Index, output["parentImageTitles"][A_Index], output["parentImageAlts"][A_Index])
    }
    ; Saving/reopening also guarantees a fresh matrix accessibility tree after
    ; parent-image detail edits.
    FullyReopenActiveMatrixParent()
    ; Each child now receives exactly one fresh SKU-tree scan after the parent
    ; has been fully closed and reopened. Never reuse coordinates from the
    ; previous parent-menu instance.
    Loop state["productCount"] {
        p := A_Index
        try {
            controls := ReacquireAndValidateMatrixOrder(state["products"])
            ClickMatrixEditButton(controls["buttons"][p])
            WaitForChildProductPage(p, state["productCount"])
            ClickPoint("overview_tab", 400)
            currentName := CopyFromPoint("product_name")
            if NormaliseHarmlessWhitespace(currentName) != NormaliseHarmlessWhitespace(state["products"][p]["productName"])
                throw Error("current child name no longer matches saved product " p " ('" state["products"][p]["productName"] "').")
            childImageCount := state["products"][p]["imageCount"]
            if childImageCount
                BeginSequentialImageMetadataInsertion(childImageCount)
            Loop childImageCount {
                i := A_Index
                ToolTip "Matrix product " p " of " state["productCount"] "`nPasting image SEO " i " of " childImageCount
                PasteImageMetadataToCms(i, output["products"][p]["imageTitles"][i], output["products"][p]["imageAlts"][i])
                LogText("matrix_image-update", "Product " p ": " state["products"][p]["productName"] ", image " i " updated.")
            }
            ClickPoint("matrix_child_save_button", 300)
            WaitForMatrixSkuPage(p, state["productCount"])
        } catch as err {
            LogText("matrix_image-error", "Matrix product " p " of " state["productCount"] ": " err.Message)
            throw Error("Matrix product " p " of " state["productCount"] ": " err.Message "`n`nProcessing stopped. Leave this page open, inspect it, and retry only after correcting the state.")
        }
    }
    ToolTip()
    total := GetMatrixTotalImageCount(state)
    if !departmentAutomationActive
        MsgBox "Matrix image SEO complete.`nProducts: " state["productCount"] "`nParent images: " state["parentImageCount"] "`nTotal image records: " total
}

