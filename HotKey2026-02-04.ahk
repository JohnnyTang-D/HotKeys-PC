#Requires AutoHotkey v2.0
#SingleInstance Force ; 确保每次运行新实例时自动替换旧实例

; ---- Ahk2Exe 编译器指令，用于生成带属性信息的单个 exe ----
;@Ahk2Exe-SetName HotKey2026
;@Ahk2Exe-SetDescription HotKey 快捷键管理工具
;@Ahk2Exe-SetVersion 1.0.3
;@Ahk2Exe-SetCopyright Copyright (c) 2026

; ---- 基础库 (必须最先加载) ----
#Include "utils\utils.ahk"
#Include "utils\crypto.ahk"

; ---- 全局 GUI 控件声明，用于在回调函数中访问 ----
global helpGui := 0, LV2 := 0, LV3 := 0

; ---- 托盘自定义与双击动作绑定 ----
A_TrayMenu.Add("快捷键说明书", (*) => ShowHotkeyHelp())
A_TrayMenu.Default := "快捷键说明书"

; ---- 初始化读取快捷键启用状态 ----
state_F := GetHotkeyState("Win_F", "1")
state_W := GetHotkeyState("Win_W", "1")
state_V := GetHotkeyState("Win_V", "1")
state_C := GetHotkeyState("Win_C", "1")
state_Q := GetHotkeyState("Win_Q", "1")
state_S := GetHotkeyState("Win_S", "1")
state_Nav := GetHotkeyState("CapsLock_Nav", "1")
state_WebStorm := GetHotkeyState("App_WebStorm", "1")
state_MsEdge := GetHotkeyState("App_MsEdge", "1")

; 全局控制 CapsLock 导航及 App 热键是否启用的变量
global isCapsLockNavEnabled := (state_Nav == "1")
global isWebStormHotkeysEnabled := (state_WebStorm == "1")
global isMsEdgeHotkeysEnabled := (state_MsEdge == "1")

; 全局统一的快捷键说明数据集 (防格式/顺序错位重置 Bug)
global hotkeysData := [{ show: "Win + F", reg: "Win_F", hotkeyName: "#f", desc: "统一门户Token：账号选择并获取统一门户 Token 自动键入",
    state: state_F }, { show: "Win + W", reg: "Win_W", hotkeyName: "#w", desc: "测试运管Token：使用融亿办账号来获取测试运管 Token 自动键入",
        state: state_W }, { show: "Win + V", reg: "Win_V", hotkeyName: "#v", desc: "剪贴板：保存剪贴板历史记录并可供再次选择", state: state_V }, { show: "Win + C",
            reg: "Win_C", hotkeyName: "#c", desc: "快捷终端：启动 Windows Terminal 命令行终端", state: state_C }, { show: "Win + Q",
                reg: "Win_Q", hotkeyName: "#q", desc: "开发工具：快捷查看当前 Git用户 代码提交日志", state: state_Q }, { show: "Win + S",
                    reg: "Win_S", hotkeyName: "#s", desc: "AI 助手：快速唤起智谱清言 AI 对话窗口", state: state_S }, { show: "CapsLock + WASD",
                        reg: "CapsLock_Nav", hotkeyName: "CapsLock", desc: "光标导航：控制鼠标/光标 向上/左/下/右 导航移动", state: state_Nav }, { show: "WebStorm: Alt + D",
                            reg: "App_WebStorm", hotkeyName: "App_WebStorm", desc: "应用热键：在 WebStorm 内双击 Alt+D 快捷键入 debugger 调试语句",
                            state: state_WebStorm }, { show: "Edge: Ctrl+Shift+F", reg: "App_MsEdge", hotkeyName: "App_MsEdge",
                                desc: "应用热键：在 Microsoft Edge 浏览器内快速搜索已打开的标签页", state: state_MsEdge }
]

; 延时 10ms 等待静态热键声明完毕后应用初始状态，避免 AHK 加载顺序报错
SetTimer(ApplyInitialHotkeyStates, -10)

ShowHotkeyHelp() {
    global helpGui, hotkeysData
    if (helpGui != 0) {
        try helpGui.Destroy()
    }

    helpGui := Gui("+AlwaysOnTop +ToolWindow", "HotKey2026 — 快捷键说明书")
    helpGui.SetFont("s10.5", "Microsoft YaHei")

    ; 创建 Tab 选项卡控件，宽度放大三分之一至 750，高度至 370，共有 3 个 Tab 页
    MyTab := helpGui.Add("Tab3", "w750 h370", ["快捷键说明", "统一门户账号", "融亿办账号"])

    ; ---- Tab 1: 快捷键说明 ----
    MyTab.UseTab(1)

    ; 每次打开时，重新从配置文件读取各个热键当前的最新的状态
    for item in hotkeysData {
        item.state := GetHotkeyState(item.reg, "1")
    }

    ; 带 CheckBox 列表选项的 ListView，高宽相应按比例放大 (w730 h310)
    LV1 := helpGui.Add("ListView", "w730 h310 Grid -Multi Checked", ["快捷键", "功能描述"])

    for item in hotkeysData {
        checkOpt := (item.state == "1") ? "Check" : "-Check"
        LV1.Add(checkOpt, item.show, item.desc)
    }

    LV1.ModifyCol(1, 180)
    LV1.ModifyCol(2, 530)

    ; 绑定 CheckBox 改变事件
    LV1.OnEvent("ItemCheck", OnHotkeyCheck)

    ; ---- Tab 2: 统一门户账号 ----
    MyTab.UseTab(2)
    global LV2 := helpGui.Add("ListView", "w730 h260 Grid -Multi", ["用户名", "密码"])

    iniFile := GetConfigPath("credentials.ini")
    if FileExist(iniFile) {
        sectionsText := ""
        try sectionsText := IniRead(iniFile)
        if (sectionsText != "") {
            loop parse, sectionsText, "`n", "`r" {
                sec := Trim(A_LoopField)
                if (sec != "" && sec != "Hotkeys") {
                    u := IniRead(iniFile, sec, "username", sec)
                    p := IniRead(iniFile, sec, "password", "")
                    LV2.Add(, u, p)
                }
            }
        }
    }
    if (LV2.GetCount() == 0) {
        LV2.Add(, "暂无账户数据", "请添加新账号")
    }
    LV2.ModifyCol(1, 300)
    LV2.ModifyCol(2, 410)

    ; 统一门户管理按钮
    helpGui.Add("Button", "w120 y+8 x20", "添加账户").OnEvent("Click", (*) => ShowPortalEditDialog(false))
    helpGui.Add("Button", "w120 x+15", "修改账户").OnEvent("Click", (*) => ShowPortalEditDialog(true))
    helpGui.Add("Button", "w120 x+15", "删除账户").OnEvent("Click", DeletePortalAccount)

    ; ---- Tab 3: 融亿办账号 ----
    MyTab.UseTab(3)
    global LV3 := helpGui.Add("ListView", "w730 h260 Grid -Multi", ["用户名", "密码"])

    iniFileRongyiban := GetConfigPath("credentials_rongyiban.ini")

    if FileExist(iniFileRongyiban) {
        sectionsText := ""
        try sectionsText := IniRead(iniFileRongyiban)
        if (sectionsText != "") {
            loop parse, sectionsText, "`n", "`r" {
                sec := Trim(A_LoopField)
                if (sec != "") {
                    u := IniRead(iniFileRongyiban, sec, "username", "")
                    p := IniRead(iniFileRongyiban, sec, "password", "")
                    LV3.Add(, u, p)
                }
            }
        }
    }
    if (LV3.GetCount() == 0) {
        LV3.Add(, "暂无融亿办账户", "请配置 credentials_rongyiban.ini")
    }
    LV3.ModifyCol(1, 300)
    LV3.ModifyCol(2, 410)

    ; 融亿办管理按钮
    helpGui.Add("Button", "w140 y+8 x20", "添加/修改").OnEvent("Click", EditRongyibanAccount)
    helpGui.Add("Button", "w140 x+15", "删除账户").OnEvent("Click", DeleteRongyibanAccount)

    MyTab.UseTab()

    ; 确定按钮居中 (750宽度下居中)
    helpGui.Add("Button", "Default w100 x325 y+25", "确定").OnEvent("Click", (*) => helpGui.Destroy())
    helpGui.Show()
}

ApplyInitialHotkeyStates() {
    if (GetHotkeyState("Win_F", "1") == "0") {
        try Hotkey("#f", "Off")
    }
    if (GetHotkeyState("Win_W", "1") == "0") {
        try Hotkey("#w", "Off")
    }
    if (GetHotkeyState("Win_V", "1") == "0") {
        try Hotkey("#v", "Off")
    }
    if (GetHotkeyState("Win_C", "1") == "0") {
        try Hotkey("#c", "Off")
    }
    if (GetHotkeyState("Win_Q", "1") == "0") {
        try Hotkey("#q", "Off")
    }
    if (GetHotkeyState("Win_S", "1") == "0") {
        try Hotkey("#s", "Off")
    }
}

OnHotkeyCheck(LV, itemIndex, isChecked) {
    global hotkeysData
    iniFileHotkeys := A_ScriptDir "\config\config.ini"
    curItem := hotkeysData[itemIndex]
    curStateVal := isChecked ? "1" : "0"

    ; 保存至 ini
    IniWrite(curStateVal, iniFileHotkeys, "Hotkeys", curItem.reg)

    ; 动态启用 / 禁用
    if (curItem.reg == "CapsLock_Nav") {
        global isCapsLockNavEnabled := isChecked
    } else if (curItem.reg == "App_WebStorm") {
        global isWebStormHotkeysEnabled := isChecked
    } else if (curItem.reg == "App_MsEdge") {
        global isMsEdgeHotkeysEnabled := isChecked
    } else {
        try Hotkey(curItem.hotkeyName, isChecked ? "On" : "Off")
    }
}

DeletePortalAccount(*) {
    row := LV2.GetNext(0, "Focused")
    if (row == 0) {
        MsgBox("请先在列表中选中需要删除的账户行！", "提示", "Owner" . helpGui.Hwnd . " Icon!")
        return
    }
    u := LV2.GetText(row, 1)
    if (u == "暂无账户数据") {
        MsgBox("该行为提示信息，无法删除！", "提示", "Owner" . helpGui.Hwnd . " Icon!")
        return
    }
    if (MsgBox("确定要删除账户 [" u "] 的配置吗？", "确认删除", "Owner" . helpGui.Hwnd . " Icon? 260") == "Yes") {
        iniFile := GetConfigPath("credentials.ini")
        try IniDelete(iniFile, u)
        LV2.Delete(row)
        if (LV2.GetCount() == 0) {
            LV2.Add(, "暂无账户数据", "请添加新账号")
        }
    }
}

ShowPortalEditDialog(isEdit := false) {
    u := "", p := ""
    row := 0
    if (isEdit) {
        row := LV2.GetNext(0, "Focused")
        if (row == 0) {
            MsgBox("请先在列表中选中需要修改的账户行！", "提示", "Owner" . helpGui.Hwnd . " Icon!")
            return
        }
        u := LV2.GetText(row, 1)
        p := LV2.GetText(row, 2)
        if (u == "暂无账户数据") {
            MsgBox("该行为提示行，无法修改！", "提示", "Owner" . helpGui.Hwnd . " Icon!")
            return
        }
    }

    ; 禁用主窗口使得子窗口成为模态窗口
    helpGui.Opt("+Disabled")

    editGui := Gui("+Owner" . helpGui.Hwnd . " +ToolWindow", isEdit ? "修改密码" : "添加新账户")
    editGui.SetFont("s10", "Microsoft YaHei")

    editGui.Add("Text", "w80", "用户名:")
    optUser := isEdit ? "Disabled vUser w200" : "vUser w200"
    editGui.Add("Edit", optUser, u)

    editGui.Add("Text", "w80 y+10", "密码:")
    editGui.Add("Edit", "vPass w200", p)

    editGui.Add("Button", "Default w80 x50 y+15", "保存").OnEvent("Click", SavePortalInfo)
    editGui.Add("Button", "w80 x+20", "取消").OnEvent("Click", ClosePortalDialog)

    editGui.OnEvent("Close", ClosePortalDialog)

    ClosePortalDialog(*) {
        helpGui.Opt("-Disabled")
        editGui.Destroy()
    }

    SavePortalInfo(*) {
        vals := editGui.Submit(false) ; 不关闭子窗体
        usr := Trim(vals.User)
        pwd := Trim(vals.Pass)

        if (usr == "" || pwd == "") {
            MsgBox("用户名和密码不能为空！", "错误", "Owner" . editGui.Hwnd . " Icon!")
            return
        }

        iniFile := GetConfigPath("credentials.ini")
        try {
            IniWrite(usr, iniFile, usr, "username")
            IniWrite(pwd, iniFile, usr, "password")
        } catch Error as e {
            MsgBox("保存失败: " e.Message, "错误", "Owner" . editGui.Hwnd . " Iconx")
            return
        }

        if (isEdit) {
            LV2.Modify(row, , usr, pwd)
        } else {
            if (LV2.GetCount() == 1 && LV2.GetText(1, 1) == "暂无账户数据") {
                LV2.Delete(1)
            }
            LV2.Add(, usr, pwd)
        }
        ClosePortalDialog()
    }

    editGui.Show()
}

EditRongyibanAccount(*) {
    iniFileRongyiban := GetConfigPath("credentials_rongyiban.ini")
    u := "", p := ""
    if (LV3.GetCount() > 0 && LV3.GetText(1, 1) != "暂无融亿办账户") {
        u := LV3.GetText(1, 1)
        p := LV3.GetText(1, 2)
    }

    ; 禁用主窗口
    helpGui.Opt("+Disabled")

    ryGui := Gui("+Owner" . helpGui.Hwnd . " +ToolWindow", "编辑融亿办账户")
    ryGui.SetFont("s10", "Microsoft YaHei")

    ryGui.Add("Text", "w80", "用户名:")
    ryGui.Add("Edit", "vUser w200", u)

    ryGui.Add("Text", "w80 y+10", "密码:")
    ryGui.Add("Edit", "vPass w200", p)

    ryGui.Add("Button", "Default w80 x50 y+15", "保存").OnEvent("Click", SaveRyInfo)
    ryGui.Add("Button", "w80 x+20", "取消").OnEvent("Click", CloseRyDialog)

    ryGui.OnEvent("Close", CloseRyDialog)

    CloseRyDialog(*) {
        helpGui.Opt("-Disabled")
        ryGui.Destroy()
    }

    SaveRyInfo(*) {
        vals := ryGui.Submit(false)
        usr := Trim(vals.User)
        pwd := Trim(vals.Pass)

        if (usr == "" || pwd == "") {
            MsgBox("用户名和密码不能为空！", "错误", "Owner" . ryGui.Hwnd . " Icon!")
            return
        }

        try {
            IniWrite(usr, iniFileRongyiban, "ry", "username")
            IniWrite(pwd, iniFileRongyiban, "ry", "password")
        } catch Error as e {
            MsgBox("保存失败: " e.Message, "错误", "Owner" . ryGui.Hwnd . " Iconx")
            return
        }

        LV3.Delete()
        LV3.Add(, usr, pwd)
        CloseRyDialog()
    }

    ryGui.Show()
}

DeleteRongyibanAccount(*) {
    if (LV3.GetCount() == 0 || LV3.GetText(1, 1) == "暂无融亿办账户") {
        MsgBox("当前无融亿办账户可删除！", "提示", "Owner" . helpGui.Hwnd . " Icon!")
        return
    }
    if (MsgBox("确定要删除融亿办账户配置 [ry] 吗？", "确认删除", "Owner" . helpGui.Hwnd . " Icon? 260") == "Yes") {
        iniFileRongyiban := GetConfigPath("credentials_rongyiban.ini")
        try IniDelete(iniFileRongyiban, "ry")
        LV3.Delete()
        LV3.Add(, "暂无融亿办账户", "请配置 credentials_rongyiban.ini")
    }
}

; ---- 全局热键 ----
#Include "lib\hotkey\hotkey_disabled.ahk"
#Include "lib\hotkey\hotkey_token.ahk"
#Include "lib\hotkey\hotkey_rongyiban.ahk"
#Include "lib\hotkey\hotkey_clipboard.ahk"
#Include "lib\hotkey\hotkey_terminal.ahk"
#Include "lib\hotkey\hotkey_gitlog.ahk"
#Include "lib\hotkey\hotkey_launcher.ahk"

; ---- 应用窗口热键 ----
#Include "lib\app\app_webstorm.ahk"
#Include "lib\app\app_msedge.ahk"

; ---- CapsLock 导航 (必须最后加载，使用 #HotIf) ----
#Include "lib\hotkey\capslock_nav.ahk"