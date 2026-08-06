#Requires AutoHotkey v2.0
#SingleInstance Force

; F8 = start saving image tabs
; F9 = stop after the current download
;
; Start on the first direct-image tab that you want to save.
; The script downloads the image using the filename in its URL,
; closes the tab, and repeats until the next tab is not an image URL.

global StopImageSaver := false
global OverwriteExisting := false
global DelayAfterClosingMs := 450

F8::SaveOpenImageTabs()

F9::
{
    global StopImageSaver
    StopImageSaver := true
    ToolTip("Stop requested. Finishing the current download...")
    SetTimer(HideToolTip, -1500)
}

SaveOpenImageTabs()
{
    global StopImageSaver, OverwriteExisting, DelayAfterClosingMs

    StopImageSaver := false
    savedCount := 0
    failedCount := 0
    downloadsDir := GetDownloadsFolder()
    savedClipboard := ClipboardAll()

    try
    {
        Loop
        {
            if StopImageSaver
                break

            url := GetCurrentTabUrl()

            ; Stop safely when the next tab is not displaying a direct image.
            if !IsDirectImageUrl(url)
                break

            fileName := GetFileNameFromUrl(url)

            if (fileName = "")
            {
                failedCount += 1
                MsgBox(
                    "The image filename could not be read from this URL:`n`n" url,
                    "Image tab saver stopped",
                    48
                )
                break
            }

            fileName := MakeWindowsSafeFileName(fileName)
            savePath := downloadsDir "\" fileName

            ; Avoid silently overwriting an existing image.
            if !OverwriteExisting
                savePath := MakeUniquePath(savePath)

            ToolTip(
                "Saving: " fileName
                . "`nCompleted: " savedCount
                . "`nPress F9 to stop."
            )

            try
            {
                ; Download() waits for the image download to finish.
                Download(url, savePath)
                savedCount += 1
            }
            catch as error
            {
                failedCount += 1

                ; Remove a partial file if one was created.
                if FileExist(savePath)
                {
                    try FileDelete(savePath)
                }

                MsgBox(
                    "The image could not be downloaded:`n`n"
                    . url
                    . "`n`nError: "
                    . error.Message,
                    "Image tab saver stopped",
                    48
                )
                break
            }

            ; Close the successfully downloaded image tab.
            Send("^w")
            Sleep(DelayAfterClosingMs)
        }
    }
    finally
    {
        A_Clipboard := savedClipboard
        ToolTip()
    }

    stopReason := StopImageSaver
        ? "Stopped manually."
        : "Stopped because the next tab was not a direct image URL."

    MsgBox(
        stopReason
        . "`n`nSaved: " savedCount
        . "`nFailed: " failedCount
        . "`nFolder: " downloadsDir,
        "Image tab saver"
    )
}

GetCurrentTabUrl()
{
    A_Clipboard := ""

    Send("^l")
    Sleep(75)
    Send("^c")

    if !ClipWait(1)
    {
        Send("{Esc}")
        return ""
    }

    url := Trim(A_Clipboard)
    Send("{Esc}")
    return url
}

IsDirectImageUrl(url)
{
    ; Supports URLs such as:
    ; https://example.com/image.jpg
    ; https://example.com/image.jpg?c=1
    return RegExMatch(
        url,
        "i)^https?://.+\.(?:jpe?g|jfif|png|webp|gif|bmp|tiff?|avif|svg)(?:[?#].*)?$"
    )
}

GetFileNameFromUrl(url)
{
    ; Remove query strings and fragments, such as ?c=1.
    cleanUrl := RegExReplace(url, "[?#].*$")
    slashPosition := InStr(cleanUrl, "/",, -1)

    return slashPosition ? SubStr(cleanUrl, slashPosition + 1) : ""
}

MakeWindowsSafeFileName(fileName)
{
    ; Replace characters Windows does not permit in filenames.
    fileName := RegExReplace(
        fileName,
        "[<>\x22:/\\|?*\x00-\x1F]",
        "_"
    )

    fileName := RTrim(fileName, ". ")

    return fileName != "" ? fileName : "image"
}

MakeUniquePath(path)
{
    if !FileExist(path)
        return path

    SplitPath(path, &fileName, &directory, &extension, &nameWithoutExtension)

    number := 1

    Loop
    {
        suffix := " (" number ")"
        candidate := directory "\" nameWithoutExtension suffix

        if (extension != "")
            candidate .= "." extension

        if !FileExist(candidate)
            return candidate

        number += 1
    }
}

GetDownloadsFolder()
{
    ; Uses the actual Windows Downloads known folder, including redirected folders.
    try
    {
        downloadsFolder := ComObject("Shell.Application").NameSpace("shell:Downloads")

        if downloadsFolder
            return downloadsFolder.Self.Path
    }

    ; Fallback for systems where the Shell lookup is unavailable.
    return EnvGet("USERPROFILE") "\Downloads"
}

HideToolTip()
{
    ToolTip()
}
