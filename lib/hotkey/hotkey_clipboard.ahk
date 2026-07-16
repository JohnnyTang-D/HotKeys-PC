; ============================================================
; Win+V — 剪贴板内容保存为文件
; 依赖: lib/utils.ahk (FileToClipboard)
; ============================================================

#v:: {
    content := A_Clipboard
    Folder := DirSelect("::{20D04FE0-3AEA-1069-A2D8-08002B30309D}")
    if (Folder = "")
        return
    IB := InputBox("请输入文件名(不含后缀):", "保存剪贴板内容")
    if IB.Result != "Cancel" {
        fileName := Folder . '\' . IB.Value . '.txt'
        if FileExist(fileName) {
            FileDelete(fileName)
        }
        FileAppend(content, fileName, "`n UTF-8")
        FileToClipboard(fileName)
    }
}
