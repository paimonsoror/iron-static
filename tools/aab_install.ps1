<#
.SYNOPSIS  Install the exact AAB on one device via a bundletool universal APK, launch it, scan the log (B1-07).
.DESCRIPTION
  tools\aab_install.ps1 -Aab <file.aab> -Serial <adb serial> [-Ks <keystore> -KsAlias <a> -KsPassFile <pw file>] [-Uninstall]
  1. Verifies the sha256 of the AAB against the <aab>.sha256 file that release_build.ps1 wrote next to it.
  2. bundletool build-apks --mode=universal, signed with the throwaway test keystore (build\testkey) or, as a
     fallback, the Android debug keystore. The upload keystore is never read here.
  3. bundletool install-apks to the device, then (unless -NoLaunch) am start -W and a logcat scan for
     SCRIPT ERROR, ArtSlots:, Strings:, FATAL and any ERROR line.
  -Serial is mandatory and every adb call carries it. Nothing else on the device is touched.
  -Uninstall removes com.normalexception.games.ironstatic afterwards (this wipes the save).
  Exit: 0 ok, 1 install/scan failure, 2 usage/tool error.
#>
param(
    [Parameter(Mandatory)][string]$Aab,
    [Parameter(Mandatory)][string]$Serial,
    [string]$Ks = '',
    [string]$KsAlias = 'testkey',
    [string]$KsPassFile = '',
    [string]$Package = 'com.normalexception.games.ironstatic',
    [string]$OutDir = '',
    [int]$WaitSeconds = 45,
    [switch]$NoLaunch,
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\_common.ps1"
$Java = 'C:\dev\tools\jdk-17\bin\java.exe'
$verLines = Get-Content (Join-Path $PSScriptRoot 'bundletool_version.txt')
$btVer = $verLines[0].Trim()
$btSha = ($verLines[1] -replace '^sha256=', '').Trim()
$Bundletool = "C:\dev\tools\bundletool\bundletool-all-$btVer.jar"

function Stop2([string]$m) { Write-Host "ERROR: $m" -ForegroundColor Red; exit 2 }
function Fail([string]$m) { Write-Host "AAB INSTALL FAIL: $m" -ForegroundColor Red; exit 1 }
function Run([string]$exe, [string[]]$a) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $o = & $exe @a 2>&1 | ForEach-Object { "$_" }; return @{ Code = $LASTEXITCODE; Out = ($o -join "`n") } } finally { $ErrorActionPreference = $old }
}
function Adb([string[]]$a) { return Run $Adb (@('-s', $Serial) + $a) }

foreach ($t in @($Java, $Bundletool, $Adb, $Aab)) { if (-not (Test-Path $t)) { Stop2 "missing: $t" } }
if ((Get-FileHash $Bundletool -Algorithm SHA256).Hash.ToLower() -ne $btSha) { Stop2 'bundletool jar hash differs from tools/bundletool_version.txt' }
$Aab = (Resolve-Path $Aab).Path

# 1. checksum
$shaFile = "$Aab.sha256"
if (-not (Test-Path $shaFile)) { Stop2 "no checksum file next to the AAB: $shaFile" }
$want = ((Get-Content $shaFile -TotalCount 1) -split '\s+')[0].ToLower()
$have = (Get-FileHash $Aab -Algorithm SHA256).Hash.ToLower()
if ($want -ne $have) { Fail "sha256 mismatch: file $have, recorded $want" }
Write-Host "sha256 OK: $have"

# 2. device must be the one named
$st = Adb @('get-state')
if ($st.Out.Trim() -ne 'device') { Fail "device $Serial not ready: $($st.Out)" }
$abi = (Adb @('shell', 'getprop', 'ro.product.cpu.abi')).Out.Trim()
$api = (Adb @('shell', 'getprop', 'ro.build.version.sdk')).Out.Trim()
$page = (Adb @('shell', 'getconf', 'PAGE_SIZE')).Out.Trim()
Write-Host "device $Serial : API $api, ABI $abi, page size $page"

# 3. signing material: test keystore first, debug keystore as fallback
$ksPass = ''
if (-not $Ks) {
    $tk = Join-Path $BuildRoot 'testkey\NOT-FOR-UPLOAD-test.keystore'
    $tp = Join-Path $BuildRoot 'testkey\NOT-FOR-UPLOAD-test.pw'
    if ((Test-Path $tk) -and (Test-Path $tp)) { $Ks = $tk; $KsPassFile = $tp }
    else {
        $Ks = Join-Path $env:USERPROFILE '.android\debug.keystore'; $KsAlias = 'androiddebugkey'; $ksPass = 'android'
        Write-Host 'test keystore not found, using the debug keystore' -ForegroundColor Yellow
    }
}
if (-not (Test-Path $Ks)) { Stop2 "keystore not found: $Ks" }
if ($KsPassFile) { $ksPass = ([System.IO.File]::ReadAllText($KsPassFile)).Trim() }

if (-not $OutDir) { $OutDir = Join-Path $BuildRoot 'aab_install' }
New-Item -ItemType Directory -Force $OutDir | Out-Null
$apks = Join-Path $OutDir 'universal.apks'
$b = Run $Java @('-jar', $Bundletool, 'build-apks', "--bundle=$Aab", "--output=$apks", '--mode=universal', '--overwrite',
    "--ks=$Ks", "--ks-key-alias=$KsAlias", "--ks-pass=pass:$ksPass", "--key-pass=pass:$ksPass")
if ($b.Code -ne 0) { Fail "build-apks failed: $($b.Out)" }
Write-Host "universal APK set: $apks"

# 4. install (fresh install: wipes an earlier copy only if the signature differs, bundletool/adb decide)
$sw = [Diagnostics.Stopwatch]::StartNew()
$i = Run $Java @('-jar', $Bundletool, 'install-apks', "--apks=$apks", "--device-id=$Serial", "--adb=$Adb")
if ($i.Code -ne 0) { Fail "install-apks failed: $($i.Out)" }
Write-Host ("install-apks OK in {0:N1} s" -f $sw.Elapsed.TotalSeconds)
$vn = (Adb @('shell', 'dumpsys', 'package', $Package)).Out -split "`n" | Where-Object { $_ -match 'versionName=|versionCode=' } | Select-Object -First 2
$vn | ForEach-Object { Write-Host "  $($_.Trim())" }

# 5. launch and scan
$bad = @()
if (-not $NoLaunch) {
    $null = Adb @('logcat', '-c')
    $l = Adb @('shell', 'am', 'start', '-W', '-n', "$Package/com.godot.game.GodotAppLauncher")
    if ($l.Out -notmatch 'Status: ok') { $l = Adb @('shell', 'monkey', '-p', $Package, '-c', 'android.intent.category.LAUNCHER', '1') }
    ($l.Out -split "`n") | Where-Object { $_ -match 'TotalTime|WaitTime|Status' } | ForEach-Object { Write-Host "  $($_.Trim())" }
    Start-Sleep -Seconds $WaitSeconds
    $pidText = (Adb @('shell', 'pidof', $Package)).Out.Trim()
    if ($pidText -notmatch '^\d+') { Fail 'process not running after launch' }
    Write-Host "process running (pid $pidText)"
    $log = (Adb @('logcat', '-d')).Out -split "`n"
    $logFile = Join-Path $OutDir 'logcat.txt'
    $log | Set-Content -Encoding utf8 $logFile
    $pats = [ordered]@{ 'SCRIPT ERROR' = 'SCRIPT ERROR'; 'ArtSlots:' = 'ArtSlots:'; 'Strings:' = 'Strings:'; 'FATAL' = 'FATAL'; 'ERROR' = '\bERROR\b' }
    foreach ($k in $pats.Keys) {
        $m = @($log | Where-Object { $_ -cmatch $pats[$k] })  # case-sensitive: "I/O error" in system lines is not an ERROR
        Write-Host ("log scan {0,-13} {1}" -f $k, $m.Count)
        $m | Select-Object -First 5 | ForEach-Object { Write-Host "    $($_.Trim())" }
        if ($m.Count -gt 0) { $bad += $m }
    }
    $eApp = @($log | Where-Object { $_ -match '\sE\s+(godot|GodotActivity|AndroidRuntime)\s*:' })
    Write-Host ("log scan E-priority godot lines (informational) {0}" -f $eApp.Count)
    $eApp | Select-Object -First 5 | ForEach-Object { Write-Host "    $($_.Trim())" }
    Write-Host "log saved: $logFile"
}
if ($Uninstall) {
    $u = Adb @('uninstall', $Package)
    Write-Host "uninstall: $($u.Out.Trim())"
}
if ($bad.Count -gt 0) { Fail "$($bad.Count) error lines in the log" }
Write-Host 'AAB INSTALL OK'
exit 0
