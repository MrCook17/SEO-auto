#Requires AutoHotkey v2.0
#SingleInstance Force

; Folder structure:
;   tools\
;       uia-click-third-edit-auto-count.ahk
;   UIA-v2\
;       Lib\
;           UIA.ahk
;           UIA_Browser.ahk
#Include "..\UIA-v2\Lib\UIA.ahk"
#Include "..\UIA-v2\Lib\UIA_Browser.ahk"

TARGET_EDIT_INDEX := 3
SEARCH_TIMEOUT_MS := 7000
STABLE_DURATION_MS := 1000

global LastEditButtons := []
global LastDocument := 0

; F6: automatically count the visible Edit controls and click the third.
F6::FindCountAndClickThirdEdit()

; F8: show the locations found during the last F6 run.
F8::ShowLastLocations()

; F9: dump Chrome's accessibility tree for diagnosis.
F9::DumpAccessibilityTree()

; F7: reload the script.
F7::Reload()

; Ctrl+Escape: exit.
^Esc::ExitApp()


FindCountAndClickThirdEdit() {
    global TARGET_EDIT_INDEX
    global SEARCH_TIMEOUT_MS
    global STABLE_DURATION_MS
    global LastEditButtons
    global LastDocument

    try {
        hwnd := WinExist("A")

        if !hwnd {
            MsgBox("No active window was found.")
            return
        }

        if (WinGetProcessName("ahk_id " hwnd) != "chrome.exe") {
            MsgBox(
                "The active window is not Google Chrome.`n`n"
                "Activate the GO b2b Chrome window and press F6 again."
            )
            return
        }

        ToolTip("Reading Chrome accessibility information...")

        browser := UIA_Browser()
        document := browser.GetCurrentDocumentElement()
        LastDocument := document

        ; Find the matrix modal from its heading. This avoids counting Edit
        ; controls on the catalogue page behind the modal.
        searchScope := FindMatrixModalScope(document)

        if !searchScope {
            ToolTip()
            MsgBox(
                "The matrix-product modal could not be identified.`n`n"
                "Make sure the window headed 'Editing Matrix Product:' is open."
            )
            return
        }

        ; No expected count is supplied. The script polls until the detected
        ; Edit locations remain unchanged for STABLE_DURATION_MS.
        LastEditButtons := WaitForStableEditLocations(
            searchScope,
            SEARCH_TIMEOUT_MS,
            STABLE_DURATION_MS
        )

        ToolTip()

        detectedCount := LastEditButtons.Length

        if (detectedCount = 0) {
            MsgBox(
                "No visible Edit controls were detected.`n`n"
                "No button was clicked.`n`n"
                "Press F9 to create an accessibility-tree dump."
            )
            return
        }

        if (detectedCount < TARGET_EDIT_INDEX) {
            MsgBox(
                "Detected " detectedCount " visible Edit control(s).`n`n"
                BuildLocationsMessage(LastEditButtons)
                "`nThere is no Edit control number " TARGET_EDIT_INDEX
                ", so nothing was clicked."
            )
            return
        }

        target := LastEditButtons[TARGET_EDIT_INDEX]

        ToolTip(
            "Detected " detectedCount " Edit control(s):`n`n"
            BuildLocationsMessage(LastEditButtons)
            "`nHighlighting and clicking number "
            TARGET_EDIT_INDEX "..."
        )

        ; Briefly highlight the selected accessibility element.
        try target.Element.Highlight()
        Sleep(1000)

        clickedWithUIA := false

        ; Prefer the element's UI Automation action.
        try {
            target.Element.Click()
            clickedWithUIA := true
        }

        ; If Chrome exposes only a text element, click its screen centre.
        if !clickedWithUIA {
            CoordMode("Mouse", "Screen")
            Click(target.CentreX, target.CentreY)
        }

        try UIA.ClearAllHighlights()

        ToolTip(
            "Detected " detectedCount " Edit control(s).`n"
            "Clicked Edit control " TARGET_EDIT_INDEX
            " at " target.CentreX "," target.CentreY "."
        )
        SetTimer(ClearToolTip, -3000)

    } catch as err {
        ToolTip()
        try UIA.ClearAllHighlights()

        MsgBox(
            "UI Automation failed.`n`n"
            "Error: " err.Message
            (err.Extra != "" ? "`nExtra: " err.Extra : "")
        )
    }
}


FindMatrixModalScope(document) {
    ; Locate the modal heading. mm:2 means substring matching.
    try {
        titleElement := document.FindElement({
            Name: "Editing Matrix Product:",
            mm: 2,
            cs: 0
        })
    } catch {
        return 0
    }

    scope := titleElement

    ; Starting from the heading, climb through its parents. The first
    ; ancestor containing an Edit control should be the modal container,
    ; before reaching the catalogue page behind it.
    Loop 15 {
        locations := GetUniqueVisibleEditLocations(scope)

        if (locations.Length > 0)
            return scope

        try {
            parent := UIA.TreeWalkerTrue.GetParentElement(scope)
        } catch {
            break
        }

        if !parent
            break

        scope := parent
    }

    return 0
}


WaitForStableEditLocations(searchScope, timeoutMs, stableDurationMs) {
    deadline := A_TickCount + timeoutMs
    best := []
    previousSignature := ""
    stableSince := 0

    Loop {
        current := GetUniqueVisibleEditLocations(searchScope)

        if (current.Length > best.Length)
            best := current

        signature := BuildLocationSignature(current)

        if (current.Length > 0) {
            if (signature = previousSignature) {
                if (stableSince = 0)
                    stableSince := A_TickCount

                if ((A_TickCount - stableSince) >= stableDurationMs)
                    return current
            } else {
                previousSignature := signature
                stableSince := A_TickCount
            }
        } else {
            previousSignature := ""
            stableSince := 0
        }

        if (A_TickCount >= deadline)
            return best

        Sleep(250)
    }
}


BuildLocationSignature(items) {
    signature := items.Length "|"

    for _, item in items {
        signature .= (
            item.X "," item.Y ","
            item.W "," item.H ";"
        )
    }

    return signature
}


GetUniqueVisibleEditLocations(searchScope) {
    raw := []
    unique := []

    ; Search every UIA control type whose accessible Name contains "Edit".
    try {
        elements := searchScope.FindElements({
            Name: "Edit",
            mm: 2,
            cs: 0
        })
    } catch {
        return unique
    }

    for _, element in elements {
        try {
            name := element.Name

            ; Exclude "Editing Matrix Product" while accepting controls such
            ; as "Edit", "Edit SKU" or "Pencil Edit".
            if !RegExMatch(name, "i)(^|[^A-Za-z])Edit([^A-Za-z]|$)")
                continue

            if element.IsOffscreen
                continue

            rect := element.Location

            if (
                rect.w <= 0
                || rect.h <= 0
                || rect.x < 0
                || rect.y < 0
            )
                continue

            raw.Push({
                Element: element,
                Name: name,
                X: Round(rect.x),
                Y: Round(rect.y),
                W: Round(rect.w),
                H: Round(rect.h),
                CentreX: Round(rect.x + rect.w / 2),
                CentreY: Round(rect.y + rect.h / 2)
            })
        }
    }

    ; Chrome can expose both a control and its child text. Merge overlapping
    ; locations so each visible green Edit control is counted once.
    for _, candidate in raw {
        duplicateIndex := 0

        for index, saved in unique {
            if LocationsRepresentSameControl(candidate, saved) {
                duplicateIndex := index
                break
            }
        }

        if !duplicateIndex {
            unique.Push(candidate)
        } else {
            oldArea := unique[duplicateIndex].W * unique[duplicateIndex].H
            newArea := candidate.W * candidate.H

            ; Keep the larger rectangle, normally the actual clickable control.
            if (newArea > oldArea)
                unique[duplicateIndex] := candidate
        }
    }

    SortLocationsTopToBottom(unique)
    return unique
}


LocationsRepresentSameControl(first, second) {
    centreClose := (
        Abs(first.CentreX - second.CentreX) <= 18
        && Abs(first.CentreY - second.CentreY) <= 18
    )

    firstInsideSecond := (
        first.CentreX >= second.X
        && first.CentreX <= second.X + second.W
        && first.CentreY >= second.Y
        && first.CentreY <= second.Y + second.H
    )

    secondInsideFirst := (
        second.CentreX >= first.X
        && second.CentreX <= first.X + first.W
        && second.CentreY >= first.Y
        && second.CentreY <= first.Y + first.H
    )

    return centreClose || firstInsideSecond || secondInsideFirst
}


SortLocationsTopToBottom(items) {
    if (items.Length < 2)
        return

    Loop items.Length - 1 {
        pass := A_Index
        swapped := false

        Loop items.Length - pass {
            index := A_Index
            first := items[index]
            second := items[index + 1]

            shouldSwap := (
                first.CentreY > second.CentreY
                || (
                    Abs(first.CentreY - second.CentreY) <= 5
                    && first.CentreX > second.CentreX
                )
            )

            if shouldSwap {
                temporary := items[index]
                items[index] := items[index + 1]
                items[index + 1] := temporary
                swapped := true
            }
        }

        if !swapped
            break
    }
}


BuildLocationsMessage(items) {
    if (items.Length = 0)
        return "No visible Edit locations were recorded.`n"

    output := ""

    for index, item in items {
        output .= Format(
            '{1}. Name="{2}" | X={3}, Y={4}, W={5}, H={6} | centre={7},{8}`n',
            index,
            item.Name,
            item.X,
            item.Y,
            item.W,
            item.H,
            item.CentreX,
            item.CentreY
        )
    }

    return output
}


ShowLastLocations() {
    global LastEditButtons

    MsgBox(
        "Detected " LastEditButtons.Length " Edit control(s):`n`n"
        BuildLocationsMessage(LastEditButtons)
    )
}


DumpAccessibilityTree() {
    global LastDocument

    try {
        if !LastDocument {
            if (WinGetProcessName("A") != "chrome.exe") {
                MsgBox("Activate Chrome before pressing F9.")
                return
            }

            browser := UIA_Browser()
            LastDocument := browser.GetCurrentDocumentElement()
        }

        dumpDir := A_ScriptDir "\..\debug"

        if !DirExist(dumpDir)
            DirCreate(dumpDir)

        dumpPath := dumpDir "\go-b2b-accessibility-tree.txt"

        if FileExist(dumpPath)
            FileDelete(dumpPath)

        ToolTip("Creating accessibility-tree dump...")
        FileAppend(LastDocument.DumpAll(), dumpPath, "UTF-8")
        ToolTip()

        MsgBox(
            "Accessibility tree saved to:`n`n"
            dumpPath
            "`n`nSearch the file for the word Edit."
        )
    } catch as err {
        ToolTip()

        MsgBox(
            "The accessibility-tree dump failed.`n`n"
            "Error: " err.Message
        )
    }
}


ClearToolTip(*) {
    ToolTip()
}
