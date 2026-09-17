EnsureTestingSessionLog() {
    global testingModeEnabled, testingSessionLogPath, testingSessionId, debugDir

    if !testingModeEnabled
        return ""
    if testingSessionLogPath != ""
        return testingSessionLogPath

    try {
        EnsureFolders()
        processId := DllCall("GetCurrentProcessId")
        testingSessionId := FormatTime(, "yyyyMMdd-HHmmss") "-pid" processId
        testingSessionLogPath := debugDir "\testing-session-" testingSessionId ".log.txt"
        header := "CROMARTIE TESTING DIAGNOSTIC SESSION`n"
            . "Started: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n"
            . "Session: " testingSessionId "`n"
            . BuildTestingRuntimeSummary()
            . "`n`n"
        FileAppend header, testingSessionLogPath, "UTF-8"
        return testingSessionLogPath
    } catch {
        ; Diagnostics must never interrupt the production automation.
        testingSessionLogPath := ""
        return ""
    }
}

TestingLog(eventName, details := "") {
    global testingModeEnabled, testingSessionLogPath

    if !testingModeEnabled
        return false
    try {
        if EnsureTestingSessionLog() = ""
            return false
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        tick := A_TickCount
        entry := "[" timestamp "] [tick=" tick "] [" eventName "]`n"
        if details != ""
            entry .= details "`n"
        entry .= "`n"
        FileAppend entry, testingSessionLogPath, "UTF-8"
        return true
    } catch {
        return false
    }
}

BuildTestingRuntimeSummary() {
    global SeoAutomationMode, imageCountToProcess, maximumImagesPerProduct
    global imageTabLoadDelayMs, imageGalleryAvailabilityTimeoutMs, imageGalleryCountTimeoutMs
    global imageGalleryCountStableDurationMs, imageGalleryMinimumObservationMs
    global imageGalleryPageChangeTimeoutMs, imageGalleryFirstPageNoChangeTimeoutMs
    global imageCopyPreCopyDelayMs
    global chatImageWindowWakeDelayMs, chatImageFocusDelayMs, chatImageAttachmentTimeoutMs
    global chatImageAttachmentPollIntervalMs, chatImageAttachmentSettleMs, chatImagePasteFallbackDelayMs
    global chatSubmitPreEnterDelayMs
    global cmsImageDetailsButtonTimeoutMs, cmsImageDetailsFormTimeoutMs, cmsImageDetailsOpenAttempts
    global cmsImageGalleryReturnTimeoutMs, cmsImageGalleryReturnSettleMs
    global fullWorkflowAutomationEnabled, departmentAutomationEnabled
    global cmsWinTitle, chatgptWinTitle, coords

    summary := "AutoHotkey version: " A_AhkVersion
        . "`nOS: " A_OSVersion
        . "`n64-bit OS: " (A_Is64bitOS ? "yes" : "no")
        . "`nProcess admin: " (A_IsAdmin ? "yes" : "no")
        . "`nScreen: " A_ScreenWidth "x" A_ScreenHeight
        . "`nSEO mode: " SeoAutomationMode
        . "`nCurrent image count: " imageCountToProcess
        . "`nMaximum images: " maximumImagesPerProduct
        . "`nImages-tab fixed delay ms: " imageTabLoadDelayMs
        . "`nGallery availability timeout ms: " imageGalleryAvailabilityTimeoutMs
        . "`nGallery count timeout ms: " imageGalleryCountTimeoutMs
        . "`nGallery count stable duration ms: " imageGalleryCountStableDurationMs
        . "`nGallery minimum observation ms: " imageGalleryMinimumObservationMs
        . "`nGallery page-change timeout ms: " imageGalleryPageChangeTimeoutMs
        . "`nGallery first-page no-change timeout ms: " imageGalleryFirstPageNoChangeTimeoutMs
        . "`nImage pre-copy delay ms: " imageCopyPreCopyDelayMs
        . "`nChatGPT image window wake delay ms: " chatImageWindowWakeDelayMs
        . "`nChatGPT image focus delay ms: " chatImageFocusDelayMs
        . "`nChatGPT attachment timeout ms: " chatImageAttachmentTimeoutMs
        . "`nChatGPT attachment poll interval ms: " chatImageAttachmentPollIntervalMs
        . "`nChatGPT attachment settle ms: " chatImageAttachmentSettleMs
        . "`nChatGPT image fallback delay ms: " chatImagePasteFallbackDelayMs
        . "`nChatGPT pre-Enter draft-settle delay ms: " chatSubmitPreEnterDelayMs
        . "`nCMS image Details button timeout ms: " cmsImageDetailsButtonTimeoutMs
        . "`nCMS image Details form timeout ms: " cmsImageDetailsFormTimeoutMs
        . "`nCMS image Details open attempts: " cmsImageDetailsOpenAttempts
        . "`nCMS image gallery-return timeout ms: " cmsImageGalleryReturnTimeoutMs
        . "`nCMS image gallery-return settle ms: " cmsImageGalleryReturnSettleMs
        . "`nFull workflow automation enabled: " (fullWorkflowAutomationEnabled ? "yes" : "no")
        . "`nDepartment automation enabled: " (departmentAutomationEnabled ? "yes" : "no")
        . "`nCMS window match: " cmsWinTitle
        . "`nChatGPT window match: " GetChatGptWinTitle()
        . "`n" GetTestingActiveWindowSummary()
        . "`nCoordinates:"
    for name, point in coords
        summary .= "`n  " name "=" point[1] "," point[2]
    return summary
}

GetTestingActiveWindowSummary() {
    try {
        hwnd := WinExist("A")
        if !hwnd
            return "Active window: none"
        title := WinGetTitle("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        minMax := WinGetMinMax("ahk_id " hwnd)
        WinGetPos &x, &y, &width, &height, "ahk_id " hwnd
        return "Active window: hwnd=" hwnd
            . "; process=" processName
            . "; state=" minMax
            . "; rect=" x "," y " " width "x" height
            . "; title=" title
    } catch as err {
        return "Active window could not be inspected: " FormatTestingError(err)
    }
}

FormatTestingError(err) {
    if !IsObject(err)
        return err ""

    text := "Message: " err.Message
    try {
        if err.What != ""
            text .= "`nWhat: " err.What
    }
    try {
        if err.File != ""
            text .= "`nFile: " err.File
    }
    try {
        if err.Line != ""
            text .= "`nLine: " err.Line
    }
    try {
        if err.Extra != ""
            text .= "`nExtra: " err.Extra
    }
    try {
        if err.Stack != ""
            text .= "`nStack:`n" err.Stack
    }
    return text
}

SanitiseTestingFilePart(value) {
    value := RegExReplace(Trim(value), "[^A-Za-z0-9_-]+", "-")
    value := Trim(value, "-")
    return value = "" ? "diagnostic" : SubStr(value, 1, 80)
}

SaveTestingElementDump(element, context) {
    global testingModeEnabled, testingSessionId, testingArtifactSequence, debugDir

    if !testingModeEnabled
        return ""
    try {
        if EnsureTestingSessionLog() = ""
            return ""
        testingArtifactSequence += 1
        safeContext := SanitiseTestingFilePart(context)
        sequence := Format("{:04}", testingArtifactSequence)
        path := debugDir "\testing-" testingSessionId "-" sequence "-" safeContext "-uia-element.txt"
        contents := "Context: " context "`nCaptured: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n"
            . GetTestingActiveWindowSummary() "`n`n" element.DumpAll()
        FileAppend contents, path, "UTF-8"
        TestingLog("uia-element-saved", "Context=" context "; path=" path "; chars=" StrLen(contents) ".")
        return path
    } catch as err {
        TestingLog("uia-element-failed", "Context=" context "; " FormatTestingError(err))
        return ""
    }
}

SaveTestingAccessibilityTree(context) {
    global testingModeEnabled, testingSessionId, testingArtifactSequence, debugDir, LastDocument

    if !testingModeEnabled
        return ""
    try {
        if EnsureTestingSessionLog() = ""
            return ""
        testingArtifactSequence += 1
        document := UIA_Browser().GetCurrentDocumentElement()
        LastDocument := document
        safeContext := SanitiseTestingFilePart(context)
        sequence := Format("{:04}", testingArtifactSequence)
        path := debugDir "\testing-" testingSessionId "-" sequence "-" safeContext "-accessibility-tree.txt"
        contents := "Context: " context "`nCaptured: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n"
            . GetTestingActiveWindowSummary() "`n`n" document.DumpAll()
        FileAppend contents, path, "UTF-8"
        TestingLog("accessibility-tree-saved", "Context=" context "; path=" path "; chars=" StrLen(contents) ".")
        return path
    } catch as err {
        TestingLog("accessibility-tree-failed", "Context=" context "; " FormatTestingError(err))
        return ""
    }
}

ReportTestingError(context, err, captureAccessibilityTree := true) {
    TestingLog(
        "error-" SanitiseTestingFilePart(context),
        FormatTestingError(err) "`n" GetTestingActiveWindowSummary()
    )
    if captureAccessibilityTree
        SaveTestingAccessibilityTree(context "-error")
}

LogUnhandledErrorForTesting(thrownValue, mode) {
    ReportTestingError("unhandled-mode-" mode, thrownValue)
    return false
}

LogTestingSessionExit(exitReason, exitCode) {
    TestingLog("session-exit", "Reason=" exitReason "; code=" exitCode ".")
}

