@echo off
chcp 65001 >nul
echo 正在安装哔哩哔哩加速...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
