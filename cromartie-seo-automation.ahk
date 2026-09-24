#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "UIA-v2\Lib\UIA.ahk"
#Include "UIA-v2\Lib\UIA_Browser.ahk"
#Include "lib\figuredart-product-creation.ahk"

SetTitleMatchMode 2
CoordMode "Mouse", "Screen"

#Include "Core\Configuration.ahk"
#Include "Core\RuntimeState.ahk"

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

InitialiseSeoPromptSettings()
OnError(LogUnhandledErrorForTesting)
OnExit(LogTestingSessionExit)

#Include "UI\Hotkeys.ahk"
