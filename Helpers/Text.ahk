StripCodeFence(text) {
    text := Trim(text, " `t`r`n")
    bt := Chr(96)

    ; Removes opening code fences copied from ChatGPT, including:
    ; ```html
    ; ``html
    ; ```
    ; ``
    ; and longer markdown fences.
    text := RegExReplace(text, "i)^\s*" bt "+\s*html\s*[\r\n]*", "")
    text := RegExReplace(text, "i)^\s*" bt "+\s*[\r\n]*", "")

    ; Removes trailing code fences, including malformed two-backtick endings.
    text := RegExReplace(text, "[\r\n\s]*" bt "+\s*$", "")

    return Trim(text, " `t`r`n")
}

CleanText(text) {
    return Trim(text, " `t`r`n")
}

EmptyToNA(text) {
    text := CleanText(text)
    return text = "" ? "N/A" : text
}

IsBotzHttpUrl(value) {
    return RegExMatch(value, "i)^https?://[^\s]+$")
}

NormaliseHarmlessWhitespace(value) {
    return StrLower(RegExReplace(Trim(value), "\s+", " "))
}

