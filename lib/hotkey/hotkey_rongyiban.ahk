; ============================================================
; Win+W — 内网 自动登录并获取 JWT Token 后转换为测试 Token
; ============================================================

#w:: {
    ; 读取账号密码
    u := GetCredential("credentials_rongyiban.ini", "ry", "username")
    p := GetCredential("credentials_rongyiban.ini", "ry", "password")
    if (u == "" || p == "") {
        MsgBox("融亿办账号或密码未配置，请先在快捷键说明书中配置融亿办账号密码！", "提示", "Icon!")
        return
    }

    ; 读取大模型 API Key 以及接口基地址配置
    apiKey := GetSetting("apiKey")
    rongyibanBaseUrl := GetSetting("rongyibanBaseUrl")
    if (apiKey == "") {
        MsgBox("大模型 API Key 未配置，请先在 config.ini 中配置 Settings/apiKey！", "提示", "Icon!")
        return
    }
    if (rongyibanBaseUrl == "") {
        MsgBox("融亿办接口基地址未配置，请先在 config.ini 中配置 Settings/rongyibanBaseUrl！", "提示", "Icon!")
        return
    }

    ; 1. 获取 Captcha UUID
    try {
        resText := RongyibanRequest("GET", "/captcha/pcruuid")
        parsedObj := JSON_parse(resText)
        captchaUuid := GetJsonVal(parsedObj, "data", "captchaUuid")
    } catch Error as e {
        MsgBox("获取 Captcha UUID 异常：`n`n" e.Message, "错误", "Icon!")
        return
    }

    ; 2. 获取验证码图片数据并转换为 Base64
    try {
        imgData := RongyibanRequest("GET", "/captcha/pcrimg/" . captchaUuid, , , true)
        cleanBase64 := BinToBase64(imgData)
    } catch Error as e {
        MsgBox("下载验证码图片失败：`n`n" e.Message, "错误", "Icon!")
        return
    }

    ; 3. 调用大模型识别验证码
    try {
        imageUrlVal := "data:image/png;base64," . cleanBase64
        payload := JSON_stringify({
            model: "glm-4v-flash",
            messages: [{
                role: "user",
                content: [{ type: "image_url", image_url: { url: imageUrlVal } }, { type: "text", text: "请分析这张图片的4位验证码,直接给出结果" }]
            }]
        })
        resModelText := SendHttpRequest("POST", "https://open.bigmodel.cn/api/paas/v4/chat/completions",
            Map("Content-Type", "application/json", "Authorization", "Bearer " . apiKey), payload)

        resModelObj := JSON_parse(resModelText)
        captchaVal := Trim(GetJsonVal(resModelObj, "choices", 1, "message", "content"))
    } catch Error as e {
        MsgBox("大模型识别验证码请求失败：`n`n" e.Message, "错误", "Icon!")
        return
    }

    ; 4. 模拟登录并获取 JWT Token
    try {
        cipher := AES_ECB_Encrypt(p, "www.easipass.com")
        loginPayload := JSON_stringify({
            loginId: u,
            password: cipher,
            captchaVal: captchaVal,
            captchaUuid: captchaUuid,
            fingerprint: "lYUB2dUYQZg1WI2wiQZseUCLR3FJPLy6CxzuiR2g6IqH/0E4SlCvd9aYlfkd8O7D"
        })
        resLoginText := RongyibanRequest("POST", "/auth/login?captchaVal=" . captchaVal . "&captchaUuid=" . captchaUuid,
            Map("Content-Type", "application/json"), loginPayload)

        resLoginObj := JSON_parse(resLoginText)
        jwtToken := GetJsonVal(resLoginObj, "data")

        if (jwtToken == "" || InStr(jwtToken, "JWT-") != 1) {
            errInfo := GetJsonVal(resLoginObj, "errorInfo")
            if (errInfo == "")
                errInfo := GetJsonVal(resLoginObj, "message")
            if (errInfo == "")
                errInfo := resLoginText
            MsgBox("登录获取 JWT 失败：`n`n" errInfo "`n`n接口返回：" resLoginText, "提示", "Icon!")
            return
        }
    } catch Error as e {
        MsgBox("登录接口请求异常：`n`n" e.Message, "错误", "Icon!")
        return
    }

    ; 5. 使用 JWT Token 换取测试 Token (trans-test-token)
    try {
        resTransText := RongyibanRequest("GET", "/auth/trans-test-token", Map("cm-authorization", jwtToken))
        resTransObj := JSON_parse(resTransText)
        testToken := GetJsonVal(resTransObj, "data")

        if (testToken != "" && InStr(testToken, "JWT-") == 1) {
            SendTextViaClipboard(testToken)
        } else {
            errTrans := GetJsonVal(resTransObj, "errorInfo")
            if (errTrans == "")
                errTrans := GetJsonVal(resTransObj, "message")
            if (errTrans == "")
                errTrans := resTransText
            MsgBox("转换测试 Token 失败：`n`n" errTrans "`n`n接口返回：" resTransText, "提示", "Icon!")
        }
    } catch Error as e {
        MsgBox("调用转换测试 Token 接口异常：`n`n" e.Message, "错误", "Icon!")
    }
}

; ------------------------------------------------------------
; 辅助请求与转换函数
; ------------------------------------------------------------

; 基础网络请求封装
SendHttpRequest(method, url, headers := "", body := "", returnBinary := false) {
    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    try whr.Option[4] := 0x3300 ; 忽略自签名 SSL 证书错误
    whr.Open(method, url, false)
    if (IsObject(headers)) {
        for k, v in headers {
            whr.SetRequestHeader(k, v)
        }
    }
    whr.Send(body)
    return returnBinary ? whr.ResponseBody : whr.ResponseText
}

; 融亿办内部接口封装
RongyibanRequest(method, path, headers := "", body := "", returnBinary := false) {
    baseUrl := GetSetting("rongyibanBaseUrl")
    return SendHttpRequest(method, baseUrl . path, headers, body, returnBinary)
}

; 二进制 SafeArray 转 Base64
BinToBase64(binData) {
    if IsObject(binData) && (binData is ComValue) {
        pSA := ComObjValue(binData)
        ubound := 0
        if DllCall("oleaut32\SafeArrayGetUBound", "Ptr", pSA, "UInt", 1, "Int*", &ubound) == 0 {
            cbData := ubound + 1
            pData := 0
            if DllCall("oleaut32\SafeArrayAccessData", "Ptr", pSA, "Ptr*", &pData) == 0 {
                cbBase64 := 0
                DllCall("crypt32\CryptBinaryToString", "Ptr", pData, "UInt", cbData, "UInt", 0x40000001, "Ptr", 0,
                    "UInt*", &cbBase64)
                base64Buf := Buffer(cbBase64 * 2)
                DllCall("crypt32\CryptBinaryToString", "Ptr", pData, "UInt", cbData, "UInt", 0x40000001, "Ptr",
                    base64Buf, "UInt*", &cbBase64)
                DllCall("oleaut32\SafeArrayUnaccessData", "Ptr", pSA)
                return StrReplace(StrReplace(StrGet(base64Buf, "UTF-16"), "`r", ""), "`n", "")
            }
        }
    }
    try {
        xml := ComObject("MSXML2.DOMDocument.6.0")
        elem := xml.createElement("tmp")
        elem.dataType := "bin.base64"
        elem.nodeTypedValue := binData
        return StrReplace(StrReplace(elem.text, "`r", ""), "`n", "")
    } catch {
        return ""
    }
}
