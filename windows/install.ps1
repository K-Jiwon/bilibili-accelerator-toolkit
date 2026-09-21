#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$Source = Split-Path -Parent $MyInvocation.MyCommand.Path
$Dest = Join-Path $env:LOCALAPPDATA "BiliAccelerator"

Write-Host "安装目录: $Dest"
if (-not (Test-Path $Dest)) {
    New-Item -ItemType Directory -Path $Dest | Out-Null
}

if ((Resolve-Path $Source).Path -ne (Resolve-Path $Dest).Path) {
    Get-ChildItem -Path $Source -Force | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $Dest -Recurse -Force
    }
}

function Find-BiliClient {
    $candidates = @()
    $candidates += Join-Path $env:LOCALAPPDATA "Programs\bilibili\哔哩哔哩.exe"
    $candidates += Join-Path $env:LOCALAPPDATA "Programs\哔哩哔哩\哔哩哔哩.exe"
    $candidates += Join-Path $env:LOCALAPPDATA "bilibili\哔哩哔哩.exe"
    if (${env:ProgramFiles}) { $candidates += Join-Path ${env:ProgramFiles} "bilibili\哔哩哔哩.exe" }
    if (${env:ProgramFiles(x86)}) { $candidates += Join-Path ${env:ProgramFiles(x86)} "bilibili\哔哩哔哩.exe" }
    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) { return $path }
    }

    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($key in $uninstallKeys) {
        $entries = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match "哔哩哔哩|bilibili" }
        foreach ($entry in $entries) {
            $dirs = @()
            if ($entry.InstallLocation) { $dirs += $entry.InstallLocation }
            if ($entry.DisplayIcon) { $dirs += (Split-Path -Parent $entry.DisplayIcon) }
            foreach ($dir in $dirs) {
                if ($dir -and (Test-Path $dir)) {
                    $found = Get-ChildItem -Path $dir -Filter *.exe -Recurse -Depth 2 -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -match "哔哩哔哩|bilibili" } |
                        Select-Object -First 1
                    if ($found) { return $found.FullName }
                }
            }
        }
    }
    return $null
}

$ConfigPath = Join-Path $Dest "config.json"
$Existing = $null
if (Test-Path $ConfigPath) {
    try {
        $Existing = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch { }
}

$Exe = $null
if ($Existing -and $Existing.clientExe -and (Test-Path $Existing.clientExe)) { $Exe = $Existing.clientExe }
$Port = 9223
if ($Existing -and $Existing.port) { $Port = [int]$Existing.port }
$Match = "bilipc.bilibili.com"
if ($Existing -and $Existing.match) { $Match = $Existing.match }
$UiMode = "lite"
if ($Existing -and $Existing.uiMode) { $UiMode = $Existing.uiMode }

if (-not $Exe) {
    $Exe = Find-BiliClient
}
if (-not $Exe) {
    Write-Host "没有自动找到哔哩哔哩客户端。" -ForegroundColor Yellow
    $answer = Read-Host "请粘贴客户端 exe 的完整路径（例如 C:\Users\你\AppData\Local\Programs\bilibili\哔哩哔哩.exe）"
    if (Test-Path $answer) {
        $Exe = $answer
    } else {
        Write-Host "路径无效，安装后请手动修改 config.json 里的 clientExe。" -ForegroundColor Yellow
        $Exe = ""
    }
}

# Keep whatever the user configured before; only fill in what is missing.
$config = [ordered]@{
    clientExe = $Exe
    port = $Port
    match = $Match
    uiMode = $UiMode
}
$config | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8

$shell = New-Object -ComObject WScript.Shell
$icon = Join-Path $Dest "bilibili.ico"
$pythonw = Join-Path $Dest "python\pythonw.exe"
$launcherPy = Join-Path $Dest "launcher.py"
$launchPs1 = Join-Path $Dest "launch.ps1"
$diagnosePs1 = Join-Path $Dest "diagnose.ps1"

# Normal shortcuts go straight to the bundled pythonw.exe: no PowerShell, no
# .vbs, no console window at all. The diagnostic shortcut keeps a visible
# console because it prints the report.
$usePythonw = Test-Path $pythonw
$launcherTarget = if ($usePythonw) { $pythonw } else { "powershell.exe" }
$launcherArgs = if ($usePythonw) { "`"$launcherPy`"" } else { "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launchPs1`"" }
$injectorArgs = if ($usePythonw) { "`"$launcherPy`" --inject-only" } else { "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launchPs1`" --inject-only" }

function New-Shortcut([string]$Path, [string]$TargetPath, [string]$Arguments, [string]$Description, [int]$WindowStyle = 7) {
    $lnk = $shell.CreateShortcut($Path)
    $lnk.TargetPath = $TargetPath
    $lnk.Arguments = $Arguments
    $lnk.WorkingDirectory = $Dest
    if (Test-Path $icon) { $lnk.IconLocation = $icon }
    $lnk.Description = $Description
    $lnk.WindowStyle = $WindowStyle
    $lnk.Save()
}

$desktop = [Environment]::GetFolderPath("Desktop")
$startMenu = [Environment]::GetFolderPath("Programs")
$startup = [Environment]::GetFolderPath("Startup")

New-Shortcut (Join-Path $desktop "哔哩哔哩 加速.lnk") $launcherTarget $launcherArgs "哔哩哔哩 加速（用这个启动客户端）"
New-Shortcut (Join-Path $startMenu "哔哩哔哩 加速.lnk") $launcherTarget $launcherArgs "哔哩哔哩 加速（用这个启动客户端）"
New-Shortcut (Join-Path $desktop "哔哩哔哩 加速 诊断.lnk") "powershell.exe" "-NoProfile -ExecutionPolicy Bypass -File `"$diagnosePs1`"" "收集诊断信息" 1
New-Shortcut (Join-Path $startup "BiliAccelerator Injector.lnk") $launcherTarget $injectorArgs "开机自动启动注入器"

Write-Host ""
Write-Host "==================== 安装完成 ====================" -ForegroundColor Green
Write-Host ""
Write-Host "已经在【桌面】创建了这两个快捷方式：" -ForegroundColor Yellow
Write-Host "  1. 哔哩哔哩 加速          ← 以后用这个启动客户端"
Write-Host "  2. 哔哩哔哩 加速 诊断      ← 出问题时双击它，生成诊断文件"
Write-Host ""
Write-Host "还创建了：开始菜单快捷方式 + 开机自动启动注入器"
Write-Host "客户端路径：$Exe"
Write-Host "面板模式：$UiMode    （lite = 去掉模糊特效、更省性能；可在 config.json 改成 full / off）"
Write-Host ""
Write-Host "下一步（照做就行）：" -ForegroundColor Yellow
Write-Host "  1) 双击桌面的「哔哩哔哩 加速」（首次会自动重启一次客户端）"
Write-Host "  2) 等客户端打开，右下角出现小闪电 ⚡ 就成功了"
Write-Host "  3) 如果 30 秒后还没有 ⚡：双击「哔哩哔哩 加速 诊断」，"
Write-Host "     桌面上会生成「哔哩哔哩加速-诊断结果.txt」，把它发给开发者"
Write-Host ""
Write-Host "日志目录：$Dest" -ForegroundColor DarkGray
Write-Host "卸载：双击 uninstall.cmd" -ForegroundColor DarkGray
