ReadOpenCmsProductIdentity() {
    global cmsWinTitle
    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    productType := IsAnyMatrixMode() ? "Matrix Product" : "Simple Product"
    ; Matrix parents do not have stock codes. Do not read the stock-code
    ; coordinate at all: their department identity is always their exact name.
    productCode := productType = "Matrix Product"
        ? ""
        : CleanText(CopyOptionalFromPoint("stock_code"))
    productName := CleanText(CopyFromPoint("product_name"))
    if productName = ""
        throw Error("The open GO b2b Product Name is blank. Start department automation from the first product's Overview page.")
    return Map("productType", productType, "productName", productName, "productCode", productCode)
}

InsertProductNameRecommendation(productNameRecommendation) {
    ClickPoint("overview_tab", 600)
    PasteToPoint("product_name", productNameRecommendation)
}

InsertMetaFields(metaTitle, metaDescription, htmlSnippet := "") {
    ClickPoint("description_tab", 600)
    PasteToPoint("meta_title", metaTitle)

    if IsFullContentMode() || IsSupplierProductCreationMode()
        PasteToPoint("html_snippet", htmlSnippet)

    PasteToPoint("meta_description", metaDescription)
}

CopyFromPoint(name) {
    ClickPoint(name, 200)
    Sleep 150
    Send "^a"
    Sleep 150
    text := CopySelectedText(2, false)
    TestingLog("field-copy", "Field=" name "; chars=" StrLen(text) ".")
    return text
}

CopyOptionalFromPoint(name) {
    ClickPoint(name, 200)
    Sleep 150
    Send "^a"
    Sleep 150
    text := CopySelectedText(2, true)
    TestingLog("field-copy-optional", "Field=" name "; chars=" StrLen(text) ".")
    return text
}

PasteToPoint(name, text) {
    maxAttempts := 5
    lastActual := ""
    lastProblem := ""
    TestingLog("field-paste-start", "Field=" name "; expected_chars=" StrLen(text) "; maximum_attempts=" maxAttempts ".")

    Loop maxAttempts {
        attempt := A_Index
        ClickPoint(name, 200)
        Sleep 150
        Send "^a"
        Sleep 150
        PasteText(text)
        Sleep 250

        try {
            ; Select and copy the value back from the same CMS control. Optional
            ; copying is required because an intentionally cleared field does
            ; not place text on the clipboard.
            lastActual := CopyOptionalFromPoint(name)
            if NormalisePastedFieldValue(lastActual) = NormalisePastedFieldValue(text) {
                TestingLog(
                    "field-paste-verified",
                    "Field=" name "; attempt=" attempt "; expected_chars=" StrLen(text) "; actual_chars=" StrLen(lastActual) "."
                )
                if attempt > 1
                    LogText("paste-verification", "Field '" name "' verified on attempt " attempt ".")
                return true
            }
            lastProblem := "read-back value did not match"
            LogText(
                "paste-verification-mismatch",
                "Field: " name
                . "`nAttempt: " attempt " of " maxAttempts
                . "`nExpected:`n" text
                . "`nActual:`n" lastActual
            )
        } catch as err {
            lastProblem := "could not read the field back: " err.Message
            LogText("paste-verification-error", "Field '" name "', attempt " attempt " of " maxAttempts ": " err.Message)
        }

        if attempt < maxAttempts {
            ToolTip "Paste verification failed for " name ".`nRetrying " (attempt + 1) " of " maxAttempts "..."
            Sleep 350
        }
    }

    ToolTip()
    throw Error(
        "Could not verify the pasted value in '" name "' after " maxAttempts " attempts."
        . "`n`nLast problem: " lastProblem
        . "`n`nProcessing stopped before continuing to another CMS field."
    )
}

NormalisePastedFieldValue(value) {
    ; Windows clipboard text can represent the same textarea content with CRLF
    ; or LF line endings. No other characters or whitespace are ignored.
    value := StrReplace(value, "`r`n", "`n")
    return StrReplace(value, "`r", "`n")
}

SetActiveMatrixParentName(expectedName := "") {
    ; Matrix parents have no stock code, so their exact Product Name is also
    ; used as the safe identity for logs, backups and page verification.
    parentName := CleanText(CopyFromPoint("product_name"))
    if parentName = ""
        throw Error("The matrix parent Product Name is blank.")
    if expectedName != "" && NormaliseCatalogueProductName(parentName) != NormaliseCatalogueProductName(expectedName)
        throw Error("The open matrix parent does not match the saved product name.`nExpected: " expectedName "`nOpened: " parentName)
    SetActiveCmsProductCode(parentName)
    return parentName
}

InsertMatrixParentMetaFields(metaTitle, metaDescription) {
    ; Deliberately cannot paste HTML and never clicks the parent Save button.
    ClickPoint("description_tab", 600)
    PasteToPoint("meta_title", metaTitle)
    PasteToPoint("meta_description", metaDescription)
}

