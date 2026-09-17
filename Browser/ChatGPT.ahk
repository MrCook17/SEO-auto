GetChatGptWinTitle() {
    global chatgptWinTitle, departmentChatgptWinTitle
    return IsDepartmentMode() ? departmentChatgptWinTitle : chatgptWinTitle
}

PastePromptToChatGPT(prompt) {
    global chatgptWinTitle, chatPasteRetries

    lastProblem := ""

    Loop chatPasteRetries {
        try {
            ActivateWindow(GetChatGptWinTitle(), 900)
            FocusChatGptInputForPaste()
            PasteLargeTextToFocusedInput(prompt)
            Flash("Prompt pasted.")
            return true
        } catch as err {
            lastProblem := err.Message
            Sleep 700
        }
    }

    throw Error("Prompt did not paste into ChatGPT after " chatPasteRetries " attempts.`n`n" lastProblem)
}

FocusChatGptInputForPaste() {
    global chatWakeDelayMs

    ; First click wakes the Chrome/ChatGPT tab if it has been inactive.
    ClickPoint("chat_input", chatWakeDelayMs)
    Sleep 250

    ; Second click focuses the message box after the page is awake.
    ClickPoint("chat_input", 500)
    Sleep 300
}

WakeChatGptInput() {
    FocusChatGptInputForPaste()
}

FocusChatGptInputForImagePaste() {
    global chatImageFocusDelayMs

    ; During an image batch ChatGPT is already awake and the draft already
    ; exists, so one short focus click is sufficient. The slower two-click wake
    ; sequence remains in place for the initial large prompt paste.
    ClickPoint("chat_input", chatImageFocusDelayMs)
    Sleep 100
}

GetChatGptDraftAttachmentCount() {
    try {
        document := UIA_Browser().GetCurrentDocumentElement()
        buttons := document.FindElements({ Name: "Remove file", Type: "Button", mm: 2, cs: 0 })
        count := 0
        for _, button in buttons {
            try {
                if RegExMatch(Trim(button.Name), "i)^Remove file\s+\d+:")
                    count += 1
            }
        }
        return count
    } catch as err {
        TestingLog("chatgpt-attachment-count-error", FormatTestingError(err))
        return -1
    }
}

WaitForChatGptDraftAttachmentCount(expectedCount) {
    global chatImageAttachmentTimeoutMs, chatImageAttachmentPollIntervalMs, chatImageAttachmentSettleMs

    startedAt := A_TickCount
    deadline := startedAt + chatImageAttachmentTimeoutMs
    lastCount := -1
    Loop {
        count := GetChatGptDraftAttachmentCount()
        if count != lastCount {
            TestingLog(
                "chatgpt-attachment-count",
                "Expected=" expectedCount "; detected=" count "; elapsed_ms=" (A_TickCount - startedAt) "."
            )
            lastCount := count
        }
        if count >= expectedCount {
            Sleep chatImageAttachmentSettleMs
            confirmedCount := GetChatGptDraftAttachmentCount()
            if confirmedCount >= expectedCount {
                TestingLog(
                    "chatgpt-attachment-ready",
                    "Expected=" expectedCount "; detected=" confirmedCount "; elapsed_ms=" (A_TickCount - startedAt) "."
                )
                return true
            }
        }
        if A_TickCount >= deadline {
            TestingLog(
                "chatgpt-attachment-timeout",
                "Expected=" expectedCount "; last_detected=" lastCount "; timeout_ms=" chatImageAttachmentTimeoutMs "."
            )
            return false
        }
        Sleep chatImageAttachmentPollIntervalMs
    }
}

VerifyChatGptPromptPasted(prompt) {
    savedClip := ClipboardAll()
    A_Clipboard := ""
    Sleep 150

    Send "^a"
    Sleep 180
    Send "^c"

    if !ClipWait(1.5) {
        A_Clipboard := savedClip
        return false
    }

    copied := A_Clipboard

    Send "{Right}"
    Sleep 100
    Send "^{End}"
    Sleep 100

    A_Clipboard := savedClip

    return PromptPasteLooksValid(copied, prompt)
}

PromptPasteLooksValid(copied, prompt) {
    copied := CleanText(copied)
    prompt := CleanText(prompt)

    if copied = ""
        return false

    if InStr(copied, "Current page/product name:") && InStr(copied, "===AUTOMATION_OUTPUT_START===")
        return true

    firstChunk := SubStr(prompt, 1, 60)
    minLength := Floor(StrLen(prompt) * 0.75)

    if StrLen(copied) >= minLength && InStr(copied, firstChunk)
        return true

    return false
}

CopyLatestChatGptResponseToClipboard() {
    savedClip := ClipboardAll()
    uiaProblem := ""
    fallbackProblem := ""

    try {
        ToolTip "Finding the latest ChatGPT response Copy button..."
        if TryCopyLatestChatGptResponseWithUia(&uiaProblem) {
            ToolTip()
            return A_Clipboard
        }

        ToolTip "ChatGPT Copy button was not available through UIA.`nScrolling to the bottom for the coordinate fallback..."
        if TryCopyLatestChatGptResponseByCoordinates(&fallbackProblem) {
            ToolTip()
            return A_Clipboard
        }
    } catch as err {
        fallbackProblem := err.Message
    }

    ToolTip()
    A_Clipboard := savedClip
    throw Error(
        "Could not copy the latest completed ChatGPT response. No CMS fields were changed."
        . "`n`nUI Automation: " (uiaProblem != "" ? uiaProblem : "No valid response was copied.")
        . "`n`nBottom-scroll fallback: " (fallbackProblem != "" ? fallbackProblem : "No valid response was copied.")
    )
}

TryCopyLatestChatGptResponseWithUia(&problem) {
    global chatgptWinTitle, chatResponseCopyTimeoutMs
    problem := ""

    try {
        ActivateWindow(GetChatGptWinTitle(), 400)
        document := UIA_Browser().GetCurrentDocumentElement()
        copyButton := FindLatestChatGptResponseCopyButton(document)
        if !copyButton {
            problem := "No exact-name Copy button was exposed in the ChatGPT accessibility tree."
            return false
        }

        A_Clipboard := ""
        copyButton.Invoke()
        if !ClipWait(chatResponseCopyTimeoutMs / 1000) {
            problem := "The latest UIA Copy button did not place text on the clipboard."
            return false
        }
        if !ClipboardHasCompleteAutomationOutput() {
            problem := "The latest UIA Copy button did not copy one complete automation-output block."
            return false
        }
        return true
    } catch as err {
        problem := err.Message
        return false
    }
}

FindLatestChatGptResponseCopyButton(document) {
    try buttons := document.FindElements({ Name: "Copy", Type: "Button", mm: 2, cs: 0 })
    catch
        return 0

    ; ChatGPT exposes code-block actions as "Copy code". Requiring the exact
    ; accessible name "Copy" leaves only response action buttons. UIA traversal
    ; order follows the conversation, so the final match belongs to the latest
    ; completed assistant response even when it is below the visible viewport.
    Loop buttons.Length {
        button := buttons[buttons.Length - A_Index + 1]
        try {
            if StrLower(Trim(button.Name)) = "copy" && button.IsEnabled
                return button
        }
    }
    return 0
}

TryCopyLatestChatGptResponseByCoordinates(&problem) {
    global chatgptWinTitle, chatResponseCopyTimeoutMs
    global chatResponseScrollNotches
    global chatResponseRecoveryPageUpCount, chatResponseRecoveryPageDownCount
    global chatResponseCopyButtonPoint
    problem := ""

    try {
        ActivateWindow(GetChatGptWinTitle(), 400)
        MouseMove chatResponseCopyButtonPoint[1], chatResponseCopyButtonPoint[2], 0

        ; Moving up first repairs the occasional ChatGPT conversation viewport
        ; state where a direct bottom scroll stops exposing response actions.
        Send "{PgUp " chatResponseRecoveryPageUpCount "}"
        Sleep 500

        ; Keep the original large wheel-down pass, then travel much farther down
        ; than the short recovery move so long responses expose their Copy action.
        SendNativeMouseWheel(-1, chatResponseScrollNotches)
        Send "{PgDn " chatResponseRecoveryPageDownCount "}"
        Sleep 900

        A_Clipboard := ""
        Click chatResponseCopyButtonPoint[1], chatResponseCopyButtonPoint[2]
        if !ClipWait(chatResponseCopyTimeoutMs / 1000) {
            problem := "Clicking " chatResponseCopyButtonPoint[1] "," chatResponseCopyButtonPoint[2] " did not place text on the clipboard."
            return false
        }
        if !ClipboardHasCompleteAutomationOutput() {
            problem := "The coordinate fallback did not copy one complete automation-output block."
            return false
        }
        return true
    } catch as err {
        problem := err.Message
        return false
    }
}

ClipboardHasCompleteAutomationOutput() {
    response := A_Clipboard
    startMarker := "===AUTOMATION_OUTPUT_START==="
    endMarker := "===AUTOMATION_OUTPUT_END==="
    startPos := InStr(response, startMarker)
    endPos := InStr(response, endMarker)
    return response != ""
        && CountTextOccurrences(response, startMarker) = 1
        && CountTextOccurrences(response, endMarker) = 1
        && startPos < endPos
        && Trim(ExtractBetween(response, startMarker, endMarker), " `t`r`n") != ""
}

