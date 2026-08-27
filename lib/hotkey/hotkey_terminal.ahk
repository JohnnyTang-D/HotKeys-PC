; ============================================================
; Win+C — 在当前资源管理器目录打开 Windows Terminal
; ============================================================

#c:: {
    currdir := EnvGet("USERPROFILE")
    activeHwnd := WinExist("A")

    ; 当前焦点在资源管理器时，读取该窗口正在浏览的目录。
    for explorerWindow in ComObject("Shell.Application").Windows {
        try {
            if (explorerWindow.HWND == activeHwnd) {
                currdir := explorerWindow.Document.Folder.Self.Path
                break
            }
        }
    }

    ; -d 会在已存在的 Windows Terminal 中新建标签页，并以指定目录作为工作目录。
    Run(Format('wt -d "{1}"', currdir))
}
