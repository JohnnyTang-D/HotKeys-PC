; ============================================================
; 工具函数模块
; 提供 JSON 解析、文件到剪贴板、鼠标坐标等通用能力
; ============================================================

; 调用开源标准库 lib/JSON.ahk 进行解析与序列化
JSON_parse(src) {
    if (src == "")
        return ""
    try {
        return JSON.parse(src)
    } catch {
        return ""
    }
}

JSON_stringify(val) {
    return JSON.stringify(val)
}

; 统一安全提取对象/Map/Array中的值（支持多级链式提取，不存在或类型不符时安全返回空字符串）
GetJsonVal(target, keys*) {
    curr := target
    for k in keys {
        if !IsObject(curr)
            return ""
        if (curr is Map) {
            if curr.Has(k)
                curr := curr[k]
            else
                return ""
        } else if (curr is Array) {
            if (IsNumber(k) && k >= 1 && k <= curr.Length)
                curr := curr[k]
            else
                return ""
        } else if (curr is Object) {
            if HasProp(curr, k)
                curr := curr.%k%
            else
                return ""
        } else {
            return ""
        }
    }
    return IsObject(curr) ? curr : String(curr)
}

; 将文件路径复制为剪贴板文件（支持资源管理器粘贴）
FileToClipboard(PathToCopy) {
    loop files, PathToCopy
        PathToCopy := A_LoopFileFullPath
    hPath := DllCall("GlobalAlloc", "UInt", 0x42, "UInt", 20 + (StrPut(PathToCopy) + 22), "UPtr")
    pPath := DllCall("GlobalLock", "Ptr", hPath, "UPtr")
    NumPut("UInt", 20, pPath)
    NumPut("UInt", 1, pPath, 16)
    StrPut(PathToCopy, pPath + 20)
    DllCall("GlobalUnlock", "UPtr", hPath)
    DllCall("OpenClipboard", "Ptr", 0)
    DllCall("EmptyClipboard")
    DllCall("SetClipboardData", "UInt", 0xF, "Ptr", hPath)
    DllCall("CloseClipboard")
}

; 获取当前鼠标相对于指定窗口的位置
GetClientMousePos(title) {
    CoordMode('Mouse', 'Screen')
    winX := 0
    winY := 0
    WinGetPos(&winX, &winY, &title)
    return {
        x: winX,
        y: winY,
    }
}

; 获取配置文件的正确路径（支持从 exe 所在的 dist/ 目录自动向上回退到项目根目录寻找）
GetConfigPath(fileName) {
    path := A_ScriptDir "\config"
    if !DirExist(path) && DirExist(A_ScriptDir "\..\config") {
        path := A_ScriptDir "\..\config"
    }
    return path . "\" . fileName
}

; 兼容 UTF-8 (包含无 BOM) 编码读取 INI 指定配置项，解决 Windows 原生 API (IniRead) 读取无 BOM 的 UTF-8 文件时发生的中文乱码问题
ReadIniUTF8(iniFile, section, key, default := "") {
    if !FileExist(iniFile)
        return default

    try {
        content := FileRead(iniFile, "UTF-8")
        currentSec := ""
        targetSec := StrLower(Trim(section))
        targetKey := StrLower(Trim(key))

        loop parse, content, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line == "" || SubStr(line, 1, 1) == ";" || SubStr(line, 1, 1) == "#")
                continue

            if (SubStr(line, 1, 1) == "[" && SubStr(line, -1) == "]") {
                currentSec := StrLower(Trim(SubStr(line, 2, StrLen(line) - 2)))
                continue
            }

            if (currentSec == targetSec) {
                eqPos := InStr(line, "=")
                if (eqPos > 1) {
                    k := StrLower(Trim(SubStr(line, 1, eqPos - 1)))
                    if (k == targetKey) {
                        val := Trim(SubStr(line, eqPos + 1))
                        ; 移除行尾以空格+分号分隔的注释
                        semiPos := InStr(val, A_Space Chr(59))
                            if (semiPos > 0) {
                                val := Trim(SubStr(val, 1, semiPos - 1))
                            }
                            return val
                        }
                    }
                }
            }
        }

        ; 若文本解析未匹配到，尝试使用原生 IniRead 兜底
        try {
            return IniRead(iniFile, section, key, default)
        } catch {
            return default
        }
    }

    ; 从 config.ini 读取 [Settings] 小节的配置值
    GetSetting(key, default := "") {
        iniFile := GetConfigPath("config.ini")
        return ReadIniUTF8(iniFile, "Settings", key, default)
    }

    ; 从 config.ini 读取 [Hotkeys] 小节的配置值
    GetHotkeyState(key, default := "1") {
        iniFile := GetConfigPath("config.ini")
        return ReadIniUTF8(iniFile, "Hotkeys", key, default)
    }

    ; 从指定凭据文件读取配置值
    GetCredential(iniFileName, section, key, default := "") {
        iniFile := GetConfigPath(iniFileName)
        return ReadIniUTF8(iniFile, section, key, default)
    }

    ; 使用剪贴板安全、秒速发送长文本（可完美免疫任何中文输入法拦截与管理员权限隔离）
    SendTextViaClipboard(text) {
        savedClip := ClipboardAll() ; 备份用户当前剪贴板的完整内容（包含图片、格式等二进制数据）
        A_Clipboard := ""           ; 清空剪贴板以供等待
        A_Clipboard := text
        if ClipWait(1) {
            SendInput("^v")         ; 发送 Ctrl + V 粘贴
            Sleep(150)              ; 稍微等待目标程序完成粘贴接收，防止提前还原剪贴板
        }
        A_Clipboard := savedClip    ; 还原剪贴板
    }
