OpenSeoPromptSettingsGui() {
    global botzPromptSettings, botzPromptSettingsGui
    global useRecommendedProductName, fullWorkflowAutomationEnabled, departmentAutomationEnabled
    global attemptImageCopyAfterPrompt

    if IsObject(botzPromptSettingsGui) {
        try {
            botzPromptSettingsGui.Show()
            return
        } catch {
            botzPromptSettingsGui := 0
        }
    }

    if !IsObject(botzPromptSettings)
        botzPromptSettings := CreateDefaultBotzPromptSettings()

    settingsGui := Gui("+AlwaysOnTop +OwnDialogs", "SEO Automation Settings")
    settingsGui.MarginX := 16
    settingsGui.MarginY := 14
    settingsGui.SetFont("s10", "Segoe UI")

    controls := Map()
    leftX := 16, rightX := 566, columnWidth := 520

    ; Left column: workflow selection and behaviour.
    settingsGui.SetFont("s11 Bold")
    settingsGui.AddText("x" leftX " y14", "Workflow")
    settingsGui.SetFont("s9 Norm")
    settingsGui.AddText("x" leftX " y43", "SEO automation mode")
    controls["seoAutomationMode"] := settingsGui.AddDropDownList("x" leftX " y63 w360", GetSeoAutomationModeOptions())
    controls["seoAutomationMode"].Choose(GetSeoAutomationModeOptionIndex(GetSeoAutomationMode()))
    settingsGui.AddText("x" leftX " y96 w" columnWidth " h34", "Department runs: matrix modes process Matrix Product rows; promotion_text_reference uses its own catalogue-search batch.")

    settingsGui.AddText("x" leftX " y137", "Submode")
    initialSubmodeLabels := GetSeoSubmodeLabelsForMode(GetSeoAutomationMode())
    controls["seoSubmode"] := settingsGui.AddDropDownList("x" leftX " y157 w360", initialSubmodeLabels)
    controls["seoSubmode"].Choose(GetSeoSubmodeOptionIndex(GetSeoAutomationMode(), GetSeoSubmodeId()))
    controls["seoSubmodeHelp"] := settingsGui.AddText("x" leftX " y190 w" columnWidth " h34", "Supplier product creation uses a submode to select its source, matching rules and prompts.")
    controls["submodeSelections"] := Map(GetSeoAutomationMode(), GetSeoSubmodeId())

    controls["seoPromptLabel"] := settingsGui.AddText("x" leftX " y230", "Prompt")
    initialPromptLabels := GetSeoPromptLabelsForSubmode(GetSeoAutomationMode(), GetSeoSubmodeId())
    if initialPromptLabels.Length = 0
        initialPromptLabels := ["Not used by this mode"]
    controls["seoPrompt"] := settingsGui.AddDropDownList("x" leftX " y250 w360", initialPromptLabels)
    controls["seoPrompt"].Choose(GetSeoPromptOptionsForSubmode(GetSeoAutomationMode(), GetSeoSubmodeId()).Length
        ? GetSeoPromptOptionIndex(GetSeoAutomationMode(), GetSeoSubmodeId(), botzPromptSettings["seoPromptId"])
        : 1)
    controls["seoPromptHelp"] := settingsGui.AddText("x" leftX " y283 w" columnWidth " h28", "Only prompts registered to the selected submode are available.")
    controls["promptSelections"] := Map(GetSeoAutomationMode() "|" GetSeoSubmodeId(), botzPromptSettings["seoPromptId"])

    settingsGui.SetFont("s10 Bold")
    settingsGui.AddText("x" leftX " y318", "Workflow options")
    settingsGui.SetFont("s9 Norm")
    controls["fullWorkflowAutomationEnabled"] := settingsGui.AddCheckBox("x" leftX " y346 w" columnWidth, "Automatically submit, wait for ChatGPT and insert the result")
    controls["fullWorkflowAutomationEnabled"].Value := fullWorkflowAutomationEnabled ? 1 : 0
    controls["departmentAutomationEnabled"] := settingsGui.AddCheckBox("x" leftX " y374 w" columnWidth, "Enable department-wide batch automation")
    controls["departmentAutomationEnabled"].Value := departmentAutomationEnabled ? 1 : 0
    controls["useRecommendedProductName"] := settingsGui.AddCheckBox("x" leftX " y402 w" columnWidth, "Insert ChatGPT's recommended product name")
    controls["useRecommendedProductName"].Value := useRecommendedProductName ? 1 : 0
    controls["attemptImageCopyAfterPrompt"] := settingsGui.AddCheckBox("x" leftX " y430 w" columnWidth, "Automatically attach CMS images to ordinary and matrix prompts")
    controls["attemptImageCopyAfterPrompt"].Value := attemptImageCopyAfterPrompt ? 1 : 0
    settingsGui.AddText("x" leftX " y458 w" columnWidth " h34", "Department batches start with Ctrl+Numpad4 and stop safely after the current product with Ctrl+Numpad6.")

    controls["promotionTextLabel"] := settingsGui.AddText("x" leftX " y503", "Promotional text")
    controls["promotionText"] := settingsGui.AddEdit("x" leftX " y524 w" columnWidth " r4", botzPromptSettings["promotionText"])
    controls["promotionTextHelp"] := settingsGui.AddText("x" leftX " y606 w" columnWidth " h30", "Used only by the two promotion modes. Leave empty to clear both promotional fields.")

    controls["testingModeEnabled"] := settingsGui.AddCheckBox("x" leftX " y648 w" columnWidth, "Testing mode (save detailed diagnostics)")
    controls["testingModeEnabled"].Value := botzPromptSettings["testingModeEnabled"] ? 1 : 0
    settingsGui.AddText("x" leftX " y674 w" columnWidth " h34", "Records workflow events, timing samples, errors, window state and relevant accessibility trees in the debug folder.")

    ; Right column: destinations and prompt context.
    settingsGui.SetFont("s11 Bold")
    settingsGui.AddText("x" rightX " y14", "Windows and prompt context")
    settingsGui.SetFont("s9 Norm")
    settingsGui.AddText("x" rightX " y44 w165", "GO b2b CMS window")
    controls["cmsWindowTitle"] := settingsGui.AddEdit("x" (rightX + 170) " y41 w350", botzPromptSettings["cmsWindowTitle"])
    settingsGui.AddText("x" rightX " y78 w165", "ChatGPT window")
    controls["chatgptWindowTitle"] := settingsGui.AddEdit("x" (rightX + 170) " y75 w350", botzPromptSettings["chatgptWindowTitle"])
    settingsGui.AddText("x" rightX " y112 w165", "Department ChatGPT")
    controls["departmentChatgptWindowTitle"] := settingsGui.AddEdit("x" (rightX + 170) " y109 w350", botzPromptSettings["departmentChatgptWindowTitle"])
    settingsGui.AddText("x" rightX " y143 w" columnWidth " h30", "Titles use partial matching. Ctrl+Alt+W copies the active window title.")

    settingsGui.AddText("x" rightX " y184", "Cromartie page URL")
    controls["pageUrl"] := settingsGui.AddEdit("x" rightX " y205 w" columnWidth, botzPromptSettings["pageUrl"])

    settingsGui.SetFont("s10 Bold")
    settingsGui.AddText("x" rightX " y255", "Recommended internal links")
    settingsGui.SetFont("s9 Norm")
    settingsGui.AddText("x" rightX " y282 w165", "Inlink name")
    settingsGui.AddText("x" (rightX + 174) " y282 w346", "Inlink URL")

    controls["inlink1Name"] := settingsGui.AddEdit("x" rightX " y303 w165", botzPromptSettings["inlink1Name"])
    controls["inlink1Url"] := settingsGui.AddEdit("x" (rightX + 174) " y303 w346", botzPromptSettings["inlink1Url"])
    controls["inlink2Name"] := settingsGui.AddEdit("x" rightX " y337 w165", botzPromptSettings["inlink2Name"])
    controls["inlink2Url"] := settingsGui.AddEdit("x" (rightX + 174) " y337 w346", botzPromptSettings["inlink2Url"])

    settingsGui.AddText("x" rightX " y383", "Extra inlink information")
    controls["inlinkExtra"] := settingsGui.AddEdit("x" rightX " y404 w" columnWidth " r3", botzPromptSettings["inlinkExtra"])

    settingsGui.AddText("x" rightX " y486", "Additional notes")
    controls["additionalNotes"] := settingsGui.AddEdit("x" rightX " y507 w" columnWidth " r5", botzPromptSettings["additionalNotes"])

    controls["seoAutomationMode"].OnEvent("Change", UpdateSeoPromptSettingsControls.Bind(controls))
    controls["seoSubmode"].OnEvent("Change", UpdateSeoPromptSettingsForSubmode.Bind(controls))
    controls["seoPrompt"].OnEvent("Change", RememberSeoPromptSelection.Bind(controls))
    UpdateSeoPromptSettingsControls(controls)

    saveButton := settingsGui.AddButton("x" rightX " y660 w110 Default", "Save")
    cancelButton := settingsGui.AddButton("x" (rightX + 120) " y660 w110", "Cancel")
    saveButton.OnEvent("Click", SaveSeoPromptSettingsFromGui.Bind(settingsGui, controls))
    cancelButton.OnEvent("Click", CloseSeoPromptSettingsGui.Bind(settingsGui))
    settingsGui.OnEvent("Close", CloseSeoPromptSettingsGui)
    settingsGui.OnEvent("Escape", CloseSeoPromptSettingsGui)

    botzPromptSettingsGui := settingsGui
    settingsGui.Show("w1105 h720 Center")
    controls["seoAutomationMode"].Focus()
}

SaveSeoPromptSettingsFromGui(settingsGui, controls, *) {
    global botzPromptSettings, departmentAutomationActive, automaticWorkflowActive
    global promotionReferenceBatchActive
    global useRecommendedProductName, fullWorkflowAutomationEnabled, departmentAutomationEnabled
    global attemptImageCopyAfterPrompt
    global cmsWinTitle, chatgptWinTitle, departmentChatgptWinTitle

    settings := Map(
        "seoAutomationMode", StrLower(Trim(controls["seoAutomationMode"].Text)),
        "seoSubmodeId", GetSeoSubmodeIdFromOptionIndex(StrLower(Trim(controls["seoAutomationMode"].Text)), controls["seoSubmode"].Value),
        "seoPromptId", GetSeoPromptIdFromOptionIndex(
            StrLower(Trim(controls["seoAutomationMode"].Text)),
            GetSeoSubmodeIdFromOptionIndex(StrLower(Trim(controls["seoAutomationMode"].Text)), controls["seoSubmode"].Value),
            controls["seoPrompt"].Value
        ),
        "pageUrl", Trim(controls["pageUrl"].Value),
        "inlink1Name", Trim(controls["inlink1Name"].Value),
        "inlink1Url", Trim(controls["inlink1Url"].Value),
        "inlink2Name", Trim(controls["inlink2Name"].Value),
        "inlink2Url", Trim(controls["inlink2Url"].Value),
        "inlinkExtra", Trim(controls["inlinkExtra"].Value),
        "additionalNotes", Trim(controls["additionalNotes"].Value),
        "promotionText", Trim(controls["promotionText"].Value, " `t`r`n"),
        "testingModeEnabled", controls["testingModeEnabled"].Value = 1,
        "cmsWindowTitle", Trim(controls["cmsWindowTitle"].Value),
        "chatgptWindowTitle", Trim(controls["chatgptWindowTitle"].Value),
        "departmentChatgptWindowTitle", Trim(controls["departmentChatgptWindowTitle"].Value),
        "useRecommendedProductName", controls["useRecommendedProductName"].Value = 1,
        "fullWorkflowAutomationEnabled", controls["fullWorkflowAutomationEnabled"].Value = 1,
        "departmentAutomationEnabled", controls["departmentAutomationEnabled"].Value = 1,
        "attemptImageCopyAfterPrompt", controls["attemptImageCopyAfterPrompt"].Value = 1
    )

    try {
        ValidateBotzPromptSettings(settings)
        workflowOptionsChanged := settings["useRecommendedProductName"] != useRecommendedProductName
            || settings["fullWorkflowAutomationEnabled"] != fullWorkflowAutomationEnabled
            || settings["departmentAutomationEnabled"] != departmentAutomationEnabled
            || settings["attemptImageCopyAfterPrompt"] != attemptImageCopyAfterPrompt
        windowTitlesChanged := settings["cmsWindowTitle"] != cmsWinTitle
            || settings["chatgptWindowTitle"] != chatgptWinTitle
            || settings["departmentChatgptWindowTitle"] != departmentChatgptWinTitle
        if (departmentAutomationActive || automaticWorkflowActive || promotionReferenceBatchActive)
            && (settings["seoAutomationMode"] != GetSeoAutomationMode()
                || settings["seoSubmodeId"] != GetSeoSubmodeId()
                || settings["seoPromptId"] != GetSeoPromptId()
                || workflowOptionsChanged
                || windowTitlesChanged)
            throw Error("The SEO mode, submode, prompt, window titles or workflow options cannot be changed while an automatic workflow is active. Stop or finish the current run first.")
        SaveBotzPromptSettings(settings)
        botzPromptSettings := settings
        ApplySharedSeoPromptSettings(settings)
        CloseSeoPromptSettingsGui(settingsGui)
        testingStatus := settings["testingModeEnabled"] ? "ON" : "OFF"
        departmentStatus := settings["departmentAutomationEnabled"] ? "ON" : "OFF"
        automaticStatus := settings["fullWorkflowAutomationEnabled"] ? "ON" : "OFF"
        Flash("SEO settings saved.`nMode: " settings["seoAutomationMode"] "`nSubmode: " GetSeoSubmodeLabel(settings["seoAutomationMode"], settings["seoSubmodeId"]) "`nAutomatic workflow: " automaticStatus "`nDepartment automation: " departmentStatus "`nTesting mode: " testingStatus, 3000)
    } catch as err {
        ReportTestingError("save-seo-prompt-settings", err, false)
        MsgBox "SEO prompt settings were not saved.`n`n" err.Message
    }
}

UpdateSeoPromptSettingsControls(controls, *) {
    selectedMode := StrLower(Trim(controls["seoAutomationMode"].Text))
    selectedSubmodeId := controls["submodeSelections"].Has(selectedMode)
        ? controls["submodeSelections"][selectedMode]
        : GetDefaultSeoSubmodeId(selectedMode)
    submodeLabels := GetSeoSubmodeLabelsForMode(selectedMode)

    controls["seoSubmode"].Delete()
    controls["seoSubmode"].Add(submodeLabels)
    controls["seoSubmode"].Choose(GetSeoSubmodeOptionIndex(selectedMode, selectedSubmodeId))
    controls["seoSubmode"].Enabled := submodeLabels.Length > 1
    controls["seoSubmodeHelp"].Text := submodeLabels.Length > 1
        ? "Select the supplier workflow before selecting its prompt."
        : "This mode uses its default submode."
    controls["submodeSelections"][selectedMode] := selectedSubmodeId
    UpdateSeoPromptSettingsForSubmode(controls)

    enabled := selectedMode = "promotion_text" || selectedMode = "promotion_text_reference"
    controls["promotionTextLabel"].Enabled := enabled
    controls["promotionText"].Enabled := enabled
    controls["promotionTextHelp"].Enabled := enabled

    ; Department review mode deliberately leaves each product open and cannot
    ; be used as a department-wide batch target.
    controls["departmentAutomationEnabled"].Enabled := selectedMode != "department"
    if selectedMode = "department"
        controls["departmentAutomationEnabled"].Value := 0
}

UpdateSeoPromptSettingsForSubmode(controls, *) {
    selectedMode := StrLower(Trim(controls["seoAutomationMode"].Text))
    selectedSubmodeId := GetSeoSubmodeIdFromOptionIndex(selectedMode, controls["seoSubmode"].Value)
    controls["submodeSelections"][selectedMode] := selectedSubmodeId
    selectionKey := selectedMode "|" selectedSubmodeId
    selectedPromptId := controls["promptSelections"].Has(selectionKey)
        ? controls["promptSelections"][selectionKey]
        : GetDefaultSeoPromptId(selectedMode, selectedSubmodeId)
    labels := GetSeoPromptLabelsForSubmode(selectedMode, selectedSubmodeId)

    controls["seoPrompt"].Delete()
    if labels.Length {
        controls["seoPrompt"].Add(labels)
        controls["seoPrompt"].Choose(GetSeoPromptOptionIndex(selectedMode, selectedSubmodeId, selectedPromptId))
        controls["seoPrompt"].Enabled := true
        controls["seoPromptHelp"].Text := "Only prompts registered to " GetSeoSubmodeLabel(selectedMode, selectedSubmodeId) " are available."
        RememberSeoPromptSelection(controls)
    } else {
        controls["seoPrompt"].Add(["Not used by this mode"])
        controls["seoPrompt"].Choose(1)
        controls["seoPrompt"].Enabled := false
        controls["seoPromptHelp"].Text := "This mode performs no ChatGPT prompt step."
        controls["promptSelections"][selectionKey] := ""
    }
}

RememberSeoPromptSelection(controls, *) {
    selectedMode := StrLower(Trim(controls["seoAutomationMode"].Text))
    selectedSubmodeId := GetSeoSubmodeIdFromOptionIndex(selectedMode, controls["seoSubmode"].Value)
    promptId := GetSeoPromptIdFromOptionIndex(selectedMode, selectedSubmodeId, controls["seoPrompt"].Value)
    controls["promptSelections"][selectedMode "|" selectedSubmodeId] := promptId
}

CloseSeoPromptSettingsGui(settingsGui, *) {
    global botzPromptSettingsGui

    try settingsGui.Destroy()
    botzPromptSettingsGui := 0
}

