# VolumeGuardian setup.ps1

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

$Folders = @(
    "$Root\scripts",
    "$Root\launchers",
    "$Root\logs",
    "$Root\runtime",
    "$Root\rusty",
    "$Root\rusty\src",
    "$Root\docs"
)

foreach ($Folder in $Folders) {
    New-Item -ItemType Directory -Force -Path $Folder | Out-Null
}

New-Item -ItemType File -Force -Path "$Root\logs\.gitkeep" | Out-Null
New-Item -ItemType File -Force -Path "$Root\runtime\.gitkeep" | Out-Null

Write-Host ""
Write-Host "VolumeGuardian setup complete." -ForegroundColor Green
Write-Host ""
Write-Host "Use:"
Write-Host "  launchers\LOCK_VOLUME.bat"
Write-Host "  launchers\UNLOCK_VOLUME.bat"
Write-Host "  launchers\STATUS_VOLUME.bat"
Write-Host ""
Write-Host "Rusty placeholder is located in:"
Write-Host "  rusty\"
Write-Host ""
