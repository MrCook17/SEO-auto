EnumerateBotzImageFiles(imagesDir, maximumCount := 0) {
    files := []
    Loop Files imagesDir "\*", "F" {
        if RegExMatch(A_LoopFileName, "i)\.(jpe?g|png|webp)$")
            files.Push(A_LoopFileFullPath)
    }
    NaturalSortBotzPaths(files)
    while maximumCount > 0 && files.Length > maximumCount
        files.Pop()
    return files
}

TakeFirstBotzImageFiles(imageFiles, maximumCount) {
    if maximumCount < 0
        throw Error("The supplier image limit cannot be negative.")
    limitedFiles := []
    count := maximumCount = 0 ? imageFiles.Length : Min(imageFiles.Length, maximumCount)
    Loop count
        limitedFiles.Push(imageFiles[A_Index])
    return limitedFiles
}

BuildBotzImageManifest(imageFiles) {
    manifest := []
    for _, imagePath in imageFiles {
        manifest.Push(Map(
            "path", imagePath,
            "size", FileGetSize(imagePath),
            "modified", FileGetTime(imagePath, "M")
        ))
    }
    return manifest
}

NaturalSortBotzPaths(paths) {
    Loop paths.Length {
        i := A_Index
        if i = 1
            continue
        current := paths[i]
        j := i - 1
        while j >= 1 && CompareBotzPathsNaturally(paths[j], current) > 0 {
            paths[j + 1] := paths[j]
            j -= 1
        }
        paths[j + 1] := current
    }
    return paths
}

CompareBotzPathsNaturally(pathA, pathB) {
    SplitPath pathA, &nameA
    SplitPath pathB, &nameB
    result := DllCall("Shlwapi.dll\StrCmpLogicalW", "Str", nameA, "Str", nameB, "Int")
    return result != 0 ? result : StrCompare(pathA, pathB, false)
}

ValidateBotzCtrlAImageFolder(imagesDir, imageFiles, supplierName := "BOTZ") {
    expected := Map()
    for _, imagePath in imageFiles
        expected[StrLower(imagePath)] := true

    foundCount := 0
    expectedFoundCount := 0
    Loop Files imagesDir "\*", "FD" {
        if InStr(A_LoopFileAttrib, "D")
            throw Error("The " supplierName " images folder contains a subfolder, so Ctrl+A could select the wrong item: " A_LoopFileFullPath)
        if !RegExMatch(A_LoopFileName, "i)\.(jpe?g|png|webp)$")
            throw Error("The " supplierName " images folder contains an unsupported file, so Ctrl+A was not used: " A_LoopFileFullPath)
        if expected.Has(StrLower(A_LoopFileFullPath))
            expectedFoundCount += 1
        foundCount += 1
    }
    if expectedFoundCount != imageFiles.Length
        throw Error("Image-folder validation found only " expectedFoundCount " of the " imageFiles.Length " expected " supplierName " images.")
    if foundCount < imageFiles.Length
        throw Error("Image-folder validation found fewer files than the " supplierName " request expects.")
    return foundCount = imageFiles.Length
}

BotzPathArraysMatch(pathsA, pathsB) {
    if pathsA.Length != pathsB.Length
        return false
    Loop pathsA.Length {
        if StrLower(pathsA[A_Index]) != StrLower(pathsB[A_Index])
            return false
    }
    return true
}

