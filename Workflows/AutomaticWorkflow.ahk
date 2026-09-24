IsAutomaticWorkflowExecutionEnabled() {
    global fullWorkflowAutomationEnabled, departmentAutomationActive
    return fullWorkflowAutomationEnabled || departmentAutomationActive
}

RunAutomaticWorkflowIfEnabled(promptAlreadySubmitted := false, forceAutomation := false) {
    global fullWorkflowAutomationEnabled, automaticWorkflowActive
    global automaticWorkflowCancelRequested, automaticWorkflowManualCompletion
    global automaticWorkflowCmsInsertionActive, departmentAutomationActive

    if !fullWorkflowAutomationEnabled && !forceAutomation
        return false
    if automaticWorkflowActive
        throw Error("A full automatic workflow is already active.")

    automaticWorkflowActive := true
    automaticWorkflowCancelRequested := false
    automaticWorkflowManualCompletion := false
    try {
        if !promptAlreadySubmitted && !SubmitChatGptDraftForAutomaticWorkflow(forceAutomation)
            return false

        if !WaitForAutomaticChatGptOutput(forceAutomation)
            return forceAutomation && departmentAutomationActive && automaticWorkflowManualCompletion
        if !AutomaticWorkflowMayContinue(forceAutomation)
            return forceAutomation && departmentAutomationActive && automaticWorkflowManualCompletion

        ToolTip AutomaticWorkflowStatusHeading() "`nChatGPT output copied and validated.`nUpdating GO b2b CMS now..."
        automaticWorkflowCmsInsertionActive := true
        try return PasteCopiedChatGPTOutputToCms(false)
        finally automaticWorkflowCmsInsertionActive := false
    } finally {
        automaticWorkflowActive := false
        automaticWorkflowCancelRequested := false
        automaticWorkflowManualCompletion := false
        automaticWorkflowCmsInsertionActive := false
        ToolTip()
    }
}

AutomaticWorkflowMayContinue(forceAutomation := false) {
    global fullWorkflowAutomationEnabled, automaticWorkflowCancelRequested
    return !automaticWorkflowCancelRequested && (fullWorkflowAutomationEnabled || forceAutomation)
}

AutomaticWorkflowStatusHeading() {
    global departmentAutomationActive
    if departmentAutomationActive
        return "DEPARTMENT AUTOMATION RUNNING"
    if IsDepartmentMode()
        return "DEPARTMENT MODE AUTOMATION"
    return "FULL WORKFLOW AUTOMATION ON"
}

AutomaticWorkflowControlHint() {
    global departmentAutomationActive
    if departmentAutomationActive
        return "`nCtrl+Numpad6: stop after the current product`nNumpad6: manual output fallback"
    if IsDepartmentMode()
        return "`nCtrl+Alt+A: turn this automation off`nNumpad6: use the manual output fallback now"
    return "`nCtrl+Alt+A: turn automation off`nNumpad6: use the manual fallback now"
}

SubmitChatGptDraftForAutomaticWorkflow(forceAutomation := false) {
    global chatgptWinTitle, chatImageWindowWakeDelayMs, chatSubmitPreEnterDelayMs
    ToolTip AutomaticWorkflowStatusHeading()
        . "`nWaiting " Round(chatSubmitPreEnterDelayMs / 1000, 1) " seconds before submitting the prepared ChatGPT request..."
    ActivateWindow(GetChatGptWinTitle(), chatImageWindowWakeDelayMs)
    ; The prompt and any images were just pasted into this existing draft, so
    ; keep it untouched for ten seconds before the final Enter. This lets
    ; ChatGPT finish materialising large prompts and draft attachments.
    FocusChatGptInputForImagePaste()
    if !AutomaticWorkflowMayContinue(forceAutomation)
        return false
    TestingLog("chatgpt-pre-submit-wait", "Delay_ms=" chatSubmitPreEnterDelayMs "; workflow=automatic.")
    Sleep chatSubmitPreEnterDelayMs
    if !AutomaticWorkflowMayContinue(forceAutomation)
        return false
    ; Re-focus after the wait in case Chrome moved focus while rendering.
    FocusChatGptInputForImagePaste()
    LogText(
        "chatgpt-auto-submit",
        "Pressing Enter after a " Round(chatSubmitPreEnterDelayMs / 1000, 1) "-second draft-settle wait."
    )
    Send "{Enter}"
    Sleep 300
    return true
}

WaitForAutomaticChatGptOutput(forceAutomation := false) {
    global chatResponseInitialWaitMs, chatResponsePollIntervalMs
    global imageOnlyChatResponseInitialWaitMs, imageOnlyChatResponsePollIntervalMs

    startedAt := A_TickCount
    initialWaitMs := IsImageOnlyMode() ? imageOnlyChatResponseInitialWaitMs : chatResponseInitialWaitMs
    pollIntervalMs := IsImageOnlyMode() ? imageOnlyChatResponsePollIntervalMs : chatResponsePollIntervalMs
    nextAttemptAt := startedAt + initialWaitMs
    attempt := 0
    lastProblem := ""

    Loop {
        if !AutomaticWorkflowMayContinue(forceAutomation) {
            ToolTip()
            return false
        }

        now := A_TickCount
        remainingMs := nextAttemptAt - now
        if remainingMs > 0 {
            message := AutomaticWorkflowStatusHeading()
                . "`nWaiting for ChatGPT to finish..."
                . "`nElapsed: " FormatAutomationWaitTime(now - startedAt)
            if attempt = 0
                message .= "`nFirst copy attempt in: " FormatAutomationWaitTime(remainingMs)
            else {
                message .= "`nCopy attempt " attempt " did not find the finished output."
                message .= "`nNext attempt in: " FormatAutomationWaitTime(remainingMs)
                if lastProblem != ""
                    message .= "`nLast result: " lastProblem
            }
            message .= AutomaticWorkflowControlHint()
            ToolTip message
            Sleep Min(500, remainingMs)
            continue
        }

        attempt += 1
        ToolTip AutomaticWorkflowStatusHeading()
            . "`nCopy attempt " attempt ": scrolling to the bottom of ChatGPT..."
            . "`nNo CMS fields will change unless a complete output block is copied."
        copied := TryCopyLatestChatGptResponseByCoordinates(&lastProblem)

        ; Numpad6 can interrupt the wait and complete the manual fallback. Do
        ; not let this suspended automatic thread continue into a second paste.
        if !AutomaticWorkflowMayContinue(forceAutomation) {
            ToolTip()
            return false
        }
        if copied {
            LogText("chatgpt-auto-output-ready", "A complete ChatGPT automation output was copied on polling attempt " attempt ".")
            ToolTip AutomaticWorkflowStatusHeading()
                . "`nComplete ChatGPT output found on attempt " attempt "."
                . "`nStarting GO b2b insertion..."
            Sleep 500
            return true
        }

        nextAttemptAt := A_TickCount + pollIntervalMs
    }
}

FormatAutomationWaitTime(milliseconds) {
    totalSeconds := Ceil(Max(0, milliseconds) / 1000)
    minutes := Floor(totalSeconds / 60)
    seconds := Mod(totalSeconds, 60)
    return minutes ":" Format("{:02}", seconds)
}

