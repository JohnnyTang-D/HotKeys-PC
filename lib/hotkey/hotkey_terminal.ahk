; ============================================================
; Win+C — 打开/激活 Windows Terminal
; ============================================================

#c:: {
    currdir := EnvGet("USERPROFILE")
    title := 'ahk_exe WindowsTerminal.exe'
    oldDetect := DetectHiddenWindows(true)
    if WinExist(title) {
        WinShow(title)
        WinActivate(title)
        WinSetAlwaysOnTop(True, title)
        WinSetAlwaysOnTop(False, title)
    } else {
        Run("wt", currdir)
        if WinWait(title, , 5) {
            WinSetAlwaysOnTop(True, title)
            WinSetAlwaysOnTop(False, title)
        }
    }
    DetectHiddenWindows(oldDetect)
}
