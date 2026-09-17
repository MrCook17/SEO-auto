I recommend a **mechanical extraction into responsibility-based files**, retaining the existing functions, globals, callbacks, prompt text, and execution order. Classes, renamed functions, consolidated parsers, and redesigned state management should come later.

No files were modified. The main script’s SHA-256 is unchanged, and the Git working tree remains clean. I did not run the application or tests, because those can create files or operate the CMS.

The checked-out [main script](/C:/Coding/SEO/Cromartie/cromartie-seo-ahk/cromartie-seo-automation.ahk) currently contains:

| Item                                      | Finding                                                                |
| ----------------------------------------- | ---------------------------------------------------------------------- |
| Lines                                     | 7,188                                                                  |
| Named functions                           | 300                                                                    |
| Top-level application variables           | 134, excluding built-ins and library definitions                       |
| Variables reassigned after initialization | 34 across the main script and included Figured’Art library             |
| Active hotkeys                            | 27                                                                     |
| Application GUIs                          | One settings window                                                    |
| Hotstrings / label-based subroutines      | None                                                                   |
| Application timer registrations           | Two one-shot tooltip callbacks                                         |
| Other registered callbacks                | `OnError`, `OnExit`, and GUI events                                    |
| Existing application library              | `lib/figuredart-product-creation.ahk`, containing another 15 functions |

I read the entire main script, the included Figured’Art implementation, its test integration, and the prompt-building/template contracts. The function allocation below accounts for **all 300 main-script functions exactly once**.

The most important architectural findings are:

- Full, Department, Metadata-only, and Image-only modes share the ordinary-product workflow. Creating separate implementations for them during extraction would introduce unnecessary changes.
- Department **review mode** and department-wide **batch automation** are different responsibilities.
- Browser interaction, GO b2b navigation, and workflow coordination deserve separate boundaries.
- Several `Botz*` and `MatrixFull*` functions are actually shared infrastructure.
- Settings, runtime state, and persisted workflow snapshots are currently interleaved.
- The first extraction can improve organization substantially without eliminating existing coupling.

The proposed layout would use the **existing repository root**, rather than introduce another directory above the running script:

```text
CromartieSEOAutomation/
├── cromartie-seo-automation.ahk
├── Core/
│   ├── Configuration.ahk
│   ├── RuntimeState.ahk
│   ├── ModeRegistry.ahk
│   ├── Settings.ahk
│   ├── WorkflowState.ahk
│   ├── RunArtifacts.ahk
│   └── Diagnostics.ahk
├── UI/
│   ├── Hotkeys.ahk
│   ├── Commands.ahk
│   └── SettingsGui.ahk
├── Workflows/
│   ├── ProductDispatch.ahk
│   ├── AutomaticWorkflow.ahk
│   ├── DepartmentBatch.ahk
│   └── ImagesToChatGPT.ahk
├── Modes/
│   ├── OrdinaryProduct.ahk
│   ├── MatrixImage.ahk
│   ├── MatrixFull.ahk
│   ├── Botz.ahk
│   └── PromotionText.ahk
├── SEO/
│   ├── OutputParsing.ahk
│   └── Validation.ahk
├── prompts/
│   ├── Builders.ahk
│   └── [existing .md templates, unchanged]
├── Browser/
│   ├── Interaction.ahk
│   ├── ChatGPT.ahk
│   └── FileTransfers.ahk
├── CMS/
│   ├── ProductFields.ahk
│   ├── UiaControls.ahk
│   ├── Catalogue.ahk
│   ├── ReferenceCatalogue.ahk
│   ├── ImageGallery.ahk
│   ├── ImageCopy.ahk
│   ├── ImageMetadata.ahk
│   ├── MatrixRows.ahk
│   ├── MatrixDiscovery.ahk
│   └── MatrixNavigation.ahk
├── Helpers/
│   ├── Text.ahk
│   └── SupplierFiles.ahk
├── lib/
│   └── figuredart-product-creation.ahk
├── UIA-v2/
├── docs/
├── state/
├── test/
├── tools/
├── logs/
├── backups/
└── debug/
```

Two deliberate choices:

- Keep `prompts/` lowercase and preserve every template path. On Windows, `Prompts/` and `prompts/` are not separate directories.
- Keep the existing Figured’Art library at its present path initially. Its standalone test includes that path and provides its own dependency stubs.

Below, dependencies identify the proposed files containing the called functions. Configuration and runtime declarations remain globally available through the entry point. “State” identifies application state; clipboard and active-window effects are called out separately.

**Core files would separate initialization, settings, persistence, and diagnostics.**

1. **`Core/Configuration.ahk` — installation-specific configuration and operational constants.**

   Move the startup-only assignments from the configuration area: window titles, template paths, directory/state-file paths, supplier roots, timeouts, delays, coordinates, image limits, and fixed feature switches.

   This comprises the **100 application variables without subsequent assignments**, detailed later. Preserve their current values, comments, and dependent path construction.

   Dependencies: built-in `A_ScriptDir`; earlier assignments within this file.

   State: initializes configuration globals; does not load settings or start automation.

   Risk: medium. Preserve path construction order, the 11-image limit, five-slot gallery geometry, coordinates, and every timing value. Some constants have misleading supplier-specific names but serve both suppliers.

2. **`Core/RuntimeState.ahk` — initial values of mutable application state.**

   Move the initial assignments for the **34 mutable globals** listed in the state inventory below. This includes effective settings, cached workflow maps, GUI ownership, run/cancellation flags, diagnostic state, current image count, and active product identity.

   Dependencies: `Configuration.ahk`, particularly `FiguredArtDefaultPromptTemplatePath` and `botzDefaultPageUrl`.

   State: owns initial declarations, while existing functions retain their current read/write behavior.

   Risk: high if converted into a function or class. For the first refactor, keep these assignments at global scope. Initialize once, before loading saved settings.

3. **`Core/ModeRegistry.ahk` — mode definitions, prompt registration, and selection validation.**

   Move these 30 functions:

   `ValidateSeoAutomationMode`, `GetSeoAutomationModeOptions`, `IsValidSeoAutomationMode`, `GetSeoAutomationModeOptionIndex`, `GetSeoAutomationMode`, `GetSeoPromptId`, `GetSeoPromptOptionsForMode`, `GetDefaultSeoPromptId`, `GetSeoPromptOption`, `IsValidSeoPromptForMode`, `GetSeoPromptLabelsForMode`, `GetSeoPromptOptionIndex`, `GetSeoPromptIdFromOptionIndex`, `GetSeoPromptLabel`, `GetPromptTemplatePath`, `IsFullMode`, `IsDepartmentMode`, `IsFullContentMode`, `IsMetadataOnlyMode`, `IsImageOnlyMode`, `IsMatrixImageMode`, `IsMatrixFullMode`, `IsBotzMode`, `IsFiguredArtMode`, `IsPromotionTextMode`, `IsPromotionTextReferenceMode`, `IsAnyPromotionTextMode`, `IsSupplierProductCreationMode`, `IsAnyMatrixMode`, `GetDepartmentProductTypeForSeoMode`.

   Dependencies: configuration/runtime declarations only.

   State: reads `SeoAutomationMode`, `SeoPromptId`, and registered template paths.

   Risk: low. Preserve option ordering, prompt IDs, mode ownership, normalization, and fallback indexes. Keeping mode and prompt registration together avoids an unnecessary circular dependency between separate registries.

4. **`Core/Settings.ahk` — shared persistent user settings.**

   Move:

   `InitialiseSeoPromptSettings`, `ApplySharedSeoPromptSettings`, `CreateDefaultBotzPromptSettings`, `ValidateBotzPromptSettings`, `SaveBotzPromptSettings`, `LoadBotzPromptSettings`.

   Dependencies: `ModeRegistry`, `WorkflowState` encoding helpers, `RunArtifacts`, `Diagnostics`, `Helpers/Text`, `prompts/Builders`.

   State: reads/writes `botzPromptSettings` and the effective settings globals; reads the settings path and defaults.

   Risk: high. Preserve backward compatibility, load-failure fallback, validation, temporary-file replacement, and the diagnostic effects of enabling/disabling testing. Retain the existing BOTZ names and file header even though these settings now serve all modes.

5. **`Core/WorkflowState.ahk` — persisted BOTZ/matrix snapshots and existing serialization helpers.**

   Move:

   `SaveBotzState`, `LoadBotzState`, `SaveMatrixState`, `LoadMatrixState`, `EncodeStateValue`, `DecodeStateValue`, `GetMatrixTotalImageCount`, `ValidateMatrixStateImageTargets`.

   Dependencies: `ModeRegistry`, `CMS/MatrixRows`.

   State: `botzState`, `matrixState`, `matrixFullState`, their paths, and image-limit configuration.

   Risk: medium/high. Preserve cache-before-disk behavior, version headers, record ordering, escaping order, validation, and the different write strategies. Do not replace the format with JSON or INI during extraction.

   `GetMatrixTotalImageCount` and `ValidateMatrixStateImageTargets` belong here initially because they interpret the persisted matrix state shape.

6. **`Core/RunArtifacts.ahk` — product identity for artifact naming, directories, logs, and backups.**

   Move:

   `ClearActiveCmsProductCode`, `SetActiveCmsProductCode`, `HasActiveCmsProductCode`, `GetActiveCmsProductCodeFilePart`, `BuildRunArtifactFileName`, `EnsureFolders`, `LogText`, `BackupText`.

   Dependencies: `ModeRegistry`, `Diagnostics`, `Helpers/Text`.

   State: reads/writes `activeCmsProductCode`; reads directory globals.

   Risk: medium. Logs require an established product identity. Matrix parents and department review use names in this variable despite its `ProductCode` name. Preserve sanitization, timestamp resolution, append behavior, and when directories are created.

7. **`Core/Diagnostics.ahk` — optional testing traces and diagnostic artifacts.**

   Move:

   `EnsureTestingSessionLog`, `TestingLog`, `BuildTestingRuntimeSummary`, `GetTestingActiveWindowSummary`, `FormatTestingError`, `SanitiseTestingFilePart`, `SaveTestingElementDump`, `SaveTestingAccessibilityTree`, `ReportTestingError`, `LogUnhandledErrorForTesting`, `LogTestingSessionExit`.

   Dependencies: `RunArtifacts`, `Browser/ChatGPT`, UIA libraries.

   State: testing flag, session path/ID, artifact sequence, `LastDocument`, and configuration/runtime values reported in the summary.

   Risk: medium. Preserve the “diagnostics must not interrupt automation” exception handling. Keep `OnError`/`OnExit` registration in bootstrap. Extracting code necessarily changes reported source filenames and line numbers.

**UI files would contain bindings, application commands, and the settings window.**

8. **`UI/Hotkeys.ahk` — the existing 27 static hotkey declarations.**

   Move the active declarations at lines 316–345, together with the commented historical bindings.

   Dependencies: `UI/Commands`, `UI/SettingsGui`, `Workflows/ProductDispatch`, `Workflows/DepartmentBatch`, `Workflows/ImagesToChatGPT`.

   State: none directly; handlers access the existing globals.

   Risk: medium. Preserve literal key syntax and unrestricted scope. Do not introduce `#HotIf`, dynamic registration, new wrappers, or different modifier behavior.

9. **`UI/Commands.ahk` — hotkey actions, status messages, and manual diagnostics.**

   Move:

   `TestScript`, `CopyActiveWindowTitle`, `ToggleRecommendedProductName`, `ToggleFullWorkflowAutomation`, `ToggleDepartmentAutomation`, `RequestDepartmentStopAfterCurrent`, `SetImageCountToProcess`, `CaptureMouseCoords`, `Flash`, `ShowMatrixLookupStatus`, `BuildLocationsMessage`, `ShowLastLocations`, `DumpAccessibilityTree`.

   Dependencies: `Browser/Interaction`, `Core/Diagnostics`, `Core/ModeRegistry`, `Core/WorkflowState`, UIA libraries.

   State: feature toggles, automatic/department/reference flags, image count, testing state, `LastEditButtons`, `LastDocument`.

   Risk: medium/high. Toggle handlers affect suspended automation. Preserve their assignments and tooltip timers. `DumpAccessibilityTree` must continue activating the CMS and reacquiring the document.

10. **`UI/SettingsGui.ahk` — settings window construction and callbacks.**

    Move:

    `OpenSeoPromptSettingsGui`, `SaveSeoPromptSettingsFromGui`, `UpdateSeoPromptSettingsControls`, `RememberSeoPromptSelection`, `CloseSeoPromptSettingsGui`.

    Dependencies: `Core/Settings`, `Core/ModeRegistry`, `Core/Diagnostics`, `UI/Commands`.

    State: `botzPromptSettings`, `botzPromptSettingsGui`, and active-run flags.

    Risk: medium. Preserve bound callback arguments, variadic parameters, local control-map lifetime, dropdown indexes, and existing-window reuse.

**Workflow files would coordinate multiple responsibilities without absorbing their implementations.**

11. **`Workflows/ProductDispatch.ahk` — entry actions and mode dispatch.**

    Move:

    `OpenProductBuildPromptAndPasteToChatGPT`, `BuildPromptFromOpenProductPageAndPasteToChatGPT`, `RunOpenProductWorkflow`, `BuildSupplierProductCreationPrompt`, `RunManualChatGptOutputPaste`.

    Dependencies: all relevant mode implementations, Figured’Art library, `AutomaticWorkflow`, browser interaction, registry, artifacts, diagnostics, UI commands.

    State: configured URL/window, automatic-active/cancel/manual-completion/insertion flags.

    Risk: high. Preserve dispatch order, exception boundaries, return values, and the distinction between opening a selected product and processing an already-open product.

12. **`Workflows/AutomaticWorkflow.ahk` — submission, polling, interruption, and automatic insertion.**

    Move:

    `IsAutomaticWorkflowExecutionEnabled`, `RunAutomaticWorkflowIfEnabled`, `AutomaticWorkflowMayContinue`, `AutomaticWorkflowStatusHeading`, `AutomaticWorkflowControlHint`, `SubmitChatGptDraftForAutomaticWorkflow`, `WaitForAutomaticChatGptOutput`, `FormatAutomationWaitTime`.

    Dependencies: `Browser/ChatGPT`, `Browser/Interaction`, `Core/ModeRegistry`, artifacts, diagnostics, `Modes/OrdinaryProduct`.

    State: all automatic-workflow flags, department-active state, automatic toggle, response/submit timing configuration.

    Risk: high. Preserve `try/finally` cleanup, cancellation checks, forced department completion, the manual-completion handoff, and the existing coordinate-only polling route.

13. **`Workflows/DepartmentBatch.ahk` — processing successive catalogue products.**

    Move:

    `StartDepartmentAutomation`, `SetActiveDepartmentProductIdentity`, `PrepareCompletedProductForCatalogueLookup`.

    Dependencies: `ProductDispatch`, `CMS/Catalogue`, `CMS/ProductFields`, browser interaction, registry, artifacts, diagnostics, text helpers.

    State: department enable/active/stop flags, automatic-active flag, last saved identity, save switch, catalogue delay.

    Risk: high. Preserve product-type filtering, post-rename identity handling, stop-after-save behavior, and the extra matrix-parent save needed to return to the catalogue.

14. **`Workflows/ImagesToChatGPT.ahk` — transferring CMS images into a ChatGPT draft.**

    Move:

    `TryCopyCmsImagesToChatGPT`, `TryCopyCmsImageToChatGPT`, `TryCopyCmsSingleImageToChatGPT`.

    Dependencies: `Browser/ChatGPT`, browser interaction, `CMS/ImageCopy`, `CMS/ImageGallery`, diagnostics, UI commands.

    State: current image count, gallery page size, image-paste timing.

    Risk: high. Preserve attachment-baseline measurement, sequential gallery traversal, stop-on-first-failure behavior, return values, and the compatibility wrapper.

**Mode files would retain complete existing functions, including mixed responsibilities that cannot be separated by moving code alone.**

15. **`Modes/OrdinaryProduct.ahk` — shared Full, Department, Metadata-only, and Image-only processing.**

    Move:

    `BuildPromptFromCurrentProductPage`, `PasteCopiedChatGPTOutputToCms`.

    Dependencies: registry, builders, parsers, validation, product fields, gallery, image metadata, ChatGPT, image-transfer workflow, automatic workflow, artifacts, diagnostics, UI commands. The insertion function also dispatches to BOTZ, Figured’Art, and both matrix modes.

    State: mode, current image count, notes/inlinks, name-recommendation toggle, last saved identity, and CMS configuration.

    Risk: high. The insertion function remains partly a dispatcher in this first pass. Splitting that body is a later decomposition.

    **Do not create separate Metadata/Image workflow copies.** Their behavior currently depends on branches inside these shared functions.

16. **`Modes/MatrixImage.ahk` — matrix parent/child image workflow.**

    Move:

    `BuildMatrixImagePrompt`, `PasteMatrixImageOutputToCms`.

    Dependencies: matrix discovery/navigation/rows, gallery and metadata editing, product fields, workflow state, builders, parsers, ChatGPT, image transfers, automatic workflow, artifacts, UI commands.

    State: `matrixState`, active parent name, image targets, department-active state.

    Risk: high. Preserve parent-first attachment order, independent child image counts, saved child order, and complete parent reopening between child visits.

17. **`Modes/MatrixFull.ahk` — parent metadata and child content/image workflow.**

    Move:

    `BuildMatrixFullPrompt`, `PasteMatrixFullOutputToCms`, `BuildMatrixFullParsedLog`.

    Dependencies: the same matrix infrastructure as Matrix Image, plus generated-field validation helpers.

    State: `matrixFullState`, active parent name, image targets, recommendation toggle, department-active state.

    Risk: high. Preserve parent rename/read-back behavior, child metadata clearing, child HTML insertion, and saving/reopening after parent changes.

18. **`Modes/Botz.ahk` — BOTZ-specific source matching and product creation.**

    Move:

    `BuildBotzPrompt`, `TransformBotzStockCode`, `FindUniqueBotzProductFolder`, `BuildBotzSourceLog`, `PasteBotzOutputToCms`, `ValidateBotzSourcesUnchanged`, `VerifyBotzCmsProduct`, `UploadAndPopulateBotzImages`, `UploadAndPopulateSingleBotzImage`.

    Dependencies: supplier-file helpers, builders, settings, workflow state, parsing/validation, ChatGPT/file transfers, product fields, artifacts, UI commands.

    State: BOTZ root/state, shared prompt settings, image limit, supplier upload timing, recommendation toggle, last saved identity.

    Risk: high. Preserve exact stock-code transformation, source-manifest checks, upload checkpoints, and refusal to repeat an ambiguous pending upload.

19. **`Modes/PromotionText.ahk` — both promotion-text workflows.**

    Move:

    `RunPromotionTextWorkflow`, `RunPromotionTextReferenceWorkflow`, `ScrollPromotionDescriptionToBottom`.

    Dependencies: `CMS/ReferenceCatalogue`, `CMS/ProductFields`, browser interaction, artifacts, diagnostics, text helpers, UI commands.

    State: promotional text, save switch, reference-batch flags, competing-run flags, last saved identity, return delay.

    Risk: high. Empty text deliberately clears fields. Preserve both Description and Custom updates, physical scrolling, reference inventory collection before processing, and saving between reference searches.

**SEO and prompt files would own text contracts without changing those contracts.**

20. **`SEO/OutputParsing.ahk` — extraction and parsing of generated output.**

    Move:

    `ParseAutomationOutput`, `ExtractBetween`, `ExtractLabel`, `ExtractValidatedAutomationBlock`, `CountTextOccurrences`, `ParseBotzAutomationOutput`, `ParseOrderedAutomationFields`, `BuildBotzParsedOutputLog`, `ParseImageOnlyOutput`, `ParseExactLineFields`, `ParseMatrixImageOutput`, `ParseMatrixFullOutput`.

    Dependencies: `SEO/Validation`, `Helpers/Text`, `Core/WorkflowState`.

    State: no direct application-global access; receives text, counts, and state maps.

    Risk: low for relocation, high for consolidation. These parsers intentionally or historically accept different input forms. Preserve all implementations separately.

    `BuildBotzParsedOutputLog` is retained here because it formats the parsed supplier-output shape and is also called by Figured’Art.

21. **`SEO/Validation.ahk` — validation of returned field values.**

    Move:

    `ValidateGeneratedFields`, `IsUsableProductNameRecommendation`, `ValidateCmsImageName`, `ValidateBotzHtml`, `ValidateImageOutputValue`, `ValidateMatrixFullOneLine`, `ValidateMatrixFullHtml`.

    Dependencies: `Helpers/Text`.

    State: none directly.

    Risk: low for relocation. Preserve warning-string versus exception behavior, optional-value handling, normalization, and differing validation strength.

22. **`prompts/Builders.ahk` — template reading, substitutions, and generated output-field instructions.**

    Move:

    `GetDefaultImageNotes`, `ReadPromptTemplateFile`, `BuildPromptFromTemplate`, `EnsurePromptSupportsImageCount`, `BuildAutomationImageOutputBlock`, `BuildBotzRecommendedInlinks`, `BuildBotzPromptFromSource`, `InjectImageOnlyOutputFields`, `BuildMatrixPromptFromState`, `BuildMatrixFullPromptFromState`, `BuildMatrixImageCountSummary`.

    Dependencies: `Core/Settings`, `Core/WorkflowState`, `Helpers/Text`.

    State: current image count, maximum image count, shared inlinks and additional notes.

    Risk: medium. Preserve exact replacement order, whitespace, markers, generated labels, and regex behavior. Leave the `.md` templates unchanged.

**Browser files would contain interaction mechanics; CMS files would contain GO b2b-specific interpretation and navigation.**

23. **`Browser/Interaction.ahk` — window, mouse, keyboard, and clipboard primitives.**

    Move:

    `PasteLargeTextToFocusedInput`, `SetClipboardText`, `ClickCoordinates`, `ActivateWindow`, `ClickPoint`, `CopySelectedText`, `PasteText`, `CopyBrowserUrl`, `SendNativeMouseWheel`.

    Dependencies: `Core/Diagnostics`.

    State: `coords`; built-in clipboard, active window, mouse position, and thread coordinate settings.

    Risk: high despite generic names. Preserve clipboard restoration, blank-field semantics, focus delays, minimized-window handling, and native wheel input.

24. **`Browser/ChatGPT.ahk` — composer and response interaction.**

    Move:

    `GetChatGptWinTitle`, `PastePromptToChatGPT`, `FocusChatGptInputForPaste`, `WakeChatGptInput`, `FocusChatGptInputForImagePaste`, `GetChatGptDraftAttachmentCount`, `WaitForChatGptDraftAttachmentCount`, `VerifyChatGptPromptPasted`, `PromptPasteLooksValid`, `CopyLatestChatGptResponseToClipboard`, `TryCopyLatestChatGptResponseWithUia`, `FindLatestChatGptResponseCopyButton`, `TryCopyLatestChatGptResponseByCoordinates`, `ClipboardHasCompleteAutomationOutput`.

    Dependencies: browser interaction, registry, diagnostics, parsing, text helpers, UI commands, UIA libraries.

    State: ChatGPT titles, paste/attachment/response-copy configuration, clipboard.

    Risk: high. Preserve exact Copy-button matching, UIA-first manual copy, coordinate fallback, and the intentionally unused composer verification path.

25. **`Browser/FileTransfers.ahk` — Windows file-picker interaction and supplier attachments.**

    Move:

    `LogSupplierChatGptImagePlan`, `AttachBotzImagesToChatGpt`, `OpenChatGptFilePicker`, `ChooseSingleFileInPicker`, `ChooseAllBotzImagesInPicker`, `NavigateSupplierImagePickerToFolder`, `FocusWindowsFilePickerList`, `ChooseFileSelectionInPicker`, `WaitForBotzChatAttachmentBatch`, `SubmitBotzChatGptDraft`.

    Dependencies: ChatGPT/browser interaction, supplier-file helpers, artifacts, diagnostics.

    State: supplier picker/attachment timing; clipboard and active picker.

    Risk: high. Preserve control-focus fallback order, Ctrl+A selection, clipboard restoration, no-retry-after-selection policy, and supplier auto-submit timing. CMS image upload also calls its single-file picker helper.

26. **`CMS/ProductFields.ahk` — reading, inserting, and verifying CMS fields.**

    Move:

    `ReadOpenCmsProductIdentity`, `InsertProductNameRecommendation`, `InsertMetaFields`, `CopyFromPoint`, `CopyOptionalFromPoint`, `PasteToPoint`, `NormalisePastedFieldValue`, `SetActiveMatrixParentName`, `InsertMatrixParentMetaFields`.

    Dependencies: browser interaction, catalogue normalization, registry, artifacts, diagnostics, text helpers.

    State: CMS window configuration; active identity through artifact helpers; mode through registry.

    Risk: high. Preserve the five-attempt paste/read-back loop, optional blank reads, mode-dependent HTML insertion, and name-based matrix identity.

27. **`CMS/UiaControls.ahk` — shared live-control lookup.**

    Move:

    `FindVisibleExactNamedControlPoint`, `WaitForVisibleExactNamedControlPoint`, `GetUiaControlTypeText`.

    Dependencies: browser interaction, UIA libraries.

    State: CMS window and `matrixStableDurationMs`.

    Risk: medium. Preserve exact-name matching, nearest-reference-point selection, rectangle stability, and document/full-window fallback. The matrix-named stability setting is also used outside matrix workflows.

28. **`CMS/Catalogue.ahk` — ordinary catalogue tiles and department traversal.**

    Move:

    `FindNextDepartmentCatalogueProduct`, `CollectDepartmentCatalogueProducts`, `NormaliseCatalogueTileText`, `GetCatalogueTileProductTypePrefix`, `IsCatalogueReferenceTile`, `HasCatalogueReferenceMarker`, `IsCatalogueDepartmentTile`, `ParseDepartmentCatalogueTileIdentity`, `FindCatalogueTileEditControl`, `FindCompletedDepartmentProductIndex`, `DepartmentCatalogueIdentityMatches`, `OpenAndVerifyNextDepartmentProduct`, `NormaliseCatalogueProductName`.

    Dependencies: browser interaction, product fields, diagnostics, text helpers, UIA libraries.

    State: CMS title and department navigation timing.

    Risk: high. Preserve exclusions, list order, ambiguity rejection, matrix-name versus ordinary-code matching, Unicode normalization, and physical Edit clicks.

29. **`CMS/ReferenceCatalogue.ahk` — reference inventory, search, and verified opening.**

    Move:

    `CollectAllCatalogueReferenceProducts`, `WaitForCatalogueReferenceProductScan`, `CollectCatalogueReferenceProductsFromDocument`, `ParseCatalogueReferenceProductIdentity`, `BuildCatalogueRowSignature`, `SearchAndOpenCatalogueReferenceProduct`, `WaitForCatalogueReferenceSearchResult`, `FindCatalogueReferenceSearchResultPoint`, `CatalogueAccessibilityTextContainsExactCode`.

    Dependencies: browser interaction, catalogue helpers, product fields, UIA-control helpers, text helpers, UIA libraries.

    State: catalogue coordinates and promotion-reference scan/search settings.

    Risk: high. Preserve scrolling/deduplication, exact stock-code matching, exclusion of the query edit control, search-pane geometry, and physical double-click opening.

30. **`CMS/ImageGallery.ahk` — gallery discovery, pagination, and image counting.**

    Move:

    `PrepareCmsImageGalleryForSequentialCopy`, `OpenDepartmentImageGalleryByCoordinates`, `GetImageTarget`, `GetImageGalleryPageForIndex`, `OpenFirstImageGalleryPage`, `WaitForImageGalleryAvailable`, `OpenImageGalleryPageForIndex`, `TryAdvanceImageGalleryPage`, `TryReturnToPreviousImageGalleryPage`, `TryMoveImageGalleryPage`, `GetImageGalleryButtonState`, `GetImageGalleryPageSnapshot`, `WaitForImageGalleryPageChange`, `ValidateImageTargetConfig`, `DetectAndSetImageCountFromImagesTab`, `DiscoverStableImageGalleryCountAcrossPages`, `WaitForStableImageGalleryCount`, `FindImageGalleryScope`, `CountImageGalleryCards`, `GetImageGalleryCardControlCounts`, `CountExactImageGalleryElements`, `AreImageGalleryCardControlCountsConsistent`, `BuildImageGalleryCountSignature`.

    Dependencies: browser interaction, UIA-control helpers, registry, artifacts, diagnostics, UIA libraries.

    State: image count, targets, page size/limits, gallery delays/timeouts, `LastDocument`.

    Risk: high. This is a coherent subsystem, despite remaining fairly large. Preserve lazy-page realization, highest-total counting, four-control consistency checks, page rewinding, and department coordinate bypass.

31. **`CMS/ImageCopy.ahk` — obtaining CMS image data on the clipboard.**

    Move:

    `CopyCmsImageToClipboard`, `CopyHighQualityPreviewByContextMenuKey`, `SelectCmsImageForPreview`, `CopyImageByContextMenuKey`.

    Dependencies: browser interaction, image gallery, diagnostics.

    State: CMS title, preview/copy configuration, gallery page size, clipboard.

    Risk: high. Successful copy deliberately leaves image data on the clipboard. Preserve context-menu copying and the optional thumbnail fallback.

32. **`CMS/ImageMetadata.ahk` — editing existing image records.**

    Move:

    `InsertImageSeoFields`, `BeginSequentialImageMetadataInsertion`, `PasteImageMetadataToCms`, `OpenCmsImageDetailsForMetadata`, `WaitForVisibleImageGalleryDetailsButton`, `WaitForCmsImageDetailsFormReady`, `IsEnabledUiaEditAtConfiguredPoint`, `WaitForCmsImageGalleryAfterDetailsSave`.

    Dependencies: browser interaction, gallery, product fields, UIA controls, registry, diagnostics, UIA libraries.

    State: coordinates, gallery page size, image-details and return timing.

    Risk: high. Preserve Details-button ordering, form readiness, retries, per-image Save, gallery-return verification, and department’s distinct single-image path.

33. **`CMS/MatrixRows.ahk` — interpreting matrix SKU row text.**

    Move:

    `DeriveVariantContext`, `IsPlausibleConnectedSkuSize`, `CountMatrixSkuIdentities`, `GetMatrixSkuRowKey`, `ExtractMatrixProductNameFromRow`, `ExtractConnectedMatrixSkuSize`, `ExtractMatrixVariantFromRow`, `NormaliseMatrixRowText`.

    Dependencies: `Helpers/Text`.

    State: none directly.

    Risk: low for extraction. Preserve regexes, fallback text, name/size distinctions, and the apparently unused `DeriveVariantContext`.

34. **`CMS/MatrixDiscovery.ahk` — discovering and reacquiring matrix child controls.**

    Move:

    `ReacquireAndValidateMatrixOrder`, `ReacquireMatrixSkuControls`, `FindMatrixModalScope`, `ScopeContainsAnyEditElement`, `RejectPotentiallyIncompleteMatrix`, `WaitForStableEditLocations`, `GetUniqueVisibleEditLocations`, `FindConnectedMatrixSkuSizeByGeometry`, `GetEditRowContext`, `ExpandMatrixSkuRowContext`, `CollectAllMatrixSkuButtons`, `MatrixScopeHasOffscreenSkuEdits`, `ScrollMatrixSkuListToTop`, `ScrollMatrixSkuListDownOneStep`, `FindCurrentMatrixSkuButton`, `WaitForMatrixModalScope`, `HasVisibleMatrixSkuRows`, `LocationsRepresentSameControl`, `SortLocationsTopToBottom`, `BuildLocationSignature`, `ClickMatrixEditButton`, `IsBetterEditLocation`, `IsMatrixModalPresent`.

    Dependencies: browser interaction, matrix-row helpers, UIA controls, text helpers, UI commands, UIA libraries.

    State: `LastDocument`, `LastEditButtons`, matrix stability/search/scroll configuration.

    Risk: very high. Preserve small-matrix versus scrolling-matrix paths, geometry deduplication, row identity, fresh-control acquisition, and the absence of unnecessary extra tree scans.

35. **`CMS/MatrixNavigation.ahk` — transitioning between parent, children, and catalogue.**

    Move:

    `PhysicallyClickMatrixParentSave`, `FindExactCatalogueMatrixParent`, `WaitForCatalogueMatrixParentEditPoint`, `WaitForChildProductPage`, `WaitForMatrixSkuPage`, `FullyReopenActiveMatrixParent`.

    Dependencies: browser interaction, catalogue, matrix discovery, product fields, UIA controls, artifacts, text helpers, UI commands, UIA libraries.

    State: active parent name, coordinates, matrix navigation/reopen/stability timing.

    Risk: very high. Preserve the intentional stale-tree bypass after leaving a child, physical clicks, guarded second Save attempt, exact parent verification, and caller-owned fresh SKU scan.

**Helpers would stay small and explicitly scoped.**

36. **`Helpers/Text.ahk` — reusable text operations.**

    Move:

    `StripCodeFence`, `CleanText`, `EmptyToNA`, `IsBotzHttpUrl`, `NormaliseHarmlessWhitespace`.

    Dependencies/state: none.

    Risk: low. Preserve differences between trimming, whitespace folding, case folding, and fence removal. Retain the existing `IsBotzHttpUrl` name.

37. **`Helpers/SupplierFiles.ahk` — shared supplier image-file handling.**

    Move:

    `EnumerateBotzImageFiles`, `TakeFirstBotzImageFiles`, `BuildBotzImageManifest`, `NaturalSortBotzPaths`, `CompareBotzPathsNaturally`, `ValidateBotzCtrlAImageFolder`, `BotzPathArraysMatch`.

    Dependencies: Windows filesystem and `Shlwapi.dll`.

    State: none directly; arrays/maps are passed by reference.

    Risk: low/medium. Preserve supported extensions, natural ordering, case comparisons, manifest contents, array mutation, and `maximumCount = 0` meaning unlimited.

The retained files also need explicit treatment:

| File                                  | Purpose, dependencies, state, and extraction decision                                                                                                                                                                                                                                                             |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cromartie-seo-automation.ahk`        | Keep directives, ordered includes, thread defaults, settings initialization, and error/exit registration. Depends on every application module. Highest startup-order sensitivity.                                                                                                                                 |
| `lib/figuredart-product-creation.ahk` | Keep its 15 functions and current include path unchanged initially. Depends on shared settings, builders, state encoding, supplier files, parsing/validation, browser/file transfers, product fields, logging, and UI commands. Uses Figured’Art paths/state plus shared supplier timing and last-saved identity. |
| `UIA-v2/Lib/UIA.ahk`                  | Retain unchanged as the UI Automation dependency. Do not extract or reorganize vendor internals.                                                                                                                                                                                                                  |
| `UIA-v2/Lib/UIA_Browser.ahk`          | Retain unchanged after `UIA.ahk`; supplies browser/document access used throughout the automation.                                                                                                                                                                                                                |
| Existing `.md` templates              | Keep contents and paths unchanged. Their instructions and output schemas form part of application behavior.                                                                                                                                                                                                       |
| Existing state/data/test/tool files   | Keep paths and formats unchanged. They are not code to move out of the main script.                                                                                                                                                                                                                               |

The Figured’Art functions retained together are:

`BuildFiguredArtPrompt`, `NormaliseFiguredArtProductCode`, `FindUniqueFiguredArtProductFolder`, `ValidateFiguredArtProductMarkdown`, `BuildFiguredArtPromptFromSource`, `BuildFiguredArtSourceLog`, `SaveFiguredArtState`, `LoadFiguredArtState`, `ValidateFiguredArtSourcesUnchanged`, `PasteFiguredArtOutputToCms`, `ParseFiguredArtAutomationOutput`, `ValidateFiguredArtHtml`, `VerifyFiguredArtCmsProduct`, `UploadAndPopulateFiguredArtImages`, `UploadAndPopulateSingleFiguredArtImage`.

Moving that library to `Modes/FiguredArt.ahk`, or splitting it further, can be a separate later change.

The **global-state inventory** is particularly important because file separation does not create state isolation.

All variables below receive startup values. The writers shown are subsequent writers.

| Mutable globals                                                 | Subsequent writers                                                                                                        | Readers / consumers                                                                                          |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `SeoAutomationMode`, `SeoPromptId`                              | `ApplySharedSeoPromptSettings`                                                                                            | Registry, GUI, workflow dispatch, mode decisions, status/diagnostics                                         |
| `FiguredArtPromptTemplatePath`                                  | `ApplySharedSeoPromptSettings`                                                                                            | `BuildFiguredArtPrompt`                                                                                      |
| `hardcodedPageUrl`                                              | `ApplySharedSeoPromptSettings`                                                                                            | Both product-start entry paths                                                                               |
| `requiredInternalLinksDefault`, `additionalProductNotesDefault` | `ApplySharedSeoPromptSettings`                                                                                            | Ordinary and matrix builders; matrix-image uses notes but not the inlink setting                             |
| `promotionText`                                                 | `ApplySharedSeoPromptSettings`                                                                                            | `RunPromotionTextWorkflow`                                                                                   |
| `botzPromptSettings`                                            | `InitialiseSeoPromptSettings`, `OpenSeoPromptSettingsGui`, `SaveSeoPromptSettingsFromGui`                                 | Settings GUI and both supplier prompt workflows                                                              |
| `botzPromptSettingsGui`                                         | `OpenSeoPromptSettingsGui`, `CloseSeoPromptSettingsGui`                                                                   | GUI reuse/destruction                                                                                        |
| `matrixState`                                                   | `BuildMatrixImagePrompt`, `LoadMatrixState`                                                                               | Matrix-image prompt/state loading; insertion receives the returned map                                       |
| `matrixFullState`                                               | `BuildMatrixFullPrompt`, `LoadMatrixState`                                                                                | Matrix-full prompt/state loading; insertion receives the returned map                                        |
| `botzState`                                                     | `BuildBotzPrompt`, `LoadBotzState`                                                                                        | BOTZ workflow; upload functions mutate the returned map                                                      |
| `figuredArtState`                                               | `BuildFiguredArtPrompt`, `LoadFiguredArtState`                                                                            | Figured’Art workflow; upload functions mutate the returned map                                               |
| `activeMatrixParentProductName`                                 | Both matrix builders and both matrix insertion functions                                                                  | `FullyReopenActiveMatrixParent`; matrix-full insertion also updates it after renaming                        |
| `activeCmsProductCode`                                          | `ClearActiveCmsProductCode`, `SetActiveCmsProductCode`                                                                    | Identity checks and artifact filename construction                                                           |
| `lastSavedNonMatrixProductIdentity`                             | Ordinary insertion, both supplier insertion functions, promotion workflow; reset by department batch                      | `PrepareCompletedProductForCatalogueLookup`                                                                  |
| `imageCountToProcess`                                           | `SetImageCountToProcess`, department branch of `BuildPromptFromCurrentProductPage`, `DetectAndSetImageCountFromImagesTab` | Ordinary prompt/parsing, image transfer, configuration validation, status/diagnostics                        |
| `useRecommendedProductName`                                     | `ToggleRecommendedProductName`                                                                                            | Ordinary, supplier, and matrix-full insertion; status                                                        |
| `fullWorkflowAutomationEnabled`                                 | `ToggleFullWorkflowAutomation`                                                                                            | Automatic workflow gates, status/diagnostics                                                                 |
| `departmentAutomationEnabled`                                   | `ToggleDepartmentAutomation`                                                                                              | Department batch and status/diagnostics                                                                      |
| `automaticWorkflowActive`                                       | `RunAutomaticWorkflowIfEnabled`                                                                                           | Manual fallback, competing-run checks, settings-save guard, status                                           |
| `automaticWorkflowCancelRequested`                              | Full-automation toggle, manual output handler, automatic workflow initialization/cleanup                                  | `AutomaticWorkflowMayContinue`                                                                               |
| `automaticWorkflowManualCompletion`                             | Manual output handler and automatic workflow initialization/cleanup                                                       | Automatic workflow’s department handoff                                                                      |
| `automaticWorkflowCmsInsertionActive`                           | `RunAutomaticWorkflowIfEnabled`                                                                                           | Manual handler’s duplicate-insertion guard                                                                   |
| `departmentAutomationActive`                                    | `StartDepartmentAutomation`                                                                                               | Automatic behavior, toggles, stop handler, settings guard, reference-batch guard, matrix completion messages |
| `departmentStopAfterCurrent`                                    | Department toggle, stop handler, department batch initialization/cleanup                                                  | Department loop and status                                                                                   |
| `promotionReferenceBatchActive`                                 | Reference workflow initialization/cleanup                                                                                 | Stop handler, duplicate-run/settings guards                                                                  |
| `promotionReferenceStopAfterCurrent`                            | Stop handler and reference workflow initialization/cleanup                                                                | Reference loop                                                                                               |
| `LastEditButtons`                                               | `ReacquireMatrixSkuControls`                                                                                              | F8 diagnostics                                                                                               |
| `LastDocument`                                                  | Gallery waits, testing-tree capture, matrix reacquisition, F9 dump                                                        | Diagnostic capture; F9 explicitly clears and reacquires it                                                   |
| `testingModeEnabled`                                            | `ApplySharedSeoPromptSettings`                                                                                            | Diagnostic functions and status                                                                              |
| `testingSessionLogPath`, `testingSessionId`                     | `EnsureTestingSessionLog`                                                                                                 | Testing log/artifact writers; status reads the path                                                          |
| `testingArtifactSequence`                                       | `SaveTestingElementDump`, `SaveTestingAccessibilityTree`                                                                  | Diagnostic artifact numbering                                                                                |

There is also **indirect mutation**: supplier upload functions receive the cached state map and change `uploadedCount` and `pendingImageIndex`. Replacing those maps with copies would change recovery behavior.

The remaining **100 globals are initialized once and then read**. Their consumers group as follows; diagnostics additionally reports several of the timing values.

| Configuration globals                                                                                                                                                                                                                           | Main readers                                                                                                                            |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `cmsWinTitle`                                                                                                                                                                                                                                   | CMS navigation/field operations, mode entry functions, department dispatch, diagnostics                                                 |
| `chatgptWinTitle`, `departmentChatgptWinTitle`                                                                                                                                                                                                  | `GetChatGptWinTitle`                                                                                                                    |
| `promotionTextSaveEnabled`                                                                                                                                                                                                                      | Promotion workflows and department-start validation                                                                                     |
| `promptDir`                                                                                                                                                                                                                                     | Template-path initialization                                                                                                            |
| `FullPromptTemplatePath`, `FullToolsPromptTemplatePath`, `DepartmentPromptTemplatePath`, `MetadataPromptTemplatePath`, `ImageOnlyPromptTemplatePath`, `MatrixImagePromptTemplatePath`, `MatrixFullPromptTemplatePath`, `BotzPromptTemplatePath` | `GetSeoPromptOptionsForMode`                                                                                                            |
| `FiguredArtDefaultPromptTemplatePath`                                                                                                                                                                                                           | Prompt registry, runtime initialization, settings application                                                                           |
| `logDir`, `backupDir`, `stateDir`, `debugDir`                                                                                                                                                                                                   | Directory creation, artifact writers, diagnostic writers; `stateDir` also builds state paths                                            |
| `matrixStateFilePath`, `matrixFullStateFilePath`, `botzStateFilePath`                                                                                                                                                                           | Corresponding workflow-state load/save functions                                                                                        |
| `figuredArtStateFilePath`, `figuredArtRootDir`                                                                                                                                                                                                  | Figured’Art library                                                                                                                     |
| `botzPromptSettingsFilePath`, `botzDefaultPageUrl`                                                                                                                                                                                              | Settings load/save/defaults; URL runtime initialization                                                                                 |
| `botzRootDir`                                                                                                                                                                                                                                   | `FindUniqueBotzProductFolder`                                                                                                           |
| `botzFilePickerTimeoutMs`                                                                                                                                                                                                                       | File-transfer helpers and both supplier upload implementations                                                                          |
| `botzChatPickerFolderLoadMs`, `botzChatPickerSelectAllMs`, `botzChatAttachmentSettleMs`                                                                                                                                                         | Supplier attachment/picker workflow                                                                                                     |
| `botzImagesTabLoadMs`, `botzImageDetailsLoadMs`                                                                                                                                                                                                 | Both supplier upload implementations                                                                                                    |
| `matrixNavigationDelayMs`, `matrixReturnDelayMs`, `matrixFullyReopenParentAfterReturn`, `matrixParentReopenDelayMs`, `matrixCatalogueSearchTimeoutMs`, `matrixCatalogueScrollSettleDelayMs`, `matrixPageWaitTimeoutMs`                          | Matrix navigation                                                                                                                       |
| `matrixSkuTabSettleDelayMs`                                                                                                                                                                                                                     | Matrix discovery retry and parent reopening                                                                                             |
| `matrixStableDurationMs`                                                                                                                                                                                                                        | Matrix discovery/navigation and shared live-control waits                                                                               |
| `matrixUiaSearchTimeoutMs`, `matrixScrollWheelNotchesPerStep`, `matrixMaxScrollSteps`, `matrixNoNewRowsStopCount`                                                                                                                               | Matrix discovery/scrolling                                                                                                              |
| `attemptImageCopyAfterPrompt`                                                                                                                                                                                                                   | Ordinary-product prompt workflow                                                                                                        |
| `maximumImagesPerProduct`                                                                                                                                                                                                                       | Image-count setters/validation, output-field generation, gallery counting, supplier selection/state validation, matrix-state validation |
| `imageTargets`                                                                                                                                                                                                                                  | Gallery target lookup/validation; matrix insertion validation                                                                           |
| `imageGalleryPageSize`                                                                                                                                                                                                                          | Gallery index mapping, sequential image transfer/editing, matrix-state validation                                                       |
| `imageGalleryMaxPages`                                                                                                                                                                                                                          | Gallery traversal and matrix-state validation                                                                                           |
| `imageGalleryNextPageDelayMs`, `imageGalleryPreviousPageDelayMs`, `imageAccessibilityTreeInitialDelayMs`                                                                                                                                        | Gallery navigation                                                                                                                      |
| `imageGalleryPageChangeTimeoutMs`, `imageGalleryFirstPageNoChangeTimeoutMs`, `imageGalleryAvailabilityTimeoutMs`, `imageGalleryCountTimeoutMs`, `imageGalleryCountStableDurationMs`, `imageGalleryMinimumObservationMs`, `imageTabLoadDelayMs`  | Gallery readiness/counting; diagnostic summary                                                                                          |
| `copyHighQualityImagePreview`, `highQualityImageCopyPoint`, `highQualityImagePreviewLoadDelayMs`, `allowThumbnailImageCopyFallback`, `imageContextCopyKey`                                                                                      | CMS image-copy functions                                                                                                                |
| `imageCopyPreCopyDelayMs`                                                                                                                                                                                                                       | CMS image-copy function; diagnostic summary                                                                                             |
| `chatPasteRetries`, `chatWakeDelayMs`                                                                                                                                                                                                           | Prompt paste/focus helpers                                                                                                              |
| `chatPasteVerifyDelayMs`                                                                                                                                                                                                                        | No current reader found                                                                                                                 |
| `chatResponseCopyTimeoutMs`, `chatResponseScrollNotches`, `chatResponseRecoveryPageUpCount`, `chatResponseRecoveryPageDownCount`, `chatResponseCopyButtonPoint`                                                                                 | Response-copy functions                                                                                                                 |
| `chatResponseInitialWaitMs`, `chatResponsePollIntervalMs`, `imageOnlyChatResponseInitialWaitMs`, `imageOnlyChatResponsePollIntervalMs`                                                                                                          | `WaitForAutomaticChatGptOutput`                                                                                                         |
| `chatImageWindowWakeDelayMs`                                                                                                                                                                                                                    | CMS-to-ChatGPT transfers and automatic submission; diagnostics                                                                          |
| `chatImageFocusDelayMs`, `chatImageAttachmentTimeoutMs`, `chatImageAttachmentPollIntervalMs`, `chatImageAttachmentSettleMs`                                                                                                                     | ChatGPT image focus/attachment verification; diagnostics                                                                                |
| `chatImagePasteFallbackDelayMs`                                                                                                                                                                                                                 | Single-image transfer fallback; diagnostics                                                                                             |
| `chatSubmitPreEnterDelayMs`                                                                                                                                                                                                                     | Automatic submission; diagnostics                                                                                                       |
| `cmsImageDetailsButtonTimeoutMs`, `cmsImageDetailsFormTimeoutMs`, `cmsImageDetailsOpenAttempts`, `cmsImageGalleryReturnTimeoutMs`, `cmsImageGalleryReturnSettleMs`                                                                              | Existing image metadata editing; diagnostics                                                                                            |
| `departmentCatalogueWaitMs`                                                                                                                                                                                                                     | Department batch                                                                                                                        |
| `departmentCatalogueTreeTimeoutMs`, `departmentProductOpenDelayMs`                                                                                                                                                                              | Catalogue traversal/open verification                                                                                                   |
| `promotionReferenceSearchTimeoutMs`, `promotionReferenceProductOpenDelayMs`, `promotionReferenceScanMaxScrollSteps`, `promotionReferenceScanNoChangeStopCount`, `promotionReferenceScanWheelNotches`                                            | Reference catalogue scanning/search                                                                                                     |
| `promotionReferenceCatalogueReturnDelayMs`                                                                                                                                                                                                      | Reference promotion batch                                                                                                               |
| `coords`                                                                                                                                                                                                                                        | Named clicks, image controls, reference catalogue geometry, matrix Save/reopen, diagnostics                                             |

Built-in and external state is equally significant:

- `A_Clipboard` carries both text and images. Different helpers deliberately restore it or leave new data in it.
- The active browser window, selected CMS tab, gallery page, scroll position, open dialog, and ChatGPT draft are implicit workflow state.
- Tooltips are shared across callbacks.
- UIA element objects can become stale after navigation.
- Mouse coordinate mode and title-match mode affect subsequent event threads.

The **GUI and event contract** should remain unchanged.

| Control / object                                         | Behavior and callback                                                                                  |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Mode dropdown: `seoAutomationMode`                       | Change → `UpdateSeoPromptSettingsControls.Bind(controls)`                                              |
| Prompt dropdown: `seoPrompt`                             | Change → `RememberSeoPromptSelection.Bind(controls)`                                                   |
| `promptSelections`                                       | Local map retaining selections while that GUI exists; not a GUI control or persisted per-mode registry |
| Promotion edit: `promotionText`                          | Enabled only for the two promotion modes                                                               |
| Testing checkbox: `testingModeEnabled`                   | Saved as a Boolean                                                                                     |
| `pageUrl`                                                | Shared page URL                                                                                        |
| `inlink1Name`, `inlink1Url`, `inlink2Name`, `inlink2Url` | Two name/URL pairs                                                                                     |
| `inlinkExtra`, `additionalNotes`                         | Multiline settings                                                                                     |
| Save button                                              | Click → `SaveSeoPromptSettingsFromGui.Bind(settingsGui, controls)`                                     |
| Cancel button                                            | Click → `CloseSeoPromptSettingsGui.Bind(settingsGui)`                                                  |
| GUI Close / Escape                                       | → `CloseSeoPromptSettingsGui`                                                                          |

The GUI uses explicit control references, `.Value`/`.Text`, and bound callbacks. It does not use a collection of `vName` global control variables.

Saving settings while an automatic run is active blocks changes to the **mode or prompt**. It does not freeze every other setting. Preserve that scope in the first refactor.

The active hotkeys are:

| Hotkey                | Handler / effect                                      |
| --------------------- | ----------------------------------------------------- |
| Ctrl+Alt+T            | `TestScript`                                          |
| Ctrl+Alt+W            | `CopyActiveWindowTitle`                               |
| Ctrl+Alt+C            | `CaptureMouseCoords`                                  |
| NumpadEnter           | Open selected product and dispatch workflow           |
| Numpad4               | Dispatch from already-open product                    |
| Ctrl+Alt+I            | Copy CMS images into ChatGPT                          |
| Ctrl+Alt+N            | Toggle recommended product-name insertion             |
| Ctrl+Alt+A            | Toggle automatic completion                           |
| Ctrl+Alt+D            | Toggle department batch                               |
| Ctrl+Numpad4          | Start department batch                                |
| Ctrl+Numpad6          | Stop department/reference batch after current product |
| Ctrl+Shift+NumLock    | Open settings                                         |
| Ctrl+0 through Ctrl+9 | Set current image count                               |
| Numpad6               | Manual response-copy/insertion fallback               |
| F8                    | Show last matrix control locations                    |
| F9                    | Dump CMS accessibility tree                           |
| Ctrl+Alt+R            | Reload                                                |
| Escape                | Exit application                                      |

The historical Ctrl+Alt+P/B/O/S bindings are commented out. Keep them as comments; do not accidentally register them during extraction.

`CaptureMouseCoords` and `Flash` each create an anonymous, one-shot `SetTimer` callback to clear the tooltip. There are no application-level periodic timer loops to relocate.

The **mode behavior matrix** explains why some modes should remain together initially:

| Mode                       | Existing implementation                    | CMS behavior to preserve                                                                          |
| -------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| `full`                     | Ordinary workflow                          | Optional name, metadata, HTML, image metadata, main Save                                          |
| `department`               | Ordinary workflow with department branches | Identity from name; fixed one image; separate ChatGPT-title setting; main product remains unsaved |
| `metadata`                 | Ordinary workflow                          | Optional name, metadata and image SEO; no HTML replacement; main Save                             |
| `image`                    | Ordinary workflow + strict image parser    | Image Name/Title/Alt only; main Save                                                              |
| `matrix_image`             | Matrix-image functions                     | Parent/child image Title/Alt; stable child ordering and repeated parent reopening                 |
| `matrix_full`              | Matrix-full functions                      | Optional parent name, parent metadata/images; child metadata cleared; child HTML/images updated   |
| `botz`                     | BOTZ functions                             | Match source folder, attach supplier images, upload first 11, populate content, Save              |
| `figuredart`               | Existing library                           | Exact supplier-code matching plus validated successful `product.md`; separate saved state         |
| `promotion_text`           | Promotion workflow                         | Fill or clear Description and Custom promotional fields                                           |
| `promotion_text_reference` | Reference batch + promotion workflow       | Inventory references, search exact codes, verify product, update, Save, continue                  |

Important existing differences:

- `NumpadEnter` rejects Matrix Image mode but supports Matrix Full.
- Department review is rejected by department-wide batch startup.
- Supplier prompt construction already submits to ChatGPT, even when ordinary full-workflow automation is off.
- Only ordinary Image-only mode uses the shorter response polling configuration.
- Matrix prompt construction attaches images before pasting the final assembled prompt.
- Department image handling bypasses gallery discovery, but still checks the image detail form.
- Image Details Save and main-product Save are separate operations.

The **principal function dependencies** form these execution chains:

```text
Startup
  → InitialiseSeoPromptSettings
    → LoadBotzPromptSettings / CreateDefaultBotzPromptSettings
    → ApplySharedSeoPromptSettings
      → registry + inlink formatting + optional diagnostics
```

```text
Numpad4
  → BuildPromptFromOpenProductPageAndPasteToChatGPT
  → RunOpenProductWorkflow
    → selected mode's preparation function
    → RunAutomaticWorkflowIfEnabled
      → SubmitChatGptDraftForAutomaticWorkflow
      → WaitForAutomaticChatGptOutput
      → PasteCopiedChatGPTOutputToCms(false)
```

```text
Ordinary preparation
  → read CMS fields and identity
  → log/back up originals
  → detect image count, or department fixed count
  → BuildPromptFromTemplate
  → EnsurePromptSupportsImageCount / InjectImageOnlyOutputFields
  → PastePromptToChatGPT
  → TryCopyCmsImagesToChatGPT
```

```text
CMS image transfer
  → measure ChatGPT attachment baseline
  → prepare CMS gallery
  → CopyCmsImageToClipboard
  → focus ChatGPT and paste
  → WaitForChatGptDraftAttachmentCount
```

```text
Manual insertion
  → RunManualChatGptOutputPaste
  → cancel an active automatic wait if necessary
  → PasteCopiedChatGPTOutputToCms
    → copy response
    → mode-specific parsing/validation
    → CMS insertion
  → record successful manual completion for the suspended workflow
```

```text
Department batch
  → ReadOpenCmsProductIdentity
  → RunOpenProductWorkflow(true)
  → PrepareCompletedProductForCatalogueLookup
  → FindNextDepartmentCatalogueProduct
  → OpenAndVerifyNextDepartmentProduct
  → repeat
```

```text
Matrix traversal
  → FullyReopenActiveMatrixParent
  → ReacquireMatrixSkuControls / ReacquireAndValidateMatrixOrder
  → ClickMatrixEditButton
  → WaitForChildProductPage
  → collect or update child
  → child Cancel / Save
  → WaitForMatrixSkuPage
  → FullyReopenActiveMatrixParent(true)
```

```text
Supplier creation
  → match product folder and validate source
  → enumerate/naturally sort images
  → build prompt + save source snapshot
  → attach all supported images + submit
  → load/validate response and saved source
  → verify current CMS product
  → upload with persisted progress
  → insert content + main Save
```

Some circular function dependencies remain after extraction—for example settings/builders, diagnostics/artifacts, and ordinary/automatic workflows. That is acceptable for this first pass. Use a central include list; do not have modules recursively include one another to express those calls.

The **persistent settings and workflow files are separate contracts**:

| File                                 | Existing format / behavior                                                                     |
| ------------------------------------ | ---------------------------------------------------------------------------------------------- |
| `state/botz-prompt-settings.txt`     | `CROMARTIE_BOTZ_PROMPT_SETTINGS_V1`; shared settings for all modes; temporary-file replacement |
| `state/matrix-image-state.txt`       | `CROMARTIE_MATRIX_STATE_V3`; parent identity, ordered children, image counts and row context   |
| `state/matrix-full-state.txt`        | `CROMARTIE_MATRIX_FULL_STATE_V3`; additionally retains child HTML                              |
| `state/botz-product-state.txt`       | Writes V3; reads V2/V3; source manifest and upload progress                                    |
| `state/figuredart-product-state.txt` | `CROMARTIE_FIGUREDART_STATE_V1`; independent supplier state and upload progress                |

The shared settings record persists mode, active prompt ID, URL, two internal links, extra link information, notes, promotional text, and testing mode.

It does **not** persist the automation toggles, recommended-name toggle, manually selected image count, coordinates, or timing configuration. Those restart from source defaults.

Preserve these subtleties:

- Older settings files can omit newer fields.
- An older file without a prompt ID selects that mode’s default prompt.
- Workflow loaders prefer an existing in-memory state map over rereading disk.
- BOTZ and matrix writers currently delete/rewrite their files; settings and Figured’Art use a temporary file and replacement.
- `%`, tab, CR, and LF escaping is order-dependent.
- Saved source paths, sizes, modification times, and upload progress are part of supplier recovery behavior.

The **prompt analysis** suggests separating prompt construction from workflow execution, while retaining every current template.

| Mode / selection     | Active template                     |
| -------------------- | ----------------------------------- |
| Full standard        | `prompt-template.md`                |
| Full tools           | `prompt-template-tools-products.md` |
| Department           | `prompt-template-department.md`     |
| Metadata             | `prompt-template-metadata-only.md`  |
| Image                | `prompt-template-image-only.md`     |
| Matrix Image         | `prompt-template-matrix-image.md`   |
| Matrix Full          | `prompt-template-matrix-full.md`    |
| BOTZ                 | `prompt-template-botz-engobes.md`   |
| Figured’Art          | `prompt-template-figuredart.md`     |
| Both promotion modes | No prompt                           |

`prompt-template-botz.md` and `prompt-template-metadata-only_bisque.md` are present but not selected by the current registry. They should remain untouched.

Repeated instructions include:

- UK English and “colour” spelling.
- Exact-product targeting and avoiding keyword stuffing.
- Avoiding invented product facts.
- Accurate descriptions of visible images.
- Distinct image title/alt/name values where applicable.
- No citations, source tokens, placeholders, or commentary inside automation values.
- Preserving field labels, counts, product order, and identifiers.
- Metadata length targets.
- Inline CSS, Cromartie styling, and supported specification-table rows.
- Internal links as navigation rather than product-fact evidence.
- First-11 CMS images versus later supplier attachments used only as context.

There is also repetition **within individual templates**:

- Tools repeats internal-link input and image-note input.
- Department repeats link, image-note, additional-note, and URL substitutions.
- Both supplier templates repeat attachment-order/count instructions in input and final-authority sections.
- A literal HTML wrapper block is shared across the Tools, BOTZ, BOTZ Engobes, and Figured’Art templates.

These are future consolidation candidates, not extraction changes. Prompt wording and repetition can affect generated output even when the intended meaning appears unchanged.

The prompt-building code has distinct contracts:

- `BuildPromptFromTemplate` substitutes ordinary page fields.
- `EnsurePromptSupportsImageCount` handles zero, one, and multiple images differently and uses a regex over the default image section.
- `InjectImageOnlyOutputFields` inserts Name/Title/Alt fields.
- Supplier builders validate required markers and distinguish attachment count from CMS image count.
- Matrix builders generate parent-first attachment maps and ordered per-child fields.
- Matrix Image and Matrix Full use different placeholder wording and different child context.
- Figured’Art reads its active template-path global directly for standalone-library compatibility.

The **duplicated or unclear code should be recorded, then left unchanged**:

| Area                            | Finding                                                                                                                                                 |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BOTZ versus Figured’Art         | Similar preparation, prompt substitutions, state records, parsing, source validation, verification, upload loops, and completion logic                  |
| Matrix Image versus Matrix Full | Similar parent discovery, ordered child traversal, image collection, attachment mapping, and insertion loops                                            |
| Parsing                         | Several implementations extract labelled fields, but their acceptance rules differ                                                                      |
| Validation                      | Repeated placeholder/source-token checks and image-distinctness checks                                                                                  |
| Navigation waits                | Repeated deadline, stability-signature, retry, and fresh-document patterns                                                                              |
| Clipboard operations            | Similar save/clear/paste/restore code, with materially different success behavior                                                                       |
| Normalization                   | Several superficially similar functions serve different contracts                                                                                       |
| Ordinary insertion              | `PasteCopiedChatGPTOutputToCms` combines dispatch, parsing, validation, browser operations, persistence-related identity, and UI reporting              |
| Prompt preparation              | `Build*Prompt` workflow functions also navigate, read files, save state, attach images, and sometimes submit                                            |
| Shared names                    | `BuildBotzRecommendedInlinks`, supplier file helpers, `BuildBotzParsedOutputLog`, and `ValidateMatrixFullOneLine` are not exclusive to their named mode |
| Product identity                | `activeCmsProductCode` sometimes contains a product name                                                                                                |
| Timing configuration            | Generic control waits use matrix-named timing; Figured’Art uses BOTZ-named upload timing                                                                |
| UI diagnostics                  | `TestScript` calls a state loader, so it can populate a workflow-state cache                                                                            |
| Persisted fields                | `initialGalleryCount` is stored/restored in supplier state but has no active decision-making use found                                                  |

Do not “standardize” these existing parser differences:

| Parser                         | Current behavior                                                                                     |
| ------------------------------ | ---------------------------------------------------------------------------------------------------- |
| `ParseAutomationOutput`        | Relatively permissive substring-based extraction; optional image names                               |
| `ParseExactLineFields`         | One-line values; rejects unknown/duplicate/missing fields; does not enforce the supplied label order |
| `ParseOrderedAutomationFields` | Ordered labels; supports multiline values                                                            |
| `ParseMatrixFullOutput`        | Validates the complete label sequence using its own implementation                                   |

Likewise, prompts generally target 60/160-character metadata, while ordinary/supplier validation rejects lengths above 65/170. Matrix Full does not simply apply the same full validation path. Preserve these distinctions.

The largest functions are reasonable later decomposition targets:

| Function                                | Lines | Potential later separation                                                 |
| --------------------------------------- | ----: | -------------------------------------------------------------------------- |
| `PasteCopiedChatGPTOutputToCms`         |   132 | Dispatch, identity capture, parse/validate, apply, save/report             |
| `StartDepartmentAutomation`             |   119 | Start checks, one-product step, stop handling, next-product selection      |
| `FullyReopenActiveMatrixParent`         |   118 | Close/save, catalogue reacquisition, guarded retry, reopen verification    |
| `WaitForStableImageGalleryCount`        |    97 | Sampling, consistency/stability decisions, diagnostics, timeout reporting  |
| `ParseMatrixFullOutput`                 |    92 | Schema generation, sequence validation, field extraction, value validation |
| `BuildPromptFromCurrentProductPage`     |    88 | Capture context, backup, prompt assembly, attachment preparation           |
| `PasteMatrixFullOutputToCms`            |    82 | Parent update, child update, navigation, reporting                         |
| `BuildBotzPrompt`                       |    81 | Source resolution, source snapshot, prompt creation, submission            |
| `OpenSeoPromptSettingsGui`              |    79 | Control creation, initial values, event wiring                             |
| `WaitForCatalogueMatrixParentEditPoint` |    76 | Search roots, scroll/reacquire, rectangle stabilization                    |
| `RunPromotionTextReferenceWorkflow`     |    75 | Inventory, per-reference step, stop/report handling                        |
| `LoadBotzState`                         |    75 | Record reading, version compatibility, validation, map construction        |

The included `BuildFiguredArtPrompt` is another 82-line counterpart. These functions should move whole during the first refactor.

The **apparently unused inventory** is:

| Function / variable                 | Evidence                                                   |
| ----------------------------------- | ---------------------------------------------------------- |
| `IsAnyPromotionTextMode`            | No caller found                                            |
| `WakeChatGptInput`                  | No caller found; explicitly retained compatibility wrapper |
| `VerifyChatGptPromptPasted`         | No caller found; explicitly retired verification path      |
| `PromptPasteLooksValid`             | Called only by the retired verification function           |
| `SetClipboardText`                  | No caller found                                            |
| `TryCopyCmsImageToChatGPT`          | No caller found; explicitly retained compatibility wrapper |
| `CopyBrowserUrl`                    | No caller found; workflows use the configured public URL   |
| `DeriveVariantContext`              | No caller found; other variant extraction is used          |
| `RejectPotentiallyIncompleteMatrix` | No caller found; current discovery supports scrolling      |
| `chatPasteVerifyDelayMs`            | No reader found                                            |

These are static-analysis findings, not grounds for deletion. All nine functions remain allocated above.

The **AutoHotkey-specific extraction hazards** are concrete:

1. **Includes do not create namespaces.** Functions retain global names; declarations can collide across files. Relative include paths resolve from the file containing the directive. Keep a central, explicit include list and avoid `#IncludeAgain`. [AutoHotkey include documentation](https://raw.githubusercontent.com/AutoHotkey/AutoHotkeyDocs/v2/docs/lib/_Include.htm)

2. **Keep global initialization global.** Wrapping assignments in `InitConfig()` without matching declarations would change scope. AutoHotkey v2 permits implicit global reads in assume-local functions, but assignment and `&` usage change resolution. Keep existing `global` declarations and parameter signatures. [AutoHotkey function-scope documentation](https://raw.githubusercontent.com/AutoHotkey/AutoHotkeyDocs/v2/docs/Functions.htm)

3. **Preserve startup ordering.** The current order is thread defaults, variable initialization, settings load/application, `OnError`, then `OnExit`. In v2, function and hotkey definitions are skipped during execution; they do not impose the old v1 auto-execute boundary. [AutoHotkey startup documentation](https://raw.githubusercontent.com/AutoHotkey/AutoHotkeyDocs/v2/docs/Scripts.htm)

4. **Keep the main script in place.** Existing resource paths are based on `A_ScriptDir`. Do not move the entry point into `Core/` or change path roots to individual include directories.

5. **Preserve callback identity and arguments.** Keep `.Bind(...)`, `(*)`, `&problem`, anonymous timers, and handler return values unchanged.

6. **Preserve interruptibility.** `Sleep`, message boxes, and other event opportunities allow hotkeys to interrupt active workflows. Introducing timers, `Critical`, new locks, or asynchronous wrappers would change behavior.

7. **Preserve object identity.** Arrays and maps are mutable objects. Sorting paths and updating supplier progress currently affect the passed objects.

8. **Preserve clipboard ownership.** CMS text-copy helpers restore the response clipboard; successful image-copy helpers leave the image available for the next paste.

9. **Preserve UIA timing and access order.** An extra tree read is not necessarily harmless. The matrix code explicitly avoids stale-tree reads and unnecessary second discovery passes.

10. **Preserve physical interaction choices.** CMS Edit/Save handling often uses UIA only for location discovery, followed by a real click. Replacing this with `Invoke()` is a behavioral change.

11. **Preserve encoding and string contents.** The main script is UTF-8 without a BOM and contains mixed line endings. Unicode dashes matter in catalogue normalization. Avoid incidental encoding conversion, string reformatting, or whitespace cleanup.

12. **Expect diagnostic location changes.** `err.File`, `err.Line`, stacks, and displayed source locations will identify extracted files. Workflow behavior can remain unchanged, but those source-location details cannot remain literally identical.

13. **Keep standalone tests isolated.** The Figured’Art test defines many stub/shared function names. Including the production bootstrap in that test would introduce duplicate definitions and startup effects.

A suitable final bootstrap would retain the existing startup statements directly:

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "UIA-v2\Lib\UIA.ahk"
#Include "UIA-v2\Lib\UIA_Browser.ahk"
#Include "lib\figuredart-product-creation.ahk"

SetTitleMatchMode 2
CoordMode "Mouse", "Screen"

#Include "Core\Configuration.ahk"
#Include "Core\RuntimeState.ahk"

; Explicit includes for the function-only modules listed above.
; No module performs workflow startup merely by being included.

InitialiseSeoPromptSettings()
OnError(LogUnhandledErrorForTesting)
OnExit(LogTestingSessionExit)

#Include "UI\Hotkeys.ahk"
```

This is a proposed shape, not a file change. The actual entry point should contain explicit includes rather than the explanatory placeholder.

For the eventual implementation, each extraction should verify:

- The complete named-function inventory, signatures, defaults, and bodies remain intact.
- All 27 bindings and GUI/error/exit/timer callbacks still reference the same functions.
- Prompt-builder outputs match baseline fixtures exactly.
- Existing settings and workflow-state versions load with the same results.
- Parser acceptance and rejection behavior remains unchanged.
- Clipboard, save/reopen, cancellation, image pagination, supplier recovery, and department-stop behavior receive focused regression checks.
- The existing Figured’Art test remains independently loadable; its stubs do not constitute full production integration coverage.

The recommended extraction order, from lowest risk to highest risk, is:

1. **Text helpers and pure matrix-row interpretation.** Move whole functions without altering normalization or regexes.
2. **Output parsing, validation, and prompt builders.** Preserve every separate implementation and exact generated string.
3. **Shared supplier-file helpers.** Verify natural ordering, manifests, and first-11 selection.
4. **Mode/prompt registry and workflow-state functions.** Preserve registrations, serialized formats, compatibility, and cache behavior.
5. **Artifact logging, testing diagnostics, and display-only UI helpers.** Preserve identity prerequisites and non-blocking diagnostic failures.
6. **Settings persistence and settings GUI.** Keep callback bindings and settings side effects unchanged.
7. **Browser interaction, ChatGPT interaction, and file transfers.** Check clipboard ownership, focus behavior, and submission timing.
8. **CMS field access, shared UIA controls, and catalogue/reference navigation.**
9. **Image gallery discovery, image copying, metadata editing, and CMS-to-ChatGPT coordination.**
10. **Ordinary, promotion, and BOTZ workflow functions.** Move complete bodies, including their current mixed responsibilities.
11. **Product dispatch, automatic completion, department batching, and state-changing hotkey handlers.** Verify interruption and manual-completion handoffs.
12. **Matrix discovery/navigation and both matrix workflows.** Preserve the entire reacquire/save/reopen protocol.
13. **Configuration/runtime declarations, literal hotkeys, and final bootstrap cleanup.** Finish only after checking initialization dependencies and confirming the entry point contains no remaining workflow implementation.
