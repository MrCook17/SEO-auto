#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "UIA-v2\Lib\UIA.ahk"
#Include "UIA-v2\Lib\UIA_Browser.ahk"
#Include "lib\figuredart-product-creation.ahk"
#Include "Helpers\Text.ahk"
#Include "CMS\MatrixRows.ahk"
#Include "SEO\OutputParsing.ahk"
#Include "SEO\Validation.ahk"
#Include "prompts\Builders.ahk"
#Include "Helpers\SupplierFiles.ahk"
#Include "Core\ModeRegistry.ahk"
#Include "Core\WorkflowState.ahk"
#Include "Core\RunArtifacts.ahk"
#Include "Core\Diagnostics.ahk"

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
; - Stops before sending in ordinary and matrix modes unless full workflow automation is enabled; supplier-creation modes submit after their attachment timer.
; - Uses ChatGPT's latest response Copy button and extracts its automation block.
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
; chatgptWinTitle := "Colour & Glaze"
chatgptWinTitle := "Tools"
departmentChatgptWinTitle := "Tools"
; chatgptWinTitle := "Arts & Crafts"
; chatgptWinTitle := "Opt"

; Available modes:
; "full" = current existing workflow
; "department" = full-content review workflow using the separate department prompt;
; Ctrl+Alt+A optionally makes Numpad4 submit and complete automatically;
; the main product always remains unsaved for review
; "metadata" = metadata and image SEO
; "image" = image SEO for one ordinary product
; "matrix_image" = image SEO for every child of one matrix product
; "matrix_full" = parent metadata plus child HTML and image SEO for one matrix product
; "botz" = BOTZ Product Creation from the matching C:\BOTZ product folder
; "figuredart" = Figured'Art Product Creation from the matching C:\FiguredArt product folder
; "promotion_text" = paste the configured promotional text into Description and Custom
; "promotion_text_reference" = find every Simple Product (Reference) on the
; current catalogue page, reopen each by stock-code search and paste the same text
; This is the fallback used by older settings files. Saving the
; Ctrl+Shift+NumLock menu persists the selected mode and its active prompt
; across reloads.
SeoAutomationMode := "full"
; Prompt choices are scoped to their owning mode. The saved prompt ID is
; validated against that mode before a template can be loaded.
SeoPromptId := "full_standard"

; PROMOTION TEXT TEST-SAVE SWITCH: change false to true to click the main
; product Save button and allow promotion_text and promotion_text_reference runs.
promotionTextSaveEnabled := true

promptDir := A_ScriptDir "\prompts"
FullPromptTemplatePath := promptDir "\prompt-template.md"
FullToolsPromptTemplatePath := promptDir "\prompt-template-tools-products.md"
DepartmentPromptTemplatePath := promptDir "\prompt-template-department.md"
MetadataPromptTemplatePath := promptDir "\prompt-template-metadata-only.md"
ImageOnlyPromptTemplatePath := promptDir "\prompt-template-image-only.md"
MatrixImagePromptTemplatePath := promptDir "\prompt-template-matrix-image.md"
MatrixFullPromptTemplatePath := promptDir "\prompt-template-matrix-full.md"
; BotzPromptTemplatePath := promptDir "\prompt-template-botz.md"
BotzPromptTemplatePath := promptDir "\prompt-template-botz-engobes.md"
FiguredArtDefaultPromptTemplatePath := promptDir "\prompt-template-figuredart.md"
; The supplier library reads this active path directly so it remains usable by
; its standalone tests. ApplySharedSeoPromptSettings keeps it in sync with the
; mode-scoped prompt selection.
FiguredArtPromptTemplatePath := FiguredArtDefaultPromptTemplatePath

; Kept as a familiar reference for the existing full workflow.
; promptTemplatePath := MetadataPromptTemplatePath
logDir := A_ScriptDir "\logs"
backupDir := A_ScriptDir "\backups"
stateDir := A_ScriptDir "\state"
debugDir := A_ScriptDir "\debug"
matrixStateFilePath := stateDir "\matrix-image-state.txt"
matrixFullStateFilePath := stateDir "\matrix-full-state.txt"
botzStateFilePath := stateDir "\botz-product-state.txt"
figuredArtStateFilePath := stateDir "\figuredart-product-state.txt"
botzPromptSettingsFilePath := stateDir "\botz-prompt-settings.txt"
botzRootDir := "C:\BOTZ\engobes"
figuredArtRootDir := "C:\FiguredArt"
botzFilePickerTimeoutMs := 10000
botzChatPickerFolderLoadMs := 2500
botzChatPickerSelectAllMs := 1500
botzChatAttachmentSettleMs := 10000
botzImagesTabLoadMs := 1500
botzImageDetailsLoadMs := 2500
matrixNavigationDelayMs := 5000
matrixReturnDelayMs := 5000
matrixFullyReopenParentAfterReturn := true
matrixParentReopenDelayMs := 5000
matrixSkuTabSettleDelayMs := 5000
matrixCatalogueSearchTimeoutMs := 20000
matrixCatalogueScrollSettleDelayMs := 3000
matrixPageWaitTimeoutMs := 20000
matrixStableDurationMs := 1000
matrixUiaSearchTimeoutMs := 15000
matrixScrollWheelNotchesPerStep := 5
matrixMaxScrollSteps := 30
matrixNoNewRowsStopCount := 3
global matrixState := 0
global matrixFullState := 0
global botzState := 0
global figuredArtState := 0
global botzPromptSettings := 0
global botzPromptSettingsGui := 0
global promotionText := ""
global activeMatrixParentProductName := ""
global activeCmsProductCode := ""
global lastSavedNonMatrixProductIdentity := 0
global automaticWorkflowActive := false
global automaticWorkflowCancelRequested := false
global automaticWorkflowManualCompletion := false
global automaticWorkflowCmsInsertionActive := false
global departmentAutomationActive := false
global departmentStopAfterCurrent := false
global LastEditButtons := []
global LastDocument := 0
global testingModeEnabled := false
global testingSessionLogPath := ""
global testingSessionId := ""
global testingArtifactSequence := 0

; Public product/category URL for {PAGE_URL} in every ChatGPT prompt. All modes
; load the shared saved value from state\botz-prompt-settings.txt at startup.
botzDefaultPageUrl := "https://www.cromartiehobbycraft.co.uk/Catalogue/Ceramic-Glazes-Ceramic-Underglazes-for-Pottery-Painting/Fired-Colour-Pottery-Glazes-Underglazes/Botz-Earthenware-Glazes-800ml/..."
hardcodedPageUrl := botzDefaultPageUrl

; Try to copy/paste the product image into ChatGPT after the prompt is pasted.
; The script still stops before sending so you can confirm the image attached correctly.
attemptImageCopyAfterPrompt := true

; Fallback value used only until the Images tab is scanned with UIA-v2.
; Every workflow now replaces this automatically from the Image Gallery cards.
imageCountToProcess := 1
; GO b2b permits at most 11 image records per product. Every workflow caps its
; automation output, parser and CMS image work to the first 11 images. Supplier
; modes may attach later images to ChatGPT as reference context only.
maximumImagesPerProduct := 11

; Image/card coordinates for the five slots visible on each Images-tab page.
; Global image indices are mapped to these reusable slots and the gallery's
; Next button is used for image 6 and above. Each entry needs:
; - image: point on the image itself, used for copying/pasting into ChatGPT
; - details_button: the button that opens the image tags/details screen
imageTargets := [
    Map("image", [399, 454], "details_button", [319, 555]),
    Map("image", [645, 451], "details_button", [571, 552]),
    Map("image", [896, 460], "details_button", [820, 554]), ; x: 896, y: 460 x: 820, y: 554
    Map("image", [1160, 459], "details_button", [1074, 551]), ; x: 1160, y: 459 x: 1074, y: 551
    Map("image", [1399, 459], "details_button", [1324, 552]) ; x: 1399, y: 459 x: 1324, y: 552
]
imageGalleryPageSize := 5
imageGalleryMaxPages := 100
imageGalleryNextPageDelayMs := 300
imageGalleryPreviousPageDelayMs := 300
imageGalleryPageChangeTimeoutMs := 5000
imageGalleryFirstPageNoChangeTimeoutMs := 2000
imageGalleryAvailabilityTimeoutMs := 15000
; Give Chrome a brief render window after opening Images before the first UIA read.
imageAccessibilityTreeInitialDelayMs := 2000
imageGalleryCountTimeoutMs := 20000
imageGalleryCountStableDurationMs := 2000
; A later carousel page can remain absent from UIA indefinitely until it is
; visited, so waiting longer on page 1 cannot reliably reveal image 11. The
; detector now visits every available page and keeps the highest realised card
; total; two seconds per page is enough to reject a transient partial render.
imageGalleryMinimumObservationMs := 2000

; High-quality image copy settings.
; Process used for each image:
; 1. Click the original image thumbnail/card listed in imageTargets.
; 2. Copy the larger/high-quality preview image from this point.
; Keep this enabled so ChatGPT receives the clearer image rather than the small thumbnail.
copyHighQualityImagePreview := true
highQualityImageCopyPoint := [635, 687] ; x: 635, y: 687
highQualityImagePreviewLoadDelayMs := 450
imageCopyPreCopyDelayMs := 1000
imageTabLoadDelayMs := 500

; false = do not silently fall back to the old low-quality thumbnail copy if
; the high-quality preview copy fails. Set to true only if you prefer an
; automatic low-quality fallback instead of manually attaching the image.
allowThumbnailImageCopyFallback := false

; Toggle with Ctrl + Alt + N.
; false = do not paste ChatGPT product name recommendation.
; true = paste the recommendation into the Product Name field when Ctrl + Alt + O runs.
useRecommendedProductName := true

; Chrome/Edge image context menu shortcut. On many Windows Chrome installs, "y" triggers Copy image.
; This is the primary image-copy path. If it selects the wrong item, change the shortcut here.
imageContextCopyKey := "y"

; ChatGPT paste reliability settings.
; These help when Chrome/ChatGPT is inactive, slow to focus, or drops the first Ctrl+V.
chatPasteRetries := 3
chatWakeDelayMs := 900
chatPasteVerifyDelayMs := 900
chatResponseCopyTimeoutMs := 5000
chatResponseScrollNotches := 100
chatResponseRecoveryPageUpCount := 2
chatResponseRecoveryPageDownCount := 20
chatResponseCopyButtonPoint := [2230, 902]
chatResponseInitialWaitMs := 120000
chatResponsePollIntervalMs := 30000
imageOnlyChatResponseInitialWaitMs := 60000
imageOnlyChatResponsePollIntervalMs := 15000
chatImageWindowWakeDelayMs := 250
chatImageFocusDelayMs := 250
chatImageAttachmentTimeoutMs := 5000
chatImageAttachmentPollIntervalMs := 150
chatImageAttachmentSettleMs := 400
chatImagePasteFallbackDelayMs := 1000
chatSubmitPreEnterDelayMs := 10000
cmsImageDetailsButtonTimeoutMs := 5000
cmsImageDetailsFormTimeoutMs := 5000
cmsImageDetailsOpenAttempts := 2
cmsImageGalleryReturnTimeoutMs := 7000
cmsImageGalleryReturnSettleMs := 500

; Ctrl+Alt+A toggles this. Keep it off by default so Numpad4, NumpadEnter and
; Numpad6 retain their existing manual workflow until automation is requested.
fullWorkflowAutomationEnabled := false

; Ctrl+Alt+D toggles department automation. Ctrl+Numpad4 starts from the
; already-open first product; Ctrl+Numpad6 requests a stop after that product.
departmentAutomationEnabled := false
departmentCatalogueWaitMs := 10000
departmentCatalogueTreeTimeoutMs := 25000
departmentProductOpenDelayMs := 10000
promotionReferenceSearchTimeoutMs := 20000
promotionReferenceProductOpenDelayMs := 5000
promotionReferenceCatalogueReturnDelayMs := 2500
promotionReferenceScanMaxScrollSteps := 100
promotionReferenceScanNoChangeStopCount := 3
promotionReferenceScanWheelNotches := 5
global promotionReferenceBatchActive := false
global promotionReferenceStopAfterCurrent := false

; Coordinates from docs\config-notes.md
coords := Map(
    ; Initial CMS page
    "product_edit_button", [1437, 310],
    "catalogue_product_list_scan_anchor", [1000, 700],
    "catalogue_search_input", [1649, 264],
    "catalogue_search_button", [1836, 326],
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
    "stock_code", [456, 484],
    ; Description tab
    "meta_title", [874, 383],
    "html_snippet", [876, 553],
    "meta_description", [900, 806],
    "promotion_description_field", [837, 861],
    ; Custom tab
    "custom_tab", [1263, 260],
    "promotion_custom_field", [932, 373],
    ; Images tab
    "image", [399, 454],
    "image_details_button", [319, 555],
    "image_gallery_previous_button", [309, 480],
    "image_gallery_next_button", [1583, 476],
    "image_add_button", [307, 343],
    ; Image details page
    "image_name", [945, 555],
    "image_title", [921, 620],
    "image_alt", [948, 684],
    "image_save_button", [1250, 734],
    ; ChatGPT
    "chat_input", [2323, 1018],
    "chat_add_button", [2246, 1026],
    "chat_add_attachments_button", [2393, 566]
    ; "chat_input", [2102, 972] ; x: 2102, y: 972
)

requiredInternalLinksDefault := "N/A"
additionalProductNotesDefault := "N/A"

InitialiseSeoPromptSettings()
OnError(LogUnhandledErrorForTesting)
OnExit(LogTestingSessionExit)

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
^!a:: ToggleFullWorkflowAutomation()
^!d:: ToggleDepartmentAutomation()
^Numpad4:: StartDepartmentAutomation()
^Numpad6:: RequestDepartmentStopAfterCurrent()
^+NumLock:: OpenSeoPromptSettingsGui()
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
; ^!o:: RunManualChatGptOutputPaste()
Numpad6:: RunManualChatGptOutputPaste()
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
    global useRecommendedProductName, SeoAutomationMode, SeoPromptId, imageCountToProcess
    global fullWorkflowAutomationEnabled, automaticWorkflowActive
    global departmentAutomationEnabled, departmentAutomationActive
    global departmentStopAfterCurrent, testingModeEnabled, testingSessionLogPath
    nameMode := useRecommendedProductName ? "ON" : "OFF"
    automationMode := fullWorkflowAutomationEnabled ? "ON" : "OFF"
    automationLabel := IsDepartmentMode()
        ? "Department Numpad4 + Numpad6 automation"
        : "Full workflow automation"
    automationStatus := automaticWorkflowActive
        ? (departmentAutomationActive ? "active inside department run" : "currently waiting/running")
        : "idle"
    departmentMode := departmentAutomationEnabled ? "ON" : "OFF"
    departmentStatus := departmentAutomationActive
        ? (departmentStopAfterCurrent ? "stopping after current product" : "running")
        : "idle"
    testingStatus := testingModeEnabled ? "ON" : "OFF"
    testingLog := testingModeEnabled && testingSessionLogPath != "" ? testingSessionLogPath : "none"
    savedCount := 0
    savedMode := "none"
    try {
        savedState := LoadMatrixState()
        savedCount := savedState["productCount"]
        savedMode := savedState["mode"]
    }
    MsgBox "SEO mode: " SeoAutomationMode
        . "`nSEO prompt: " SeoPromptId " (" GetSeoPromptLabel(GetSeoAutomationMode(), GetSeoPromptId()) ")"
        . "`nImages: " imageCountToProcess
        . "`nRecommended product-name insertion: " nameMode
        . "`n" automationLabel " (Ctrl+Alt+A): " automationMode " (" automationStatus ")"
        . "`nDepartment automation (Ctrl+Alt+D): " departmentMode " (" departmentStatus ")"
        . "`nTesting diagnostics: " testingStatus
        . "`nTesting session log: " testingLog
        . "`nDepartment start: Ctrl+Numpad4"
        . "`nDepartment stop after current product: Ctrl+Numpad6"
        . "`nUIA-v2 matrix support: available"
        . "`nSaved matrix state: " savedMode
        . "`nSaved matrix children: " savedCount
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

ToggleFullWorkflowAutomation() {
    global fullWorkflowAutomationEnabled, automaticWorkflowCancelRequested
    global departmentAutomationActive
    fullWorkflowAutomationEnabled := !fullWorkflowAutomationEnabled
    if !fullWorkflowAutomationEnabled && !departmentAutomationActive
        automaticWorkflowCancelRequested := true
    mode := fullWorkflowAutomationEnabled ? "ON" : "OFF"
    message := (IsDepartmentMode() ? "Department Numpad4 + Numpad6 automation: " : "Full workflow automation: ") mode
    if !fullWorkflowAutomationEnabled && departmentAutomationActive
        message .= "`nThe active department run is unaffected; use Ctrl+Numpad6 to stop it after the current product."
    else if IsDepartmentMode() {
        if fullWorkflowAutomationEnabled
            message .= "`nNumpad4 will submit, wait and insert the result automatically. The product will remain unsaved."
        else
            message .= "`nNumpad4 will prepare the prompt and images only. Press Numpad6 manually when the response is ready."
    } else if !fullWorkflowAutomationEnabled
        message .= "`nAny active ChatGPT wait will stop safely."
    Flash(message, 2500)
}

ToggleDepartmentAutomation() {
    global departmentAutomationEnabled, departmentAutomationActive
    global departmentStopAfterCurrent
    if IsDepartmentMode() {
        departmentAutomationEnabled := false
        Flash("Department-wide automation is unavailable in department review mode.`nOpen one product and press Numpad4 instead.", 3500)
        return
    }
    departmentAutomationEnabled := !departmentAutomationEnabled
    if !departmentAutomationEnabled && departmentAutomationActive
        departmentStopAfterCurrent := true
    mode := departmentAutomationEnabled ? "ON" : "OFF"
    message := "Department automation: " mode
    if !departmentAutomationEnabled && departmentAutomationActive
        message .= "`nThe current product will finish, then the department run will stop."
    else if departmentAutomationEnabled
        message .= "`nStart from the first " GetDepartmentProductTypeForSeoMode() " Overview with Ctrl+Numpad4."
    Flash(message, 3000)
}

RequestDepartmentStopAfterCurrent() {
    global departmentAutomationActive, departmentStopAfterCurrent
    global promotionReferenceBatchActive, promotionReferenceStopAfterCurrent
    if promotionReferenceBatchActive {
        promotionReferenceStopAfterCurrent := true
        Flash("Reference promotion-text stop requested.`nThe current product will finish and save first.", 3000)
        return true
    }
    if !departmentAutomationActive {
        Flash("No department automation run is active.", 2000)
        return false
    }
    departmentStopAfterCurrent := true
    Flash("Department stop requested.`nThe current product will finish and save first.", 3000)
    return true
}

SetImageCountToProcess(imageCount) {
    global imageCountToProcess, maximumImagesPerProduct

    if imageCount < 0 {
        Flash("Image count cannot be negative.")
        return false
    }

    requestedCount := imageCount
    imageCountToProcess := Min(imageCount, maximumImagesPerProduct)
    message := "Prompt/CMS image count set to " imageCountToProcess "."
    if requestedCount > maximumImagesPerProduct
        message .= "`nOnly the first " maximumImagesPerProduct " images can be processed per product."
    Flash(message)
    return true
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

        if IsPromotionTextReferenceMode() {
            RunPromotionTextReferenceWorkflow()
            return
        }

        if IsMatrixImageMode()
            throw Error("NumpadEnter is not used for matrix-image mode. Open the matrix parent and press Numpad4.")

        ClickPoint("product_edit_button", 1500)
        if IsPromotionTextMode() {
            RunPromotionTextWorkflow()
            return
        } else if IsSupplierProductCreationMode()
            BuildSupplierProductCreationPrompt(pageUrl)
        else if IsMatrixFullMode()
            BuildMatrixFullPrompt(pageUrl)
        else
            BuildPromptFromCurrentProductPage(pageUrl)
        RunAutomaticWorkflowIfEnabled(IsSupplierProductCreationMode())
    } catch as err {
        ReportTestingError("open-product-workflow", err)
        MsgBox "OpenProductBuildPromptAndPasteToChatGPT failed:`n`n" err.Message
    }
}

; ==========================================================
; HOTKEY 1B - START FROM ALREADY-OPEN PRODUCT PAGE
; ==========================================================

BuildPromptFromOpenProductPageAndPasteToChatGPT() {
    try {
        return RunOpenProductWorkflow(false)
    } catch as err {
        ReportTestingError("open-current-product-workflow", err)
        MsgBox "BuildPromptFromOpenProductPageAndPasteToChatGPT failed:`n`n" err.Message
        return false
    }
}

RunOpenProductWorkflow(forceAutomaticCompletion := false) {
    global cmsWinTitle, hardcodedPageUrl

    EnsureFolders()
    ActivateWindow(cmsWinTitle)

    ; Use the temporary hardcoded public URL for {{PAGE_URL}}. Do not copy the
    ; browser URL because the active page is a GO b2b CMS URL.
    pageUrl := hardcodedPageUrl
    if IsPromotionTextReferenceMode()
        return RunPromotionTextReferenceWorkflow()
    if IsPromotionTextMode()
        return RunPromotionTextWorkflow()
    if IsSupplierProductCreationMode()
        BuildSupplierProductCreationPrompt(pageUrl)
    else if IsMatrixFullMode()
        BuildMatrixFullPrompt(pageUrl)
    else if IsMatrixImageMode()
        BuildMatrixImagePrompt(pageUrl)
    else
        BuildPromptFromCurrentProductPage(pageUrl, forceAutomaticCompletion)
    return RunAutomaticWorkflowIfEnabled(IsSupplierProductCreationMode(), forceAutomaticCompletion)
}

; ==========================================================
; BUILD PROMPT FROM CURRENT PRODUCT PAGE
; ==========================================================

BuildPromptFromCurrentProductPage(pageUrl, forceAutomaticCompletion := false) {
    global cmsWinTitle, chatgptWinTitle, SeoAutomationMode
    global requiredInternalLinksDefault, additionalProductNotesDefault
    global attemptImageCopyAfterPrompt, imageCountToProcess

    ValidateSeoAutomationMode()
    if IsDepartmentMode()
        imageCountToProcess := 1
    ClearActiveCmsProductCode()
    ActivateWindow(cmsWinTitle)
    ValidateImageTargetConfig()

    ; Overview tab: exact GO b2b identity and product name. Department review
    ; mode intentionally identifies the product by name and never reads Stock Code.
    ClickPoint("overview_tab", 500)
    productName := CopyFromPoint("product_name")
    if IsDepartmentMode()
        SetActiveCmsProductCode(productName)
    else
        SetActiveCmsProductCode(CopyFromPoint("stock_code"))
    TestingLog(
        "product-workflow-start",
        "Product name=" productName "; mode=" GetSeoAutomationMode() "; page_url=" pageUrl "."
    )

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

    ; Department review products always have one image, so avoid reading the GO
    ; b2b gallery tree and use the configured first-image coordinates instead.
    if IsDepartmentMode()
        TestingLog("department-image-count", "Using fixed image count=1 and configured coordinates; gallery UIA detection was skipped.")
    else {
        ; Count actual gallery cards from their exact Remove buttons. Image labels
        ; are deliberately ignored because GO B2B can skip label numbers.
        DetectAndSetImageCountFromImagesTab()
    }

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
        imagesReady := TryCopyCmsImagesToChatGPT(false)
        if (IsAutomaticWorkflowExecutionEnabled() || forceAutomaticCompletion) && !imagesReady
            throw Error("Automatic workflow stopped before sending because one or more CMS images could not be pasted into ChatGPT.")
        Flash("Prompt pasted. Image copy attempted.")
        return
    }

    Flash("Prompt pasted. Attach image manually.")
}

; ==========================================================
; MODE AND PROMPT TEMPLATE HELPERS
; ==========================================================

GetChatGptWinTitle() {
    global chatgptWinTitle, departmentChatgptWinTitle
    return IsDepartmentMode() ? departmentChatgptWinTitle : chatgptWinTitle
}

BuildSupplierProductCreationPrompt(pageUrl) {
    if IsBotzMode()
        return BuildBotzPrompt(pageUrl)
    if IsFiguredArtMode()
        return BuildFiguredArtPrompt(pageUrl)
    throw Error("The current SEO mode is not a supplier product-creation mode.")
}

; ==========================================================
; DYNAMIC IMAGE OUTPUT PROMPT SUPPORT
; ==========================================================

; ==========================================================
; RELIABLE CHATGPT PROMPT PASTE
; ==========================================================

PastePromptToChatGPT(prompt) {
    global chatgptWinTitle, chatPasteRetries

    lastProblem := ""

    Loop chatPasteRetries {
        try {
            ActivateWindow(GetChatGptWinTitle(), 900)
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

; Backwards-compatible wrapper retained for older/manual callers.
WakeChatGptInput() {
    FocusChatGptInputForPaste()
}

FocusChatGptInputForImagePaste() {
    global chatImageFocusDelayMs

    ; During an image batch ChatGPT is already awake and the draft already
    ; exists, so one short focus click is sufficient. The slower two-click wake
    ; sequence remains in place for the initial large prompt paste.
    ClickPoint("chat_input", chatImageFocusDelayMs)
    Sleep 100
}

GetChatGptDraftAttachmentCount() {
    try {
        document := UIA_Browser().GetCurrentDocumentElement()
        buttons := document.FindElements({ Name: "Remove file", Type: "Button", mm: 2, cs: 0 })
        count := 0
        for _, button in buttons {
            try {
                if RegExMatch(Trim(button.Name), "i)^Remove file\s+\d+:")
                    count += 1
            }
        }
        return count
    } catch as err {
        TestingLog("chatgpt-attachment-count-error", FormatTestingError(err))
        return -1
    }
}

WaitForChatGptDraftAttachmentCount(expectedCount) {
    global chatImageAttachmentTimeoutMs, chatImageAttachmentPollIntervalMs, chatImageAttachmentSettleMs

    startedAt := A_TickCount
    deadline := startedAt + chatImageAttachmentTimeoutMs
    lastCount := -1
    Loop {
        count := GetChatGptDraftAttachmentCount()
        if count != lastCount {
            TestingLog(
                "chatgpt-attachment-count",
                "Expected=" expectedCount "; detected=" count "; elapsed_ms=" (A_TickCount - startedAt) "."
            )
            lastCount := count
        }
        if count >= expectedCount {
            Sleep chatImageAttachmentSettleMs
            confirmedCount := GetChatGptDraftAttachmentCount()
            if confirmedCount >= expectedCount {
                TestingLog(
                    "chatgpt-attachment-ready",
                    "Expected=" expectedCount "; detected=" confirmedCount "; elapsed_ms=" (A_TickCount - startedAt) "."
                )
                return true
            }
        }
        if A_TickCount >= deadline {
            TestingLog(
                "chatgpt-attachment-timeout",
                "Expected=" expectedCount "; last_detected=" lastCount "; timeout_ms=" chatImageAttachmentTimeoutMs "."
            )
            return false
        }
        Sleep chatImageAttachmentPollIntervalMs
    }
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
    global imageCountToProcess, chatgptWinTitle, chatImageWindowWakeDelayMs

    try {
        if imageCountToProcess < 1
            return true

        successCount := 0
        batchStartedAt := A_TickCount
        TestingLog("chatgpt-image-batch-start", "Starting " imageCountToProcess " CMS image copy/paste attempt(s).")

        ; The prompt can appear in ChatGPT as one draft file tile. Measure the
        ; current draft first, then verify that each image adds exactly one more
        ; attachment instead of waiting a long fixed delay after every Ctrl+V.
        ActivateWindow(GetChatGptWinTitle(), chatImageWindowWakeDelayMs)
        attachmentBaseline := GetChatGptDraftAttachmentCount()
        TestingLog("chatgpt-attachment-baseline", "Draft attachment count before CMS images: " attachmentBaseline ".")

        ; Open and rewind the gallery once. Images are ordered left-to-right in
        ; groups of five, so the batch can move forward only at images 6 and 11
        ; instead of reopening page 1 for every individual image.
        PrepareCmsImageGalleryForSequentialCopy()

        Loop imageCountToProcess {
            expectedAttachmentCount := attachmentBaseline >= 0 ? attachmentBaseline + successCount + 1 : -1
            if TryCopyCmsSingleImageToChatGPT(A_Index, false, true, expectedAttachmentCount)
                successCount += 1
            else {
                TestingLog("chatgpt-image-batch-stopped", "Stopped after " successCount " successful image(s); image " A_Index " failed.")
                break
            }
            Sleep 100
        }

        if showResult {
            if successCount = imageCountToProcess
                Flash("Image paste attempted for " successCount " image(s).")
            else
                Flash("Image paste attempted for " successCount " of " imageCountToProcess " image(s).")
        }

        TestingLog(
            "chatgpt-image-batch-complete",
            "Successful attempts: " successCount " of " imageCountToProcess
            . "; elapsed_ms=" (A_TickCount - batchStartedAt) "."
        )
        SaveTestingAccessibilityTree("chatgpt-after-" successCount "-of-" imageCountToProcess "-image-pastes")
        return successCount = imageCountToProcess
    } catch as err {
        ReportTestingError("chatgpt-image-batch", err)
        if showResult
            MsgBox "TryCopyCmsImagesToChatGPT failed:`n`n" err.Message
        return false
    }
}

; Backwards-compatible helper: copies image 1 only.
TryCopyCmsImageToChatGPT(showResult := true) {
    return TryCopyCmsSingleImageToChatGPT(1, showResult)
}

TryCopyCmsSingleImageToChatGPT(imageIndex := 1, showResult := true, sequentialGallery := false, expectedChatAttachmentCount := -1) {
    global chatgptWinTitle, imageGalleryPageSize
    global chatImageWindowWakeDelayMs, chatImagePasteFallbackDelayMs

    try {
        imageStartedAt := A_TickCount
        TestingLog(
            "chatgpt-image-start",
            "Image " imageIndex "; gallery_page=" GetImageGalleryPageForIndex(imageIndex)
            . "; gallery_slot=" (Mod(imageIndex - 1, imageGalleryPageSize) + 1) "."
        )
        imageCopied := CopyCmsImageToClipboard(imageIndex, sequentialGallery)

        if !imageCopied {
            TestingLog("chatgpt-image-copy-failed", "Image " imageIndex " did not reach the clipboard.")
            if showResult
                Flash("Image " imageIndex " copy failed. Attach manually.")
            return false
        }

        ActivateWindow(GetChatGptWinTitle(), chatImageWindowWakeDelayMs)
        FocusChatGptInputForImagePaste()
        Send "^v"
        if expectedChatAttachmentCount >= 0 {
            if !WaitForChatGptDraftAttachmentCount(expectedChatAttachmentCount) {
                TestingLog(
                    "chatgpt-image-paste-unverified",
                    "Image " imageIndex " did not raise the draft attachment count to " expectedChatAttachmentCount "."
                )
                return false
            }
        } else
            Sleep chatImagePasteFallbackDelayMs
        TestingLog(
            "chatgpt-image-paste",
            "Image " imageIndex " was copied and verified in ChatGPT; elapsed_ms=" (A_TickCount - imageStartedAt) "."
        )

        if showResult
            Flash("Image " imageIndex " paste attempted.")

        return true
    } catch as err {
        ReportTestingError("chatgpt-image-" imageIndex, err)
        if showResult
            MsgBox "TryCopyCmsSingleImageToChatGPT failed for image " imageIndex ":`n`n" err.Message
        return false
    }
}

PrepareCmsImageGalleryForSequentialCopy() {
    global cmsWinTitle

    startedAt := A_TickCount
    ActivateWindow(cmsWinTitle, 100)
    if IsDepartmentMode() {
        OpenDepartmentImageGalleryByCoordinates("image-copy")
        TestingLog(
            "image-gallery-sequential-ready",
            "Department mode opened the one-image gallery by configured coordinates; UIA gallery discovery was skipped."
        )
        return
    }
    OpenFirstImageGalleryPage()
    TestingLog(
        "image-gallery-sequential-ready",
        "Gallery prepared on page 1 for sequential image copying; elapsed_ms=" (A_TickCount - startedAt) "."
    )
}

OpenDepartmentImageGalleryByCoordinates(context := "department-image") {
    global cmsWinTitle, imageTabLoadDelayMs

    ActivateWindow(cmsWinTitle, 100)
    ClickPoint("images_tab", imageTabLoadDelayMs)
    TestingLog(
        "department-image-gallery-coordinate-open",
        "Context=" context "; fixed image count=1; Images tab opened through configured coordinates."
    )
}

CopyCmsImageToClipboard(imageIndex := 1, sequentialGallery := false) {
    global cmsWinTitle, imageContextCopyKey, copyHighQualityImagePreview, allowThumbnailImageCopyFallback
    global imageGalleryPageSize, imageCopyPreCopyDelayMs

    ActivateWindow(cmsWinTitle, sequentialGallery ? 100 : 300)
    if sequentialGallery {
        if imageIndex > 1 && Mod(imageIndex - 1, imageGalleryPageSize) = 0 {
            targetPage := GetImageGalleryPageForIndex(imageIndex)
            TestingLog("image-gallery-sequential-advance", "Advancing to page " targetPage " for image " imageIndex ".")
            if !TryAdvanceImageGalleryPage()
                throw Error("Could not advance the sequential Image Gallery batch to page " targetPage " for image " imageIndex ".")
        }
    } else
        OpenImageGalleryPageForIndex(imageIndex)

    ; Give the selected carousel page and its image resource one final second
    ; to settle before opening/copying the preview. This is deliberately applied
    ; to every image, including images that do not cross a page boundary.
    TestingLog("image-copy-pre-delay", "Image " imageIndex "; delay_ms=" imageCopyPreCopyDelayMs ".")
    Sleep imageCopyPreCopyDelayMs

    ; The testing trace showed that Ctrl+C on the high-quality preview failed
    ; for every image, while the context-menu Copy image shortcut succeeded for
    ; every image. Use that successful route directly.
    if copyHighQualityImagePreview {
        if CopyHighQualityPreviewByContextMenuKey(imageIndex, imageContextCopyKey)
            return true

        ; Avoid silently attaching the old low-quality thumbnail unless the
        ; manual fallback setting is enabled near the top of this file.
        if !allowThumbnailImageCopyFallback
            return false
    }

    ; The optional thumbnail fallback also uses the proven context-menu route;
    ; there is deliberately no preliminary Ctrl+C attempt anywhere in this flow.
    if CopyImageByContextMenuKey(imageIndex, imageContextCopyKey)
        return true

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
    Sleep 100
    Click "Right"
    Sleep 300
    Send copyKey

    if ClipWait(3, true) {
        TestingLog("image-clipboard-copy", "Image " imageIndex " copied from the high-quality preview with the context-menu shortcut.")
        return true
    }

    TestingLog("image-clipboard-copy-miss", "Image " imageIndex " high-quality context-menu attempt did not produce clipboard data.")
    Send "{Esc}"
    A_Clipboard := savedClip
    return false
}

SelectCmsImageForPreview(imageIndex := 1) {
    target := GetImageTarget(imageIndex)
    ClickCoordinates(target["image"], 300)
}

CopyImageByContextMenuKey(imageIndex, copyKey) {
    savedClip := ClipboardAll()
    A_Clipboard := ""
    Sleep 100

    target := GetImageTarget(imageIndex)
    point := target["image"]
    MouseMove point[1], point[2]
    Sleep 100
    Click "Right"
    Sleep 300
    Send copyKey

    if ClipWait(3, true) {
        return true
    }

    Send "{Esc}"
    A_Clipboard := savedClip
    return false
}

GetImageTarget(imageIndex) {
    global imageTargets, imageGalleryPageSize

    if imageIndex < 1
        throw Error("Image indices must start at 1; received " imageIndex ".")
    if imageTargets.Length != imageGalleryPageSize
        throw Error("imageTargets must contain exactly " imageGalleryPageSize " reusable gallery-slot coordinate entries.")

    slotIndex := Mod(imageIndex - 1, imageGalleryPageSize) + 1
    return imageTargets[slotIndex]
}

GetImageGalleryPageForIndex(imageIndex) {
    global imageGalleryPageSize
    if imageIndex < 1
        throw Error("Image indices must start at 1; received " imageIndex ".")
    return Floor((imageIndex - 1) / imageGalleryPageSize) + 1
}

OpenFirstImageGalleryPage() {
    global imageTabLoadDelayMs, imageGalleryMaxPages, imageAccessibilityTreeInitialDelayMs

    ; GO b2b preserves the current gallery page when the Images tab is clicked.
    ; Wait adaptively for the tab's UIA subtree before attempting pagination,
    ; then walk backwards until Previous no longer changes the page.
    ClickPoint("images_tab", imageTabLoadDelayMs)
    ToolTip "Waiting for the Images tab to settle before reading its accessibility tree..."
    TestingLog("image-gallery-pre-uia-delay", "Delay_ms=" imageAccessibilityTreeInitialDelayMs ".")
    Sleep imageAccessibilityTreeInitialDelayMs
    WaitForImageGalleryAvailable()
    Loop imageGalleryMaxPages {
        if !TryReturnToPreviousImageGalleryPage()
            return
        if A_Index = imageGalleryMaxPages
            throw Error("Could not return to the first Image Gallery page within the " imageGalleryMaxPages "-page safety limit.")
    }
}

WaitForImageGalleryAvailable(timeoutMs := 0) {
    global LastDocument, imageGalleryAvailabilityTimeoutMs

    effectiveTimeoutMs := timeoutMs > 0 ? timeoutMs : imageGalleryAvailabilityTimeoutMs
    startedAt := A_TickCount
    deadline := startedAt + effectiveTimeoutMs
    attempt := 0
    lastProblem := "Image Gallery has not appeared yet."

    Loop {
        attempt += 1
        ToolTip "Waiting for the Images tab accessibility tree..."
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            LastDocument := document
            gallery := FindImageGalleryScope(document)
            if gallery {
                TestingLog(
                    "image-gallery-available",
                    "UIA gallery became available after " (A_TickCount - startedAt) " ms on attempt " attempt "."
                )
                ToolTip()
                return gallery
            }
            lastProblem := "The browser document was available, but the Image Gallery scope was absent."
        } catch as err {
            lastProblem := FormatTestingError(err)
        }

        if A_TickCount >= deadline {
            ToolTip()
            TestingLog("image-gallery-availability-timeout", lastProblem)
            SaveTestingAccessibilityTree("image-gallery-availability-timeout")
            throw Error(
                "The Images tab accessibility tree did not become available within " effectiveTimeoutMs " ms."
                . "`n`nLast UIA result: " lastProblem
                . "`n`nLeave the Images tab open and press F9 to dump the tree."
            )
        }
        Sleep 250
    }
}

OpenImageGalleryPageForIndex(imageIndex) {
    targetPage := GetImageGalleryPageForIndex(imageIndex)
    OpenFirstImageGalleryPage()

    if targetPage > 1 {
        Loop targetPage - 1 {
            if !TryAdvanceImageGalleryPage()
                throw Error("Could not reach Image Gallery page " targetPage " for image " imageIndex ". The gallery ended on page " A_Index ".")
        }
    }
}

TryAdvanceImageGalleryPage() {
    global imageGalleryNextPageDelayMs

    return TryMoveImageGalleryPage(
        "image_gallery_next_button",
        "Next",
        imageGalleryNextPageDelayMs
    )
}

TryReturnToPreviousImageGalleryPage() {
    global imageGalleryPreviousPageDelayMs, imageGalleryFirstPageNoChangeTimeoutMs

    return TryMoveImageGalleryPage(
        "image_gallery_previous_button",
        "Previous",
        imageGalleryPreviousPageDelayMs,
        imageGalleryFirstPageNoChangeTimeoutMs
    )
}

TryMoveImageGalleryPage(buttonCoordinateName, directionLabel, clickDelayMs, noChangeTimeoutMs := 0) {

    document := UIA_Browser().GetCurrentDocumentElement()
    gallery := FindImageGalleryScope(document)
    if !gallery
        throw Error("The Image Gallery scope was unavailable before clicking its " directionLabel " button.")
    previousSnapshot := GetImageGalleryPageSnapshot(gallery)
    buttonState := GetImageGalleryButtonState(buttonCoordinateName, gallery, directionLabel)
    TestingLog(
        "image-gallery-page-move",
        "Direction=" directionLabel "; button_state=" buttonState "; before_snapshot_chars=" StrLen(previousSnapshot) "."
    )
    if buttonState = 0 {
        TestingLog("image-gallery-page-edge", directionLabel " button is disabled.")
        return false
    }

    ClickPoint(buttonCoordinateName, clickDelayMs)
    if WaitForImageGalleryPageChange(previousSnapshot, noChangeTimeoutMs) {
        TestingLog("image-gallery-page-changed", directionLabel " navigation succeeded on its first click.")
        return true
    }

    ; Retry once when UIA identified an enabled control. This handles a click
    ; landing during a brief gallery rerender without mistaking it for an edge.
    if buttonState = 1 {
        ClickPoint(buttonCoordinateName, clickDelayMs)
        if WaitForImageGalleryPageChange(previousSnapshot, noChangeTimeoutMs) {
            TestingLog("image-gallery-page-changed", directionLabel " navigation succeeded on its retry click.")
            return true
        }
    }
    TestingLog("image-gallery-page-unchanged", directionLabel " navigation did not change the gallery snapshot.")
    return false
}

GetImageGalleryButtonState(buttonCoordinateName, gallery := 0, directionLabel := "") {
    global coords

    ; Chrome omits Previous on page 1 and Next on the last page. A scoped UIA
    ; lookup can identify those edges immediately, avoiding the old click plus
    ; two-second no-change timeout on every image.
    if gallery && directionLabel != "" {
        try {
            requestedButtons := gallery.FindElements({ Name: directionLabel, Type: "Button", mm: 2, cs: 0 })
            for _, button in requestedButtons {
                if StrLower(Trim(button.Name)) = StrLower(directionLabel)
                    return button.IsEnabled ? 1 : 0
            }

            oppositeLabel := StrLower(directionLabel) = "previous" ? "Next" : "Previous"
            oppositeButtons := gallery.FindElements({ Name: oppositeLabel, Type: "Button", mm: 2, cs: 0 })
            for _, button in oppositeButtons {
                if StrLower(Trim(button.Name)) = StrLower(oppositeLabel)
                    return 0
            }

            if CountImageGalleryCards(gallery) <= 5
                return 0
        }
    }

    ; If the scoped tree is temporarily incomplete, retain the point-based
    ; fallback and page-change verification used by older runs.
    point := coords[buttonCoordinateName]

    try node := UIA.SmallestElementFromPoint(point[1], point[2])
    catch
        return -1

    Loop 8 {
        try {
            if StrLower(GetUiaControlTypeText(node)) = "button"
                return node.IsEnabled ? 1 : 0
        }
        try parent := UIA.TreeWalkerTrue.GetParentElement(node)
        catch
            return -1
        if !parent
            return -1
        node := parent
    }
    return -1
}

GetImageGalleryPageSnapshot(gallery) {
    try return gallery.DumpAll(" ", 10)
    catch
        return ""
}

WaitForImageGalleryPageChange(previousSnapshot, timeoutMs := 0) {
    global imageGalleryPageChangeTimeoutMs
    effectiveTimeoutMs := timeoutMs > 0 ? timeoutMs : imageGalleryPageChangeTimeoutMs
    deadline := A_TickCount + effectiveTimeoutMs
    changedSnapshot := ""
    stableSince := 0

    Loop {
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            gallery := FindImageGalleryScope(document)
            snapshot := gallery ? GetImageGalleryPageSnapshot(gallery) : ""
            if snapshot != "" && snapshot != previousSnapshot {
                if snapshot = changedSnapshot {
                    if A_TickCount - stableSince >= 400
                        return true
                } else {
                    changedSnapshot := snapshot
                    stableSince := A_TickCount
                }
            }
        }
        if A_TickCount >= deadline
            return false
        Sleep 200
    }
}

ClickCoordinates(point, delayMs := 250) {
    if point[1] = 0 || point[2] = 0
        throw Error("Coordinate not set.")

    Click point[1], point[2]
    Sleep delayMs
}

ValidateImageTargetConfig() {
    global imageCountToProcess, maximumImagesPerProduct, imageTargets, imageGalleryPageSize, coords

    if imageCountToProcess < 0
        throw Error("imageCountToProcess cannot be negative.")
    if imageCountToProcess > maximumImagesPerProduct
        throw Error("imageCountToProcess cannot exceed the GO b2b limit of " maximumImagesPerProduct ".")

    if imageGalleryPageSize < 1 || imageTargets.Length != imageGalleryPageSize
        throw Error("Image pagination requires exactly " imageGalleryPageSize " coordinate entries in imageTargets; found " imageTargets.Length ".")
    if !coords.Has("image_gallery_previous_button") || !coords.Has("image_gallery_next_button")
        throw Error("The Image Gallery Previous and Next button coordinates must both be configured.")
}

; Opens the Images tab and updates imageCountToProcess after visiting each
; available five-image carousel page. GO b2b lazily realises later pages in the
; accessibility tree: 002104 exposed only ten cards until its third page was
; visited. Already-realised pages remain in the tree, so take the highest total
; observed rather than summing page counts and double-counting retained cards.
; Each genuine card has one exact-name Remove button, which remains reliable
; even when visible image labels skip.
DetectAndSetImageCountFromImagesTab(expectedCount := -1) {
    global imageCountToProcess, maximumImagesPerProduct

    ValidateImageTargetConfig()
    OpenFirstImageGalleryPage()
    actualCount := DiscoverStableImageGalleryCountAcrossPages()
    detectedCount := Min(actualCount, maximumImagesPerProduct)

    if expectedCount >= 0 && detectedCount != expectedCount
        throw Error("Image count changed or differs between matrix children: expected " expectedCount ", detected " detectedCount ".")

    imageCountToProcess := detectedCount
    message := "UIA-v2 detected " actualCount " total Image Gallery card(s) after realising and checking every available carousel page."
    if actualCount > maximumImagesPerProduct
        message .= " Only the first " maximumImagesPerProduct " will be processed because GO b2b permits at most " maximumImagesPerProduct " image records per product."
    LogText("image-count-detected", message)
    TestingLog("image-count-accepted", message " Prompt/CMS count is " detectedCount ".")
    SaveTestingAccessibilityTree("image-count-accepted-" detectedCount)
    return detectedCount
}

DiscoverStableImageGalleryCountAcrossPages() {
    global imageGalleryMaxPages, maximumImagesPerProduct

    highestCount := -1
    pageNumber := 1
    Loop imageGalleryMaxPages {
        currentCount := WaitForStableImageGalleryCount()
        highestCount := Max(highestCount, currentCount)
        TestingLog(
            "image-count-page-observed",
            "Carousel page=" pageNumber "; current_realised_total=" currentCount
            . "; highest_realised_total=" highestCount "."
        )

        ; No further traversal is useful once the CMS processing limit has been
        ; found, even if the source product somehow contains more records.
        if highestCount >= maximumImagesPerProduct {
            TestingLog(
                "image-count-page-scan-complete",
                "Stopped after page " pageNumber " because the " maximumImagesPerProduct "-image processing limit was realised."
            )
            return highestCount
        }

        if A_Index = imageGalleryMaxPages
            throw Error("Image Gallery page discovery reached its " imageGalleryMaxPages "-page safety limit.")

        if !TryAdvanceImageGalleryPage() {
            TestingLog(
                "image-count-page-scan-complete",
                "Reached the final carousel page " pageNumber "; accepted highest realised total " highestCount "."
            )
            return highestCount
        }
        pageNumber += 1
    }
}

WaitForStableImageGalleryCount(timeoutMs := 0, stableDurationMs := 0, minimumObservationMs := -1) {
    global LastDocument, maximumImagesPerProduct
    global imageGalleryCountTimeoutMs, imageGalleryCountStableDurationMs, imageGalleryMinimumObservationMs

    effectiveTimeoutMs := timeoutMs > 0 ? timeoutMs : imageGalleryCountTimeoutMs
    effectiveStableDurationMs := stableDurationMs > 0 ? stableDurationMs : imageGalleryCountStableDurationMs
    effectiveMinimumObservationMs := minimumObservationMs >= 0 ? minimumObservationMs : imageGalleryMinimumObservationMs
    startedAt := A_TickCount
    deadline := startedAt + effectiveTimeoutMs
    previousSignature := ""
    stableSince := 0
    sampleNumber := 0
    lastCounts := Map("remove", -1, "details", -1, "sizeOptions", -1, "images", -1)
    lastProblem := "No complete Image Gallery sample was available."

    Loop {
        ToolTip "Reading Image Gallery accessibility tree..."
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            LastDocument := document
            gallery := FindImageGalleryScope(document)
            if gallery {
                sampleNumber += 1
                counts := GetImageGalleryCardControlCounts(gallery)
                lastCounts := counts
                signature := BuildImageGalleryCountSignature(counts)
                consistent := AreImageGalleryCardControlCountsConsistent(counts)
                now := A_TickCount

                if signature != previousSignature {
                    previousSignature := signature
                    stableSince := now
                    SaveTestingElementDump(
                        gallery,
                        "image-count-sample-" sampleNumber "-" signature
                    )
                }

                TestingLog(
                    "image-count-sample",
                    "Sample " sampleNumber
                    . "; elapsed_ms=" (now - startedAt)
                    . "; " signature
                    . "; consistent=" (consistent ? "yes" : "no")
                    . "; stable_ms=" (now - stableSince)
                )

                if consistent {
                    lastProblem := "The count was consistent but had not completed the minimum observation and stability periods."
                    ; Once the GO b2b processing cap is present, no later card
                    ; can increase the work this run is allowed to perform.
                    minimumWaitSatisfied := counts["remove"] >= maximumImagesPerProduct
                        || now - startedAt >= effectiveMinimumObservationMs
                    if minimumWaitSatisfied
                        && now - stableSince >= effectiveStableDurationMs {
                        ToolTip()
                        TestingLog(
                            "image-count-stable",
                            "Accepted " counts["remove"] " card(s) after " (now - startedAt)
                            . " ms; stable for " (now - stableSince) " ms; " signature "."
                        )
                        return counts["remove"]
                    }
                } else {
                    lastProblem := "Per-card accessibility controls disagreed: " signature "."
                }
            } else {
                previousSignature := ""
                stableSince := 0
                lastProblem := "The Image Gallery scope temporarily disappeared during rendering."
            }
        } catch as err {
            ; Chrome can briefly invalidate UIA elements while the tab renders.
            ; Retry until the overall deadline instead of accepting a bad count.
            previousSignature := ""
            stableSince := 0
            lastProblem := FormatTestingError(err)
            TestingLog("image-count-sample-error", lastProblem)
        }
        if A_TickCount >= deadline {
            ToolTip()
            finalSignature := BuildImageGalleryCountSignature(lastCounts)
            TestingLog(
                "image-count-timeout",
                "Timed out after " effectiveTimeoutMs " ms. Last counts: " finalSignature ". Last result: " lastProblem
            )
            SaveTestingAccessibilityTree("image-count-timeout")
            throw Error(
                "The Image Gallery card count did not become complete and stable within " effectiveTimeoutMs " ms."
                . "`n`nLast counts: " finalSignature
                . "`nLast UIA result: " lastProblem
                . "`n`nLeave the Images tab open and press F9 to dump the tree."
            )
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
    return GetImageGalleryCardControlCounts(scope)["remove"]
}

GetImageGalleryCardControlCounts(scope) {
    return Map(
        "remove", CountExactImageGalleryElements(scope, "Remove", "Button"),
        "details", CountExactImageGalleryElements(scope, "Details", "Button"),
        "sizeOptions", CountExactImageGalleryElements(scope, "Size Options", "Button"),
        "images", CountExactImageGalleryElements(scope, "", "Image")
    )
}

CountExactImageGalleryElements(scope, expectedName, typeName) {
    count := 0
    ; UIA's Image control type is localised by Chrome as "graphic".
    expectedLocalizedType := StrLower(typeName) = "image" ? "graphic" : StrLower(typeName)
    condition := expectedName = ""
        ? { Type: typeName }
        : { Name: expectedName, Type: typeName, mm: 2, cs: 0 }
    try elements := scope.FindElements(condition)
    catch
        return count

    for _, element in elements {
        try {
            if expectedName != "" && StrLower(Trim(element.Name)) != StrLower(expectedName)
                continue
            if StrLower(GetUiaControlTypeText(element)) != expectedLocalizedType
                continue
            count += 1
        }
    }
    return count
}

AreImageGalleryCardControlCountsConsistent(counts) {
    return counts["remove"] = counts["details"]
    && counts["remove"] = counts["sizeOptions"]
    && counts["remove"] = counts["images"]
}

BuildImageGalleryCountSignature(counts) {
    return "remove=" counts["remove"]
    . ", details=" counts["details"]
    . ", size_options=" counts["sizeOptions"]
    . ", images=" counts["images"]
}

; ==========================================================
; HOTKEY 2 - PASTE COPIED CHATGPT OUTPUT INTO CMS
; ==========================================================

RunManualChatGptOutputPaste() {
    global automaticWorkflowActive, automaticWorkflowCancelRequested
    global automaticWorkflowManualCompletion, automaticWorkflowCmsInsertionActive
    if automaticWorkflowCmsInsertionActive {
        Flash("Automatic CMS insertion is already running. Numpad6 was ignored to prevent a duplicate paste.", 3000)
        return false
    }
    interruptedAutomaticWorkflow := automaticWorkflowActive
    if interruptedAutomaticWorkflow
        automaticWorkflowCancelRequested := true
    succeeded := PasteCopiedChatGPTOutputToCms(true)
    if interruptedAutomaticWorkflow && succeeded
        automaticWorkflowManualCompletion := true
    return succeeded
}

PasteCopiedChatGPTOutputToCms(copyLatestResponse := true) {
    global cmsWinTitle, useRecommendedProductName, imageCountToProcess
    global lastSavedNonMatrixProductIdentity

    try {
        EnsureFolders()
        ValidateSeoAutomationMode()
        if copyLatestResponse
            CopyLatestChatGptResponseToClipboard()

        if IsBotzMode() {
            PasteBotzOutputToCms()
            return true
        }

        if IsFiguredArtMode() {
            PasteFiguredArtOutputToCms()
            return true
        }

        ValidateImageTargetConfig()

        if IsMatrixFullMode() {
            PasteMatrixFullOutputToCms()
            return true
        }

        if IsMatrixImageMode() {
            PasteMatrixImageOutputToCms()
            return true
        }

        ActivateWindow(cmsWinTitle)
        ClearActiveCmsProductCode()
        ClickPoint("overview_tab", 500)
        completedProductName := CleanText(CopyFromPoint("product_name"))
        if completedProductName = ""
            throw Error("The current GO b2b Product Name is blank, so the completed product cannot be identified safely.")
        if IsDepartmentMode() {
            SetActiveCmsProductCode(completedProductName)
            currentProductCode := ""
        } else
            currentProductCode := SetActiveCmsProductCode(CopyFromPoint("stock_code"))
        response := A_Clipboard

        if !InStr(response, "===AUTOMATION_OUTPUT_START===") {
            MsgBox "The automated ChatGPT copy did not place an automation block on the clipboard. No CMS fields were changed."
            return false
        }

        block := ExtractBetween(response, "===AUTOMATION_OUTPUT_START===", "===AUTOMATION_OUTPUT_END===")

        if block = "" {
            MsgBox "Automation markers were found, but the block could not be extracted."
            return false
        }

        output := IsImageOnlyMode() ? ParseImageOnlyOutput(block, imageCountToProcess) : ParseAutomationOutput(block, imageCountToProcess, IsMetadataOnlyMode())
        productNameRecommendation := output["productNameRecommendation"]
        metaTitle := output["metaTitle"]
        metaDescription := output["metaDescription"]
        htmlSnippet := output["htmlSnippet"]
        imageTitles := output["imageTitles"]
        imageAlts := output["imageAlts"]
        imageNames := output["imageNames"]
        TestingLog(
            "chatgpt-output-parsed",
            "Expected image count=" imageCountToProcess
            . "; parsed names=" imageNames.Length
            . "; parsed titles=" imageTitles.Length
            . "; parsed alts=" imageAlts.Length "."
        )

        LogText("chatgpt-output", response)
        LogText("automation-block", block)

        ; The strict image-only parser has already validated every required image
        ; field; metadata is intentionally absent in this mode.
        warnings := IsImageOnlyMode() ? "" : ValidateGeneratedFields(metaTitle, metaDescription, htmlSnippet, imageTitles, imageAlts, IsFullContentMode())

        if warnings != "" {
            MsgBox "Warnings found. No fields were pasted.`n`n" warnings
            return false
        }

        ActivateWindow(cmsWinTitle)

        ; Optional Overview tab: paste product name recommendation
        if !IsImageOnlyMode() && useRecommendedProductName && IsUsableProductNameRecommendation(productNameRecommendation) {
            InsertProductNameRecommendation(productNameRecommendation)
            ; Keep the exact value accepted by GO b2b. Department automation
            ; must find the renamed catalogue row, not the pre-update name that
            ; was captured before the ChatGPT workflow began.
            completedProductName := CleanText(CopyFromPoint("product_name"))
            if completedProductName = ""
                throw Error("The updated Product Name could not be read back from GO b2b.")
        }

        ; Description tab: paste meta fields. Full mode also pastes the HTML/product description field.
        if !IsImageOnlyMode()
            InsertMetaFields(metaTitle, metaDescription, htmlSnippet)

        ; Images tab: open each image details page and paste image metadata
        InsertImageSeoFields(imageTitles, imageAlts, imageNames)

        ; Save every ordinary workflow after all metadata and requested image
        ; records have been updated.
        if IsFullMode() || IsMetadataOnlyMode() || IsImageOnlyMode() {
            lastSavedNonMatrixProductIdentity := Map(
                "productName", completedProductName,
                "productCode", currentProductCode
            )
            ClickPoint("product_save_button", 1000)
        }

        if IsDepartmentMode()
            Flash("SEO fields pasted. Review the product, then save it manually.", 3000)
        else if IsFullMode()
            Flash("SEO fields pasted and product saved.")
        else if IsMetadataOnlyMode()
            Flash("Metadata and image SEO fields pasted and product saved.")
        else if IsImageOnlyMode()
            Flash("Image SEO fields pasted and product saved.")
        else
            Flash("SEO fields pasted; main product was not saved.")
        return true
    } catch as err {
        ReportTestingError("paste-chatgpt-output-to-cms", err)
        MsgBox "PasteCopiedChatGPTOutputToCms failed:`n`n" err.Message
        return false
    }
}

IsAutomaticWorkflowExecutionEnabled() {
    global fullWorkflowAutomationEnabled, departmentAutomationActive
    return fullWorkflowAutomationEnabled || departmentAutomationActive
}

RunAutomaticWorkflowIfEnabled(promptAlreadySubmitted := false, forceAutomation := false) {
    global fullWorkflowAutomationEnabled, automaticWorkflowActive
    global automaticWorkflowCancelRequested, automaticWorkflowManualCompletion
    global automaticWorkflowCmsInsertionActive, departmentAutomationActive

    if !fullWorkflowAutomationEnabled && !forceAutomation
        return false
    if automaticWorkflowActive
        throw Error("A full automatic workflow is already active.")

    automaticWorkflowActive := true
    automaticWorkflowCancelRequested := false
    automaticWorkflowManualCompletion := false
    try {
        if !promptAlreadySubmitted && !SubmitChatGptDraftForAutomaticWorkflow(forceAutomation)
            return false

        if !WaitForAutomaticChatGptOutput(forceAutomation)
            return forceAutomation && departmentAutomationActive && automaticWorkflowManualCompletion
        if !AutomaticWorkflowMayContinue(forceAutomation)
            return forceAutomation && departmentAutomationActive && automaticWorkflowManualCompletion

        ToolTip AutomaticWorkflowStatusHeading() "`nChatGPT output copied and validated.`nUpdating GO b2b CMS now..."
        automaticWorkflowCmsInsertionActive := true
        try return PasteCopiedChatGPTOutputToCms(false)
        finally automaticWorkflowCmsInsertionActive := false
    } finally {
        automaticWorkflowActive := false
        automaticWorkflowCancelRequested := false
        automaticWorkflowManualCompletion := false
        automaticWorkflowCmsInsertionActive := false
        ToolTip()
    }
}

AutomaticWorkflowMayContinue(forceAutomation := false) {
    global fullWorkflowAutomationEnabled, automaticWorkflowCancelRequested
    return !automaticWorkflowCancelRequested && (fullWorkflowAutomationEnabled || forceAutomation)
}

AutomaticWorkflowStatusHeading() {
    global departmentAutomationActive
    if departmentAutomationActive
        return "DEPARTMENT AUTOMATION RUNNING"
    if IsDepartmentMode()
        return "DEPARTMENT MODE AUTOMATION"
    return "FULL WORKFLOW AUTOMATION ON"
}

AutomaticWorkflowControlHint() {
    global departmentAutomationActive
    if departmentAutomationActive
        return "`nCtrl+Numpad6: stop after the current product`nNumpad6: manual output fallback"
    if IsDepartmentMode()
        return "`nCtrl+Alt+A: turn this automation off`nNumpad6: use the manual output fallback now"
    return "`nCtrl+Alt+A: turn automation off`nNumpad6: use the manual fallback now"
}

SubmitChatGptDraftForAutomaticWorkflow(forceAutomation := false) {
    global chatgptWinTitle, chatImageWindowWakeDelayMs, chatSubmitPreEnterDelayMs
    ToolTip AutomaticWorkflowStatusHeading()
        . "`nWaiting " Round(chatSubmitPreEnterDelayMs / 1000, 1) " seconds before submitting the prepared ChatGPT request..."
    ActivateWindow(GetChatGptWinTitle(), chatImageWindowWakeDelayMs)
    ; The prompt and any images were just pasted into this existing draft, so
    ; keep it untouched for ten seconds before the final Enter. This lets
    ; ChatGPT finish materialising large prompts and draft attachments.
    FocusChatGptInputForImagePaste()
    if !AutomaticWorkflowMayContinue(forceAutomation)
        return false
    TestingLog("chatgpt-pre-submit-wait", "Delay_ms=" chatSubmitPreEnterDelayMs "; workflow=automatic.")
    Sleep chatSubmitPreEnterDelayMs
    if !AutomaticWorkflowMayContinue(forceAutomation)
        return false
    ; Re-focus after the wait in case Chrome moved focus while rendering.
    FocusChatGptInputForImagePaste()
    LogText(
        "chatgpt-auto-submit",
        "Pressing Enter after a " Round(chatSubmitPreEnterDelayMs / 1000, 1) "-second draft-settle wait."
    )
    Send "{Enter}"
    Sleep 300
    return true
}

WaitForAutomaticChatGptOutput(forceAutomation := false) {
    global chatResponseInitialWaitMs, chatResponsePollIntervalMs
    global imageOnlyChatResponseInitialWaitMs, imageOnlyChatResponsePollIntervalMs

    startedAt := A_TickCount
    initialWaitMs := IsImageOnlyMode() ? imageOnlyChatResponseInitialWaitMs : chatResponseInitialWaitMs
    pollIntervalMs := IsImageOnlyMode() ? imageOnlyChatResponsePollIntervalMs : chatResponsePollIntervalMs
    nextAttemptAt := startedAt + initialWaitMs
    attempt := 0
    lastProblem := ""

    Loop {
        if !AutomaticWorkflowMayContinue(forceAutomation) {
            ToolTip()
            return false
        }

        now := A_TickCount
        remainingMs := nextAttemptAt - now
        if remainingMs > 0 {
            message := AutomaticWorkflowStatusHeading()
                . "`nWaiting for ChatGPT to finish..."
                . "`nElapsed: " FormatAutomationWaitTime(now - startedAt)
            if attempt = 0
                message .= "`nFirst copy attempt in: " FormatAutomationWaitTime(remainingMs)
            else {
                message .= "`nCopy attempt " attempt " did not find the finished output."
                message .= "`nNext attempt in: " FormatAutomationWaitTime(remainingMs)
                if lastProblem != ""
                    message .= "`nLast result: " lastProblem
            }
            message .= AutomaticWorkflowControlHint()
            ToolTip message
            Sleep Min(500, remainingMs)
            continue
        }

        attempt += 1
        ToolTip AutomaticWorkflowStatusHeading()
            . "`nCopy attempt " attempt ": scrolling to the bottom of ChatGPT..."
            . "`nNo CMS fields will change unless a complete output block is copied."
        copied := TryCopyLatestChatGptResponseByCoordinates(&lastProblem)

        ; Numpad6 can interrupt the wait and complete the manual fallback. Do
        ; not let this suspended automatic thread continue into a second paste.
        if !AutomaticWorkflowMayContinue(forceAutomation) {
            ToolTip()
            return false
        }
        if copied {
            LogText("chatgpt-auto-output-ready", "A complete ChatGPT automation output was copied on polling attempt " attempt ".")
            ToolTip AutomaticWorkflowStatusHeading()
                . "`nComplete ChatGPT output found on attempt " attempt "."
                . "`nStarting GO b2b insertion..."
            Sleep 500
            return true
        }

        nextAttemptAt := A_TickCount + pollIntervalMs
    }
}

FormatAutomationWaitTime(milliseconds) {
    totalSeconds := Ceil(Max(0, milliseconds) / 1000)
    minutes := Floor(totalSeconds / 60)
    seconds := Mod(totalSeconds, 60)
    return minutes ":" Format("{:02}", seconds)
}

; ==========================================================
; DEPARTMENT-WIDE AUTOMATION
; ==========================================================

StartDepartmentAutomation() {
    global departmentAutomationEnabled, departmentAutomationActive
    global departmentStopAfterCurrent, automaticWorkflowActive
    global departmentCatalogueWaitMs
    global lastSavedNonMatrixProductIdentity
    global promotionTextSaveEnabled

    ValidateSeoAutomationMode()
    if IsDepartmentMode() {
        MsgBox "The department SEO mode deliberately leaves each product unsaved for review, so it cannot run as a department-wide batch.`n`nOpen one product and press Numpad4 instead. The prompt will be submitted and the response inserted automatically, then the product will remain open for you to review and save manually."
        return false
    }
    if IsPromotionTextReferenceMode() {
        MsgBox "promotion_text_reference has its own stock-code search batch.`n`nOpen the catalogue product list and press NumpadEnter or Numpad4. Department automation does not need to be enabled."
        return false
    }
    departmentWorkflowMode := GetSeoAutomationMode()
    departmentProductType := GetDepartmentProductTypeForSeoMode(departmentWorkflowMode)

    if !departmentAutomationEnabled {
        MsgBox "Department automation is OFF.`n`nPress Ctrl+Alt+D to turn it on, open the first " departmentProductType " Overview tab, then press Ctrl+Numpad4."
        return false
    }
    if IsPromotionTextMode() && !promotionTextSaveEnabled {
        MsgBox "Department promotion-text automation was not started because test mode does not save or leave the current product.`n`nAfter the single-product test succeeds, change promotionTextSaveEnabled := false to true near the top of this script, reload it, then use the normal department keybinds."
        return false
    }
    if departmentAutomationActive {
        MsgBox "A department automation run is already active."
        return false
    }
    if automaticWorkflowActive {
        MsgBox "A single-product automatic workflow is already active. Wait for it to finish or cancel its wait before starting a department."
        return false
    }

    departmentAutomationActive := true
    departmentStopAfterCurrent := false
    completedCount := 0
    try {
        currentIdentity := ReadOpenCmsProductIdentity()
        SetActiveDepartmentProductIdentity(currentIdentity)
        LogText(
            "department-started",
            "Department automation started."
            . "`nWorkflow: " departmentWorkflowMode
            . "`nCatalogue product type: " departmentProductType
            . "`nFirst product: " currentIdentity["productName"]
        )

        Loop {
            if GetSeoAutomationMode() != departmentWorkflowMode
                throw Error("SeoAutomationMode changed during the department run. Restart the department so every product uses one consistent workflow.")
            productNumber := completedCount + 1
            ToolTip "DEPARTMENT AUTOMATION RUNNING"
                . "`nWorkflow: " departmentWorkflowMode
                . "`nProduct type: " departmentProductType
                . "`nProduct " productNumber ": " currentIdentity["productName"]
                . "`nCode: " EmptyToNA(currentIdentity["productCode"])
                . "`nPreparing the ChatGPT workflow..."
                . "`nCtrl+Numpad6: stop after this product"

            ; Prevent a failed or interrupted product from reusing the previous
            ; product's post-save identity.
            lastSavedNonMatrixProductIdentity := 0
            if !RunOpenProductWorkflow(true)
                throw Error("The automatic workflow did not complete product " productNumber " ('" currentIdentity["productName"] "').")

            completedCount += 1
            completedIdentity := PrepareCompletedProductForCatalogueLookup(currentIdentity)
            LogText(
                "department-product-complete",
                "Department product " completedCount " completed and saved."
                . "`nProduct name: " completedIdentity["productName"]
                . "`nProduct code: " EmptyToNA(completedIdentity["productCode"])
            )

            if departmentStopAfterCurrent || !departmentAutomationEnabled {
                LogText("department-stopped", "Department automation stopped after completing " completedCount " product(s), as requested.")
                MsgBox "Department automation stopped safely after saving the current product.`n`nProducts completed: " completedCount
                return true
            }

            ToolTip "DEPARTMENT AUTOMATION RUNNING"
                . "`nSaved product " completedCount ": " completedIdentity["productName"]
                . "`nWaiting " Round(departmentCatalogueWaitMs / 1000, 1) " seconds before reading the catalogue accessibility tree..."
                . "`nCtrl+Numpad6: stop before the next product starts"
            Sleep departmentCatalogueWaitMs

            if departmentStopAfterCurrent || !departmentAutomationEnabled {
                LogText("department-stopped", "Department automation stopped after completing " completedCount " product(s), as requested.")
                MsgBox "Department automation stopped safely after saving the current product.`n`nProducts completed: " completedCount
                return true
            }

            nextResult := FindNextDepartmentCatalogueProduct(completedIdentity, departmentProductType)
            if departmentStopAfterCurrent || !departmentAutomationEnabled {
                LogText("department-stopped", "Department automation stopped after completing " completedCount " product(s), as requested.")
                MsgBox "Department automation stopped safely after saving the current product.`n`nProducts completed: " completedCount
                return true
            }
            if nextResult["status"] = "end" {
                LogText("department-complete", "Reached the final " departmentProductType " exposed in the department accessibility tree after completing " completedCount " product(s).")
                MsgBox "Department automation is complete.`n`nProduct type: " departmentProductType "`nProducts completed: " completedCount "`nNo matching product follows the last completed item in the catalogue accessibility tree."
                return true
            }

            currentIdentity := OpenAndVerifyNextDepartmentProduct(nextResult["product"], completedCount + 1)
        }
    } catch as err {
        ReportTestingError("department-automation", err)
        MsgBox "Department automation stopped.`n`nProducts completed: " completedCount "`n`n" err.Message
        return false
    } finally {
        departmentAutomationActive := false
        departmentStopAfterCurrent := false
        ToolTip()
    }
}

ReadOpenCmsProductIdentity() {
    global cmsWinTitle
    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    productType := IsAnyMatrixMode() ? "Matrix Product" : "Simple Product"
    ; Matrix parents do not have stock codes. Do not read the stock-code
    ; coordinate at all: their department identity is always their exact name.
    productCode := productType = "Matrix Product"
        ? ""
        : CleanText(CopyOptionalFromPoint("stock_code"))
    productName := CleanText(CopyFromPoint("product_name"))
    if productName = ""
        throw Error("The open GO b2b Product Name is blank. Start department automation from the first product's Overview page.")
    return Map("productType", productType, "productName", productName, "productCode", productCode)
}

SetActiveDepartmentProductIdentity(identity) {
    ; The department-started log is written before the product workflow has a
    ; chance to initialise its own artifact identity. Seed it here using the
    ; same rule as catalogue matching: matrix parent name, otherwise code.
    productType := identity.Has("productType") ? StrLower(Trim(identity["productType"])) : ""
    artifactIdentity := productType = "matrix product"
        ? identity["productName"]
        : identity["productCode"]
    return SetActiveCmsProductCode(artifactIdentity)
}

PrepareCompletedProductForCatalogueLookup(originalIdentity) {
    global cmsWinTitle
    global lastSavedNonMatrixProductIdentity
    if !IsAnyMatrixMode() {
        if !IsObject(lastSavedNonMatrixProductIdentity)
            return originalIdentity

        originalCode := CleanText(originalIdentity["productCode"])
        savedCode := CleanText(lastSavedNonMatrixProductIdentity["productCode"])
        if originalCode = "" || savedCode = "" || StrLower(originalCode) != StrLower(savedCode)
            throw Error("The saved post-update product identity does not match the product that began this department step.")
        return lastSavedNonMatrixProductIdentity
    }

    ; Matrix insertion finishes inside the reopened parent. Read back its exact
    ; post-update identity, then close/save it to return to the department list.
    ActivateWindow(cmsWinTitle)
    completedIdentity := ReadOpenCmsProductIdentity()
    ToolTip "DEPARTMENT AUTOMATION RUNNING`nClosing the completed matrix parent and returning to the catalogue..."
    ClickPoint("product_save_button", 500)
    return completedIdentity
}

FindNextDepartmentCatalogueProduct(completedIdentity, departmentProductType) {
    global cmsWinTitle, departmentCatalogueTreeTimeoutMs
    deadline := A_TickCount + departmentCatalogueTreeTimeoutMs
    lastRowCount := 0
    lastTreeProblem := ""

    Loop {
        ToolTip "DEPARTMENT AUTOMATION RUNNING"
            . "`nReading the catalogue accessibility tree..."
            . "`nProduct type: " departmentProductType
            . "`nFinding the row after: " completedIdentity["productName"]
        try {
            ActivateWindow(cmsWinTitle, 250)
            document := UIA_Browser().GetCurrentDocumentElement()
            products := CollectDepartmentCatalogueProducts(document, departmentProductType)
            lastRowCount := products.Length
            currentIndex := FindCompletedDepartmentProductIndex(products, completedIdentity)
            if currentIndex {
                if currentIndex = products.Length
                    return Map("status", "end")
                return Map("status", "next", "product", products[currentIndex + 1])
            }
        } catch as err {
            lastTreeProblem := err.Message
        }

        if A_TickCount >= deadline
            throw Error(
                "Could not find the completed product in the current catalogue accessibility tree."
                . "`nCompleted product: " completedIdentity["productName"]
                . "`nCompleted code: " EmptyToNA(completedIdentity["productCode"])
                . "`nCatalogue " departmentProductType " rows detected: " lastRowCount
                . (lastTreeProblem != "" ? "`nLast accessibility error: " lastTreeProblem : "")
                . "`n`nThe next product was not opened."
            )
        Sleep 500
    }
}

CollectDepartmentCatalogueProducts(document, departmentProductType := "") {
    try {
        catalogueList := document.FindElement({ AutomationId: "catalogueNodeListView" })
        listItems := catalogueList.FindElements({ Type: "ListItem" })
    } catch
        return []

    products := []
    for _, listItem in listItems {
        if !InStr(StrLower(listItem.ClassName), "cms-catalogue-tile")
            continue
        rowText := listItem.Name
        ; Child-department links share the product tile class. Reference
        ; departments have no Edit suffix, so skip them by their type prefix.
        if IsCatalogueDepartmentTile(rowText)
            continue
        ; Reference links are handled by their own catalogue-search workflow.
        ; They can share the selected product type but have no Edit control.
        if IsCatalogueReferenceTile(rowText) {
            TestingLog("catalogue-reference-tile-skipped", NormaliseCatalogueTileText(rowText))
            continue
        }
        rowProductType := GetCatalogueTileProductTypePrefix(rowText)
        ; Only ordinary products of the selected type participate in the
        ; ordering. Keep strict parsing for those rows before opening one.
        if rowProductType = "" {
            TestingLog("catalogue-other-tile-skipped", NormaliseCatalogueTileText(rowText))
            continue
        }
        if departmentProductType != "" && StrLower(rowProductType) != StrLower(departmentProductType)
            continue

        identity := ParseDepartmentCatalogueTileIdentity(rowText)
        if !identity {
            ; GO b2b also marks reference links with a dedicated child class.
            ; Use it when the accessible name has an unfamiliar format.
            if HasCatalogueReferenceMarker(listItem) {
                TestingLog("catalogue-reference-tile-skipped", NormaliseCatalogueTileText(rowText))
                continue
            }
            throw Error("A catalogue product tile could not be parsed safely: " rowText)
        }
        ; Department runs operate on one product class only. Matrix modes use
        ; Matrix Product parents; ordinary and BOTZ modes use Simple Products.
        ; Filtering before next-row selection makes interleaved Matrix SKU rows
        ; invisible to the run instead of opening and trying to optimise them.
        if departmentProductType != "" && StrLower(identity["productType"]) != StrLower(departmentProductType)
            continue
        editLink := FindCatalogueTileEditControl(listItem)
        if !editLink
            throw Error("A catalogue product tile has no usable Edit control: " identity["rowText"])
        identity["rowElement"] := listItem
        identity["editElement"] := editLink
        products.Push(identity)
    }
    return products
}

NormaliseCatalogueTileText(rowText) {
    text := RegExReplace(rowText, "[\x{E000}-\x{F8FF}]", " ")
    return RegExReplace(Trim(text), "[\r\n\t ]+", " ")
}

GetCatalogueTileProductTypePrefix(rowText) {
    text := NormaliseCatalogueTileText(rowText)
    if RegExMatch(text, "i)^(Simple Product|Matrix SKU|Matrix Product)\b", &match)
        return match[1]
    return ""
}

IsCatalogueReferenceTile(rowText) {
    text := NormaliseCatalogueTileText(rowText)
    return RegExMatch(text, "i)^(?:Simple Product|Matrix SKU|Matrix Product)\s+\(Reference\)(?:\s|$)") || RegExMatch(text, "i)^Matrix SKU\s+Reference(?:\s|$)")
}

HasCatalogueReferenceMarker(listItem) {
    try return listItem.FindElements({ ClassName: "cms-catalogue-tile-reference" }).Length > 0
    catch
        return false
}

IsCatalogueDepartmentTile(rowText) {
    text := NormaliseCatalogueTileText(rowText)
    return RegExMatch(text, "i)^Department\s+\S")
}

ParseDepartmentCatalogueTileIdentity(rowText) {
    text := NormaliseCatalogueTileText(rowText)
    if !RegExMatch(text, "i)^(Simple Product|Matrix SKU|Matrix Product)\s+(.+?)\s+Edit$", &match)
        return 0

    productType := match[1]
    body := Trim(match[2])
    productCode := ""
    productName := body
    if StrLower(productType) != "matrix product" {
        if !RegExMatch(body, "^(.+\S)\s+(\S+)$", &identityMatch)
            return 0
        productName := Trim(identityMatch[1])
        productCode := Trim(identityMatch[2])
    }
    if productName = ""
        return 0
    return Map(
        "productType", productType,
        "productName", productName,
        "productCode", productCode,
        "rowText", text
    )
}

FindCatalogueTileEditControl(listItem) {
    try editControls := listItem.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return 0
    for _, editControl in editControls {
        try {
            if StrLower(Trim(editControl.Name)) = "edit" && editControl.IsEnabled
                return editControl
        }
    }
    return 0
}

FindVisibleExactNamedControlPoint(searchRoot, controlName, referencePoint, scopeLabel) {
    try elements := searchRoot.FindElements({ Name: controlName, mm: 2, cs: 0 })
    catch
        return 0
    best := 0
    bestDistance := 0
    for _, element in elements {
        try {
            exposedName := RegExReplace(element.Name, "[\x{E000}-\x{F8FF}]", " ")
            exposedName := RegExReplace(Trim(exposedName), "[\r\n\t ]+", " ")
            if StrLower(exposedName) != StrLower(Trim(controlName))
                continue
            if !element.IsEnabled || element.IsOffscreen
                continue
            rect := element.Location
            if rect.w <= 0 || rect.h <= 0 || rect.x < 0 || rect.y < 0
                continue
            point := {
                X: Round(rect.x),
                Y: Round(rect.y),
                W: Round(rect.w),
                H: Round(rect.h),
                CentreX: Round(rect.x + rect.w / 2),
                CentreY: Round(rect.y + rect.h / 2),
                ScopeLabel: scopeLabel
            }
            distance := ((point.CentreX - referencePoint[1]) ** 2) + ((point.CentreY - referencePoint[2]) ** 2)
            if !best || distance < bestDistance {
                best := point
                bestDistance := distance
            }
        }
    }
    return best
}

WaitForVisibleExactNamedControlPoint(controlName, referencePoint, timeoutMs := 5000) {
    global cmsWinTitle, matrixStableDurationMs
    deadline := A_TickCount + timeoutMs
    priorSignature := ""
    stableSince := 0
    Loop {
        point := 0
        try {
            ActivateWindow(cmsWinTitle, 100)
            browser := UIA_Browser(cmsWinTitle)
            document := browser.GetCurrentDocumentElement()
            point := FindVisibleExactNamedControlPoint(document, controlName, referencePoint, "current browser document")
            if !point
                point := FindVisibleExactNamedControlPoint(browser.BrowserElement, controlName, referencePoint, "complete Chrome window")
        }
        if point {
            signature := point.X "," point.Y "," point.W "," point.H
            if signature = priorSignature {
                if stableSince && A_TickCount - stableSince >= matrixStableDurationMs
                    return point
            } else {
                priorSignature := signature
                stableSince := A_TickCount
            }
        } else {
            priorSignature := ""
            stableSince := 0
        }
        if A_TickCount >= deadline
            return 0
        Sleep 250
    }
}

PhysicallyClickMatrixParentSave(delayMs, requireLiveSaveControl := false) {
    global coords
    referencePoint := coords["product_save_button"]
    savePoint := WaitForVisibleExactNamedControlPoint("Save", referencePoint, 5000)
    ToolTip()
    if savePoint {
        MouseMove savePoint.CentreX, savePoint.CentreY, 0
        Sleep 250
        Click savePoint.CentreX, savePoint.CentreY
        Sleep delayMs
        return savePoint
    }
    if requireLiveSaveControl
        return 0

    ; Retain the configured coordinate only as an initial fallback for GO b2b
    ; versions which do not expose the Save button to UIA. It is never used for
    ; a retry, because the catalogue may already be open by then.
    ClickPoint("product_save_button", delayMs)
    return {
        X: referencePoint[1],
        Y: referencePoint[2],
        W: 0,
        H: 0,
        CentreX: referencePoint[1],
        CentreY: referencePoint[2],
        ScopeLabel: "configured fallback coordinate"
    }
}

FindExactCatalogueMatrixParent(searchRoot, productName, fallbackScopeLabel := "current browser document") {
    targetName := NormaliseCatalogueProductName(productName)
    matches := []
    catalogueScope := searchRoot
    scopeLabel := fallbackScopeLabel
    try {
        catalogueScope := searchRoot.FindElement({ AutomationId: "catalogueNodeListView" })
        scopeLabel := "catalogueNodeListView"
    }
    ; Chrome sometimes drops the Kendo list container itself during a rebuild
    ; while its cms-catalogue-tile descendants remain in the UIA tree. Search
    ; all ListItems in the supplied root when that container is absent.
    try listItems := catalogueScope.FindElements({ Type: "ListItem" })
    catch as err
        throw Error("Catalogue ListItems could not be read from " scopeLabel ".`n" err.Message)

    for _, listItem in listItems {
        try rowClass := listItem.ClassName
        catch
            continue
        if !InStr(StrLower(rowClass), "cms-catalogue-tile")
            continue
        try rowName := listItem.Name
        catch
            continue
        identity := ParseDepartmentCatalogueTileIdentity(rowName)
        if !identity
            continue
        if StrLower(identity["productType"]) != "matrix product"
            continue
        if NormaliseCatalogueProductName(identity["productName"]) != targetName
            continue
        editElement := FindCatalogueTileEditControl(listItem)
        if !editElement
            throw Error("The exact Matrix Product row has no enabled child Edit link: " identity["rowText"])
        matches.Push(Map(
            "identity", identity,
            "rowElement", listItem,
            "editElement", editElement,
            "scopeLabel", scopeLabel
        ))
    }

    if matches.Length > 1
        throw Error("More than one Matrix Product row exactly matched '" productName "', so a physical click would be unsafe.")
    return matches.Length = 1 ? matches[1] : 0
}

WaitForCatalogueMatrixParentEditPoint(productName, timeoutMs) {
    global cmsWinTitle, matrixCatalogueScrollSettleDelayMs, matrixStableDurationMs
    deadline := A_TickCount + timeoutMs
    priorSignature := ""
    stableSince := 0
    lastProblem := ""

    Loop {
        try {
            ActivateWindow(cmsWinTitle, 100)
            browser := UIA_Browser(cmsWinTitle)
            document := browser.GetCurrentDocumentElement()
            match := FindExactCatalogueMatrixParent(document, productName)
            ; GetCurrentDocumentElement can briefly select a transitional
            ; Chrome Document. The complete browser window is a second,
            ; independent search root and can still expose the catalogue rows.
            if !match
                match := FindExactCatalogueMatrixParent(browser.BrowserElement, productName, "complete Chrome window")
            if !match {
                lastProblem := "No exact Matrix Product row was exposed in the current Document or the complete Chrome window."
                priorSignature := ""
                stableSince := 0
            } else {
                editElement := match["editElement"]
                if editElement.IsOffscreen {
                    ; UIA is used only to reveal and measure the exact row. It
                    ; never invokes or clicks the Edit control.
                    match["rowElement"].ScrollIntoView()
                    ToolTip "Bringing the exact matrix parent Edit button into view...`n" productName
                    Sleep matrixCatalogueScrollSettleDelayMs
                    priorSignature := ""
                    stableSince := 0
                    continue
                }

                rect := editElement.Location
                if rect.w <= 0 || rect.h <= 0 || rect.x < 0 || rect.y < 0 {
                    lastProblem := "The exact row was found, but its child Edit link had no usable screen rectangle."
                    priorSignature := ""
                    stableSince := 0
                } else {
                    point := {
                        X: Round(rect.x),
                        Y: Round(rect.y),
                        W: Round(rect.w),
                        H: Round(rect.h),
                        CentreX: Round(rect.x + rect.w / 2),
                        CentreY: Round(rect.y + rect.h / 2),
                        RowText: match["identity"]["rowText"],
                        ScopeLabel: match["scopeLabel"]
                    }
                    signature := point.X "," point.Y "," point.W "," point.H
                    if signature = priorSignature {
                        if stableSince && A_TickCount - stableSince >= matrixStableDurationMs
                            return point
                    } else {
                        priorSignature := signature
                        stableSince := A_TickCount
                    }
                    lastProblem := "The exact Edit rectangle was still moving while the catalogue loaded."
                }
            }
        } catch as err {
            lastProblem := err.Message
            priorSignature := ""
            stableSince := 0
        }

        if A_TickCount >= deadline
            throw Error(
                "Could not obtain a stable physical-click location for Matrix Product '" productName "' from the live accessibility tree."
                . (lastProblem != "" ? "`nLast accessibility problem: " lastProblem : "")
            )
        Sleep 250
    }
}

FindCompletedDepartmentProductIndex(products, completedIdentity) {
    matches := []
    for index, product in products {
        if DepartmentCatalogueIdentityMatches(product, completedIdentity)
            matches.Push(index)
    }
    if matches.Length > 1
        throw Error("More than one catalogue row matched the completed product, so choosing the next product would be unsafe.")
    return matches.Length = 1 ? matches[1] : 0
}

DepartmentCatalogueIdentityMatches(catalogueProduct, completedIdentity) {
    catalogueType := catalogueProduct.Has("productType") ? StrLower(Trim(catalogueProduct["productType"])) : ""
    completedType := completedIdentity.Has("productType") ? StrLower(Trim(completedIdentity["productType"])) : ""
    if catalogueType = "matrix product" || completedType = "matrix product"
        return NormaliseCatalogueProductName(catalogueProduct["productName"])
            = NormaliseCatalogueProductName(completedIdentity["productName"])

    completedCode := CleanText(completedIdentity["productCode"])
    catalogueCode := CleanText(catalogueProduct["productCode"])
    if completedCode != "" && catalogueCode != ""
        return StrLower(completedCode) = StrLower(catalogueCode)
    return NormaliseCatalogueProductName(catalogueProduct["productName"])
        = NormaliseCatalogueProductName(completedIdentity["productName"])
}

OpenAndVerifyNextDepartmentProduct(product, productNumber) {
    global cmsWinTitle, departmentProductOpenDelayMs, departmentCatalogueTreeTimeoutMs
    ToolTip "DEPARTMENT AUTOMATION RUNNING"
        . "`nOpening product " productNumber ": " product["productName"]
        . "`nCode: " EmptyToNA(product["productCode"])
        . "`nCtrl+Numpad6: stop after this product"

    ; Accessibility is used only to identify and, if necessary, expose the
    ; correct row. The Edit button itself is always pressed with a real mouse
    ; move/click; UIA Invoke/Click is deliberately not used here.
    try {
        if product["editElement"].IsOffscreen {
            product["rowElement"].ScrollIntoView()
            Sleep 1000
        }

        ; Scrolling can rebuild the Kendo list and stale the original element.
        ; Reacquire the matching row, then use only its current rectangle.
        document := UIA_Browser().GetCurrentDocumentElement()
        liveProducts := CollectDepartmentCatalogueProducts(document, product["productType"])
        liveIndex := FindCompletedDepartmentProductIndex(liveProducts, product)
        if !liveIndex
            throw Error("The matching catalogue row disappeared before its physical click.")
        liveProduct := liveProducts[liveIndex]
        if liveProduct["editElement"].IsOffscreen
            throw Error("The matching Edit button remained off-screen after scrolling.")
        rect := liveProduct["editElement"].Location
        if rect.w <= 0 || rect.h <= 0 || rect.x < 0 || rect.y < 0
            throw Error("The live Edit button has no usable screen rectangle.")
        editX := Round(rect.x + rect.w / 2)
        editY := Round(rect.y + rect.h / 2)
        MouseMove editX, editY, 0
        Sleep 200
        Click editX, editY
        Sleep 750
    } catch as clickError {
        throw Error("Could not physically click the next catalogue Edit button.`n" clickError.Message)
    }

    Sleep departmentProductOpenDelayMs
    expectedIdentity := Map("productType", product["productType"], "productName", product["productName"], "productCode", product["productCode"])
    deadline := A_TickCount + departmentCatalogueTreeTimeoutMs
    lastOpenedIdentity := 0
    Loop {
        try {
            actualIdentity := ReadOpenCmsProductIdentity()
            lastOpenedIdentity := actualIdentity
            if DepartmentCatalogueIdentityMatches(expectedIdentity, actualIdentity)
                return actualIdentity
        }
        if A_TickCount >= deadline
            break
        ToolTip "DEPARTMENT AUTOMATION RUNNING"
            . "`nWaiting for product " productNumber " Overview to become ready..."
            . "`nExpected: " product["productName"]
        Sleep 500
    }

    openedText := lastOpenedIdentity
        ? lastOpenedIdentity["productName"] " (" EmptyToNA(lastOpenedIdentity["productCode"]) ")"
        : "The Overview fields could not be read."
    throw Error(
        "The next Edit control did not open the expected product."
        . "`nExpected: " product["productName"] " (" EmptyToNA(product["productCode"]) ")"
        . "`nOpened: " openedText
    )
}

; ==========================================================
; COPY LATEST COMPLETED CHATGPT RESPONSE
; ==========================================================

CopyLatestChatGptResponseToClipboard() {
    savedClip := ClipboardAll()
    uiaProblem := ""
    fallbackProblem := ""

    try {
        ToolTip "Finding the latest ChatGPT response Copy button..."
        if TryCopyLatestChatGptResponseWithUia(&uiaProblem) {
            ToolTip()
            return A_Clipboard
        }

        ToolTip "ChatGPT Copy button was not available through UIA.`nScrolling to the bottom for the coordinate fallback..."
        if TryCopyLatestChatGptResponseByCoordinates(&fallbackProblem) {
            ToolTip()
            return A_Clipboard
        }
    } catch as err {
        fallbackProblem := err.Message
    }

    ToolTip()
    A_Clipboard := savedClip
    throw Error(
        "Could not copy the latest completed ChatGPT response. No CMS fields were changed."
        . "`n`nUI Automation: " (uiaProblem != "" ? uiaProblem : "No valid response was copied.")
        . "`n`nBottom-scroll fallback: " (fallbackProblem != "" ? fallbackProblem : "No valid response was copied.")
    )
}

TryCopyLatestChatGptResponseWithUia(&problem) {
    global chatgptWinTitle, chatResponseCopyTimeoutMs
    problem := ""

    try {
        ActivateWindow(GetChatGptWinTitle(), 400)
        document := UIA_Browser().GetCurrentDocumentElement()
        copyButton := FindLatestChatGptResponseCopyButton(document)
        if !copyButton {
            problem := "No exact-name Copy button was exposed in the ChatGPT accessibility tree."
            return false
        }

        A_Clipboard := ""
        copyButton.Invoke()
        if !ClipWait(chatResponseCopyTimeoutMs / 1000) {
            problem := "The latest UIA Copy button did not place text on the clipboard."
            return false
        }
        if !ClipboardHasCompleteAutomationOutput() {
            problem := "The latest UIA Copy button did not copy one complete automation-output block."
            return false
        }
        return true
    } catch as err {
        problem := err.Message
        return false
    }
}

FindLatestChatGptResponseCopyButton(document) {
    try buttons := document.FindElements({ Name: "Copy", Type: "Button", mm: 2, cs: 0 })
    catch
        return 0

    ; ChatGPT exposes code-block actions as "Copy code". Requiring the exact
    ; accessible name "Copy" leaves only response action buttons. UIA traversal
    ; order follows the conversation, so the final match belongs to the latest
    ; completed assistant response even when it is below the visible viewport.
    Loop buttons.Length {
        button := buttons[buttons.Length - A_Index + 1]
        try {
            if StrLower(Trim(button.Name)) = "copy" && button.IsEnabled
                return button
        }
    }
    return 0
}

TryCopyLatestChatGptResponseByCoordinates(&problem) {
    global chatgptWinTitle, chatResponseCopyTimeoutMs
    global chatResponseScrollNotches
    global chatResponseRecoveryPageUpCount, chatResponseRecoveryPageDownCount
    global chatResponseCopyButtonPoint
    problem := ""

    try {
        ActivateWindow(GetChatGptWinTitle(), 400)
        MouseMove chatResponseCopyButtonPoint[1], chatResponseCopyButtonPoint[2], 0

        ; Moving up first repairs the occasional ChatGPT conversation viewport
        ; state where a direct bottom scroll stops exposing response actions.
        Send "{PgUp " chatResponseRecoveryPageUpCount "}"
        Sleep 500

        ; Keep the original large wheel-down pass, then travel much farther down
        ; than the short recovery move so long responses expose their Copy action.
        SendNativeMouseWheel(-1, chatResponseScrollNotches)
        Send "{PgDn " chatResponseRecoveryPageDownCount "}"
        Sleep 900

        A_Clipboard := ""
        Click chatResponseCopyButtonPoint[1], chatResponseCopyButtonPoint[2]
        if !ClipWait(chatResponseCopyTimeoutMs / 1000) {
            problem := "Clicking " chatResponseCopyButtonPoint[1] "," chatResponseCopyButtonPoint[2] " did not place text on the clipboard."
            return false
        }
        if !ClipboardHasCompleteAutomationOutput() {
            problem := "The coordinate fallback did not copy one complete automation-output block."
            return false
        }
        return true
    } catch as err {
        problem := err.Message
        return false
    }
}

ClipboardHasCompleteAutomationOutput() {
    response := A_Clipboard
    startMarker := "===AUTOMATION_OUTPUT_START==="
    endMarker := "===AUTOMATION_OUTPUT_END==="
    startPos := InStr(response, startMarker)
    endPos := InStr(response, endMarker)
    return response != ""
        && CountTextOccurrences(response, startMarker) = 1
        && CountTextOccurrences(response, endMarker) = 1
        && startPos < endPos
        && Trim(ExtractBetween(response, startMarker, endMarker), " `t`r`n") != ""
}

; ==========================================================
; AUTOMATION OUTPUT PARSING
; ==========================================================

; ==========================================================
; CMS INSERTION HELPERS
; ==========================================================

RunPromotionTextReferenceWorkflow() {
    global cmsWinTitle, promotionTextSaveEnabled
    global promotionReferenceBatchActive, promotionReferenceStopAfterCurrent
    global promotionReferenceCatalogueReturnDelayMs
    global departmentAutomationActive, automaticWorkflowActive

    if !promotionTextSaveEnabled
        throw Error("promotion_text_reference cannot run while promotionTextSaveEnabled is false, because every saved product must return to the catalogue before the next stock-code search.")
    if promotionReferenceBatchActive
        throw Error("A reference promotion-text batch is already active.")
    if departmentAutomationActive || automaticWorkflowActive
        throw Error("Another automatic workflow is already active. Let it finish before starting the reference promotion-text batch.")

    promotionReferenceBatchActive := true
    promotionReferenceStopAfterCurrent := false
    completedCount := 0
    totalCount := 0
    try {
        EnsureFolders()
        ActivateWindow(cmsWinTitle)
        references := CollectAllCatalogueReferenceProducts()
        totalCount := references.Length
        if totalCount = 0
            throw Error("No 'Simple Product (Reference)' rows were found on the current catalogue page's accessibility tree.")

        referenceLog := "Reference products detected: " totalCount
        for index, reference in references
            referenceLog .= "`n" index ". " reference["productCode"] " - " reference["productName"]
        ; This inventory is collected before any product is opened, so there is
        ; deliberately no active stock-code identity for a product-scoped log.
        TestingLog("promotion-reference-products", referenceLog)

        for index, reference in references {
            ToolTip "REFERENCE PROMOTION-TEXT BATCH"
                . "`nProduct " index " of " totalCount
                . "`nSearching for code: " reference["productCode"]
                . "`nCtrl+Numpad6: stop after this product"

            SearchAndOpenCatalogueReferenceProduct(reference, index, totalCount)
            if !RunPromotionTextWorkflow()
                throw Error("Promotional text was not completed for reference product '" reference["productCode"] "'.")
            completedCount += 1

            LogText(
                "promotion-reference-product-complete",
                "Reference product " completedCount " of " totalCount " completed and saved."
                . "`nProduct name: " reference["productName"]
                . "`nProduct code: " reference["productCode"]
            )

            if promotionReferenceStopAfterCurrent {
                MsgBox "Reference promotion-text batch stopped safely after saving the current product.`n`nProducts completed: " completedCount " of " totalCount
                return true
            }
            if index < totalCount {
                ToolTip "REFERENCE PROMOTION-TEXT BATCH"
                    . "`nSaved " completedCount " of " totalCount
                    . "`nWaiting for the catalogue search before the next code..."
                Sleep promotionReferenceCatalogueReturnDelayMs
            }
        }

        LogText("promotion-reference-complete", "Reference promotion-text batch completed " completedCount " product(s).")
        MsgBox "Reference promotion-text batch is complete.`n`nProducts completed: " completedCount
        return true
    } catch as err {
        ReportTestingError("promotion-reference-batch", err)
        MsgBox "Reference promotion-text batch stopped.`n`nProducts completed: " completedCount " of " totalCount "`n`n" err.Message
        return false
    } finally {
        promotionReferenceBatchActive := false
        promotionReferenceStopAfterCurrent := false
        ToolTip()
    }
}

CollectAllCatalogueReferenceProducts() {
    global cmsWinTitle, coords
    global promotionReferenceScanMaxScrollSteps, promotionReferenceScanNoChangeStopCount
    global promotionReferenceScanWheelNotches

    anchor := coords["catalogue_product_list_scan_anchor"]
    MouseMove anchor[1], anchor[2], 0
    SendNativeMouseWheel(1, 120)
    Sleep 900

    collected := []
    seenCodes := Map()
    priorSignature := ""
    unchangedCount := 0

    Loop promotionReferenceScanMaxScrollSteps + 1 {
        scan := WaitForCatalogueReferenceProductScan(5000)

        for _, reference in scan["references"] {
            key := StrLower(reference["productCode"])
            if seenCodes.Has(key) {
                if NormaliseCatalogueProductName(seenCodes[key]) != NormaliseCatalogueProductName(reference["productName"])
                    throw Error("Stock code '" reference["productCode"] "' belongs to more than one Simple Product (Reference) row.")
                continue
            }
            seenCodes[key] := reference["productName"]
            collected.Push(reference)
        }

        signature := BuildCatalogueRowSignature(scan["rowTexts"])
        ToolTip "REFERENCE PROMOTION-TEXT BATCH"
            . "`nScanning the catalogue accessibility tree..."
            . "`nReference codes found: " collected.Length
            . "`nScroll step: " (A_Index - 1)

        if signature = priorSignature
            unchangedCount += 1
        else {
            priorSignature := signature
            unchangedCount := 0
        }
        if unchangedCount >= promotionReferenceScanNoChangeStopCount
            return collected

        MouseMove anchor[1], anchor[2], 0
        SendNativeMouseWheel(-1, promotionReferenceScanWheelNotches)
        Sleep 650
    }

    throw Error("The catalogue reference scan reached its " promotionReferenceScanMaxScrollSteps "-step safety limit before the product list stopped changing.")
}

WaitForCatalogueReferenceProductScan(timeoutMs) {
    global cmsWinTitle
    deadline := A_TickCount + timeoutMs
    lastProblem := ""
    Loop {
        try {
            ActivateWindow(cmsWinTitle, 100)
            document := UIA_Browser().GetCurrentDocumentElement()
            return CollectCatalogueReferenceProductsFromDocument(document)
        } catch as err {
            lastProblem := err.Message
        }
        if A_TickCount >= deadline
            throw Error("The catalogue accessibility tree did not become ready for the reference scan.`n" lastProblem)
        Sleep 250
    }
}

CollectCatalogueReferenceProductsFromDocument(document) {
    try {
        catalogueList := document.FindElement({ AutomationId: "catalogueNodeListView" })
        listItems := catalogueList.FindElements({ Type: "ListItem" })
    } catch as err {
        throw Error("The catalogue product list was not available in the current accessibility tree.`n" err.Message)
    }

    references := []
    rowTexts := []
    for _, listItem in listItems {
        try rowClass := listItem.ClassName
        catch
            continue
        if !InStr(StrLower(rowClass), "cms-catalogue-tile")
            continue
        try rowText := NormaliseCatalogueTileText(listItem.Name)
        catch
            continue
        if rowText = ""
            continue
        rowTexts.Push(rowText)
        identity := ParseCatalogueReferenceProductIdentity(rowText)
        if identity
            references.Push(identity)
    }
    return Map("references", references, "rowTexts", rowTexts)
}

ParseCatalogueReferenceProductIdentity(rowText) {
    text := NormaliseCatalogueTileText(rowText)
    if !RegExMatch(text, "i)^Simple Product\s+\(Reference\)\s+(.+)$", &match)
        return 0

    body := Trim(match[1])
    if !RegExMatch(body, "^(.+\S)\s+(\S+)$", &identityMatch)
        return 0
    productName := Trim(identityMatch[1])
    productCode := Trim(identityMatch[2])
    if productName = "" || productCode = ""
        return 0
    return Map(
        "productType", "Simple Product (Reference)",
        "productName", productName,
        "productCode", productCode,
        "rowText", text
    )
}

BuildCatalogueRowSignature(rowTexts) {
    signature := ""
    for _, rowText in rowTexts
        signature .= (signature = "" ? "" : "`n") rowText
    return signature
}

SearchAndOpenCatalogueReferenceProduct(reference, productNumber, productCount) {
    global cmsWinTitle, coords
    global promotionReferenceSearchTimeoutMs, promotionReferenceProductOpenDelayMs
    stockCode := reference["productCode"]

    ActivateWindow(cmsWinTitle)
    searchButtonPoint := WaitForVisibleExactNamedControlPoint("Search", coords["catalogue_search_button"], promotionReferenceSearchTimeoutMs)
    if !searchButtonPoint
        throw Error("The catalogue Search controls did not become available before searching for '" stockCode "'.")
    ClickPoint("catalogue_search_input", 200)
    Send "^a"
    Sleep 150
    PasteText(stockCode)
    ClickPoint("catalogue_search_button", 500)

    resultPoint := WaitForCatalogueReferenceSearchResult(stockCode, promotionReferenceSearchTimeoutMs)
    if !resultPoint
        throw Error("Search did not expose a visible result row with the exact stock code '" stockCode "'.")

    ToolTip "REFERENCE PROMOTION-TEXT BATCH"
        . "`nProduct " productNumber " of " productCount
        . "`nOpening exact search result: " stockCode
    MouseMove resultPoint.CentreX, resultPoint.CentreY, 0
    Sleep 250
    Click resultPoint.CentreX, resultPoint.CentreY, 2
    Sleep promotionReferenceProductOpenDelayMs

    overviewPoint := WaitForVisibleExactNamedControlPoint("Overview", coords["overview_tab"], promotionReferenceSearchTimeoutMs)
    if !overviewPoint
        throw Error("Double-clicking search result '" stockCode "' did not expose the product Overview tab.")

    openedIdentity := ReadOpenCmsProductIdentity()
    if StrLower(CleanText(openedIdentity["productCode"])) != StrLower(CleanText(stockCode))
        throw Error(
            "The search result opened the wrong product."
            . "`nExpected code: " stockCode
            . "`nOpened code: " EmptyToNA(openedIdentity["productCode"])
        )
    return openedIdentity
}

WaitForCatalogueReferenceSearchResult(stockCode, timeoutMs) {
    global cmsWinTitle
    deadline := A_TickCount + timeoutMs
    priorSignature := ""
    stableSince := 0

    Loop {
        point := 0
        try {
            ActivateWindow(cmsWinTitle, 100)
            browser := UIA_Browser(cmsWinTitle)
            document := browser.GetCurrentDocumentElement()
            point := FindCatalogueReferenceSearchResultPoint(document, stockCode, "current browser document")
            if !point
                point := FindCatalogueReferenceSearchResultPoint(browser.BrowserElement, stockCode, "complete Chrome window")
        }

        if point {
            signature := point.X "," point.Y "," point.W "," point.H
            if signature = priorSignature {
                if stableSince && A_TickCount - stableSince >= 500
                    return point
            } else {
                priorSignature := signature
                stableSince := A_TickCount
            }
        } else {
            priorSignature := ""
            stableSince := 0
        }
        if A_TickCount >= deadline
            return 0
        Sleep 250
    }
}

FindCatalogueReferenceSearchResultPoint(searchRoot, stockCode, scopeLabel) {
    global coords
    try elements := searchRoot.FindElements({ Name: stockCode, mm: 2, cs: 0 })
    catch
        return 0

    searchPaneMinimumX := coords["catalogue_search_input"][1] - 150
    best := 0
    bestScore := 0
    for _, element in elements {
        try {
            name := NormaliseCatalogueTileText(element.Name)
            if !CatalogueAccessibilityTextContainsExactCode(name, stockCode)
                continue
            if element.IsOffscreen || !element.IsEnabled
                continue
            controlType := StrLower(GetUiaControlTypeText(element))
            ; The query edit can expose its current value as an accessible name
            ; in some Chrome builds. Never mistake that input for the result row.
            if controlType = "edit" || controlType = "combobox" || controlType = "combo box"
                || controlType = "document" || controlType = "pane"
                continue
            rect := element.Location
            if rect.w <= 0 || rect.h <= 0 || rect.x < 0 || rect.y < 0
                continue
            centreX := Round(rect.x + rect.w / 2)
            centreY := Round(rect.y + rect.h / 2)
            if centreX < searchPaneMinimumX
                continue
            if centreY <= coords["catalogue_search_input"][2] + 20
                continue

            exactName := StrLower(name) = StrLower(stockCode)
            score := (exactName ? 0 : 1000000000) + (rect.w * rect.h)
            if !best || score < bestScore {
                best := {
                    X: Round(rect.x),
                    Y: Round(rect.y),
                    W: Round(rect.w),
                    H: Round(rect.h),
                    CentreX: centreX,
                    CentreY: centreY,
                    RowText: name,
                    ScopeLabel: scopeLabel
                }
                bestScore := score
            }
        }
    }
    return best
}

CatalogueAccessibilityTextContainsExactCode(text, stockCode) {
    target := StrLower(Trim(stockCode))
    for _, token in StrSplit(NormaliseCatalogueTileText(text), " ") {
        if StrLower(token) = target
            return true
    }
    return false
}

RunPromotionTextWorkflow() {
    global cmsWinTitle, promotionText, promotionTextSaveEnabled
    global lastSavedNonMatrixProductIdentity

    textToPaste := Trim(promotionText, " `t`r`n")
    fieldAction := textToPaste = "" ? "cleared" : "filled"

    ActivateWindow(cmsWinTitle)
    ClearActiveCmsProductCode()

    ; Capture the exact simple-product identity before editing so department
    ; automation can find the completed catalogue row after Save.
    ClickPoint("overview_tab", 500)
    currentProductCode := SetActiveCmsProductCode(CopyFromPoint("stock_code"))
    completedProductName := CleanText(CopyFromPoint("product_name"))
    if completedProductName = ""
        throw Error("The current GO b2b Product Name is blank, so the promotion-text product cannot be identified safely.")

    ; Description keeps the promotional field at the bottom of the page.
    ; Allow the tab panel to finish opening before scrolling its page body.
    ClickPoint("description_tab", 1200)
    ScrollPromotionDescriptionToBottom()
    PasteToPoint("promotion_description_field", textToPaste)

    ClickPoint("custom_tab", 600)
    PasteToPoint("promotion_custom_field", textToPaste)

    LogText(
        "promotion-text",
        "Product name: " completedProductName
        . "`nProduct code: " currentProductCode
        . "`nSave enabled: " (promotionTextSaveEnabled ? "yes" : "no")
        . "`nField action: " fieldAction
        . "`n`nPromotional text:`n" textToPaste
    )

    if promotionTextSaveEnabled {
        lastSavedNonMatrixProductIdentity := Map(
            "productName", completedProductName,
            "productCode", currentProductCode
        )
        ClickPoint("product_save_button", 1000)
        Flash("Description and Custom promotional fields " fieldAction ", then the product was saved.", 3000)
    } else {
        Flash("Description and Custom promotional fields " fieldAction ".`nTEST MODE: the product was not saved.", 3500)
    }
    return true
}

ScrollPromotionDescriptionToBottom() {
    ; Do not send Ctrl+End here. The Description tab button still has keyboard
    ; focus after it is clicked, and GO b2b's tab strip can interpret End as a
    ; request to activate its final (Custom) tab. Native wheel input over a blank
    ; part of the page body scrolls Description without changing tabs.
    MouseMove 1620, 663, 0
    SendNativeMouseWheel(-1, 120)
    Sleep 700
}

InsertProductNameRecommendation(productNameRecommendation) {
    ClickPoint("overview_tab", 600)
    PasteToPoint("product_name", productNameRecommendation)
}

InsertMetaFields(metaTitle, metaDescription, htmlSnippet := "") {
    ClickPoint("description_tab", 600)
    PasteToPoint("meta_title", metaTitle)

    if IsFullContentMode() || IsSupplierProductCreationMode()
        PasteToPoint("html_snippet", htmlSnippet)

    PasteToPoint("meta_description", metaDescription)
}

InsertImageSeoFields(imageTitles, imageAlts, imageNames := 0) {
    if imageTitles.Length
        BeginSequentialImageMetadataInsertion(imageTitles.Length)
    Loop imageTitles.Length {
        imageName := imageNames && imageNames.Length >= A_Index ? imageNames[A_Index] : ""
        PasteImageMetadataToCms(A_Index, imageTitles[A_Index], imageAlts[A_Index], imageName)
    }
    if imageTitles.Length && !IsDepartmentMode()
        SaveTestingAccessibilityTree("cms-after-" imageTitles.Length "-image-metadata-records")
}

; ==========================================================
; IMAGE METADATA PASTE HELPERS
; ==========================================================

BeginSequentialImageMetadataInsertion(imageCount) {
    if imageCount < 1
        return

    if IsDepartmentMode() {
        if imageCount != 1
            throw Error("Department mode expects exactly one image metadata record; received " imageCount ".")
        OpenDepartmentImageGalleryByCoordinates("image-metadata")
        TestingLog(
            "cms-image-metadata-start",
            "Department mode opened its single image gallery by configured coordinates; UIA gallery discovery was skipped."
        )
        return
    }

    ; Use verified UIA page changes here as well as during image copying. Blind
    ; Previous clicks could leave the metadata run on the wrong carousel page.
    OpenFirstImageGalleryPage()
    TestingLog(
        "cms-image-metadata-start",
        "Image count=" imageCount "; gallery page 1 was verified through UIA."
    )
}

PasteImageMetadataToCms(imageIndex, imageTitle, imageAlt, imageName := "") {
    global imageGalleryPageSize, cmsImageGalleryReturnSettleMs

    ; Image cards are ordered left-to-right in groups of five. Image 6, 11,
    ; 16, etc. moves to the next page and reuses the first configured slot.
    if imageIndex > 1 && Mod(imageIndex - 1, imageGalleryPageSize) = 0 {
        TestingLog(
            "cms-image-page-advance",
            "Advancing to gallery page " GetImageGalleryPageForIndex(imageIndex) " for image " imageIndex "."
        )
        if !TryAdvanceImageGalleryPage()
            throw Error("Could not reach Image Gallery page " GetImageGalleryPageForIndex(imageIndex) " before editing image " imageIndex ".")
    }
    TestingLog(
        "cms-image-metadata",
        "Opening image " imageIndex
        . "; gallery_page=" GetImageGalleryPageForIndex(imageIndex)
        . "; slot=" (Mod(imageIndex - 1, imageGalleryPageSize) + 1)
        . "; name_chars=" StrLen(imageName)
        . "; title_chars=" StrLen(imageTitle)
        . "; alt_chars=" StrLen(imageAlt) "."
    )
    OpenCmsImageDetailsForMetadata(imageIndex)
    if imageName != ""
        PasteToPoint("image_name", imageName)
    PasteToPoint("image_title", imageTitle)
    PasteToPoint("image_alt", imageAlt)

    ; GO B2B requires this Image Save button to leave the image details page.
    ; This does not click the main product Save button.
    ClickPoint("image_save_button", 250)
    if IsDepartmentMode() {
        Sleep cmsImageGalleryReturnSettleMs
        TestingLog(
            "cms-image-gallery-return-coordinate-mode",
            "Department mode skipped the post-save gallery accessibility-tree verification for its single image."
        )
    } else
        WaitForCmsImageGalleryAfterDetailsSave(imageIndex)
    TestingLog(
        "cms-image-metadata-saved",
        IsDepartmentMode()
            ? "Image 1 detail record was populated and saved; department coordinate mode used a fixed return delay."
            : "Image " imageIndex " detail record was populated, saved, and the Image Gallery return was verified."
    )
}

OpenCmsImageDetailsForMetadata(imageIndex) {
    global cmsImageDetailsOpenAttempts, cmsImageDetailsButtonTimeoutMs, cmsImageDetailsFormTimeoutMs
    global imageGalleryPageSize

    slotIndex := Mod(imageIndex - 1, imageGalleryPageSize) + 1
    Loop cmsImageDetailsOpenAttempts {
        attempt := A_Index
        if IsDepartmentMode() {
            if imageIndex != 1
                throw Error("Department mode can open only its configured first image; received image " imageIndex ".")
            target := GetImageTarget(1)
            point := target["details_button"]
            TestingLog(
                "cms-image-details-open-attempt",
                "Image=1; attempt=" attempt "; slot=1; source=department-configured-coordinate; x=" point[1] "; y=" point[2] "."
            )
            Click point[1], point[2]
        } else {
            buttonInfo := WaitForVisibleImageGalleryDetailsButton(slotIndex, cmsImageDetailsButtonTimeoutMs)
            if buttonInfo {
                TestingLog(
                    "cms-image-details-open-attempt",
                    "Image=" imageIndex "; attempt=" attempt "; slot=" slotIndex
                    . "; source=UIA; x=" buttonInfo["x"] "; y=" buttonInfo["y"] "."
                )
                ; Use a physical click at the live UIA rectangle. This preserves the
                ; proven browser interaction while avoiding stale fixed coordinates.
                Click buttonInfo["x"], buttonInfo["y"]
            } else {
                ; Retain the configured screen point only as a compatibility fallback
                ; if Chrome temporarily declines to expose visible Details buttons.
                target := GetImageTarget(imageIndex)
                point := target["details_button"]
                TestingLog(
                    "cms-image-details-open-attempt",
                    "Image=" imageIndex "; attempt=" attempt "; slot=" slotIndex
                    . "; source=configured-fallback; x=" point[1] "; y=" point[2] "."
                )
                Click point[1], point[2]
            }
        }

        if WaitForCmsImageDetailsFormReady(cmsImageDetailsFormTimeoutMs) {
            TestingLog("cms-image-details-ready", "Image=" imageIndex "; attempt=" attempt ".")
            return true
        }

        TestingLog(
            "cms-image-details-open-miss",
            "Image=" imageIndex "; attempt=" attempt "; the Title and Alt edit controls did not appear."
        )
        if !IsDepartmentMode()
            SaveTestingAccessibilityTree("cms-image-" imageIndex "-details-open-attempt-" attempt "-failed")
        if attempt < cmsImageDetailsOpenAttempts {
            ; Rebuild the exact page from a verified page 1 before retrying. This
            ; handles a Save transition swallowing the first Details click.
            if IsDepartmentMode()
                OpenDepartmentImageGalleryByCoordinates("image-metadata-retry")
            else
                OpenImageGalleryPageForIndex(imageIndex)
        }
    }

    throw Error(
        "Image " imageIndex " Details did not open after " cmsImageDetailsOpenAttempts " verified attempt(s)."
        . " The script stopped before pasting into the wrong page."
    )
}

WaitForVisibleImageGalleryDetailsButton(slotIndex, timeoutMs) {
    deadline := A_TickCount + timeoutMs
    Loop {
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            gallery := FindImageGalleryScope(document)
            if gallery {
                buttons := gallery.FindElements({ Name: "Details", Type: "Button", mm: 3, cs: 0 })
                visibleButtons := []
                for _, button in buttons {
                    try {
                        if button.IsOffscreen || !button.IsEnabled
                            continue
                        rect := button.Location
                        if rect.w <= 0 || rect.h <= 0
                            continue
                        item := Map(
                            "x", Round(rect.x + rect.w / 2),
                            "y", Round(rect.y + rect.h / 2)
                        )
                        insertAt := visibleButtons.Length + 1
                        for existingIndex, existing in visibleButtons {
                            if item["x"] < existing["x"] {
                                insertAt := existingIndex
                                break
                            }
                        }
                        visibleButtons.InsertAt(insertAt, item)
                    }
                }
                if visibleButtons.Length >= slotIndex
                    return visibleButtons[slotIndex]
            }
        }
        if A_TickCount >= deadline
            return 0
        Sleep 200
    }
}

WaitForCmsImageDetailsFormReady(timeoutMs) {
    deadline := A_TickCount + timeoutMs
    Loop {
        if IsEnabledUiaEditAtConfiguredPoint("image_title")
            && IsEnabledUiaEditAtConfiguredPoint("image_alt")
            return true
        if A_TickCount >= deadline
            return false
        Sleep 200
    }
}

IsEnabledUiaEditAtConfiguredPoint(coordinateName) {
    global coords
    point := coords[coordinateName]

    try node := UIA.SmallestElementFromPoint(point[1], point[2])
    catch
        return false

    Loop 8 {
        try {
            if StrLower(GetUiaControlTypeText(node)) = "edit" {
                if node.IsOffscreen || !node.IsEnabled
                    return false
                return true
            }
        }
        try parent := UIA.TreeWalkerTrue.GetParentElement(node)
        catch
            return false
        if !parent
            return false
        node := parent
    }
    return false
}

WaitForCmsImageGalleryAfterDetailsSave(imageIndex) {
    global cmsImageGalleryReturnTimeoutMs, cmsImageGalleryReturnSettleMs

    startedAt := A_TickCount
    WaitForImageGalleryAvailable(cmsImageGalleryReturnTimeoutMs)
    Sleep cmsImageGalleryReturnSettleMs
    ; Confirm the scope survived the final settle period instead of accepting a
    ; short-lived transitional tree immediately after Save.
    WaitForImageGalleryAvailable(cmsImageGalleryReturnTimeoutMs)
    TestingLog(
        "cms-image-gallery-return-ready",
        "Image=" imageIndex "; elapsed_ms=" (A_TickCount - startedAt) "."
    )
}

; ==========================================================
; VALIDATION
; ==========================================================

Flash(message, durationMs := 1500) {
    ToolTip message
    SetTimer () => ToolTip(), -durationMs
}

; ==========================================================
; CORE HELPERS
; ==========================================================

ActivateWindow(title, wakeDelayMs := 300) {
    TestingLog("window-activate-request", "Requested window: " title "; wake_delay_ms=" wakeDelayMs ".")
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
            TestingLog("window-activated", GetTestingActiveWindowSummary())
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

    TestingLog(
        "coordinate-click",
        "Name=" name "; x=" point[1] "; y=" point[2] "; delay_ms=" delayMs "; " GetTestingActiveWindowSummary()
    )
    Click point[1], point[2]
    Sleep delayMs
}

CopyFromPoint(name) {
    ClickPoint(name, 200)
    Sleep 150
    Send "^a"
    Sleep 150
    text := CopySelectedText(2, false)
    TestingLog("field-copy", "Field=" name "; chars=" StrLen(text) ".")
    return text
}

CopyOptionalFromPoint(name) {
    ClickPoint(name, 200)
    Sleep 150
    Send "^a"
    Sleep 150
    text := CopySelectedText(2, true)
    TestingLog("field-copy-optional", "Field=" name "; chars=" StrLen(text) ".")
    return text
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
    TestingLog("field-paste-start", "Field=" name "; expected_chars=" StrLen(text) "; maximum_attempts=" maxAttempts ".")

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
                TestingLog(
                    "field-paste-verified",
                    "Field=" name "; attempt=" attempt "; expected_chars=" StrLen(text) "; actual_chars=" StrLen(lastActual) "."
                )
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

    ; An intentionally blank value clears the selected CMS field.
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

SetActiveMatrixParentName(expectedName := "") {
    ; Matrix parents have no stock code, so their exact Product Name is also
    ; used as the safe identity for logs, backups and page verification.
    parentName := CleanText(CopyFromPoint("product_name"))
    if parentName = ""
        throw Error("The matrix parent Product Name is blank.")
    if expectedName != "" && NormaliseCatalogueProductName(parentName) != NormaliseCatalogueProductName(expectedName)
        throw Error("The open matrix parent does not match the saved product name.`nExpected: " expectedName "`nOpened: " parentName)
    SetActiveCmsProductCode(parentName)
    return parentName
}

; ==========================================================
; OPTIONAL TESTING-MODE DIAGNOSTICS
; ==========================================================

; ==========================================================
; SHARED SEO PROMPT SETTINGS
; ==========================================================

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
    global SeoAutomationMode, SeoPromptId, hardcodedPageUrl, requiredInternalLinksDefault, additionalProductNotesDefault, promotionText
    global testingModeEnabled, FiguredArtPromptTemplatePath, FiguredArtDefaultPromptTemplatePath

    testingWasEnabled := testingModeEnabled
    SeoAutomationMode := settings["seoAutomationMode"]
    SeoPromptId := settings["seoPromptId"]
    figuredArtOption := GetSeoPromptOption("figuredart", SeoAutomationMode = "figuredart" ? SeoPromptId : GetDefaultSeoPromptId("figuredart"))
    FiguredArtPromptTemplatePath := IsObject(figuredArtOption) ? figuredArtOption["path"] : FiguredArtDefaultPromptTemplatePath
    hardcodedPageUrl := settings["pageUrl"]
    requiredInternalLinksDefault := BuildBotzRecommendedInlinks(settings)
    additionalProductNotesDefault := settings["additionalNotes"] != "" ? settings["additionalNotes"] : "NONE"
    promotionText := settings["promotionText"]
    testingModeEnabled := settings["testingModeEnabled"]

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

    return Map(
        "seoAutomationMode", GetSeoAutomationMode(),
        "seoPromptId", GetDefaultSeoPromptId(GetSeoAutomationMode()),
        "pageUrl", botzDefaultPageUrl,
        "inlink1Name", "",
        "inlink1Url", "",
        "inlink2Name", "",
        "inlink2Url", "",
        "inlinkExtra", "",
        "additionalNotes", "",
        "promotionText", "",
        "testingModeEnabled", false
    )
}

OpenSeoPromptSettingsGui() {
    global botzPromptSettings, botzPromptSettingsGui

    if IsObject(botzPromptSettingsGui) {
        try {
            botzPromptSettingsGui.Show()
            return
        } catch {
            botzPromptSettingsGui := 0
        }
    }

    if !IsObject(botzPromptSettings)
        botzPromptSettings := CreateDefaultBotzPromptSettings()

    settingsGui := Gui("+AlwaysOnTop +OwnDialogs", "SEO Prompt Settings")
    settingsGui.MarginX := 16
    settingsGui.MarginY := 14
    settingsGui.SetFont("s10", "Segoe UI")

    controls := Map()
    settingsGui.AddText("xm", "SEO automation mode")
    controls["seoAutomationMode"] := settingsGui.AddDropDownList("xm y+4 w260", GetSeoAutomationModeOptions())
    controls["seoAutomationMode"].Choose(GetSeoAutomationModeOptionIndex(GetSeoAutomationMode()))
    settingsGui.AddText("xm y+6 w700", "Department runs: matrix modes process Matrix Product rows; promotion_text_reference runs its own catalogue-search batch.")

    controls["seoPromptLabel"] := settingsGui.AddText("xm y+14", "Prompt")
    initialPromptLabels := GetSeoPromptLabelsForMode(GetSeoAutomationMode())
    if initialPromptLabels.Length = 0
        initialPromptLabels := ["Not used by this mode"]
    controls["seoPrompt"] := settingsGui.AddDropDownList("xm y+4 w360", initialPromptLabels)
    controls["seoPrompt"].Choose(GetSeoPromptOptionsForMode(GetSeoAutomationMode()).Length
        ? GetSeoPromptOptionIndex(GetSeoAutomationMode(), botzPromptSettings["seoPromptId"])
        : 1)
    controls["seoPromptHelp"] := settingsGui.AddText("xm y+4 w700", "Only prompts registered to the selected mode are available.")
    controls["promptSelections"] := Map(GetSeoAutomationMode(), botzPromptSettings["seoPromptId"])

    controls["promotionTextLabel"] := settingsGui.AddText("xm y+14", "Promotional text")
    controls["promotionText"] := settingsGui.AddEdit("xm y+4 w700 r5", botzPromptSettings["promotionText"])
    controls["promotionTextHelp"] := settingsGui.AddText("xm y+4 w700", "Leave empty to clear Description and Custom promotional fields in either promotion mode.")
    controls["seoAutomationMode"].OnEvent("Change", UpdateSeoPromptSettingsControls.Bind(controls))
    controls["seoPrompt"].OnEvent("Change", RememberSeoPromptSelection.Bind(controls))
    UpdateSeoPromptSettingsControls(controls)

    controls["testingModeEnabled"] := settingsGui.AddCheckBox("xm y+14 w700", "Testing mode (save detailed diagnostics for future debugging)")
    controls["testingModeEnabled"].Value := botzPromptSettings["testingModeEnabled"] ? 1 : 0
    settingsGui.AddText("xm y+4 w700", "Records workflow events, timing/count samples, errors, window state and relevant accessibility trees in the debug folder.")

    settingsGui.AddText("xm y+14", "Cromartie page URL")
    controls["pageUrl"] := settingsGui.AddEdit("xm y+4 w700", botzPromptSettings["pageUrl"])

    settingsGui.SetFont("s10 Bold")
    settingsGui.AddText("xm y+16", "Recommended internal links")
    settingsGui.SetFont("s9 Norm")
    settingsGui.AddText("xm y+6 w220", "Inlink name")
    settingsGui.AddText("x+12 yp w468", "Inlink URL")

    controls["inlink1Name"] := settingsGui.AddEdit("xm y+4 w220", botzPromptSettings["inlink1Name"])
    controls["inlink1Url"] := settingsGui.AddEdit("x+12 yp w468", botzPromptSettings["inlink1Url"])
    controls["inlink2Name"] := settingsGui.AddEdit("xm y+8 w220", botzPromptSettings["inlink2Name"])
    controls["inlink2Url"] := settingsGui.AddEdit("x+12 yp w468", botzPromptSettings["inlink2Url"])

    settingsGui.AddText("xm y+14", "Extra inlink information")
    controls["inlinkExtra"] := settingsGui.AddEdit("xm y+4 w700 r3", botzPromptSettings["inlinkExtra"])

    settingsGui.AddText("xm y+14", "Additional notes")
    controls["additionalNotes"] := settingsGui.AddEdit("xm y+4 w700 r4", botzPromptSettings["additionalNotes"])

    saveButton := settingsGui.AddButton("xm y+16 w100 Default", "Save")
    cancelButton := settingsGui.AddButton("x+10 yp w100", "Cancel")
    saveButton.OnEvent("Click", SaveSeoPromptSettingsFromGui.Bind(settingsGui, controls))
    cancelButton.OnEvent("Click", CloseSeoPromptSettingsGui.Bind(settingsGui))
    settingsGui.OnEvent("Close", CloseSeoPromptSettingsGui)
    settingsGui.OnEvent("Escape", CloseSeoPromptSettingsGui)

    botzPromptSettingsGui := settingsGui
    settingsGui.Show("AutoSize Center")
    controls["seoAutomationMode"].Focus()
}

SaveSeoPromptSettingsFromGui(settingsGui, controls, *) {
    global botzPromptSettings, departmentAutomationActive, automaticWorkflowActive
    global promotionReferenceBatchActive

    settings := Map(
        "seoAutomationMode", StrLower(Trim(controls["seoAutomationMode"].Text)),
        "seoPromptId", GetSeoPromptIdFromOptionIndex(StrLower(Trim(controls["seoAutomationMode"].Text)), controls["seoPrompt"].Value),
        "pageUrl", Trim(controls["pageUrl"].Value),
        "inlink1Name", Trim(controls["inlink1Name"].Value),
        "inlink1Url", Trim(controls["inlink1Url"].Value),
        "inlink2Name", Trim(controls["inlink2Name"].Value),
        "inlink2Url", Trim(controls["inlink2Url"].Value),
        "inlinkExtra", Trim(controls["inlinkExtra"].Value),
        "additionalNotes", Trim(controls["additionalNotes"].Value),
        "promotionText", Trim(controls["promotionText"].Value, " `t`r`n"),
        "testingModeEnabled", controls["testingModeEnabled"].Value = 1
    )

    try {
        ValidateBotzPromptSettings(settings)
        if (departmentAutomationActive || automaticWorkflowActive || promotionReferenceBatchActive)
            && (settings["seoAutomationMode"] != GetSeoAutomationMode() || settings["seoPromptId"] != GetSeoPromptId())
            throw Error("The SEO mode or prompt cannot be changed while an automatic workflow is active. Stop or finish the current run first.")
        SaveBotzPromptSettings(settings)
        botzPromptSettings := settings
        ApplySharedSeoPromptSettings(settings)
        CloseSeoPromptSettingsGui(settingsGui)
        testingStatus := settings["testingModeEnabled"] ? "ON" : "OFF"
        Flash("SEO prompt settings saved.`nMode: " settings["seoAutomationMode"] "`nPrompt: " GetSeoPromptLabel(settings["seoAutomationMode"], settings["seoPromptId"]) "`nTesting mode: " testingStatus, 2500)
    } catch as err {
        ReportTestingError("save-seo-prompt-settings", err, false)
        MsgBox "SEO prompt settings were not saved.`n`n" err.Message
    }
}

UpdateSeoPromptSettingsControls(controls, *) {
    selectedMode := StrLower(Trim(controls["seoAutomationMode"].Text))
    selectedPromptId := controls["promptSelections"].Has(selectedMode)
        ? controls["promptSelections"][selectedMode]
        : GetDefaultSeoPromptId(selectedMode)
    labels := GetSeoPromptLabelsForMode(selectedMode)

    controls["seoPrompt"].Delete()
    if labels.Length {
        controls["seoPrompt"].Add(labels)
        controls["seoPrompt"].Choose(GetSeoPromptOptionIndex(selectedMode, selectedPromptId))
        controls["seoPrompt"].Enabled := true
        controls["seoPromptHelp"].Text := "Only prompts registered to " selectedMode " mode are available."
        RememberSeoPromptSelection(controls)
    } else {
        controls["seoPrompt"].Add(["Not used by this mode"])
        controls["seoPrompt"].Choose(1)
        controls["seoPrompt"].Enabled := false
        controls["seoPromptHelp"].Text := "This mode performs no ChatGPT prompt step."
        controls["promptSelections"][selectedMode] := ""
    }

    enabled := selectedMode = "promotion_text" || selectedMode = "promotion_text_reference"
    controls["promotionTextLabel"].Enabled := enabled
    controls["promotionText"].Enabled := enabled
    controls["promotionTextHelp"].Enabled := enabled
}

RememberSeoPromptSelection(controls, *) {
    selectedMode := StrLower(Trim(controls["seoAutomationMode"].Text))
    promptId := GetSeoPromptIdFromOptionIndex(selectedMode, controls["seoPrompt"].Value)
    controls["promptSelections"][selectedMode] := promptId
}

CloseSeoPromptSettingsGui(settingsGui, *) {
    global botzPromptSettingsGui

    try settingsGui.Destroy()
    botzPromptSettingsGui := 0
}

ValidateBotzPromptSettings(settings) {
    if !settings.Has("seoAutomationMode") || !IsValidSeoAutomationMode(settings["seoAutomationMode"])
        throw Error("Select a valid SEO automation mode.")
    if !settings.Has("seoPromptId")
        throw Error("The SEO prompt setting is missing.")
    if !IsValidSeoPromptForMode(settings["seoAutomationMode"], settings["seoPromptId"])
        throw Error("Select a prompt that belongs to the selected SEO automation mode.")
    if !settings.Has("promotionText")
        throw Error("The promotion-text setting is missing.")
    if !settings.Has("testingModeEnabled")
        throw Error("The testing-mode setting is missing.")
    if settings["testingModeEnabled"] != true && settings["testingModeEnabled"] != false
        throw Error("The testing-mode setting must be enabled or disabled.")
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

    temporaryPath := botzPromptSettingsFilePath ".tmp"
    if FileExist(temporaryPath)
        FileDelete temporaryPath
    FileAppend text, temporaryPath, "UTF-8"
    FileMove temporaryPath, botzPromptSettingsFilePath, 1
}

LoadBotzPromptSettings() {
    global botzPromptSettingsFilePath

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
    ; Files saved before the mode dropdown existed remain valid and retain the
    ; configured SeoAutomationMode from the top of this script until next save.
    settings["seoAutomationMode"] := values.Has("seo_automation_mode")
        ? StrLower(Trim(values["seo_automation_mode"]))
        : GetSeoAutomationMode()
    ; Settings saved before prompt selection existed use that mode's first
    ; registered prompt, preserving every previous workflow by default.
    settings["seoPromptId"] := values.Has("seo_prompt_id")
        ? StrLower(Trim(values["seo_prompt_id"]))
        : GetDefaultSeoPromptId(settings["seoAutomationMode"])
    ValidateBotzPromptSettings(settings)
    return settings
}

; ==========================================================
; BOTZ PRODUCT CREATION
; ==========================================================

BuildBotzPrompt(pageUrl) {
    global cmsWinTitle, botzState, botzPromptSettings, maximumImagesPerProduct

    try {
        ClearActiveCmsProductCode()
        ActivateWindow(cmsWinTitle)
        ClickPoint("overview_tab", 500)
        stockCode := SetActiveCmsProductCode(CopyFromPoint("stock_code"))
        productName := CleanText(CopyFromPoint("product_name"))
        if productName = ""
            throw Error("The GO b2b product name is blank.")

        matchCode := TransformBotzStockCode(stockCode)
        productFolder := FindUniqueBotzProductFolder(matchCode)
        productMdPath := productFolder "\product.md"
        imagesDir := productFolder "\images"
        if !FileExist(productMdPath)
            throw Error("The matched BOTZ folder has no product.md file: " productMdPath)
        if !DirExist(imagesDir)
            throw Error("The matched BOTZ folder has no images folder: " imagesDir)

        productMd := FileRead(productMdPath, "UTF-8")
        if CleanText(productMd) = ""
            throw Error("The matched product.md file is empty: " productMdPath)

        ; This scan deliberately happens immediately before request creation.
        ; product.md image lists are never read or trusted by the automation.
        attachmentImageFiles := EnumerateBotzImageFiles(imagesDir)
        if attachmentImageFiles.Length = 0
            throw Error("The matched BOTZ images folder contains no supported image files: " imagesDir)
        imageFiles := TakeFirstBotzImageFiles(attachmentImageFiles, maximumImagesPerProduct)
        imageManifest := BuildBotzImageManifest(imageFiles)

        promptTemplatePath := GetPromptTemplatePath()
        if !FileExist(promptTemplatePath)
            throw Error("The selected BOTZ prompt template was not found: " promptTemplatePath)
        if !IsObject(botzPromptSettings)
            InitialiseSeoPromptSettings()
        prompt := BuildBotzPromptFromSource(
            FileRead(promptTemplatePath, "UTF-8"),
            pageUrl,
            productName,
            productMd,
            imageFiles,
            botzPromptSettings,
            attachmentImageFiles
        )

        botzState := Map(
            "mode", "botz",
            "productName", productName,
            "stockCode", stockCode,
            "matchCode", matchCode,
            "productFolder", productFolder,
            "productMdPath", productMdPath,
            "productMdSize", FileGetSize(productMdPath),
            "productMdModified", FileGetTime(productMdPath, "M"),
            "initialGalleryCount", 0,
            "uploadedCount", 0,
            "pendingImageIndex", 0,
            "imageCount", imageFiles.Length,
            "images", imageFiles,
            "imageManifest", imageManifest
        )
        SaveBotzState(botzState)

        LogText("botz-source", BuildBotzSourceLog(botzState))
        LogSupplierChatGptImagePlan("BOTZ", "botz", attachmentImageFiles.Length, imageFiles.Length)
        LogText("botz-chatgpt-request", prompt)
        PastePromptToChatGPT(prompt)
        ValidateBotzSourcesUnchanged(botzState)
        AttachBotzImagesToChatGpt(attachmentImageFiles)
        Flash("BOTZ prompt and " attachmentImageFiles.Length " image attachment(s) were submitted to ChatGPT.`nGO b2b remains limited to the first " imageFiles.Length " image(s).", 3000)
    } catch as err {
        if HasActiveCmsProductCode() {
            LogText("botz-error", "Prompt build stopped: " err.Message)
            LogText("botz-skipped-product", "BOTZ product was not requested or changed: " err.Message)
        }
        throw
    }
}

TransformBotzStockCode(stockCode) {
    stockCode := CleanText(stockCode)
    LogText("botz-stock-code", "GO b2b stock code: " stockCode)
    if !RegExMatch(stockCode, "^[A-Za-z][0-9]{2,}$")
        throw Error("Invalid GO b2b stock code '" stockCode "'. Expected one leading letter followed by digits, similar to B91018.")

    matchCode := SubStr(stockCode, 2, StrLen(stockCode) - 2)
    if !RegExMatch(matchCode, "^[0-9]+$")
        throw Error("Removing the first and final stock-code characters did not produce a numeric BOTZ folder code.")
    LogText("botz-match-code", "Stock code " stockCode " transformed to exact folder code " matchCode ".")
    return matchCode
}

FindUniqueBotzProductFolder(matchCode) {
    global botzRootDir
    if !DirExist(botzRootDir)
        throw Error("BOTZ source root was not found: " botzRootDir)

    prefix := matchCode " "
    matches := []
    Loop Files botzRootDir "\*", "D" {
        if SubStr(A_LoopFileName, 1, StrLen(prefix)) = prefix
            matches.Push(A_LoopFileFullPath)
    }

    if matches.Length = 0
        throw Error("No BOTZ folder begins with the exact numeric prefix '" prefix "' under " botzRootDir ".")
    if matches.Length > 1 {
        matchList := ""
        for _, path in matches
            matchList .= (matchList = "" ? "" : "`n") path
        throw Error("Multiple BOTZ folders begin with the exact numeric prefix '" prefix "':`n" matchList)
    }

    LogText("botz-folder-match", "Exact prefix '" prefix "' matched: " matches[1])
    return matches[1]
}

LogSupplierChatGptImagePlan(supplierName, logPrefix, attachmentCount, cmsImageCount) {
    message := "Attaching all " attachmentCount " supplier image(s) to ChatGPT using Ctrl+A."
    message .= " The automation output, parser and GO b2b image work use only the first " cmsImageCount " image(s)."
    if attachmentCount > cmsImageCount
        message .= " The remaining " (attachmentCount - cmsImageCount) " attachment(s) are reference context only."
    LogText(logPrefix "-image-plan", message)
}

BuildBotzSourceLog(state) {
    text := "Product name: " state["productName"]
    text .= "`nGO b2b stock code: " state["stockCode"]
    text .= "`nTransformed matching code: " state["matchCode"]
    text .= "`nMatched BOTZ folder: " state["productFolder"]
    text .= "`nproduct.md path: " state["productMdPath"]
    text .= "`nDiscovered image count: " state["imageCount"]
    for index, imagePath in state["images"]
        text .= "`nImage " index ": " imagePath
    return text
}

AttachBotzImagesToChatGpt(imageFiles, supplierName := "BOTZ", logPrefix := "botz") {
    if imageFiles.Length = 0
        throw Error("No " supplierName " images were supplied for ChatGPT attachment.")

    SplitPath imageFiles[1], , &imagesDir
    ValidateBotzCtrlAImageFolder(imagesDir, imageFiles, supplierName)

    selectionAttempted := false
    try {
        ToolTip "Opening ChatGPT attachments for " imageFiles.Length " " supplierName " images..."
        OpenChatGptFilePicker()
        selectionAttempted := true
        ChooseAllBotzImagesInPicker(imagesDir, supplierName)
        WaitForBotzChatAttachmentBatch(imageFiles, supplierName)
        for index, imagePath in imageFiles
            LogText(logPrefix "-chatgpt-attachment", "Batch submitted image " index " of " imageFiles.Length ": " imagePath)
        LogText(logPrefix "-chatgpt-attachment", "Attachment settle timer completed for " imageFiles.Length " requested image(s).")
        SubmitBotzChatGptDraft(supplierName, logPrefix)
        ToolTip()
        return true
    } catch as err {
        ToolTip()
        Send "{Esc}"
        LogText(logPrefix "-chatgpt-attachment-error", "Attachment batch failed: " err.Message)
        if selectionAttempted
            throw Error("The ChatGPT attachment selection started but did not complete safely. It was not retried, to avoid duplicates: " err.Message)
        throw
    }
}

OpenChatGptFilePicker() {
    global chatgptWinTitle, botzFilePickerTimeoutMs
    ActivateWindow(GetChatGptWinTitle(), 500)
    ClickPoint("chat_add_button", 900)
    ClickPoint("chat_add_attachments_button", 700)
    picker := WinWaitActive("ahk_class #32770", , botzFilePickerTimeoutMs / 1000)
    if !picker
        throw Error("The Windows file picker did not open after clicking ChatGPT + at 2246,1026 and Add attachments at 2317,395.")
    return picker
}

ChooseSingleFileInPicker(filePath) {
    if !FileExist(filePath)
        throw Error("File picker source no longer exists: " filePath)
    ChooseFileSelectionInPicker(filePath)
}

ChooseAllBotzImagesInPicker(imagesDir, supplierName := "BOTZ") {
    global botzFilePickerTimeoutMs, botzChatPickerSelectAllMs
    picker := NavigateSupplierImagePickerToFolder(imagesDir, supplierName)
    FocusWindowsFilePickerList(picker)
    Sleep 700
    Send "^a"
    ToolTip "All " supplierName " images selected.`nWaiting before confirming..."
    Sleep botzChatPickerSelectAllMs
    Send "{Enter}"

    if !WinWaitClose("ahk_id " picker, , botzFilePickerTimeoutMs / 1000)
        throw Error("The Windows file picker did not close after Ctrl+A and confirmation.")
}

NavigateSupplierImagePickerToFolder(imagesDir, supplierName) {
    global botzChatPickerFolderLoadMs
    if !DirExist(imagesDir)
        throw Error(supplierName " images folder no longer exists: " imagesDir)

    picker := WinExist("A")
    if !picker || !WinActive("ahk_class #32770")
        throw Error("The Windows file picker is not active.")

    savedClip := ClipboardAll()
    try {
        A_Clipboard := ""
        A_Clipboard := imagesDir
        if !ClipWait(2)
            throw Error("The " supplierName " images-folder path could not be placed on the clipboard.")
        Send "^l"
        Sleep 600
        Send "^a"
        Send "^v"
        Sleep 600
        Send "{Enter}"
        ToolTip "Waiting for the " supplierName " images folder to open..."
        Sleep botzChatPickerFolderLoadMs
    } finally {
        A_Clipboard := savedClip
    }
    return picker
}

FocusWindowsFilePickerList(picker) {
    candidates := ["DirectUIHWND2", "DirectUIHWND1", "SysListView321", "SHELLDLL_DefView1"]
    for _, controlName in candidates {
        try {
            if !ControlGetHwnd(controlName, "ahk_id " picker)
                continue
            ControlFocus controlName, "ahk_id " picker
            return controlName
        }
    }
    throw Error("The Windows file list could not be focused, so Ctrl+A was not sent.")
}

ChooseFileSelectionInPicker(selectionText) {
    global botzFilePickerTimeoutMs
    picker := WinExist("A")
    if !picker || !WinActive("ahk_class #32770")
        throw Error("The Windows file picker is not active.")

    savedClip := ClipboardAll()
    try {
        A_Clipboard := ""
        A_Clipboard := selectionText
        if !ClipWait(2)
            throw Error("The file selection could not be placed on the clipboard.")
        Send "!n"
        Sleep 250
        Send "^a"
        Send "^v"
        Sleep 250
        Send "{Enter}"
        if !WinWaitClose("ahk_id " picker, , botzFilePickerTimeoutMs / 1000)
            throw Error("The Windows file picker did not close after submitting the file selection.")
    } finally {
        A_Clipboard := savedClip
    }
}

WaitForBotzChatAttachmentBatch(imageFiles, supplierName := "BOTZ") {
    global botzChatAttachmentSettleMs
    startedAt := A_TickCount
    Loop {
        elapsed := A_TickCount - startedAt
        ToolTip "Waiting for ChatGPT to process " imageFiles.Length " " supplierName " attachments...`n" Round(elapsed / 1000, 1) " seconds"
        if elapsed >= botzChatAttachmentSettleMs
            break
        Sleep 500
    }
    return true
}

SubmitBotzChatGptDraft(supplierName := "BOTZ", logPrefix := "botz") {
    global chatgptWinTitle, botzChatAttachmentSettleMs
    ; WaitForBotzChatAttachmentBatch supplies the full ten-second period for
    ; the draft to finish loading its images.
    ToolTip supplierName " attachments settled. Sending the prepared request..."
    ActivateWindow(GetChatGptWinTitle(), 300)
    FocusChatGptInputForPaste()
    TestingLog("chatgpt-pre-submit-wait", "Delay_ms=0; attachment_settle_ms=" botzChatAttachmentSettleMs "; workflow=" logPrefix "; supplier=" supplierName ".")
    LogText(logPrefix "-chatgpt-submit", "Pressing Enter after the " Round(botzChatAttachmentSettleMs / 1000, 1) "-second " supplierName " attachment timer.")
    Send "{Enter}"
}

PasteBotzOutputToCms() {
    global cmsWinTitle, useRecommendedProductName
    global lastSavedNonMatrixProductIdentity

    try {
        ClearActiveCmsProductCode()
        response := A_Clipboard
        state := LoadBotzState()
        SetActiveCmsProductCode(state["stockCode"])
        ValidateBotzSourcesUnchanged(state)
        block := ExtractValidatedAutomationBlock(response)
        output := ParseBotzAutomationOutput(block, state)
        LogText("botz-chatgpt-output", response)
        LogText("botz-parsed-output", BuildBotzParsedOutputLog(output))

        ActivateWindow(cmsWinTitle)
        VerifyBotzCmsProduct(state, output)
        UploadAndPopulateBotzImages(state, output)

        completedProductName := state["productName"]
        if useRecommendedProductName && IsUsableProductNameRecommendation(output["productNameRecommendation"]) {
            InsertProductNameRecommendation(output["productNameRecommendation"])
            completedProductName := CleanText(CopyFromPoint("product_name"))
            if completedProductName = ""
                throw Error("The updated BOTZ Product Name could not be read back from GO b2b.")
        }
        InsertMetaFields(output["metaTitle"], output["metaDescription"], output["htmlSnippet"])
        lastSavedNonMatrixProductIdentity := Map(
            "productName", completedProductName,
            "productCode", state["stockCode"]
        )
        ClickPoint("product_save_button", 1000)

        LogText("botz-product-complete", "Completed BOTZ Product Creation for '" state["productName"] "' (" state["stockCode"] ") with " state["imageCount"] " image(s).")
        Flash("BOTZ product created and saved with " state["imageCount"] " image(s).", 3000)
    } catch as err {
        if HasActiveCmsProductCode() {
            LogText("botz-error", "Product update stopped: " err.Message)
            LogText("botz-skipped-product", "BOTZ product was not completed: " err.Message)
        }
        throw
    }
}

ValidateBotzSourcesUnchanged(state) {
    global maximumImagesPerProduct
    if !FileExist(state["productMdPath"])
        throw Error("The saved BOTZ product.md no longer exists: " state["productMdPath"])
    if FileGetSize(state["productMdPath"]) != state["productMdSize"] || FileGetTime(state["productMdPath"], "M") != state["productMdModified"]
        throw Error("product.md changed after the ChatGPT request was built. Rebuild the BOTZ prompt before continuing.")

    matchedFolder := FindUniqueBotzProductFolder(state["matchCode"])
    if StrLower(matchedFolder) != StrLower(state["productFolder"])
        throw Error("The exact BOTZ folder match changed after the request was built. Rebuild the BOTZ prompt.")

    currentImages := EnumerateBotzImageFiles(state["productFolder"] "\images", maximumImagesPerProduct)
    if !BotzPathArraysMatch(currentImages, state["images"])
        throw Error("The BOTZ images folder changed after the ChatGPT request was built. Rebuild the prompt so image order and output fields remain aligned.")
    Loop currentImages.Length {
        imagePath := currentImages[A_Index]
        savedItem := state["imageManifest"][A_Index]
        if FileGetSize(imagePath) != savedItem["size"] || FileGetTime(imagePath, "M") != savedItem["modified"]
            throw Error("BOTZ image " A_Index " changed after the ChatGPT request was built: " imagePath ". Rebuild the prompt before uploading.")
    }
}

VerifyBotzCmsProduct(state, output) {
    ClickPoint("overview_tab", 500)
    currentProductName := CleanText(CopyFromPoint("product_name"))
    currentStockCode := CleanText(CopyFromPoint("stock_code"))
    if currentStockCode != state["stockCode"]
        throw Error("The open GO b2b stock code changed. Expected '" state["stockCode"] "', found '" currentStockCode "'.")
    if TransformBotzStockCode(currentStockCode) != state["matchCode"]
        throw Error("The open GO b2b product no longer maps to the saved BOTZ folder code.")

    originalMatches := NormaliseHarmlessWhitespace(currentProductName) = NormaliseHarmlessWhitespace(state["productName"])
    recommendedMatches := IsUsableProductNameRecommendation(output["productNameRecommendation"])
        && NormaliseHarmlessWhitespace(currentProductName) = NormaliseHarmlessWhitespace(output["productNameRecommendation"])
    if !originalMatches && !recommendedMatches
        throw Error("The open GO b2b product name does not match the saved BOTZ run. Expected '" state["productName"] "', found '" currentProductName "'.")
    LogText("botz-product-verified", "Product name: " currentProductName "`nStock code: " currentStockCode "`nFolder code: " state["matchCode"])
}

UploadAndPopulateBotzImages(state, output) {
    if state["pendingImageIndex"]
        throw Error("A previous BOTZ run stopped while image " state["pendingImageIndex"] " was being added. Inspect that image manually before retrying; no image was uploaded twice.")
    if state["uploadedCount"] = state["imageCount"] {
        LogText("botz-upload-recovery", "Saved BOTZ progress already marks all " state["imageCount"] " image detail record(s) complete; uploads were skipped.")
        return true
    }

    startIndex := state["uploadedCount"] + 1
    remaining := state["imageCount"] - state["uploadedCount"]
    LogText("botz-upload-recovery", "Starting/resuming BOTZ upload at image " startIndex " of " state["imageCount"] ".")

    Loop remaining {
        imageIndex := startIndex + A_Index - 1
        imagePath := state["images"][imageIndex]
        try {
            UploadAndPopulateSingleBotzImage(state, imagePath, imageIndex, state["imageCount"], output)
            state["uploadedCount"] := imageIndex
            state["pendingImageIndex"] := 0
            SaveBotzState(state)
        } catch as err {
            LogText("botz-upload-error", "Image " imageIndex " of " state["imageCount"] ": " imagePath "`n" err.Message)
            throw Error("BOTZ image upload/details stopped at image " imageIndex " of " state["imageCount"] ": " err.Message)
        }
    }
    return true
}

UploadAndPopulateSingleBotzImage(state, imagePath, imageIndex, totalImages, output) {
    global botzFilePickerTimeoutMs, botzImagesTabLoadMs, botzImageDetailsLoadMs
    if !FileExist(imagePath)
        throw Error("Image source no longer exists: " imagePath)

    ; Give the Images tab time to render before clicking its Add button.
    ClickPoint("images_tab", botzImagesTabLoadMs)
    LogText("botz-image-upload", "Starting image " imageIndex " of " totalImages ": " imagePath)
    ClickPoint("image_add_button", 500)
    picker := WinWaitActive("ahk_class #32770", , botzFilePickerTimeoutMs / 1000)
    if !picker
        throw Error("The GO b2b Add button did not open the Windows file picker.")
    ChooseSingleFileInPicker(imagePath)

    ; The file has been submitted. Persist an ambiguous in-progress state before
    ; touching the detail form so recovery cannot upload the same image twice.
    state["pendingImageIndex"] := imageIndex
    SaveBotzState(state)

    ToolTip "Waiting for image " imageIndex " detail fields..."
    Sleep botzImageDetailsLoadMs
    PasteToPoint("image_name", output["imageNames"][imageIndex])
    PasteToPoint("image_title", output["imageTitles"][imageIndex])
    PasteToPoint("image_alt", output["imageAlts"][imageIndex])
    ClickPoint("image_save_button", 1200)

    LogText(
        "botz-image-metadata",
        "Uploaded and saved image " imageIndex " of " totalImages ": " imagePath
        . "`nName: " output["imageNames"][imageIndex]
        . "`nTitle: " output["imageTitles"][imageIndex]
        . "`nAlt/tag: " output["imageAlts"][imageIndex]
    )
}

; ==========================================================
; STRICT IMAGE/MATRIX OUTPUT PARSING
; ==========================================================

; ==========================================================
; MATRIX PROMPT, STATE AND INSERTION
; ==========================================================

BuildMatrixImagePrompt(pageUrl) {
    global cmsWinTitle, chatgptWinTitle, imageCountToProcess, matrixState
    global additionalProductNotesDefault, activeMatrixParentProductName
    ValidateImageTargetConfig()
    ClearActiveCmsProductCode()
    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    parentName := SetActiveMatrixParentName()
    activeMatrixParentProductName := parentName
    ClickPoint("description_tab", 600)
    parentTitle := CopyOptionalFromPoint("meta_title")
    firstHtml := ""
    parentDescription := CopyOptionalFromPoint("meta_description")
    parentImageCount := DetectAndSetImageCountFromImagesTab()
    if parentImageCount
        if !TryCopyCmsImagesToChatGPT(false) && IsAutomaticWorkflowExecutionEnabled()
            throw Error("Full workflow automation stopped because the matrix parent images were not pasted into ChatGPT successfully.")
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
        ; The initial discovery tree is still fresh for child 1. Every later
        ; child gets one new tree after the parent has been fully reopened.
        controls := p = 1 ? initial : ReacquireAndValidateMatrixOrder(products)
        ClickMatrixEditButton(controls["buttons"][p])
        WaitForChildProductPage(p, productCount)
        if p = 1 {
            ClickPoint("description_tab", 600)
            firstHtml := CopyOptionalFromPoint("html_snippet")
        }
        products[p]["imageCount"] := DetectAndSetImageCountFromImagesTab()
        if products[p]["imageCount"]
            if !TryCopyCmsImagesToChatGPT(false) && IsAutomaticWorkflowExecutionEnabled()
                throw Error("Full workflow automation stopped because images for matrix product " p " were not pasted into ChatGPT successfully.")
        ActivateWindow(cmsWinTitle)
        ClickPoint("matrix_child_cancel_button", 300)
        WaitForMatrixSkuPage(p, productCount)
    }
    matrixState := Map("mode", "matrix_image", "parentProductName", parentName, "productCount", productCount, "parentImageCount", parentImageCount, "products", products)
    SaveMatrixState(matrixState)
    promptTemplatePath := GetPromptTemplatePath()
    if !FileExist(promptTemplatePath)
        throw Error("The selected matrix-image prompt template was not found: " promptTemplatePath)
    prompt := BuildMatrixPromptFromState(FileRead(promptTemplatePath, "UTF-8"), pageUrl, parentTitle, parentDescription, firstHtml, matrixState)
    LogText("matrix_image-parent-context", "Parent: " parentName "`nURL: " pageUrl "`nChildren: " productCount "`nParent images: " parentImageCount "`nTotal images: " GetMatrixTotalImageCount(matrixState))
    LogText("matrix_image-prompt", prompt)
    PastePromptToChatGPT(prompt)
    ActivateWindow(GetChatGptWinTitle())
    FocusChatGptInputForPaste()
    Flash("Matrix prompt and attachments are ready for manual review.", 3000)
}

BuildMatrixFullPrompt(pageUrl) {
    global cmsWinTitle, chatgptWinTitle, imageCountToProcess, matrixFullState
    global activeMatrixParentProductName
    ValidateImageTargetConfig()
    ClearActiveCmsProductCode()
    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    parentName := SetActiveMatrixParentName()
    activeMatrixParentProductName := parentName
    ClickPoint("description_tab", 600)
    parentTitle := CopyOptionalFromPoint("meta_title")
    parentDescription := CopyOptionalFromPoint("meta_description")
    parentImageCount := DetectAndSetImageCountFromImagesTab()
    if parentImageCount
        if !TryCopyCmsImagesToChatGPT(false) && IsAutomaticWorkflowExecutionEnabled()
            throw Error("Full workflow automation stopped because the matrix parent images were not pasted into ChatGPT successfully.")
    ; Rebuild the parent after inspecting its Images tab. The reopen helper
    ; returns on a fresh Matrix SKUs tab, ready for the first UIA lookup.
    ActivateWindow(cmsWinTitle)
    FullyReopenActiveMatrixParent()
    initial := ReacquireMatrixSkuControls(0)
    productCount := initial["buttons"].Length
    products := []
    Loop productCount {
        p := A_Index
        rowText := NormaliseMatrixRowText(initial["buttons"][p].RowText)
        exactName := ExtractMatrixProductNameFromRow(rowText, p)
        connectedSize := ExtractConnectedMatrixSkuSize(rowText)
        products.Push(Map("index", p, "productName", exactName, "connectedSize", connectedSize, "variantContext", ExtractMatrixVariantFromRow(rowText, exactName), "skuRowText", rowText, "originalHtmlSnippet", "", "imageCount", 0))
    }

    ; Visit every child separately. As in matrix_image, fully close and reopen
    ; the parent after every child return because GO b2b otherwise leaves
    ; Chrome's accessibility tree in a broken/stale state.
    Loop productCount {
        p := A_Index
        ; Do not build a second tree in the same SKU menu before child 1.
        controls := p = 1 ? initial : ReacquireAndValidateMatrixOrder(products)
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
            if !TryCopyCmsImagesToChatGPT(false) && IsAutomaticWorkflowExecutionEnabled()
                throw Error("Full workflow automation stopped because images for matrix product " p " were not pasted into ChatGPT successfully.")
        ActivateWindow(cmsWinTitle)
        LogText("matrix_full-child-context", "Product " p ": " products[p]["productName"] "`nConnected SKU size: " products[p]["connectedSize"] "`nVariant: " products[p]["variantContext"] "`nSKU row: " products[p]["skuRowText"] "`nHTML:`n" products[p]["originalHtmlSnippet"])
        ClickPoint("matrix_child_cancel_button", 300)
        WaitForMatrixSkuPage(p, productCount)
    }

    matrixFullState := Map("mode", "matrix_full", "parentProductName", parentName, "productCount", productCount, "parentImageCount", parentImageCount, "products", products)
    SaveMatrixState(matrixFullState)
    promptTemplatePath := GetPromptTemplatePath()
    if !FileExist(promptTemplatePath)
        throw Error("The selected matrix-full prompt template was not found: " promptTemplatePath)
    prompt := BuildMatrixFullPromptFromState(FileRead(promptTemplatePath, "UTF-8"), pageUrl, parentTitle, parentDescription, matrixFullState)
    LogText("matrix_full-parent-context", "Parent: " parentName "`nURL: " pageUrl "`nMeta title: " parentTitle "`nMeta description: " parentDescription "`nChildren: " productCount "`nParent images: " parentImageCount "`nTotal images: " GetMatrixTotalImageCount(matrixFullState))
    LogText("matrix_full-prompt", prompt)
    PastePromptToChatGPT(prompt)

    ActivateWindow(GetChatGptWinTitle())
    FocusChatGptInputForPaste()
    Flash("Matrix-full prompt and attachments are ready for manual review.", 3000)
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

PasteMatrixFullOutputToCms() {
    global cmsWinTitle, imageCountToProcess, imageTargets, activeMatrixParentProductName, useRecommendedProductName
    global departmentAutomationActive
    state := LoadMatrixState("matrix_full")
    activeMatrixParentProductName := state["parentProductName"]
    ValidateMatrixStateImageTargets(state, imageTargets.Length)
    ClearActiveCmsProductCode()
    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    activeMatrixParentProductName := SetActiveMatrixParentName(state["parentProductName"])
    response := A_Clipboard
    block := ExtractBetween(response, "===AUTOMATION_OUTPUT_START===", "===AUTOMATION_OUTPUT_END===")
    if block = ""
        throw Error("A complete matrix-full automation block is not on the clipboard.")

    ; Parsing and validation finish before the first CMS field is changed.
    output := ParseMatrixFullOutput(block, state)
    LogText("matrix_full-chatgpt-output", response)
    LogText("matrix_full-automation-block", block)
    LogText("matrix_full-parsed-output", BuildMatrixFullParsedLog(output))
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
        BeginSequentialImageMetadataInsertion(state["parentImageCount"])
        Loop state["parentImageCount"]
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
            ClickPoint("description_tab", 600)
            ; Child matrix SKUs must inherit metadata from the parent matrix
            ; page. Explicitly clear any legacy child-level metadata before
            ; replacing the child's HTML description.
            PasteToPoint("meta_title", "")
            PasteToPoint("meta_description", "")
            PasteToPoint("html_snippet", output["products"][p]["htmlSnippet"])
            if childImageCount
                BeginSequentialImageMetadataInsertion(childImageCount)
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
    completionMessage := "Matrix-full SEO complete.`nChild products: " state["productCount"] "`nParent images: " state["parentImageCount"] "`nChild HTML snippets updated: " state["productCount"] "`nTotal image records updated: " totalImages "`n" nameStatus "`nThe parent was saved/reopened by the matrix accessibility-tree recovery workflow."
    if !departmentAutomationActive
        MsgBox completionMessage
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
    global departmentAutomationActive
    state := LoadMatrixState()
    activeMatrixParentProductName := state["parentProductName"]
    ValidateMatrixStateImageTargets(state, imageTargets.Length)
    ClearActiveCmsProductCode()
    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    activeMatrixParentProductName := SetActiveMatrixParentName(state["parentProductName"])
    response := A_Clipboard
    block := ExtractBetween(response, "===AUTOMATION_OUTPUT_START===", "===AUTOMATION_OUTPUT_END===")
    if block = ""
        throw Error("A complete matrix automation block is not on the clipboard.")
    output := ParseMatrixImageOutput(block, state)
    LogText("matrix_image-chatgpt-output", response)
    if state["parentImageCount"] {
        BeginSequentialImageMetadataInsertion(state["parentImageCount"])
        Loop state["parentImageCount"]
            PasteImageMetadataToCms(A_Index, output["parentImageTitles"][A_Index], output["parentImageAlts"][A_Index])
    }
    ; Saving/reopening also guarantees a fresh matrix accessibility tree after
    ; parent-image detail edits.
    FullyReopenActiveMatrixParent()
    ; Each child now receives exactly one fresh SKU-tree scan after the parent
    ; has been fully closed and reopened. Never reuse coordinates from the
    ; previous parent-menu instance.
    Loop state["productCount"] {
        p := A_Index
        try {
            controls := ReacquireAndValidateMatrixOrder(state["products"])
            ClickMatrixEditButton(controls["buttons"][p])
            WaitForChildProductPage(p, state["productCount"])
            ClickPoint("overview_tab", 400)
            currentName := CopyFromPoint("product_name")
            if NormaliseHarmlessWhitespace(currentName) != NormaliseHarmlessWhitespace(state["products"][p]["productName"])
                throw Error("current child name no longer matches saved product " p " ('" state["products"][p]["productName"] "').")
            childImageCount := state["products"][p]["imageCount"]
            if childImageCount
                BeginSequentialImageMetadataInsertion(childImageCount)
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
    if !departmentAutomationActive
        MsgBox "Matrix image SEO complete.`nProducts: " state["productCount"] "`nParent images: " state["parentImageCount"] "`nTotal image records: " total
}

; ==========================================================
; UIA-V2 MATRIX DISCOVERY AND SAFE REACQUISITION
; ==========================================================

ReacquireMatrixSkuControls(expectedCount := 0) {
    global matrixUiaSearchTimeoutMs, matrixStableDurationMs, matrixSkuTabSettleDelayMs
    global LastDocument, LastEditButtons
    lastProblem := ""
    try {
        Loop 2 {
            attempt := A_Index
            ShowMatrixLookupStatus("Reading Chrome accessibility tree...`nAttempt " attempt " of 2")
            try {
                result := WaitForMatrixModalScope(matrixUiaSearchTimeoutMs)
                document := result["document"]
                scope := result["scope"]
                LastDocument := document
                if !scope
                    throw Error("No stable matrix SKU rows became available within " matrixUiaSearchTimeoutMs " ms.")

                ShowMatrixLookupStatus("Collecting all SKU rows while scrolling...`nAttempt " attempt " of 2")
                buttons := CollectAllMatrixSkuButtons(scope)
                LastEditButtons := buttons
                if buttons.Length = 0
                    throw Error("The matrix scope appeared, but its child Edit controls had not finished rebuilding.")
                if expectedCount && buttons.Length != expectedCount
                    throw Error("Matrix child count is not stable: expected " expectedCount ", detected " buttons.Length ".")
                return Map("document", document, "scope", scope, "buttons", buttons)
            } catch as err {
                lastProblem := err.Message
                LastDocument := 0
                LastEditButtons := []
            }

            if attempt = 1 {
                ShowMatrixLookupStatus("Matrix SKU page was not stable yet.`nWaiting five seconds before retrying...")
                Sleep matrixSkuTabSettleDelayMs
            }
        }
        throw Error(
            "Matrix child controls were still unavailable after two stable-tree attempts."
            . (lastProblem != "" ? "`nLast problem: " lastProblem : "")
            . "`nPress F9 for an accessibility-tree dump."
        )
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
    global matrixStableDurationMs
    deadline := A_TickCount + timeoutMs
    priorSignature := ""
    stableSince := 0
    Loop {
        ShowMatrixLookupStatus("Waiting for stable matrix SKU rows...")
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            scope := FindMatrixModalScope(document)
            headingFound := !!scope
            ; Chrome does not always expose the modal heading. A visible Edit
            ; control whose nearest row contains both Name and StockCode is a
            ; stronger SKU-specific fallback than searching generic page text.
            if !scope && HasVisibleMatrixSkuRows(document)
                scope := document

            if scope && HasVisibleMatrixSkuRows(scope) {
                visibleButtons := GetUniqueVisibleEditLocations(scope)
                signature := BuildLocationSignature(visibleButtons)
                if visibleButtons.Length && signature = priorSignature {
                    if stableSince && A_TickCount - stableSince >= matrixStableDurationMs
                        return Map("document", document, "scope", scope, "headingFound", headingFound)
                } else if visibleButtons.Length {
                    priorSignature := signature
                    stableSince := A_TickCount
                } else {
                    priorSignature := ""
                    stableSince := 0
                }
            } else {
                priorSignature := ""
                stableSince := 0
            }
        } catch {
            priorSignature := ""
            stableSince := 0
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
    ; For a small, fully visible matrix, ReacquireMatrixSkuControls has already
    ; produced a stable live rectangle in this exact parent-menu instance. Use
    ; it directly instead of building a second accessibility tree before the
    ; click. Large scrolling matrices still need to reveal the saved row first.
    ToolTip()
    CoordMode "Mouse", "Screen"
    currentItem := item
    if item.HasOwnProp("RowKey") && (!item.HasOwnProp("RequiresScroll") || item.RequiresScroll)
        currentItem := FindCurrentMatrixSkuButton(item)
    MouseMove currentItem.CentreX, currentItem.CentreY, 0
    Sleep 150
    Click currentItem.CentreX, currentItem.CentreY
    Sleep 750
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
    global matrixPageWaitTimeoutMs, matrixNavigationDelayMs, matrixStableDurationMs
    Sleep matrixNavigationDelayMs
    deadline := A_TickCount + matrixPageWaitTimeoutMs
    readySince := 0
    Loop {
        ShowMatrixLookupStatus("Waiting for child product " productIndex " of " productCount " to open...`nChecking the accessibility tree.")
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            parentStillPresent := IsMatrixModalPresent(document) || !!FindMatrixModalScope(document)
            if !parentStillPresent {
                if !readySince
                    readySince := A_TickCount
                if A_TickCount - readySince >= matrixStableDurationMs {
                    ToolTip()
                    Sleep 1000
                    return true
                }
            } else {
                readySince := 0
            }
        } catch {
            readySince := 0
        }
        if A_TickCount >= deadline {
            ToolTip()
            throw Error("Child page did not become ready for product " productIndex " of " productCount ".")
        }
        Sleep 300
    }
}

WaitForMatrixSkuPage(productIndex, expectedCount, allowParentReopen := true) {
    global matrixReturnDelayMs, matrixFullyReopenParentAfterReturn, matrixPageWaitTimeoutMs
    ; Cancel/Save has already been clicked. The returned SKU accessibility tree
    ; is known to be stale after one child visit, so never validate or reuse it.
    ; Wait for the parent menu physically, close the whole parent, and enter it
    ; again before any new SKU-tree collection occurs.
    ToolTip "Waiting for the matrix parent menu to return..."
    Sleep matrixReturnDelayMs

    if allowParentReopen && matrixFullyReopenParentAfterReturn {
        ToolTip "Discarding the used SKU menu and fully reopening the matrix parent..."
        FullyReopenActiveMatrixParent(true)
        ToolTip()
        return true
    }

    ; Retained only for callers which explicitly opt out of the full reopen.
    result := WaitForMatrixModalScope(matrixPageWaitTimeoutMs)
    if !result["scope"]
        throw Error("The matrix SKU page did not become stable after returning from child product " productIndex " of " expectedCount ".")
    ToolTip()
    return true
}

FullyReopenActiveMatrixParent(bypassParentSaveAccessibility := false) {
    global activeMatrixParentProductName, matrixParentReopenDelayMs, coords
    global matrixSkuTabSettleDelayMs
    global matrixCatalogueSearchTimeoutMs
    if Trim(activeMatrixParentProductName) = ""
        throw Error("The active matrix parent name is unavailable, so the parent cannot be reopened safely.")

    ; Close/save the entire matrix parent to return to the catalogue list.
    ToolTip "Closing the matrix parent to rebuild GO b2b..."
    LogText("matrix-navigation", "Closing matrix parent before catalogue reopen: " activeMatrixParentProductName)
    Sleep 250
    if bypassParentSaveAccessibility {
        ; This path is used immediately after leaving a child. Do not read the
        ; known-stale SKU accessibility tree merely to locate the parent Save
        ; button; perform the configured physical Save click and discard that
        ; entire parent-menu instance.
        ToolTip()
        ClickPoint("product_save_button", matrixParentReopenDelayMs)
        savePoint := {
            CentreX: coords["product_save_button"][1],
            CentreY: coords["product_save_button"][2],
            ScopeLabel: "configured physical coordinate; stale SKU tree bypassed"
        }
    } else {
        savePoint := PhysicallyClickMatrixParentSave(matrixParentReopenDelayMs)
    }
    LogText(
        "matrix-navigation",
        "Physically clicked the matrix parent Save control."
        . "`nAccessibility scope: " savePoint.ScopeLabel
        . "`nPhysical click centre: " savePoint.CentreX "," savePoint.CentreY
    )

    ; Locate the exact Matrix Product row in the freshly collected live tree,
    ; then retain only its child Edit link's screen rectangle. The button press
    ; itself is a real mouse click at that rectangle's centre.
    ToolTip "Locating the exact matrix parent Edit button in the accessibility tree...`n" activeMatrixParentProductName
    firstLocateProblem := ""
    try editPoint := WaitForCatalogueMatrixParentEditPoint(activeMatrixParentProductName, matrixCatalogueSearchTimeoutMs)
    catch as err {
        firstLocateProblem := err.Message
        ; Retry only if UIA still exposes a live Save control, proving the
        ; product editor remains open. Never click the old Save coordinate on
        ; an already-open catalogue page.
        LogText(
            "matrix-navigation-retry",
            "The catalogue was unavailable after the initial physical Save. Checking whether the editor still exposes Save."
            . "`nParent: " activeMatrixParentProductName
            . "`nFirst lookup problem: " firstLocateProblem
        )
        retrySavePoint := PhysicallyClickMatrixParentSave(matrixParentReopenDelayMs, true)
        if !retrySavePoint
            throw Error(
                "The catalogue accessibility rows were unavailable after physically closing the matrix parent, and the product editor no longer exposed a Save control."
                . "`nParent: '" activeMatrixParentProductName "'"
                . "`nLookup problem: " firstLocateProblem
                . "`nNo second coordinate click was attempted."
            )
        LogText(
            "matrix-navigation-retry",
            "The editor still exposed Save, so it was physically clicked once more."
            . "`nAccessibility scope: " retrySavePoint.ScopeLabel
            . "`nPhysical click centre: " retrySavePoint.CentreX "," retrySavePoint.CentreY
        )
        try editPoint := WaitForCatalogueMatrixParentEditPoint(activeMatrixParentProductName, matrixCatalogueSearchTimeoutMs)
        catch as retryErr {
            throw Error(
                "The exact matrix parent could not be located after two physical Save attempts."
                . "`nParent: '" activeMatrixParentProductName "'"
                . "`nFirst lookup: " firstLocateProblem
                . "`nSecond lookup: " retryErr.Message
            )
        }
    }
    LogText(
        "matrix-navigation",
        "Accessibility located the exact Matrix Product Edit link for physical clicking."
        . "`nParent: " activeMatrixParentProductName
        . "`nRow: " editPoint.RowText
        . "`nAccessibility scope: " editPoint.ScopeLabel
        . "`nRectangle: " editPoint.X "," editPoint.Y " " editPoint.W "x" editPoint.H
        . "`nPhysical click centre: " editPoint.CentreX "," editPoint.CentreY
    )
    ; Clear the status tooltip before moving to the live button rectangle so
    ; the tooltip itself can never cover and intercept the physical click.
    ToolTip()
    MouseMove editPoint.CentreX, editPoint.CentreY, 0
    Sleep 250
    Click editPoint.CentreX, editPoint.CentreY
    Sleep matrixParentReopenDelayMs

    detectedParentName := ""
    try {
        ClickPoint("overview_tab", 1000)
        detectedParentName := CleanText(CopyOptionalFromPoint("product_name"))
    }
    if NormaliseCatalogueProductName(detectedParentName) != NormaliseCatalogueProductName(activeMatrixParentProductName) {
        detectedText := detectedParentName != "" && StrLen(detectedParentName) <= 200
            ? "'" detectedParentName "'"
            : "[Product Name could not be read]"
        throw Error(
            "Safety stop: the accessibility-derived physical Edit click did not open the expected matrix parent."
            . "`nExpected: '" activeMatrixParentProductName "'"
            . "`nDetected: " detectedText
            . "`nClicked accessibility rectangle: " editPoint.X "," editPoint.Y " " editPoint.W "x" editPoint.H
        )
    }
    LogText("matrix-navigation", "Accessibility-derived physical Edit click opened and verified matrix parent: " activeMatrixParentProductName)

    ; Enter the refreshed SKU menu physically, but deliberately do not collect
    ; its accessibility tree here. The immediate caller owns the one fresh
    ; scan for this menu and will use that scan's coordinates for its child.
    ToolTip "Opening a fresh Matrix SKUs menu..."
    ClickPoint("matrix_skus_tab", matrixSkuTabSettleDelayMs)
    LogText("matrix-navigation", "Fresh Matrix SKUs menu opened without pre-reading its accessibility tree: " activeMatrixParentProductName)
    ToolTip()
    return true
}

NormaliseCatalogueProductName(value) {
    value := StrReplace(value, Chr(160), " ")
    value := StrReplace(value, "–", "-")
    value := StrReplace(value, "—", "-")
    value := RegExReplace(Trim(value), "\s+", " ")
    ; GO b2b inconsistently exposes spaces around hyphens between the Product
    ; Name field and its catalogue tile (for example "Fuchsia - Dry" versus
    ; "Fuchsia- Dry"). Treat that presentation-only spacing as equivalent.
    value := RegExReplace(value, "\s*-\s*", "-")
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
        testingPath := SaveTestingAccessibilityTree("manual-f9")
        ToolTip()
        message := "Accessibility tree saved to:`n" path
        if testingPath != ""
            message .= "`n`nTesting-mode copy saved to:`n" testingPath
        MsgBox message
    } catch as err {
        ReportTestingError("manual-f9-accessibility-tree", err, false)
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
