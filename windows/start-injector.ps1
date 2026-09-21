# Start the injector as a hidden background process, honouring config.json.
# Used by both the launcher and the startup entry so the port can never
# diverge between the two.
$ErrorActionPreference = "SilentlyContinue"

$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
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

$running = $false
try {
    Get-CimInstance Win32_Process -Filter "Name='python.exe'" | ForEach-Object {
        if ($_.CommandLine -and $_.CommandLine.Contains("injector.py")) { $running = $true }
    }
} catch { }
if ($running) { exit 0 }

$Python = Join-Path $Base "python\python.exe"
$Injector = Join-Path $Base "injector.py"
$UserScript = Join-Path $Base "bilibili-accelerator.user.js"
$InjectorLog = Join-Path $Base "injector.log"

Start-Process -FilePath $Python -ArgumentList @(
    "-X", "utf8", "`"$Injector`"",
    "--port", "$Port",
    "--script", "`"$UserScript`"",
    "--match", "`"$Match`"",
    "--logfile", "`"$InjectorLog`""
) -WindowStyle Hidden
