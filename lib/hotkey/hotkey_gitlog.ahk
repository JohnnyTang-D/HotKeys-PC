; ============================================================
; Win+Q — Git 日志查询 (按日期范围)
; 弹出日期选择器，构造 git log 命令并发送到终端
; ============================================================

#q:: {
    prev_hwnd := WinExist("A")

    gitAuthor := GetSetting("gitAuthor")
    if (gitAuthor == "") {
        MsgBox("Git 作者未配置，请先在 config.ini 中配置 Settings/gitAuthor！", "提示", "Icon!")
        return
    }

    g := Gui(, "选择起始日期")
    g.Opt("+AlwaysOnTop")
    g.SetFont("s10", "Microsoft YaHei")
    g.Add("Text", , "请选择起始日期:")
    g.Add("DateTime", "vStartDate w220", "yyyy-MM-dd")
    g.Add("Button", "Default w80 x75 y+15", "确定").OnEvent("Click", ConfirmDate)
    g.Show()

    ConfirmDate(*) {
        saved := g.Submit()
        sDate := saved.StartDate
        eDate := DateAdd(sDate, 1, "days")
        startStr := FormatTime(sDate, "yyyy-MM-dd")
        endStr := FormatTime(eDate, "yyyy-MM-dd")
        git_command := 'git --no-pager log --all --author="' gitAuthor '" --since="' startStr ' 09:00" --until="' endStr ' 09:00" --pretty=format:"%B" --no-merges'
        if WinExist("ahk_id " prev_hwnd) {
            WinActivate("ahk_id " prev_hwnd)
            WinWaitActive("ahk_id " prev_hwnd, , 1)
        }
        SendInput(git_command)
    }
}
