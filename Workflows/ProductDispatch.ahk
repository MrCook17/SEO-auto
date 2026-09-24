OpenProductBuildPromptAndPasteToChatGPT() {
    global cmsWinTitle, hardcodedPageUrl

    try {
        EnsureFolders()
        ActivateWindow(cmsWinTitle)

        ; Use the temporary hardcoded public URL for {{PAGE_URL}}.
        ; Do not copy the browser URL here because the active page is a GO B2B CMS URL.
        pageUrl := hardcodedPageUrl

        if IsPromotionTextReferenceMode() {
            RunPromotionTextReferenceWorkflow()
            return
        }

        if IsMatrixImageMode()
            throw Error("NumpadEnter is not used for matrix-image mode. Open the matrix parent and press Numpad4.")

        ClickPoint("product_edit_button", 1500)
        if IsDisplayOnWebsiteAppMode() {
            RunDisplayOnWebsiteAppWorkflow()
            return
        } else if IsPromotionTextMode() {
            RunPromotionTextWorkflow()
            return
        } else if IsSupplierProductCreationMode()
            BuildSupplierProductCreationPrompt(pageUrl)
        else if IsMatrixFullMode()
            BuildMatrixFullPrompt(pageUrl)
        else
            BuildPromptFromCurrentProductPage(pageUrl)
        RunAutomaticWorkflowIfEnabled(IsSupplierProductCreationMode())
    } catch as err {
        ReportTestingError("open-product-workflow", err)
        MsgBox "OpenProductBuildPromptAndPasteToChatGPT failed:`n`n" err.Message
    }
}

BuildPromptFromOpenProductPageAndPasteToChatGPT() {
    try {
        return RunOpenProductWorkflow(false)
    } catch as err {
        ReportTestingError("open-current-product-workflow", err)
        MsgBox "BuildPromptFromOpenProductPageAndPasteToChatGPT failed:`n`n" err.Message
        return false
    }
}

RunOpenProductWorkflow(forceAutomaticCompletion := false) {
    global cmsWinTitle, hardcodedPageUrl

    EnsureFolders()
    ActivateWindow(cmsWinTitle)

    ; Use the temporary hardcoded public URL for {{PAGE_URL}}. Do not copy the
    ; browser URL because the active page is a GO b2b CMS URL.
    pageUrl := hardcodedPageUrl
    if IsPromotionTextReferenceMode()
        return RunPromotionTextReferenceWorkflow()
    if IsDisplayOnWebsiteAppMode()
        return RunDisplayOnWebsiteAppWorkflow()
    if IsPromotionTextMode()
        return RunPromotionTextWorkflow()
    if IsSupplierProductCreationMode()
        BuildSupplierProductCreationPrompt(pageUrl)
    else if IsMatrixFullMode()
        BuildMatrixFullPrompt(pageUrl)
    else if IsMatrixImageMode()
        BuildMatrixImagePrompt(pageUrl)
    else
        BuildPromptFromCurrentProductPage(pageUrl, forceAutomaticCompletion)
    return RunAutomaticWorkflowIfEnabled(IsSupplierProductCreationMode(), forceAutomaticCompletion)
}

BuildSupplierProductCreationPrompt(pageUrl) {
    if IsBotzMode()
        return BuildBotzPrompt(pageUrl)
    throw Error("The current SEO mode is not a supplier product-creation mode.")
}

RunManualChatGptOutputPaste() {
    global automaticWorkflowActive, automaticWorkflowCancelRequested
    global automaticWorkflowManualCompletion, automaticWorkflowCmsInsertionActive
    if automaticWorkflowCmsInsertionActive {
        Flash("Automatic CMS insertion is already running. Numpad6 was ignored to prevent a duplicate paste.", 3000)
        return false
    }
    interruptedAutomaticWorkflow := automaticWorkflowActive
    if interruptedAutomaticWorkflow
        automaticWorkflowCancelRequested := true
    succeeded := PasteCopiedChatGPTOutputToCms(true)
    if interruptedAutomaticWorkflow && succeeded
        automaticWorkflowManualCompletion := true
    return succeeded
}

RunDisplayOnWebsiteAppWorkflow() {
    global cmsWinTitle

    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    ClickPoint("display_on_website_button", 200)
    ClickPoint("display_on_app_button", 200)
    ClickPoint("product_save_button", 1000)
    Flash("Display on Website and Display on App were clicked, then the product was saved.", 3000)
    return true
}

