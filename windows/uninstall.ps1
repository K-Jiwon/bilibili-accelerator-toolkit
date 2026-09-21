$ErrorActionPreference = "SilentlyContinue"

$Dest = Join-Path $env:LOCALAPPDATA "BiliAccelerator"

$shortcuts = @(
    (Join-Path ([Environment]::GetFolderPath("Desktop")) "哔哩哔哩 加速.lnk"),
    (Join-Path ([Environment]::GetFolderPath("Programs")) "哔哩哔哩 加速.lnk"),
    (Join-Path ([Environment]::GetFolderPath("Startup")) "BiliAccelerator Injector.lnk")
)
foreach ($item in $shortcuts) {
    if (Test-Path $item) { Remove-Item $item -Force }
}

try {
    Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
        Where-Object { $_.CommandLine -like "*injector.py*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
} catch { }

if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
Write-Host "已卸载哔哩哔哩加速。"
