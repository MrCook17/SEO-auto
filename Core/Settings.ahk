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
    global SeoAutomationMode, SeoSubmodeId, SeoPromptId, hardcodedPageUrl, requiredInternalLinksDefault, additionalProductNotesDefault, promotionText
    global testingModeEnabled
    global cmsWinTitle, chatgptWinTitle, departmentChatgptWinTitle
    global useRecommendedProductName, fullWorkflowAutomationEnabled, departmentAutomationEnabled
    global attemptImageCopyAfterPrompt

    testingWasEnabled := testingModeEnabled
    SeoAutomationMode := settings["seoAutomationMode"]
    SeoSubmodeId := settings["seoSubmodeId"]
    SeoPromptId := settings["seoPromptId"]
    hardcodedPageUrl := settings["pageUrl"]
    requiredInternalLinksDefault := BuildBotzRecommendedInlinks(settings)
    additionalProductNotesDefault := settings["additionalNotes"] != "" ? settings["additionalNotes"] : "NONE"
    promotionText := settings["promotionText"]
    testingModeEnabled := settings["testingModeEnabled"]
    cmsWinTitle := settings["cmsWindowTitle"]
    chatgptWinTitle := settings["chatgptWindowTitle"]
    departmentChatgptWinTitle := settings["departmentChatgptWindowTitle"]
    useRecommendedProductName := settings["useRecommendedProductName"]
    fullWorkflowAutomationEnabled := settings["fullWorkflowAutomationEnabled"]
    departmentAutomationEnabled := settings["departmentAutomationEnabled"]
    attemptImageCopyAfterPrompt := settings["attemptImageCopyAfterPrompt"]

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
    global cmsWinTitle, chatgptWinTitle, departmentChatgptWinTitle
    global useRecommendedProductName, fullWorkflowAutomationEnabled, departmentAutomationEnabled
    global attemptImageCopyAfterPrompt

    mode := GetSeoAutomationMode()
    submodeId := IsValidSeoSubmodeForMode(mode, GetSeoSubmodeId())
        ? GetSeoSubmodeId()
        : GetDefaultSeoSubmodeId(mode)
    return Map(
        "seoAutomationMode", mode,
        "seoSubmodeId", submodeId,
        "seoPromptId", GetDefaultSeoPromptId(mode, submodeId),
        "pageUrl", botzDefaultPageUrl,
        "inlink1Name", "",
        "inlink1Url", "",
        "inlink2Name", "",
        "inlink2Url", "",
        "inlinkExtra", "",
        "additionalNotes", "",
        "promotionText", "",
        "testingModeEnabled", false,
        "cmsWindowTitle", cmsWinTitle,
        "chatgptWindowTitle", chatgptWinTitle,
        "departmentChatgptWindowTitle", departmentChatgptWinTitle,
        "useRecommendedProductName", useRecommendedProductName,
        "fullWorkflowAutomationEnabled", fullWorkflowAutomationEnabled,
        "departmentAutomationEnabled", departmentAutomationEnabled,
        "attemptImageCopyAfterPrompt", attemptImageCopyAfterPrompt
    )
}

ValidateBotzPromptSettings(settings) {
    if !settings.Has("seoAutomationMode") || !IsValidSeoAutomationMode(settings["seoAutomationMode"])
        throw Error("Select a valid SEO automation mode.")
    if !settings.Has("seoSubmodeId") || !IsValidSeoSubmodeForMode(settings["seoAutomationMode"], settings["seoSubmodeId"])
        throw Error("Select a submode that belongs to the selected SEO automation mode.")
    if !settings.Has("seoPromptId")
        throw Error("The SEO prompt setting is missing.")
    if !IsValidSeoPromptForSubmode(settings["seoAutomationMode"], settings["seoSubmodeId"], settings["seoPromptId"])
        throw Error("Select a prompt that belongs to the selected SEO submode.")
    if !settings.Has("promotionText")
        throw Error("The promotion-text setting is missing.")
    if !settings.Has("testingModeEnabled")
        throw Error("The testing-mode setting is missing.")
    if settings["testingModeEnabled"] != true && settings["testingModeEnabled"] != false
        throw Error("The testing-mode setting must be enabled or disabled.")
    if !settings.Has("cmsWindowTitle") || Trim(settings["cmsWindowTitle"]) = ""
        throw Error("The GO b2b CMS window title cannot be blank.")
    if !settings.Has("chatgptWindowTitle") || Trim(settings["chatgptWindowTitle"]) = ""
        throw Error("The ChatGPT window title cannot be blank.")
    if !settings.Has("departmentChatgptWindowTitle") || Trim(settings["departmentChatgptWindowTitle"]) = ""
        throw Error("The Department ChatGPT window title cannot be blank.")
    for _, key in ["useRecommendedProductName", "fullWorkflowAutomationEnabled", "departmentAutomationEnabled", "attemptImageCopyAfterPrompt"] {
        if !settings.Has(key) || (settings[key] != true && settings[key] != false)
            throw Error("The workflow option '" key "' must be enabled or disabled.")
    }
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
    text .= "seo_submode_id`t" EncodeStateValue(settings["seoSubmodeId"]) "`n"
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
    text .= "cms_window_title`t" EncodeStateValue(settings["cmsWindowTitle"]) "`n"
    text .= "chatgpt_window_title`t" EncodeStateValue(settings["chatgptWindowTitle"]) "`n"
    text .= "department_chatgpt_window_title`t" EncodeStateValue(settings["departmentChatgptWindowTitle"]) "`n"
    text .= "use_recommended_product_name`t" (settings["useRecommendedProductName"] ? "1" : "0") "`n"
    text .= "full_workflow_automation_enabled`t" (settings["fullWorkflowAutomationEnabled"] ? "1" : "0") "`n"
    text .= "department_automation_enabled`t" (settings["departmentAutomationEnabled"] ? "1" : "0") "`n"
    text .= "attempt_image_copy_after_prompt`t" (settings["attemptImageCopyAfterPrompt"] ? "1" : "0") "`n"

    temporaryPath := botzPromptSettingsFilePath ".tmp"
    if FileExist(temporaryPath)
        FileDelete temporaryPath
    FileAppend text, temporaryPath, "UTF-8"
    FileMove temporaryPath, botzPromptSettingsFilePath, 1
}

LoadBotzPromptSettings() {
    global botzPromptSettingsFilePath
    global cmsWinTitle, chatgptWinTitle, departmentChatgptWinTitle
    global useRecommendedProductName, fullWorkflowAutomationEnabled, departmentAutomationEnabled
    global attemptImageCopyAfterPrompt

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
    ; Window-title settings were added later. Older files keep using the
    ; configured startup titles until they are next saved from the menu.
    settings["cmsWindowTitle"] := values.Has("cms_window_title")
        ? values["cms_window_title"]
        : cmsWinTitle
    settings["chatgptWindowTitle"] := values.Has("chatgpt_window_title")
        ? values["chatgpt_window_title"]
        : chatgptWinTitle
    settings["departmentChatgptWindowTitle"] := values.Has("department_chatgpt_window_title")
        ? values["department_chatgpt_window_title"]
        : departmentChatgptWinTitle
    optionDefaults := Map(
        "use_recommended_product_name", Map("setting", "useRecommendedProductName", "default", useRecommendedProductName),
        "full_workflow_automation_enabled", Map("setting", "fullWorkflowAutomationEnabled", "default", fullWorkflowAutomationEnabled),
        "department_automation_enabled", Map("setting", "departmentAutomationEnabled", "default", departmentAutomationEnabled),
        "attempt_image_copy_after_prompt", Map("setting", "attemptImageCopyAfterPrompt", "default", attemptImageCopyAfterPrompt)
    )
    for fileKey, option in optionDefaults {
        if values.Has(fileKey) && values[fileKey] != "0" && values[fileKey] != "1"
            throw Error("The saved workflow option '" fileKey "' must be 0 or 1.")
        settings[option["setting"]] := values.Has(fileKey)
            ? values[fileKey] = "1"
            : option["default"]
    }
    ; Files saved before the mode dropdown existed remain valid and retain the
    ; configured SeoAutomationMode from the top of this script until next save.
    savedMode := values.Has("seo_automation_mode")
        ? StrLower(Trim(values["seo_automation_mode"]))
        : GetSeoAutomationMode()
    ; BOTZ was formerly a top-level mode. Migrate it to the supplier-product
    ; mode and its BOTZ submode when loading the existing settings file.
    settings["seoAutomationMode"] := NormaliseSeoAutomationMode(savedMode)
    settings["seoSubmodeId"] := values.Has("seo_submode_id")
        ? StrLower(Trim(values["seo_submode_id"]))
        : (savedMode = "botz" ? "botz" : GetDefaultSeoSubmodeId(settings["seoAutomationMode"]))
    ; Settings saved before prompt selection existed use that mode's first
    ; registered prompt, preserving every previous workflow by default.
    settings["seoPromptId"] := values.Has("seo_prompt_id")
        ? StrLower(Trim(values["seo_prompt_id"]))
        : GetDefaultSeoPromptId(settings["seoAutomationMode"], settings["seoSubmodeId"])
    ValidateBotzPromptSettings(settings)
    return settings
}

