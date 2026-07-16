chcp 65001 >nul
@echo off
title HotKey Build Script

echo ============================================================
echo        HotKey Build: EXE compile -^> Setup package
echo ============================================================
echo.

echo [1/2] Compiling AutoHotkey script...
echo.
call "%~dp0buildExe.bat"
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] EXE compilation failed!
    goto ERROR_EXIT
)
echo.
echo [OK] EXE compiled.
echo.

echo [2/2] Searching for Inno Setup compiler...
set "ISCC="
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if exist "C:\Program Files\Inno Setup 6\ISCC.exe" set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"
if exist "C:\apps\Inno Setup 6\ISCC.exe" set "ISCC=C:\apps\Inno Setup 6\ISCC.exe"
if "%ISCC%"=="" (
    echo [ERROR] ISCC.exe not found!
    echo Please install Inno Setup 6.
    goto ERROR_EXIT
)

echo ISCC: "%ISCC%"

:: 自动从 AHK 主脚本中读取版本号
set "APP_VERSION=1.0.0"
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-Content '%~dp0HotKey2026-02-04.ahk' | Select-String 'Ahk2Exe-SetVersion' | Select-Object -First 1).Line.Split(' ')[1].Trim()"`) do (
    set "APP_VERSION=%%a"
)
echo AppVersion detected: %APP_VERSION%
echo Compiling setup package...
echo.

"%ISCC%" /DAppVersion=%APP_VERSION% "%~dp0setup.iss"
if %ERRORLEVEL% equ 0 (
    echo.
    echo ============================================================
    echo [OK] Build complete! Package in dist folder.
    echo ============================================================
    goto SUCCESS_EXIT
) else (
    echo.
    echo [ERROR] Setup compilation failed! ISCC exit: %ERRORLEVEL%
    goto ERROR_EXIT
)

:SUCCESS_EXIT
exit /b 0

:ERROR_EXIT
echo.
echo Build failed. Check errors above.
echo.
pause
exit /b 1