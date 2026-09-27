ParseAutomationOutput(block, imageCount, metadataOnly := false) {
    hasImageNames := imageCount > 0 && InStr(block, "IMAGE_1_NAME:")
    firstImageLabel := imageCount > 0 ? "IMAGE_1_" (hasImageNames ? "NAME:" : "TITLE:") : ""
    productNameRecommendation := ExtractLabel(block, "PRODUCT_NAME_RECOMMENDATION:", "META_TITLE:")
    metaTitle := ExtractLabel(block, "META_TITLE:", "META_DESCRIPTION:")

    if metadataOnly {
        metaDescription := ExtractLabel(block, "META_DESCRIPTION:", firstImageLabel)
        htmlSnippet := ""
    } else {
        metaDescription := ExtractLabel(block, "META_DESCRIPTION:", "HTML_SNIPPET:")
        htmlSnippet := ExtractLabel(block, "HTML_SNIPPET:", firstImageLabel)
        htmlSnippet := StripCodeFence(htmlSnippet)
    }

    imageNames := []
    imageTitles := []
    imageAlts := []

    Loop imageCount {
        i := A_Index
        nextImageLabel := i < imageCount ? "IMAGE_" (i + 1) (hasImageNames ? "_NAME:" : "_TITLE:") : ""

        if hasImageNames
            imageNames.Push(ExtractLabel(block, "IMAGE_" i "_NAME:", "IMAGE_" i "_TITLE:"))

        imageTitles.Push(ExtractLabel(block, "IMAGE_" i "_TITLE:", "IMAGE_" i "_ALT:"))
        imageAlts.Push(ExtractLabel(block, "IMAGE_" i "_ALT:", nextImageLabel))
    }

    return Map(
        "productNameRecommendation", productNameRecommendation,
        "metaTitle", metaTitle,
        "metaDescription", metaDescription,
        "htmlSnippet", htmlSnippet,
        "imageNames", imageNames,
        "imageTitles", imageTitles,
        "imageAlts", imageAlts
    )
}

ExtractBetween(text, startMarker, endMarker) {
    startPos := InStr(text, startMarker)

    if !startPos
        return ""

    startPos += StrLen(startMarker)

    endPos := InStr(text, endMarker, , startPos)

    if !endPos
        return ""

    return Trim(SubStr(text, startPos, endPos - startPos), " `t`r`n")
}

ExtractLabel(block, startLabel, endLabel := "") {
    startPos := InStr(block, startLabel)

    if !startPos
        return ""

    startPos += StrLen(startLabel)

    if endLabel != "" {
        endPos := InStr(block, endLabel, , startPos)

        if !endPos
            return Trim(SubStr(block, startPos), " `t`r`n")

        return Trim(SubStr(block, startPos, endPos - startPos), " `t`r`n")
    }

    return Trim(SubStr(block, startPos), " `t`r`n")
}

ExtractValidatedAutomationBlock(response) {
    startMarker := "===AUTOMATION_OUTPUT_START==="
    endMarker := "===AUTOMATION_OUTPUT_END==="
    if CountTextOccurrences(response, startMarker) != 1 || CountTextOccurrences(response, endMarker) != 1
        throw Error("The ChatGPT response must contain exactly one complete automation-output marker pair.")
    if InStr(response, endMarker) <= InStr(response, startMarker)
        throw Error("The automation-output markers are in the wrong order.")
    block := ExtractBetween(response, startMarker, endMarker)
    if block = ""
        throw Error("The automation-output block is empty.")
    return block
}

CountTextOccurrences(text, needle) {
    count := 0, position := 1
    while position := InStr(text, needle, , position) {
        count += 1
        position += StrLen(needle)
    }
    return count
}

ParseSupplierProductAutomationOutput(block, state, profile := 0) {
    if !IsObject(profile)
        profile := GetSupplierProductProfile(state["submode"])
    supplierName := profile["displayName"]
    expected := ["MODE", "PRODUCT_NAME", "IMAGE_COUNT", "PRODUCT_NAME_RECOMMENDATION", "META_TITLE", "META_DESCRIPTION", "HTML_SNIPPET"]
    Loop state["imageCount"] {
        expected.Push("IMAGE_" A_Index "_NAME")
        expected.Push("IMAGE_" A_Index "_TITLE")
        expected.Push("IMAGE_" A_Index "_ALT")
    }
    fields := ParseOrderedAutomationFields(block, expected)

    mode := ValidateMatrixFullOneLine(fields["MODE"], supplierName " mode")
    if mode != profile["outputMode"]
        throw Error(supplierName " output MODE must be " profile["outputMode"] ".")
    echoedName := ValidateMatrixFullOneLine(fields["PRODUCT_NAME"], supplierName " product name")
    if NormaliseHarmlessWhitespace(echoedName) != NormaliseHarmlessWhitespace(state["productName"])
        throw Error("The " supplierName " output product name does not match the saved GO b2b product name.")
    if !IsInteger(fields["IMAGE_COUNT"]) || Integer(fields["IMAGE_COUNT"]) != state["imageCount"]
        throw Error("The " supplierName " output image count does not match the current supplier image folder.")

    recommendation := ValidateMatrixFullOneLine(fields["PRODUCT_NAME_RECOMMENDATION"], "Product name recommendation")
    metaTitle := ValidateMatrixFullOneLine(fields["META_TITLE"], "Meta title")
    metaDescription := ValidateMatrixFullOneLine(fields["META_DESCRIPTION"], "Meta description")
    htmlSnippet := StripCodeFence(fields["HTML_SNIPPET"])
    ValidateSupplierProductHtml(htmlSnippet, supplierName)

    imageNames := [], imageTitles := [], imageAlts := []
    Loop state["imageCount"] {
        i := A_Index
        imageName := ValidateCmsImageName(fields["IMAGE_" i "_NAME"], i)
        imageTitle := ValidateImageOutputValue(fields["IMAGE_" i "_TITLE"], "Image " i " title")
        imageAlt := ValidateImageOutputValue(fields["IMAGE_" i "_ALT"], "Image " i " alt text")
        if NormaliseHarmlessWhitespace(imageName) = NormaliseHarmlessWhitespace(imageTitle) || NormaliseHarmlessWhitespace(imageName) = NormaliseHarmlessWhitespace(imageAlt)
            throw Error("Image " i " Name must be distinct from its Title and Alt text.")
        if NormaliseHarmlessWhitespace(imageTitle) = NormaliseHarmlessWhitespace(imageAlt)
            throw Error("Image " i " Title and Alt text are identical.")
        imageNames.Push(imageName), imageTitles.Push(imageTitle), imageAlts.Push(imageAlt)
    }

    warnings := ValidateGeneratedFields(metaTitle, metaDescription, htmlSnippet, imageTitles, imageAlts, true)
    if warnings != ""
        throw Error(supplierName " generated-field validation failed:`n" warnings)

    return Map(
        "mode", mode,
        "productName", echoedName,
        "productNameRecommendation", recommendation,
        "metaTitle", metaTitle,
        "metaDescription", metaDescription,
        "htmlSnippet", htmlSnippet,
        "imageNames", imageNames,
        "imageTitles", imageTitles,
        "imageAlts", imageAlts
    )
}

ParseBotzAutomationOutput(block, state) {
    return ParseSupplierProductAutomationOutput(block, state, GetSupplierProductProfile("botz"))
}

ParseOrderedAutomationFields(block, expectedLabels) {
    text := StrReplace(block, "`r", "")
    allowed := Map(), fields := Map(), locations := []
    for _, label in expectedLabels
        allowed[label] := true

    position := 1
    while found := RegExMatch(text, "m)^([A-Z][A-Z0-9_]*):[ `t]*$", &match, position) {
        label := match[1]
        if !allowed.Has(label)
            throw Error("Unexpected automation label: " label ".")
        position := found + StrLen(match[0])
    }

    searchFrom := 1
    for _, label in expectedLabels {
        pattern := "m)^" label ":[ `t]*$"
        found := RegExMatch(text, pattern, &match, searchFrom)
        if !found
            throw Error("Missing or out-of-order automation field: " label ".")
        duplicate := RegExMatch(text, pattern, , found + StrLen(match[0]))
        if duplicate
            throw Error("Duplicate automation label: " label ".")
        locations.Push(Map("label", label, "labelStart", found, "valueStart", found + StrLen(match[0])))
        searchFrom := found + StrLen(match[0])
    }
    if Trim(SubStr(text, 1, locations[1]["labelStart"] - 1), " `t`n") != ""
        throw Error("Unexpected text appears before the first product-creation automation field.")

    Loop locations.Length {
        item := locations[A_Index]
        valueEnd := A_Index < locations.Length ? locations[A_Index + 1]["labelStart"] : StrLen(text) + 1
        fields[item["label"]] := Trim(SubStr(text, item["valueStart"], valueEnd - item["valueStart"]), " `t`n")
    }
    return fields
}

BuildBotzParsedOutputLog(output) {
    text := "Mode: " output["mode"]
    text .= "`nProduct name: " output["productName"]
    text .= "`nRecommendation: " output["productNameRecommendation"]
    text .= "`nMeta title: " output["metaTitle"]
    text .= "`nMeta description: " output["metaDescription"]
    text .= "`nHTML snippet:`n" output["htmlSnippet"]
    Loop output["imageNames"].Length {
        i := A_Index
        text .= "`nImage " i " Name: " output["imageNames"][i]
        text .= "`nImage " i " Title: " output["imageTitles"][i]
        text .= "`nImage " i " Alt: " output["imageAlts"][i]
    }
    return text
}

ParseImageOnlyOutput(block, imageCount) {
    expected := ["MODE", "IMAGE_COUNT"]
    Loop imageCount {
        expected.Push("IMAGE_" A_Index "_NAME")
        expected.Push("IMAGE_" A_Index "_TITLE")
        expected.Push("IMAGE_" A_Index "_ALT")
    }
    fields := ParseExactLineFields(block, expected)
    if fields["MODE"] != "IMAGE_ONLY"
        throw Error("Image output MODE must be IMAGE_ONLY.")
    if !IsInteger(fields["IMAGE_COUNT"]) || Integer(fields["IMAGE_COUNT"]) != imageCount
        throw Error("Image output count does not match imageCountToProcess (" imageCount ").")
    names := [], titles := [], alts := []
    Loop imageCount {
        name := ValidateCmsImageName(fields["IMAGE_" A_Index "_NAME"], A_Index)
        title := ValidateImageOutputValue(fields["IMAGE_" A_Index "_TITLE"], "Image " A_Index " title")
        alt := ValidateImageOutputValue(fields["IMAGE_" A_Index "_ALT"], "Image " A_Index " alt")
        if NormaliseHarmlessWhitespace(name) = NormaliseHarmlessWhitespace(title) || NormaliseHarmlessWhitespace(name) = NormaliseHarmlessWhitespace(alt)
            throw Error("Image " A_Index " Name must be distinct from its Title and Alt text.")
        if NormaliseHarmlessWhitespace(title) = NormaliseHarmlessWhitespace(alt)
            throw Error("Image " A_Index " title and alt text are identical.")
        names.Push(name), titles.Push(title), alts.Push(alt)
    }
    return Map("productNameRecommendation", "", "metaTitle", "", "metaDescription", "", "htmlSnippet", "", "imageNames", names, "imageTitles", titles, "imageAlts", alts)
}

ParseExactLineFields(block, expectedLabels) {
    allowed := Map()
    for _, label in expectedLabels
        allowed[label] := true
    fields := Map(), pending := ""
    for _, rawLine in StrSplit(StrReplace(block, "`r", ""), "`n") {
        line := Trim(rawLine, " `t")
        if line = ""
            continue
        if RegExMatch(line, "^([A-Z][A-Z0-9_]*):$", &match) {
            label := match[1]
            if !allowed.Has(label)
                throw Error("Unexpected automation label: " label ".")
            if fields.Has(label) || pending != ""
                throw Error(pending != "" ? "Missing value for " pending "." : "Duplicate automation label: " label ".")
            pending := label
            continue
        }
        if pending = ""
            throw Error("Unexpected text in automation block: " line)
        fields[pending] := line
        pending := ""
    }
    if pending != ""
        throw Error("Missing value for " pending ".")
    for _, label in expectedLabels {
        if !fields.Has(label)
            throw Error("Missing automation field: " label ".")
    }
    return fields
}

ParseMatrixImageOutput(block, state) {
    productCount := state["productCount"], parentImageCount := state["parentImageCount"]
    expected := ["MODE", "PRODUCT_COUNT", "PARENT_IMAGE_COUNT", "TOTAL_IMAGE_COUNT"]
    Loop parentImageCount {
        expected.Push("PARENT_IMAGE_" A_Index "_TITLE")
        expected.Push("PARENT_IMAGE_" A_Index "_ALT")
    }
    Loop productCount {
        p := A_Index
        expected.Push("PRODUCT_" p "_NAME")
        expected.Push("PRODUCT_" p "_IMAGE_COUNT")
        Loop state["products"][p]["imageCount"] {
            expected.Push("PRODUCT_" p "_IMAGE_" A_Index "_TITLE")
            expected.Push("PRODUCT_" p "_IMAGE_" A_Index "_ALT")
        }
    }
    fields := ParseExactLineFields(block, expected)
    if fields["MODE"] != "MATRIX_IMAGE"
        throw Error("Matrix output MODE must be MATRIX_IMAGE.")
    if !IsInteger(fields["PRODUCT_COUNT"]) || Integer(fields["PRODUCT_COUNT"]) != productCount
        throw Error("Matrix product count does not match the saved prompt state.")
    if !IsInteger(fields["PARENT_IMAGE_COUNT"]) || Integer(fields["PARENT_IMAGE_COUNT"]) != parentImageCount
        throw Error("Parent image count does not match the saved prompt state.")
    if !IsInteger(fields["TOTAL_IMAGE_COUNT"]) || Integer(fields["TOTAL_IMAGE_COUNT"]) != GetMatrixTotalImageCount(state)
        throw Error("Total image count does not match the saved prompt state.")
    parentTitles := [], parentAlts := []
    Loop parentImageCount {
        i := A_Index
        title := ValidateImageOutputValue(fields["PARENT_IMAGE_" i "_TITLE"], "Parent image " i " title")
        alt := ValidateImageOutputValue(fields["PARENT_IMAGE_" i "_ALT"], "Parent image " i " alt")
        if NormaliseHarmlessWhitespace(title) = NormaliseHarmlessWhitespace(alt)
            throw Error("Parent image " i " title and alt text are identical.")
        parentTitles.Push(title), parentAlts.Push(alt)
    }
    products := []
    Loop productCount {
        p := A_Index
        imageCount := state["products"][p]["imageCount"]
        echoedName := fields["PRODUCT_" p "_NAME"]
        if NormaliseHarmlessWhitespace(echoedName) != NormaliseHarmlessWhitespace(state["products"][p]["productName"])
            throw Error("Product " p " name does not match the saved matrix order.")
        if !IsInteger(fields["PRODUCT_" p "_IMAGE_COUNT"]) || Integer(fields["PRODUCT_" p "_IMAGE_COUNT"]) != imageCount
            throw Error("Product " p " image count does not match the saved prompt state.")
        titles := [], alts := []
        Loop imageCount {
            i := A_Index
            title := ValidateImageOutputValue(fields["PRODUCT_" p "_IMAGE_" i "_TITLE"], "Product " p ", image " i " title")
            alt := ValidateImageOutputValue(fields["PRODUCT_" p "_IMAGE_" i "_ALT"], "Product " p ", image " i " alt")
            if StrLower(title) = StrLower(alt)
                throw Error("Product " p ", image " i " title and alt text are identical.")
            titles.Push(title), alts.Push(alt)
        }
        products.Push(Map("productName", echoedName, "imageTitles", titles, "imageAlts", alts))
    }
    return Map("mode", "MATRIX_IMAGE", "productCount", productCount, "parentImageTitles", parentTitles, "parentImageAlts", parentAlts, "products", products)
}

ParseMatrixFullOutput(block, state) {
    productCount := state["productCount"], parentImageCount := state["parentImageCount"]
    expected := ["MODE", "PRODUCT_COUNT", "PARENT_IMAGE_COUNT", "TOTAL_IMAGE_COUNT", "PARENT_PRODUCT_NAME_RECOMMENDATION", "PARENT_META_TITLE", "PARENT_META_DESCRIPTION"]
    Loop parentImageCount {
        expected.Push("PARENT_IMAGE_" A_Index "_TITLE")
        expected.Push("PARENT_IMAGE_" A_Index "_ALT")
    }
    Loop productCount {
        p := A_Index
        expected.Push("PRODUCT_" p "_NAME")
        expected.Push("PRODUCT_" p "_IMAGE_COUNT")
        expected.Push("PRODUCT_" p "_HTML_SNIPPET")
        Loop state["products"][p]["imageCount"] {
            expected.Push("PRODUCT_" p "_IMAGE_" A_Index "_TITLE")
            expected.Push("PRODUCT_" p "_IMAGE_" A_Index "_ALT")
        }
    }

    ; Validate the complete label sequence first. This rejects duplicates,
    ; missing fields, unexpected products and fields outside the saved matrix.
    labels := []
    pos := 1
    while RegExMatch(block, "m)^\s*([A-Z][A-Z0-9_]*):\s*$", &match, pos) {
        labels.Push(match[1])
        pos := match.Pos(0) + match.Len(0)
    }
    if labels.Length != expected.Length
        throw Error("Matrix-full output contains " labels.Length " fields; expected " expected.Length ".")
    Loop expected.Length {
        if labels[A_Index] != expected[A_Index]
            throw Error("Matrix-full field " A_Index " must be " expected[A_Index] ", but found " labels[A_Index] ".")
    }

    fields := Map()
    Loop expected.Length {
        label := expected[A_Index]
        startNeedle := label ":"
        startPos := InStr(block, startNeedle)
        startPos += StrLen(startNeedle)
        if A_Index < expected.Length {
            nextPos := InStr(block, expected[A_Index + 1] ":", , startPos)
            value := SubStr(block, startPos, nextPos - startPos)
        } else
            value := SubStr(block, startPos)
        fields[label] := Trim(value, " `t`r`n")
    }

    if fields["MODE"] != "MATRIX_FULL"
        throw Error("Matrix-full output MODE must be MATRIX_FULL.")
    if !IsInteger(fields["PRODUCT_COUNT"]) || Integer(fields["PRODUCT_COUNT"]) != productCount
        throw Error("Matrix-full product count does not match the saved prompt state.")
    if !IsInteger(fields["PARENT_IMAGE_COUNT"]) || Integer(fields["PARENT_IMAGE_COUNT"]) != parentImageCount
        throw Error("Matrix-full parent image count does not match the saved prompt state.")
    if !IsInteger(fields["TOTAL_IMAGE_COUNT"]) || Integer(fields["TOTAL_IMAGE_COUNT"]) != GetMatrixTotalImageCount(state)
        throw Error("Matrix-full total image count does not match the saved prompt state.")

    parentRecommendation := ValidateMatrixFullOneLine(fields["PARENT_PRODUCT_NAME_RECOMMENDATION"], "Parent product-name recommendation", false)
    parentTitle := ValidateMatrixFullOneLine(fields["PARENT_META_TITLE"], "Parent meta title")
    parentDescription := ValidateMatrixFullOneLine(fields["PARENT_META_DESCRIPTION"], "Parent meta description")
    parentTitles := [], parentAlts := []
    Loop parentImageCount {
        i := A_Index
        title := ValidateImageOutputValue(fields["PARENT_IMAGE_" i "_TITLE"], "Parent image " i " title")
        alt := ValidateImageOutputValue(fields["PARENT_IMAGE_" i "_ALT"], "Parent image " i " alt")
        if NormaliseHarmlessWhitespace(title) = NormaliseHarmlessWhitespace(alt)
            throw Error("Parent image " i " title and alt text are identical.")
        parentTitles.Push(title), parentAlts.Push(alt)
    }
    products := []
    Loop productCount {
        p := A_Index
        imageCount := state["products"][p]["imageCount"]
        echoedName := ValidateMatrixFullOneLine(fields["PRODUCT_" p "_NAME"], "Product " p " name")
        if NormaliseHarmlessWhitespace(echoedName) != NormaliseHarmlessWhitespace(state["products"][p]["productName"])
            throw Error("Product " p " name does not match saved child '" state["products"][p]["productName"] "'.")
        if !IsInteger(fields["PRODUCT_" p "_IMAGE_COUNT"]) || Integer(fields["PRODUCT_" p "_IMAGE_COUNT"]) != imageCount
            throw Error("Product " p " image count does not match the saved prompt state.")
        html := StripCodeFence(fields["PRODUCT_" p "_HTML_SNIPPET"])
        ValidateMatrixFullHtml(html, p)
        titles := [], alts := []
        Loop imageCount {
            i := A_Index
            title := ValidateImageOutputValue(fields["PRODUCT_" p "_IMAGE_" i "_TITLE"], "Product " p ", image " i " title")
            alt := ValidateImageOutputValue(fields["PRODUCT_" p "_IMAGE_" i "_ALT"], "Product " p ", image " i " alt")
            if NormaliseHarmlessWhitespace(title) = NormaliseHarmlessWhitespace(alt)
                throw Error("Product " p ", image " i " title and alt text are identical.")
            titles.Push(title), alts.Push(alt)
        }
        products.Push(Map("productName", echoedName, "htmlSnippet", html, "imageTitles", titles, "imageAlts", alts))
    }
    return Map("mode", "MATRIX_FULL", "productCount", productCount, "parentProductNameRecommendation", parentRecommendation, "parentMetaTitle", parentTitle, "parentMetaDescription", parentDescription, "parentImageTitles", parentTitles, "parentImageAlts", parentAlts, "products", products)
}

