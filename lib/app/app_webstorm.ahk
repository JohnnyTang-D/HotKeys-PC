; ============================================================
; webstorm64.exe 窗口内热键映射
; Alt+D 双击 → 输入 debugger
; 受全局变量 isWebStormHotkeysEnabled 与窗口激活状态联合控制
; ============================================================

#HotIf (isWebStormHotkeysEnabled && WinActive("ahk_exe webstorm64.exe"))
!d::
{
    DoubleTapDeb('debugger')
}
#HotIf

; 双击检测函数 (400ms 内按两次触发)
DoubleTapDeb(val) {
    static last := 0
    if (A_TickCount - last < 400) {
        printDeb(val)
        last := 0
    } else {
        last := A_TickCount
    }
}

; 延迟发送文本
printDeb(val) {
    Sleep(200)
    SendInput(val)
}
