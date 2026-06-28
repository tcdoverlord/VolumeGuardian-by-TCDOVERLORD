# VolumeGuardian - VolumeStatus.ps1
# Version: 1.1

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$RuntimeDir = Join-Path $ProjectRoot "runtime"
$LogsDir = Join-Path $ProjectRoot "logs"
$PidFile = Join-Path $RuntimeDir "VolumeGuardian.pid"
$LogFile = Join-Path $LogsDir "VolumeGuardian.log"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "        VolumeGuardian Status" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $PidFile) {
    $PidValue = Get-Content $PidFile -ErrorAction SilentlyContinue
    $Proc = Get-Process -Id $PidValue -ErrorAction SilentlyContinue

    if ($Proc) {
        Write-Host "Status: LOCKED" -ForegroundColor Green
        Write-Host "Plain meaning: VolumeGuardian is currently protecting your selected volume limit."
        Write-Host "Guard PID: $PidValue"
    } else {
        Write-Host "Status: WARNING" -ForegroundColor Yellow
        Write-Host "Plain meaning: A PID file exists, but the background guard is not running."
        Write-Host "Suggested fix: Run UNLOCK_VOLUME.bat, then LOCK_VOLUME.bat again."
    }
} else {
    Write-Host "Status: UNLOCKED" -ForegroundColor Gray
    Write-Host "Plain meaning: VolumeGuardian is not currently limiting Windows volume."
}

Write-Host ""

if (Test-Path $LogFile) {
    Write-Host "Latest log entries:" -ForegroundColor Cyan
    Get-Content $LogFile -Tail 8
} else {
    Write-Host "No log file found yet."
}

Write-Host ""
