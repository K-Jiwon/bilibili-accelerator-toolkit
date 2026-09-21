# Collect everything needed to debug a Windows install into one text file.
$ErrorActionPreference = "SilentlyContinue"

$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path ([Environment]::GetFolderPath("Desktop")) "哔哩哔哩加速-诊断结果.txt"
$lines = New-Object System.Collections.ArrayList

function Add-Line($text) { [void]$lines.Add([string]$text) }

Add-Line "哔哩哔哩 加速 · 诊断报告"
Add-Line ("时间: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Add-Line ("安装目录: " + $Base)
Add-Line ""

Add-Line "== 系统 =="
$os = Get-CimInstance Win32_OperatingSystem
Add-Line ("Windows: " + $os.Caption + " (" + $os.Version + ")")
Add-Line ("PowerShell: " + $PSVersionTable.PSVersion.ToString())
Add-Line ("管理员: " + ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))

Add-Line ""
Add-Line "== 配置 config.json =="
$cfgPath = Join-Path $Base "config.json"
if (Test-Path $cfgPath) {
    Add-Line (Get-Content $cfgPath -Raw -Encoding UTF8)
} else {
    Add-Line "（没有 config.json，说明还没安装成功）"
}

$cfg = $null
if (Test-Path $cfgPath) {
    try { $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
}
$exe = $null
if ($cfg) { $exe = $cfg.clientExe }
$port = 9223
if ($cfg -and $cfg.port) { $port = [int]$cfg.port }
$procName = ""
if ($exe) { $procName = [System.IO.Path]::GetFileNameWithoutExtension($exe) }

Add-Line ""
Add-Line "== 客户端 =="
Add-Line ("clientExe: " + $exe)
Add-Line ("文件存在: " + (Test-Path $exe))
if ($procName) {
    $procs = @(Get-Process -Name $procName -ErrorAction SilentlyContinue)
    Add-Line ("正在运行的进程数: " + $procs.Count)
    Get-CimInstance Win32_Process -Filter ("Name='" + $procName + ".exe'") | ForEach-Object {
        Add-Line ("  命令行: " + $_.CommandLine)
    }
}

Add-Line ""
Add-Line ("== 调试端口 " + $port + " ==")
try {
    $resp = Invoke-WebRequest -Uri ("http://127.0.0.1:" + $port + "/json/version") -UseBasicParsing -TimeoutSec 3
    Add-Line ("HTTP " + $resp.StatusCode)
    Add-Line $resp.Content
    if ($resp.Content -match "bilibili") {
        Add-Line "UA 校验: OK（确认是哔哩哔哩客户端）"
    } else {
        Add-Line "UA 校验: 失败 —— 端口被别的程序占用了，请把 config.json 的 port 改成 9333 再试"
    }
} catch {
    Add-Line "端口没有响应：客户端没有带调试端口启动，或客户端还是商店版（不支持）"
}

Add-Line ""
Add-Line "== 注入器进程 =="
$found = $false
Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" | ForEach-Object {
    if ($_.CommandLine -match "injector") {
        $found = $true
        Add-Line ("PID " + $_.ProcessId + " : " + $_.CommandLine)
    }
}
if (-not $found) { Add-Line "没有发现正在运行的注入器进程" }

Add-Line ""
Add-Line "== 自带 Python 检查 =="
$py = Join-Path $Base "python\python.exe"
Add-Line ("python.exe 存在: " + (Test-Path $py))
if (Test-Path $py) {
    $result = & $py -X utf8 -c "import wsclient, sys; print('wsclient OK', sys.version)" 2>&1
    Add-Line ($result -join " ")
}

Add-Line ""
Add-Line "== injector.log 最后 40 行 =="
$log = Join-Path $Base "injector.log"
if (Test-Path $log) { Add-Line ((Get-Content $log -Tail 40 -Encoding UTF8) -join "`r`n") } else { Add-Line "（没有日志）" }

Add-Line ""
Add-Line "== launcher.log 最后 40 行 =="
$launcherLog = Join-Path $Base "launcher.log"
if (Test-Path $launcherLog) { Add-Line ((Get-Content $launcherLog -Tail 40 -Encoding UTF8) -join "`r`n") } else { Add-Line "（没有日志）" }

$text = $lines -join "`r`n"
$text | Set-Content -Path $out -Encoding UTF8

Write-Host $text
Write-Host ""
Write-Host ("诊断结果已保存到: " + $out) -ForegroundColor Green
Write-Host "把这个文件发给开发者即可。"
Write-Host ""
Read-Host "按回车键关闭"
