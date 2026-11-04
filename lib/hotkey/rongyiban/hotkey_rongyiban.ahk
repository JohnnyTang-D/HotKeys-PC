; Win+W：业务流程只负责取值、校验与返回，错误由入口统一展示。
#Include "rongyiban_http.ahk"
#Include "rongyiban_error.ahk"

#w:: {
    context := CreateRongyibanContext()
    try {
        token := GetRongyibanTestToken(context)
        context.stage := "output"
        ; 缓存命中时立即返回，需等触发按键释放后再粘贴，避免组合键状态干扰 Ctrl+V。
        KeyWait("w")
        KeyWait("LWin")
        KeyWait("RWin")
        SendTextViaClipboard(token)
    } catch Error as err {
        ShowRongyibanError(context, err)
    }
}

; 上下文仅存放诊断数据，不保存账号、密码或 Token。
CreateRongyibanContext() {
    return { stage: "config", diagnostics: [], captchaPreview: "", captchaStarted: 0 }
}

; 缓存最终输出的测试 Token；切换账号或接口地址后重新获取，缓存不落盘。
GetRongyibanTestToken(context) {
    static cached := { token: "", expiresAt: 0, username: "", baseUrl: "" }
    context.stage := "config"
    config := ReadRongyibanConfig()
    now := DateDiff(A_NowUTC, "19700101000000", "Seconds")
    if (cached.token != "" && now < cached.expiresAt
        && cached.username == config.username && cached.baseUrl == config.baseUrl)
        return cached.token

    cached := { token: "", expiresAt: 0, username: "", baseUrl: "" }
    token := FetchRongyibanTestToken(context, config)
    expiresAt := GetRongyibanTokenExpiry(token)
    ; 使用请求结束后的时间检查，避免缓存已过期或没有有效过期时间的 Token。
    if (expiresAt <= DateDiff(A_NowUTC, "19700101000000", "Seconds"))
        throw Error("测试 Token 已过期或未包含有效的 exp 字段，无法复用。")
    cached := { token: token, expiresAt: expiresAt, username: config.username, baseUrl: config.baseUrl }
    return token
}

FetchRongyibanTestToken(context, config) {
    captcha := FetchRongyibanCaptcha(config, context)
    context.stage := "recognize"
    captchaValue := RecognizeRongyibanCaptcha(config, captcha, context)
    context.stage := "login"
    jwt := LoginRongyiban(config, captcha, captchaValue, context)
    context.stage := "exchange"
    return ExchangeRongyibanToken(config, jwt, context)
}

; 仅解析服务端返回 Token 的 exp 用于本地缓存判断，不承担签名验证。
GetRongyibanTokenExpiry(token) {
    try {
        if (SubStr(token, 1, 4) != "JWT-")
            return 0
        parts := StrSplit(SubStr(token, 5), ".")
        if (parts.Length != 3)
            return 0
        payload := StrReplace(StrReplace(parts[2], "-", "+"), "_", "/")
        while Mod(StrLen(payload), 4)
            payload .= "="
        size := 0
        if !DllCall("crypt32\CryptStringToBinaryW", "Str", payload, "UInt", StrLen(payload), "UInt", 1,
            "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0)
            return 0
        decodedBuffer := Buffer(size)
        if !DllCall("crypt32\CryptStringToBinaryW", "Str", payload, "UInt", StrLen(payload), "UInt", 1,
            "Ptr", decodedBuffer, "UInt*", &size, "Ptr", 0, "Ptr", 0)
            return 0
        expiresAt := GetJsonVal(JSON.parse(StrGet(decodedBuffer, size, "UTF-8")), "exp")
        return IsNumber(expiresAt) && expiresAt > 0 ? expiresAt + 0 : 0
    } catch {
        return 0
    }
}

ReadRongyibanConfig() {
    config := {
        username: GetCredential("credentials_rongyiban.ini", "ry", "username"),
        password: GetCredential("credentials_rongyiban.ini", "ry", "password"),
        apiKey: GetSetting("apiKey"), baseUrl: GetSetting("rongyibanBaseUrl")
    }
    if (config.username == "" || config.password == "")
        throw Error("融亿办账号或密码未配置，请先在快捷键说明书中配置融亿办账号密码！")
    if (config.apiKey == "")
        throw Error("大模型 API Key 未配置，请先在 config.ini 中配置 Settings/apiKey！")
    if (config.baseUrl == "")
        throw Error("融亿办接口基地址未配置，请先在 config.ini 中配置 Settings/rongyibanBaseUrl！")
    return config
}

FetchRongyibanCaptcha(config, context) {
    context.stage := "captcha"
    context.captchaStarted := A_TickCount
    response := RongyibanRequest(config.baseUrl, "GET", "/captcha/pcruuid", , , false, context.diagnostics,
        "获取验证码 UUID")
    parsed := ParseRongyibanResponse(response)
    uuid := GetJsonVal(parsed, "data", "captchaUuid")
    if (uuid == "")
        throw Error(RongyibanError(parsed, "接口未返回验证码 UUID"))

    context.stage := "image"
    image := RongyibanRequest(config.baseUrl, "GET", "/captcha/pcrimg/" uuid, , , true, context.diagnostics, "下载验证码图片")
    base64 := BinToBase64(image)
    if (base64 == "")
        throw Error("验证码图片为空或 Base64 转换失败")
    ; 保留实际发送给模型的同一张图片，失败时不重新下载。
    context.captchaPreview := { image: image, rawText: "", hasModelText: false }
    return { uuid: uuid, base64: base64 }
}

RecognizeRongyibanCaptcha(config, captcha, context) {
    payload := JSON_stringify({
        model: "glm-4.6v-flash",
        messages: [{ role: "user",
            content: [{ type: "image_url", image_url: { url: "data:image/png;base64," captcha.base64 } }, { type: "text",
                text: "识别图片中的4位验证码。只输出这4位英文字母或数字，保留大小写，不要解释、前缀、标点、空格或 Markdown。无法确定时返回空字符串，不要猜测或列出多个答案。" }] }]
    })
    response := SendHttpRequest("POST", "https://open.bigmodel.cn/api/paas/v4/chat/completions",
        Map("Content-Type", "application/json", "Authorization", "Bearer " config.apiKey), payload, false, context.diagnostics,
        "模型识别验证码")
    parsed := ParseRongyibanResponse(response)
    preview := context.captchaPreview
    preview.rawText := GetJsonVal(parsed, "choices", 1, "message", "content")
    preview.hasModelText := true
    value := ExtractRongyibanCaptcha(preview.rawText)
    if (value == "") {
        context.diagnostics.Push("验证码识别格式：未找到唯一的独立四位字母数字串；原始长度 " StrLen(preview.rawText))
        throw Error(RongyibanError(parsed, "验证码识别结果中没有唯一的四位验证码，请对照图片与模型原文。"))
    }
    context.diagnostics.Push(value == Trim(preview.rawText)
        ? "验证码识别格式：四位字母数字，检查通过"
        : "验证码识别格式：已从模型原文提取唯一四位验证码")
    return value
}

LoginRongyiban(config, captcha, captchaValue, context) {
    payload := JSON_stringify({ loginId: config.username, password: AES_ECB_Encrypt(config.password, "www.easipass.com"
    ),
        captchaVal: captchaValue, captchaUuid: captcha.uuid,
        fingerprint: "lYUB2dUYQZg1WI2wiQZseUCLR3FJPLy6CxzuiR2g6IqH/0E4SlCvd9aYlfkd8O7D" })
    context.diagnostics.Push("获取验证码至提交登录耗时：" (A_TickCount - context.captchaStarted) " ms")
    response := RongyibanRequest(config.baseUrl, "POST", "/auth/login?captchaVal=" captchaValue "&captchaUuid=" captcha
        .uuid,
        Map("Content-Type", "application/json"), payload, false, context.diagnostics, "登录获取 JWT")
    parsed := ParseRongyibanResponse(response)
    token := GetJsonVal(parsed, "data")
    if (token == "" || InStr(token, "JWT-") != 1)
        throw Error(RongyibanError(parsed, "接口未返回有效 JWT"))
    return token
}

ExchangeRongyibanToken(config, jwt, context) {
    response := RongyibanRequest(config.baseUrl, "GET", "/auth/trans-test-token", Map("cm-authorization", jwt), , false,
    context.diagnostics, "转换测试 Token")
    parsed := ParseRongyibanResponse(response)
    token := GetJsonVal(parsed, "data")
    if (token == "" || InStr(token, "JWT-") != 1)
        throw Error(RongyibanError(parsed, "接口未返回有效测试 Token"))
    return token
}

; 仅采用唯一的独立四位串，避免从更长的字母数字串截取，或在多个候选中猜选。
ExtractRongyibanCaptcha(rawText) {
    pattern := "(?<![A-Za-z0-9])[A-Za-z0-9]{4}(?![A-Za-z0-9])"
    position := RegExMatch(rawText, pattern, &candidate)
    if !position
        return ""
    if RegExMatch(rawText, pattern, , position + candidate.Len)
        return ""
    return candidate[0]
}
