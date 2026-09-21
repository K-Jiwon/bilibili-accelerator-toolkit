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
    Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" |
        Where-Object {
            $_.CommandLine -and (
                $_.CommandLine -like "*injector.py*" -or
                $_.CommandLine -like "*launcher.py*" -or
                $_.CommandLine -like "*$Dest*"
            )
        } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
} catch { }

Start-Sleep -Milliseconds 800
if (Test-Path $Dest) {
    Remove-Item $Dest -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path $Dest) {
    Write-Host "有文件删不掉（可能还在被占用）。请重启电脑后再运行一次 uninstall.cmd。" -ForegroundColor Yellow
} else {
    Write-Host "已删除程序目录: $Dest"
}
Write-Host "已卸载哔哩哔哩加速。"
