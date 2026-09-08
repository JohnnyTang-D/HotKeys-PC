# 功能代码索引

## 融亿办测试 Token（Win+W）

- `lib/hotkey/rongyiban/hotkey_rongyiban.ahk`：快捷键入口、诊断上下文、配置读取、验证码获取与识别、登录及 Token 转换；唯一验证码候选提取；按最终测试 Token 的 exp 在进程内缓存，过期或切换账号、接口地址后重新获取。
- `lib/hotkey/rongyiban/rongyiban_http.ahk`：HTTP 请求、状态与耗时记录、响应解析、后端错误提取、图片 Base64 转换。
- `lib/hotkey/rongyiban/rongyiban_error.ahk`：阶段错误标题、诊断日志、验证码图片与模型原文对照窗口。
- `HotKey2026-02-04.ahk`：主脚本，通过原有 Include 加载快捷键模块；快捷键模块加载上述两个辅助文件。
- `utils/utils.ahk`：配置读取、JSON 辅助函数与剪贴板输出。
- `utils/crypto.ahk`：登录密码加密。

诊断上下文只携带阶段、请求记录、验证码预览和计时信息；凭据与 Token 通过业务参数和返回值传递。业务异常在快捷键入口统一捕获，错误模块负责展示。
