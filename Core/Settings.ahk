InitialiseSeoPromptSettings() {
    global botzPromptSettings, botzPromptSettingsFilePath

    try {
        botzPromptSettings := LoadBotzPromptSettings()
        ApplySharedSeoPromptSettings(botzPromptSettings)
    } catch as err {
        botzPromptSettings := CreateDefaultBotzPromptSettings()
        ApplySharedSeoPromptSettings(botzPromptSettings)
        MsgBox "The saved SEO prompt settings could not be loaded, so the built-in defaults are being used.`n`nFile: " botzPromptSettingsFilePath "`n`n" err.Message
    }
}

ApplySharedSeoPromptSettings(settings) {
    global SeoAutomationMode, SeoPromptId, hardcodedPageUrl, requiredInternalLinksDefault, additionalProductNotesDefault, promotionText
    global testingModeEnabled

    testingWasEnabled := testingModeEnabled
    SeoAutomationMode := settings["seoAutomationMode"]
    SeoPromptId := settings["seoPromptId"]
    hardcodedPageUrl := settings["pageUrl"]
    requiredInternalLinksDefault := BuildBotzRecommendedInlinks(settings)
    additionalProductNotesDefault := settings["additionalNotes"] != "" ? settings["additionalNotes"] : "NONE"
    promotionText := settings["promotionText"]
    testingModeEnabled := settings["testingModeEnabled"]

    if testingModeEnabled {
        EnsureTestingSessionLog()
        TestingLog(
            testingWasEnabled ? "settings-applied" : "testing-mode-enabled",
            BuildTestingRuntimeSummary()
        )
    } else if testingWasEnabled {
        ; Record the final setting change while diagnostics are still enabled.
        testingModeEnabled := true
        TestingLog("testing-mode-disabled", "Testing mode was disabled and saved from the SEO Prompt Settings menu.")
        testingModeEnabled := false
    }
}

CreateDefaultBotzPromptSettings() {
    global botzDefaultPageUrl

    return Map(
        "seoAutomationMode", GetSeoAutomationMode(),
        "seoPromptId", GetDefaultSeoPromptId(GetSeoAutomationMode()),
        "pageUrl", botzDefaultPageUrl,
        "inlink1Name", "",
        "inlink1Url", "",
        "inlink2Name", "",
        "inlink2Url", "",
        "inlinkExtra", "",
        "additionalNotes", "",
        "promotionText", "",
        "testingModeEnabled", false
    )
}

ValidateBotzPromptSettings(settings) {
    if !settings.Has("seoAutomationMode") || !IsValidSeoAutomationMode(settings["seoAutomationMode"])
        throw Error("Select a valid SEO automation mode.")
    if !settings.Has("seoPromptId")
        throw Error("The SEO prompt setting is missing.")
    if !IsValidSeoPromptForMode(settings["seoAutomationMode"], settings["seoPromptId"])
        throw Error("Select a prompt that belongs to the selected SEO automation mode.")
    if !settings.Has("promotionText")
        throw Error("The promotion-text setting is missing.")
    if !settings.Has("testingModeEnabled")
        throw Error("The testing-mode setting is missing.")
    if settings["testingModeEnabled"] != true && settings["testingModeEnabled"] != false
        throw Error("The testing-mode setting must be enabled or disabled.")
    if settings["pageUrl"] = ""
        throw Error("The Cromartie page URL cannot be blank.")
    if !IsBotzHttpUrl(settings["pageUrl"])
        throw Error("The Cromartie page URL must be a complete http:// or https:// URL without spaces.")

    Loop 2 {
        index := A_Index
        name := settings["inlink" index "Name"]
        url := settings["inlink" index "Url"]
        if (name = "") != (url = "")
            throw Error("Inlink row " index " must have both a name and a URL, or both boxes must be blank.")
        if url != "" && !IsBotzHttpUrl(url)
            throw Error("Inlink row " index " must use a complete http:// or https:// URL without spaces.")
    }
}

SaveBotzPromptSettings(settings) {
    global botzPromptSettingsFilePath

    ValidateBotzPromptSettings(settings)
    EnsureFolders()
    text := "CROMARTIE_BOTZ_PROMPT_SETTINGS_V1`n"
    text .= "seo_automation_mode`t" EncodeStateValue(settings["seoAutomationMode"]) "`n"
    text .= "seo_prompt_id`t" EncodeStateValue(settings["seoPromptId"]) "`n"
    text .= "page_url`t" EncodeStateValue(settings["pageUrl"]) "`n"
    text .= "inlink_1_name`t" EncodeStateValue(settings["inlink1Name"]) "`n"
    text .= "inlink_1_url`t" EncodeStateValue(settings["inlink1Url"]) "`n"
    text .= "inlink_2_name`t" EncodeStateValue(settings["inlink2Name"]) "`n"
    text .= "inlink_2_url`t" EncodeStateValue(settings["inlink2Url"]) "`n"
    text .= "inlink_extra`t" EncodeStateValue(settings["inlinkExtra"]) "`n"
    text .= "additional_notes`t" EncodeStateValue(settings["additionalNotes"]) "`n"
    text .= "promotion_text`t" EncodeStateValue(settings["promotionText"]) "`n"
    text .= "testing_mode_enabled`t" (settings["testingModeEnabled"] ? "1" : "0") "`n"

    temporaryPath := botzPromptSettingsFilePath ".tmp"
    if FileExist(temporaryPath)
        FileDelete temporaryPath
    FileAppend text, temporaryPath, "UTF-8"
    FileMove temporaryPath, botzPromptSettingsFilePath, 1
}

LoadBotzPromptSettings() {
    global botzPromptSettingsFilePath

    if !FileExist(botzPromptSettingsFilePath)
        return CreateDefaultBotzPromptSettings()

    lines := StrSplit(StrReplace(FileRead(botzPromptSettingsFilePath, "UTF-8"), "`r", ""), "`n")
    if lines.Length < 8 || lines[1] != "CROMARTIE_BOTZ_PROMPT_SETTINGS_V1"
        throw Error("The BOTZ prompt settings file is invalid or unsupported.")

    values := Map()
    Loop lines.Length - 1 {
        line := lines[A_Index + 1]
        if line = ""
            continue
        parts := StrSplit(line, "`t")
        if parts.Length != 2
            throw Error("The BOTZ prompt settings file contains an invalid record.")
        values[parts[1]] := DecodeStateValue(parts[2])
    }

    fieldMap := Map(
        "page_url", "pageUrl",
        "inlink_1_name", "inlink1Name",
        "inlink_1_url", "inlink1Url",
        "inlink_2_name", "inlink2Name",
        "inlink_2_url", "inlink2Url",
        "inlink_extra", "inlinkExtra",
        "additional_notes", "additionalNotes"
    )
    settings := Map()
    for fileKey, settingKey in fieldMap {
        if !values.Has(fileKey)
            throw Error("The BOTZ prompt settings file is missing: " fileKey ".")
        settings[settingKey] := values[fileKey]
    }
    ; Keep settings files saved before promotion_text mode backward compatible.
    settings["promotionText"] := values.Has("promotion_text") ? values["promotion_text"] : ""
    ; Keep settings files saved before diagnostic testing mode backward compatible.
    if values.Has("testing_mode_enabled")
        && values["testing_mode_enabled"] != "0"
        && values["testing_mode_enabled"] != "1"
        throw Error("The saved testing-mode setting must be 0 or 1.")
    settings["testingModeEnabled"] := values.Has("testing_mode_enabled")
        ? values["testing_mode_enabled"] = "1"
        : false
    ; Files saved before the mode dropdown existed remain valid and retain the
    ; configured SeoAutomationMode from the top of this script until next save.
    settings["seoAutomationMode"] := values.Has("seo_automation_mode")
        ? StrLower(Trim(values["seo_automation_mode"]))
        : GetSeoAutomationMode()
    ; Settings saved before prompt selection existed use that mode's first
    ; registered prompt, preserving every previous workflow by default.
    settings["seoPromptId"] := values.Has("seo_prompt_id")
        ? StrLower(Trim(values["seo_prompt_id"]))
        : GetDefaultSeoPromptId(settings["seoAutomationMode"])
    ValidateBotzPromptSettings(settings)
    return settings
}

