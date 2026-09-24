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

