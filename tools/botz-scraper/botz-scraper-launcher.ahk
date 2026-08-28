#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

global BotzOutputDirectory := "C:\BOTZ\stoneware"
global BotzScriptPath := A_ScriptDir "\botz-scraper.js"

A_TrayMenu.Add()
A_TrayMenu.Add("BOTZ: One-product headed test", (*) => RunBotz("--headed --limit 1", "One-product test"))
A_TrayMenu.Add("BOTZ: Five-product headed test", (*) => RunBotz("--headed --limit 5", "Five-product test"))
A_TrayMenu.Add("BOTZ: Specific product code...", (*) => RunSpecificProduct())
A_TrayMenu.Add()
A_TrayMenu.Add("BOTZ: Resume", (*) => RunBotz("--resume", "Resume"))
A_TrayMenu.Add("BOTZ: Retry failures", (*) => RunBotz("--retry-failed", "Retry failures"))
A_TrayMenu.Add("BOTZ: Full resumable run", (*) => ConfirmFullRun())
A_TrayMenu.Add()
A_TrayMenu.Add("Open BOTZ output", (*) => OpenBotzOutput())
A_TrayMenu.Add("Open BOTZ log", (*) => OpenBotzLog())
A_TrayMenu.Default := "BOTZ: One-product headed test"
A_TrayMenu.ClickCount := 1
A_IconTip := "BOTZ Earthenware Scraper"

MsgBox(
    "The BOTZ scraper launcher is ready in the tray menu.",
    "BOTZ Scraper"
)

RunSpecificProduct()
{
    result := InputBox(
        "Enter the four-digit earthenware product code:",
        "BOTZ product code",
        "w330 h130"
    )
    if (result.Result != "OK")
        return
    code := Trim(result.Value)
    if !RegExMatch(code, "^\d{4}$")
    {
        MsgBox("Enter exactly four digits.", "BOTZ Scraper", 48)
        return
    }
    RunBotz("--headed --product-code " code, "Product " code)
}

ConfirmFullRun()
{
    answer := MsgBox(
        "Start a full resumable BOTZ earthenware scrape?`n`nExisting completed products will be verified and skipped.",
        "Confirm BOTZ full run",
        36
    )
    if (answer = "Yes")
        RunBotz("--resume", "Full resumable run")
}

RunBotz(arguments, label)
{
    global BotzScriptPath

    if !FileExist(BotzScriptPath)
    {
        MsgBox("Scraper not found:`n" BotzScriptPath, "BOTZ Scraper", 16)
        return
    }
    if !NodeIsAvailable()
    {
        MsgBox(
            "Node.js was not found on PATH.`n`nInstall Node.js 20 or newer, then restart this launcher.",
            "BOTZ Scraper",
            16
        )
        return
    }
    if !FileExist(A_ScriptDir "\node_modules\playwright\package.json")
    {
        MsgBox(
            "Playwright dependencies are missing.`n`nOpen PowerShell in:`n" A_ScriptDir
            . "`n`nThen run:`nnpm install`nnpx playwright install chromium",
            "BOTZ Scraper",
            16
        )
        return
    }

    command := 'node "' BotzScriptPath '" ' arguments
    try
        exitCode := RunWait(command, A_ScriptDir)
    catch as error
    {
        MsgBox("The Node process could not start:`n`n" error.Message, "BOTZ Scraper", 16)
        return
    }

    icon := exitCode = 0 ? 64 : 48
    answer := MsgBox(
        label " finished with exit code " exitCode ".`n`nOpen the scrape log?",
        "BOTZ Scraper",
        4 + icon
    )
    if (answer = "Yes")
        OpenBotzLog()
}

NodeIsAvailable()
{
    try
        return RunWait(A_ComSpec ' /D /C "where node >nul 2>nul"', , "Hide") = 0
    catch
        return false
}

OpenBotzOutput()
{
    global BotzOutputDirectory
    if !DirExist(BotzOutputDirectory)
        DirCreate(BotzOutputDirectory)
    Run('explorer.exe "' BotzOutputDirectory '"')
}

OpenBotzLog()
{
    global BotzOutputDirectory
    logPath := BotzOutputDirectory "\scrape-log.txt"
    if !FileExist(logPath)
    {
        MsgBox("The BOTZ log does not exist yet:`n" logPath, "BOTZ Scraper", 48)
        return
    }
    Run('notepad.exe "' logPath '"')
}