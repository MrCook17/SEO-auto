#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

global FiguredArtOutputDirectory := "C:\FiguredArt"
global FiguredArtScriptPath := A_ScriptDir "\figuredart-scraper.js"
global FiguredArtPdfPath := ""

A_TrayMenu.Add()
A_TrayMenu.Add("Figured'Art: Select purchase-order PDF...", (*) => SelectPdf())
A_TrayMenu.Add("Figured'Art: Extract PDF manifest", (*) => RunFiguredArt("--manifest-only", "Manifest extraction"))
A_TrayMenu.Add("Figured'Art: SFA137-Y validation", (*) => RunFiguredArt("--product-code SFA137-Y", "SFA137-Y validation"))
A_TrayMenu.Add("Figured'Art: Specific product code...", (*) => RunSpecificProduct())
A_TrayMenu.Add()
A_TrayMenu.Add("Figured'Art: Resume", (*) => RunFiguredArt("", "Resume"))
A_TrayMenu.Add("Figured'Art: Retry manual-attention products", (*) => RunFiguredArt("--retry-attention", "Attention retry"))
A_TrayMenu.Add("Figured'Art: Full resumable run", (*) => ConfirmFullRun())
A_TrayMenu.Add()
A_TrayMenu.Add("Open Figured'Art output", (*) => OpenOutput())
A_TrayMenu.Add("Open Figured'Art log", (*) => OpenFile("scrape-log.txt"))
A_TrayMenu.Add("Open Figured'Art summary", (*) => OpenFile("summary.json"))
A_TrayMenu.Default := "Figured'Art: SFA137-Y validation"
A_TrayMenu.ClickCount := 1
A_IconTip := "Figured'Art Product Scraper"

MsgBox(
    "The Figured'Art scraper launcher is ready in the tray menu.`n`nSelect the purchase-order PDF before starting a run.",
    "Figured'Art Scraper"
)

SelectPdf()
{
    global FiguredArtPdfPath
    selected := FileSelect(1, , "Select Figured'Art purchase-order PDF", "PDF documents (*.pdf)")
    if (selected = "")
        return false
    FiguredArtPdfPath := selected
    TrayTip("Selected:`n" selected, "Figured'Art Scraper")
    return true
}

RunSpecificProduct()
{
    result := InputBox(
        "Enter a product code that exists in the selected PDF:",
        "Figured'Art product code",
        "w360 h130"
    )
    if (result.Result != "OK")
        return
    code := StrUpper(Trim(result.Value))
    if !RegExMatch(code, "i)^[A-Z][A-Z0-9]*\d[A-Z0-9]*(?:-[A-Z0-9]+)?$")
    {
        MsgBox("Enter a valid supplier product code.", "Figured'Art Scraper", 48)
        return
    }
    RunFiguredArt("--product-code " code, "Product " code)
}

ConfirmFullRun()
{
    answer := MsgBox(
        "Start a full resumable Figured'Art scrape?`n`nEvery unique code in the selected PDF will be accounted for. Existing verified SUCCESS output will be skipped.",
        "Confirm Figured'Art full run",
        36
    )
    if (answer = "Yes")
        RunFiguredArt("", "Full resumable run")
}

RunFiguredArt(arguments, label)
{
    global FiguredArtScriptPath, FiguredArtPdfPath, FiguredArtOutputDirectory

    if !FileExist(FiguredArtScriptPath)
    {
        MsgBox("Scraper not found:`n" FiguredArtScriptPath, "Figured'Art Scraper", 16)
        return
    }
    if (FiguredArtPdfPath = "" || !FileExist(FiguredArtPdfPath))
    {
        if !SelectPdf()
            return
    }
    if InStr(FiguredArtPdfPath, '"') || InStr(FiguredArtOutputDirectory, '"')
    {
        MsgBox("Paths containing a double quote are not supported.", "Figured'Art Scraper", 16)
        return
    }
    if !NodeIsAvailable()
    {
        MsgBox(
            "Node.js was not found on PATH.`n`nInstall Node.js 20 or newer, then restart this launcher.",
            "Figured'Art Scraper",
            16
        )
        return
    }
    if !FileExist(A_ScriptDir "\node_modules\sharp\package.json")
    {
        MsgBox(
            "Scraper dependencies are missing.`n`nOpen PowerShell in:`n" A_ScriptDir
            . "`n`nThen run:`nnpm.cmd install",
            "Figured'Art Scraper",
            16
        )
        return
    }

    command := 'node "' FiguredArtScriptPath '" --pdf "' FiguredArtPdfPath
        . '" --output "' FiguredArtOutputDirectory '"'
    if (arguments != "")
        command .= " " arguments
    try
        exitCode := RunWait(command, A_ScriptDir)
    catch as error
    {
        MsgBox("The Node process could not start:`n`n" error.Message, "Figured'Art Scraper", 16)
        return
    }

    icon := exitCode = 0 ? 64 : 48
    answer := MsgBox(
        label " finished with exit code " exitCode ".`n`nOpen the summary?",
        "Figured'Art Scraper",
        4 + icon
    )
    if (answer = "Yes")
        OpenFile("summary.json")
}

NodeIsAvailable()
{
    try
        return RunWait(A_ComSpec ' /D /C "where node >nul 2>nul"', , "Hide") = 0
    catch
        return false
}

OpenOutput()
{
    global FiguredArtOutputDirectory
    if !DirExist(FiguredArtOutputDirectory)
        DirCreate(FiguredArtOutputDirectory)
    Run('explorer.exe "' FiguredArtOutputDirectory '"')
}

OpenFile(fileName)
{
    global FiguredArtOutputDirectory
    filePath := FiguredArtOutputDirectory "\" fileName
    if !FileExist(filePath)
    {
        MsgBox("The file does not exist yet:`n" filePath, "Figured'Art Scraper", 48)
        return
    }
    Run('notepad.exe "' filePath '"')
}
