; 基础网络请求封装
SendHttpRequest(method, url, headers := "", body := "", returnBinary := false, diagnostics := "", stage := "请求") {
    started := A_TickCount
    status := "未取得"
    contentType := "未提供"
    responseLength := "未取得"
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        try whr.Option[4] := 0x3300 ; 忽略自签名 SSL 证书错误
        try whr.SetTimeouts(5000, 5000, 10000, 10000) ; 设置域名解析、连接、发送、接收超时时间 (毫秒)
        whr.Open(method, url, false)
        if (IsObject(headers)) {
            for k, v in headers {
                whr.SetRequestHeader(k, v)
            }
        }
        whr.Send(body)
        status := whr.Status
        try contentType := whr.GetResponseHeader("Content-Type")
        response := returnBinary ? whr.ResponseBody : whr.ResponseText
        if !returnBinary
            responseLength := StrLen(response)
        if (status < 200 || status >= 300) {
            detail := returnBinary ? "图片接口请求失败" : RongyibanError(JSON_parse(response), "接口未返回可解析的错误信息")
            throw Error("HTTP " status "：" detail)
        }
        if returnBinary {
            if !InStr(StrLower(contentType), "image/")
                throw Error("验证码接口返回的内容类型不是图片")
        } else if (Trim(response) == "") {
            throw Error("接口响应正文为空")
        }
        return response
    } finally {
        ; 仅收集阶段元数据，不记录请求地址、凭据、验证码图片或 Token。
        if IsObject(diagnostics)
            diagnostics.Push(stage "：HTTP " status "；类型 " contentType "；耗时 " (A_TickCount - started)
                " ms" (returnBinary ? "" : "；正文字符数 " responseLength))
    }
}

; 融亿办内部接口封装
RongyibanRequest(baseUrl, method, path, headers := "", body := "", returnBinary := false, diagnostics := "", stage := "请求") {
    return SendHttpRequest(method, baseUrl . path, headers, body, returnBinary, diagnostics, stage)
}

; 当前流程使用严格解析，避免公共解析函数将错误吞掉后继续登录。
ParseRongyibanResponse(text) {
    try parsed := JSON.parse(text)
    catch
        throw Error("接口响应不是有效 JSON")
    if !IsObject(parsed)
        throw Error("接口 JSON 响应不是对象")
    return parsed
}

RongyibanError(parsed, fallback) {
    for key in ["bizMessage", "errorInfo", "message"] {
        message := GetJsonVal(parsed, key)
        if (message != "")
            return message
    }
    message := GetJsonVal(parsed, "error", "message")
    return message != "" ? message : fallback
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
