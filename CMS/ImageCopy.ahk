CopyCmsImageToClipboard(imageIndex := 1, sequentialGallery := false) {
    global cmsWinTitle, imageContextCopyKey, copyHighQualityImagePreview, allowThumbnailImageCopyFallback
    global imageGalleryPageSize, imageCopyPreCopyDelayMs

    ActivateWindow(cmsWinTitle, sequentialGallery ? 100 : 300)
    if sequentialGallery {
        if imageIndex > 1 && Mod(imageIndex - 1, imageGalleryPageSize) = 0 {
            targetPage := GetImageGalleryPageForIndex(imageIndex)
            TestingLog("image-gallery-sequential-advance", "Advancing to page " targetPage " for image " imageIndex ".")
            if !TryAdvanceImageGalleryPage()
                throw Error("Could not advance the sequential Image Gallery batch to page " targetPage " for image " imageIndex ".")
        }
    } else
        OpenImageGalleryPageForIndex(imageIndex)

    ; Give the selected carousel page and its image resource one final second
    ; to settle before opening/copying the preview. This is deliberately applied
    ; to every image, including images that do not cross a page boundary.
    TestingLog("image-copy-pre-delay", "Image " imageIndex "; delay_ms=" imageCopyPreCopyDelayMs ".")
    Sleep imageCopyPreCopyDelayMs

    ; The testing trace showed that Ctrl+C on the high-quality preview failed
    ; for every image, while the context-menu Copy image shortcut succeeded for
    ; every image. Use that successful route directly.
    if copyHighQualityImagePreview {
        if CopyHighQualityPreviewByContextMenuKey(imageIndex, imageContextCopyKey)
            return true

        ; Avoid silently attaching the old low-quality thumbnail unless the
        ; manual fallback setting is enabled near the top of this file.
        if !allowThumbnailImageCopyFallback
            return false
    }

    ; The optional thumbnail fallback also uses the proven context-menu route;
    ; there is deliberately no preliminary Ctrl+C attempt anywhere in this flow.
    if CopyImageByContextMenuKey(imageIndex, imageContextCopyKey)
        return true

    return false
}

CopyHighQualityPreviewByContextMenuKey(imageIndex, copyKey) {
    global highQualityImageCopyPoint, highQualityImagePreviewLoadDelayMs

    savedClip := ClipboardAll()
    A_Clipboard := ""
    Sleep 100

    SelectCmsImageForPreview(imageIndex)
    Sleep highQualityImagePreviewLoadDelayMs

    MouseMove highQualityImageCopyPoint[1], highQualityImageCopyPoint[2]
    Sleep 100
    Click "Right"
    Sleep 300
    Send copyKey

    if ClipWait(3, true) {
        TestingLog("image-clipboard-copy", "Image " imageIndex " copied from the high-quality preview with the context-menu shortcut.")
        return true
    }

    TestingLog("image-clipboard-copy-miss", "Image " imageIndex " high-quality context-menu attempt did not produce clipboard data.")
    Send "{Esc}"
    A_Clipboard := savedClip
    return false
}

SelectCmsImageForPreview(imageIndex := 1) {
    target := GetImageTarget(imageIndex)
    ClickCoordinates(target["image"], 300)
}

CopyImageByContextMenuKey(imageIndex, copyKey) {
    savedClip := ClipboardAll()
    A_Clipboard := ""
    Sleep 100

    target := GetImageTarget(imageIndex)
    point := target["image"]
    MouseMove point[1], point[2]
    Sleep 100
    Click "Right"
    Sleep 300
    Send copyKey

    if ClipWait(3, true) {
        return true
    }

    Send "{Esc}"
    A_Clipboard := savedClip
    return false
}

