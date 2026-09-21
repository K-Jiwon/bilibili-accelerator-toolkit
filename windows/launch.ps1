# BiliAccelerator launcher (Windows)
# Starts the injector, then launches the Bilibili desktop client with a
# Chromium DevTools port so the accelerator userscript can be injected.

$ErrorActionPreference = "SilentlyContinue"

$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $Base "launcher.log"

function Write-Log([string]$Message) {
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Show-Message([string]$Text, [string]$Title) {
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shell.Popup($Text, 20, $Title, 48) | Out-Null
    } catch { }
}

$ConfigPath = Join-Path $Base "config.json"
$Config = $null
if (Test-Path $ConfigPath) {
    try {
        $Config = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch { }
}

$Port = 9223
if ($Config -and $Config.port) { $Port = [int]$Config.port }
$Match = "bilipc.bilibili.com"
if ($Config -and $Config.match) { $Match = $Config.match }
$Exe = $null
if ($Config -and $Config.clientExe) { $Exe = $Config.clientExe }

if (-not $Exe -or -not (Test-Path $Exe)) {
    Write-Log "client exe not found (config: $Exe)"
    Show-Message "没有找到哔哩哔哩客户端。`n`n请编辑安装目录下的 config.json，把 clientExe 改成客户端完整路径，例如：`nC:\Users\你\AppData\Local\Programs\bilibili\哔哩哔哩.exe" "哔哩哔哩 加速"
    exit 1
}

$Python = Join-Path $Base "python\python.exe"
$Injector = Join-Path $Base "injector.py"
$UserScript = Join-Path $Base "bilibili-accelerator.user.js"
$InjectorLog = Join-Path $Base "injector.log"

$injectorRunning = $false
try {
    $procs = Get-CimInstance Win32_Process -Filter "Name='python.exe'"
    foreach ($p in $procs) {
        if ($p.CommandLine -and $p.CommandLine.Contains("injector.py")) { $injectorRunning = $true; break }
    }
} catch { }

if (-not $injectorRunning) {
    Write-Log "starting injector"
    Start-Process -FilePath $Python -ArgumentList @(
        "-X", "utf8", "`"$Injector`"",
        "--port", "$Port",
        "--script", "`"$UserScript`"",
        "--match", "`"$Match`"",
        "--logfile", "`"$InjectorLog`""
    ) -WindowStyle Hidden
}

function Test-Devtools {
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/version" -UseBasicParsing -TimeoutSec 1
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

$procName = [System.IO.Path]::GetFileNameWithoutExtension($Exe)

if (Test-Devtools) {
    Write-Log "devtools already available; activating existing client"
    try {
        $existing = Get-Process -Name $procName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($existing) {
            $shell = New-Object -ComObject WScript.Shell
            $shell.AppActivate($existing.Id) | Out-Null
        }
    } catch { }
    exit 0
}

try {
    $running = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($running) {
        $running | Stop-Process -Force
        Write-Log "stopped existing client processes ($procName)"
        for ($i = 0; $i -lt 20; $i++) {
            if (-not (Get-Process -Name $procName -ErrorAction SilentlyContinue)) { break }
            Start-Sleep -Milliseconds 500
        }
    }
} catch { }

Write-Log "launching client with devtools port $Port"
Start-Process -FilePath $Exe -ArgumentList "--remote-debugging-port=$Port"

for ($i = 0; $i -lt 40; $i++) {
    if (Test-Devtools) { break }
    Start-Sleep -Milliseconds 500
}

if (Test-Devtools) {
    Write-Log "accelerated client is up"
} else {
    Write-Log "devtools port did not open"
    Show-Message "客户端已启动，但没有开启调试端口。`n`n可能你装的是微软商店（UWP）版本，那种版本不支持注入。`n请使用哔哩哔哩官网下载的电脑版客户端。" "哔哩哔哩 加速"
}
