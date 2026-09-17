SaveBotzState(state) {
    global botzStateFilePath
    text := "CROMARTIE_BOTZ_STATE_V3`n"
    text .= "product_name`t" EncodeStateValue(state["productName"]) "`n"
    text .= "stock_code`t" EncodeStateValue(state["stockCode"]) "`n"
    text .= "match_code`t" state["matchCode"] "`n"
    text .= "folder`t" EncodeStateValue(state["productFolder"]) "`n"
    text .= "product_md`t" EncodeStateValue(state["productMdPath"]) "`n"
    text .= "product_md_size`t" state["productMdSize"] "`n"
    text .= "product_md_modified`t" state["productMdModified"] "`n"
    text .= "initial_gallery_count`t" state["initialGalleryCount"] "`n"
    text .= "uploaded_count`t" state["uploadedCount"] "`n"
    text .= "pending_image`t" state["pendingImageIndex"] "`n"
    text .= "image_count`t" state["imageCount"] "`n"
    for index, imagePath in state["images"] {
        manifestItem := state["imageManifest"][index]
        text .= "image`t" index "`t" EncodeStateValue(imagePath) "`t" manifestItem["size"] "`t" manifestItem["modified"] "`n"
    }
    if FileExist(botzStateFilePath)
        FileDelete botzStateFilePath
    FileAppend text, botzStateFilePath, "UTF-8"
}

LoadBotzState() {
    global botzStateFilePath, botzState, maximumImagesPerProduct
    if botzState
        return botzState
    if !FileExist(botzStateFilePath)
        throw Error("No saved BOTZ run exists. Build the BOTZ prompt with Numpad4 first.")

    lines := StrSplit(StrReplace(FileRead(botzStateFilePath, "UTF-8"), "`r", ""), "`n")
    if lines.Length < 10 || (lines[1] != "CROMARTIE_BOTZ_STATE_V2" && lines[1] != "CROMARTIE_BOTZ_STATE_V3")
        throw Error("The saved BOTZ state file is invalid or unsupported.")
    stateVersion := lines[1]

    values := Map(), images := [], imageManifest := []
    Loop lines.Length - 1 {
        line := lines[A_Index + 1]
        if line = ""
            continue
        parts := StrSplit(line, "`t")
        if parts[1] = "image" {
            if parts.Length != 5 || !IsInteger(parts[2]) || Integer(parts[2]) != images.Length + 1 || !IsInteger(parts[4])
                throw Error("The saved BOTZ image order is invalid.")
            imagePath := DecodeStateValue(parts[3])
            images.Push(imagePath)
            imageManifest.Push(Map("path", imagePath, "size", Integer(parts[4]), "modified", parts[5]))
        } else {
            if parts.Length != 2
                throw Error("The saved BOTZ state contains an invalid record: " line)
            values[parts[1]] := parts[2]
        }
    }

    required := ["product_name", "stock_code", "match_code", "folder", "product_md", "product_md_size", "product_md_modified", "initial_gallery_count", "image_count"]
    for _, key in required {
        if !values.Has(key)
            throw Error("The saved BOTZ state is missing: " key ".")
    }
    if !IsInteger(values["image_count"]) || Integer(values["image_count"]) < 1 || Integer(values["image_count"]) != images.Length
        throw Error("The saved BOTZ image count is invalid.")
    if Integer(values["image_count"]) > maximumImagesPerProduct
        throw Error("The saved BOTZ image count exceeds the GO b2b limit of " maximumImagesPerProduct ". Rebuild the BOTZ prompt to select only the first " maximumImagesPerProduct " images.")
    if stateVersion = "CROMARTIE_BOTZ_STATE_V3" {
        for _, key in ["uploaded_count", "pending_image"] {
            if !values.Has(key) || !IsInteger(values[key])
                throw Error("The saved BOTZ state has invalid or missing progress: " key ".")
        }
    }
    uploadedCount := stateVersion = "CROMARTIE_BOTZ_STATE_V3" && values.Has("uploaded_count") && IsInteger(values["uploaded_count"])
        ? Integer(values["uploaded_count"])
        : 0
    pendingImageIndex := stateVersion = "CROMARTIE_BOTZ_STATE_V3" && values.Has("pending_image") && IsInteger(values["pending_image"])
        ? Integer(values["pending_image"])
        : 0
    if uploadedCount < 0 || uploadedCount > Integer(values["image_count"])
        throw Error("The saved BOTZ uploaded-image progress is invalid.")
    if pendingImageIndex < 0 || pendingImageIndex > Integer(values["image_count"])
        throw Error("The saved BOTZ pending-image progress is invalid.")

    botzState := Map(
        "mode", "botz",
        "productName", DecodeStateValue(values["product_name"]),
        "stockCode", DecodeStateValue(values["stock_code"]),
        "matchCode", values["match_code"],
        "productFolder", DecodeStateValue(values["folder"]),
        "productMdPath", DecodeStateValue(values["product_md"]),
        "productMdSize", Integer(values["product_md_size"]),
        "productMdModified", values["product_md_modified"],
        "initialGalleryCount", Integer(values["initial_gallery_count"]),
        "uploadedCount", uploadedCount,
        "pendingImageIndex", pendingImageIndex,
        "imageCount", Integer(values["image_count"]),
        "images", images,
        "imageManifest", imageManifest
    )
    return botzState
}

SaveMatrixState(state) {
    global matrixStateFilePath, matrixFullStateFilePath
    mode := state.Has("mode") ? state["mode"] : "matrix_image"
    if mode != "matrix_image" && mode != "matrix_full"
        throw Error("Cannot save unsupported matrix state mode '" mode "'.")
    filePath := mode = "matrix_full" ? matrixFullStateFilePath : matrixStateFilePath
    text := mode = "matrix_full" ? "CROMARTIE_MATRIX_FULL_STATE_V3`nmode`tmatrix_full`n" : "CROMARTIE_MATRIX_STATE_V3`n"
    text .= "parent`t" EncodeStateValue(state["parentProductName"]) "`n"
    text .= "count`t" state["productCount"] "`nparent_images`t" state["parentImageCount"] "`n"
    for _, product in state["products"] {
        connectedSize := product.Has("connectedSize") ? product["connectedSize"] : ExtractConnectedMatrixSkuSize(product["skuRowText"])
        text .= "product`t" product["index"] "`t" product["imageCount"] "`t" EncodeStateValue(product["productName"]) "`t" EncodeStateValue(connectedSize) "`t" EncodeStateValue(product["variantContext"]) "`t" EncodeStateValue(product["skuRowText"])
        if mode = "matrix_full"
            text .= "`t" EncodeStateValue(product["originalHtmlSnippet"])
        text .= "`n"
    }
    if FileExist(filePath)
        FileDelete filePath
    FileAppend text, filePath, "UTF-8"
}

LoadMatrixState(requestedMode := "") {
    global matrixStateFilePath, matrixFullStateFilePath, matrixState, matrixFullState
    mode := requestedMode != "" ? StrLower(Trim(requestedMode)) : (IsMatrixFullMode() ? "matrix_full" : "matrix_image")
    if mode != "matrix_image" && mode != "matrix_full"
        throw Error("Unsupported matrix state mode '" mode "'.")
    if mode = "matrix_full" && matrixFullState
        return matrixFullState
    if mode = "matrix_image" && matrixState
        return matrixState
    filePath := mode = "matrix_full" ? matrixFullStateFilePath : matrixStateFilePath
    expectedHeader := mode = "matrix_full" ? "CROMARTIE_MATRIX_FULL_STATE_V3" : "CROMARTIE_MATRIX_STATE_V3"
    if !FileExist(filePath)
        throw Error("No saved " mode " state exists. Build its matrix prompt with Numpad4 first.")
    lines := StrSplit(StrReplace(FileRead(filePath, "UTF-8"), "`r", ""), "`n")
    if lines.Length < 4 || lines[1] != expectedHeader
        throw Error("The saved matrix state file is invalid or unsupported.")
    products := [], parent := "", count := 0, parentImages := 0
    Loop lines.Length - 1 {
        line := lines[A_Index + 1]
        if line = ""
            continue
        parts := StrSplit(line, "`t")
        switch parts[1] {
            case "mode":
                if parts.Length != 2 || parts[2] != mode
                    throw Error("The saved matrix state mode does not match " mode ".")
            case "parent": parent := DecodeStateValue(parts[2])
            case "count": count := Integer(parts[2])
            case "parent_images": parentImages := Integer(parts[2])
            case "product":
                expectedParts := mode = "matrix_full" ? 8 : 7
                if parts.Length != expectedParts
                    throw Error("A product record in the matrix state file is invalid.")
                product := Map("index", Integer(parts[2]), "imageCount", Integer(parts[3]), "productName", DecodeStateValue(parts[4]), "connectedSize", DecodeStateValue(parts[5]), "variantContext", DecodeStateValue(parts[6]), "skuRowText", DecodeStateValue(parts[7]))
                if mode = "matrix_full"
                    product["originalHtmlSnippet"] := DecodeStateValue(parts[8])
                products.Push(product)
        }
    }
    if parent = "" || count < 1 || parentImages < 0 || products.Length != count
        throw Error("The saved matrix state is incomplete.")
    Loop count {
        if products[A_Index]["index"] != A_Index || products[A_Index]["productName"] = "" || products[A_Index]["imageCount"] < 0
            throw Error("The saved matrix product order is invalid.")
    }
    loaded := Map("mode", mode, "parentProductName", parent, "productCount", count, "parentImageCount", parentImages, "products", products)
    if mode = "matrix_full"
        matrixFullState := loaded
    else
        matrixState := loaded
    return loaded
}

EncodeStateValue(value) {
    value := StrReplace(value, "%", "%25")
    value := StrReplace(value, "`t", "%09")
    value := StrReplace(value, "`r", "%0D")
    return StrReplace(value, "`n", "%0A")
}

DecodeStateValue(value) {
    value := StrReplace(value, "%0A", "`n")
    value := StrReplace(value, "%0D", "`r")
    value := StrReplace(value, "%09", "`t")
    return StrReplace(value, "%25", "%")
}

GetMatrixTotalImageCount(state) {
    total := state["parentImageCount"]
    for _, product in state["products"]
        total += product["imageCount"]
    return total
}

ValidateMatrixStateImageTargets(state, availableTargets) {
    global imageGalleryPageSize, imageGalleryMaxPages, maximumImagesPerProduct
    if availableTargets != imageGalleryPageSize
        throw Error("Matrix image pagination requires " imageGalleryPageSize " reusable gallery targets; found " availableTargets ".")
    maximumImages := Min(imageGalleryPageSize * imageGalleryMaxPages, maximumImagesPerProduct)
    if state["parentImageCount"] > maximumImages
        throw Error("Saved matrix parent image count exceeds the pagination safety limit of " maximumImages ".")
    for p, product in state["products"] {
        if product["imageCount"] > maximumImages
            throw Error("Saved matrix product " p " image count exceeds the pagination safety limit of " maximumImages ".")
    }
}

