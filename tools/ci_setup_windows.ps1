<#
.SYNOPSIS  Provision a Windows CI runner for tools\release_build.ps1 / aab_check.ps1 (docs/release/ci_release.md).
.DESCRIPTION
  tools\ci_setup_windows.ps1 -Root <dir> [-AppDataDir <dir>]
  1. Downloads the Godot editor and the export templates for tools\GODOT_VERSION from the official godot-builds release
     and verifies each archive against the SHA512 pinned in tools\godot_sha512.txt. Downloads bundletool and verifies
     it against tools\bundletool_version.txt. Archives are kept in <Root>\dl (the workflow caches that folder); they are
     verified on EVERY run, so a poisoned cache entry cannot get through.
  2. Extracts the editor to <Root>\godot and only the Android parts of the templates to <Root>\templates, and links
     <AppDataDir>\Godot\export_templates\<ver> to them.
  3. Writes <AppDataDir>\Godot\editor_settings-4.7.tres with the JDK 17 and Android SDK paths (what the local
     editor settings provide on the dev PC).
  4. Checks the Android SDK (platform 36, build-tools 35.0.1, a NDK with llvm-objdump, cmdline-tools) and installs a
     missing piece with sdkmanager at a pinned version.
  5. On GitHub Actions, exports IRONSTATIC_GODOT / IRONSTATIC_JDK / IRONSTATIC_BUNDLETOOL / ANDROID_HOME via GITHUB_ENV.
  -AppDataDir defaults to $env:APPDATA (tests pass a scratch folder so the real editor settings stay untouched).
  Exit: 0 ok; throws on any failure.
#>
param(
    [Parameter(Mandatory)][string]$Root,
    [string]$AppDataDir = $env:APPDATA,
    [string]$Jdk = '',
    [string]$Sdk = ''
)
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName System.IO.Compression.FileSystem

$PlatformPin = 'platforms;android-36'
$BuildToolsPin = 'build-tools;35.0.1'
$NdkPin = 'ndk;27.3.13750724'

$ver = (Get-Content -Raw (Join-Path $PSScriptRoot 'GODOT_VERSION')).Trim()          # 4.7.2-stable
$mm = ($ver -split '\.')[0..1] -join '.'                                           # 4.7
$tplVer = $ver -replace '-', '.'                                                    # 4.7.2.stable
$short = $ver -replace '-stable$', ''                                               # 4.7.2
$sums = @{}
foreach ($l in Get-Content (Join-Path $PSScriptRoot 'godot_sha512.txt')) {
    if ($l -match '^([0-9a-f]{128})\s+(\S+)$') { $sums[$Matches[2]] = $Matches[1] }
}
$vl = Get-Content (Join-Path $PSScriptRoot 'bundletool_version.txt')
$btVer = $vl[0].Trim()
$btSha = ($vl[1] -replace '^sha256=', '').Trim().ToLower()

$dl = Join-Path $Root 'dl'
New-Item -ItemType Directory -Force $dl | Out-Null

function Get-Verified([string]$Url, [string]$Name, [string]$Algo, [string]$Want) {
    $path = Join-Path $dl $Name
    if (Test-Path $path) {
        if ((Get-FileHash $path -Algorithm $Algo).Hash.ToLower() -eq $Want) { Write-Host "cached and verified: $Name"; return $path }
        Write-Host "cached $Name has the wrong hash; downloading again"
        Remove-Item $path -Force
    }
    Write-Host "downloading $Url"
    & curl.exe -fsSL --retry 3 --retry-delay 5 -o $path $Url
    if ($LASTEXITCODE -ne 0) { throw "download failed ($LASTEXITCODE): $Url" }
    $got = (Get-FileHash $path -Algorithm $Algo).Hash.ToLower()
    if ($got -ne $Want) { Remove-Item $path -Force; throw "$Name $Algo mismatch: got $got, pinned $Want" }
    Write-Host "verified $Algo of $Name"
    return $path
}
function Expand-Some([string]$Zip, [string]$Dest, [scriptblock]$Want) {
    New-Item -ItemType Directory -Force $Dest | Out-Null
    $z = [System.IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        foreach ($e in $z.Entries) {
            if ($e.FullName.EndsWith('/') -or -not (& $Want $e.FullName)) { continue }
            $target = Join-Path $Dest (Split-Path $e.FullName -Leaf)
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
        }
    }
    finally { $z.Dispose() }
}

# 1. downloads (all verified)
$base = "https://github.com/godotengine/godot-builds/releases/download/$ver"
$edName = "Godot_v${ver}_win64.exe.zip"
$tplName = "Godot_v${ver}_export_templates.tpz"
foreach ($n in $edName, $tplName) { if (-not $sums.ContainsKey($n)) { throw "tools\godot_sha512.txt has no hash for $n (update it together with tools\GODOT_VERSION)" } }
$edZip = Get-Verified "$base/$edName" $edName 'SHA512' $sums[$edName]
$tplZip = Get-Verified "$base/$tplName" $tplName 'SHA512' $sums[$tplName]
$btJar = Get-Verified "https://github.com/google/bundletool/releases/download/$btVer/bundletool-all-$btVer.jar" "bundletool-all-$btVer.jar" 'SHA256' $btSha

# 2. extract
$godotDir = Join-Path $Root "godot\$short"
$tplDir = Join-Path $Root "templates\$tplVer"
foreach ($d in $godotDir, $tplDir) { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
Expand-Some $edZip $godotDir { param($n) $n -like '*.exe' }
$tplLeaf = { param($n) ($n -match '^templates/(android_[^/]+|version\.txt)$') }
Expand-Some $tplZip $tplDir $tplLeaf
foreach ($f in 'android_source.zip', 'version.txt') { if (-not (Test-Path (Join-Path $tplDir $f))) { throw "export templates lack $f" } }
$godotConsole = Join-Path $godotDir "Godot_v${ver}_win64_console.exe"
if (-not (Test-Path $godotConsole)) { throw "editor archive lacks $godotConsole" }
if ((Get-Content -Raw (Join-Path $tplDir 'version.txt')).Trim() -ne $tplVer) { throw "templates version.txt is not $tplVer" }
$tplLink = Join-Path $AppDataDir "Godot\export_templates\$tplVer"
New-Item -ItemType Directory -Force (Split-Path $tplLink) | Out-Null
if (Test-Path $tplLink) { Remove-Item $tplLink -Recurse -Force }
New-Item -ItemType Junction -Path $tplLink -Target $tplDir | Out-Null

# 3. JDK and SDK
if (-not $Jdk) { $Jdk = if ($env:IRONSTATIC_JDK) { $env:IRONSTATIC_JDK } else { $env:JAVA_HOME_17_X64 } }
if (-not $Jdk -or -not (Test-Path (Join-Path $Jdk 'bin\javac.exe'))) { throw 'JDK 17 not found (set IRONSTATIC_JDK or JAVA_HOME_17_X64)' }
$ErrorActionPreference = 'Continue'
$jv = (& (Join-Path $Jdk 'bin\java.exe') -version 2>&1 | ForEach-Object { "$_" }) -join ' '
$ErrorActionPreference = 'Stop'
if ($jv -notmatch 'version "17\.') { throw "JDK at $Jdk is not version 17: $jv" }
if (-not $Sdk) { $Sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { "$env:LOCALAPPDATA\Android\Sdk" } }
if (-not (Test-Path $Sdk)) { throw "Android SDK not found: $Sdk" }
$sdkmanager = Get-ChildItem (Join-Path $Sdk 'cmdline-tools\*\bin\sdkmanager.bat') -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1
function Install-SdkPackage([string]$Package) {
    if (-not $sdkmanager) { throw "SDK package $Package is missing and sdkmanager (cmdline-tools) is not installed" }
    Write-Host "installing $Package with sdkmanager"
    $env:JAVA_HOME = $Jdk
    $yes = (1..40 | ForEach-Object { 'y' }) -join "`n"
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $out = $yes | & $sdkmanager.FullName "--sdk_root=$Sdk" $Package 2>&1 | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $old }
    if ($LASTEXITCODE -ne 0) { throw "sdkmanager failed for ${Package}: $($out | Select-Object -Last 3)" }
}
if (-not (Test-Path (Join-Path $Sdk 'platforms\android-36'))) { Install-SdkPackage $PlatformPin }
if (-not (Test-Path (Join-Path $Sdk 'build-tools\35.0.1'))) { Install-SdkPackage $BuildToolsPin }
$objdump = { Get-ChildItem "$Sdk\ndk\*\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-objdump.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1 }
if (-not (& $objdump)) { Install-SdkPackage $NdkPin }
if (-not (& $objdump)) { throw 'llvm-objdump still not found in the NDK' }
if (-not (Test-Path (Join-Path $Sdk 'platform-tools'))) { Install-SdkPackage 'platform-tools' }
Write-Host "SDK ${Sdk}: platform 36, build-tools 35.0.1, $((& $objdump).FullName)"

# 4. Godot editor settings: the same two paths the dev PC has in editor_settings-4.7.tres
$cfgDir = Join-Path $AppDataDir 'Godot'
New-Item -ItemType Directory -Force $cfgDir | Out-Null
$fs = { param($p) $p.Replace('\', '/') }
$settings = "[gd_resource type=`"EditorSettings`" format=3]`n`n[resource]`nexport/android/java_sdk_path = `"$(& $fs $Jdk)`"`nexport/android/android_sdk_path = `"$(& $fs $Sdk)`"`nexport/android/shutdown_adb_on_exit = false`n"
[System.IO.File]::WriteAllText((Join-Path $cfgDir "editor_settings-$mm.tres"), $settings, (New-Object System.Text.UTF8Encoding($false)))

# 5. hand the locations to the build scripts
$envOut = [ordered]@{ IRONSTATIC_GODOT = $godotConsole; IRONSTATIC_JDK = $Jdk; IRONSTATIC_BUNDLETOOL = $btJar; ANDROID_HOME = $Sdk }
foreach ($k in $envOut.Keys) { Write-Host "$k = $($envOut[$k])" }
if ($env:GITHUB_ENV) {
    $lines = ($envOut.Keys | ForEach-Object { "$_=$($envOut[$_])" }) -join "`n"
    [System.IO.File]::AppendAllText($env:GITHUB_ENV, $lines + "`n", (New-Object System.Text.UTF8Encoding($false)))
}
Write-Host 'OK CI runner ready'
