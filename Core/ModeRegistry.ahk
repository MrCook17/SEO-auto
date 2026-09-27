ValidateSeoAutomationMode() {
    global SeoAutomationMode, SeoSubmodeId, SeoPromptId
    mode := GetSeoAutomationMode()
    submodeId := GetSeoSubmodeId()

    if !IsValidSeoAutomationMode(mode) {
        throw Error("Invalid SeoAutomationMode: " SeoAutomationMode ". Use 'full', 'department', 'metadata', 'image', 'matrix_image', 'matrix_full', 'supplier_product', 'promotion_text', 'promotion_text_reference' or 'display_on_website_app'.")
    }
    if !IsValidSeoSubmodeForMode(mode, submodeId)
        throw Error("Invalid SEO submode '" SeoSubmodeId "' for mode '" mode "'.")
    if !IsValidSeoPromptForSubmode(mode, submodeId, GetSeoPromptId())
        throw Error("Invalid SEO prompt '" SeoPromptId "' for mode '" mode "' and submode '" submodeId "'. Prompt choices cannot be shared across submodes.")
}

GetSeoAutomationModeOptions() {
    return ["full", "department", "metadata", "image", "matrix_image", "matrix_full", "supplier_product", "promotion_text", "promotion_text_reference", "display_on_website_app"]
}

NormaliseSeoAutomationMode(mode) {
    normalisedMode := StrLower(Trim(mode))
    ; Settings saved before submodes existed used BOTZ as the mode itself.
    return normalisedMode = "botz" ? "supplier_product" : normalisedMode
}

IsValidSeoAutomationMode(mode) {
    normalisedMode := NormaliseSeoAutomationMode(mode)
    for _, validMode in GetSeoAutomationModeOptions() {
        if normalisedMode = validMode
            return true
    }
    return false
}

GetSeoAutomationModeOptionIndex(mode) {
    normalisedMode := NormaliseSeoAutomationMode(mode)
    for index, validMode in GetSeoAutomationModeOptions() {
        if normalisedMode = validMode
            return index
    }
    return 1
}

GetSeoAutomationMode() {
    global SeoAutomationMode
    return NormaliseSeoAutomationMode(SeoAutomationMode)
}

GetSeoSubmodeId() {
    global SeoSubmodeId
    return StrLower(Trim(SeoSubmodeId))
}

GetSeoPromptId() {
    global SeoPromptId
    return StrLower(Trim(SeoPromptId))
}

GetSeoSubmodeOptionsForMode(mode) {
    mode := NormaliseSeoAutomationMode(mode)
    if mode = "supplier_product" {
        return [
            Map("id", "botz", "label", "BOTZ Engobes"),
            Map("id", "crystal_art", "label", "Crystal Art")
        ]
    }
    if IsValidSeoAutomationMode(mode)
        return [Map("id", "default", "label", "Default")]
    return []
}

GetDefaultSeoSubmodeId(mode) {
    options := GetSeoSubmodeOptionsForMode(mode)
    return options.Length ? options[1]["id"] : ""
}

GetSeoSubmodeOption(mode, submodeId) {
    submodeId := StrLower(Trim(submodeId))
    for _, option in GetSeoSubmodeOptionsForMode(mode) {
        if option["id"] = submodeId
            return option
    }
    return 0
}

IsValidSeoSubmodeForMode(mode, submodeId) {
    return IsObject(GetSeoSubmodeOption(mode, submodeId))
}

GetSeoSubmodeLabelsForMode(mode) {
    labels := []
    for _, option in GetSeoSubmodeOptionsForMode(mode)
        labels.Push(option["label"])
    return labels
}

GetSeoSubmodeOptionIndex(mode, submodeId) {
    submodeId := StrLower(Trim(submodeId))
    for index, option in GetSeoSubmodeOptionsForMode(mode) {
        if option["id"] = submodeId
            return index
    }
    return 1
}

GetSeoSubmodeIdFromOptionIndex(mode, optionIndex) {
    options := GetSeoSubmodeOptionsForMode(mode)
    if optionIndex < 1 || optionIndex > options.Length
        return ""
    return options[optionIndex]["id"]
}

GetSeoSubmodeLabel(mode, submodeId) {
    option := GetSeoSubmodeOption(mode, submodeId)
    return IsObject(option) ? option["label"] : "Not used by this mode"
}

GetSeoPromptOptionsForSubmode(mode, submodeId) {
    global FullPromptTemplatePath, FullToolsPromptTemplatePath
    global DepartmentPromptTemplatePath, MetadataPromptTemplatePath, ImageOnlyPromptTemplatePath
    global MatrixImagePromptTemplatePath, MatrixFullPromptTemplatePath
    global BotzPromptTemplatePath, CrystalArtPromptTemplatePath

    mode := NormaliseSeoAutomationMode(mode)
    submodeId := StrLower(Trim(submodeId))
    switch mode {
        case "full":
            return submodeId = "default" ? [
                Map("id", "full_standard", "label", "Standard full product", "path", FullPromptTemplatePath),
                Map("id", "full_tools_products", "label", "Tools product optimisation", "path", FullToolsPromptTemplatePath)
            ] : []
        case "department":
            return submodeId = "default" ? [Map("id", "department_standard", "label", "Standard department", "path", DepartmentPromptTemplatePath)] : []
        case "metadata":
            return submodeId = "default" ? [Map("id", "metadata_standard", "label", "Standard metadata and images", "path", MetadataPromptTemplatePath)] : []
        case "image":
            return submodeId = "default" ? [Map("id", "image_standard", "label", "Standard image SEO", "path", ImageOnlyPromptTemplatePath)] : []
        case "matrix_image":
            return submodeId = "default" ? [Map("id", "matrix_image_standard", "label", "Standard matrix image SEO", "path", MatrixImagePromptTemplatePath)] : []
        case "matrix_full":
            return submodeId = "default" ? [Map("id", "matrix_full_standard", "label", "Standard matrix full", "path", MatrixFullPromptTemplatePath)] : []
        case "supplier_product":
            switch submodeId {
                case "botz":
                    return [Map("id", "botz_engobes", "label", "BOTZ engobes", "path", BotzPromptTemplatePath)]
                case "crystal_art":
                    return [Map("id", "crystal_art_standard", "label", "Crystal Art product", "path", CrystalArtPromptTemplatePath)]
            }
        case "promotion_text", "promotion_text_reference", "display_on_website_app":
            return []
    }
    return []
}

GetSeoPromptOptionsForMode(mode) {
    submodeId := NormaliseSeoAutomationMode(mode) = GetSeoAutomationMode()
        ? GetSeoSubmodeId()
        : GetDefaultSeoSubmodeId(mode)
    return GetSeoPromptOptionsForSubmode(mode, submodeId)
}

GetDefaultSeoPromptId(mode, submodeId := "") {
    if submodeId = ""
        submodeId := GetDefaultSeoSubmodeId(mode)
    options := GetSeoPromptOptionsForSubmode(mode, submodeId)
    return options.Length ? options[1]["id"] : ""
}

GetSeoPromptOption(mode, submodeId, promptId := unset) {
    if !IsSet(promptId) {
        promptId := submodeId
        submodeId := GetDefaultSeoSubmodeId(mode)
    }
    promptId := StrLower(Trim(promptId))
    for _, option in GetSeoPromptOptionsForSubmode(mode, submodeId) {
        if option["id"] = promptId
            return option
    }
    return 0
}

IsValidSeoPromptForSubmode(mode, submodeId, promptId) {
    options := GetSeoPromptOptionsForSubmode(mode, submodeId)
    if options.Length = 0
        return Trim(promptId) = ""
    return IsObject(GetSeoPromptOption(mode, submodeId, promptId))
}

IsValidSeoPromptForMode(mode, promptId) {
    return IsValidSeoPromptForSubmode(mode, GetDefaultSeoSubmodeId(mode), promptId)
}

GetSeoPromptLabelsForSubmode(mode, submodeId) {
    labels := []
    for _, option in GetSeoPromptOptionsForSubmode(mode, submodeId)
        labels.Push(option["label"])
    return labels
}

GetSeoPromptLabelsForMode(mode) {
    return GetSeoPromptLabelsForSubmode(mode, GetDefaultSeoSubmodeId(mode))
}

GetSeoPromptOptionIndex(mode, submodeId, promptId := unset) {
    if !IsSet(promptId) {
        promptId := submodeId
        submodeId := GetDefaultSeoSubmodeId(mode)
    }
    promptId := StrLower(Trim(promptId))
    for index, option in GetSeoPromptOptionsForSubmode(mode, submodeId) {
        if option["id"] = promptId
            return index
    }
    return 1
}

GetSeoPromptIdFromOptionIndex(mode, submodeId, optionIndex := unset) {
    if !IsSet(optionIndex) {
        optionIndex := submodeId
        submodeId := GetDefaultSeoSubmodeId(mode)
    }
    options := GetSeoPromptOptionsForSubmode(mode, submodeId)
    if optionIndex < 1 || optionIndex > options.Length
        return ""
    return options[optionIndex]["id"]
}

GetSeoPromptLabel(mode, submodeId, promptId := unset) {
    if !IsSet(promptId) {
        promptId := submodeId
        submodeId := GetDefaultSeoSubmodeId(mode)
    }
    option := GetSeoPromptOption(mode, submodeId, promptId)
    return IsObject(option) ? option["label"] : "Not used by this submode"
}

GetPromptTemplatePath() {
    ValidateSeoAutomationMode()
    option := GetSeoPromptOption(GetSeoAutomationMode(), GetSeoSubmodeId(), GetSeoPromptId())
    if !IsObject(option) || option["path"] = ""
        throw Error("Mode '" GetSeoAutomationMode() "' and submode '" GetSeoSubmodeId() "' do not have a usable prompt template selected.")
    return option["path"]
}

IsFullMode() {
    return GetSeoAutomationMode() = "full"
}

IsDepartmentMode() {
    return GetSeoAutomationMode() = "department"
}

IsFullContentMode() {
    return IsFullMode() || IsDepartmentMode()
}

IsMetadataOnlyMode() {
    return GetSeoAutomationMode() = "metadata"
}

IsImageOnlyMode() {
    return GetSeoAutomationMode() = "image"
}

IsMatrixImageMode() {
    return GetSeoAutomationMode() = "matrix_image"
}

IsMatrixFullMode() {
    return GetSeoAutomationMode() = "matrix_full"
}

IsBotzMode() {
    return IsSupplierProductCreationMode() && GetSeoSubmodeId() = "botz"
}

IsCrystalArtMode() {
    return IsSupplierProductCreationMode() && GetSeoSubmodeId() = "crystal_art"
}

IsPromotionTextMode() {
    return GetSeoAutomationMode() = "promotion_text"
}

IsPromotionTextReferenceMode() {
    return GetSeoAutomationMode() = "promotion_text_reference"
}

IsDisplayOnWebsiteAppMode() {
    return GetSeoAutomationMode() = "display_on_website_app"
}

IsAnyPromotionTextMode() {
    return IsPromotionTextMode() || IsPromotionTextReferenceMode()
}

IsSupplierProductCreationMode() {
    return GetSeoAutomationMode() = "supplier_product"
}

IsAnyMatrixMode() {
    return IsMatrixImageMode() || IsMatrixFullMode()
}

GetDepartmentProductTypeForSeoMode(mode := "") {
    mode := mode != "" ? NormaliseSeoAutomationMode(mode) : GetSeoAutomationMode()
    if !IsValidSeoAutomationMode(mode)
        throw Error("Cannot choose a department product type for invalid SEO mode '" mode "'.")
    return mode = "matrix_image" || mode = "matrix_full"
        ? "Matrix Product"
        : "Simple Product"
}
