TestScript() {
    global useRecommendedProductName, SeoAutomationMode, SeoSubmodeId, SeoPromptId, imageCountToProcess
    global fullWorkflowAutomationEnabled, automaticWorkflowActive
    global departmentAutomationEnabled, departmentAutomationActive
    global departmentStopAfterCurrent, testingModeEnabled, testingSessionLogPath
    nameMode := useRecommendedProductName ? "ON" : "OFF"
    automationMode := fullWorkflowAutomationEnabled ? "ON" : "OFF"
    automationLabel := IsDepartmentMode()
        ? "Department Numpad4 + Numpad6 automation"
        : "Full workflow automation"
    automationStatus := automaticWorkflowActive
        ? (departmentAutomationActive ? "active inside department run" : "currently waiting/running")
        : "idle"
    departmentMode := departmentAutomationEnabled ? "ON" : "OFF"
    departmentStatus := departmentAutomationActive
        ? (departmentStopAfterCurrent ? "stopping after current product" : "running")
        : "idle"
    testingStatus := testingModeEnabled ? "ON" : "OFF"
    testingLog := testingModeEnabled && testingSessionLogPath != "" ? testingSessionLogPath : "none"
    savedCount := 0
    savedMode := "none"
    try {
        savedState := LoadMatrixState()
        savedCount := savedState["productCount"]
        savedMode := savedState["mode"]
    }
    MsgBox "SEO mode: " SeoAutomationMode
        . "`nSEO submode: " SeoSubmodeId " (" GetSeoSubmodeLabel(GetSeoAutomationMode(), GetSeoSubmodeId()) ")"
        . "`nSEO prompt: " SeoPromptId " (" GetSeoPromptLabel(GetSeoAutomationMode(), GetSeoSubmodeId(), GetSeoPromptId()) ")"
        . "`nImages: " imageCountToProcess
        . "`nRecommended product-name insertion: " nameMode
        . "`n" automationLabel " (Ctrl+Alt+A): " automationMode " (" automationStatus ")"
        . "`nDepartment automation (Ctrl+Alt+D): " departmentMode " (" departmentStatus ")"
        . "`nTesting diagnostics: " testingStatus
        . "`nTesting session log: " testingLog
        . "`nDepartment start: Ctrl+Numpad4"
        . "`nDepartment stop after current product: Ctrl+Numpad6"
        . "`nUIA-v2 matrix support: available"
        . "`nSaved matrix state: " savedMode
        . "`nSaved matrix children: " savedCount
}

CopyActiveWindowTitle() {
    title := WinGetTitle("A")
    A_Clipboard := title
    Flash("Copied active window title")
}

ToggleRecommendedProductName() {
    global useRecommendedProductName
    useRecommendedProductName := !useRecommendedProductName
    mode := useRecommendedProductName ? "ON" : "OFF"
    Flash("Product name recommendation paste: " mode)
}

ToggleFullWorkflowAutomation() {
    global fullWorkflowAutomationEnabled, automaticWorkflowCancelRequested
    global departmentAutomationActive
    fullWorkflowAutomationEnabled := !fullWorkflowAutomationEnabled
    if !fullWorkflowAutomationEnabled && !departmentAutomationActive
        automaticWorkflowCancelRequested := true
    mode := fullWorkflowAutomationEnabled ? "ON" : "OFF"
    message := (IsDepartmentMode() ? "Department Numpad4 + Numpad6 automation: " : "Full workflow automation: ") mode
    if !fullWorkflowAutomationEnabled && departmentAutomationActive
        message .= "`nThe active department run is unaffected; use Ctrl+Numpad6 to stop it after the current product."
    else if IsDepartmentMode() {
        if fullWorkflowAutomationEnabled
            message .= "`nNumpad4 will submit, wait and insert the result automatically. The product will remain unsaved."
        else
            message .= "`nNumpad4 will prepare the prompt and images only. Press Numpad6 manually when the response is ready."
    } else if !fullWorkflowAutomationEnabled
        message .= "`nAny active ChatGPT wait will stop safely."
    Flash(message, 2500)
}

ToggleDepartmentAutomation() {
    global departmentAutomationEnabled, departmentAutomationActive
    global departmentStopAfterCurrent
    if IsDepartmentMode() {
        departmentAutomationEnabled := false
        Flash("Department-wide automation is unavailable in department review mode.`nOpen one product and press Numpad4 instead.", 3500)
        return
    }
    departmentAutomationEnabled := !departmentAutomationEnabled
    if !departmentAutomationEnabled && departmentAutomationActive
        departmentStopAfterCurrent := true
    mode := departmentAutomationEnabled ? "ON" : "OFF"
    message := "Department automation: " mode
    if !departmentAutomationEnabled && departmentAutomationActive
        message .= "`nThe current product will finish, then the department run will stop."
    else if departmentAutomationEnabled
        message .= "`nStart from the first " GetDepartmentProductTypeForSeoMode() " Overview with Ctrl+Numpad4."
    Flash(message, 3000)
}

RequestDepartmentStopAfterCurrent() {
    global departmentAutomationActive, departmentStopAfterCurrent
    global promotionReferenceBatchActive, promotionReferenceStopAfterCurrent
    if promotionReferenceBatchActive {
        promotionReferenceStopAfterCurrent := true
        Flash("Reference promotion-text stop requested.`nThe current product will finish and save first.", 3000)
        return true
    }
    if !departmentAutomationActive {
        Flash("No department automation run is active.", 2000)
        return false
    }
    departmentStopAfterCurrent := true
    Flash("Department stop requested.`nThe current product will finish and save first.", 3000)
    return true
}

SetImageCountToProcess(imageCount) {
    global imageCountToProcess, maximumImagesPerProduct

    if imageCount < 0 {
        Flash("Image count cannot be negative.")
        return false
    }

    requestedCount := imageCount
    imageCountToProcess := Min(imageCount, maximumImagesPerProduct)
    message := "Prompt/CMS image count set to " imageCountToProcess "."
    if requestedCount > maximumImagesPerProduct
        message .= "`nOnly the first " maximumImagesPerProduct " images can be processed per product."
    Flash(message)
    return true
}

CaptureMouseCoords() {
    MouseGetPos &x, &y
    A_Clipboard := "x: " x ", y: " y
    ToolTip "Copied coordinates: x=" x ", y=" y
    SetTimer () => ToolTip(), -1500
}

Flash(message, durationMs := 1500) {
    ToolTip message
    SetTimer () => ToolTip(), -durationMs
}

ShowMatrixLookupStatus(message) {
    MouseGetPos &mouseX, &mouseY
    ToolTip message, mouseX + 22, mouseY + 22
}

BuildLocationsMessage(items) {
    output := ""
    for index, item in items {
        connectedSize := item.HasOwnProp("ConnectedSize") ? item.ConnectedSize : ""
        output .= index ". " item.Name " | size=" (connectedSize = "" ? "[not detected]" : connectedSize) " | type=" item.ControlType " | rect=" item.X "," item.Y " " item.W "x" item.H " | centre=" item.CentreX "," item.CentreY " | row=" item.RowText "`n"
    }
    return output = "" ? "No Edit controls recorded." : output
}

ShowLastLocations() {
    global LastEditButtons
    MsgBox "Detected " LastEditButtons.Length " Edit control(s):`n`n" BuildLocationsMessage(LastEditButtons)
}

DumpAccessibilityTree() {
    global LastDocument, cmsWinTitle, debugDir
    try {
        ; F9 may be pressed while ChatGPT or the script's own message box was
        ; most recently active. UIA_Browser searches the active browser, so
        ; explicitly activate the configured GO b2b CMS window first.
        ActivateWindow(cmsWinTitle, 500)
        LastDocument := 0
        LastDocument := UIA_Browser().GetCurrentDocumentElement()
        if !DirExist(debugDir)
            DirCreate debugDir
        path := debugDir "\go-b2b-accessibility-tree.txt"
        if FileExist(path)
            FileDelete path
        ToolTip "Creating accessibility-tree dump..."
        FileAppend LastDocument.DumpAll(), path, "UTF-8"
        testingPath := SaveTestingAccessibilityTree("manual-f9")
        ToolTip()
        message := "Accessibility tree saved to:`n" path
        if testingPath != ""
            message .= "`n`nTesting-mode copy saved to:`n" testingPath
        MsgBox message
    } catch as err {
        ReportTestingError("manual-f9-accessibility-tree", err, false)
        ToolTip()
        MsgBox "Accessibility-tree dump failed:`n`n" err.Message
    }
}

