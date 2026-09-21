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
}
$config | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8

$shell = New-Object -ComObject WScript.Shell
$icon = Join-Path $Dest "bilibili.ico"
$target = Join-Path $Dest "launch.vbs"

function New-Shortcut([string]$Path, [string]$Arguments) {
    $lnk = $shell.CreateShortcut($Path)
    $lnk.TargetPath = "wscript.exe"
    $lnk.Arguments = $Arguments
    $lnk.WorkingDirectory = $Dest
    if (Test-Path $icon) { $lnk.IconLocation = $icon }
    $lnk.Description = "哔哩哔哩 加速"
    $lnk.Save()
}

$launchArg = "`"$target`""
New-Shortcut (Join-Path ([Environment]::GetFolderPath("Desktop")) "哔哩哔哩 加速.lnk") $launchArg
New-Shortcut (Join-Path ([Environment]::GetFolderPath("Programs")) "哔哩哔哩 加速.lnk") $launchArg

$injectorVbs = Join-Path $Dest "injector.vbs"
New-Shortcut (Join-Path ([Environment]::GetFolderPath("Startup")) "BiliAccelerator Injector.lnk") "`"$injectorVbs`""

Write-Host ""
Write-Host "安装完成！" -ForegroundColor Green
Write-Host "· 桌面和开始菜单已创建「哔哩哔哩 加速」快捷方式"
Write-Host "· 客户端路径: $Exe"
Write-Host "· 以后从这个快捷方式启动（首次会自动重启一次客户端）"
Write-Host "· 注入日志: $Dest\injector.log"
Write-Host "· 卸载: 运行 uninstall.ps1"
