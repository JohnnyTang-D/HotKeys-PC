; 标题与展示策略统一在此维护，业务流程只更新当前阶段。
GetRongyibanErrorTitle(stage) {
    static titles := Map("config", "融亿办配置不完整", "captcha", "获取 Captcha UUID 异常",
        "image", "下载验证码图片失败", "recognize", "大模型识别验证码请求失败",
        "login", "登录获取 JWT 失败", "exchange", "转换测试 Token 失败", "output", "输出测试 Token 失败")
    return titles.Has(stage) ? titles[stage] : "获取测试 Token 失败"
}

ShowRongyibanError(context, err) {
    stage := GetRongyibanErrorTitle(context.stage)
    diagnostics := context.diagnostics
    captchaPreview := (context.stage == "recognize" || context.stage == "login") ? context.captchaPreview : ""
    summary := ""
    for entry in diagnostics
        summary .= entry "`n"
    ; 日志只保存阶段与元数据；后端错误仅在弹窗中展示。
    logPath := A_Temp "\hotkeys-win-w.log"
    logHint := "诊断日志：" logPath
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " stage "`n" summary "`n", logPath, "UTF-8")
    catch
        logHint := "诊断日志写入失败，请保留此弹窗截图。"
    details := stage "：`n`n" err.Message "`n`n" summary "`n" logHint
    if !IsObject(captchaPreview) {
        MsgBox(details, "提示", "Icon!")
        return
    }

    preview := Gui("+AlwaysOnTop", "验证码失败对照")
    preview.SetFont("s10", "Microsoft YaHei")
    preview.Add("Text", "w620", "本次验证码图片（与发送给模型的图片相同）：")
    try {
        ; 仅失败时保存原始图片，不重新下载，避免验证码变化影响对照。
        imagePath := A_Temp "\hotkeys-win-w-captcha-" A_Now "-" A_TickCount ".png"
        stream := ComObject("ADODB.Stream")
        stream.Type := 1
        stream.Open()
        try {
            stream.Write(captchaPreview.image)
            stream.SaveToFile(imagePath, 1)
        } finally {
            stream.Close()
        }
        preview.Add("Picture", "w240 h-1", imagePath)
        preview.Add("Edit", "w620 r2 ReadOnly", "图片文件：" imagePath)
    } catch Error as imageError {
        preview.Add("Edit", "w620 r2 ReadOnly", "验证码图片显示失败：" imageError.Message)
    }
    preview.Add("Text", "w620", "模型原始输出（未裁剪；空白、换行均保留）：")
    preview.Add("Edit", "w620 r4 ReadOnly", captchaPreview.rawText)
    preview.Add("Text", "w620", captchaPreview.hasModelText
        ? "原始长度：" StrLen(captchaPreview.rawText) "；去除首尾空白后长度：" StrLen(Trim(captchaPreview.rawText))
            : "未取得模型输出，详情见下方错误。")
    preview.Add("Edit", "w620 r12 ReadOnly", details)
    preview.Add("Button", "w90 Default", "关闭").OnEvent("Click", (*) => preview.Destroy())
    preview.OnEvent("Close", (*) => preview.Destroy())
    preview.OnEvent("Escape", (*) => preview.Destroy())
    preview.Show()
}
