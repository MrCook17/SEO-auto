#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode 2
CoordMode "Mouse", "Screen"

; ==========================================================
; CROMARTIE GO B2B + CHATGPT SEO AUTOMATION
; AutoHotkey v2
;
; Safe first version:
; - Opens the selected product from the initial CMS page.
; - Copies product name from Overview.
; - Copies meta title, meta description and HTML from Description.
; - Allows meta title, meta description and HTML fields to be blank.
; - Builds the ChatGPT prompt from prompt-template.md.
; - Uses a temporary hardcoded public URL instead of the GO B2B CMS URL.
; - Pastes the prompt into ChatGPT.
; - Tries to copy one or more high-quality product images from the CMS Images tab and paste them into ChatGPT.
; - Stops before sending so the image attachment can be checked manually.
; - Extracts ChatGPT's automation block from the clipboard.
; - Pastes generated SEO fields into GO B2B.
; - Does NOT click the main product Save button.
; - Automatically clicks the Image Details Save button after each image SEO field set is pasted, because GO B2B requires it to leave the image details page.
; - Can optionally paste ChatGPT's recommended product name with Ctrl + Alt + N.
; - Uses popups only for errors or blocking validation warnings.
; ==========================================================

; ==========================================================
; CONFIGURATION
; ==========================================================

cmsWinTitle := "GOb2b Admin - Cromartie Hobbycraft Limited - Catalogue Manager - Google Chrome"
; chatgptWinTitle := "Colour & Glaze - SEO Metadata Creation - Google Chrome"
; chatgptWinTitle := "Colour & Glaze - Product SEO Metadata Setup - Google Chrome"
; chatgptWinTitle := "Colour & Glaze"
chatgptWinTitle := "Arts & Crafts"

; Available modes:
; "full" = current existing workflow
; "metadata" = metadata-only workflow
SeoAutomationMode := "metadata"

FullPromptTemplatePath := A_ScriptDir "\prompt-template.md"
MetadataPromptTemplatePath := A_ScriptDir "\prompt-template-metadata-only.md"

; Kept as a familiar reference for the existing full workflow.
promptTemplatePath := MetadataPromptTemplatePath
logDir := A_ScriptDir "\logs"
backupDir := A_ScriptDir "\backups"

; Temporary hardcoded public product/category URL for {PAGE_URL} in the ChatGPT prompt.
; This avoids using the GO B2B CMS edit URL.
hardcodedPageUrl := "https://www.cromartiehobbycraft.co.uk/Catalogue/New-Products/GR-Pottery-Forms-Clay-Tools-and-Formers/..."

; Try to copy/paste the product image into ChatGPT after the prompt is pasted.
; The script still stops before sending so you can confirm the image attached correctly.
attemptImageCopyAfterPrompt := true

; Number of product images to copy into ChatGPT and update in GO B2B.
; Change this to 1, 2, 3, etc. depending on the department/product range.
imageCountToProcess := 1

; Image/card coordinates on the Images tab.
; Add more Map(...) entries here later if a department has more images.
; Each entry needs:
; - image: point on the image itself, used for copying/pasting into ChatGPT
; - details_button: the button that opens the image tags/details screen
imageTargets := [
    Map("image", [399, 454], "details_button", [319, 555]),
    Map("image", [645, 451], "details_button", [571, 552]),
    Map("image", [896, 460], "details_button", [820, 554]), ; x: 896, y: 460 x: 820, y: 554
    Map("image", [1160, 459], "details_button", [1074, 551]) ; x: 1160, y: 459 x: 1074, y: 551
]

; High-quality image copy settings.
; Process used for each image:
; 1. Click the original image thumbnail/card listed in imageTargets.
; 2. Copy the larger/high-quality preview image from this point.
; Keep this enabled so ChatGPT receives the clearer image rather than the small thumbnail.
copyHighQualityImagePreview := true
highQualityImageCopyPoint := [635, 687] ; x: 635, y: 687
highQualityImagePreviewLoadDelayMs := 700

; false = do not silently fall back to the old low-quality thumbnail copy if
; the high-quality preview copy fails. Set to true only if you prefer an
; automatic low-quality fallback instead of manually attaching the image.
allowThumbnailImageCopyFallback := false

; Toggle with Ctrl + Alt + N.
; false = do not paste ChatGPT product name recommendation.
; true = paste the recommendation into the Product Name field when Ctrl + Alt + O runs.
useRecommendedProductName := false

; Chrome/Edge image context menu shortcut. On many Windows Chrome installs, "y" triggers Copy image.
; If the right-click fallback opens the wrong context menu item, change this to the shortcut that works on your browser.
imageContextCopyKey := "y"

; ChatGPT paste reliability settings.
; These help when Chrome/ChatGPT is inactive, slow to focus, or drops the first Ctrl+V.
chatPasteRetries := 3
chatWakeDelayMs := 900
chatPasteVerifyDelayMs := 900

; Coordinates from config-notes.md
coords := Map(
    ; Initial CMS page
    "product_edit_button", [1437, 310],
    ; Product page tabs/buttons
    "overview_tab", [288, 260],
    "description_tab", [378, 261],
    "images_tab", [457, 260],
    "product_save_button", [1626, 996],
    ; Overview tab
    "product_name", [923, 374],
    ; Description tab
    "meta_title", [874, 383],
    "html_snippet", [876, 553],
    "meta_description", [900, 806],
    ; Images tab
    "image", [399, 454],
    "image_details_button", [319, 555],
    ; Image details page
    "image_title", [921, 620],
    "image_alt", [948, 684],
    "image_save_button", [1250, 734],
    ; ChatGPT
    "chat_input", [2323, 1018]
)

requiredInternalLinksDefault := "N/A"
additionalProductNotesDefault := "N/A"

; ==========================================================
; HOTKEYS
; ==========================================================

^!t:: TestScript()
^!w:: CopyActiveWindowTitle()
^!c:: CaptureMouseCoords()
; ^!p:: OpenProductBuildPromptAndPasteToChatGPT()
NumpadEnter:: OpenProductBuildPromptAndPasteToChatGPT()
; ^!b:: BuildPromptFromOpenProductPageAndPasteToChatGPT()
Numpad4:: BuildPromptFromOpenProductPageAndPasteToChatGPT()
^!i:: TryCopyCmsImagesToChatGPT()
^!n:: ToggleRecommendedProductName()
^1:: SetImageCountToProcess(1)
^2:: SetImageCountToProcess(2)
^3:: SetImageCountToProcess(3)
^4:: SetImageCountToProcess(4)
^5:: SetImageCountToProcess(5)
^6:: SetImageCountToProcess(6)
^7:: SetImageCountToProcess(7)
^8:: SetImageCountToProcess(8)
^9:: SetImageCountToProcess(9)
; ^!o:: PasteCopiedChatGPTOutputToCms()
Numpad6:: PasteCopiedChatGPTOutputToCms()
^!r:: Reload()
Esc:: ExitApp()

; Main product save is intentionally disabled.
; Only enable later after repeated testing on safe products.
; ^!s::ClickPoint("product_save_button", 500)

; ==========================================================
; TEST HELPERS
; ==========================================================

TestScript() {
    global useRecommendedProductName, SeoAutomationMode, imageCountToProcess
    nameMode := useRecommendedProductName ? "ON" : "OFF"
    Flash("Script running. SEO mode: " SeoAutomationMode ". Images: " imageCountToProcess ". Product name recommendation: " nameMode)
}

CopyActiveWindowTitle() {
    title := WinGetTitle("A")
    A_Clipboard := title
    Flash("Copied active window title")
}

ToggleRecommendedProductName() {
    global useRecommendedProductName
    useRecommendedProductName := !useRecommendedProductName
    mode := useRecommendedProductName ? "ON" : "OFF"
    Flash("Product name recommendation paste: " mode)
}

SetImageCountToProcess(imageCount) {
    global imageCountToProcess, imageTargets

    if imageCount < 1 {
        Flash("Image count must be at least 1.")
        return false
    }

    if imageCount > imageTargets.Length {
        MsgBox "Cannot set image count to " imageCount ".`n`nOnly " imageTargets.Length " image coordinate entries are configured in imageTargets."
        return false
    }

    imageCountToProcess := imageCount
    Flash("Prompt/CMS image count set to " imageCount ".")
    return true
}

GetDefaultImageNotes() {
    global imageCountToProcess
    return "Attached images. Number of product images: " imageCountToProcess "."
}

CaptureMouseCoords() {
    MouseGetPos &x, &y
    A_Clipboard := "x: " x ", y: " y
    ToolTip "Copied coordinates: x=" x ", y=" y
    SetTimer () => ToolTip(), -1500
}

; ==========================================================
; HOTKEY 1A - START FROM INITIAL CMS PAGE
; ==========================================================

OpenProductBuildPromptAndPasteToChatGPT() {
    global cmsWinTitle, hardcodedPageUrl

    try {
        EnsureFolders()
        ActivateWindow(cmsWinTitle)

        ; Use the temporary hardcoded public URL for {{PAGE_URL}}.
        ; Do not copy the browser URL here because the active page is a GO B2B CMS URL.
        pageUrl := hardcodedPageUrl

        ClickPoint("product_edit_button", 1500)
        BuildPromptFromCurrentProductPage(pageUrl)
    } catch as err {
        MsgBox "OpenProductBuildPromptAndPasteToChatGPT failed:`n`n" err.Message
    }
}

; ==========================================================
; HOTKEY 1B - START FROM ALREADY-OPEN PRODUCT PAGE
; ==========================================================

BuildPromptFromOpenProductPageAndPasteToChatGPT() {
    global cmsWinTitle, hardcodedPageUrl

    try {
        EnsureFolders()
        ActivateWindow(cmsWinTitle)

        ; Use the temporary hardcoded public URL for {{PAGE_URL}}.
        ; Do not copy the browser URL here because the active page is a GO B2B CMS URL.
        pageUrl := hardcodedPageUrl
        BuildPromptFromCurrentProductPage(pageUrl)
    } catch as err {
        MsgBox "BuildPromptFromOpenProductPageAndPasteToChatGPT failed:`n`n" err.Message
    }
}

; ==========================================================
; BUILD PROMPT FROM CURRENT PRODUCT PAGE
; ==========================================================

BuildPromptFromCurrentProductPage(pageUrl) {
    global cmsWinTitle, chatgptWinTitle, SeoAutomationMode
    global requiredInternalLinksDefault, additionalProductNotesDefault
    global attemptImageCopyAfterPrompt, imageCountToProcess

    ValidateSeoAutomationMode()
    ActivateWindow(cmsWinTitle)
    ValidateImageTargetConfig()

    ; Overview tab: product name
    ClickPoint("overview_tab", 500)
    productName := CopyFromPoint("product_name")

    ; Description tab: meta and HTML fields
    ClickPoint("description_tab", 600)
    ; These fields are allowed to be blank on unoptimised/new CMS pages.
    ; They should return an empty string instead of failing the whole hotkey.
    currentMetaTitle := CopyOptionalFromPoint("meta_title")
    currentHtmlSnippet := CopyOptionalFromPoint("html_snippet")
    currentMetaDescription := CopyOptionalFromPoint("meta_description")

    originalFields := "PAGE_URL:`n" pageUrl "`n`n"
    originalFields .= "PRODUCT_NAME:`n" productName "`n`n"
    originalFields .= "CURRENT_META_TITLE:`n" currentMetaTitle "`n`n"
    originalFields .= "CURRENT_META_DESCRIPTION:`n" currentMetaDescription "`n`n"
    originalFields .= "CURRENT_HTML_SNIPPET:`n" currentHtmlSnippet

    LogText("original-fields", originalFields)
    BackupText("original-fields", originalFields)

    templatePath := GetPromptTemplatePath()

    if !FileExist(templatePath) {
        throw Error("Prompt template was not found beside this script for SEO mode '" SeoAutomationMode "': " templatePath)
    }

    template := ReadPromptTemplateFile(templatePath)
    imageNotes := GetDefaultImageNotes()

    prompt := BuildPromptFromTemplate(
        template,
        pageUrl,
        productName,
        currentMetaTitle,
        currentMetaDescription,
        currentHtmlSnippet,
        requiredInternalLinksDefault,
        imageNotes,
        additionalProductNotesDefault
    )
    prompt := EnsurePromptSupportsImageCount(prompt, imageCountToProcess)

    LogText("prompt", prompt)

    PastePromptToChatGPT(prompt)

    if attemptImageCopyAfterPrompt {
        TryCopyCmsImagesToChatGPT(false)
        Flash("Prompt pasted. Image copy attempted.")
        return
    }

    Flash("Prompt pasted. Attach image manually.")
}

; ==========================================================
; MODE AND PROMPT TEMPLATE HELPERS
; ==========================================================

ValidateSeoAutomationMode() {
    global SeoAutomationMode
    mode := GetSeoAutomationMode()

    if mode != "full" && mode != "metadata" {
        throw Error("Invalid SeoAutomationMode: " SeoAutomationMode ". Use 'full' or 'metadata'.")
    }
}

GetSeoAutomationMode() {
    global SeoAutomationMode
    return StrLower(Trim(SeoAutomationMode))
}

IsFullMode() {
    return GetSeoAutomationMode() = "full"
}

IsMetadataOnlyMode() {
    return GetSeoAutomationMode() = "metadata"
}

GetPromptTemplatePath() {
    global FullPromptTemplatePath, MetadataPromptTemplatePath

    ValidateSeoAutomationMode()

    if IsMetadataOnlyMode()
        return MetadataPromptTemplatePath

    return FullPromptTemplatePath
}

ReadPromptTemplateFile(templatePath) {
    return FileRead(templatePath, "UTF-8")
}

BuildPromptFromTemplate(template, pageUrl, productName, currentMetaTitle, currentMetaDescription, currentHtmlSnippet, requiredInternalLinks, imageNotes, additionalProductNotes) {
    prompt := template
    prompt := StrReplace(prompt, "{{PAGE_URL}}", CleanText(pageUrl))
    prompt := StrReplace(prompt, "{{PRODUCT_NAME}}", CleanText(productName))
    prompt := StrReplace(prompt, "{{CURRENT_META_TITLE}}", EmptyToNA(currentMetaTitle))
    prompt := StrReplace(prompt, "{{CURRENT_META_DESCRIPTION}}", EmptyToNA(currentMetaDescription))
    prompt := StrReplace(prompt, "{{CURRENT_HTML_SNIPPET}}", CleanText(currentHtmlSnippet))
    prompt := StrReplace(prompt, "{{REQUIRED_INTERNAL_LINKS}}", requiredInternalLinks)
    prompt := StrReplace(prompt, "{{IMAGE_NOTES}}", imageNotes)
    prompt := StrReplace(prompt, "{{ADDITIONAL_PRODUCT_NOTES}}", additionalProductNotes)

    return prompt
}

; ==========================================================
; DYNAMIC IMAGE OUTPUT PROMPT SUPPORT
; ==========================================================

EnsurePromptSupportsImageCount(prompt, imageCount) {
    if imageCount <= 1
        return prompt

    imageOutputBlock := BuildAutomationImageOutputBlock(imageCount)

    ; Replace the image section inside the automation block so ChatGPT returns
    ; IMAGE_1_TITLE/ALT, IMAGE_2_TITLE/ALT, etc.
    prompt := RegExReplace(
        prompt,
        "is)IMAGE_1_TITLE:\s*[\r\n]+.*?===AUTOMATION_OUTPUT_END===",
        imageOutputBlock "===AUTOMATION_OUTPUT_END==="
    )

    ; Add a plain instruction as a fallback in case the exact prompt template changes later.
    if !InStr(prompt, "IMAGE_" imageCount "_ALT:") {
        prompt .= "`n`nImportant automation note: this product has " imageCount " attached images. The final automation block must include IMAGE_1_TITLE and IMAGE_1_ALT through IMAGE_" imageCount "_TITLE and IMAGE_" imageCount "_ALT."
    }

    return prompt
}

BuildAutomationImageOutputBlock(imageCount) {
    block := ""

    Loop imageCount {
        i := A_Index

        block .= "IMAGE_" i "_TITLE:`n"
        block .= "[exact image " i " title only]`n`n"
        block .= "IMAGE_" i "_ALT:`n"
        block .= "[exact image " i " alt text only]"

        if i < imageCount
            block .= "`n`n"
        else
            block .= "`n"
    }

    return block
}

; ==========================================================
; RELIABLE CHATGPT PROMPT PASTE
; ==========================================================

PastePromptToChatGPT(prompt) {
    global chatgptWinTitle, chatPasteRetries

    lastProblem := ""

    Loop chatPasteRetries {
        try {
            ActivateWindow(chatgptWinTitle, 900)
            FocusChatGptInputForPaste()
            PasteLargeTextToFocusedInput(prompt)
            Flash("Prompt pasted.")
            return true
        } catch as err {
            lastProblem := err.Message
            Sleep 700
        }
    }

    throw Error("Prompt did not paste into ChatGPT after " chatPasteRetries " attempts.`n`n" lastProblem)
}

FocusChatGptInputForPaste() {
    global chatWakeDelayMs

    ; First click wakes the Chrome/ChatGPT tab if it has been inactive.
    ClickPoint("chat_input", chatWakeDelayMs)
    Sleep 250

    ; Second click focuses the message box after the page is awake.
    ClickPoint("chat_input", 500)
    Sleep 300
}

; Keep this wrapper because the image-paste code also uses it.
WakeChatGptInput() {
    FocusChatGptInputForPaste()
}

PasteLargeTextToFocusedInput(text) {
    savedClip := ClipboardAll()

    A_Clipboard := ""
    Sleep 150
    A_Clipboard := text

    if !ClipWait(2) {
        A_Clipboard := savedClip
        throw Error("Clipboard did not receive prompt text.")
    }

    ; ChatGPT's input is contenteditable, so the older verify routine could steal focus.
    ; This simpler flow focuses, clears any draft text, pastes, and does not inspect the input afterwards.
    Send "^a"
    Sleep 180
    Send "{Backspace}"
    Sleep 250
    Send "^v"
    Sleep 1400

    A_Clipboard := savedClip
}

; Old verification functions have intentionally been left unused.
; They can be useful for debugging, but the main paste flow no longer calls them
; because selecting/copying from ChatGPT's input was causing focus problems.

VerifyChatGptPromptPasted(prompt) {
    savedClip := ClipboardAll()
    A_Clipboard := ""
    Sleep 150

    Send "^a"
    Sleep 180
    Send "^c"

    if !ClipWait(1.5) {
        A_Clipboard := savedClip
        return false
    }

    copied := A_Clipboard

    Send "{Right}"
    Sleep 100
    Send "^{End}"
    Sleep 100

    A_Clipboard := savedClip

    return PromptPasteLooksValid(copied, prompt)
}

PromptPasteLooksValid(copied, prompt) {
    copied := CleanText(copied)
    prompt := CleanText(prompt)

    if copied = ""
        return false

    if InStr(copied, "Current page/product name:") && InStr(copied, "===AUTOMATION_OUTPUT_START===")
        return true

    firstChunk := SubStr(prompt, 1, 60)
    minLength := Floor(StrLen(prompt) * 0.75)

    if StrLen(copied) >= minLength && InStr(copied, firstChunk)
        return true

    return false
}

SetClipboardText(text) {
    A_Clipboard := ""
    Sleep 100
    A_Clipboard := text

    if !ClipWait(2) {
        throw Error("Clipboard did not receive prompt text.")
    }
}


; ==========================================================
; IMAGE COPY / PASTE TO CHATGPT
; ==========================================================

TryCopyCmsImagesToChatGPT(showResult := true) {
    global imageCountToProcess, imageTargets

    try {
        if imageCountToProcess < 1
            return true

        if imageCountToProcess > imageTargets.Length {
            MsgBox "Image count is set to " imageCountToProcess ", but only " imageTargets.Length " image coordinate entries exist in imageTargets."
            return false
        }

        successCount := 0

        Loop imageCountToProcess {
            if TryCopyCmsSingleImageToChatGPT(A_Index, false)
                successCount += 1
            Sleep 600
        }

        if showResult {
            if successCount = imageCountToProcess
                Flash("Image paste attempted for " successCount " image(s).")
            else
                Flash("Image paste attempted for " successCount " of " imageCountToProcess " image(s).")
        }

        return successCount = imageCountToProcess
    } catch as err {
        if showResult
            MsgBox "TryCopyCmsImagesToChatGPT failed:`n`n" err.Message
        return false
    }
}

; Backwards-compatible helper: copies image 1 only.
TryCopyCmsImageToChatGPT(showResult := true) {
    return TryCopyCmsSingleImageToChatGPT(1, showResult)
}

TryCopyCmsSingleImageToChatGPT(imageIndex := 1, showResult := true) {
    global chatgptWinTitle

    try {
        imageCopied := CopyCmsImageToClipboard(imageIndex)

        if !imageCopied {
            if showResult
                Flash("Image " imageIndex " copy failed. Attach manually.")
            return false
        }

        ActivateWindow(chatgptWinTitle, 700)
        WakeChatGptInput()
        Send "^v"
        Sleep 1700

        if showResult
            Flash("Image " imageIndex " paste attempted.")

        return true
    } catch as err {
        if showResult
            MsgBox "TryCopyCmsSingleImageToChatGPT failed for image " imageIndex ":`n`n" err.Message
        return false
    }
}

CopyCmsImageToClipboard(imageIndex := 1) {
    global cmsWinTitle, imageContextCopyKey, copyHighQualityImagePreview, allowThumbnailImageCopyFallback

    ActivateWindow(cmsWinTitle)
    ClickPoint("images_tab", 800)

    ; Preferred method: click the configured image thumbnail/card, then copy
    ; the larger/high-quality preview image from highQualityImageCopyPoint.
    if copyHighQualityImagePreview {
        if CopyHighQualityPreviewByCtrlC(imageIndex)
            return true

        ; Browser fallback for the high-quality preview: right-click the
        ; larger preview and use Chrome's Copy image shortcut.
        if CopyHighQualityPreviewByContextMenuKey(imageIndex, imageContextCopyKey)
            return true

        ; Avoid silently attaching the old low-quality thumbnail unless the
        ; manual fallback setting is enabled near the top of this file.
        if !allowThumbnailImageCopyFallback
            return false
    }

    ; Optional legacy fallback methods. These preserve the old thumbnail copy
    ; behaviour only when allowThumbnailImageCopyFallback is true.
    if CopyImageByCtrlC(imageIndex)
        return true

    ; On many Chrome installs, the shortcut is "y". If this does not work,
    ; test the context menu manually and change imageContextCopyKey near the top.
    if CopyImageByContextMenuKey(imageIndex, imageContextCopyKey)
        return true

    return false
}

CopyHighQualityPreviewByCtrlC(imageIndex := 1) {
    global highQualityImageCopyPoint, highQualityImagePreviewLoadDelayMs

    savedClip := ClipboardAll()
    A_Clipboard := ""
    Sleep 100

    SelectCmsImageForPreview(imageIndex)
    Sleep highQualityImagePreviewLoadDelayMs

    ClickCoordinates(highQualityImageCopyPoint, 300)
    Send "^c"

    if ClipWait(2, true) {
        return true
    }

    A_Clipboard := savedClip
    return false
}

CopyHighQualityPreviewByContextMenuKey(imageIndex, copyKey) {
    global highQualityImageCopyPoint, highQualityImagePreviewLoadDelayMs

    savedClip := ClipboardAll()
    A_Clipboard := ""
    Sleep 100

    SelectCmsImageForPreview(imageIndex)
    Sleep highQualityImagePreviewLoadDelayMs

    MouseMove highQualityImageCopyPoint[1], highQualityImageCopyPoint[2]
    Sleep 150
    Click "Right"
    Sleep 500
    Send copyKey

    if ClipWait(3, true) {
        return true
    }

    Send "{Esc}"
    A_Clipboard := savedClip
    return false
}

SelectCmsImageForPreview(imageIndex := 1) {
    target := GetImageTarget(imageIndex)
    ClickCoordinates(target["image"], 500)
}

CopyImageByCtrlC(imageIndex := 1) {
    savedClip := ClipboardAll()
    A_Clipboard := ""
    Sleep 100

    target := GetImageTarget(imageIndex)
    ClickCoordinates(target["image"], 300)
    Send "^c"

    if ClipWait(2, true) {
        return true
    }

    A_Clipboard := savedClip
    return false
}

CopyImageByContextMenuKey(imageIndex, copyKey) {
    savedClip := ClipboardAll()
    A_Clipboard := ""
    Sleep 100

    target := GetImageTarget(imageIndex)
    point := target["image"]
    MouseMove point[1], point[2]
    Sleep 150
    Click "Right"
    Sleep 500
    Send copyKey

    if ClipWait(3, true) {
        return true
    }

    Send "{Esc}"
    A_Clipboard := savedClip
    return false
}

GetImageTarget(imageIndex) {
    global imageTargets

    if imageIndex < 1 || imageIndex > imageTargets.Length
        throw Error("Missing image target coordinates for image " imageIndex ". Add it to imageTargets or lower imageCountToProcess.")

    return imageTargets[imageIndex]
}

ClickCoordinates(point, delayMs := 250) {
    if point[1] = 0 || point[2] = 0
        throw Error("Coordinate not set.")

    Click point[1], point[2]
    Sleep delayMs
}

ValidateImageTargetConfig() {
    global imageCountToProcess, imageTargets

    if imageCountToProcess < 1
        throw Error("imageCountToProcess must be at least 1.")

    if imageCountToProcess > imageTargets.Length
        throw Error("imageCountToProcess is set to " imageCountToProcess ", but imageTargets only contains " imageTargets.Length " image coordinate entries.")
}

; ==========================================================
; HOTKEY 2 - PASTE COPIED CHATGPT OUTPUT INTO CMS
; ==========================================================

PasteCopiedChatGPTOutputToCms() {
    global cmsWinTitle, useRecommendedProductName, imageCountToProcess

    try {
        EnsureFolders()
        ValidateSeoAutomationMode()
        ValidateImageTargetConfig()

        response := A_Clipboard

        if !InStr(response, "===AUTOMATION_OUTPUT_START===") {
            MsgBox "Could not find the automation block.`n`nFirst click ChatGPT's copy button on the finished response, then press Ctrl + Alt + O again."
            return
        }

        block := ExtractBetween(response, "===AUTOMATION_OUTPUT_START===", "===AUTOMATION_OUTPUT_END===")

        if block = "" {
            MsgBox "Automation markers were found, but the block could not be extracted."
            return
        }

        output := ParseAutomationOutput(block, imageCountToProcess, IsMetadataOnlyMode())
        productNameRecommendation := output["productNameRecommendation"]
        metaTitle := output["metaTitle"]
        metaDescription := output["metaDescription"]
        htmlSnippet := output["htmlSnippet"]
        imageTitles := output["imageTitles"]
        imageAlts := output["imageAlts"]

        LogText("chatgpt-output", response)
        LogText("automation-block", block)

        warnings := ValidateGeneratedFields(metaTitle, metaDescription, htmlSnippet, imageTitles, imageAlts, IsFullMode())

        if warnings != "" {
            MsgBox "Warnings found. No fields were pasted.`n`n" warnings
            return
        }

        ActivateWindow(cmsWinTitle)

        ; Optional Overview tab: paste product name recommendation
        if useRecommendedProductName && IsUsableProductNameRecommendation(productNameRecommendation) {
            InsertProductNameRecommendation(productNameRecommendation)
        }

        ; Description tab: paste meta fields. Full mode also pastes the HTML/product description field.
        InsertMetaFields(metaTitle, metaDescription, htmlSnippet)

        ; Images tab: open each image details page and paste image metadata
        InsertImageSeoFields(imageTitles, imageAlts)

        Flash("SEO fields pasted.")
    } catch as err {
        MsgBox "PasteCopiedChatGPTOutputToCms failed:`n`n" err.Message
    }
}

; ==========================================================
; AUTOMATION OUTPUT PARSING
; ==========================================================

ParseAutomationOutput(block, imageCount, metadataOnly := false) {
    productNameRecommendation := ExtractLabel(block, "PRODUCT_NAME_RECOMMENDATION:", "META_TITLE:")
    metaTitle := ExtractLabel(block, "META_TITLE:", "META_DESCRIPTION:")

    if metadataOnly {
        metaDescription := ExtractLabel(block, "META_DESCRIPTION:", "IMAGE_1_TITLE:")
        htmlSnippet := ""
    } else {
        metaDescription := ExtractLabel(block, "META_DESCRIPTION:", "HTML_SNIPPET:")
        htmlSnippet := ExtractLabel(block, "HTML_SNIPPET:", "IMAGE_1_TITLE:")
        htmlSnippet := StripCodeFence(htmlSnippet)
    }

    imageTitles := []
    imageAlts := []

    Loop imageCount {
        i := A_Index
        nextImageTitleLabel := i < imageCount ? "IMAGE_" (i + 1) "_TITLE:" : ""

        imageTitles.Push(ExtractLabel(block, "IMAGE_" i "_TITLE:", "IMAGE_" i "_ALT:"))
        imageAlts.Push(ExtractLabel(block, "IMAGE_" i "_ALT:", nextImageTitleLabel))
    }

    return Map(
        "productNameRecommendation", productNameRecommendation,
        "metaTitle", metaTitle,
        "metaDescription", metaDescription,
        "htmlSnippet", htmlSnippet,
        "imageTitles", imageTitles,
        "imageAlts", imageAlts
    )
}

; ==========================================================
; CMS INSERTION HELPERS
; ==========================================================

InsertProductNameRecommendation(productNameRecommendation) {
    ClickPoint("overview_tab", 600)
    PasteToPoint("product_name", productNameRecommendation)
}

InsertMetaFields(metaTitle, metaDescription, htmlSnippet := "") {
    ClickPoint("description_tab", 600)
    PasteToPoint("meta_title", metaTitle)

    if IsFullMode()
        PasteToPoint("html_snippet", htmlSnippet)

    PasteToPoint("meta_description", metaDescription)
}

InsertImageSeoFields(imageTitles, imageAlts) {
    Loop imageTitles.Length {
        PasteImageMetadataToCms(A_Index, imageTitles[A_Index], imageAlts[A_Index])
    }
}

; ==========================================================
; IMAGE METADATA PASTE HELPERS
; ==========================================================

PasteImageMetadataToCms(imageIndex, imageTitle, imageAlt) {
    target := GetImageTarget(imageIndex)

    ClickPoint("images_tab", 700)
    ClickCoordinates(target["details_button"], 1000)
    PasteToPoint("image_title", imageTitle)
    PasteToPoint("image_alt", imageAlt)

    ; GO B2B requires this Image Save button to leave the image details page.
    ; This does not click the main product Save button.
    ClickPoint("image_save_button", 1000)
}

; ==========================================================
; VALIDATION
; ==========================================================

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

Flash(message, durationMs := 1500) {
    ToolTip message
    SetTimer () => ToolTip(), -durationMs
}

; ==========================================================
; CORE HELPERS
; ==========================================================

ActivateWindow(title, wakeDelayMs := 300) {
    if !WinExist(title) {
        throw Error("Window not found: " title)
    }

    ; Do NOT call WinRestore on every activation.
    ; WinRestore turns a maximised Chrome window into a restored/down-sized window,
    ; which was causing the browser tab/window to "restore down" when Ctrl+Alt+P/B ran.
    ; Only restore if the window is actually minimised.
    try {
        minMaxState := WinGetMinMax(title)
        if minMaxState = -1 {
            WinRestore(title)
            Sleep 250
        }
    }

    Loop 3 {
        WinActivate(title)

        if WinWaitActive(title, , 2) {
            Sleep wakeDelayMs
            return true
        }

        Sleep 300
    }

    throw Error("Window did not become active: " title)
}

ClickPoint(name, delayMs := 250) {
    global coords

    if !coords.Has(name) {
        throw Error("Missing coordinate: " name)
    }

    point := coords[name]

    if point[1] = 0 || point[2] = 0 {
        throw Error("Coordinate not set for: " name)
    }

    Click point[1], point[2]
    Sleep delayMs
}

CopyFromPoint(name) {
    ClickPoint(name, 200)
    Sleep 150
    Send "^a"
    Sleep 150
    return CopySelectedText(2, false)
}

CopyOptionalFromPoint(name) {
    ClickPoint(name, 200)
    Sleep 150
    Send "^a"
    Sleep 150
    return CopySelectedText(2, true)
}

CopySelectedText(timeout := 2, allowBlank := false) {
    savedClip := ClipboardAll()
    A_Clipboard := ""
    Sleep 100

    Send "^c"

    if !ClipWait(timeout) {
        ; Empty CMS fields are valid for optional fields such as meta title,
        ; meta description and HTML snippet. Because the clipboard was cleared
        ; before copying, a timeout here usually just means the selected field was blank.
        if allowBlank {
            A_Clipboard := savedClip
            return ""
        }

        A_Clipboard := savedClip
        throw Error("Clipboard did not receive copied text.")
    }

    text := A_Clipboard
    A_Clipboard := savedClip
    return text
}

PasteToPoint(name, text) {
    ClickPoint(name, 200)
    Sleep 150
    Send "^a"
    Sleep 150
    PasteText(text)
}

PasteText(text) {
    savedClip := ClipboardAll()

    ; If a generated value is intentionally blank and the user continued past
    ; the validation warning, clear the selected CMS field without failing.
    if text = "" {
        Send "{Backspace}"
        Sleep 250
        return
    }

    A_Clipboard := ""
    Sleep 100

    A_Clipboard := text

    if !ClipWait(2) {
        A_Clipboard := savedClip
        throw Error("Clipboard did not receive paste text.")
    }

    Send "^v"
    Sleep 350
    A_Clipboard := savedClip
}

CopyBrowserUrl() {
    Send "^l"
    Sleep 150
    return CopySelectedText(2, false)
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

EnsureFolders() {
    global logDir, backupDir

    if !DirExist(logDir)
        DirCreate logDir

    if !DirExist(backupDir)
        DirCreate backupDir
}

LogText(prefix, text) {
    global logDir

    timestamp := FormatTime(, "yyyyMMdd-HHmmss")
    filePath := logDir "\" prefix "-" timestamp ".txt"
    FileAppend text, filePath, "UTF-8"
}

BackupText(prefix, text) {
    global backupDir

    timestamp := FormatTime(, "yyyyMMdd-HHmmss")
    filePath := backupDir "\" prefix "-" timestamp ".txt"
    FileAppend text, filePath, "UTF-8"
}