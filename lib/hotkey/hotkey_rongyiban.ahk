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

    ; 1. 初始化 COM htmlfile 用于执行 JScript 提取与结构化 JSON 序列化
    js := ComObject("htmlfile")
    js.write('<meta http-equiv="X-UA-Compatible" content="IE=edge">')
    js.parentWindow.execScript("
    (LTrim
        function getCaptchaVal(jsonStr) {
            try {
                var obj = JSON.parse(jsonStr);
                return obj.choices[0].message.content.trim();
            } catch(e) { return ''; }
        }
        function getJwtToken(jsonStr) {
            try {
                var obj = JSON.parse(jsonStr);
                return obj.data;
            } catch(e) { return ''; }
        }
        function buildPayload(imageUrl, prompt) {
            var payload = {
                model: 'glm-4v-flash',
                messages: [{
                    role: 'user',
                    content: [
                        { type: 'image_url', image_url: { url: imageUrl } },
                        { type: 'text', text: prompt }
                    ]
                }]
            };
            return JSON.stringify(payload);
        }
        function buildLoginPayload(loginId, password, captchaVal, captchaUuid, fingerprint) {
            var payload = {
                loginId: loginId,
                password: password,
                captchaVal: captchaVal,
                captchaUuid: captchaUuid,
                fingerprint: fingerprint
            };
            return JSON.stringify(payload);
        }
    )",
    "JScript")

    ; 2. 获取 Captcha UUID
    try {
        resText := RongyibanRequest("GET", "/captcha/pcruuid")
        captchaUuid := JSON_parse(resText).data.captchaUuid
    } catch Error as e {
        MsgBox("获取 Captcha UUID 失败：`n`n" e.Message)
        return
    }

    ; 3. 获取验证码图片数据并转换为 Base64
    try {
        imgData := RongyibanRequest("GET", "/captcha/pcrimg/" . captchaUuid, , , true)
        cleanBase64 := BinToBase64(imgData)
    } catch Error as e {
        MsgBox("下载验证码图片失败：`n`n" e.Message)
        return
    }

    ; 4. 调用大模型识别验证码
    try {
        imageUrlVal := "data:image/png;base64," . cleanBase64
        payload := js.parentWindow.buildPayload(imageUrlVal, "请分析这张图片的4位验证码,直接给出结果")
        resModelText := SendHttpRequest("POST", "https://open.bigmodel.cn/api/paas/v4/chat/completions", 
            Map("Content-Type", "application/json", "Authorization", "Bearer " . apiKey), payload)

        captchaVal := js.parentWindow.getCaptchaVal(resModelText)
        if (captchaVal == "") {
            MsgBox("大模型返回数据解析为空，返回数据：`n`n" resModelText)
            return
        }
    } catch Error as e {
        MsgBox("大模型识别验证码请求失败：`n`n" e.Message)
        return
    }

    ; 5. 模拟登录并获取 JWT Token
    try {
        cipher := AES_ECB_Encrypt(p, "www.easipass.com")
        loginPayload := js.parentWindow.buildLoginPayload(
            u, cipher, captchaVal, captchaUuid,
            "lYUB2dUYQZg1WI2wiQZseUCLR3FJPLy6CxzuiR2g6IqH/0E4SlCvd9aYlfkd8O7D"
        )
        resLoginText := RongyibanRequest("POST", "/auth/login?captchaVal=" . captchaVal . "&captchaUuid=" . captchaUuid,
            Map("Content-Type", "application/json"), loginPayload)

        jwtToken := js.parentWindow.getJwtToken(resLoginText)
        if (jwtToken == "" || InStr(jwtToken, "JWT-") != 1) {
            errInfo := "未知错误"
            try {
                resLoginObj := JSON_parse(resLoginText)
                if (resLoginObj.errorInfo != "")
                    errInfo := resLoginObj.errorInfo
                else if (resLoginObj.message != "")
                    errInfo := resLoginObj.message
            }
            MsgBox("登录获取 JWT 失败：`n`n" errInfo "`n`n接口返回：" resLoginText)
            return
        }
    } catch Error as e {
        MsgBox("登录接口请求异常：`n`n" e.Message)
        return
    }

    ; 6. 使用 JWT Token 换取测试 Token (trans-test-token)
    try {
        resTransText := RongyibanRequest("GET", "/auth/trans-test-token", Map("cm-authorization", jwtToken))
        resTransObj := JSON_parse(resTransText)
        testToken := ""
        try testToken := resTransObj.data

        if (testToken != "" && InStr(testToken, "JWT-") == 1) {
            SendText(testToken)
        } else {
            errTrans := "转换测试 Token 失败"
            try {
                if (resTransObj.errorInfo != "")
                    errTrans := resTransObj.errorInfo
                else if (resTransObj.message != "")
                    errTrans := resTransObj.message
            }
            MsgBox("转换测试 Token 失败：`n`n" errTrans "`n`n接口返回：" resTransText)
        }
    } catch Error as e {
        MsgBox("调用转换测试 Token 接口异常：`n`n" e.Message)
    }
}

; ------------------------------------------------------------
; 辅助请求与转换函数
; ------------------------------------------------------------

; 基础网络请求封装
SendHttpRequest(method, url, headers := "", body := "", returnBinary := false) {
    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    whr.Option[4] := 0x3300 ; 忽略自签名 SSL 证书错误
    whr.Open(method, url, true)
    if (IsObject(headers)) {
        for k, v in headers {
            whr.SetRequestHeader(k, v)
        }
    }
    whr.Send(body)
    whr.WaitForResponse()
    return returnBinary ? whr.ResponseBody : whr.ResponseText
}

; 融亿办内部接口封装
RongyibanRequest(method, path, headers := "", body := "", returnBinary := false) {
    baseUrl := GetSetting("rongyibanBaseUrl")
    return SendHttpRequest(method, baseUrl . path, headers, body, returnBinary)
}

; 二进制 SafeArray 转 Base64
BinToBase64(binData) {
    xml := ComObject("MSXML2.DOMDocument.6.0")
    elem := xml.createElement("tmp")
    elem.dataType := "bin.base64"
    elem.nodeTypedValue := binData
    return StrReplace(elem.text, "`n", "")
}
