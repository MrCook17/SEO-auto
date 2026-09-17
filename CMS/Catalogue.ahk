FindNextDepartmentCatalogueProduct(completedIdentity, departmentProductType) {
    global cmsWinTitle, departmentCatalogueTreeTimeoutMs
    deadline := A_TickCount + departmentCatalogueTreeTimeoutMs
    lastRowCount := 0
    lastTreeProblem := ""

    Loop {
        ToolTip "DEPARTMENT AUTOMATION RUNNING"
            . "`nReading the catalogue accessibility tree..."
            . "`nProduct type: " departmentProductType
            . "`nFinding the row after: " completedIdentity["productName"]
        try {
            ActivateWindow(cmsWinTitle, 250)
            document := UIA_Browser().GetCurrentDocumentElement()
            products := CollectDepartmentCatalogueProducts(document, departmentProductType)
            lastRowCount := products.Length
            currentIndex := FindCompletedDepartmentProductIndex(products, completedIdentity)
            if currentIndex {
                if currentIndex = products.Length
                    return Map("status", "end")
                return Map("status", "next", "product", products[currentIndex + 1])
            }
        } catch as err {
            lastTreeProblem := err.Message
        }

        if A_TickCount >= deadline
            throw Error(
                "Could not find the completed product in the current catalogue accessibility tree."
                . "`nCompleted product: " completedIdentity["productName"]
                . "`nCompleted code: " EmptyToNA(completedIdentity["productCode"])
                . "`nCatalogue " departmentProductType " rows detected: " lastRowCount
                . (lastTreeProblem != "" ? "`nLast accessibility error: " lastTreeProblem : "")
                . "`n`nThe next product was not opened."
            )
        Sleep 500
    }
}

CollectDepartmentCatalogueProducts(document, departmentProductType := "") {
    try {
        catalogueList := document.FindElement({ AutomationId: "catalogueNodeListView" })
        listItems := catalogueList.FindElements({ Type: "ListItem" })
    } catch
        return []

    products := []
    for _, listItem in listItems {
        if !InStr(StrLower(listItem.ClassName), "cms-catalogue-tile")
            continue
        rowText := listItem.Name
        ; Child-department links share the product tile class. Reference
        ; departments have no Edit suffix, so skip them by their type prefix.
        if IsCatalogueDepartmentTile(rowText)
            continue
        ; Reference links are handled by their own catalogue-search workflow.
        ; They can share the selected product type but have no Edit control.
        if IsCatalogueReferenceTile(rowText) {
            TestingLog("catalogue-reference-tile-skipped", NormaliseCatalogueTileText(rowText))
            continue
        }
        rowProductType := GetCatalogueTileProductTypePrefix(rowText)
        ; Only ordinary products of the selected type participate in the
        ; ordering. Keep strict parsing for those rows before opening one.
        if rowProductType = "" {
            TestingLog("catalogue-other-tile-skipped", NormaliseCatalogueTileText(rowText))
            continue
        }
        if departmentProductType != "" && StrLower(rowProductType) != StrLower(departmentProductType)
            continue

        identity := ParseDepartmentCatalogueTileIdentity(rowText)
        if !identity {
            ; GO b2b also marks reference links with a dedicated child class.
            ; Use it when the accessible name has an unfamiliar format.
            if HasCatalogueReferenceMarker(listItem) {
                TestingLog("catalogue-reference-tile-skipped", NormaliseCatalogueTileText(rowText))
                continue
            }
            throw Error("A catalogue product tile could not be parsed safely: " rowText)
        }
        ; Department runs operate on one product class only. Matrix modes use
        ; Matrix Product parents; ordinary and BOTZ modes use Simple Products.
        ; Filtering before next-row selection makes interleaved Matrix SKU rows
        ; invisible to the run instead of opening and trying to optimise them.
        if departmentProductType != "" && StrLower(identity["productType"]) != StrLower(departmentProductType)
            continue
        editLink := FindCatalogueTileEditControl(listItem)
        if !editLink
            throw Error("A catalogue product tile has no usable Edit control: " identity["rowText"])
        identity["rowElement"] := listItem
        identity["editElement"] := editLink
        products.Push(identity)
    }
    return products
}

NormaliseCatalogueTileText(rowText) {
    text := RegExReplace(rowText, "[\x{E000}-\x{F8FF}]", " ")
    return RegExReplace(Trim(text), "[\r\n\t ]+", " ")
}

GetCatalogueTileProductTypePrefix(rowText) {
    text := NormaliseCatalogueTileText(rowText)
    if RegExMatch(text, "i)^(Simple Product|Matrix SKU|Matrix Product)\b", &match)
        return match[1]
    return ""
}

IsCatalogueReferenceTile(rowText) {
    text := NormaliseCatalogueTileText(rowText)
    return RegExMatch(text, "i)^(?:Simple Product|Matrix SKU|Matrix Product)\s+\(Reference\)(?:\s|$)") || RegExMatch(text, "i)^Matrix SKU\s+Reference(?:\s|$)")
}

HasCatalogueReferenceMarker(listItem) {
    try return listItem.FindElements({ ClassName: "cms-catalogue-tile-reference" }).Length > 0
    catch
        return false
}

IsCatalogueDepartmentTile(rowText) {
    text := NormaliseCatalogueTileText(rowText)
    return RegExMatch(text, "i)^Department\s+\S")
}

ParseDepartmentCatalogueTileIdentity(rowText) {
    text := NormaliseCatalogueTileText(rowText)
    if !RegExMatch(text, "i)^(Simple Product|Matrix SKU|Matrix Product)\s+(.+?)\s+Edit$", &match)
        return 0

    productType := match[1]
    body := Trim(match[2])
    productCode := ""
    productName := body
    if StrLower(productType) != "matrix product" {
        if !RegExMatch(body, "^(.+\S)\s+(\S+)$", &identityMatch)
            return 0
        productName := Trim(identityMatch[1])
        productCode := Trim(identityMatch[2])
    }
    if productName = ""
        return 0
    return Map(
        "productType", productType,
        "productName", productName,
        "productCode", productCode,
        "rowText", text
    )
}

FindCatalogueTileEditControl(listItem) {
    try editControls := listItem.FindElements({ Name: "Edit", mm: 2, cs: 0 })
    catch
        return 0
    for _, editControl in editControls {
        try {
            if StrLower(Trim(editControl.Name)) = "edit" && editControl.IsEnabled
                return editControl
        }
    }
    return 0
}

FindCompletedDepartmentProductIndex(products, completedIdentity) {
    matches := []
    for index, product in products {
        if DepartmentCatalogueIdentityMatches(product, completedIdentity)
            matches.Push(index)
    }
    if matches.Length > 1
        throw Error("More than one catalogue row matched the completed product, so choosing the next product would be unsafe.")
    return matches.Length = 1 ? matches[1] : 0
}

DepartmentCatalogueIdentityMatches(catalogueProduct, completedIdentity) {
    catalogueType := catalogueProduct.Has("productType") ? StrLower(Trim(catalogueProduct["productType"])) : ""
    completedType := completedIdentity.Has("productType") ? StrLower(Trim(completedIdentity["productType"])) : ""
    if catalogueType = "matrix product" || completedType = "matrix product"
        return NormaliseCatalogueProductName(catalogueProduct["productName"])
            = NormaliseCatalogueProductName(completedIdentity["productName"])

    completedCode := CleanText(completedIdentity["productCode"])
    catalogueCode := CleanText(catalogueProduct["productCode"])
    if completedCode != "" && catalogueCode != ""
        return StrLower(completedCode) = StrLower(catalogueCode)
    return NormaliseCatalogueProductName(catalogueProduct["productName"])
        = NormaliseCatalogueProductName(completedIdentity["productName"])
}

OpenAndVerifyNextDepartmentProduct(product, productNumber) {
    global cmsWinTitle, departmentProductOpenDelayMs, departmentCatalogueTreeTimeoutMs
    ToolTip "DEPARTMENT AUTOMATION RUNNING"
        . "`nOpening product " productNumber ": " product["productName"]
        . "`nCode: " EmptyToNA(product["productCode"])
        . "`nCtrl+Numpad6: stop after this product"

    ; Accessibility is used only to identify and, if necessary, expose the
    ; correct row. The Edit button itself is always pressed with a real mouse
    ; move/click; UIA Invoke/Click is deliberately not used here.
    try {
        if product["editElement"].IsOffscreen {
            product["rowElement"].ScrollIntoView()
            Sleep 1000
        }

        ; Scrolling can rebuild the Kendo list and stale the original element.
        ; Reacquire the matching row, then use only its current rectangle.
        document := UIA_Browser().GetCurrentDocumentElement()
        liveProducts := CollectDepartmentCatalogueProducts(document, product["productType"])
        liveIndex := FindCompletedDepartmentProductIndex(liveProducts, product)
        if !liveIndex
            throw Error("The matching catalogue row disappeared before its physical click.")
        liveProduct := liveProducts[liveIndex]
        if liveProduct["editElement"].IsOffscreen
            throw Error("The matching Edit button remained off-screen after scrolling.")
        rect := liveProduct["editElement"].Location
        if rect.w <= 0 || rect.h <= 0 || rect.x < 0 || rect.y < 0
            throw Error("The live Edit button has no usable screen rectangle.")
        editX := Round(rect.x + rect.w / 2)
        editY := Round(rect.y + rect.h / 2)
        MouseMove editX, editY, 0
        Sleep 200
        Click editX, editY
        Sleep 750
    } catch as clickError {
        throw Error("Could not physically click the next catalogue Edit button.`n" clickError.Message)
    }

    Sleep departmentProductOpenDelayMs
    expectedIdentity := Map("productType", product["productType"], "productName", product["productName"], "productCode", product["productCode"])
    deadline := A_TickCount + departmentCatalogueTreeTimeoutMs
    lastOpenedIdentity := 0
    Loop {
        try {
            actualIdentity := ReadOpenCmsProductIdentity()
            lastOpenedIdentity := actualIdentity
            if DepartmentCatalogueIdentityMatches(expectedIdentity, actualIdentity)
                return actualIdentity
        }
        if A_TickCount >= deadline
            break
        ToolTip "DEPARTMENT AUTOMATION RUNNING"
            . "`nWaiting for product " productNumber " Overview to become ready..."
            . "`nExpected: " product["productName"]
        Sleep 500
    }

    openedText := lastOpenedIdentity
        ? lastOpenedIdentity["productName"] " (" EmptyToNA(lastOpenedIdentity["productCode"]) ")"
        : "The Overview fields could not be read."
    throw Error(
        "The next Edit control did not open the expected product."
        . "`nExpected: " product["productName"] " (" EmptyToNA(product["productCode"]) ")"
        . "`nOpened: " openedText
    )
}

NormaliseCatalogueProductName(value) {
    value := StrReplace(value, Chr(160), " ")
    value := StrReplace(value, "–", "-")
    value := StrReplace(value, "—", "-")
    value := RegExReplace(Trim(value), "\s+", " ")
    ; GO b2b inconsistently exposes spaces around hyphens between the Product
    ; Name field and its catalogue tile (for example "Fuchsia - Dry" versus
    ; "Fuchsia- Dry"). Treat that presentation-only spacing as equivalent.
    value := RegExReplace(value, "\s*-\s*", "-")
    return StrLower(value)
}

