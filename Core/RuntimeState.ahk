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

global matrixState := 0
global matrixFullState := 0
global botzState := 0
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

hardcodedPageUrl := botzDefaultPageUrl

; Fallback value used only until the Images tab is scanned with UIA-v2.
; Every workflow now replaces this automatically from the Image Gallery cards.
imageCountToProcess := 1

; Toggle with Ctrl + Alt + N.
; false = do not paste ChatGPT product name recommendation.
; true = paste the recommendation into the Product Name field when Ctrl + Alt + O runs.
useRecommendedProductName := true

; Ctrl+Alt+A toggles this. Keep it off by default so Numpad4, NumpadEnter and
; Numpad6 retain their existing manual workflow until automation is requested.
fullWorkflowAutomationEnabled := false

; Ctrl+Alt+D toggles department automation. Ctrl+Numpad4 starts from the
; already-open first product; Ctrl+Numpad6 requests a stop after that product.
departmentAutomationEnabled := false

global promotionReferenceBatchActive := false
global promotionReferenceStopAfterCurrent := false

requiredInternalLinksDefault := "N/A"
additionalProductNotesDefault := "N/A"
