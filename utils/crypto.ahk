; ============================================================
; 加解密模块
; ============================================================

_SymmetricCrypto(algo, mode, op, data, keyStr, ivStr := "") {
    static providers := Map()
    provKey := algo "_" mode

    ; 初始化 Algorithm Provider (仅初始化一次并根据算法+链模式做缓存，以达到极致性能)
    if (!providers.Has(provKey)) {
        hAlg := 0
        if DllCall("bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", &hAlg, "Str", algo, "Ptr", 0, "UInt", 0) != 0
            throw Error("无法打开 " algo " 算法提供程序")

        chainMode := "ChainingMode" mode
        if DllCall("bcrypt\BCryptSetProperty", "Ptr", hAlg, "Str", "ChainingMode", "Str", chainMode, "UInt", (StrLen(
            chainMode) + 1) * 2, "UInt", 0) != 0 {
            DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAlg, "UInt", 0)
            throw Error("无法设置 " mode " 链接模式")
        }

        cbKeyObject := 0
        DllCall("bcrypt\BCryptGetProperty", "Ptr", hAlg, "Str", "ObjectLength", "UInt*", &cbKeyObject, "UInt", 4,
            "UInt*", &cbResult := 0, "UInt", 0)

        cbBlock := 0
        DllCall("bcrypt\BCryptGetProperty", "Ptr", hAlg, "Str", "BlockLength", "UInt*", &cbBlock, "UInt", 4, "UInt*", &
            cbResult := 0, "UInt", 0)

        providers[provKey] := { hAlg: hAlg, cbKeyObject: cbKeyObject, cbBlock: cbBlock }
    }

    prov := providers[provKey]

    ; 动态分配 Key Data 缓冲区，自适应传入密钥字符串长度
    keyBytesLen := StrPut(keyStr, "UTF-8") - 1
    pbKeyData := Buffer(keyBytesLen + 1)
    StrPut(keyStr, pbKeyData, "UTF-8")

    pbKeyObject := Buffer(prov.cbKeyObject)
    hKey := 0
    if DllCall("bcrypt\BCryptGenerateSymmetricKey", "Ptr", prov.hAlg, "Ptr*", &hKey, "Ptr", pbKeyObject, "UInt", prov.cbKeyObject,
        "Ptr", pbKeyData, "UInt", keyBytesLen, "UInt", 0) != 0
        throw Error("无法生成对称密钥")

    ; 准备 IV 缓冲区 (ECB 模式忽略)
    pbIV := 0
    cbIV := 0
    if (mode != "ECB" && ivStr != "") {
        cbIV := prov.cbBlock
        pbIV := Buffer(cbIV)
        StrPut(ivStr, pbIV, "UTF-8")
    }

    result := ""
    try {
        if (op == "encrypt") {
            cbInput := StrPut(data, "UTF-8") - 1
            pbInput := Buffer(cbInput + 1)
            StrPut(data, pbInput, "UTF-8")

            ; 第一次调用获取输出缓冲区大小 (使用 PKCS7 填充: dwFlags = 1)
            DllCall("bcrypt\BCryptEncrypt", "Ptr", hKey, "Ptr", pbInput, "UInt", cbInput, "Ptr", 0, "Ptr", pbIV, "UInt",
                cbIV, "Ptr", 0, "UInt", 0, "UInt*", &cbOutput := 0, "UInt", 1)
            pbOutput := Buffer(cbOutput)

            if DllCall("bcrypt\BCryptEncrypt", "Ptr", hKey, "Ptr", pbInput, "UInt", cbInput, "Ptr", 0, "Ptr", pbIV,
                "UInt", cbIV, "Ptr", pbOutput, "UInt", cbOutput, "UInt*", &cbResult := 0, "UInt", 1) != 0
                throw Error("加密失败")

            ; 二进制转为 Base64 (NOCRLF)
            DllCall("crypt32\CryptBinaryToString", "Ptr", pbOutput, "UInt", cbOutput, "UInt", 0x40000001, "Ptr", 0,
                "UInt*", &cbBase64 := 0)
            base64Buf := Buffer(cbBase64 * 2)
            DllCall("crypt32\CryptBinaryToString", "Ptr", pbOutput, "UInt", cbOutput, "UInt", 0x40000001, "Ptr",
                base64Buf, "UInt*", &cbBase64)
            result := StrGet(base64Buf, "UTF-16")
        } else {
            ; Base64 转二进制 Buffer
            DllCall("crypt32\CryptStringToBinary", "Str", data, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &cbBinary := 0,
                "Ptr", 0, "Ptr", 0)
            pbInput := Buffer(cbBinary)
            DllCall("crypt32\CryptStringToBinary", "Str", data, "UInt", 0, "UInt", 1, "Ptr", pbInput, "UInt*", &
                cbBinary, "Ptr", 0, "Ptr", 0)

            ; 第一次调用获取解密后缓冲区大小
            DllCall("bcrypt\BCryptDecrypt", "Ptr", hKey, "Ptr", pbInput, "UInt", cbBinary, "Ptr", 0, "Ptr", pbIV,
                "UInt", cbIV, "Ptr", 0, "UInt", 0, "UInt*", &cbOutput := 0, "UInt", 1)
            pbOutput := Buffer(cbOutput)

            if DllCall("bcrypt\BCryptDecrypt", "Ptr", hKey, "Ptr", pbInput, "UInt", cbBinary, "Ptr", 0, "Ptr", pbIV,
                "UInt", cbIV, "Ptr", pbOutput, "UInt", cbOutput, "UInt*", &cbResult := 0, "UInt", 1) != 0
                throw Error("解密失败")

            ; 将二进制结果转为明文，使用 cbResult 以精确解包
            result := StrGet(pbOutput, cbResult, "UTF-8")
        }
    } finally {
        if (hKey != 0)
            DllCall("bcrypt\BCryptDestroyKey", "Ptr", hKey)
    }
    return result
}

DES_CBC_Encrypt(plainText) {
    return _SymmetricCrypto("3DES", "CBC", "encrypt", plainText, "mobilewinx@easipass@1234", "01234567")
}

DES_CBC_Decrypt(cipherBase64) {
    return _SymmetricCrypto("3DES", "CBC", "decrypt", cipherBase64, "mobilewinx@easipass@1234", "01234567")
}

AES_ECB_Encrypt(plainText, keyStr := "www.easipass.com") {
    return _SymmetricCrypto("AES", "ECB", "encrypt", plainText, keyStr)
}

; URL 编码 (仅处理 Base64 中会破坏 URL 的特殊字符: + = /)
UrlEncode(str) {
    str := StrReplace(str, '+', '%2B')
    str := StrReplace(str, '=', '%3D')
    str := StrReplace(str, '/', '%2F')
    return str
}
