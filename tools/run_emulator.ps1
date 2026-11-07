<#
.SYNOPSIS  Boot the tower_phone emulator (WHPX, host GPU) and wait until Android finished booting.
.PARAMETER ColdBoot  Skip the quickboot snapshot (use after a crash or config change).
#>
param(
    [string]$Avd = "tower_phone",
    [switch]$ColdBoot,
    [int]$TimeoutSec = 300
)
$ErrorActionPreference = "Stop"
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$adb = "$sdk\platform-tools\adb.exe"
$emu = "$sdk\emulator\emulator.exe"

function Get-Boot { try { ((& $adb shell getprop sys.boot_completed 2>$null) -join '').Trim() } catch { '' } }

& $adb start-server | Out-Null
if ((& $adb devices) -match 'emulator-\d+\s+device') {
    Write-Host "An emulator is already running."
} else {
    $args = @('-avd', $Avd, '-gpu', 'host', '-no-boot-anim', '-no-audio')
    if ($ColdBoot) { $args += '-no-snapshot-load' }
    Write-Host "Starting $Avd $(if($ColdBoot){'(cold boot)'})..."
    Start-Process -FilePath $emu -ArgumentList $args -WindowStyle Minimized
}
$sw = [Diagnostics.Stopwatch]::StartNew()
& $adb wait-for-device
while ((Get-Boot) -ne '1') {
    if ($sw.Elapsed.TotalSeconds -gt $TimeoutSec) { throw "Emulator did not finish booting in $TimeoutSec s" }
    Start-Sleep -Seconds 3
}
Write-Host ("Emulator booted in {0:N0}s. Tip: wait ~20s after a COLD boot before launching apps." -f $sw.Elapsed.TotalSeconds)