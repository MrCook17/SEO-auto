OpenSeoPromptSettingsGui() {
    global botzPromptSettings, botzPromptSettingsGui

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

    settingsGui := Gui("+AlwaysOnTop +OwnDialogs", "SEO Prompt Settings")
    settingsGui.MarginX := 16
    settingsGui.MarginY := 14
    settingsGui.SetFont("s10", "Segoe UI")

    controls := Map()
    settingsGui.AddText("xm", "SEO automation mode")
    controls["seoAutomationMode"] := settingsGui.AddDropDownList("xm y+4 w260", GetSeoAutomationModeOptions())
    controls["seoAutomationMode"].Choose(GetSeoAutomationModeOptionIndex(GetSeoAutomationMode()))
    settingsGui.AddText("xm y+6 w700", "Department runs: matrix modes process Matrix Product rows; promotion_text_reference runs its own catalogue-search batch.")

    controls["seoPromptLabel"] := settingsGui.AddText("xm y+14", "Prompt")
    initialPromptLabels := GetSeoPromptLabelsForMode(GetSeoAutomationMode())
    if initialPromptLabels.Length = 0
        initialPromptLabels := ["Not used by this mode"]
    controls["seoPrompt"] := settingsGui.AddDropDownList("xm y+4 w360", initialPromptLabels)
    controls["seoPrompt"].Choose(GetSeoPromptOptionsForMode(GetSeoAutomationMode()).Length
        ? GetSeoPromptOptionIndex(GetSeoAutomationMode(), botzPromptSettings["seoPromptId"])
        : 1)
    controls["seoPromptHelp"] := settingsGui.AddText("xm y+4 w700", "Only prompts registered to the selected mode are available.")
    controls["promptSelections"] := Map(GetSeoAutomationMode(), botzPromptSettings["seoPromptId"])

    controls["promotionTextLabel"] := settingsGui.AddText("xm y+14", "Promotional text")
    controls["promotionText"] := settingsGui.AddEdit("xm y+4 w700 r5", botzPromptSettings["promotionText"])
    controls["promotionTextHelp"] := settingsGui.AddText("xm y+4 w700", "Leave empty to clear Description and Custom promotional fields in either promotion mode.")
    controls["seoAutomationMode"].OnEvent("Change", UpdateSeoPromptSettingsControls.Bind(controls))
    controls["seoPrompt"].OnEvent("Change", RememberSeoPromptSelection.Bind(controls))
    UpdateSeoPromptSettingsControls(controls)

    controls["testingModeEnabled"] := settingsGui.AddCheckBox("xm y+14 w700", "Testing mode (save detailed diagnostics for future debugging)")
    controls["testingModeEnabled"].Value := botzPromptSettings["testingModeEnabled"] ? 1 : 0
    settingsGui.AddText("xm y+4 w700", "Records workflow events, timing/count samples, errors, window state and relevant accessibility trees in the debug folder.")

    settingsGui.AddText("xm y+14", "Cromartie page URL")
    controls["pageUrl"] := settingsGui.AddEdit("xm y+4 w700", botzPromptSettings["pageUrl"])

    settingsGui.SetFont("s10 Bold")
    settingsGui.AddText("xm y+16", "Recommended internal links")
    settingsGui.SetFont("s9 Norm")
    settingsGui.AddText("xm y+6 w220", "Inlink name")
    settingsGui.AddText("x+12 yp w468", "Inlink URL")

    controls["inlink1Name"] := settingsGui.AddEdit("xm y+4 w220", botzPromptSettings["inlink1Name"])
    controls["inlink1Url"] := settingsGui.AddEdit("x+12 yp w468", botzPromptSettings["inlink1Url"])
    controls["inlink2Name"] := settingsGui.AddEdit("xm y+8 w220", botzPromptSettings["inlink2Name"])
    controls["inlink2Url"] := settingsGui.AddEdit("x+12 yp w468", botzPromptSettings["inlink2Url"])

    settingsGui.AddText("xm y+14", "Extra inlink information")
    controls["inlinkExtra"] := settingsGui.AddEdit("xm y+4 w700 r3", botzPromptSettings["inlinkExtra"])

    settingsGui.AddText("xm y+14", "Additional notes")
    controls["additionalNotes"] := settingsGui.AddEdit("xm y+4 w700 r4", botzPromptSettings["additionalNotes"])

    saveButton := settingsGui.AddButton("xm y+16 w100 Default", "Save")
    cancelButton := settingsGui.AddButton("x+10 yp w100", "Cancel")
    saveButton.OnEvent("Click", SaveSeoPromptSettingsFromGui.Bind(settingsGui, controls))
    cancelButton.OnEvent("Click", CloseSeoPromptSettingsGui.Bind(settingsGui))
    settingsGui.OnEvent("Close", CloseSeoPromptSettingsGui)
    settingsGui.OnEvent("Escape", CloseSeoPromptSettingsGui)

    botzPromptSettingsGui := settingsGui
    settingsGui.Show("AutoSize Center")
    controls["seoAutomationMode"].Focus()
}

SaveSeoPromptSettingsFromGui(settingsGui, controls, *) {
    global botzPromptSettings, departmentAutomationActive, automaticWorkflowActive
    global promotionReferenceBatchActive

    settings := Map(
        "seoAutomationMode", StrLower(Trim(controls["seoAutomationMode"].Text)),
        "seoPromptId", GetSeoPromptIdFromOptionIndex(StrLower(Trim(controls["seoAutomationMode"].Text)), controls["seoPrompt"].Value),
        "pageUrl", Trim(controls["pageUrl"].Value),
        "inlink1Name", Trim(controls["inlink1Name"].Value),
        "inlink1Url", Trim(controls["inlink1Url"].Value),
        "inlink2Name", Trim(controls["inlink2Name"].Value),
        "inlink2Url", Trim(controls["inlink2Url"].Value),
        "inlinkExtra", Trim(controls["inlinkExtra"].Value),
        "additionalNotes", Trim(controls["additionalNotes"].Value),
        "promotionText", Trim(controls["promotionText"].Value, " `t`r`n"),
        "testingModeEnabled", controls["testingModeEnabled"].Value = 1
    )

    try {
        ValidateBotzPromptSettings(settings)
        if (departmentAutomationActive || automaticWorkflowActive || promotionReferenceBatchActive)
            && (settings["seoAutomationMode"] != GetSeoAutomationMode() || settings["seoPromptId"] != GetSeoPromptId())
            throw Error("The SEO mode or prompt cannot be changed while an automatic workflow is active. Stop or finish the current run first.")
        SaveBotzPromptSettings(settings)
        botzPromptSettings := settings
        ApplySharedSeoPromptSettings(settings)
        CloseSeoPromptSettingsGui(settingsGui)
        testingStatus := settings["testingModeEnabled"] ? "ON" : "OFF"
        Flash("SEO prompt settings saved.`nMode: " settings["seoAutomationMode"] "`nPrompt: " GetSeoPromptLabel(settings["seoAutomationMode"], settings["seoPromptId"]) "`nTesting mode: " testingStatus, 2500)
    } catch as err {
        ReportTestingError("save-seo-prompt-settings", err, false)
        MsgBox "SEO prompt settings were not saved.`n`n" err.Message
    }
}

UpdateSeoPromptSettingsControls(controls, *) {
    selectedMode := StrLower(Trim(controls["seoAutomationMode"].Text))
    selectedPromptId := controls["promptSelections"].Has(selectedMode)
        ? controls["promptSelections"][selectedMode]
        : GetDefaultSeoPromptId(selectedMode)
    labels := GetSeoPromptLabelsForMode(selectedMode)

    controls["seoPrompt"].Delete()
    if labels.Length {
        controls["seoPrompt"].Add(labels)
        controls["seoPrompt"].Choose(GetSeoPromptOptionIndex(selectedMode, selectedPromptId))
        controls["seoPrompt"].Enabled := true
        controls["seoPromptHelp"].Text := "Only prompts registered to " selectedMode " mode are available."
        RememberSeoPromptSelection(controls)
    } else {
        controls["seoPrompt"].Add(["Not used by this mode"])
        controls["seoPrompt"].Choose(1)
        controls["seoPrompt"].Enabled := false
        controls["seoPromptHelp"].Text := "This mode performs no ChatGPT prompt step."
        controls["promptSelections"][selectedMode] := ""
    }

    enabled := selectedMode = "promotion_text" || selectedMode = "promotion_text_reference"
    controls["promotionTextLabel"].Enabled := enabled
    controls["promotionText"].Enabled := enabled
    controls["promotionTextHelp"].Enabled := enabled
}

RememberSeoPromptSelection(controls, *) {
    selectedMode := StrLower(Trim(controls["seoAutomationMode"].Text))
    promptId := GetSeoPromptIdFromOptionIndex(selectedMode, controls["seoPrompt"].Value)
    controls["promptSelections"][selectedMode] := promptId
}

CloseSeoPromptSettingsGui(settingsGui, *) {
    global botzPromptSettingsGui

    try settingsGui.Destroy()
    botzPromptSettingsGui := 0
}

