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

