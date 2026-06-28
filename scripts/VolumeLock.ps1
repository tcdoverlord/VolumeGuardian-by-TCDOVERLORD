# VolumeGuardian - VolumeLock.ps1
# Version: 1.2
# Purpose: Lock Windows master volume at the current user-selected safe level.

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$RuntimeDir  = Join-Path $ProjectRoot "runtime"
$LogsDir     = Join-Path $ProjectRoot "logs"
$PidFile     = Join-Path $RuntimeDir "VolumeGuardian.pid"
$GuardFile   = Join-Path $RuntimeDir "VolumeGuard.running.ps1"
$LogFile     = Join-Path $LogsDir "VolumeGuardian.log"

New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

function Write-VGLog {
    param([string]$Message)
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Time] $Message"
}

$GuardScript = @'
param(
    [string]$LogFile
)

function Write-GuardLog {
    param([string]$Message)
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Time] $Message"
}

function Write-FriendlyBlock {
    param(
        [string]$Title,
        [string[]]$Lines
    )

    Write-GuardLog "------------------------------------------------------------"
    Write-GuardLog $Title
    foreach ($Line in $Lines) {
        Write-GuardLog $Line
    }
    Write-GuardLog "------------------------------------------------------------"
}

try {
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public enum EDataFlow {
    eRender = 0,
    eCapture = 1,
    eAll = 2
}

public enum ERole {
    eConsole = 0,
    eMultimedia = 1,
    eCommunications = 2
}

[Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
[ComImport]
public class MMDeviceEnumerator {}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(EDataFlow dataFlow, int dwStateMask, IntPtr ppDevices);
    int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice ppEndpoint);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDevice {
    int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, out IAudioEndpointVolume ppInterface);
}

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IAudioEndpointVolume {
    int RegisterControlChangeNotify(IntPtr pNotify);
    int UnregisterControlChangeNotify(IntPtr pNotify);
    int GetChannelCount(out uint pnChannelCount);
    int SetMasterVolumeLevel(float fLevelDB, Guid pguidEventContext);
    int SetMasterVolumeLevelScalar(float fLevel, Guid pguidEventContext);
    int GetMasterVolumeLevel(out float pfLevelDB);
    int GetMasterVolumeLevelScalar(out float pfLevel);
    int SetChannelVolumeLevel(uint nChannel, float fLevelDB, Guid pguidEventContext);
    int SetChannelVolumeLevelScalar(uint nChannel, float fLevel, Guid pguidEventContext);
    int GetChannelVolumeLevel(uint nChannel, out float pfLevelDB);
    int GetChannelVolumeLevelScalar(uint nChannel, out float pfLevel);
    int SetMute(bool bMute, Guid pguidEventContext);
    int GetMute(out bool pbMute);
    int GetVolumeStepInfo(out uint pnStep, out uint pnStepCount);
    int VolumeStepUp(Guid pguidEventContext);
    int VolumeStepDown(Guid pguidEventContext);
    int QueryHardwareSupport(out uint pdwHardwareSupportMask);
    int GetVolumeRange(out float pflVolumeMindB, out float pflVolumeMaxdB, out float pflVolumeIncrementdB);
}

public class VGAudio {
    public static IAudioEndpointVolume GetVolumeEndpoint() {
        IMMDeviceEnumerator enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumerator());
        IMMDevice device;
        int hr = enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out device);
        Marshal.ThrowExceptionForHR(hr);

        Guid iid = typeof(IAudioEndpointVolume).GUID;
        IAudioEndpointVolume volume;
        hr = device.Activate(ref iid, 23, IntPtr.Zero, out volume);
        Marshal.ThrowExceptionForHR(hr);

        return volume;
    }

    public static float GetVolume() {
        IAudioEndpointVolume endpoint = GetVolumeEndpoint();
        float level;
        int hr = endpoint.GetMasterVolumeLevelScalar(out level);
        Marshal.ThrowExceptionForHR(hr);
        return level;
    }

    public static void SetVolume(float level) {
        if (level < 0f) level = 0f;
        if (level > 1f) level = 1f;

        IAudioEndpointVolume endpoint = GetVolumeEndpoint();
        int hr = endpoint.SetMasterVolumeLevelScalar(level, Guid.Empty);
        Marshal.ThrowExceptionForHR(hr);
    }
}
"@
}
catch {
    Write-GuardLog "ERROR: VolumeGuardian could not load the Windows audio engine."
    Write-GuardLog "Plain meaning: Windows did not allow the script to connect to the speaker volume controls."
    Write-GuardLog "Technical detail: $($_.Exception.Message)"
    exit 1
}

try {
    [single]$LockedVolume = [VGAudio]::GetVolume()
    $LockedPercent = [math]::Round($LockedVolume * 100)

    Write-FriendlyBlock "VolumeGuardian LOCKED" @(
        "Plain meaning: Your Windows volume safety limit is now active.",
        "Safe volume limit captured: $LockedPercent percent.",
        "What this means: Windows volume can go lower, but attempts to go above $LockedPercent percent will be pulled back down.",
        "Protection mode: Active background guard."
    )

    if ($LockedPercent -le 0) {
        Write-FriendlyBlock "WARNING: Captured volume is 0 percent" @(
            "Plain meaning: VolumeGuardian thinks your Windows output volume is muted or at zero.",
            "What to check: Make sure your correct speaker/headphone output device is selected.",
            "What to check: Set Windows volume to your desired safe limit before locking."
        )
    }

    while ($true) {
        try {
            [single]$Now = [VGAudio]::GetVolume()
            $NowPercent = [math]::Round($Now * 100)

            if ($Now -gt ($LockedVolume + 0.005)) {
                [VGAudio]::SetVolume($LockedVolume)

                Write-FriendlyBlock "Volume increase blocked" @(
                    "Plain meaning: Something tried to raise your Windows volume too high.",
                    "Attempted volume: $NowPercent percent.",
                    "Allowed safe limit: $LockedPercent percent.",
                    "Result: VolumeGuardian lowered it back to your safe limit.",
                    "Why: Protecting the listening limit you chose."
                )
            }
        }
        catch {
            Write-FriendlyBlock "Guard loop warning" @(
                "Plain meaning: VolumeGuardian had trouble checking or correcting the volume during this cycle.",
                "It will keep trying.",
                "Technical detail: $($_.Exception.Message)"
            )
        }

        Start-Sleep -Milliseconds 150
    }
}
catch {
    Write-FriendlyBlock "ERROR: VolumeGuardian could not start protection" @(
        "Plain meaning: The lock did not fully activate.",
        "Technical detail: $($_.Exception.Message)"
    )
    exit 1
}
'@

Set-Content -Path $GuardFile -Value $GuardScript -Encoding UTF8

if (Test-Path $PidFile) {
    $OldPid = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ($OldPid) {
        Stop-Process -Id $OldPid -Force -ErrorAction SilentlyContinue
        Write-VGLog "Stopped old guard process PID $OldPid."
        Write-VGLog "Plain meaning: VolumeGuardian shut down the previous lock before starting a fresh one."
    }
}

$Process = Start-Process powershell.exe `
    -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$GuardFile`" -LogFile `"$LogFile`"" `
    -PassThru

Set-Content -Path $PidFile -Value $Process.Id

Start-Sleep -Milliseconds 700

Write-VGLog "Started guard process PID $($Process.Id)."
Write-VGLog "Plain meaning: VolumeGuardian background protection is running."

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "        VolumeGuardian" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Guardian Status: LOCKED" -ForegroundColor Green
Write-Host "Background Guard PID: $($Process.Id)"
Write-Host ""
Write-Host "Check logs\VolumeGuardian.log for the locked volume percent."
Write-Host ""
