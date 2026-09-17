ValidateSeoAutomationMode() {
    global SeoAutomationMode, SeoPromptId
    mode := GetSeoAutomationMode()

    if !IsValidSeoAutomationMode(mode) {
        throw Error("Invalid SeoAutomationMode: " SeoAutomationMode ". Use 'full', 'department', 'metadata', 'image', 'matrix_image', 'matrix_full', 'botz', 'figuredart', 'promotion_text' or 'promotion_text_reference'.")
    }
    if !IsValidSeoPromptForMode(mode, GetSeoPromptId())
        throw Error("Invalid SEO prompt '" SeoPromptId "' for mode '" mode "'. Prompt choices cannot be shared across modes.")
}

GetSeoAutomationModeOptions() {
    return ["full", "department", "metadata", "image", "matrix_image", "matrix_full", "botz", "figuredart", "promotion_text", "promotion_text_reference"]
}

IsValidSeoAutomationMode(mode) {
    normalisedMode := StrLower(Trim(mode))
    for _, validMode in GetSeoAutomationModeOptions() {
        if normalisedMode = validMode
            return true
    }
    return false
}

GetSeoAutomationModeOptionIndex(mode) {
    normalisedMode := StrLower(Trim(mode))
    for index, validMode in GetSeoAutomationModeOptions() {
        if normalisedMode = validMode
            return index
    }
    return 1
}

GetSeoAutomationMode() {
    global SeoAutomationMode
    return StrLower(Trim(SeoAutomationMode))
}

GetSeoPromptId() {
    global SeoPromptId
    return StrLower(Trim(SeoPromptId))
}

GetSeoPromptOptionsForMode(mode) {
    global FullPromptTemplatePath, FullToolsPromptTemplatePath
    global DepartmentPromptTemplatePath, MetadataPromptTemplatePath, ImageOnlyPromptTemplatePath
    global MatrixImagePromptTemplatePath, MatrixFullPromptTemplatePath
    global BotzPromptTemplatePath, FiguredArtDefaultPromptTemplatePath

    mode := StrLower(Trim(mode))
    switch mode {
        case "full":
            return [
                Map("id", "full_standard", "label", "Standard full product", "path", FullPromptTemplatePath),
                Map("id", "full_tools_products", "label", "Tools product optimisation", "path", FullToolsPromptTemplatePath)
            ]
        case "department":
            return [Map("id", "department_standard", "label", "Standard department", "path", DepartmentPromptTemplatePath)]
        case "metadata":
            return [Map("id", "metadata_standard", "label", "Standard metadata and images", "path", MetadataPromptTemplatePath)]
        case "image":
            return [Map("id", "image_standard", "label", "Standard image SEO", "path", ImageOnlyPromptTemplatePath)]
        case "matrix_image":
            return [Map("id", "matrix_image_standard", "label", "Standard matrix image SEO", "path", MatrixImagePromptTemplatePath)]
        case "matrix_full":
            return [Map("id", "matrix_full_standard", "label", "Standard matrix full", "path", MatrixFullPromptTemplatePath)]
        case "botz":
            return [Map("id", "botz_engobes", "label", "BOTZ engobes", "path", BotzPromptTemplatePath)]
        case "figuredart":
            return [Map("id", "figuredart_standard", "label", "Figured'Art product creation", "path", FiguredArtDefaultPromptTemplatePath)]
        case "promotion_text", "promotion_text_reference":
            return []
    }
    return []
}

GetDefaultSeoPromptId(mode) {
    options := GetSeoPromptOptionsForMode(mode)
    return options.Length ? options[1]["id"] : ""
}

GetSeoPromptOption(mode, promptId) {
    promptId := StrLower(Trim(promptId))
    for _, option in GetSeoPromptOptionsForMode(mode) {
        if option["id"] = promptId
            return option
    }
    return 0
}

IsValidSeoPromptForMode(mode, promptId) {
    options := GetSeoPromptOptionsForMode(mode)
    if options.Length = 0
        return Trim(promptId) = ""
    return IsObject(GetSeoPromptOption(mode, promptId))
}

GetSeoPromptLabelsForMode(mode) {
    labels := []
    for _, option in GetSeoPromptOptionsForMode(mode)
        labels.Push(option["label"])
    return labels
}

GetSeoPromptOptionIndex(mode, promptId) {
    promptId := StrLower(Trim(promptId))
    for index, option in GetSeoPromptOptionsForMode(mode) {
        if option["id"] = promptId
            return index
    }
    return 1
}

GetSeoPromptIdFromOptionIndex(mode, optionIndex) {
    options := GetSeoPromptOptionsForMode(mode)
    if optionIndex < 1 || optionIndex > options.Length
        return ""
    return options[optionIndex]["id"]
}

GetSeoPromptLabel(mode, promptId) {
    option := GetSeoPromptOption(mode, promptId)
    return IsObject(option) ? option["label"] : "Not used by this mode"
}

GetPromptTemplatePath() {
    ValidateSeoAutomationMode()
    option := GetSeoPromptOption(GetSeoAutomationMode(), GetSeoPromptId())
    if !IsObject(option) || option["path"] = ""
        throw Error("Mode '" GetSeoAutomationMode() "' does not have a usable prompt template selected.")
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
    return GetSeoAutomationMode() = "botz"
}

IsFiguredArtMode() {
    return GetSeoAutomationMode() = "figuredart"
}

IsPromotionTextMode() {
    return GetSeoAutomationMode() = "promotion_text"
}

IsPromotionTextReferenceMode() {
    return GetSeoAutomationMode() = "promotion_text_reference"
}

IsAnyPromotionTextMode() {
    return IsPromotionTextMode() || IsPromotionTextReferenceMode()
}

IsSupplierProductCreationMode() {
    return IsBotzMode() || IsFiguredArtMode()
}

IsAnyMatrixMode() {
    return IsMatrixImageMode() || IsMatrixFullMode()
}

GetDepartmentProductTypeForSeoMode(mode := "") {
    mode := mode != "" ? StrLower(Trim(mode)) : GetSeoAutomationMode()
    if !IsValidSeoAutomationMode(mode)
        throw Error("Cannot choose a department product type for invalid SEO mode '" mode "'.")
    return mode = "matrix_image" || mode = "matrix_full"
        ? "Matrix Product"
        : "Simple Product"
}

