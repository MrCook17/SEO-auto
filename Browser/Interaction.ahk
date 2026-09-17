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

SetClipboardText(text) {
    A_Clipboard := ""
    Sleep 100
    A_Clipboard := text

    if !ClipWait(2) {
        throw Error("Clipboard did not receive prompt text.")
    }
}

ClickCoordinates(point, delayMs := 250) {
    if point[1] = 0 || point[2] = 0
        throw Error("Coordinate not set.")

    Click point[1], point[2]
    Sleep delayMs
}

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

SendNativeMouseWheel(direction, notchCount) {
    ; mouse_event produces actual wheel input instead of a keyboard-style Send.
    ; This avoids the Windows alert sound seen with large {WheelUp/Down} sends.
    wheelDelta := direction > 0 ? 120 : -120
    Loop notchCount {
        DllCall("user32\mouse_event", "UInt", 0x0800, "UInt", 0, "UInt", 0, "Int", wheelDelta, "UPtr", 0)
        Sleep 12
    }
}

