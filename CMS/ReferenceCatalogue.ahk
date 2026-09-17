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

