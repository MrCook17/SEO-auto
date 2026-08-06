#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "UIA-v2\Lib\UIA.ahk"
#Include "UIA-v2\Lib\UIA_Browser.ahk"

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
; - Builds the ChatGPT prompt from prompts\prompt-template.md.
; - Uses a temporary hardcoded public URL instead of the GO B2B CMS URL.
; - Pastes the prompt into ChatGPT.
; - Tries to copy one or more high-quality product images from the CMS Images tab and paste them into ChatGPT.
; - Stops before sending so the image attachment can be checked manually.
; - Extracts ChatGPT's automation block from the clipboard.
; - Pastes generated SEO fields into GO B2B.
; - Clicks the main product Save button after all fields are pasted in full, metadata and image-only modes.
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
chatgptWinTitle := "Colour & Glaze"
; chatgptWinTitle := "Arts & Crafts"
; chatgptWinTitle := "Opt"

; Available modes:
; "full" = current existing workflow
; "metadata" = metadata and image SEO
; "image" = image SEO for one ordinary product
; "matrix_image" = image SEO for every child of one matrix product
; "matrix_full" = parent metadata plus child HTML and image SEO for one matrix product
SeoAutomationMode := "metadata"

promptDir := A_ScriptDir "\prompts"
FullPromptTemplatePath := promptDir "\prompt-template.md"
MetadataPromptTemplatePath := promptDir "\prompt-template-metadata-only.md"
ImageOnlyPromptTemplatePath := promptDir "\prompt-template-image-only.md"
MatrixImagePromptTemplatePath := promptDir "\prompt-template-matrix-image.md"
MatrixFullPromptTemplatePath := promptDir "\prompt-template-matrix-full.md"

; Kept as a familiar reference for the existing full workflow.
; promptTemplatePath := MetadataPromptTemplatePath
logDir := A_ScriptDir "\logs"
backupDir := A_ScriptDir "\backups"
stateDir := A_ScriptDir "\state"
debugDir := A_ScriptDir "\debug"
matrixStateFilePath := stateDir "\matrix-image-state.txt"
matrixFullStateFilePath := stateDir "\matrix-full-state.txt"
matrixNavigationDelayMs := 4000
matrixReturnDelayMs := 3000
matrixFullyReopenParentAfterReturn := true
matrixParentReopenDelayMs := 2500
matrixPageWaitTimeoutMs := 12000
matrixStableDurationMs := 1000
matrixUiaSearchTimeoutMs := 7000
matrixScrollWheelNotchesPerStep := 5
matrixMaxScrollSteps := 30
matrixNoNewRowsStopCount := 3
global matrixState := 0
global matrixFullState := 0
global activeMatrixParentProductName := ""
global LastEditButtons := []
global LastDocument := 0

; Temporary hardcoded public product/category URL for {PAGE_URL} in the ChatGPT prompt.
; This avoids using the GO B2B CMS edit URL.
hardcodedPageUrl := "https://www.cromartiehobbycraft.co.uk/Catalogue/Ceramic-Glazes-Ceramic-Underglazes-for-Pottery-Painting/Fired-Colour-Pottery-Glazes-Underglazes/Botz-Unidekor-Glazes/..."

; Try to copy/paste the product image into ChatGPT after the prompt is pasted.
; The script still stops before sending so you can confirm the image attached correctly.
attemptImageCopyAfterPrompt := true

; Fallback value used only until the Images tab is scanned with UIA-v2.
; Every workflow now replaces this automatically from the Image Gallery cards.
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
    Map("image", [1160, 459], "details_button", [1074, 551]), ; x: 1160, y: 459 x: 1074, y: 551
    Map("image", [1399, 459], "details_button", [1324, 552]) ; x: 1399, y: 459 x: 1324, y: 552
]

; High-quality image copy settings.
; Process used for each image:
; 1. Click the original image thumbnail/card listed in imageTargets.
; 2. Copy the larger/high-quality preview image from this point.
; Keep this enabled so ChatGPT receives the clearer image rather than the small thumbnail.
copyHighQualityImagePreview := true
highQualityImageCopyPoint := [635, 687] ; x: 635, y: 687
highQualityImagePreviewLoadDelayMs := 700
imageTabLoadDelayMs := 1500

; false = do not silently fall back to the old low-quality thumbnail copy if
; the high-quality preview copy fails. Set to true only if you prefer an
; automatic low-quality fallback instead of manually attaching the image.
allowThumbnailImageCopyFallback := false

; Toggle with Ctrl + Alt + N.
; false = do not paste ChatGPT product name recommendation.
; true = paste the recommendation into the Product Name field when Ctrl + Alt + O runs.
useRecommendedProductName := true

; Chrome/Edge image context menu shortcut. On many Windows Chrome installs, "y" triggers Copy image.
; If the right-click fallback opens the wrong context menu item, change this to the shortcut that works on your browser.
imageContextCopyKey := "y"

; ChatGPT paste reliability settings.
; These help when Chrome/ChatGPT is inactive, slow to focus, or drops the first Ctrl+V.
chatPasteRetries := 3
chatWakeDelayMs := 900
chatPasteVerifyDelayMs := 900

; Coordinates from docs\config-notes.md
coords := Map(
    ; Initial CMS page
    "product_edit_button", [1437, 310],
    ; "product_edit_button", [1483, 310], ; x: 1483, y: 310
    ; Product page tabs/buttons
    "overview_tab", [288, 260],
    "description_tab", [378, 261],
    "images_tab", [457, 260],
    "product_save_button", [1626, 996],
    "matrix_skus_tab", [837, 264],
    "matrix_child_cancel_button", [1558, 998],
    "matrix_child_save_button", [1630, 996],
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
    ; "chat_input", [2102, 972] ; x: 2102, y: 972
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
^0:: SetImageCountToProcess(0)
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
F8:: ShowLastLocations()
F9:: DumpAccessibilityTree()
^!r:: Reload()
Esc:: ExitApp()

; Manual main product save remains disabled.
; ^!s::ClickPoint("product_save_button", 500)

; ==========================================================
; TEST HELPERS
; ==========================================================

TestScript() {
    global useRecommendedProductName, SeoAutomationMode, imageCountToProcess
    nameMode := useRecommendedProductName ? "ON" : "OFF"
    savedCount := 0
    savedMode := "none"
    try {
        savedState := LoadMatrixState()
        savedCount := savedState["productCount"]
        savedMode := savedState["mode"]
    }
    MsgBox "SEO mode: " SeoAutomationMode "`nImages: " imageCountToProcess "`nRecommended product-name insertion: " nameMode "`nUIA-v2 matrix support: available`nSaved matrix state: " savedMode "`nSaved matrix children: " savedCount
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

    if imageCount < 0 {
        Flash("Image count cannot be negative.")
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

        if IsMatrixImageMode()
            throw Error("NumpadEnter is not used for matrix-image mode. Open the matrix parent and press Numpad4.")

        ClickPoint("product_edit_button", 1500)
        if IsMatrixFullMode()
            BuildMatrixFullPrompt(pageUrl)
        else
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
        if IsMatrixFullMode()
            BuildMatrixFullPrompt(pageUrl)
        else if IsMatrixImageMode()
            BuildMatrixImagePrompt(pageUrl)
        else
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

    ; Count actual gallery cards from their exact Remove buttons. Image labels
    ; are deliberately ignored because GO B2B can skip label numbers.
    DetectAndSetImageCountFromImagesTab()

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
    prompt := IsImageOnlyMode() ? InjectImageOnlyOutputFields(prompt, imageCountToProcess) : EnsurePromptSupportsImageCount(prompt, imageCountToProcess)

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

    if mode != "full" && mode != "metadata" && mode != "image" && mode != "matrix_image" && mode != "matrix_full" {
        throw Error("Invalid SeoAutomationMode: " SeoAutomationMode ". Use 'full', 'metadata', 'image', 'matrix_image' or 'matrix_full'.")
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

IsImageOnlyMode() {
    return GetSeoAutomationMode() = "image"
}

IsMatrixImageMode() {
    return GetSeoAutomationMode() = "matrix_image"
}

IsMatrixFullMode() {
    return GetSeoAutomationMode() = "matrix_full"
}

IsAnyMatrixMode() {
    return IsMatrixImageMode() || IsMatrixFullMode()
}

GetPromptTemplatePath() {
    global FullPromptTemplatePath, MetadataPromptTemplatePath, ImageOnlyPromptTemplatePath, MatrixImagePromptTemplatePath, MatrixFullPromptTemplatePath

    ValidateSeoAutomationMode()

    if IsMetadataOnlyMode()
        return MetadataPromptTemplatePath

    if IsImageOnlyMode()
        return ImageOnlyPromptTemplatePath

    if IsMatrixImageMode()
        return MatrixImagePromptTemplatePath
    if IsMatrixFullMode()
        return MatrixFullPromptTemplatePath

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
    if imageCount = 0 {
        ; Remove the template's default IMAGE_1 fields when this run has no
        ; configured images. The ordinary-output parser then ends the preceding
        ; field at the end of the automation block.
        return RegExReplace(
            prompt,
            "is)IMAGE_1_TITLE:\s*[\r\n]+.*?===AUTOMATION_OUTPUT_END===",
            "===AUTOMATION_OUTPUT_END==="
        )
    }

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

    if imageCountToProcess < 0
        throw Error("imageCountToProcess cannot be negative.")

    if imageCountToProcess > imageTargets.Length
        throw Error("imageCountToProcess is set to " imageCountToProcess ", but imageTargets only contains " imageTargets.Length " image coordinate entries.")
}

; Opens the Images tab and updates imageCountToProcess from the accessibility
; tree. Each genuine gallery card has one exact-name Remove button, so this
; remains correct when labels jump from (for example) Image 2 to Image 4.
DetectAndSetImageCountFromImagesTab(expectedCount := -1) {
    global imageCountToProcess, imageTargets, imageTabLoadDelayMs

    ClickPoint("images_tab", imageTabLoadDelayMs)
    detectedCount := WaitForStableImageGalleryCount()

    if detectedCount > imageTargets.Length
        throw Error("The Images tab contains " detectedCount " image(s), but imageTargets only has " imageTargets.Length " coordinate entries. Add more image targets before continuing.")

    if expectedCount >= 0 && detectedCount != expectedCount
        throw Error("Image count changed or differs between matrix children: expected " expectedCount ", detected " detectedCount ".")

    imageCountToProcess := detectedCount
    LogText("image-count-detected", "UIA-v2 detected " detectedCount " Image Gallery card(s).")
    return detectedCount
}

WaitForStableImageGalleryCount(timeoutMs := 7000, stableDurationMs := 750) {
    global LastDocument
    deadline := A_TickCount + timeoutMs
    previousCount := -1
    stableSince := 0

    Loop {
        ToolTip "Reading Image Gallery accessibility tree..."
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            LastDocument := document
            gallery := FindImageGalleryScope(document)
            if gallery {
                count := CountImageGalleryCards(gallery)
                if count = previousCount {
                    if !stableSince
                        stableSince := A_TickCount
                    if A_TickCount - stableSince >= stableDurationMs {
                        ToolTip()
                        return count
                    }
                } else {
                    previousCount := count
                    stableSince := A_TickCount
                }
            }
        } catch {
            ; Chrome can briefly invalidate UIA elements while the tab renders.
            ; Retry until the overall deadline instead of accepting a bad count.
        }
        if A_TickCount >= deadline {
            ToolTip()
            throw Error("The Image Gallery did not become available in the accessibility tree within " timeoutMs " ms. Leave the Images tab open and press F9 to dump the tree.")
        }
        Sleep 250
    }
}

FindImageGalleryScope(document) {
    try heading := document.FindElement({ Name: "Image Gallery", mm: 2, cs: 0 })
    catch
        return 0

    scope := heading
    Loop 12 {
        ; The smallest ancestor exposing the gallery's Add control contains
        ; the image cards without including unrelated page controls.
        try addElements := scope.FindElements({ Name: "Add", mm: 2, cs: 0 })
        catch
            addElements := []
        for _, element in addElements {
            try {
                if RegExMatch(Trim(element.Name), "i)^\+?\s*Add$")
                    return scope
            }
        }
        try parent := UIA.TreeWalkerTrue.GetParentElement(scope)
        catch
            break
        if !parent
            break
        scope := parent
    }
    return 0
}

CountImageGalleryCards(scope) {
    count := 0
    try elements := scope.FindElements({ Name: "Remove", mm: 2, cs: 0 })
    catch
        return count

    for _, element in elements {
        try {
            if StrLower(Trim(element.Name)) != "remove"
                continue
            if StrLower(GetUiaControlTypeText(element)) != "button"
                continue
            count += 1
        }
    }
    return count
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

        if IsMatrixFullMode() {
            PasteMatrixFullOutputToCms()
            return
        }

        if IsMatrixImageMode() {
            PasteMatrixImageOutputToCms()
            return
        }

        ActivateWindow(cmsWinTitle)
        DetectAndSetImageCountFromImagesTab()

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

        output := IsImageOnlyMode() ? ParseImageOnlyOutput(block, imageCountToProcess) : ParseAutomationOutput(block, imageCountToProcess, IsMetadataOnlyMode())
        productNameRecommendation := output["productNameRecommendation"]
        metaTitle := output["metaTitle"]
        metaDescription := output["metaDescription"]
        htmlSnippet := output["htmlSnippet"]
        imageTitles := output["imageTitles"]
        imageAlts := output["imageAlts"]

        LogText("chatgpt-output", response)
        LogText("automation-block", block)

        ; The strict image-only parser has already validated every required image
        ; field; metadata is intentionally absent in this mode.
        warnings := IsImageOnlyMode() ? "" : ValidateGeneratedFields(metaTitle, metaDescription, htmlSnippet, imageTitles, imageAlts, IsFullMode())

        if warnings != "" {
            MsgBox "Warnings found. No fields were pasted.`n`n" warnings
            return
        }

        ActivateWindow(cmsWinTitle)

        ; Optional Overview tab: paste product name recommendation
        if !IsImageOnlyMode() && useRecommendedProductName && IsUsableProductNameRecommendation(productNameRecommendation) {
            InsertProductNameRecommendation(productNameRecommendation)
        }

        ; Description tab: paste meta fields. Full mode also pastes the HTML/product description field.
        if !IsImageOnlyMode()
            InsertMetaFields(metaTitle, metaDescription, htmlSnippet)

        ; Images tab: open each image details page and paste image metadata
        InsertImageSeoFields(imageTitles, imageAlts)

        ; Save every ordinary workflow after all metadata and requested image
        ; records have been updated.
        if IsFullMode() || IsMetadataOnlyMode() || IsImageOnlyMode()
            ClickPoint("product_save_button", 1000)

        if IsFullMode()
            Flash("SEO fields pasted and product saved.")
        else if IsMetadataOnlyMode()
            Flash("Metadata and image SEO fields pasted and product saved.")
        else if IsImageOnlyMode()
            Flash("Image SEO fields pasted and product saved.")
        else
            Flash("SEO fields pasted; main product was not saved.")
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
    global imageTabLoadDelayMs
    target := GetImageTarget(imageIndex)

    ClickPoint("images_tab", imageTabLoadDelayMs)
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
    maxAttempts := 5
    lastActual := ""
    lastProblem := ""

    Loop maxAttempts {
        attempt := A_Index
        ClickPoint(name, 200)
        Sleep 150
        Send "^a"
        Sleep 150
        PasteText(text)
        Sleep 250

        try {
            ; Select and copy the value back from the same CMS control. Optional
            ; copying is required because an intentionally cleared field does
            ; not place text on the clipboard.
            lastActual := CopyOptionalFromPoint(name)
            if NormalisePastedFieldValue(lastActual) = NormalisePastedFieldValue(text) {
                if attempt > 1
                    LogText("paste-verification", "Field '" name "' verified on attempt " attempt ".")
                return true
            }
            lastProblem := "read-back value did not match"
            LogText(
                "paste-verification-mismatch",
                "Field: " name
                . "`nAttempt: " attempt " of " maxAttempts
                . "`nExpected:`n" text
                . "`nActual:`n" lastActual
            )
        } catch as err {
            lastProblem := "could not read the field back: " err.Message
            LogText("paste-verification-error", "Field '" name "', attempt " attempt " of " maxAttempts ": " err.Message)
        }

        if attempt < maxAttempts {
            ToolTip "Paste verification failed for " name ".`nRetrying " (attempt + 1) " of " maxAttempts "..."
            Sleep 350
        }
    }

    ToolTip()
    throw Error(
        "Could not verify the pasted value in '" name "' after " maxAttempts " attempts."
        . "`n`nLast problem: " lastProblem
        . "`n`nProcessing stopped before continuing to another CMS field."
    )
}

NormalisePastedFieldValue(value) {
    ; Windows clipboard text can represent the same textarea content with CRLF
    ; or LF line endings. No other characters or whitespace are ignored.
    value := StrReplace(value, "`r`n", "`n")
    return StrReplace(value, "`r", "`n")
}

PasteText(text) {
    savedClip := ClipboardAll()

    ; If a generated value is intentionally blank and the user continued past
    ; the validation warning, clear the selected CMS field without failing.
    if text = "" {
        Send "{Backspace}"
        Sleep 250
        A_Clipboard := savedClip
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
    global logDir, backupDir, stateDir, debugDir

    if !DirExist(logDir)
        DirCreate logDir

    if !DirExist(backupDir)
        DirCreate backupDir

    if !DirExist(stateDir)
        DirCreate stateDir

    if !DirExist(debugDir)
        DirCreate debugDir
}

LogText(prefix, text) {
    global logDir

    timestamp := FormatTime(, "yyyyMMdd-HHmmss")
    filePath := logDir "\" GetSeoAutomationMode() "-" prefix "-" timestamp ".txt"
    FileAppend text, filePath, "UTF-8"
}

BackupText(prefix, text) {
    global backupDir

    timestamp := FormatTime(, "yyyyMMdd-HHmmss")
    filePath := backupDir "\" prefix "-" timestamp ".txt"
    FileAppend text, filePath, "UTF-8"
}

; ==========================================================
; STRICT IMAGE/MATRIX OUTPUT PARSING
; ==========================================================

InjectImageOnlyOutputFields(prompt, imageCount) {
    fields := BuildAutomationImageOutputBlock(imageCount)
    return StrReplace(StrReplace(prompt, "{{IMAGE_COUNT}}", imageCount), "{{IMAGE_AUTOMATION_OUTPUT_FIELDS}}", fields)
}

ParseImageOnlyOutput(block, imageCount) {
    expected := ["MODE", "IMAGE_COUNT"]
    Loop imageCount {
        expected.Push("IMAGE_" A_Index "_TITLE")
        expected.Push("IMAGE_" A_Index "_ALT")
    }
    fields := ParseExactLineFields(block, expected)
    if fields["MODE"] != "IMAGE_ONLY"
        throw Error("Image output MODE must be IMAGE_ONLY.")
    if !IsInteger(fields["IMAGE_COUNT"]) || Integer(fields["IMAGE_COUNT"]) != imageCount
        throw Error("Image output count does not match imageCountToProcess (" imageCount ").")
    titles := [], alts := []
    Loop imageCount {
        title := ValidateImageOutputValue(fields["IMAGE_" A_Index "_TITLE"], "Image " A_Index " title")
        alt := ValidateImageOutputValue(fields["IMAGE_" A_Index "_ALT"], "Image " A_Index " alt")
        if StrLower(title) = StrLower(alt)
            throw Error("Image " A_Index " title and alt text are identical.")
        titles.Push(title), alts.Push(alt)
    }
    return Map("productNameRecommendation", "", "metaTitle", "", "metaDescription", "", "htmlSnippet", "", "imageTitles", titles, "imageAlts", alts)
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

NormaliseHarmlessWhitespace(value) {
    return StrLower(RegExReplace(Trim(value), "\s+", " "))
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

; ==========================================================
; MATRIX PROMPT, STATE AND INSERTION
; ==========================================================

BuildMatrixImagePrompt(pageUrl) {
    global cmsWinTitle, chatgptWinTitle, imageCountToProcess, matrixState, MatrixImagePromptTemplatePath
    global additionalProductNotesDefault, activeMatrixParentProductName
    ValidateImageTargetConfig()
    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    parentName := CopyFromPoint("product_name")
    activeMatrixParentProductName := parentName
    ClickPoint("description_tab", 600)
    parentTitle := CopyOptionalFromPoint("meta_title")
    firstHtml := ""
    parentDescription := CopyOptionalFromPoint("meta_description")
    parentImageCount := DetectAndSetImageCountFromImagesTab()
    if parentImageCount
        TryCopyCmsImagesToChatGPT(false)
    ; Visiting the parent Images tab can leave Chromium's matrix-SKU UIA tree
    ; stale. Close and reopen the complete parent before the first SKU scan so
    ; ReacquireMatrixSkuControls reads a newly built accessibility tree.
    ActivateWindow(cmsWinTitle)
    FullyReopenActiveMatrixParent()
    initial := ReacquireMatrixSkuControls(0)
    productCount := initial["buttons"].Length
    products := []
    Loop productCount {
        p := A_Index
        rowText := NormaliseMatrixRowText(initial["buttons"][p].RowText)
        exactName := ExtractMatrixProductNameFromRow(rowText, p)
        variantContext := ExtractMatrixVariantFromRow(rowText, exactName)
        products.Push(Map("index", p, "productName", exactName, "variantContext", variantContext, "skuRowText", rowText, "imageCount", 0))
    }

    ; Collect and attach each child's images during the same visit. Counts are
    ; read independently because matrix children need not share an image count.
    Loop productCount {
        p := A_Index
        controls := ReacquireAndValidateMatrixOrder(products)
        ClickMatrixEditButton(controls["buttons"][p])
        WaitForChildProductPage(p, productCount)
        if p = 1 {
            ClickPoint("description_tab", 600)
            firstHtml := CopyOptionalFromPoint("html_snippet")
        }
        products[p]["imageCount"] := DetectAndSetImageCountFromImagesTab()
        if products[p]["imageCount"]
            TryCopyCmsImagesToChatGPT(false)
        ActivateWindow(cmsWinTitle)
        ClickPoint("matrix_child_cancel_button", 300)
        WaitForMatrixSkuPage(p, productCount)
    }
    matrixState := Map("mode", "matrix_image", "parentProductName", parentName, "productCount", productCount, "parentImageCount", parentImageCount, "products", products)
    SaveMatrixState(matrixState)
    prompt := BuildMatrixPromptFromState(FileRead(MatrixImagePromptTemplatePath, "UTF-8"), pageUrl, parentTitle, parentDescription, firstHtml, matrixState)
    LogText("matrix_image-parent-context", "Parent: " parentName "`nURL: " pageUrl "`nChildren: " productCount "`nParent images: " parentImageCount "`nTotal images: " GetMatrixTotalImageCount(matrixState))
    LogText("matrix_image-prompt", prompt)
    PastePromptToChatGPT(prompt)
    ActivateWindow(chatgptWinTitle)
    FocusChatGptInputForPaste()
    Flash("Matrix prompt and attachments are ready for manual review.", 3000)
}

BuildMatrixPromptFromState(template, pageUrl, metaTitle, metaDescription, firstHtml, state) {
    global additionalProductNotesDefault
    productsText := "", mapping := "", outputFields := "", attachment := 0
    parentCount := state["parentImageCount"]
    if parentCount {
        Loop parentCount {
            i := A_Index, attachment += 1
            mapping .= "Attached image " attachment " = Parent matrix product, Image " i "`n"
            outputFields .= "PARENT_IMAGE_" i "_TITLE:`n[one-line value]`n`nPARENT_IMAGE_" i "_ALT:`n[one-line value]`n`n"
        }
    }
    for p, product in state["products"] {
        imageCount := product["imageCount"]
        imageSummary := imageCount = 0 ? "No images are configured for this product." : "Attached images: Product " p " Image 1 through Product " p " Image " imageCount
        productsText .= "Product " p ":`nExact product name: " product["productName"] "`nVariant, size or colour difference: " product["variantContext"] "`nSKU row context: " EmptyToNA(product["skuRowText"]) "`n" imageSummary "`n`n"
        outputFields .= "PRODUCT_" p "_NAME:`n[exact input product name unchanged]`n`nPRODUCT_" p "_IMAGE_COUNT:`n" imageCount "`n`n"
        Loop imageCount {
            i := A_Index, attachment += 1
            mapping .= "Attached image " attachment " = Product " p ", Image " i "`n"
            outputFields .= "PRODUCT_" p "_IMAGE_" i "_TITLE:`n[one-line value]`n`nPRODUCT_" p "_IMAGE_" i "_ALT:`n[one-line value]`n`n"
        }
    }
    prompt := template
    replacements := Map("{{PAGE_URL}}", pageUrl, "{{MATRIX_PRODUCT_NAME}}", state["parentProductName"], "{{CURRENT_META_TITLE}}", EmptyToNA(metaTitle), "{{CURRENT_META_DESCRIPTION}}", EmptyToNA(metaDescription), "{{FIRST_CHILD_HTML_SNIPPET}}", EmptyToNA(firstHtml), "{{PRODUCT_COUNT}}", state["productCount"], "{{PARENT_IMAGE_COUNT}}", parentCount, "{{TOTAL_IMAGE_COUNT}}", GetMatrixTotalImageCount(state), "{{MATRIX_PRODUCTS}}", Trim(productsText), "{{ATTACHMENT_ORDER}}", EmptyToNA(Trim(mapping)), "{{IMAGE_NOTES}}", BuildMatrixImageCountSummary(state), "{{ADDITIONAL_PRODUCT_NOTES}}", additionalProductNotesDefault, "{{MATRIX_AUTOMATION_OUTPUT_FIELDS}}", outputFields)
    for token, value in replacements
        prompt := StrReplace(prompt, token, value)
    return prompt
}

BuildMatrixFullPrompt(pageUrl) {
    global cmsWinTitle, chatgptWinTitle, imageCountToProcess, matrixFullState
    global MatrixFullPromptTemplatePath, activeMatrixParentProductName
    ValidateImageTargetConfig()
    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    parentName := CopyFromPoint("product_name")
    activeMatrixParentProductName := parentName
    ClickPoint("description_tab", 600)
    parentTitle := CopyOptionalFromPoint("meta_title")
    parentDescription := CopyOptionalFromPoint("meta_description")
    parentImageCount := DetectAndSetImageCountFromImagesTab()
    if parentImageCount
        TryCopyCmsImagesToChatGPT(false)
    ; Rebuild the parent after inspecting its Images tab. The reopen helper
    ; returns on a fresh Matrix SKUs tab, ready for the first UIA lookup.
    ActivateWindow(cmsWinTitle)
    FullyReopenActiveMatrixParent()
    controls := ReacquireMatrixSkuControls(0)
    productCount := controls["buttons"].Length
    products := []
    Loop productCount {
        p := A_Index
        rowText := NormaliseMatrixRowText(controls["buttons"][p].RowText)
        exactName := ExtractMatrixProductNameFromRow(rowText, p)
        connectedSize := ExtractConnectedMatrixSkuSize(rowText)
        products.Push(Map("index", p, "productName", exactName, "connectedSize", connectedSize, "variantContext", ExtractMatrixVariantFromRow(rowText, exactName), "skuRowText", rowText, "originalHtmlSnippet", "", "imageCount", 0))
    }

    ; Visit every child separately. As in matrix_image, fully close and reopen
    ; the parent after every child return because GO b2b otherwise leaves
    ; Chrome's accessibility tree in a broken/stale state.
    Loop productCount {
        p := A_Index
        controls := ReacquireAndValidateMatrixOrder(products)
        ClickMatrixEditButton(controls["buttons"][p])
        WaitForChildProductPage(p, productCount)
        ClickPoint("overview_tab", 400)
        currentName := CopyFromPoint("product_name")
        if NormaliseHarmlessWhitespace(currentName) != NormaliseHarmlessWhitespace(products[p]["productName"])
            throw Error("Matrix-full collection opened the wrong child at product " p ". Expected '" products[p]["productName"] "', found '" currentName "'.")
        ClickPoint("description_tab", 600)
        products[p]["originalHtmlSnippet"] := CopyOptionalFromPoint("html_snippet")
        products[p]["imageCount"] := DetectAndSetImageCountFromImagesTab()
        if products[p]["imageCount"]
            TryCopyCmsImagesToChatGPT(false)
        ActivateWindow(cmsWinTitle)
        LogText("matrix_full-child-context", "Product " p ": " products[p]["productName"] "`nConnected SKU size: " products[p]["connectedSize"] "`nVariant: " products[p]["variantContext"] "`nSKU row: " products[p]["skuRowText"] "`nHTML:`n" products[p]["originalHtmlSnippet"])
        ClickPoint("matrix_child_cancel_button", 300)
        WaitForMatrixSkuPage(p, productCount)
    }

    matrixFullState := Map("mode", "matrix_full", "parentProductName", parentName, "productCount", productCount, "parentImageCount", parentImageCount, "products", products)
    SaveMatrixState(matrixFullState)
    prompt := BuildMatrixFullPromptFromState(FileRead(MatrixFullPromptTemplatePath, "UTF-8"), pageUrl, parentTitle, parentDescription, matrixFullState)
    LogText("matrix_full-parent-context", "Parent: " parentName "`nURL: " pageUrl "`nMeta title: " parentTitle "`nMeta description: " parentDescription "`nChildren: " productCount "`nParent images: " parentImageCount "`nTotal images: " GetMatrixTotalImageCount(matrixFullState))
    LogText("matrix_full-prompt", prompt)
    PastePromptToChatGPT(prompt)

    ActivateWindow(chatgptWinTitle)
    FocusChatGptInputForPaste()
    Flash("Matrix-full prompt and attachments are ready for manual review.", 3000)
}

BuildMatrixFullPromptFromState(template, pageUrl, metaTitle, metaDescription, state) {
    productsText := "", mapping := "", outputFields := "", attachment := 0, bt := Chr(96)
    parentCount := state["parentImageCount"]
    Loop parentCount {
        i := A_Index, attachment += 1
        mapping .= "Attached image " attachment " = Parent matrix product, Image " i "`n"
        outputFields .= "PARENT_IMAGE_" i "_TITLE:`n[one-line image title]`n`nPARENT_IMAGE_" i "_ALT:`n[one-line image alt text]`n`n"
    }
    for p, product in state["products"] {
        imageCount := product["imageCount"]
        imageSummary := imageCount = 0 ? "No images are configured for this product." : "Attached images: Product " p " Image 1 through Product " p " Image " imageCount
        productsText .= "Product " p ":`nExact child product name (audit identifier): " product["productName"] "`nConnected SKU size (from the same accessibility row): " EmptyToNA(product["connectedSize"]) "`nVariant context: " product["variantContext"] "`nFull SKU row context: " EmptyToNA(product["skuRowText"]) "`nCurrent child HTML/product description snippet:`n" bt bt bt "html`n" product["originalHtmlSnippet"] "`n" bt bt bt "`n" imageSummary "`n`n"
        outputFields .= "PRODUCT_" p "_NAME:`n[exact original child name unchanged]`n`nPRODUCT_" p "_IMAGE_COUNT:`n" imageCount "`n`nPRODUCT_" p "_HTML_SNIPPET:`n" bt bt bt "html`n[complete multiline child HTML]`n" bt bt bt "`n`n"
        Loop imageCount {
            i := A_Index, attachment += 1
            mapping .= "Attached image " attachment " = Product " p ", Image " i "`n"
            outputFields .= "PRODUCT_" p "_IMAGE_" i "_TITLE:`n[one-line image title]`n`nPRODUCT_" p "_IMAGE_" i "_ALT:`n[one-line image alt text]`n`n"
        }
    }
    replacements := Map(
        "{{PAGE_URL}}", pageUrl,
        "{{MATRIX_PRODUCT_NAME}}", state["parentProductName"],
        "{{CURRENT_META_TITLE}}", EmptyToNA(metaTitle),
        "{{CURRENT_META_DESCRIPTION}}", EmptyToNA(metaDescription),
        "{{PRODUCT_COUNT}}", state["productCount"],
        "{{PARENT_IMAGE_COUNT}}", parentCount,
        "{{TOTAL_IMAGE_COUNT}}", GetMatrixTotalImageCount(state),
        "{{MATRIX_PRODUCTS}}", Trim(productsText),
        "{{ATTACHMENT_ORDER}}", Trim(mapping),
        "{{IMAGE_NOTES}}", BuildMatrixImageCountSummary(state),
        "{{MATRIX_AUTOMATION_OUTPUT_FIELDS}}", outputFields
    )
    prompt := template
    for token, value in replacements
        prompt := StrReplace(prompt, token, value)
    return prompt
}

GetMatrixTotalImageCount(state) {
    total := state["parentImageCount"]
    for _, product in state["products"]
        total += product["imageCount"]
    return total
}

BuildMatrixImageCountSummary(state) {
    summary := "Parent matrix product: " state["parentImageCount"] " image(s)."
    for p, product in state["products"]
        summary .= "`nProduct " p ": " product["imageCount"] " image(s)."
    summary .= "`nTotal attachments: " GetMatrixTotalImageCount(state) "."
    return summary
}

ValidateMatrixStateImageTargets(state, availableTargets) {
    if state["parentImageCount"] > availableTargets
        throw Error("Saved matrix parent needs " state["parentImageCount"] " image target(s), but only " availableTargets " are configured.")
    for p, product in state["products"] {
        if product["imageCount"] > availableTargets
            throw Error("Saved matrix product " p " needs " product["imageCount"] " image target(s), but only " availableTargets " are configured.")
    }
}

ReacquireAndValidateMatrixOrder(products) {
    controls := ReacquireMatrixSkuControls(products.Length)
    Loop products.Length {
        rowText := NormaliseMatrixRowText(controls["buttons"][A_Index].RowText)
        currentName := ExtractMatrixProductNameFromRow(rowText, A_Index)
        if NormaliseHarmlessWhitespace(currentName) != NormaliseHarmlessWhitespace(products[A_Index]["productName"])
            throw Error("Matrix SKU order changed at product " A_Index ". Expected '" products[A_Index]["productName"] "', detected '" currentName "'.")
    }
    return controls
}

DeriveVariantContext(productName, rowText) {
    rowText := Trim(RegExReplace(rowText, "i)Editing Matrix Product:|\bEdit\b", ""))
    return rowText = "" ? "Not separately available; see product name" : rowText
}

PasteMatrixFullOutputToCms() {
    global cmsWinTitle, imageCountToProcess, imageTargets, activeMatrixParentProductName, useRecommendedProductName
    state := LoadMatrixState("matrix_full")
    activeMatrixParentProductName := state["parentProductName"]
    ValidateMatrixStateImageTargets(state, imageTargets.Length)
    response := A_Clipboard
    block := ExtractBetween(response, "===AUTOMATION_OUTPUT_START===", "===AUTOMATION_OUTPUT_END===")
    if block = ""
        throw Error("A complete matrix-full automation block is not on the clipboard.")

    ; Parsing and validation finish before the first CMS field is changed.
    output := ParseMatrixFullOutput(block, state)
    LogText("matrix_full-chatgpt-output", response)
    LogText("matrix_full-automation-block", block)
    LogText("matrix_full-parsed-output", BuildMatrixFullParsedLog(output))
    ActivateWindow(cmsWinTitle)

    if useRecommendedProductName && IsUsableProductNameRecommendation(output["parentProductNameRecommendation"]) {
        InsertProductNameRecommendation(output["parentProductNameRecommendation"])
        ; Read the value back from GO b2b and use that exact CMS value for the
        ; catalogue lookup. The pasted recommendation may contain whitespace
        ; or characters which the input normalises when it accepts the value.
        activeMatrixParentProductName := CopyFromPoint("product_name")
        if Trim(activeMatrixParentProductName) = ""
            throw Error("The renamed matrix parent could not be read back from the Product Name field.")
        LogText("matrix_full-update", "Parent reopen name after rename: " activeMatrixParentProductName)
    }
    InsertMatrixParentMetaFields(output["parentMetaTitle"], output["parentMetaDescription"])
    if state["parentImageCount"] {
        detectedParentCount := DetectAndSetImageCountFromImagesTab(state["parentImageCount"])
        Loop detectedParentCount
            PasteImageMetadataToCms(A_Index, output["parentImageTitles"][A_Index], output["parentImageAlts"][A_Index])
    }

    ; GO b2b invalidates/stales the matrix accessibility tree after any parent
    ; field is changed. Save and fully reopen the exact parent before opening
    ; Matrix SKUs, using the same recovery path as child return transitions.
    FullyReopenActiveMatrixParent()

    Loop state["productCount"] {
        p := A_Index
        try {
            controls := ReacquireAndValidateMatrixOrder(state["products"])
            ClickMatrixEditButton(controls["buttons"][p])
            WaitForChildProductPage(p, state["productCount"])
            ClickPoint("overview_tab", 400)
            currentName := CopyFromPoint("product_name")
            if NormaliseHarmlessWhitespace(currentName) != NormaliseHarmlessWhitespace(state["products"][p]["productName"])
                throw Error("current child name no longer matches saved product '" state["products"][p]["productName"] "'; found '" currentName "'.")
            childImageCount := state["products"][p]["imageCount"]
            DetectAndSetImageCountFromImagesTab(childImageCount)
            ClickPoint("description_tab", 600)
            ; Child matrix SKUs must inherit metadata from the parent matrix
            ; page. Explicitly clear any legacy child-level metadata before
            ; replacing the child's HTML description.
            PasteToPoint("meta_title", "")
            PasteToPoint("meta_description", "")
            PasteToPoint("html_snippet", output["products"][p]["htmlSnippet"])
            Loop childImageCount {
                i := A_Index
                ToolTip "Matrix-full product " p " of " state["productCount"] "`nPasting image SEO " i " of " childImageCount
                PasteImageMetadataToCms(i, output["products"][p]["imageTitles"][i], output["products"][p]["imageAlts"][i])
            }
            ClickPoint("matrix_child_save_button", 300)
            WaitForMatrixSkuPage(p, state["productCount"])
            LogText("matrix_full-update", "Product " p ": " state["products"][p]["productName"] "; child metadata cleared, HTML and " childImageCount " image record(s) updated.")
        } catch as err {
            LogText("matrix_full-error", "Product " p " ('" state["products"][p]["productName"] "'): " err.Message)
            throw Error("Matrix-full product " p " of " state["productCount"] " ('" state["products"][p]["productName"] "'):`n" err.Message "`n`nProcessing stopped to avoid updating the wrong child.")
        }
    }
    ToolTip()
    totalImages := GetMatrixTotalImageCount(state)
    nameStatus := useRecommendedProductName && IsUsableProductNameRecommendation(output["parentProductNameRecommendation"]) ? "Parent product name recommendation and metadata were pasted." : "Parent metadata was pasted; parent product name was left unchanged."
    MsgBox "Matrix-full SEO complete.`nChild products: " state["productCount"] "`nParent images: " state["parentImageCount"] "`nChild HTML snippets updated: " state["productCount"] "`nTotal image records updated: " totalImages "`n" nameStatus "`nThe parent was saved/reopened by the matrix accessibility-tree recovery workflow."
}

BuildMatrixFullParsedLog(output) {
    text := "Mode: " output["mode"] "`nParent recommendation: " output["parentProductNameRecommendation"] "`nParent meta title: " output["parentMetaTitle"] "`nParent meta description: " output["parentMetaDescription"] "`nProducts: " output["productCount"] "`n"
    Loop output["parentImageTitles"].Length
        text .= "Parent image " A_Index " title: " output["parentImageTitles"][A_Index] "`nParent image " A_Index " alt: " output["parentImageAlts"][A_Index] "`n"
    for p, product in output["products"] {
        text .= "`nProduct " p ": " product["productName"] "`nHTML:`n" product["htmlSnippet"] "`n"
        Loop product["imageTitles"].Length
            text .= "Image " A_Index " title: " product["imageTitles"][A_Index] "`nImage " A_Index " alt: " product["imageAlts"][A_Index] "`n"
    }
    return text
}

InsertMatrixParentMetaFields(metaTitle, metaDescription) {
    ; Deliberately cannot paste HTML and never clicks the parent Save button.
    ClickPoint("description_tab", 600)
    PasteToPoint("meta_title", metaTitle)
    PasteToPoint("meta_description", metaDescription)
}

PasteMatrixImageOutputToCms() {
    global cmsWinTitle, imageCountToProcess, imageTargets, activeMatrixParentProductName
    state := LoadMatrixState()
    activeMatrixParentProductName := state["parentProductName"]
    ValidateMatrixStateImageTargets(state, imageTargets.Length)
    response := A_Clipboard
    block := ExtractBetween(response, "===AUTOMATION_OUTPUT_START===", "===AUTOMATION_OUTPUT_END===")
    if block = ""
        throw Error("A complete matrix automation block is not on the clipboard.")
    output := ParseMatrixImageOutput(block, state)
    LogText("matrix_image-chatgpt-output", response)
    ActivateWindow(cmsWinTitle)
    if state["parentImageCount"] {
        DetectAndSetImageCountFromImagesTab(state["parentImageCount"])
        Loop state["parentImageCount"]
            PasteImageMetadataToCms(A_Index, output["parentImageTitles"][A_Index], output["parentImageAlts"][A_Index])
    }
    ; Saving/reopening also guarantees a fresh matrix accessibility tree after
    ; parent-image detail edits.
    FullyReopenActiveMatrixParent()
    ; Scan once at the start of the insertion stage. This validates the child
    ; count and stores fresh screen coordinates, but no UIA lookup is performed
    ; after any child Save transition.
    controls := ReacquireMatrixSkuControls(state["productCount"])
    Loop state["productCount"] {
        p := A_Index
        try {
            ClickMatrixEditButton(controls["buttons"][p])
            WaitForChildProductPage(p, state["productCount"])
            ClickPoint("overview_tab", 400)
            currentName := CopyFromPoint("product_name")
            if NormaliseHarmlessWhitespace(currentName) != NormaliseHarmlessWhitespace(state["products"][p]["productName"])
                throw Error("current child name no longer matches saved product " p " ('" state["products"][p]["productName"] "').")
            childImageCount := state["products"][p]["imageCount"]
            DetectAndSetImageCountFromImagesTab(childImageCount)
            Loop childImageCount {
                i := A_Index
                ToolTip "Matrix product " p " of " state["productCount"] "`nPasting image SEO " i " of " childImageCount
                PasteImageMetadataToCms(i, output["products"][p]["imageTitles"][i], output["products"][p]["imageAlts"][i])
                LogText("matrix_image-update", "Product " p ": " state["products"][p]["productName"] ", image " i " updated.")
            }
            ClickPoint("matrix_child_save_button", 300)
            WaitForMatrixSkuPage(p, state["productCount"])
        } catch as err {
            LogText("matrix_image-error", "Matrix product " p " of " state["productCount"] ": " err.Message)
            throw Error("Matrix product " p " of " state["productCount"] ": " err.Message "`n`nProcessing stopped. Leave this page open, inspect it, and retry only after correcting the state.")
        }
    }
    ToolTip()
    total := GetMatrixTotalImageCount(state)
    MsgBox "Matrix image SEO complete.`nProducts: " state["productCount"] "`nParent images: " state["parentImageCount"] "`nTotal image records: " total
}

SaveMatrixState(state) {
    global matrixStateFilePath, matrixFullStateFilePath
    mode := state.Has("mode") ? state["mode"] : "matrix_image"
    if mode != "matrix_image" && mode != "matrix_full"
        throw Error("Cannot save unsupported matrix state mode '" mode "'.")
    filePath := mode = "matrix_full" ? matrixFullStateFilePath : matrixStateFilePath
    text := mode = "matrix_full" ? "CROMARTIE_MATRIX_FULL_STATE_V3`nmode`tmatrix_full`n" : "CROMARTIE_MATRIX_STATE_V3`n"
    text .= "parent`t" EncodeStateValue(state["parentProductName"]) "`n"
    text .= "count`t" state["productCount"] "`nparent_images`t" state["parentImageCount"] "`n"
    for _, product in state["products"] {
        connectedSize := product.Has("connectedSize") ? product["connectedSize"] : ExtractConnectedMatrixSkuSize(product["skuRowText"])
        text .= "product`t" product["index"] "`t" product["imageCount"] "`t" EncodeStateValue(product["productName"]) "`t" EncodeStateValue(connectedSize) "`t" EncodeStateValue(product["variantContext"]) "`t" EncodeStateValue(product["skuRowText"])
        if mode = "matrix_full"
            text .= "`t" EncodeStateValue(product["originalHtmlSnippet"])
        text .= "`n"
    }
    if FileExist(filePath)
        FileDelete filePath
    FileAppend text, filePath, "UTF-8"
}

LoadMatrixState(requestedMode := "") {
    global matrixStateFilePath, matrixFullStateFilePath, matrixState, matrixFullState
    mode := requestedMode != "" ? StrLower(Trim(requestedMode)) : (IsMatrixFullMode() ? "matrix_full" : "matrix_image")
    if mode != "matrix_image" && mode != "matrix_full"
        throw Error("Unsupported matrix state mode '" mode "'.")
    if mode = "matrix_full" && matrixFullState
        return matrixFullState
    if mode = "matrix_image" && matrixState
        return matrixState
    filePath := mode = "matrix_full" ? matrixFullStateFilePath : matrixStateFilePath
    expectedHeader := mode = "matrix_full" ? "CROMARTIE_MATRIX_FULL_STATE_V3" : "CROMARTIE_MATRIX_STATE_V3"
    if !FileExist(filePath)
        throw Error("No saved " mode " state exists. Build its matrix prompt with Numpad4 first.")
    lines := StrSplit(StrReplace(FileRead(filePath, "UTF-8"), "`r", ""), "`n")
    if lines.Length < 4 || lines[1] != expectedHeader
        throw Error("The saved matrix state file is invalid or unsupported.")
    products := [], parent := "", count := 0, parentImages := 0
    Loop lines.Length - 1 {
        line := lines[A_Index + 1]
        if line = ""
            continue
        parts := StrSplit(line, "`t")
        switch parts[1] {
            case "mode":
                if parts.Length != 2 || parts[2] != mode
                    throw Error("The saved matrix state mode does not match " mode ".")
            case "parent": parent := DecodeStateValue(parts[2])
            case "count": count := Integer(parts[2])
            case "parent_images": parentImages := Integer(parts[2])
            case "product":
                expectedParts := mode = "matrix_full" ? 8 : 7
                if parts.Length != expectedParts
                    throw Error("A product record in the matrix state file is invalid.")
                product := Map("index", Integer(parts[2]), "imageCount", Integer(parts[3]), "productName", DecodeStateValue(parts[4]), "connectedSize", DecodeStateValue(parts[5]), "variantContext", DecodeStateValue(parts[6]), "skuRowText", DecodeStateValue(parts[7]))
                if mode = "matrix_full"
                    product["originalHtmlSnippet"] := DecodeStateValue(parts[8])
                products.Push(product)
        }
    }
    if parent = "" || count < 1 || parentImages < 0 || products.Length != count
        throw Error("The saved matrix state is incomplete.")
    Loop count {
        if products[A_Index]["index"] != A_Index || products[A_Index]["productName"] = "" || products[A_Index]["imageCount"] < 0
            throw Error("The saved matrix product order is invalid.")
    }
    loaded := Map("mode", mode, "parentProductName", parent, "productCount", count, "parentImageCount", parentImages, "products", products)
    if mode = "matrix_full"
        matrixFullState := loaded
    else
        matrixState := loaded
    return loaded
}

EncodeStateValue(value) {
    value := StrReplace(value, "%", "%25")
    value := StrReplace(value, "`t", "%09")
    value := StrReplace(value, "`r", "%0D")
    return StrReplace(value, "`n", "%0A")
}

DecodeStateValue(value) {
    value := StrReplace(value, "%0A", "`n")
    value := StrReplace(value, "%0D", "`r")
    value := StrReplace(value, "%09", "`t")
    return StrReplace(value, "%25", "%")
}

; ==========================================================
; UIA-V2 MATRIX DISCOVERY AND SAFE REACQUISITION
; ==========================================================

ReacquireMatrixSkuControls(expectedCount := 0) {
    global matrixUiaSearchTimeoutMs, matrixStableDurationMs, LastDocument, LastEditButtons
    ShowMatrixLookupStatus("Reading Chrome accessibility tree...")
    try {
        result := WaitForMatrixModalScope(matrixUiaSearchTimeoutMs)
        document := result["document"]
        scope := result["scope"]
        LastDocument := document
        if !scope
            throw Error("No matrix SKU Edit controls with Name/StockCode row context became available within " matrixUiaSearchTimeoutMs " ms. Press F9 to dump the current accessibility tree.")
        ShowMatrixLookupStatus("Collecting all SKU rows while scrolling...")
        buttons := CollectAllMatrixSkuButtons(scope)
        LastEditButtons := buttons
        if buttons.Length = 0
            throw Error("No matrix child Edit controls were detected. Press F9 for an accessibility-tree dump.")
        if expectedCount && buttons.Length != expectedCount
            throw Error("Matrix child count changed: expected " expectedCount ", detected " buttons.Length ".")
        return Map("document", document, "scope", scope, "buttons", buttons)
    } finally {
        ToolTip()
    }
}

FindMatrixModalScope(document) {
    try titleElement := document.FindElement({ Name: "Editing Matrix Product:", mm: 2, cs: 0 })
    catch
        return 0
    try {
        if titleElement.IsOffscreen
            return 0
    }
    scope := titleElement
    Loop 15 {
        ; During loading Chrome can expose Edit elements before their screen
        ; rectangles are stable, so modal discovery must not require visibility.
        if ScopeContainsAnyEditElement(scope)
            return scope
        try parent := UIA.TreeWalkerTrue.GetParentElement(scope)
        catch
            break
        if !parent
            break
        scope := parent
    }
    return 0
}

ScopeContainsAnyEditElement(scope) {
    try elements := scope.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return false
    for _, element in elements {
        try {
            if RegExMatch(element.Name, "i)(^|[^A-Za-z])Edit([^A-Za-z]|$)")
                return true
        }
    }
    return false
}

RejectPotentiallyIncompleteMatrix(scope) {
    try elements := scope.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return
    for _, element in elements {
        try {
            if RegExMatch(element.Name, "i)(^|[^A-Za-z])Edit([^A-Za-z]|$)") && element.IsOffscreen
                throw Error("The matrix exposes off-screen Edit controls, so the complete scrollable list cannot be mapped safely. Expand or scroll the list until all children are exposed, then retry.")
        }
    }
}

WaitForStableEditLocations(scope, timeoutMs, stableDurationMs) {
    deadline := A_TickCount + timeoutMs, best := [], prior := "", stableSince := 0
    Loop {
        ShowMatrixLookupStatus("Scanning Edit buttons...`nBest count so far: " best.Length)
        current := GetUniqueVisibleEditLocations(scope)
        if current.Length > best.Length
            best := current
        signature := BuildLocationSignature(current)
        if current.Length && signature = prior {
            if !stableSince
                stableSince := A_TickCount
            if A_TickCount - stableSince >= stableDurationMs
                return current
        } else {
            prior := signature, stableSince := A_TickCount
        }
        if A_TickCount >= deadline
            return best
        Sleep 250
    }
}

GetUniqueVisibleEditLocations(scope) {
    candidates := [], unique := [], hasExactEditNames := false, hasSkuRows := false
    try elements := scope.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return unique
    for _, element in elements {
        try {
            if !RegExMatch(element.Name, "i)(^|[^A-Za-z])Edit([^A-Za-z]|$)") || element.IsOffscreen
                continue
            rect := element.Location
            if rect.w <= 0 || rect.h <= 0 || rect.x < 0 || rect.y < 0
                continue
            ; Retain only screen geometry and row text. UIA element references
            ; can become stale immediately after Chrome starts navigating.
            exactEditName := StrLower(Trim(element.Name)) = "edit"
            if exactEditName
                hasExactEditNames := true
            rowText := GetEditRowContext(element)
            isSkuRow := RegExMatch(rowText, "i)\bName\b") && RegExMatch(rowText, "i)\bStock\s*Code\b|\bStockCode\b")
            if isSkuRow
                hasSkuRows := true
            connectedSize := isSkuRow ? FindConnectedMatrixSkuSizeByGeometry(scope, element) : ""
            if connectedSize != "" && ExtractConnectedMatrixSkuSize(rowText) = "Not separately exposed in the SKU accessibility row"
                rowText := connectedSize " " rowText
            item := { Name: element.Name, ExactEditName: exactEditName, IsSkuRow: isSkuRow, ConnectedSize: connectedSize, ControlType: GetUiaControlTypeText(element), X: Round(rect.x), Y: Round(rect.y), W: Round(rect.w), H: Round(rect.h), CentreX: Round(rect.x + rect.w / 2), CentreY: Round(rect.y + rect.h / 2), RowText: rowText }
            candidates.Push(item)
        }
    }

    ; Chrome often exposes both the visible Edit control and a larger parent
    ; whose accessible name merely contains "Edit". When exact-name elements
    ; exist, ignore the broad named containers: their rectangle centres can be
    ; well outside the visible green button.
    for _, item in candidates {
        if hasSkuRows && !item.IsSkuRow
            continue
        if hasExactEditNames && !item.ExactEditName
            continue
        duplicate := 0
        for index, saved in unique {
            if LocationsRepresentSameControl(item, saved) {
                duplicate := index
                break
            }
        }
        if !duplicate
            unique.Push(item)
        ; For overlapping exact Edit elements, the smaller rectangle is
        ; normally the visible text/control and has the safest click centre.
        else if IsBetterEditLocation(item, unique[duplicate])
            unique[duplicate] := item
    }
    SortLocationsTopToBottom(unique)
    return unique
}

FindConnectedMatrixSkuSizeByGeometry(scope, editElement) {
    cardRect := 0
    node := editElement
    Loop 8 {
        try node := UIA.TreeWalkerTrue.GetParentElement(node)
        catch
            break
        if !node
            break
        try nodeName := NormaliseMatrixRowText(node.Name)
        catch
            continue
        if !RegExMatch(nodeName, "i)\bName\b") || !RegExMatch(nodeName, "i)\bStock\s*Code\b|\bStockCode\b")
            continue
        try rect := node.Location
        catch
            continue
        if rect.w > 0 && rect.h > 0 {
            cardRect := rect
            break
        }
    }
    if !cardRect
        return ""

    candidates := []
    for _, typeName in ["Text", "DataItem", "Custom"] {
        try elements := scope.FindElements({ Type: typeName })
        catch
            continue
        for _, element in elements {
            try {
                if element.IsOffscreen
                    continue
                name := NormaliseMatrixRowText(element.Name)
                if !IsPlausibleConnectedSkuSize(name)
                    continue
                rect := element.Location
                if rect.w <= 0 || rect.h <= 0
                    continue
                centreX := rect.x + rect.w / 2
                centreY := rect.y + rect.h / 2
                ; The size must sit to the left of the Name/StockCode card and
                ; vertically inside that exact card's row.
                if centreX >= cardRect.x + 3
                    continue
                if centreY < cardRect.y - 3 || centreY > cardRect.y + cardRect.h + 3
                    continue
                distance := Abs(cardRect.x - (rect.x + rect.w))
                candidates.Push({ Name: name, Distance: distance, X: rect.x })
            }
        }
    }
    if candidates.Length = 0
        return ""

    best := candidates[1]
    for _, candidate in candidates {
        if candidate.Distance < best.Distance
            best := candidate
    }
    return best.Name
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

GetEditRowContext(element) {
    node := element, best := ""
    Loop 8 {
        try node := UIA.TreeWalkerTrue.GetParentElement(node)
        catch
            break
        if !node
            break
        try name := Trim(node.Name)
        catch
            continue
        if name = "" || InStr(name, "Editing Matrix Product:") || RegExMatch(name, "i)^Edit$")
            continue
        cleanedName := RegExReplace(name, "[\r\n\t]+", " ")
        ; The nearest ancestor containing the row's Name and StockCode is the
        ; SKU record. Return it immediately instead of continuing upwards into
        ; the whole SKU table or matrix modal.
        if RegExMatch(cleanedName, "i)\bName\b") && RegExMatch(cleanedName, "i)\bStock\s*Code\b|\bStockCode\b")
            return ExpandMatrixSkuRowContext(node, cleanedName)
        if best = ""
            best := cleanedName
    }
    return best
}

ExpandMatrixSkuRowContext(skuNode, baseText) {
    ; The nearest named ancestor normally represents the right-hand SKU card
    ; (Name/StockCode/Edit), while its parent row also contains the connected
    ; left-hand Size cell. Walk only a few levels and accept a broader name
    ; only while it still contains exactly one SKU identity. This prevents a
    ; table containing several SKUs from being mistaken for one product row.
    best := RegExReplace(baseText, "[\r\n\t]+", " ")
    node := skuNode
    Loop 4 {
        try node := UIA.TreeWalkerTrue.GetParentElement(node)
        catch
            break
        if !node
            break
        try candidate := RegExReplace(Trim(node.Name), "[\r\n\t]+", " ")
        catch
            continue
        if candidate = "" || InStr(candidate, "Editing Matrix Product:")
            continue
        if CountMatrixSkuIdentities(candidate) != 1
            continue
        if GetMatrixSkuRowKey(candidate) != GetMatrixSkuRowKey(best)
            continue
        ; Prefer the first single-SKU ancestor that adds text before "Name";
        ; that prefix is the connected Size/Colour/Variant cell.
        if RegExMatch(candidate, "i)^(.+?)\s+Name\s*:?", &prefixMatch) {
            prefix := Trim(prefixMatch[1])
            prefix := Trim(RegExReplace(prefix, "i)^(Size|Colour|Color|Variant)\s*:?\s*", ""))
            if prefix != "" {
                best := candidate
                break
            }
        }
    }
    return best
}

CountMatrixSkuIdentities(text) {
    count := 0, pos := 1
    while RegExMatch(text, "i)\b(?:Stock\s*Code|StockCode)\s*:", &match, pos) {
        count += 1
        pos := match.Pos(0) + match.Len(0)
    }
    return count
}

CollectAllMatrixSkuButtons(scope) {
    global matrixUiaSearchTimeoutMs, matrixStableDurationMs
    global matrixMaxScrollSteps, matrixNoNewRowsStopCount

    firstView := WaitForStableEditLocations(scope, matrixUiaSearchTimeoutMs, matrixStableDurationMs)
    if firstView.Length = 0
        return []

    anchorX := firstView[1].CentreX
    anchorY := firstView[1].CentreY

    ; Small matrices expose every SKU at once and have no internal scrollbar.
    ; Sending wheel input there can scroll the surrounding page or move the
    ; pointer away from the modal, so return the visible set without scrolling.
    if !MatrixScopeHasOffscreenSkuEdits(scope) {
        for _, item in firstView {
            key := GetMatrixSkuRowKey(item.RowText)
            if key = ""
                throw Error("A visible matrix SKU row has no usable StockCode or product-name identity.")
            item.RowKey := key
            item.RequiresScroll := false
            item.ScrollSteps := 0
            item.ScrollAnchorX := anchorX
            item.ScrollAnchorY := anchorY
        }
        return firstView
    }

    ScrollMatrixSkuListToTop(anchorX, anchorY)

    collected := [], seen := Map(), noNewCount := 0
    Loop matrixMaxScrollSteps + 1 {
        scrollStep := A_Index - 1
        ShowMatrixLookupStatus("Scanning matrix SKU list...`nProducts found: " collected.Length "`nScroll step: " scrollStep)
        current := WaitForStableEditLocations(scope, matrixUiaSearchTimeoutMs, 350)
        newCount := 0
        for _, item in current {
            key := GetMatrixSkuRowKey(item.RowText)
            if key = "" || seen.Has(key)
                continue
            item.RowKey := key
            item.RequiresScroll := true
            item.ScrollSteps := scrollStep
            item.ScrollAnchorX := anchorX
            item.ScrollAnchorY := anchorY
            seen[key] := true
            collected.Push(item)
            newCount += 1
        }

        if newCount = 0
            noNewCount += 1
        else
            noNewCount := 0

        if noNewCount >= matrixNoNewRowsStopCount
            break

        ScrollMatrixSkuListDownOneStep(anchorX, anchorY)
    }

    ScrollMatrixSkuListToTop(anchorX, anchorY)
    return collected
}

MatrixScopeHasOffscreenSkuEdits(scope) {
    try elements := scope.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return false
    for _, element in elements {
        try {
            if !element.IsOffscreen
                continue
            rowText := NormaliseMatrixRowText(GetEditRowContext(element))
            if RegExMatch(rowText, "i)\bName\b") && RegExMatch(rowText, "i)\bStock\s*Code\b|\bStockCode\b")
                return true
        }
    }
    return false
}

GetMatrixSkuRowKey(rowText) {
    text := NormaliseMatrixRowText(rowText)
    if RegExMatch(text, "i)\bStock\s*Code\s*:\s*([^ ]+)", &match)
        return "stock:" StrLower(match[1])
    if RegExMatch(text, "i)\bName\s*:?\s*(.+?)(?=\s+Stock\s*Code|\s+StockCode|$)", &match)
        return "name:" NormaliseHarmlessWhitespace(match[1])
    return ""
}

ScrollMatrixSkuListToTop(anchorX, anchorY) {
    MouseMove anchorX, anchorY, 0
    ; A large bounded wheel-up sequence reliably resets the internal SKU pane
    ; without depending on a fixed scrollbar coordinate.
    SendNativeMouseWheel(1, 60)
    Sleep 700
}

ScrollMatrixSkuListDownOneStep(anchorX, anchorY) {
    global matrixScrollWheelNotchesPerStep
    MouseMove anchorX, anchorY, 0
    SendNativeMouseWheel(-1, matrixScrollWheelNotchesPerStep)
    Sleep 650
}

SendNativeMouseWheel(direction, notchCount) {
    ; mouse_event produces actual wheel input instead of a keyboard-style Send.
    ; This avoids the Windows alert sound seen with large {WheelUp/Down} sends.
    wheelDelta := direction > 0 ? 120 : -120
    Loop notchCount {
        DllCall("user32\mouse_event", "UInt", 0x0800, "UInt", 0, "UInt", 0, "Int", wheelDelta, "UPtr", 0)
        Sleep 12
    }
}

FindCurrentMatrixSkuButton(item) {
    global matrixMaxScrollSteps
    anchorX := item.ScrollAnchorX, anchorY := item.ScrollAnchorY
    targetKey := item.RowKey

    if item.HasOwnProp("RequiresScroll") && !item.RequiresScroll {
        document := UIA_Browser().GetCurrentDocumentElement()
        scope := FindMatrixModalScope(document)
        if !scope && HasVisibleMatrixSkuRows(document)
            scope := document
        if scope {
            for _, candidate in GetUniqueVisibleEditLocations(scope) {
                if GetMatrixSkuRowKey(candidate.RowText) = targetKey
                    return candidate
            }
        }
        throw Error("Visible matrix SKU '" targetKey "' could not be located without scrolling.")
    }

    ScrollMatrixSkuListToTop(anchorX, anchorY)

    Loop matrixMaxScrollSteps + 1 {
        ShowMatrixLookupStatus("Locating " targetKey "...`nScroll step: " (A_Index - 1))
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            scope := FindMatrixModalScope(document)
            if !scope && HasVisibleMatrixSkuRows(document)
                scope := document
            if scope {
                visibleButtons := GetUniqueVisibleEditLocations(scope)
                for _, candidate in visibleButtons {
                    if GetMatrixSkuRowKey(candidate.RowText) = targetKey {
                        ToolTip()
                        return candidate
                    }
                }
            }
        }
        if A_Index <= matrixMaxScrollSteps
            ScrollMatrixSkuListDownOneStep(anchorX, anchorY)
    }
    ToolTip()
    throw Error("Could not bring matrix SKU '" targetKey "' into view for clicking.")
}

WaitForMatrixModalScope(timeoutMs) {
    deadline := A_TickCount + timeoutMs
    Loop {
        ShowMatrixLookupStatus("Waiting for the matrix SKU accessibility tree...")
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            scope := FindMatrixModalScope(document)
            if scope
                return Map("document", document, "scope", scope, "headingFound", true)
            ; Chrome does not always expose the modal heading. A visible Edit
            ; control whose nearest row contains both Name and StockCode is a
            ; stronger SKU-specific fallback than searching generic page text.
            if HasVisibleMatrixSkuRows(document)
                return Map("document", document, "scope", document, "headingFound", false)
        }
        if A_TickCount >= deadline
            return Map("document", 0, "scope", 0, "headingFound", false)
        Sleep 250
    }
}

HasVisibleMatrixSkuRows(scope) {
    try elements := scope.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return false
    for _, element in elements {
        try {
            if element.IsOffscreen
                continue
            rowText := NormaliseMatrixRowText(GetEditRowContext(element))
            if RegExMatch(rowText, "i)\bName\b") && RegExMatch(rowText, "i)\bStock\s*Code\b|\bStockCode\b")
                return true
        }
    }
    return false
}

LocationsRepresentSameControl(a, b) {
    return (Abs(a.CentreX - b.CentreX) <= 18 && Abs(a.CentreY - b.CentreY) <= 18) || (a.CentreX >= b.X && a.CentreX <= b.X + b.W && a.CentreY >= b.Y && a.CentreY <= b.Y + b.H) || (b.CentreX >= a.X && b.CentreX <= a.X + a.W && b.CentreY >= a.Y && b.CentreY <= a.Y + a.H)
}

SortLocationsTopToBottom(items) {
    if items.Length < 2
        return
    Loop items.Length - 1 {
        swapped := false
        Loop items.Length - A_Index {
            i := A_Index, a := items[i], b := items[i + 1]
            if a.CentreY > b.CentreY || (Abs(a.CentreY - b.CentreY) <= 5 && a.CentreX > b.CentreX) {
                items[i] := b, items[i + 1] := a, swapped := true
            }
        }
        if !swapped
            break
    }
}

BuildLocationSignature(items) {
    signature := items.Length "|"
    for _, item in items
        signature .= item.X "," item.Y "," item.W "," item.H ";"
    return signature
}

ClickMatrixEditButton(item) {
    ; Scroll until the saved StockCode/name identity is visible, then use its
    ; current UIA rectangle. Never reuse a Y coordinate captured in a different
    ; scroll position.
    ToolTip()
    CoordMode "Mouse", "Screen"
    currentItem := item.HasOwnProp("RowKey") ? FindCurrentMatrixSkuButton(item) : item
    MouseMove currentItem.CentreX, currentItem.CentreY, 0
    Sleep 150
    Click currentItem.CentreX, currentItem.CentreY
    Sleep 300
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

IsBetterEditLocation(candidate, saved) {
    if candidate.ExactEditName != saved.ExactEditName
        return candidate.ExactEditName
    return candidate.W * candidate.H < saved.W * saved.H
}

GetUiaControlTypeText(element) {
    try return element.LocalizedControlType
    catch
        return "unknown"
}

ShowMatrixLookupStatus(message) {
    MouseGetPos &mouseX, &mouseY
    ToolTip message, mouseX + 22, mouseY + 22
}

WaitForChildProductPage(productIndex, productCount) {
    global matrixPageWaitTimeoutMs, matrixNavigationDelayMs
    Sleep matrixNavigationDelayMs
    deadline := A_TickCount + matrixPageWaitTimeoutMs
    Loop {
        ShowMatrixLookupStatus("Waiting for child product " productIndex " of " productCount " to open...`nChecking the accessibility tree.")
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            if !FindMatrixModalScope(document) {
                ToolTip()
                Sleep 400
                return true
            }
        }
        if A_TickCount >= deadline {
            ToolTip()
            throw Error("Child page did not become ready for product " productIndex " of " productCount ".")
        }
        Sleep 300
    }
}

WaitForMatrixSkuPage(productIndex, expectedCount, allowParentReopen := true) {
    global matrixReturnDelayMs, matrixFullyReopenParentAfterReturn
    ; Cancel/Save has already been clicked. Do not interrogate the
    ; accessibility tree during this transition; allow GO b2b three seconds
    ; to restore the matrix SKU page, then continue.
    ToolTip "Waiting for the matrix SKU page to load..."
    Sleep matrixReturnDelayMs

    if allowParentReopen && matrixFullyReopenParentAfterReturn
        FullyReopenActiveMatrixParent()
    ToolTip()
    return true
}

FullyReopenActiveMatrixParent() {
    global activeMatrixParentProductName, matrixParentReopenDelayMs
    if Trim(activeMatrixParentProductName) = ""
        throw Error("The active matrix parent name is unavailable, so the parent cannot be reopened safely.")

    ; Close/save the entire matrix parent to return to the catalogue list.
    ToolTip "Closing the matrix parent to rebuild GO b2b..."
    ClickPoint("product_save_button", matrixParentReopenDelayMs)

    ; Locate the exact matrix parent row on the catalogue page and click its
    ; live Edit-button centre. This avoids a fixed row coordinate.
    ToolTip "Finding matrix parent:`n" activeMatrixParentProductName
    editButton := WaitForCatalogueProductEditButton(activeMatrixParentProductName, 10000)
    if !editButton
        throw Error("Could not find the catalogue Edit button for matrix parent '" activeMatrixParentProductName "'.")
    MouseMove editButton.CentreX, editButton.CentreY, 0
    Sleep 150
    Click editButton.CentreX, editButton.CentreY
    Sleep matrixParentReopenDelayMs

    ToolTip "Opening the refreshed SKUs tab..."
    ClickPoint("matrix_skus_tab", 1500)
}

WaitForCatalogueProductEditButton(productName, timeoutMs) {
    deadline := A_TickCount + timeoutMs
    Loop {
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            button := FindCatalogueProductEditButton(document, productName)
            if button
                return button
        }
        if A_TickCount >= deadline
            return 0
        Sleep 300
    }
}

FindCatalogueProductEditButton(document, productName) {
    targetName := NormaliseCatalogueProductName(productName)

    ; Prefer matching the accessible row belonging to each live Edit button.
    ; Some GO b2b catalogue views do not expose the product-name text as a
    ; separate searchable UIA element after a rename, although the Edit
    ; button's ancestor row still contains the complete current name.
    directMatch := FindCatalogueMatrixParentEditByRow(document, targetName)
    if directMatch
        return directMatch

    words := StrSplit(targetName, " "), searchAnchor := ""
    Loop Min(3, words.Length)
        searchAnchor .= (A_Index > 1 ? " " : "") words[A_Index]
    ; Search with a short stable anchor, then enforce the complete normalised
    ; parent name below. This tolerates NBSPs and repeated spaces in Chrome.
    try productElements := document.FindElements({ Name: searchAnchor, mm: 2, cs: 0 })
    catch
        return 0

    productRows := []
    for _, productElement in productElements {
        try {
            if productElement.IsOffscreen
                continue
            exposedName := NormaliseCatalogueProductName(productElement.Name)
            if !InStr(exposedName, targetName)
                continue
            rect := productElement.Location
            if rect.w > 0 && rect.h > 0
                productRows.Push({ CentreY: rect.y + rect.h / 2, Name: productElement.Name })
        }
    }

    if productRows.Length = 0
        return 0

    try editElements := document.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return 0

    best := 0, bestDistance := 999999
    for _, editElement in editElements {
        try {
            if editElement.IsOffscreen || StrLower(Trim(editElement.Name)) != "edit"
                continue
            rect := editElement.Location
            if rect.w <= 0 || rect.h <= 0
                continue
            editCentreY := rect.y + rect.h / 2
            for _, productRow in productRows {
                distance := Abs(editCentreY - productRow.CentreY)
                if distance < bestDistance {
                    bestDistance := distance
                    best := { CentreX: Round(rect.x + rect.w / 2), CentreY: Round(editCentreY) }
                }
            }
        }
    }

    ; Adjacent catalogue rows are roughly 53 pixels apart. This tolerance
    ; accepts the target row while rejecting the Edit buttons above and below.
    return best && bestDistance <= 35 ? best : 0
}

FindCatalogueMatrixParentEditByRow(document, targetName) {
    try editElements := document.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return 0

    for _, editElement in editElements {
        try {
            if editElement.IsOffscreen || StrLower(Trim(editElement.Name)) != "edit"
                continue
            rect := editElement.Location
            if rect.w <= 0 || rect.h <= 0
                continue
            if !CatalogueEditBelongsToMatrixParent(editElement, targetName)
                continue
            return { CentreX: Round(rect.x + rect.w / 2), CentreY: Round(rect.y + rect.h / 2) }
        }
    }
    return 0
}

CatalogueEditBelongsToMatrixParent(editElement, targetName) {
    node := editElement
    Loop 10 {
        try node := UIA.TreeWalkerTrue.GetParentElement(node)
        catch
            return false
        if !node
            return false
        try rowText := NormaliseCatalogueProductName(node.Name)
        catch
            continue
        if !InStr(rowText, targetName)
            continue
        ; The catalogue can show child Matrix SKU rows directly beneath their
        ; parent. Only an ancestor explicitly identifying a Matrix Product is
        ; allowed to satisfy the reopen lookup.
        if InStr(rowText, "matrix product") && !InStr(rowText, "matrix sku")
            return true
    }
    return false
}

NormaliseCatalogueProductName(value) {
    value := StrReplace(value, Chr(160), " ")
    value := StrReplace(value, "–", "-")
    value := StrReplace(value, "—", "-")
    value := RegExReplace(Trim(value), "\s+", " ")
    return StrLower(value)
}

BuildLocationsMessage(items) {
    output := ""
    for index, item in items {
        connectedSize := item.HasOwnProp("ConnectedSize") ? item.ConnectedSize : ""
        output .= index ". " item.Name " | size=" (connectedSize = "" ? "[not detected]" : connectedSize) " | type=" item.ControlType " | rect=" item.X "," item.Y " " item.W "x" item.H " | centre=" item.CentreX "," item.CentreY " | row=" item.RowText "`n"
    }
    return output = "" ? "No Edit controls recorded." : output
}

ShowLastLocations() {
    global LastEditButtons
    MsgBox "Detected " LastEditButtons.Length " Edit control(s):`n`n" BuildLocationsMessage(LastEditButtons)
}

DumpAccessibilityTree() {
    global LastDocument, cmsWinTitle, debugDir
    try {
        ; F9 may be pressed while ChatGPT or the script's own message box was
        ; most recently active. UIA_Browser searches the active browser, so
        ; explicitly activate the configured GO b2b CMS window first.
        ActivateWindow(cmsWinTitle, 500)
        LastDocument := 0
        LastDocument := UIA_Browser().GetCurrentDocumentElement()
        if !DirExist(debugDir)
            DirCreate debugDir
        path := debugDir "\go-b2b-accessibility-tree.txt"
        if FileExist(path)
            FileDelete path
        ToolTip "Creating accessibility-tree dump..."
        FileAppend LastDocument.DumpAll(), path, "UTF-8"
        ToolTip()
        MsgBox "Accessibility tree saved to:`n" path
    } catch as err {
        ToolTip()
        MsgBox "Accessibility-tree dump failed:`n`n" err.Message
    }
}

IsMatrixModalPresent(document) {
    try {
        heading := document.FindElement({ Name: "Editing Matrix Product:", mm: 2, cs: 0 })
        return !!heading
    } catch {
        return false
    }
}
