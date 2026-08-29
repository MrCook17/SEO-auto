#Requires AutoHotkey v2.0

global figuredArtRootDir := A_Temp "\cromartie-figuredart-mode-test-" A_TickCount
global figuredArtStateFilePath := figuredArtRootDir "\figuredart-product-state.txt"
global figuredArtState := 0
global maximumImagesPerProduct := 11
global cmsWinTitle := "Test CMS"
global FiguredArtPromptTemplatePath := A_ScriptDir "\..\prompts\prompt-template-figuredart.md"
global botzPromptSettings := CreateDefaultBotzPromptSettings()
global useRecommendedProductName := false
global lastSavedNonMatrixProductIdentity := 0
global botzFilePickerTimeoutMs := 100
global botzImagesTabLoadMs := 0
global botzImageDetailsLoadMs := 0

try {
    productCode := "SFA137-Y"
    productFolder := figuredArtRootDir "\" productCode " Santorini Sunrise"
    imagesDir := productFolder "\images"
    DirCreate imagesDir
    productMd := "# Product`n`nProduct Code: SFA137-Y`nName: Santorini Sunrise`nFinal Status: SUCCESS`n`n## Description`n`nA framed paint-by-numbers kit."
    productMdPath := productFolder "\product.md"
    FileAppend productMd, productMdPath, "UTF-8"
    Loop 12 {
        sequence := Format("{:02}", A_Index)
        FileAppend "image " sequence, imagesDir "\SFA137-Y_" sequence ".jpg", "UTF-8"
    }

    AssertEqual(NormaliseFiguredArtProductCode("sfa137-y"), productCode, "Product-code normalisation")
    AssertEqual(FindUniqueFiguredArtProductFolder(productCode), productFolder, "Exact folder matching")
    ValidateFiguredArtProductMarkdown(productMd, productCode, productMdPath)
    rejectedPartial := false
    try ValidateFiguredArtProductMarkdown(StrReplace(productMd, "SUCCESS", "PARTIAL"), productCode, productMdPath)
    catch
        rejectedPartial := true
    AssertTrue(rejectedPartial, "Non-success product.md must be rejected")

    attachmentImageFiles := EnumerateBotzImageFiles(imagesDir)
    AssertEqual(attachmentImageFiles.Length, 12, "ChatGPT attachment discovery")
    imageFiles := TakeFirstBotzImageFiles(attachmentImageFiles, maximumImagesPerProduct)
    AssertEqual(imageFiles.Length, 11, "Image discovery limit")
    AssertTrue(InStr(imageFiles[1], "_01.jpg") > 0, "Natural image order")
    AssertTrue(InStr(imageFiles[11], "_11.jpg") > 0, "First eleven image selection")
    promptSettings := CreateDefaultBotzPromptSettings()
    template := FileRead(A_ScriptDir "\..\prompts\prompt-template-figuredart.md", "UTF-8")
    prompt := BuildFiguredArtPromptFromSource(
        template,
        "https://www.cromartiehobbycraft.co.uk/example",
        "Santorini Sunrise",
        productMd,
        imageFiles,
        promptSettings,
        attachmentImageFiles
    )
    AssertTrue(InStr(prompt, "FIGUREDART_PRODUCT_CREATION") > 0, "Figured'Art output mode")
    AssertTrue(InStr(prompt, "{{IMAGE_COUNT}}") = 0, "Image-count marker replacement")
    AssertTrue(InStr(prompt, "{{ATTACHMENT_IMAGE_COUNT}}") = 0, "Attachment-count marker replacement")
    AssertTrue(InStr(prompt, "Attachment 11 of 12: SFA137-Y_11.jpg (GO b2b image 11)") > 0, "Eleventh GO b2b image mapping")
    AssertTrue(InStr(prompt, "Attachment 12 of 12: SFA137-Y_12.jpg (reference only - do not return CMS image fields)") > 0, "Twelfth reference attachment mapping")
    AssertTrue(InStr(prompt, "IMAGE_12_NAME:") = 0, "Twelfth automation field exclusion")

    manifest := BuildBotzImageManifest(imageFiles)
    state := Map(
        "mode", "figuredart",
        "productName", "Santorini Sunrise",
        "stockCode", productCode,
        "matchCode", productCode,
        "productFolder", productFolder,
        "productMdPath", productMdPath,
        "productMdSize", FileGetSize(productMdPath),
        "productMdModified", FileGetTime(productMdPath, "M"),
        "initialGalleryCount", 0,
        "uploadedCount", 0,
        "pendingImageIndex", 0,
        "imageCount", imageFiles.Length,
        "images", imageFiles,
        "imageManifest", manifest
    )
    SaveFiguredArtState(state)
    figuredArtState := 0
    loaded := LoadFiguredArtState()
    AssertEqual(loaded["matchCode"], productCode, "State product code")
    AssertEqual(loaded["imageCount"], 11, "State image count")
    ValidateFiguredArtSourcesUnchanged(loaded)

    automationBlock := "MODE:`nFIGUREDART_PRODUCT_CREATION`n`nPRODUCT_NAME:`nSantorini Sunrise`n`nIMAGE_COUNT:`n11`n`nPRODUCT_NAME_RECOMMENDATION:`nKEEP CURRENT PRODUCT NAME`n`nMETA_TITLE:`nSantorini Sunrise Paint by Numbers`n`nMETA_DESCRIPTION:`nCreate the Santorini Sunrise design with this framed paint-by-numbers kit.`n`nHTML_SNIPPET:`n<div><h2>Santorini Sunrise</h2><p>A framed paint-by-numbers kit.</p></div>`n"
    Loop 11 {
        i := A_Index
        automationBlock .= "`nIMAGE_" i "_NAME:`nSFA137-Y Santorini Image " i "`n`nIMAGE_" i "_TITLE:`nSantorini Sunrise Product View " i "`n`nIMAGE_" i "_ALT:`nView " i " of the Santorini Sunrise paint-by-numbers kit`n"
    }
    parsed := ParseFiguredArtAutomationOutput(automationBlock, loaded)
    AssertEqual(parsed["mode"], "FIGUREDART_PRODUCT_CREATION", "Automation output mode")
    AssertEqual(parsed["imageNames"].Length, 11, "Automation output image count")
    rejectedWrongMode := false
    try ParseFiguredArtAutomationOutput(StrReplace(automationBlock, "FIGUREDART_PRODUCT_CREATION", "BOTZ_PRODUCT_CREATION"), loaded)
    catch
        rejectedWrongMode := true
    AssertTrue(rejectedWrongMode, "Wrong supplier output mode must be rejected")

    FileAppend "Figured'Art mode helper tests passed.`n", "*"
    DirDelete figuredArtRootDir, 1
    ExitApp 0
} catch as err {
    try DirDelete figuredArtRootDir, 1
    FileAppend "Figured'Art mode helper tests failed: " err.Message "`n", "**"
    ExitApp 1
}

#Include "..\lib\figuredart-product-creation.ahk"

AssertTrue(condition, label) {
    if !condition
        throw Error(label " failed.")
}

AssertEqual(actual, expected, label) {
    if actual != expected
        throw Error(label " failed. Expected '" expected "', found '" actual "'.")
}

CleanText(text) {
    return Trim(StrReplace(text, "`r", ""), " `t`n")
}

LogText(prefix, text) {
    return true
}

LogSupplierChatGptImagePlan(*) {
    return true
}

CreateDefaultBotzPromptSettings() {
    return Map(
        "inlink1Name", "",
        "inlink1Url", "",
        "inlink2Name", "",
        "inlink2Url", "",
        "inlinkExtra", "",
        "additionalNotes", ""
    )
}

BuildBotzRecommendedInlinks(settings) {
    return "NONE"
}

BuildAutomationImageOutputBlock(imageCount, includeImageNames := false) {
    text := ""
    Loop imageCount {
        i := A_Index
        text .= (text = "" ? "" : "`n`n") "IMAGE_" i "_NAME:`n[name]`n`nIMAGE_" i "_TITLE:`n[title]`n`nIMAGE_" i "_ALT:`n[alt]"
    }
    return text
}

EnumerateBotzImageFiles(imagesDir, maximumCount := 0) {
    files := []
    Loop Files imagesDir "\*", "F" {
        if RegExMatch(A_LoopFileName, "i)\.(jpe?g|png|webp)$")
            files.Push(A_LoopFileFullPath)
    }
    NaturalSortBotzPaths(files)
    while maximumCount > 0 && files.Length > maximumCount
        files.Pop()
    return files
}

TakeFirstBotzImageFiles(imageFiles, maximumCount) {
    limitedFiles := []
    count := maximumCount = 0 ? imageFiles.Length : Min(imageFiles.Length, maximumCount)
    Loop count
        limitedFiles.Push(imageFiles[A_Index])
    return limitedFiles
}

BuildBotzImageManifest(imageFiles) {
    manifest := []
    for _, imagePath in imageFiles
        manifest.Push(Map("path", imagePath, "size", FileGetSize(imagePath), "modified", FileGetTime(imagePath, "M")))
    return manifest
}

NaturalSortBotzPaths(paths) {
    Loop paths.Length {
        i := A_Index
        if i = 1
            continue
        current := paths[i]
        j := i - 1
        while j >= 1 && CompareBotzPathsNaturally(paths[j], current) > 0 {
            paths[j + 1] := paths[j]
            j -= 1
        }
        paths[j + 1] := current
    }
}

CompareBotzPathsNaturally(pathA, pathB) {
    SplitPath pathA, &nameA
    SplitPath pathB, &nameB
    return DllCall("Shlwapi.dll\StrCmpLogicalW", "Str", nameA, "Str", nameB, "Int")
}

BotzPathArraysMatch(pathsA, pathsB) {
    if pathsA.Length != pathsB.Length
        return false
    Loop pathsA.Length {
        if StrLower(pathsA[A_Index]) != StrLower(pathsB[A_Index])
            return false
    }
    return true
}

EncodeStateValue(value) {
    return value
}

DecodeStateValue(value) {
    return value
}

ClearActiveCmsProductCode(*) {
}

ActivateWindow(*) {
}

ClickPoint(*) {
}

SetActiveCmsProductCode(value) {
    return value
}

CopyFromPoint(*) {
    return ""
}

InitialiseSeoPromptSettings(*) {
}

PastePromptToChatGPT(*) {
}

AttachBotzImagesToChatGpt(*) {
}

Flash(*) {
}

HasActiveCmsProductCode(*) {
    return false
}

ExtractValidatedAutomationBlock(*) {
    return ""
}

BuildBotzParsedOutputLog(*) {
    return ""
}

IsUsableProductNameRecommendation(*) {
    return false
}

InsertProductNameRecommendation(*) {
}

InsertMetaFields(*) {
}

ParseOrderedAutomationFields(block, expectedLabels) {
    text := StrReplace(block, "`r", "")
    allowed := Map(), fields := Map(), locations := []
    for _, label in expectedLabels
        allowed[label] := true

    position := 1
    while found := RegExMatch(text, "m)^([A-Z][A-Z0-9_]*):[ `t]*$", &match, position) {
        if !allowed.Has(match[1])
            throw Error("Unexpected automation label: " match[1] ".")
        position := found + StrLen(match[0])
    }
    searchFrom := 1
    for _, label in expectedLabels {
        pattern := "m)^" label ":[ `t]*$"
        found := RegExMatch(text, pattern, &match, searchFrom)
        if !found
            throw Error("Missing or out-of-order automation field: " label ".")
        if RegExMatch(text, pattern, , found + StrLen(match[0]))
            throw Error("Duplicate automation label: " label ".")
        locations.Push(Map("label", label, "labelStart", found, "valueStart", found + StrLen(match[0])))
        searchFrom := found + StrLen(match[0])
    }
    if Trim(SubStr(text, 1, locations[1]["labelStart"] - 1), " `t`n") != ""
        throw Error("Unexpected text before first field.")
    Loop locations.Length {
        item := locations[A_Index]
        valueEnd := A_Index < locations.Length ? locations[A_Index + 1]["labelStart"] : StrLen(text) + 1
        fields[item["label"]] := Trim(SubStr(text, item["valueStart"], valueEnd - item["valueStart"]), " `t`n")
    }
    return fields
}

ValidateMatrixFullOneLine(value, *) {
    value := Trim(value)
    if value = "" || InStr(value, "`n")
        throw Error("Expected one non-empty line.")
    return value
}

NormaliseHarmlessWhitespace(value) {
    return StrLower(RegExReplace(Trim(value), "\s+", " "))
}

StripCodeFence(value) {
    return value
}

ValidateCmsImageName(value, *) {
    value := ValidateImageOutputValue(value)
    if InStr(value, "\") || InStr(value, "/") || RegExMatch(value, "i)\.(jpe?g|png|webp)$")
        throw Error("CMS image name looks like a file path.")
    return value
}

ValidateImageOutputValue(value, *) {
    value := Trim(value)
    if value = "" || InStr(value, "`n")
        throw Error("Expected one non-empty image field line.")
    return value
}

ValidateGeneratedFields(*) {
    return ""
}

ChooseSingleFileInPicker(*) {
}

PasteToPoint(*) {
}
