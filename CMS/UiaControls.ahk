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

GetUiaControlTypeText(element) {
    try return element.LocalizedControlType
    catch
        return "unknown"
}

