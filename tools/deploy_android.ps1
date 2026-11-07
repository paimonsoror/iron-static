<#
.SYNOPSIS  Export a debug APK headlessly, install it on the running emulator/device, launch it, tail Godot logcat.
.EXAMPLE   .\deploy_android.ps1 -ProjectPath C:\dev\tools\smoke_test -Package com.example.smoketest
#>
param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$Package,
    [string]$Preset = "Android",
    [int]$LogSeconds = 8,
    [string]$Serial = ""
)
$ErrorActionPreference = "Stop"
$godot = "C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$adb = "$sdk\platform-tools\adb.exe"
$ProjectPath = (Resolve-Path $ProjectPath).Path
$buildDir = Join-Path $ProjectPath "build"
New-Item -ItemType Directory -Force $buildDir | Out-Null
$apk = Join-Path $buildDir "$Package.debug.apk"

Write-Host "== Exporting $Preset -> $apk"
& $godot --headless --path $ProjectPath --import 2>&1 | Out-Null
$log = & $godot --headless --path $ProjectPath --export-debug $Preset $apk 2>&1 | Out-String
if (-not (Test-Path $apk)) { Write-Host $log; throw "Export failed (no APK produced)." }
($log -split "`n") | Where-Object { $_ -match 'ERROR|Signed' } | ForEach-Object { Write-Host $_.Trim() }

# Godot's export may restart the adb server; make sure it is back and a device is ready.
& $adb start-server | Out-Null
$sel = @(); if ($Serial) { $sel = @('-s', $Serial) }
$tries = 0
while (-not ((& $adb @sel get-state 2>$null) -join '' ).Trim().Equals('device')) {
    if (++$tries -gt 40) { throw "No device/emulator online. Run tools\run_emulator.ps1 or connect a phone." }
    Start-Sleep -Seconds 3
}
Write-Host "== Installing"
& $adb @sel install -r $apk
if ($LASTEXITCODE -ne 0) { throw "adb install failed" }
& $adb @sel logcat -c
Write-Host "== Launching $Package"
& $adb @sel shell monkey -p $Package -c android.intent.category.LAUNCHER 1 | Out-Null
Write-Host "== Godot log for $LogSeconds s"
$job = Start-Job { param($a,$s) & $a @s logcat -s godot:V GodotApp:V } -ArgumentList $adb, $sel
Start-Sleep -Seconds $LogSeconds
Receive-Job $job | Write-Host
Stop-Job $job; Remove-Job $job -Force
$pid_ = ((& $adb @sel shell pidof $Package) -join '').Trim()
if ($pid_) { Write-Host "== RUNNING (pid $pid_)" } else { Write-Host "== NOT RUNNING - check: adb logcat -d | findstr $Package"; exit 1 }