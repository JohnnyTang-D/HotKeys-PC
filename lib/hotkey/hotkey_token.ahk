; ============================================================
; Win+F — 账号选择 & Token 获取
; 依赖: utils/crypto.ahk (DES_CBC_Encrypt, UrlEncode)
;        lib/utils.ahk  (JSON_parse)
; 数据: credentials.ini (自动创建于脚本目录)
; ============================================================

#f:: {
    iniFile := GetConfigPath('credentials.ini')
    portalTokenUrl := GetSetting("portalTokenUrl")
    portalClientId := GetSetting("portalClientId")
    if (portalTokenUrl == "" || portalClientId == "") {
        MsgBox("统一门户接口配置不完整，请先在 config.ini 中配置 Settings/portalTokenUrl 和 portalClientId！", "提示", "Icon!")
        return
    }

    if !FileExist(iniFile) {
        ; 如果本地不存在配置文件，则将编译打包的初始 credentials.ini 释放到同级目录
        ; 这样既可以作为初始模版，又避免了运行中覆盖用户已修改的数据
        FileInstall 'config\credentials.ini', iniFile, false
    }

    g := Gui(, "获取Token - 选择账号")
    g.Opt("+AlwaysOnTop")
    g.SetFont("s10", "Microsoft YaHei")

    g.Add("Text", , "选择账号:")
    cb := g.Add("ComboBox", "vSelectedName w250")

    ; 刷新下拉列表
    RefreshCombo(cb, iniFile) {
        cb.Delete()
        sectionNames := IniRead(iniFile)
        count := 0
        for name in StrSplit(StrReplace(sectionNames, "`r", ""), "`n") {
            if (name != "") {
                cb.Add([name])
                count++
            }
        }
        if (count > 0) {
            cb.Choose(1) ; 默认选中第一个账号
        }
    }
    RefreshCombo(cb, iniFile)

    ; 获取账号凭据
    GetAccountCred(name, iniFile) {
        u := GetCredential("credentials.ini", name, "username")
        p := GetCredential("credentials.ini", name, "password")
        return { username: u, password: p }
    }

    ; 确定按钮 - 调用API获取token
    btnOK := g.Add("Button", "Default w80 x75 y+15", "确定")
    btnOK.OnEvent("Click", GetToken)
    GetToken(*) {
        saved := g.Submit()
        selectedName := saved.SelectedName
        if (selectedName == "") {
            MsgBox("请先选择或添加一个账号")
            return
        }
        creds := GetAccountCred(selectedName, iniFile)
        if (creds.username == "" || creds.password == "") {
            MsgBox("账号信息不完整，请重新添加")
            return
        }
        g.Destroy()
        encUser := UrlEncode(DES_CBC_Encrypt(creds.username))
        encPass := UrlEncode(DES_CBC_Encrypt(creds.password))
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        requestUrl := portalTokenUrl . "?username=" . encUser . "&password=" . encPass . "&client_id=" . portalClientId
        whr.Open("GET", requestUrl, false)
        whr.SetRequestHeader("User-Agent",
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0'
        )
        whr.Send()
        Sleep(150)
        
        try {
            resObj := JSON_parse(whr.ResponseText)
            flag := ""
            try flag := resObj.flag
            
            if (flag == "T") {
                SendTextViaClipboard(resObj.data.refresh_token)
            } else {
                ; 接口失败时，安全读取 errorInfo 或 data 字符串以展示错误原因
                errMsg := "未知错误"
                try errMsg := resObj.errorInfo
                if (errMsg == "" || errMsg == "未知错误") {
                    try errMsg := resObj.data
                }
                MsgBox("获取 Token 失败：`n`n" errMsg)
            }
        } catch Error as e {
            MsgBox("解析接口数据异常：`n`n" e.Message "`n`n接口返回：" whr.ResponseText)
        }
    }

    ; 添加账号按钮
    btnAdd := g.Add("Button", "w80 x+10 yp", "添加账号")
    btnAdd.OnEvent("Click", AddAccount)
    AddAccount(*) {
        ag := Gui(, "添加账号")
        ag.Opt("+AlwaysOnTop +Owner" g.Hwnd)
        ag.SetFont("s10", "Microsoft YaHei")

        ag.Add("Text", , "Username:")
        ag.Add("Edit", "vAccUser w300")

        ag.Add("Text", , "Password:")
        ag.Add("Edit", "vAccPass w300 Password")

        ag.Add("Button", "Default w80 x120 y+15", "保存").OnEvent("Click", SaveAccount)
        ag.Show()

        SaveAccount(*) {
            saved := ag.Submit()
            if (saved.AccUser == "") {
                MsgBox("Username 不能为空")
                return
            }
            IniWrite(saved.AccUser, iniFile, saved.AccUser, "username")
            IniWrite(saved.AccPass, iniFile, saved.AccUser, "password")
            ag.Destroy()
            RefreshCombo(cb, iniFile)
        }
    }

    ; 删除账号按钮
    btnDel := g.Add("Button", "w80 x+10 yp", "删除账号")
    btnDel.OnEvent("Click", DeleteAccount)
    DeleteAccount(*) {
        saved := g.Submit()
        selectedName := saved.SelectedName
        if (selectedName == "") {
            MsgBox("请先选择一个账号")
            return
        }
        result := MsgBox("确定要删除账号 '" selectedName "' 吗？", "确认删除", "YesNo")
        if (result == "Yes") {
            IniDelete(iniFile, selectedName)
            RefreshCombo(cb, iniFile)
        }
    }

    g.Show()
}
