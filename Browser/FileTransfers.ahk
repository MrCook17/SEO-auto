LogSupplierChatGptImagePlan(supplierName, logPrefix, attachmentCount, cmsImageCount) {
    message := "Attaching all " attachmentCount " supplier image(s) to ChatGPT using Ctrl+A."
    message .= " The automation output, parser and GO b2b image work use only the first " cmsImageCount " image(s)."
    if attachmentCount > cmsImageCount
        message .= " The remaining " (attachmentCount - cmsImageCount) " attachment(s) are reference context only."
    LogText(logPrefix "-image-plan", message)
}

AttachBotzImagesToChatGpt(imageFiles, supplierName := "BOTZ", logPrefix := "botz") {
    if imageFiles.Length = 0
        throw Error("No " supplierName " images were supplied for ChatGPT attachment.")

    SplitPath imageFiles[1], , &imagesDir
    ValidateBotzCtrlAImageFolder(imagesDir, imageFiles, supplierName)

    selectionAttempted := false
    try {
        ToolTip "Opening ChatGPT attachments for " imageFiles.Length " " supplierName " images..."
        OpenChatGptFilePicker()
        selectionAttempted := true
        ChooseAllBotzImagesInPicker(imagesDir, supplierName)
        WaitForBotzChatAttachmentBatch(imageFiles, supplierName)
        for index, imagePath in imageFiles
            LogText(logPrefix "-chatgpt-attachment", "Batch submitted image " index " of " imageFiles.Length ": " imagePath)
        LogText(logPrefix "-chatgpt-attachment", "Attachment settle timer completed for " imageFiles.Length " requested image(s).")
        SubmitBotzChatGptDraft(supplierName, logPrefix)
        ToolTip()
        return true
    } catch as err {
        ToolTip()
        Send "{Esc}"
        LogText(logPrefix "-chatgpt-attachment-error", "Attachment batch failed: " err.Message)
        if selectionAttempted
            throw Error("The ChatGPT attachment selection started but did not complete safely. It was not retried, to avoid duplicates: " err.Message)
        throw
    }
}

OpenChatGptFilePicker() {
    global chatgptWinTitle, botzFilePickerTimeoutMs
    ActivateWindow(GetChatGptWinTitle(), 500)
    ClickPoint("chat_add_button", 900)
    ClickPoint("chat_add_attachments_button", 700)
    picker := WinWaitActive("ahk_class #32770", , botzFilePickerTimeoutMs / 1000)
    if !picker
        throw Error("The Windows file picker did not open after clicking ChatGPT + at 2246,1026 and Add attachments at 2317,395.")
    return picker
}

ChooseSingleFileInPicker(filePath) {
    if !FileExist(filePath)
        throw Error("File picker source no longer exists: " filePath)
    ChooseFileSelectionInPicker(filePath)
}

ChooseAllBotzImagesInPicker(imagesDir, supplierName := "BOTZ") {
    global botzFilePickerTimeoutMs, botzChatPickerSelectAllMs
    picker := NavigateSupplierImagePickerToFolder(imagesDir, supplierName)
    FocusWindowsFilePickerList(picker)
    Sleep 700
    Send "^a"
    ToolTip "All " supplierName " images selected.`nWaiting before confirming..."
    Sleep botzChatPickerSelectAllMs
    Send "{Enter}"

    if !WinWaitClose("ahk_id " picker, , botzFilePickerTimeoutMs / 1000)
        throw Error("The Windows file picker did not close after Ctrl+A and confirmation.")
}

NavigateSupplierImagePickerToFolder(imagesDir, supplierName) {
    global botzChatPickerFolderLoadMs
    if !DirExist(imagesDir)
        throw Error(supplierName " images folder no longer exists: " imagesDir)

    picker := WinExist("A")
    if !picker || !WinActive("ahk_class #32770")
        throw Error("The Windows file picker is not active.")

    savedClip := ClipboardAll()
    try {
        A_Clipboard := ""
        A_Clipboard := imagesDir
        if !ClipWait(2)
            throw Error("The " supplierName " images-folder path could not be placed on the clipboard.")
        Send "^l"
        Sleep 600
        Send "^a"
        Send "^v"
        Sleep 600
        Send "{Enter}"
        ToolTip "Waiting for the " supplierName " images folder to open..."
        Sleep botzChatPickerFolderLoadMs
    } finally {
        A_Clipboard := savedClip
    }
    return picker
}

FocusWindowsFilePickerList(picker) {
    candidates := ["DirectUIHWND2", "DirectUIHWND1", "SysListView321", "SHELLDLL_DefView1"]
    for _, controlName in candidates {
        try {
            if !ControlGetHwnd(controlName, "ahk_id " picker)
                continue
            ControlFocus controlName, "ahk_id " picker
            return controlName
        }
    }
    throw Error("The Windows file list could not be focused, so Ctrl+A was not sent.")
}

ChooseFileSelectionInPicker(selectionText) {
    global botzFilePickerTimeoutMs
    picker := WinExist("A")
    if !picker || !WinActive("ahk_class #32770")
        throw Error("The Windows file picker is not active.")

    savedClip := ClipboardAll()
    try {
        A_Clipboard := ""
        A_Clipboard := selectionText
        if !ClipWait(2)
            throw Error("The file selection could not be placed on the clipboard.")
        Send "!n"
        Sleep 250
        Send "^a"
        Send "^v"
        Sleep 250
        Send "{Enter}"
        if !WinWaitClose("ahk_id " picker, , botzFilePickerTimeoutMs / 1000)
            throw Error("The Windows file picker did not close after submitting the file selection.")
    } finally {
        A_Clipboard := savedClip
    }
}

WaitForBotzChatAttachmentBatch(imageFiles, supplierName := "BOTZ") {
    global botzChatAttachmentSettleMs
    startedAt := A_TickCount
    Loop {
        elapsed := A_TickCount - startedAt
        ToolTip "Waiting for ChatGPT to process " imageFiles.Length " " supplierName " attachments...`n" Round(elapsed / 1000, 1) " seconds"
        if elapsed >= botzChatAttachmentSettleMs
            break
        Sleep 500
    }
    return true
}

SubmitBotzChatGptDraft(supplierName := "BOTZ", logPrefix := "botz") {
    global chatgptWinTitle, botzChatAttachmentSettleMs
    ; WaitForBotzChatAttachmentBatch supplies the full ten-second period for
    ; the draft to finish loading its images.
    ToolTip supplierName " attachments settled. Sending the prepared request..."
    ActivateWindow(GetChatGptWinTitle(), 300)
    FocusChatGptInputForPaste()
    TestingLog("chatgpt-pre-submit-wait", "Delay_ms=0; attachment_settle_ms=" botzChatAttachmentSettleMs "; workflow=" logPrefix "; supplier=" supplierName ".")
    LogText(logPrefix "-chatgpt-submit", "Pressing Enter after the " Round(botzChatAttachmentSettleMs / 1000, 1) "-second " supplierName " attachment timer.")
    Send "{Enter}"
}

