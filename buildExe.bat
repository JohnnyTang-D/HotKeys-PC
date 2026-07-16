chcp 65001 >nul
@echo off
title HotKey 项目一键编译脚本

echo ============================================================
echo               HotKey AHK 项目一键编译工具
echo ============================================================
echo.

:: 1. 定义相关的路径变量
set "AHK2EXE=C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
set "BASE_EXE=C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
set "SRC_AHK=HotKey2026-02-04.ahk"
set "OUT_EXE=HotKey2026-02-04.exe"
set "DIST_DIR=dist"

:: 2. 环境安全自检
echo [1/3] 正在检查编译环境...

if not exist "%AHK2EXE%" (
    echo [错误] 未在默认路径找到 Ahk2Exe 编译器！
    echo 预期路径: "%AHK2EXE%"
    goto ERROR_EXIT
)

if not exist "%BASE_EXE%" (
    echo [错误] 未在默认路径找到 v2 64位解释器底座！
    echo 预期路径: "%BASE_EXE%"
    goto ERROR_EXIT
)

if not exist "%SRC_AHK%" (
    echo [错误] 未在当前目录下找到主脚本文件 "%SRC_AHK%"！
    goto ERROR_EXIT
)

echo [OK] 编译环境检测通过。
echo.

:: 2.5 确保 dist 输出目录存在
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

:: 3. 检查是否有同名进程正在运行（防止文件被锁定写入失败）
echo [2/3] 正在检测后台进程冲突...
tasklist | findstr /i "%OUT_EXE%" >nul
if %ERRORLEVEL% equ 0 (
    echo [警告] 检测到 %OUT_EXE% 正在后台运行！
    echo 正在尝试自动关闭运行中的进程以防止写入冲突...
    taskkill /f /im "%OUT_EXE%" >nul 2>&1
    :: 等待一秒确保文件锁完全释放
    timeout /t 1 /nobreak >nul
)
echo [OK] 进程冲突检查完毕。
echo.

:: 4. 调用编译器进行编译
echo [3/3] 正在调用 Ahk2Exe 编译器进行打包...
echo 输入脚本: %SRC_AHK%
echo 输出目标: %OUT_EXE%
echo.

"%AHK2EXE%" /in "%SRC_AHK%" /out "%DIST_DIR%\%OUT_EXE%" /base "%BASE_EXE%"

if %ERRORLEVEL% equ 0 (
    echo.
    echo ============================================================
    echo [恭喜] 编译完成！已成功生成独立的单 EXE 文件：
    echo "%CD%\%DIST_DIR%\%OUT_EXE%"
    echo ============================================================
    goto SUCCESS_EXIT
) else (
    echo.
    echo [错误] 编译失败！Ahk2Exe 编译器退出码: %ERRORLEVEL%
    goto ERROR_EXIT
)

:SUCCESS_EXIT
exit /b 0

:ERROR_EXIT
echo.
echo 编译未能成功完成。请检查以上错误信息后重试。
echo.
pause
exit /b 1
