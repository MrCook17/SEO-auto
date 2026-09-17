DeriveVariantContext(productName, rowText) {
    rowText := Trim(RegExReplace(rowText, "i)Editing Matrix Product:|\bEdit\b", ""))
    return rowText = "" ? "Not separately available; see product name" : rowText
}

IsPlausibleConnectedSkuSize(value) {
    value := Trim(value)
    if value = "" || RegExMatch(value, "i)^(Size|Name|Edit|Remove|Skus?)\s*:?\s*$")
        return false
    ; Connected values are commonly capacities/dimensions, but retain other
    ; concise matrix variants (such as named sizes) when they occupy the
    ; verified left-hand cell.
    return StrLen(value) <= 80 && !RegExMatch(value, "i)\bStock\s*Code\b|\bStockCode\b")
}

CountMatrixSkuIdentities(text) {
    count := 0, pos := 1
    while RegExMatch(text, "i)\b(?:Stock\s*Code|StockCode)\s*:", &match, pos) {
        count += 1
        pos := match.Pos(0) + match.Len(0)
    }
    return count
}

GetMatrixSkuRowKey(rowText) {
    text := NormaliseMatrixRowText(rowText)
    if RegExMatch(text, "i)\bStock\s*Code\s*:\s*([^ ]+)", &match)
        return "stock:" StrLower(match[1])
    if RegExMatch(text, "i)\bName\s*:?\s*(.+?)(?=\s+Stock\s*Code|\s+StockCode|$)", &match)
        return "name:" NormaliseHarmlessWhitespace(match[1])
    return ""
}

ExtractMatrixProductNameFromRow(rowText, productIndex) {
    text := NormaliseMatrixRowText(rowText)
    if RegExMatch(text, "i)\bName\s*:?\s*(.+?)(?=\s+Stock\s*Code\s*:|\s+StockCode\s*:|\s+Edit\b|\s+Remove\b|$)", &match) {
        name := Trim(match[1])
        if name != ""
            return name
    }
    throw Error("Could not extract the exact product name from accessibility row " productIndex ".`n`nRow text: " rowText "`n`nPress F8 to inspect the detected rows.")
}

ExtractConnectedMatrixSkuSize(rowText) {
    text := NormaliseMatrixRowText(rowText)
    ; A connected value is exposed before the row's Name field, for example:
    ; "236ml (8oz) Name Electric Celadon Green ... StockCode: C626SM".
    if RegExMatch(text, "i)^(.+?)(?=\s+Name\s*:?)", &match) {
        size := Trim(match[1])
        size := Trim(RegExReplace(size, "i)^(Size)\s*:?\s*", ""))
        if size != ""
            return size
    }
    return "Not separately exposed in the SKU accessibility row"
}

ExtractMatrixVariantFromRow(rowText, productName) {
    text := NormaliseMatrixRowText(rowText)
    if RegExMatch(text, "i)^(.+?)(?=\s+Name\s*:)", &match) {
        variant := Trim(RegExReplace(match[1], "i)^(Size|Colour|Color|Variant)\s*:?\s*", ""))
        if variant != ""
            return variant
    }
    ; Many GO b2b rows expose the size only inside the product name, for
    ; example: OG Square - 11" (11x11x.75 inch).
    if RegExMatch(productName, "-\s*(.+?)(?=\s*\()", &nameMatch) {
        variant := Trim(nameMatch[1])
        ; Ignore an occasional stray accessibility digit after a quoted size.
        variant := RegExReplace(variant, "^(.+?[\x22'])\s+\d+$", "$1")
        if variant != ""
            return variant
    }
    return "Not separately available; see product name"
}

NormaliseMatrixRowText(rowText) {
    ; Remove Chrome's private-use icon glyphs and trailing button labels while
    ; preserving the product name, size and stock code text.
    text := RegExReplace(rowText, "[\x{E000}-\x{F8FF}]", " ")
    text := RegExReplace(text, "i)\s+Edit\s+Remove\s*$", "")
    return RegExReplace(Trim(text), "[\r\n\t ]+", " ")
}

