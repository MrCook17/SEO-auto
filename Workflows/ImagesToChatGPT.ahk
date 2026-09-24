TryCopyCmsImagesToChatGPT(showResult := true) {
    global imageCountToProcess, chatgptWinTitle, chatImageWindowWakeDelayMs

    try {
        if imageCountToProcess < 1
            return true

        successCount := 0
        batchStartedAt := A_TickCount
        TestingLog("chatgpt-image-batch-start", "Starting " imageCountToProcess " CMS image copy/paste attempt(s).")

        ; The prompt can appear in ChatGPT as one draft file tile. Measure the
        ; current draft first, then verify that each image adds exactly one more
        ; attachment instead of waiting a long fixed delay after every Ctrl+V.
        ActivateWindow(GetChatGptWinTitle(), chatImageWindowWakeDelayMs)
        attachmentBaseline := GetChatGptDraftAttachmentCount()
        TestingLog("chatgpt-attachment-baseline", "Draft attachment count before CMS images: " attachmentBaseline ".")

        ; Open and rewind the gallery once. Images are ordered left-to-right in
        ; groups of five, so the batch can move forward only at images 6 and 11
        ; instead of reopening page 1 for every individual image.
        PrepareCmsImageGalleryForSequentialCopy()

        Loop imageCountToProcess {
            expectedAttachmentCount := attachmentBaseline >= 0 ? attachmentBaseline + successCount + 1 : -1
            if TryCopyCmsSingleImageToChatGPT(A_Index, false, true, expectedAttachmentCount)
                successCount += 1
            else {
                TestingLog("chatgpt-image-batch-stopped", "Stopped after " successCount " successful image(s); image " A_Index " failed.")
                break
            }
            Sleep 100
        }

        if showResult {
            if successCount = imageCountToProcess
                Flash("Image paste attempted for " successCount " image(s).")
            else
                Flash("Image paste attempted for " successCount " of " imageCountToProcess " image(s).")
        }

        TestingLog(
            "chatgpt-image-batch-complete",
            "Successful attempts: " successCount " of " imageCountToProcess
            . "; elapsed_ms=" (A_TickCount - batchStartedAt) "."
        )
        SaveTestingAccessibilityTree("chatgpt-after-" successCount "-of-" imageCountToProcess "-image-pastes")
        return successCount = imageCountToProcess
    } catch as err {
        ReportTestingError("chatgpt-image-batch", err)
        if showResult
            MsgBox "TryCopyCmsImagesToChatGPT failed:`n`n" err.Message
        return false
    }
}

TryCopyCmsImageToChatGPT(showResult := true) {
    return TryCopyCmsSingleImageToChatGPT(1, showResult)
}

TryCopyCmsSingleImageToChatGPT(imageIndex := 1, showResult := true, sequentialGallery := false, expectedChatAttachmentCount := -1) {
    global chatgptWinTitle, imageGalleryPageSize
    global chatImageWindowWakeDelayMs, chatImagePasteFallbackDelayMs

    try {
        imageStartedAt := A_TickCount
        TestingLog(
            "chatgpt-image-start",
            "Image " imageIndex "; gallery_page=" GetImageGalleryPageForIndex(imageIndex)
            . "; gallery_slot=" (Mod(imageIndex - 1, imageGalleryPageSize) + 1) "."
        )
        imageCopied := CopyCmsImageToClipboard(imageIndex, sequentialGallery)

        if !imageCopied {
            TestingLog("chatgpt-image-copy-failed", "Image " imageIndex " did not reach the clipboard.")
            if showResult
                Flash("Image " imageIndex " copy failed. Attach manually.")
            return false
        }

        ActivateWindow(GetChatGptWinTitle(), chatImageWindowWakeDelayMs)
        FocusChatGptInputForImagePaste()
        Send "^v"
        if expectedChatAttachmentCount >= 0 {
            if !WaitForChatGptDraftAttachmentCount(expectedChatAttachmentCount) {
                TestingLog(
                    "chatgpt-image-paste-unverified",
                    "Image " imageIndex " did not raise the draft attachment count to " expectedChatAttachmentCount "."
                )
                return false
            }
        } else
            Sleep chatImagePasteFallbackDelayMs
        TestingLog(
            "chatgpt-image-paste",
            "Image " imageIndex " was copied and verified in ChatGPT; elapsed_ms=" (A_TickCount - imageStartedAt) "."
        )

        if showResult
            Flash("Image " imageIndex " paste attempted.")

        return true
    } catch as err {
        ReportTestingError("chatgpt-image-" imageIndex, err)
        if showResult
            MsgBox "TryCopyCmsSingleImageToChatGPT failed for image " imageIndex ":`n`n" err.Message
        return false
    }
}

