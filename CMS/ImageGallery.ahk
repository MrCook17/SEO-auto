PrepareCmsImageGalleryForSequentialCopy() {
    global cmsWinTitle

    startedAt := A_TickCount
    ActivateWindow(cmsWinTitle, 100)
    if IsDepartmentMode() {
        OpenDepartmentImageGalleryByCoordinates("image-copy")
        TestingLog(
            "image-gallery-sequential-ready",
            "Department mode opened the one-image gallery by configured coordinates; UIA gallery discovery was skipped."
        )
        return
    }
    OpenFirstImageGalleryPage()
    TestingLog(
        "image-gallery-sequential-ready",
        "Gallery prepared on page 1 for sequential image copying; elapsed_ms=" (A_TickCount - startedAt) "."
    )
}

OpenDepartmentImageGalleryByCoordinates(context := "department-image") {
    global cmsWinTitle, imageTabLoadDelayMs

    ActivateWindow(cmsWinTitle, 100)
    ClickPoint("images_tab", imageTabLoadDelayMs)
    TestingLog(
        "department-image-gallery-coordinate-open",
        "Context=" context "; fixed image count=1; Images tab opened through configured coordinates."
    )
}

GetImageTarget(imageIndex) {
    global imageTargets, imageGalleryPageSize

    if imageIndex < 1
        throw Error("Image indices must start at 1; received " imageIndex ".")
    if imageTargets.Length != imageGalleryPageSize
        throw Error("imageTargets must contain exactly " imageGalleryPageSize " reusable gallery-slot coordinate entries.")

    slotIndex := Mod(imageIndex - 1, imageGalleryPageSize) + 1
    return imageTargets[slotIndex]
}

GetImageGalleryPageForIndex(imageIndex) {
    global imageGalleryPageSize
    if imageIndex < 1
        throw Error("Image indices must start at 1; received " imageIndex ".")
    return Floor((imageIndex - 1) / imageGalleryPageSize) + 1
}

OpenFirstImageGalleryPage() {
    global imageTabLoadDelayMs, imageGalleryMaxPages, imageAccessibilityTreeInitialDelayMs

    ; GO b2b preserves the current gallery page when the Images tab is clicked.
    ; Wait adaptively for the tab's UIA subtree before attempting pagination,
    ; then walk backwards until Previous no longer changes the page.
    ClickPoint("images_tab", imageTabLoadDelayMs)
    ToolTip "Waiting for the Images tab to settle before reading its accessibility tree..."
    TestingLog("image-gallery-pre-uia-delay", "Delay_ms=" imageAccessibilityTreeInitialDelayMs ".")
    Sleep imageAccessibilityTreeInitialDelayMs
    WaitForImageGalleryAvailable()
    Loop imageGalleryMaxPages {
        if !TryReturnToPreviousImageGalleryPage()
            return
        if A_Index = imageGalleryMaxPages
            throw Error("Could not return to the first Image Gallery page within the " imageGalleryMaxPages "-page safety limit.")
    }
}

WaitForImageGalleryAvailable(timeoutMs := 0) {
    global LastDocument, imageGalleryAvailabilityTimeoutMs

    effectiveTimeoutMs := timeoutMs > 0 ? timeoutMs : imageGalleryAvailabilityTimeoutMs
    startedAt := A_TickCount
    deadline := startedAt + effectiveTimeoutMs
    attempt := 0
    lastProblem := "Image Gallery has not appeared yet."

    Loop {
        attempt += 1
        ToolTip "Waiting for the Images tab accessibility tree..."
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            LastDocument := document
            gallery := FindImageGalleryScope(document)
            if gallery {
                TestingLog(
                    "image-gallery-available",
                    "UIA gallery became available after " (A_TickCount - startedAt) " ms on attempt " attempt "."
                )
                ToolTip()
                return gallery
            }
            lastProblem := "The browser document was available, but the Image Gallery scope was absent."
        } catch as err {
            lastProblem := FormatTestingError(err)
        }

        if A_TickCount >= deadline {
            ToolTip()
            TestingLog("image-gallery-availability-timeout", lastProblem)
            SaveTestingAccessibilityTree("image-gallery-availability-timeout")
            throw Error(
                "The Images tab accessibility tree did not become available within " effectiveTimeoutMs " ms."
                . "`n`nLast UIA result: " lastProblem
                . "`n`nLeave the Images tab open and press F9 to dump the tree."
            )
        }
        Sleep 250
    }
}

OpenImageGalleryPageForIndex(imageIndex) {
    targetPage := GetImageGalleryPageForIndex(imageIndex)
    OpenFirstImageGalleryPage()

    if targetPage > 1 {
        Loop targetPage - 1 {
            if !TryAdvanceImageGalleryPage()
                throw Error("Could not reach Image Gallery page " targetPage " for image " imageIndex ". The gallery ended on page " A_Index ".")
        }
    }
}

TryAdvanceImageGalleryPage() {
    global imageGalleryNextPageDelayMs

    return TryMoveImageGalleryPage(
        "image_gallery_next_button",
        "Next",
        imageGalleryNextPageDelayMs
    )
}

TryReturnToPreviousImageGalleryPage() {
    global imageGalleryPreviousPageDelayMs, imageGalleryFirstPageNoChangeTimeoutMs

    return TryMoveImageGalleryPage(
        "image_gallery_previous_button",
        "Previous",
        imageGalleryPreviousPageDelayMs,
        imageGalleryFirstPageNoChangeTimeoutMs
    )
}

TryMoveImageGalleryPage(buttonCoordinateName, directionLabel, clickDelayMs, noChangeTimeoutMs := 0) {

    document := UIA_Browser().GetCurrentDocumentElement()
    gallery := FindImageGalleryScope(document)
    if !gallery
        throw Error("The Image Gallery scope was unavailable before clicking its " directionLabel " button.")
    previousSnapshot := GetImageGalleryPageSnapshot(gallery)
    buttonState := GetImageGalleryButtonState(buttonCoordinateName, gallery, directionLabel)
    TestingLog(
        "image-gallery-page-move",
        "Direction=" directionLabel "; button_state=" buttonState "; before_snapshot_chars=" StrLen(previousSnapshot) "."
    )
    if buttonState = 0 {
        TestingLog("image-gallery-page-edge", directionLabel " button is disabled.")
        return false
    }

    ClickPoint(buttonCoordinateName, clickDelayMs)
    if WaitForImageGalleryPageChange(previousSnapshot, noChangeTimeoutMs) {
        TestingLog("image-gallery-page-changed", directionLabel " navigation succeeded on its first click.")
        return true
    }

    ; Retry once when UIA identified an enabled control. This handles a click
    ; landing during a brief gallery rerender without mistaking it for an edge.
    if buttonState = 1 {
        ClickPoint(buttonCoordinateName, clickDelayMs)
        if WaitForImageGalleryPageChange(previousSnapshot, noChangeTimeoutMs) {
            TestingLog("image-gallery-page-changed", directionLabel " navigation succeeded on its retry click.")
            return true
        }
    }
    TestingLog("image-gallery-page-unchanged", directionLabel " navigation did not change the gallery snapshot.")
    return false
}

GetImageGalleryButtonState(buttonCoordinateName, gallery := 0, directionLabel := "") {
    global coords

    ; Chrome omits Previous on page 1 and Next on the last page. A scoped UIA
    ; lookup can identify those edges immediately, avoiding the old click plus
    ; two-second no-change timeout on every image.
    if gallery && directionLabel != "" {
        try {
            requestedButtons := gallery.FindElements({ Name: directionLabel, Type: "Button", mm: 2, cs: 0 })
            for _, button in requestedButtons {
                if StrLower(Trim(button.Name)) = StrLower(directionLabel)
                    return button.IsEnabled ? 1 : 0
            }

            oppositeLabel := StrLower(directionLabel) = "previous" ? "Next" : "Previous"
            oppositeButtons := gallery.FindElements({ Name: oppositeLabel, Type: "Button", mm: 2, cs: 0 })
            for _, button in oppositeButtons {
                if StrLower(Trim(button.Name)) = StrLower(oppositeLabel)
                    return 0
            }

            if CountImageGalleryCards(gallery) <= 5
                return 0
        }
    }

    ; If the scoped tree is temporarily incomplete, retain the point-based
    ; fallback and page-change verification used by older runs.
    point := coords[buttonCoordinateName]

    try node := UIA.SmallestElementFromPoint(point[1], point[2])
    catch
        return -1

    Loop 8 {
        try {
            if StrLower(GetUiaControlTypeText(node)) = "button"
                return node.IsEnabled ? 1 : 0
        }
        try parent := UIA.TreeWalkerTrue.GetParentElement(node)
        catch
            return -1
        if !parent
            return -1
        node := parent
    }
    return -1
}

GetImageGalleryPageSnapshot(gallery) {
    try return gallery.DumpAll(" ", 10)
    catch
        return ""
}

WaitForImageGalleryPageChange(previousSnapshot, timeoutMs := 0) {
    global imageGalleryPageChangeTimeoutMs
    effectiveTimeoutMs := timeoutMs > 0 ? timeoutMs : imageGalleryPageChangeTimeoutMs
    deadline := A_TickCount + effectiveTimeoutMs
    changedSnapshot := ""
    stableSince := 0

    Loop {
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            gallery := FindImageGalleryScope(document)
            snapshot := gallery ? GetImageGalleryPageSnapshot(gallery) : ""
            if snapshot != "" && snapshot != previousSnapshot {
                if snapshot = changedSnapshot {
                    if A_TickCount - stableSince >= 400
                        return true
                } else {
                    changedSnapshot := snapshot
                    stableSince := A_TickCount
                }
            }
        }
        if A_TickCount >= deadline
            return false
        Sleep 200
    }
}

ValidateImageTargetConfig() {
    global imageCountToProcess, maximumImagesPerProduct, imageTargets, imageGalleryPageSize, coords

    if imageCountToProcess < 0
        throw Error("imageCountToProcess cannot be negative.")
    if imageCountToProcess > maximumImagesPerProduct
        throw Error("imageCountToProcess cannot exceed the GO b2b limit of " maximumImagesPerProduct ".")

    if imageGalleryPageSize < 1 || imageTargets.Length != imageGalleryPageSize
        throw Error("Image pagination requires exactly " imageGalleryPageSize " coordinate entries in imageTargets; found " imageTargets.Length ".")
    if !coords.Has("image_gallery_previous_button") || !coords.Has("image_gallery_next_button")
        throw Error("The Image Gallery Previous and Next button coordinates must both be configured.")
}

DetectAndSetImageCountFromImagesTab(expectedCount := -1) {
    global imageCountToProcess, maximumImagesPerProduct

    ValidateImageTargetConfig()
    OpenFirstImageGalleryPage()
    actualCount := DiscoverStableImageGalleryCountAcrossPages()
    detectedCount := Min(actualCount, maximumImagesPerProduct)

    if expectedCount >= 0 && detectedCount != expectedCount
        throw Error("Image count changed or differs between matrix children: expected " expectedCount ", detected " detectedCount ".")

    imageCountToProcess := detectedCount
    message := "UIA-v2 detected " actualCount " total Image Gallery card(s) after realising and checking every available carousel page."
    if actualCount > maximumImagesPerProduct
        message .= " Only the first " maximumImagesPerProduct " will be processed because GO b2b permits at most " maximumImagesPerProduct " image records per product."
    LogText("image-count-detected", message)
    TestingLog("image-count-accepted", message " Prompt/CMS count is " detectedCount ".")
    SaveTestingAccessibilityTree("image-count-accepted-" detectedCount)
    return detectedCount
}

DiscoverStableImageGalleryCountAcrossPages() {
    global imageGalleryMaxPages, maximumImagesPerProduct

    highestCount := -1
    pageNumber := 1
    Loop imageGalleryMaxPages {
        currentCount := WaitForStableImageGalleryCount()
        highestCount := Max(highestCount, currentCount)
        TestingLog(
            "image-count-page-observed",
            "Carousel page=" pageNumber "; current_realised_total=" currentCount
            . "; highest_realised_total=" highestCount "."
        )

        ; No further traversal is useful once the CMS processing limit has been
        ; found, even if the source product somehow contains more records.
        if highestCount >= maximumImagesPerProduct {
            TestingLog(
                "image-count-page-scan-complete",
                "Stopped after page " pageNumber " because the " maximumImagesPerProduct "-image processing limit was realised."
            )
            return highestCount
        }

        if A_Index = imageGalleryMaxPages
            throw Error("Image Gallery page discovery reached its " imageGalleryMaxPages "-page safety limit.")

        if !TryAdvanceImageGalleryPage() {
            TestingLog(
                "image-count-page-scan-complete",
                "Reached the final carousel page " pageNumber "; accepted highest realised total " highestCount "."
            )
            return highestCount
        }
        pageNumber += 1
    }
}

WaitForStableImageGalleryCount(timeoutMs := 0, stableDurationMs := 0, minimumObservationMs := -1) {
    global LastDocument, maximumImagesPerProduct
    global imageGalleryCountTimeoutMs, imageGalleryCountStableDurationMs, imageGalleryMinimumObservationMs

    effectiveTimeoutMs := timeoutMs > 0 ? timeoutMs : imageGalleryCountTimeoutMs
    effectiveStableDurationMs := stableDurationMs > 0 ? stableDurationMs : imageGalleryCountStableDurationMs
    effectiveMinimumObservationMs := minimumObservationMs >= 0 ? minimumObservationMs : imageGalleryMinimumObservationMs
    startedAt := A_TickCount
    deadline := startedAt + effectiveTimeoutMs
    previousSignature := ""
    stableSince := 0
    sampleNumber := 0
    lastCounts := Map("remove", -1, "details", -1, "sizeOptions", -1, "images", -1)
    lastProblem := "No complete Image Gallery sample was available."

    Loop {
        ToolTip "Reading Image Gallery accessibility tree..."
        try {
            document := UIA_Browser().GetCurrentDocumentElement()
            LastDocument := document
            gallery := FindImageGalleryScope(document)
            if gallery {
                sampleNumber += 1
                counts := GetImageGalleryCardControlCounts(gallery)
                lastCounts := counts
                signature := BuildImageGalleryCountSignature(counts)
                consistent := AreImageGalleryCardControlCountsConsistent(counts)
                now := A_TickCount

                if signature != previousSignature {
                    previousSignature := signature
                    stableSince := now
                    SaveTestingElementDump(
                        gallery,
                        "image-count-sample-" sampleNumber "-" signature
                    )
                }

                TestingLog(
                    "image-count-sample",
                    "Sample " sampleNumber
                    . "; elapsed_ms=" (now - startedAt)
                    . "; " signature
                    . "; consistent=" (consistent ? "yes" : "no")
                    . "; stable_ms=" (now - stableSince)
                )

                if consistent {
                    lastProblem := "The count was consistent but had not completed the minimum observation and stability periods."
                    ; Once the GO b2b processing cap is present, no later card
                    ; can increase the work this run is allowed to perform.
                    minimumWaitSatisfied := counts["remove"] >= maximumImagesPerProduct
                        || now - startedAt >= effectiveMinimumObservationMs
                    if minimumWaitSatisfied
                        && now - stableSince >= effectiveStableDurationMs {
                        ToolTip()
                        TestingLog(
                            "image-count-stable",
                            "Accepted " counts["remove"] " card(s) after " (now - startedAt)
                            . " ms; stable for " (now - stableSince) " ms; " signature "."
                        )
                        return counts["remove"]
                    }
                } else {
                    lastProblem := "Per-card accessibility controls disagreed: " signature "."
                }
            } else {
                previousSignature := ""
                stableSince := 0
                lastProblem := "The Image Gallery scope temporarily disappeared during rendering."
            }
        } catch as err {
            ; Chrome can briefly invalidate UIA elements while the tab renders.
            ; Retry until the overall deadline instead of accepting a bad count.
            previousSignature := ""
            stableSince := 0
            lastProblem := FormatTestingError(err)
            TestingLog("image-count-sample-error", lastProblem)
        }
        if A_TickCount >= deadline {
            ToolTip()
            finalSignature := BuildImageGalleryCountSignature(lastCounts)
            TestingLog(
                "image-count-timeout",
                "Timed out after " effectiveTimeoutMs " ms. Last counts: " finalSignature ". Last result: " lastProblem
            )
            SaveTestingAccessibilityTree("image-count-timeout")
            throw Error(
                "The Image Gallery card count did not become complete and stable within " effectiveTimeoutMs " ms."
                . "`n`nLast counts: " finalSignature
                . "`nLast UIA result: " lastProblem
                . "`n`nLeave the Images tab open and press F9 to dump the tree."
            )
        }
        Sleep 250
    }
}

FindImageGalleryScope(document) {
    try heading := document.FindElement({ Name: "Image Gallery", mm: 2, cs: 0 })
    catch
        return 0

    scope := heading
    Loop 12 {
        ; The smallest ancestor exposing the gallery's Add control contains
        ; the image cards without including unrelated page controls.
        try addElements := scope.FindElements({ Name: "Add", mm: 2, cs: 0 })
        catch
            addElements := []
        for _, element in addElements {
            try {
                if RegExMatch(Trim(element.Name), "i)^\+?\s*Add$")
                    return scope
            }
        }
        try parent := UIA.TreeWalkerTrue.GetParentElement(scope)
        catch
            break
        if !parent
            break
        scope := parent
    }
    return 0
}

CountImageGalleryCards(scope) {
    return GetImageGalleryCardControlCounts(scope)["remove"]
}

GetImageGalleryCardControlCounts(scope) {
    return Map(
        "remove", CountExactImageGalleryElements(scope, "Remove", "Button"),
        "details", CountExactImageGalleryElements(scope, "Details", "Button"),
        "sizeOptions", CountExactImageGalleryElements(scope, "Size Options", "Button"),
        "images", CountExactImageGalleryElements(scope, "", "Image")
    )
}

CountExactImageGalleryElements(scope, expectedName, typeName) {
    count := 0
    condition := expectedName = ""
        ? { Type: typeName }
        : { Name: expectedName, Type: typeName, mm: 2, cs: 0 }
    try elements := scope.FindElements(condition)
    catch
        return count

    for _, element in elements {
        try {
            if expectedName != "" && StrLower(Trim(element.Name)) != StrLower(expectedName)
                continue
            count += 1
        }
    }
    return count
}

AreImageGalleryCardControlCountsConsistent(counts) {
    return counts["remove"] = counts["details"]
    && counts["remove"] = counts["sizeOptions"]
    && counts["remove"] = counts["images"]
}

BuildImageGalleryCountSignature(counts) {
    return "remove=" counts["remove"]
    . ", details=" counts["details"]
    . ", size_options=" counts["sizeOptions"]
    . ", images=" counts["images"]
}

