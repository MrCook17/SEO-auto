ClearActiveCmsProductCode() {
    global activeCmsProductCode
    activeCmsProductCode := ""
}

SetActiveCmsProductCode(productCode) {
    global activeCmsProductCode
    productCode := CleanText(productCode)
    if productCode = ""
        throw Error("The GO b2b product identity is blank, so product-specific logs and backups cannot be named safely.")
    activeCmsProductCode := productCode
    return productCode
}

HasActiveCmsProductCode() {
    global activeCmsProductCode
    return CleanText(activeCmsProductCode) != ""
}

GetActiveCmsProductCodeFilePart() {
    global activeCmsProductCode
    productCode := CleanText(activeCmsProductCode)
    if productCode = ""
        throw Error("The exact GO b2b product identity has not been collected, so a log or backup cannot be created.")

    ; Preserve the exact CMS value unless Windows forbids one of its characters
    ; in a filename. Normal GO b2b stock codes such as B91018 are unchanged.
    filePart := RegExReplace(productCode, "[<>:`"/\\|?*\x00-\x1F]", "_")
    filePart := RTrim(filePart, " .")
    if filePart = ""
        throw Error("The GO b2b product identity cannot be represented in a Windows filename: " productCode)
    return filePart
}

BuildRunArtifactFileName(prefix, timestamp) {
    return GetSeoAutomationMode() "-" GetActiveCmsProductCodeFilePart() "-" prefix "-" timestamp ".txt"
}

EnsureFolders() {
    global logDir, backupDir, stateDir, debugDir

    if !DirExist(logDir)
        DirCreate logDir

    if !DirExist(backupDir)
        DirCreate backupDir

    if !DirExist(stateDir)
        DirCreate stateDir

    if !DirExist(debugDir)
        DirCreate debugDir
}

LogText(prefix, text) {
    global logDir

    timestamp := FormatTime(, "yyyyMMdd-HHmmss")
    filePath := logDir "\" BuildRunArtifactFileName(prefix, timestamp)
    FileAppend text, filePath, "UTF-8"
    TestingLog("run-log-saved", "Prefix=" prefix "; path=" filePath "; chars=" StrLen(text) ".")
}

BackupText(prefix, text) {
    global backupDir

    timestamp := FormatTime(, "yyyyMMdd-HHmmss")
    filePath := backupDir "\" BuildRunArtifactFileName(prefix, timestamp)
    FileAppend text, filePath, "UTF-8"
    TestingLog("backup-saved", "Prefix=" prefix "; path=" filePath "; chars=" StrLen(text) ".")
}

