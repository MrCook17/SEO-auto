ValidateGeneratedFields(metaTitle, metaDescription, htmlSnippet, imageTitles, imageAlts, requireHtmlSnippet := true) {
    warnings := ""

    if CleanText(metaTitle) = ""
        warnings .= "Meta title is empty.`n"

    if CleanText(metaDescription) = ""
        warnings .= "Meta description is empty.`n"

    if requireHtmlSnippet && CleanText(htmlSnippet) = ""
        warnings .= "HTML snippet is empty.`n"

    Loop imageTitles.Length {
        if CleanText(imageTitles[A_Index]) = ""
            warnings .= "Image " A_Index " title is empty.`n"

        if CleanText(imageAlts[A_Index]) = ""
            warnings .= "Image " A_Index " alt text is empty.`n"
    }

    if StrLen(metaTitle) > 65
        warnings .= "Meta title is over 65 characters.`n"

    if StrLen(metaDescription) > 170
        warnings .= "Meta description is over 170 characters.`n"

    if requireHtmlSnippet {
        if !InStr(htmlSnippet, "<")
            warnings .= "HTML snippet does not look like HTML.`n"

        if InStr(htmlSnippet, ":contentReference[") || InStr(htmlSnippet, "oaicite")
            warnings .= "HTML may contain citation/source-token text.`n"

        if InStr(htmlSnippet, "{{") || InStr(htmlSnippet, "}}")
            warnings .= "HTML may still contain placeholder text.`n"
    }

    return warnings
}

IsUsableProductNameRecommendation(productNameRecommendation) {
    name := CleanText(productNameRecommendation)

    if name = ""
        return false

    lowerName := StrLower(name)

    ; Do not paste explanatory/non-name recommendations into the CMS product name field.
    if lowerName = "n/a" || lowerName = "na"
        return false

    if InStr(lowerName, "keep current")
        return false

    if InStr(lowerName, "no change")
        return false

    if InStr(lowerName, "do not change")
        return false

    if InStr(lowerName, "current product name")
        return false

    return true
}

ValidateCmsImageName(value, imageIndex) {
    value := ValidateImageOutputValue(value, "Image " imageIndex " name")
    if InStr(value, "\") || InStr(value, "/") || RegExMatch(value, "i)\.(jpe?g|png|webp)$")
        throw Error("Image " imageIndex " Name looks like a file path or filename. It must be a clean CMS image name.")
    return value
}

ValidateBotzHtml(htmlSnippet) {
    if CleanText(htmlSnippet) = ""
        throw Error("BOTZ HTML snippet is empty.")
    if !InStr(htmlSnippet, "<")
        throw Error("BOTZ HTML snippet does not look like HTML.")
    if InStr(htmlSnippet, "{{") || InStr(htmlSnippet, "}}")
        throw Error("BOTZ HTML snippet contains placeholder text.")
    if RegExMatch(htmlSnippet, "i)(oaicite|contentReference|:source\[|\[citation)")
        throw Error("BOTZ HTML snippet contains citation/source-token text.")
    if InStr(htmlSnippet, Chr(96) Chr(96) Chr(96))
        throw Error("BOTZ HTML snippet still contains a code fence.")
}

ValidateImageOutputValue(value, fieldName) {
    value := Trim(value)
    if value = "" || RegExMatch(value, "i)^\[.*\]$") || InStr(value, "{{")
        throw Error(fieldName " is blank or contains a placeholder.")
    if InStr(value, "`n") || InStr(value, "`r")
        throw Error(fieldName " must be one line.")
    if RegExMatch(value, "i)(oaicite|contentReference|:source\[|\[citation)")
        throw Error(fieldName " contains citation/source-token text.")
    return value
}

ValidateMatrixFullOneLine(value, fieldName, requireValue := true) {
    value := Trim(value)
    if requireValue && value = ""
        throw Error(fieldName " is empty.")
    if InStr(value, "`n") || InStr(value, "`r")
        throw Error(fieldName " must be one line.")
    if RegExMatch(value, "i)^\s*\[.*\]\s*$") || InStr(value, "{{")
        throw Error(fieldName " contains placeholder text.")
    if RegExMatch(value, "i)(oaicite|contentReference|:source\[|\[citation)")
        throw Error(fieldName " contains citation/source-token text.")
    return value
}

ValidateMatrixFullHtml(html, productIndex) {
    if Trim(html) = ""
        throw Error("Product " productIndex " HTML snippet is empty.")
    if InStr(html, "{{") || RegExMatch(html, "i)\[(exact|complete|insert|one-line|placeholder)[^]]*\]")
        throw Error("Product " productIndex " HTML snippet contains placeholder text.")
    if RegExMatch(html, "i)(oaicite|contentReference|:source\[|\[citation)")
        throw Error("Product " productIndex " HTML snippet contains citation/source-token text.")
    if InStr(html, Chr(96) Chr(96) Chr(96))
        throw Error("Product " productIndex " HTML snippet still contains a code fence.")
}

