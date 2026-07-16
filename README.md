# HotKey2026 快捷键管理工具

基于 **AutoHotkey v2.0** 开发的 Windows 快捷键效率工具集，专为开发和日常工作流程设计，提供热键开关、大模型辅助验证码识别登录、剪贴板增强、特定应用快捷键等功能。

---

## 🚀 主要功能与热键一览

| 快捷键 | 功能描述 | 依赖/配置 |
| :--- | :--- | :--- |
| **`Win + F`** | **统一门户 Token 获取**：弹出账号选择界面，选择后自动获取 Token 并键入当前光标处。 | 需在 `credentials.ini` 中配置账号，`config.ini` 中配置接口。 |
| **`Win + W`** | **测试运管 Token 获取**：自动下载登录验证码图片，调用智谱清言大模型（`glm-4v-flash`）识别后登录融亿办，获取 JWT Token 并键入当前光标处。 | 需在 `credentials_rongyiban.ini` 中配置账号，`config.ini` 中配置大模型 API Key 和接口基地址。 |
| **`Win + V`** | **剪贴板保存为文件**：将当前剪贴板的文本内容保存为 `.txt` 文件，并自动将文件对象复制回剪贴板。 | - |
| **`Win + C`** | **快捷启动终端**：快速打开或激活 Windows Terminal 命令行终端（若已存在则直接前置并激活）。 | - |
| **`Win + Q`** | **Git 日志快速查询**：弹出日期选择器，构建针对当前配置作者的 `git log` 命令并自动键入当前终端窗口。 | 需在 `config.ini` 中配置 `gitAuthor`。 |
| **`Win + S`** | **唤起 AI 助手**：快捷启动或激活桌面上的 `智谱清言` 客户端。 | 需在桌面上存在 `智谱清言.lnk` 快捷方式。 |
| **`CapsLock` 导航模式** | 开启大写锁定（`CapsLock`）后，`W/A/S/D` 等键将映射为光标/鼠标控制键，实现双手不离主键盘区导航。按 `Esc` 退出大写模式。 | `W/A/S/D` 移动光标；`E` -> 退格；`Q` -> 删除；`F` -> `Home`；`J` -> `End`。 |
| **`Alt + D` (双击)** | **WebStorm 调试注入**：在 WebStorm 中双击 `Alt + D` 自动输入 `debugger`。 | 仅在 WebStorm 窗口激活且配置启用时生效。 |
| **`Ctrl + Shift + F`** | **Edge 标签页搜索**：在 Microsoft Edge 中快速拉起标签页搜索功能（内部映射为 `Ctrl + Shift + A`）。 | 仅在 Edge 窗口激活且配置启用时生效。 |

---

## ⚙️ 配置说明

在使用上述快捷键之前，需要对相关的配置文件进行配置。项目提供了相应的示例配置文件（`.example.ini`），可以复制并重命名为 `.ini` 文件后进行修改。

### 1. `config/config.ini` (核心配置)
用于配置热键状态、大模型接口和相关服务地址。可参考 [config.example.ini](file:///c:/stu/hotkeys/config/config.example.ini) 进行创建：
```ini
[Hotkeys]
Win_F=1           ; 是否启用 Win+F 统一门户 Token 功能 (1-启用, 0-禁用)
Win_W=1           ; 是否启用 Win+W 测试运管 Token 功能
Win_V=1           ; 是否启用 Win+V 剪贴板保存文件功能
Win_C=1           ; 是否启用 Win+C 快捷终端功能
Win_Q=1           ; 是否启用 Win+Q Git 日志查询功能
Win_S=1           ; 是否启用 Win+S AI助手功能
CapsLock_Nav=1    ; 是否启用 CapsLock 导航模式
App_WebStorm=1    ; 是否启用 WebStorm 应用热键
App_MsEdge=1      ; 是否启用 Edge 应用热键

[Settings]
apiKey=your_bigmodel_api_key_here               ; 智谱清言大模型 API Key（用于 Win+W 验证码识别）
rongyibanBaseUrl=https://172.16.2.93/cm-portal/v1 ; 融亿办接口基地址
portalTokenUrl=http://192.168.114.43/...        ; 统一门户 Token 获取接口
portalClientId=vgES727DFqpr5LNttxf6oA%3D%3D      ; 统一门户 Client ID
gitAuthor=your_name_here                        ; 用于 Win+Q 过滤 Git 提交记录的作者姓名
```

### 2. `config/credentials.ini` (统一门户账号)
配置统一门户的多个账号密码，供 `Win + F` 触发时下拉选择。可参考 [credentials.example.ini](file:///c:/stu/hotkeys/config/credentials.example.ini) 进行创建：
```ini
[账户别名或用户名]
username=your_username
password=your_password
```

### 3. `config/credentials_rongyiban.ini` (融亿办账号)
配置融亿办的账号密码，用于 `Win + W` 自动登录获取 Token。可参考 [credentials_rongyiban.example.ini](file:///c:/stu/hotkeys/config/credentials_rongyiban.example.ini) 进行创建：
```ini
[ry]
username=your_rongyiban_username
password=your_rongyiban_password
```

---

## 🖥️ 图形化管理界面 (GUI)

双击系统托盘中的图标，或右键托盘图标选择“**快捷键说明书**”，可以唤起图形化管理窗口：
1. **快捷键说明**：展示所有快捷键及其状态。可以通过勾选框动态开启或关闭对应的快捷键，修改会即时生效并同步保存到 `config.ini`。
2. **统一门户账号**：可以方便地添加、修改或删除用于 `Win + F` 快速登录的账户凭据。
3. **融亿办账号**：可以配置、修改或清除用于 `Win + W` 的融亿办登录账号与密码。

---

## 🛠️ 编译与打包

如果你想将脚本编译成可独立运行的绿色版 `.exe`，或者制作安装包，可以按照以下步骤操作：

### 环境要求
1. 安装 **AutoHotkey v2.0**，默认安装路径需包含 `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` 和 `Compiler\Ahk2Exe.exe`。
2. 安装 **Inno Setup 6** (若需要打包安装程序)。

### 打包脚本
- **编译单 EXE 程序**：
  双击运行根目录下的 `buildExe.bat`，它会自动检测环境、解决可能运行中的旧进程冲突，并调用 Ahk2Exe 将 `HotKey2026-02-04.ahk` 编译输出到 `dist\HotKey2026-02-04.exe`。
- **编译 EXE + 制作安装包**：
  双击运行根目录下的 `build.bat`。该脚本会先调用 `buildExe.bat` 编译，然后检测 Inno Setup 编译器，并基于 `setup.iss` 配置文件将程序和默认配置打包成安装包输出到 `dist` 目录下。
