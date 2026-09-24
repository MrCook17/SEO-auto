#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "UIA-v2\Lib\UIA.ahk"
#Include "UIA-v2\Lib\UIA_Browser.ahk"
#Include "lib\figuredart-product-creation.ahk"
#Include "Helpers\Text.ahk"
#Include "CMS\MatrixRows.ahk"
#Include "CMS\MatrixDiscovery.ahk"
#Include "CMS\MatrixNavigation.ahk"
#Include "SEO\OutputParsing.ahk"
#Include "SEO\Validation.ahk"
#Include "prompts\Builders.ahk"
#Include "Helpers\SupplierFiles.ahk"
#Include "Core\ModeRegistry.ahk"
#Include "Core\WorkflowState.ahk"
#Include "Core\RunArtifacts.ahk"
#Include "Core\Diagnostics.ahk"
#Include "Core\Settings.ahk"
#Include "UI\Commands.ahk"
#Include "UI\SettingsGui.ahk"
#Include "Browser\Interaction.ahk"
#Include "Browser\ChatGPT.ahk"
#Include "Browser\FileTransfers.ahk"
#Include "CMS\ProductFields.ahk"
#Include "CMS\UiaControls.ahk"
#Include "CMS\Catalogue.ahk"
#Include "CMS\ReferenceCatalogue.ahk"
#Include "CMS\ImageGallery.ahk"
#Include "CMS\ImageCopy.ahk"
#Include "CMS\ImageMetadata.ahk"
#Include "Modes\OrdinaryProduct.ahk"
#Include "Modes\MatrixImage.ahk"
#Include "Modes\MatrixFull.ahk"
#Include "Modes\Botz.ahk"
#Include "Modes\PromotionText.ahk"
#Include "Workflows\ProductDispatch.ahk"
#Include "Workflows\AutomaticWorkflow.ahk"
#Include "Workflows\DepartmentBatch.ahk"
#Include "Workflows\ImagesToChatGPT.ahk"

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
; "display_on_website_app" = enable both display controls and save the product
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
    "display_on_website_button", [350, 708],
    "display_on_app_button", [340, 734],
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

#Include "UI\Hotkeys.ahk"

; ==========================================================
; TEST HELPERS
; ==========================================================









; ==========================================================
; HOTKEY 1A - START FROM INITIAL CMS PAGE
; ==========================================================

; ==========================================================
; HOTKEY 1B - START FROM ALREADY-OPEN PRODUCT PAGE
; ==========================================================

; ==========================================================
; BUILD PROMPT FROM CURRENT PRODUCT PAGE
; ==========================================================

; ==========================================================
; MODE AND PROMPT TEMPLATE HELPERS
; ==========================================================

; ==========================================================
; DYNAMIC IMAGE OUTPUT PROMPT SUPPORT
; ==========================================================

; ==========================================================
; RELIABLE CHATGPT PROMPT PASTE
; ==========================================================

; Backwards-compatible wrapper retained for older/manual callers.
; Old verification functions have intentionally been left unused.
; They can be useful for debugging, but the main paste flow no longer calls them
; because selecting/copying from ChatGPT's input was causing focus problems.


; ==========================================================
; IMAGE COPY / PASTE TO CHATGPT
; ==========================================================

; Backwards-compatible helper: copies image 1 only.
; Opens the Images tab and updates imageCountToProcess after visiting each
; available five-image carousel page. GO b2b lazily realises later pages in the
; accessibility tree: 002104 exposed only ten cards until its third page was
; visited. Already-realised pages remain in the tree, so take the highest total
; observed rather than summing page counts and double-counting retained cards.
; Each genuine card has one exact-name Remove button, which remains reliable
; even when visible image labels skip.
; ==========================================================
; HOTKEY 2 - PASTE COPIED CHATGPT OUTPUT INTO CMS
; ==========================================================

; ==========================================================
; DEPARTMENT-WIDE AUTOMATION
; ==========================================================




; ==========================================================
; COPY LATEST COMPLETED CHATGPT RESPONSE
; ==========================================================

; ==========================================================
; AUTOMATION OUTPUT PARSING
; ==========================================================

; ==========================================================
; CMS INSERTION HELPERS
; ==========================================================

RunDisplayOnWebsiteAppWorkflow() {
    global cmsWinTitle

    ActivateWindow(cmsWinTitle)
    ClickPoint("overview_tab", 500)
    ClickPoint("display_on_website_button", 200)
    ClickPoint("display_on_app_button", 200)
    ClickPoint("product_save_button", 1000)
    Flash("Display on Website and Display on App were clicked, then the product was saved.", 3000)
    return true
}

; ==========================================================
; IMAGE METADATA PASTE HELPERS
; ==========================================================

; ==========================================================
; VALIDATION
; ==========================================================


; ==========================================================
; CORE HELPERS
; ==========================================================

; ==========================================================
; OPTIONAL TESTING-MODE DIAGNOSTICS
; ==========================================================

; ==========================================================
; SHARED SEO PROMPT SETTINGS
; ==========================================================

; ==========================================================
; BOTZ PRODUCT CREATION
; ==========================================================

; ==========================================================
; STRICT IMAGE/MATRIX OUTPUT PARSING
; ==========================================================

; ==========================================================
; MATRIX PROMPT, STATE AND INSERTION
; ==========================================================







; ==========================================================
; UIA-V2 MATRIX DISCOVERY AND SAFE REACQUISITION
; ==========================================================
