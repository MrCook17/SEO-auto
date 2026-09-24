ReacquireAndValidateMatrixOrder(products) {
    controls := ReacquireMatrixSkuControls(products.Length)
    Loop products.Length {
        rowText := NormaliseMatrixRowText(controls["buttons"][A_Index].RowText)
        currentName := ExtractMatrixProductNameFromRow(rowText, A_Index)
        if NormaliseHarmlessWhitespace(currentName) != NormaliseHarmlessWhitespace(products[A_Index]["productName"])
            throw Error("Matrix SKU order changed at product " A_Index ". Expected '" products[A_Index]["productName"] "', detected '" currentName "'.")
    }
    return controls
}

ReacquireMatrixSkuControls(expectedCount := 0) {
    global matrixUiaSearchTimeoutMs, matrixStableDurationMs, matrixSkuTabSettleDelayMs
    global LastDocument, LastEditButtons
    lastProblem := ""
    try {
        Loop 2 {
            attempt := A_Index
            ShowMatrixLookupStatus("Reading Chrome accessibility tree...`nAttempt " attempt " of 2")
            try {
                result := WaitForMatrixModalScope(matrixUiaSearchTimeoutMs)
                document := result["document"]
                scope := result["scope"]
                LastDocument := document
                if !scope
                    throw Error("No stable matrix SKU rows became available within " matrixUiaSearchTimeoutMs " ms.")

                ShowMatrixLookupStatus("Collecting all SKU rows while scrolling...`nAttempt " attempt " of 2")
                buttons := CollectAllMatrixSkuButtons(scope)
                LastEditButtons := buttons
                if buttons.Length = 0
                    throw Error("The matrix scope appeared, but its child Edit controls had not finished rebuilding.")
                if expectedCount && buttons.Length != expectedCount
                    throw Error("Matrix child count is not stable: expected " expectedCount ", detected " buttons.Length ".")
                return Map("document", document, "scope", scope, "buttons", buttons)
            } catch as err {
                lastProblem := err.Message
                LastDocument := 0
                LastEditButtons := []
            }

            if attempt = 1 {
                ShowMatrixLookupStatus("Matrix SKU page was not stable yet.`nWaiting five seconds before retrying...")
                Sleep matrixSkuTabSettleDelayMs
            }
        }
        throw Error(
            "Matrix child controls were still unavailable after two stable-tree attempts."
            . (lastProblem != "" ? "`nLast problem: " lastProblem : "")
            . "`nPress F9 for an accessibility-tree dump."
        )
    } finally {
        ToolTip()
    }
}

FindMatrixModalScope(document) {
    try titleElement := document.FindElement({ Name: "Editing Matrix Product:", mm: 2, cs: 0 })
    catch
        return 0
    try {
        if titleElement.IsOffscreen
            return 0
    }
    scope := titleElement
    Loop 15 {
        ; During loading Chrome can expose Edit elements before their screen
        ; rectangles are stable, so modal discovery must not require visibility.
        if ScopeContainsAnyEditElement(scope)
            return scope
        try parent := UIA.TreeWalkerTrue.GetParentElement(scope)
        catch
            break
        if !parent
            break
        scope := parent
    }
    return 0
}

ScopeContainsAnyEditElement(scope) {
    try elements := scope.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return false
    for _, element in elements {
        try {
            if RegExMatch(element.Name, "i)(^|[^A-Za-z])Edit([^A-Za-z]|$)")
                return true
        }
    }
    return false
}

RejectPotentiallyIncompleteMatrix(scope) {
    try elements := scope.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return
    for _, element in elements {
        try {
            if RegExMatch(element.Name, "i)(^|[^A-Za-z])Edit([^A-Za-z]|$)") && element.IsOffscreen
                throw Error("The matrix exposes off-screen Edit controls, so the complete scrollable list cannot be mapped safely. Expand or scroll the list until all children are exposed, then retry.")
        }
    }
}

WaitForStableEditLocations(scope, timeoutMs, stableDurationMs) {
    deadline := A_TickCount + timeoutMs, best := [], prior := "", stableSince := 0
    Loop {
        ShowMatrixLookupStatus("Scanning Edit buttons...`nBest count so far: " best.Length)
        current := GetUniqueVisibleEditLocations(scope)
        if current.Length > best.Length
            best := current
        signature := BuildLocationSignature(current)
        if current.Length && signature = prior {
            if !stableSince
                stableSince := A_TickCount
            if A_TickCount - stableSince >= stableDurationMs
                return current
        } else {
            prior := signature, stableSince := A_TickCount
        }
        if A_TickCount >= deadline
            return best
        Sleep 250
    }
}

GetUniqueVisibleEditLocations(scope) {
    candidates := [], unique := [], hasExactEditNames := false, hasSkuRows := false
    try elements := scope.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return unique
    for _, element in elements {
        try {
            if !RegExMatch(element.Name, "i)(^|[^A-Za-z])Edit([^A-Za-z]|$)") || element.IsOffscreen
                continue
            rect := element.Location
            if rect.w <= 0 || rect.h <= 0 || rect.x < 0 || rect.y < 0
                continue
            ; Retain only screen geometry and row text. UIA element references
            ; can become stale immediately after Chrome starts navigating.
            exactEditName := StrLower(Trim(element.Name)) = "edit"
            if exactEditName
                hasExactEditNames := true
            rowText := GetEditRowContext(element)
            isSkuRow := RegExMatch(rowText, "i)\bName\b") && RegExMatch(rowText, "i)\bStock\s*Code\b|\bStockCode\b")
            if isSkuRow
                hasSkuRows := true
            connectedSize := isSkuRow ? FindConnectedMatrixSkuSizeByGeometry(scope, element) : ""
            if connectedSize != "" && ExtractConnectedMatrixSkuSize(rowText) = "Not separately exposed in the SKU accessibility row"
                rowText := connectedSize " " rowText
            item := { Name: element.Name, ExactEditName: exactEditName, IsSkuRow: isSkuRow, ConnectedSize: connectedSize, ControlType: GetUiaControlTypeText(element), X: Round(rect.x), Y: Round(rect.y), W: Round(rect.w), H: Round(rect.h), CentreX: Round(rect.x + rect.w / 2), CentreY: Round(rect.y + rect.h / 2), RowText: rowText }
            candidates.Push(item)
        }
    }

    ; Chrome often exposes both the visible Edit control and a larger parent
    ; whose accessible name merely contains "Edit". When exact-name elements
    ; exist, ignore the broad named containers: their rectangle centres can be
    ; well outside the visible green button.
    for _, item in candidates {
        if hasSkuRows && !item.IsSkuRow
            continue
        if hasExactEditNames && !item.ExactEditName
            continue
        duplicate := 0
        for index, saved in unique {
            if LocationsRepresentSameControl(item, saved) {
                duplicate := index
                break
            }
        }
        if !duplicate
            unique.Push(item)
        ; For overlapping exact Edit elements, the smaller rectangle is
        ; normally the visible text/control and has the safest click centre.
        else if IsBetterEditLocation(item, unique[duplicate])
            unique[duplicate] := item
    }
    SortLocationsTopToBottom(unique)
    return unique
}

FindConnectedMatrixSkuSizeByGeometry(scope, editElement) {
    cardRect := 0
    node := editElement
    Loop 8 {
        try node := UIA.TreeWalkerTrue.GetParentElement(node)
        catch
            break
        if !node
            break
        try nodeName := NormaliseMatrixRowText(node.Name)
        catch
            continue
        if !RegExMatch(nodeName, "i)\bName\b") || !RegExMatch(nodeName, "i)\bStock\s*Code\b|\bStockCode\b")
            continue
        try rect := node.Location
        catch
            continue
        if rect.w > 0 && rect.h > 0 {
            cardRect := rect
            break
        }
    }
    if !cardRect
        return ""

    candidates := []
    for _, typeName in ["Text", "DataItem", "Custom"] {
        try elements := scope.FindElements({ Type: typeName })
        catch
            continue
        for _, element in elements {
            try {
                if element.IsOffscreen
                    continue
                name := NormaliseMatrixRowText(element.Name)
                if !IsPlausibleConnectedSkuSize(name)
                    continue
                rect := element.Location
                if rect.w <= 0 || rect.h <= 0
                    continue
                centreX := rect.x + rect.w / 2
                centreY := rect.y + rect.h / 2
                ; The size must sit to the left of the Name/StockCode card and
                ; vertically inside that exact card's row.
                if centreX >= cardRect.x + 3
                    continue
                if centreY < cardRect.y - 3 || centreY > cardRect.y + cardRect.h + 3
                    continue
                distance := Abs(cardRect.x - (rect.x + rect.w))
                candidates.Push({ Name: name, Distance: distance, X: rect.x })
            }
        }
    }
    if candidates.Length = 0
        return ""

    best := candidates[1]
    for _, candidate in candidates {
        if candidate.Distance < best.Distance
            best := candidate
    }
    return best.Name
}

GetEditRowContext(element) {
    node := element, best := ""
    Loop 8 {
        try node := UIA.TreeWalkerTrue.GetParentElement(node)
        catch
            break
        if !node
            break
        try name := Trim(node.Name)
        catch
            continue
        if name = "" || InStr(name, "Editing Matrix Product:") || RegExMatch(name, "i)^Edit$")
            continue
        cleanedName := RegExReplace(name, "[\r\n\t]+", " ")
        ; The nearest ancestor containing the row's Name and StockCode is the
        ; SKU record. Return it immediately instead of continuing upwards into
        ; the whole SKU table or matrix modal.
        if RegExMatch(cleanedName, "i)\bName\b") && RegExMatch(cleanedName, "i)\bStock\s*Code\b|\bStockCode\b")
            return ExpandMatrixSkuRowContext(node, cleanedName)
        if best = ""
            best := cleanedName
    }
    return best
}

ExpandMatrixSkuRowContext(skuNode, baseText) {
    ; The nearest named ancestor normally represents the right-hand SKU card
    ; (Name/StockCode/Edit), while its parent row also contains the connected
    ; left-hand Size cell. Walk only a few levels and accept a broader name
    ; only while it still contains exactly one SKU identity. This prevents a
    ; table containing several SKUs from being mistaken for one product row.
    best := RegExReplace(baseText, "[\r\n\t]+", " ")
    node := skuNode
    Loop 4 {
        try node := UIA.TreeWalkerTrue.GetParentElement(node)
        catch
            break
        if !node
            break
        try candidate := RegExReplace(Trim(node.Name), "[\r\n\t]+", " ")
        catch
            continue
        if candidate = "" || InStr(candidate, "Editing Matrix Product:")
            continue
        if CountMatrixSkuIdentities(candidate) != 1
            continue
        if GetMatrixSkuRowKey(candidate) != GetMatrixSkuRowKey(best)
            continue
        ; Prefer the first single-SKU ancestor that adds text before "Name";
        ; that prefix is the connected Size/Colour/Variant cell.
        if RegExMatch(candidate, "i)^(.+?)\s+Name\s*:?", &prefixMatch) {
            prefix := Trim(prefixMatch[1])
            prefix := Trim(RegExReplace(prefix, "i)^(Size|Colour|Color|Variant)\s*:?\s*", ""))
            if prefix != "" {
                best := candidate
                break
            }
        }
    }
    return best
}

CollectAllMatrixSkuButtons(scope) {
    global matrixUiaSearchTimeoutMs, matrixStableDurationMs
    global matrixMaxScrollSteps, matrixNoNewRowsStopCount

    firstView := WaitForStableEditLocations(scope, matrixUiaSearchTimeoutMs, matrixStableDurationMs)
    if firstView.Length = 0
        return []

    anchorX := firstView[1].CentreX
    anchorY := firstView[1].CentreY

    ; Small matrices expose every SKU at once and have no internal scrollbar.
    ; Sending wheel input there can scroll the surrounding page or move the
    ; pointer away from the modal, so return the visible set without scrolling.
    if !MatrixScopeHasOffscreenSkuEdits(scope) {
        for _, item in firstView {
            key := GetMatrixSkuRowKey(item.RowText)
            if key = ""
                throw Error("A visible matrix SKU row has no usable StockCode or product-name identity.")
            item.RowKey := key
            item.RequiresScroll := false
            item.ScrollSteps := 0
            item.ScrollAnchorX := anchorX
            item.ScrollAnchorY := anchorY
        }
        return firstView
    }

    ScrollMatrixSkuListToTop(anchorX, anchorY)

    collected := [], seen := Map(), noNewCount := 0
    Loop matrixMaxScrollSteps + 1 {
        scrollStep := A_Index - 1
        ShowMatrixLookupStatus("Scanning matrix SKU list...`nProducts found: " collected.Length "`nScroll step: " scrollStep)
        current := WaitForStableEditLocations(scope, matrixUiaSearchTimeoutMs, 350)
        newCount := 0
        for _, item in current {
            key := GetMatrixSkuRowKey(item.RowText)
            if key = "" || seen.Has(key)
                continue
            item.RowKey := key
            item.RequiresScroll := true
            item.ScrollSteps := scrollStep
            item.ScrollAnchorX := anchorX
            item.ScrollAnchorY := anchorY
            seen[key] := true
            collected.Push(item)
            newCount += 1
        }

        if newCount = 0
            noNewCount += 1
        else
            noNewCount := 0

        if noNewCount >= matrixNoNewRowsStopCount
            break

        ScrollMatrixSkuListDownOneStep(anchorX, anchorY)
    }

    ScrollMatrixSkuListToTop(anchorX, anchorY)
    return collected
}

MatrixScopeHasOffscreenSkuEdits(scope) {
    try elements := scope.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return false
    for _, element in elements {
        try {
            if !element.IsOffscreen
                continue
            rowText := NormaliseMatrixRowText(GetEditRowContext(element))
            if RegExMatch(rowText, "i)\bName\b") && RegExMatch(rowText, "i)\bStock\s*Code\b|\bStockCode\b")
                return true
        }
    }
    return false
}

ScrollMatrixSkuListToTop(anchorX, anchorY) {
    MouseMove anchorX, anchorY, 0
    ; A large bounded wheel-up sequence reliably resets the internal SKU pane
    ; without depending on a fixed scrollbar coordinate.
    SendNativeMouseWheel(1, 60)
    Sleep 700
}

ScrollMatrixSkuListDownOneStep(anchorX, anchorY) {
    global matrixScrollWheelNotchesPerStep
    MouseMove anchorX, anchorY, 0
    SendNativeMouseWheel(-1, matrixScrollWheelNotchesPerStep)
    Sleep 650
}

FindCurrentMatrixSkuButton(item) {
    global matrixMaxScrollSteps
    anchorX := item.ScrollAnchorX, anchorY := item.ScrollAnchorY
    targetKey := item.RowKey

    if item.HasOwnProp("RequiresScroll") && !item.RequiresScroll {
        document := UIA_Browser().GetCurrentDocumentElement()
        scope := FindMatrixModalScope(document)
        if !scope && HasVisibleMatrixSkuRows(document)
            scope := document
        if scope {
            for _, candidate in GetUniqueVisibleEditLocations(scope) {
                if GetMatrixSkuRowKey(candidate.RowText) = targetKey
                    return candidate
            }
        }
        throw Error("Visible matrix SKU '" targetKey "' could not be located without scrolling.")
    }

    ScrollMatrixSkuListToTop(anchorX, anchorY)

    Loop matrixMaxScrollSteps + 1 {
        ShowMatrixLookupStatus("Locating " targetKey "...`nScroll step: " (A_Index - 1))
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            scope := FindMatrixModalScope(document)
            if !scope && HasVisibleMatrixSkuRows(document)
                scope := document
            if scope {
                visibleButtons := GetUniqueVisibleEditLocations(scope)
                for _, candidate in visibleButtons {
                    if GetMatrixSkuRowKey(candidate.RowText) = targetKey {
                        ToolTip()
                        return candidate
                    }
                }
            }
        }
        if A_Index <= matrixMaxScrollSteps
            ScrollMatrixSkuListDownOneStep(anchorX, anchorY)
    }
    ToolTip()
    throw Error("Could not bring matrix SKU '" targetKey "' into view for clicking.")
}

WaitForMatrixModalScope(timeoutMs) {
    global matrixStableDurationMs
    deadline := A_TickCount + timeoutMs
    priorSignature := ""
    stableSince := 0
    Loop {
        ShowMatrixLookupStatus("Waiting for stable matrix SKU rows...")
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            scope := FindMatrixModalScope(document)
            headingFound := !!scope
            ; Chrome does not always expose the modal heading. A visible Edit
            ; control whose nearest row contains both Name and StockCode is a
            ; stronger SKU-specific fallback than searching generic page text.
            if !scope && HasVisibleMatrixSkuRows(document)
                scope := document

            if scope && HasVisibleMatrixSkuRows(scope) {
                visibleButtons := GetUniqueVisibleEditLocations(scope)
                signature := BuildLocationSignature(visibleButtons)
                if visibleButtons.Length && signature = priorSignature {
                    if stableSince && A_TickCount - stableSince >= matrixStableDurationMs
                        return Map("document", document, "scope", scope, "headingFound", headingFound)
                } else if visibleButtons.Length {
                    priorSignature := signature
                    stableSince := A_TickCount
                } else {
                    priorSignature := ""
                    stableSince := 0
                }
            } else {
                priorSignature := ""
                stableSince := 0
            }
        } catch {
            priorSignature := ""
            stableSince := 0
        }
        if A_TickCount >= deadline
            return Map("document", 0, "scope", 0, "headingFound", false)
        Sleep 250
    }
}

HasVisibleMatrixSkuRows(scope) {
    try elements := scope.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return false
    for _, element in elements {
        try {
            if element.IsOffscreen
                continue
            rowText := NormaliseMatrixRowText(GetEditRowContext(element))
            if RegExMatch(rowText, "i)\bName\b") && RegExMatch(rowText, "i)\bStock\s*Code\b|\bStockCode\b")
                return true
        }
    }
    return false
}

LocationsRepresentSameControl(a, b) {
    return (Abs(a.CentreX - b.CentreX) <= 18 && Abs(a.CentreY - b.CentreY) <= 18) || (a.CentreX >= b.X && a.CentreX <= b.X + b.W && a.CentreY >= b.Y && a.CentreY <= b.Y + b.H) || (b.CentreX >= a.X && b.CentreX <= a.X + a.W && b.CentreY >= a.Y && b.CentreY <= a.Y + a.H)
}

SortLocationsTopToBottom(items) {
    if items.Length < 2
        return
    Loop items.Length - 1 {
        swapped := false
        Loop items.Length - A_Index {
            i := A_Index, a := items[i], b := items[i + 1]
            if a.CentreY > b.CentreY || (Abs(a.CentreY - b.CentreY) <= 5 && a.CentreX > b.CentreX) {
                items[i] := b, items[i + 1] := a, swapped := true
            }
        }
        if !swapped
            break
    }
}

BuildLocationSignature(items) {
    signature := items.Length "|"
    for _, item in items
        signature .= item.X "," item.Y "," item.W "," item.H ";"
    return signature
}

ClickMatrixEditButton(item) {
    ; For a small, fully visible matrix, ReacquireMatrixSkuControls has already
    ; produced a stable live rectangle in this exact parent-menu instance. Use
    ; it directly instead of building a second accessibility tree before the
    ; click. Large scrolling matrices still need to reveal the saved row first.
    ToolTip()
    CoordMode "Mouse", "Screen"
    currentItem := item
    if item.HasOwnProp("RowKey") && (!item.HasOwnProp("RequiresScroll") || item.RequiresScroll)
        currentItem := FindCurrentMatrixSkuButton(item)
    MouseMove currentItem.CentreX, currentItem.CentreY, 0
    Sleep 150
    Click currentItem.CentreX, currentItem.CentreY
    Sleep 750
}

IsBetterEditLocation(candidate, saved) {
    if candidate.ExactEditName != saved.ExactEditName
        return candidate.ExactEditName
    return candidate.W * candidate.H < saved.W * saved.H
}

IsMatrixModalPresent(document) {
    try {
        heading := document.FindElement({ Name: "Editing Matrix Product:", mm: 2, cs: 0 })
        return !!heading
    } catch {
        return false
    }
}

