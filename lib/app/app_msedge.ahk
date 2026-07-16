; ============================================================
; msedge.exe 窗口内热键映射
; Ctrl+Shift+F → 搜索标签页
; 受全局变量 isMsEdgeHotkeysEnabled 与窗口激活状态联合控制
; ============================================================

#HotIf (isMsEdgeHotkeysEnabled && WinActive("ahk_exe msedge.exe"))
^+f::
{
    searchTab()
}
#HotIf

searchTab() {
    SendInput('^+a')
}
