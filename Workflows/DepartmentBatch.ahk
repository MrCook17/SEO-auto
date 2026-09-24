StartDepartmentAutomation() {
    global departmentAutomationEnabled, departmentAutomationActive
    global departmentStopAfterCurrent, automaticWorkflowActive
    global departmentCatalogueWaitMs
    global lastSavedNonMatrixProductIdentity
    global promotionTextSaveEnabled

    ValidateSeoAutomationMode()
    if IsDepartmentMode() {
        MsgBox "The department SEO mode deliberately leaves each product unsaved for review, so it cannot run as a department-wide batch.`n`nOpen one product and press Numpad4 instead. The prompt will be submitted and the response inserted automatically, then the product will remain open for you to review and save manually."
        return false
    }
    if IsPromotionTextReferenceMode() {
        MsgBox "promotion_text_reference has its own stock-code search batch.`n`nOpen the catalogue product list and press NumpadEnter or Numpad4. Department automation does not need to be enabled."
        return false
    }
    departmentWorkflowMode := GetSeoAutomationMode()
    departmentProductType := GetDepartmentProductTypeForSeoMode(departmentWorkflowMode)

    if !departmentAutomationEnabled {
        MsgBox "Department automation is OFF.`n`nPress Ctrl+Alt+D to turn it on, open the first " departmentProductType " Overview tab, then press Ctrl+Numpad4."
        return false
    }
    if IsPromotionTextMode() && !promotionTextSaveEnabled {
        MsgBox "Department promotion-text automation was not started because test mode does not save or leave the current product.`n`nAfter the single-product test succeeds, change promotionTextSaveEnabled := false to true near the top of this script, reload it, then use the normal department keybinds."
        return false
    }
    if departmentAutomationActive {
        MsgBox "A department automation run is already active."
        return false
    }
    if automaticWorkflowActive {
        MsgBox "A single-product automatic workflow is already active. Wait for it to finish or cancel its wait before starting a department."
        return false
    }

    departmentAutomationActive := true
    departmentStopAfterCurrent := false
    completedCount := 0
    try {
        currentIdentity := ReadOpenCmsProductIdentity()
        SetActiveDepartmentProductIdentity(currentIdentity)
        LogText(
            "department-started",
            "Department automation started."
            . "`nWorkflow: " departmentWorkflowMode
            . "`nCatalogue product type: " departmentProductType
            . "`nFirst product: " currentIdentity["productName"]
        )

        Loop {
            if GetSeoAutomationMode() != departmentWorkflowMode
                throw Error("SeoAutomationMode changed during the department run. Restart the department so every product uses one consistent workflow.")
            productNumber := completedCount + 1
            ToolTip "DEPARTMENT AUTOMATION RUNNING"
                . "`nWorkflow: " departmentWorkflowMode
                . "`nProduct type: " departmentProductType
                . "`nProduct " productNumber ": " currentIdentity["productName"]
                . "`nCode: " EmptyToNA(currentIdentity["productCode"])
                . "`nPreparing the ChatGPT workflow..."
                . "`nCtrl+Numpad6: stop after this product"

            ; Prevent a failed or interrupted product from reusing the previous
            ; product's post-save identity.
            lastSavedNonMatrixProductIdentity := 0
            if !RunOpenProductWorkflow(true)
                throw Error("The automatic workflow did not complete product " productNumber " ('" currentIdentity["productName"] "').")

            completedCount += 1
            completedIdentity := PrepareCompletedProductForCatalogueLookup(currentIdentity)
            LogText(
                "department-product-complete",
                "Department product " completedCount " completed and saved."
                . "`nProduct name: " completedIdentity["productName"]
                . "`nProduct code: " EmptyToNA(completedIdentity["productCode"])
            )

            if departmentStopAfterCurrent || !departmentAutomationEnabled {
                LogText("department-stopped", "Department automation stopped after completing " completedCount " product(s), as requested.")
                MsgBox "Department automation stopped safely after saving the current product.`n`nProducts completed: " completedCount
                return true
            }

            ToolTip "DEPARTMENT AUTOMATION RUNNING"
                . "`nSaved product " completedCount ": " completedIdentity["productName"]
                . "`nWaiting " Round(departmentCatalogueWaitMs / 1000, 1) " seconds before reading the catalogue accessibility tree..."
                . "`nCtrl+Numpad6: stop before the next product starts"
            Sleep departmentCatalogueWaitMs

            if departmentStopAfterCurrent || !departmentAutomationEnabled {
                LogText("department-stopped", "Department automation stopped after completing " completedCount " product(s), as requested.")
                MsgBox "Department automation stopped safely after saving the current product.`n`nProducts completed: " completedCount
                return true
            }

            nextResult := FindNextDepartmentCatalogueProduct(completedIdentity, departmentProductType)
            if departmentStopAfterCurrent || !departmentAutomationEnabled {
                LogText("department-stopped", "Department automation stopped after completing " completedCount " product(s), as requested.")
                MsgBox "Department automation stopped safely after saving the current product.`n`nProducts completed: " completedCount
                return true
            }
            if nextResult["status"] = "end" {
                LogText("department-complete", "Reached the final " departmentProductType " exposed in the department accessibility tree after completing " completedCount " product(s).")
                MsgBox "Department automation is complete.`n`nProduct type: " departmentProductType "`nProducts completed: " completedCount "`nNo matching product follows the last completed item in the catalogue accessibility tree."
                return true
            }

            currentIdentity := OpenAndVerifyNextDepartmentProduct(nextResult["product"], completedCount + 1)
        }
    } catch as err {
        ReportTestingError("department-automation", err)
        MsgBox "Department automation stopped.`n`nProducts completed: " completedCount "`n`n" err.Message
        return false
    } finally {
        departmentAutomationActive := false
        departmentStopAfterCurrent := false
        ToolTip()
    }
}

SetActiveDepartmentProductIdentity(identity) {
    ; The department-started log is written before the product workflow has a
    ; chance to initialise its own artifact identity. Seed it here using the
    ; same rule as catalogue matching: matrix parent name, otherwise code.
    productType := identity.Has("productType") ? StrLower(Trim(identity["productType"])) : ""
    artifactIdentity := productType = "matrix product"
        ? identity["productName"]
        : identity["productCode"]
    return SetActiveCmsProductCode(artifactIdentity)
}

PrepareCompletedProductForCatalogueLookup(originalIdentity) {
    global cmsWinTitle
    global lastSavedNonMatrixProductIdentity
    if !IsAnyMatrixMode() {
        if !IsObject(lastSavedNonMatrixProductIdentity)
            return originalIdentity

        originalCode := CleanText(originalIdentity["productCode"])
        savedCode := CleanText(lastSavedNonMatrixProductIdentity["productCode"])
        if originalCode = "" || savedCode = "" || StrLower(originalCode) != StrLower(savedCode)
            throw Error("The saved post-update product identity does not match the product that began this department step.")
        return lastSavedNonMatrixProductIdentity
    }

    ; Matrix insertion finishes inside the reopened parent. Read back its exact
    ; post-update identity, then close/save it to return to the department list.
    ActivateWindow(cmsWinTitle)
    completedIdentity := ReadOpenCmsProductIdentity()
    ToolTip "DEPARTMENT AUTOMATION RUNNING`nClosing the completed matrix parent and returning to the catalogue..."
    ClickPoint("product_save_button", 500)
    return completedIdentity
}

