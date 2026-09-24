InsertImageSeoFields(imageTitles, imageAlts, imageNames := 0) {
    if imageTitles.Length
        BeginSequentialImageMetadataInsertion(imageTitles.Length)
    Loop imageTitles.Length {
        imageName := imageNames && imageNames.Length >= A_Index ? imageNames[A_Index] : ""
        PasteImageMetadataToCms(A_Index, imageTitles[A_Index], imageAlts[A_Index], imageName)
    }
    if imageTitles.Length && !IsDepartmentMode()
        SaveTestingAccessibilityTree("cms-after-" imageTitles.Length "-image-metadata-records")
}

BeginSequentialImageMetadataInsertion(imageCount) {
    if imageCount < 1
        return

    if IsDepartmentMode() {
        if imageCount != 1
            throw Error("Department mode expects exactly one image metadata record; received " imageCount ".")
        OpenDepartmentImageGalleryByCoordinates("image-metadata")
        TestingLog(
            "cms-image-metadata-start",
            "Department mode opened its single image gallery by configured coordinates; UIA gallery discovery was skipped."
        )
        return
    }

    ; Use verified UIA page changes here as well as during image copying. Blind
    ; Previous clicks could leave the metadata run on the wrong carousel page.
    OpenFirstImageGalleryPage()
    TestingLog(
        "cms-image-metadata-start",
        "Image count=" imageCount "; gallery page 1 was verified through UIA."
    )
}

PasteImageMetadataToCms(imageIndex, imageTitle, imageAlt, imageName := "") {
    global imageGalleryPageSize, cmsImageGalleryReturnSettleMs

    ; Image cards are ordered left-to-right in groups of five. Image 6, 11,
    ; 16, etc. moves to the next page and reuses the first configured slot.
    if imageIndex > 1 && Mod(imageIndex - 1, imageGalleryPageSize) = 0 {
        TestingLog(
            "cms-image-page-advance",
            "Advancing to gallery page " GetImageGalleryPageForIndex(imageIndex) " for image " imageIndex "."
        )
        if !TryAdvanceImageGalleryPage()
            throw Error("Could not reach Image Gallery page " GetImageGalleryPageForIndex(imageIndex) " before editing image " imageIndex ".")
    }
    TestingLog(
        "cms-image-metadata",
        "Opening image " imageIndex
        . "; gallery_page=" GetImageGalleryPageForIndex(imageIndex)
        . "; slot=" (Mod(imageIndex - 1, imageGalleryPageSize) + 1)
        . "; name_chars=" StrLen(imageName)
        . "; title_chars=" StrLen(imageTitle)
        . "; alt_chars=" StrLen(imageAlt) "."
    )
    OpenCmsImageDetailsForMetadata(imageIndex)
    if imageName != ""
        PasteToPoint("image_name", imageName)
    PasteToPoint("image_title", imageTitle)
    PasteToPoint("image_alt", imageAlt)

    ; GO B2B requires this Image Save button to leave the image details page.
    ; This does not click the main product Save button.
    ClickPoint("image_save_button", 250)
    if IsDepartmentMode() {
        Sleep cmsImageGalleryReturnSettleMs
        TestingLog(
            "cms-image-gallery-return-coordinate-mode",
            "Department mode skipped the post-save gallery accessibility-tree verification for its single image."
        )
    } else
        WaitForCmsImageGalleryAfterDetailsSave(imageIndex)
    TestingLog(
        "cms-image-metadata-saved",
        IsDepartmentMode()
            ? "Image 1 detail record was populated and saved; department coordinate mode used a fixed return delay."
            : "Image " imageIndex " detail record was populated, saved, and the Image Gallery return was verified."
    )
}

OpenCmsImageDetailsForMetadata(imageIndex) {
    global cmsImageDetailsOpenAttempts, cmsImageDetailsButtonTimeoutMs, cmsImageDetailsFormTimeoutMs
    global imageGalleryPageSize

    slotIndex := Mod(imageIndex - 1, imageGalleryPageSize) + 1
    Loop cmsImageDetailsOpenAttempts {
        attempt := A_Index
        if IsDepartmentMode() {
            if imageIndex != 1
                throw Error("Department mode can open only its configured first image; received image " imageIndex ".")
            target := GetImageTarget(1)
            point := target["details_button"]
            TestingLog(
                "cms-image-details-open-attempt",
                "Image=1; attempt=" attempt "; slot=1; source=department-configured-coordinate; x=" point[1] "; y=" point[2] "."
            )
            Click point[1], point[2]
        } else {
            buttonInfo := WaitForVisibleImageGalleryDetailsButton(slotIndex, cmsImageDetailsButtonTimeoutMs)
            if buttonInfo {
                TestingLog(
                    "cms-image-details-open-attempt",
                    "Image=" imageIndex "; attempt=" attempt "; slot=" slotIndex
                    . "; source=UIA; x=" buttonInfo["x"] "; y=" buttonInfo["y"] "."
                )
                ; Use a physical click at the live UIA rectangle. This preserves the
                ; proven browser interaction while avoiding stale fixed coordinates.
                Click buttonInfo["x"], buttonInfo["y"]
            } else {
                ; Retain the configured screen point only as a compatibility fallback
                ; if Chrome temporarily declines to expose visible Details buttons.
                target := GetImageTarget(imageIndex)
                point := target["details_button"]
                TestingLog(
                    "cms-image-details-open-attempt",
                    "Image=" imageIndex "; attempt=" attempt "; slot=" slotIndex
                    . "; source=configured-fallback; x=" point[1] "; y=" point[2] "."
                )
                Click point[1], point[2]
            }
        }

        if WaitForCmsImageDetailsFormReady(cmsImageDetailsFormTimeoutMs) {
            TestingLog("cms-image-details-ready", "Image=" imageIndex "; attempt=" attempt ".")
            return true
        }

        TestingLog(
            "cms-image-details-open-miss",
            "Image=" imageIndex "; attempt=" attempt "; the Title and Alt edit controls did not appear."
        )
        if !IsDepartmentMode()
            SaveTestingAccessibilityTree("cms-image-" imageIndex "-details-open-attempt-" attempt "-failed")
        if attempt < cmsImageDetailsOpenAttempts {
            ; Rebuild the exact page from a verified page 1 before retrying. This
            ; handles a Save transition swallowing the first Details click.
            if IsDepartmentMode()
                OpenDepartmentImageGalleryByCoordinates("image-metadata-retry")
            else
                OpenImageGalleryPageForIndex(imageIndex)
        }
    }

    throw Error(
        "Image " imageIndex " Details did not open after " cmsImageDetailsOpenAttempts " verified attempt(s)."
        . " The script stopped before pasting into the wrong page."
    )
}

WaitForVisibleImageGalleryDetailsButton(slotIndex, timeoutMs) {
    deadline := A_TickCount + timeoutMs
    Loop {
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            gallery := FindImageGalleryScope(document)
            if gallery {
                buttons := gallery.FindElements({ Name: "Details", Type: "Button", mm: 3, cs: 0 })
                visibleButtons := []
                for _, button in buttons {
                    try {
                        if button.IsOffscreen || !button.IsEnabled
                            continue
                        rect := button.Location
                        if rect.w <= 0 || rect.h <= 0
                            continue
                        item := Map(
                            "x", Round(rect.x + rect.w / 2),
                            "y", Round(rect.y + rect.h / 2)
                        )
                        insertAt := visibleButtons.Length + 1
                        for existingIndex, existing in visibleButtons {
                            if item["x"] < existing["x"] {
                                insertAt := existingIndex
                                break
                            }
                        }
                        visibleButtons.InsertAt(insertAt, item)
                    }
                }
                if visibleButtons.Length >= slotIndex
                    return visibleButtons[slotIndex]
            }
        }
        if A_TickCount >= deadline
            return 0
        Sleep 200
    }
}

WaitForCmsImageDetailsFormReady(timeoutMs) {
    deadline := A_TickCount + timeoutMs
    Loop {
        if IsEnabledUiaEditAtConfiguredPoint("image_title")
            && IsEnabledUiaEditAtConfiguredPoint("image_alt")
            return true
        if A_TickCount >= deadline
            return false
        Sleep 200
    }
}

IsEnabledUiaEditAtConfiguredPoint(coordinateName) {
    global coords
    point := coords[coordinateName]

    try node := UIA.SmallestElementFromPoint(point[1], point[2])
    catch
        return false

    Loop 8 {
        try {
            if StrLower(GetUiaControlTypeText(node)) = "edit" {
                if node.IsOffscreen || !node.IsEnabled
                    return false
                return true
            }
        }
        try parent := UIA.TreeWalkerTrue.GetParentElement(node)
        catch
            return false
        if !parent
            return false
        node := parent
    }
    return false
}

WaitForCmsImageGalleryAfterDetailsSave(imageIndex) {
    global cmsImageGalleryReturnTimeoutMs, cmsImageGalleryReturnSettleMs

    startedAt := A_TickCount
    WaitForImageGalleryAvailable(cmsImageGalleryReturnTimeoutMs)
    Sleep cmsImageGalleryReturnSettleMs
    ; Confirm the scope survived the final settle period instead of accepting a
    ; short-lived transitional tree immediately after Save.
    WaitForImageGalleryAvailable(cmsImageGalleryReturnTimeoutMs)
    TestingLog(
        "cms-image-gallery-return-ready",
        "Image=" imageIndex "; elapsed_ms=" (A_TickCount - startedAt) "."
    )
}

