# Start the injector as a hidden background process, honouring config.json.
# Used by both the launcher and the startup entry so the port can never
# diverge between the two. A stale injector that runs on a different port is
# replaced instead of silently winning the de-duplication check.
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
$MatchHosts = "bilipc.bilibili.com"
if ($Config -and $Config.match) { $MatchHosts = $Config.match }

$desiredPort = "$Port"
$running = @()
try {
    Get-CimInstance Win32_Process -Filter "Name='python.exe'" | ForEach-Object {
        if ($_.CommandLine -and $_.CommandLine -match "injector\.py") {
            $portMatch = [regex]::Match($_.CommandLine, "--port\s+""?([0-9]+)""?")
            $runningPort = ""
            if ($portMatch.Success) { $runningPort = $portMatch.Groups[1].Value }
            $running += [pscustomobject]@{ Id = $_.ProcessId; Port = $runningPort }
        }
    }
} catch { }

foreach ($item in $running) {
    if ($item.Port -eq $desiredPort) { exit 0 }
}

# A stale injector (different or unknown port) would keep polling the wrong
# port forever, so replace it.
foreach ($item in $running) {
    Stop-Process -Id $item.Id -Force -ErrorAction SilentlyContinue
}

$Python = Join-Path $Base "python\python.exe"
$Injector = Join-Path $Base "injector.py"
$UserScript = Join-Path $Base "bilibili-accelerator.user.js"
$InjectorLog = Join-Path $Base "injector.log"

Start-Process -FilePath $Python -ArgumentList @(
    "-X", "utf8", "`"$Injector`"",
    "--port", "$Port",
    "--script", "`"$UserScript`"",
    "--match", "`"$MatchHosts`"",
    "--logfile", "`"$InjectorLog`""
) -WindowStyle Hidden
