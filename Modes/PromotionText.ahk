RunPromotionTextWorkflow() {
    global cmsWinTitle, promotionText, promotionTextSaveEnabled
    global lastSavedNonMatrixProductIdentity

    textToPaste := Trim(promotionText, " `t`r`n")
    fieldAction := textToPaste = "" ? "cleared" : "filled"

    ActivateWindow(cmsWinTitle)
    ClearActiveCmsProductCode()

    ; Capture the exact simple-product identity before editing so department
    ; automation can find the completed catalogue row after Save.
    ClickPoint("overview_tab", 500)
    currentProductCode := SetActiveCmsProductCode(CopyFromPoint("stock_code"))
    completedProductName := CleanText(CopyFromPoint("product_name"))
    if completedProductName = ""
        throw Error("The current GO b2b Product Name is blank, so the promotion-text product cannot be identified safely.")

    ; Description keeps the promotional field at the bottom of the page.
    ; Allow the tab panel to finish opening before scrolling its page body.
    ClickPoint("description_tab", 1200)
    ScrollPromotionDescriptionToBottom()
    PasteToPoint("promotion_description_field", textToPaste)

    ClickPoint("custom_tab", 600)
    PasteToPoint("promotion_custom_field", textToPaste)

    LogText(
        "promotion-text",
        "Product name: " completedProductName
        . "`nProduct code: " currentProductCode
        . "`nSave enabled: " (promotionTextSaveEnabled ? "yes" : "no")
        . "`nField action: " fieldAction
        . "`n`nPromotional text:`n" textToPaste
    )

    if promotionTextSaveEnabled {
        lastSavedNonMatrixProductIdentity := Map(
            "productName", completedProductName,
            "productCode", currentProductCode
        )
        ClickPoint("product_save_button", 1000)
        Flash("Description and Custom promotional fields " fieldAction ", then the product was saved.", 3000)
    } else {
        Flash("Description and Custom promotional fields " fieldAction ".`nTEST MODE: the product was not saved.", 3500)
    }
    return true
}

RunPromotionTextReferenceWorkflow() {
    global cmsWinTitle, promotionTextSaveEnabled
    global promotionReferenceBatchActive, promotionReferenceStopAfterCurrent
    global promotionReferenceCatalogueReturnDelayMs
    global departmentAutomationActive, automaticWorkflowActive

    if !promotionTextSaveEnabled
        throw Error("promotion_text_reference cannot run while promotionTextSaveEnabled is false, because every saved product must return to the catalogue before the next stock-code search.")
    if promotionReferenceBatchActive
        throw Error("A reference promotion-text batch is already active.")
    if departmentAutomationActive || automaticWorkflowActive
        throw Error("Another automatic workflow is already active. Let it finish before starting the reference promotion-text batch.")

    promotionReferenceBatchActive := true
    promotionReferenceStopAfterCurrent := false
    completedCount := 0
    totalCount := 0
    try {
        EnsureFolders()
        ActivateWindow(cmsWinTitle)
        references := CollectAllCatalogueReferenceProducts()
        totalCount := references.Length
        if totalCount = 0
            throw Error("No 'Simple Product (Reference)' rows were found on the current catalogue page's accessibility tree.")

        referenceLog := "Reference products detected: " totalCount
        for index, reference in references
            referenceLog .= "`n" index ". " reference["productCode"] " - " reference["productName"]
        ; This inventory is collected before any product is opened, so there is
        ; deliberately no active stock-code identity for a product-scoped log.
        TestingLog("promotion-reference-products", referenceLog)

        for index, reference in references {
            ToolTip "REFERENCE PROMOTION-TEXT BATCH"
                . "`nProduct " index " of " totalCount
                . "`nSearching for code: " reference["productCode"]
                . "`nCtrl+Numpad6: stop after this product"

            SearchAndOpenCatalogueReferenceProduct(reference, index, totalCount)
            if !RunPromotionTextWorkflow()
                throw Error("Promotional text was not completed for reference product '" reference["productCode"] "'.")
            completedCount += 1

            LogText(
                "promotion-reference-product-complete",
                "Reference product " completedCount " of " totalCount " completed and saved."
                . "`nProduct name: " reference["productName"]
                . "`nProduct code: " reference["productCode"]
            )

            if promotionReferenceStopAfterCurrent {
                MsgBox "Reference promotion-text batch stopped safely after saving the current product.`n`nProducts completed: " completedCount " of " totalCount
                return true
            }
            if index < totalCount {
                ToolTip "REFERENCE PROMOTION-TEXT BATCH"
                    . "`nSaved " completedCount " of " totalCount
                    . "`nWaiting for the catalogue search before the next code..."
                Sleep promotionReferenceCatalogueReturnDelayMs
            }
        }

        LogText("promotion-reference-complete", "Reference promotion-text batch completed " completedCount " product(s).")
        MsgBox "Reference promotion-text batch is complete.`n`nProducts completed: " completedCount
        return true
    } catch as err {
        ReportTestingError("promotion-reference-batch", err)
        MsgBox "Reference promotion-text batch stopped.`n`nProducts completed: " completedCount " of " totalCount "`n`n" err.Message
        return false
    } finally {
        promotionReferenceBatchActive := false
        promotionReferenceStopAfterCurrent := false
        ToolTip()
    }
}

ScrollPromotionDescriptionToBottom() {
    ; Do not send Ctrl+End here. The Description tab button still has keyboard
    ; focus after it is clicked, and GO b2b's tab strip can interpret End as a
    ; request to activate its final (Custom) tab. Native wheel input over a blank
    ; part of the page body scrolls Description without changing tabs.
    MouseMove 1620, 663, 0
    SendNativeMouseWheel(-1, 120)
    Sleep 700
}

