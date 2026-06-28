# VolumeGuardian - VolumeUnlock.ps1

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$RuntimeDir = Join-Path $ProjectRoot "runtime"
$LogsDir = Join-Path $ProjectRoot "logs"
$PidFile = Join-Path $RuntimeDir "VolumeGuardian.pid"
$LogFile = Join-Path $LogsDir "VolumeGuardian.log"

function Write-VGLog {
    param([string]$Message)
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Time] $Message"
}

if (Test-Path $PidFile) {
    $PidValue = Get-Content $PidFile -ErrorAction SilentlyContinue

    if ($PidValue) {
        Stop-Process -Id $PidValue -Force -ErrorAction SilentlyContinue
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
        Write-VGLog "Unlocked. Stopped guard process PID $PidValue."
        Write-Host "VolumeGuardian is now UNLOCKED." -ForegroundColor Yellow
    }
} else {
    Write-Host "VolumeGuardian was not running." -ForegroundColor Gray
}
