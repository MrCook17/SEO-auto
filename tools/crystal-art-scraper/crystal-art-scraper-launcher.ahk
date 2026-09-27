#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

global CrystalArtOutputDirectory := "C:\Crystal Art"
global CrystalArtScriptPath := A_ScriptDir "\crystal-art-scraper.js"
global CrystalArtInputPath := A_ScriptDir "\product-codes.txt"

A_TrayMenu.Add()
A_TrayMenu.Add("Crystal Art: Scrape product-codes.txt", (*) => ConfirmListRun())
A_TrayMenu.Add("Crystal Art: Specific product code...", (*) => RunSpecificProduct())
A_TrayMenu.Add("Crystal Art: Retry failures", (*) => RunCrystalArt("--retry-failed", "Retry failures"))
A_TrayMenu.Add()
A_TrayMenu.Add("Edit product-codes.txt", (*) => EditProductCodes())
A_TrayMenu.Add("Open Crystal Art output", (*) => OpenOutput())
A_TrayMenu.Add("Open scrape log", (*) => OpenLog())
A_TrayMenu.Default := "Crystal Art: Scrape product-codes.txt"
A_TrayMenu.ClickCount := 1
A_IconTip := "Crystal Art Scraper"

MsgBox(
    "Add one Craft Buddy product code per line to product-codes.txt, then use the tray menu to run the scraper.",
    "Crystal Art Scraper"
)

ConfirmListRun()
{
    global CrystalArtInputPath
    answer := MsgBox(
        "Scrape every code in:`n" CrystalArtInputPath "?`n`nCompleted products will be verified and skipped.",
        "Confirm Crystal Art scrape",
        36
    )
    if (answer = "Yes")
        RunCrystalArt("--resume", "Product-code list")
}

RunSpecificProduct()
{
    result := InputBox(
        "Enter the Craft Buddy product code:",
        "Crystal Art product code",
        "w390 h130"
    )
    if (result.Result != "OK")
        return
    code := Trim(result.Value)
    if !RegExMatch(code, "^[A-Za-z0-9][A-Za-z0-9._-]{1,79}$")
    {
        MsgBox("Enter a valid product code using letters, numbers, hyphens, dots or underscores.", "Crystal Art Scraper", 48)
        return
    }
    RunCrystalArt("--product-code " code, "Product " code)
}

RunCrystalArt(arguments, label)
{
    global CrystalArtScriptPath
    if !FileExist(CrystalArtScriptPath)
    {
        MsgBox("Scraper not found:`n" CrystalArtScriptPath, "Crystal Art Scraper", 16)
        return
    }
    if !NodeIsAvailable()
    {
        MsgBox("Node.js 20 or newer was not found on PATH.", "Crystal Art Scraper", 16)
        return
    }
    if !FileExist(A_ScriptDir "\node_modules\sharp\package.json")
    {
        MsgBox(
            "Dependencies are missing.`n`nOpen PowerShell in:`n" A_ScriptDir "`n`nThen run:`nnpm.cmd install",
            "Crystal Art Scraper",
            16
        )
        return
    }

    try
        exitCode := RunWait('node "' CrystalArtScriptPath '" ' arguments, A_ScriptDir)
    catch as error
    {
        MsgBox("The scraper could not start:`n`n" error.Message, "Crystal Art Scraper", 16)
        return
    }
    icon := exitCode = 0 ? 64 : 48
    answer := MsgBox(
        label " finished with exit code " exitCode ".`n`nOpen the scrape log?",
        "Crystal Art Scraper",
        4 + icon
    )
    if (answer = "Yes")
        OpenLog()
}

NodeIsAvailable()
{
    try
        return RunWait(A_ComSpec ' /D /C "where node >nul 2>nul"', , "Hide") = 0
    catch
        return false
}

EditProductCodes()
{
    global CrystalArtInputPath
    Run('notepad.exe "' CrystalArtInputPath '"')
}

OpenOutput()
{
    global CrystalArtOutputDirectory
    if !DirExist(CrystalArtOutputDirectory)
        DirCreate(CrystalArtOutputDirectory)
    Run('explorer.exe "' CrystalArtOutputDirectory '"')
}

OpenLog()
{
    global CrystalArtOutputDirectory
    logPath := CrystalArtOutputDirectory "\scrape-log.txt"
    if !FileExist(logPath)
    {
        MsgBox("The scrape log does not exist yet:`n" logPath, "Crystal Art Scraper", 48)
        return
    }
    Run('notepad.exe "' logPath '"')
}
