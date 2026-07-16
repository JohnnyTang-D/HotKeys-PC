; ============================================================
; Win+S — 启动/激活智谱清言
; ============================================================

#s:: {
    title := '智谱清言'
    if !WinExist(title) {
        Run(A_Desktop '\智谱清言.lnk')
        if !WinWait(title, , 5)
            return
    }
    if (WinGetMinMax(title) == -1) {
        WinRestore(title)
    }
    WinShow(title)
    WinActivate(title)
}
