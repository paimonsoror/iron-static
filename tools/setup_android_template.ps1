# Installs (or repairs) the Godot Android Gradle build template in android/build.
# The template is NOT tracked in git (it contains >100 MB engine AARs); run this after a fresh
# clone or a Godot upgrade. Idempotent: re-running only re-applies the project customizations.
#
#   powershell -NoProfile -File tools\setup_android_template.ps1          # install if missing
#   powershell -NoProfile -File tools\setup_android_template.ps1 -Force   # wipe and reinstall
param([switch]$Force)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$pinned = (Get-Content -Raw (Join-Path $PSScriptRoot 'GODOT_VERSION')).Trim()   # e.g. 4.7.2-stable
$templateVersion = $pinned -replace '-', '.'                                     # e.g. 4.7.2.stable
$zip = Join-Path $env:APPDATA "Godot\export_templates\$templateVersion\android_source.zip"
$androidDir = Join-Path $RepoRoot 'android'
$buildDir = Join-Path $androidDir 'build'
$versionFile = Join-Path $androidDir '.build_version'

$installed = (Test-Path $versionFile) -and (Test-Path (Join-Path $buildDir 'build.gradle'))
$current = $installed -and ((Get-Content -Raw $versionFile).Trim() -eq $templateVersion)

if ($Force -or -not $current) {
    if (-not (Test-Path $zip)) { throw "Export templates not installed: $zip (see docs/setup/DEV_ENVIRONMENT.md)" }
    if (Test-Path $buildDir) {
        Write-Host "Removing old template at $buildDir"
        Remove-Item -Recurse -Force $buildDir
    }
    New-Item -ItemType Directory -Path $buildDir | Out-Null
    Write-Host "Extracting $zip"
    $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (Test-Path $tar) {
        & $tar -xf $zip -C $buildDir
        if ($LASTEXITCODE -ne 0) { throw "tar failed with exit code $LASTEXITCODE" }
    } else {
        Expand-Archive -Path $zip -DestinationPath $buildDir
    }
    [System.IO.File]::WriteAllText($versionFile, $templateVersion)
} else {
    Write-Host "Template $templateVersion already installed; re-applying customizations"
}

# Godot warns about the template's nested test project.godot; that stderr line breaks
# deploy_android.ps1 under PowerShell 5.1, so hide the folder from Godot's scanner.
$gdIgnore = Join-Path $buildDir '.gdignore'
if (-not (Test-Path $gdIgnore)) { [System.IO.File]::WriteAllText($gdIgnore, '') }

# gradle.properties: 3 GB heap; no persistent daemon (a lingering daemon keeps Godot's
# stdout pipe open and hangs deploy_android.ps1). See docs/setup/gradle_build.md.
$props = Join-Path $buildDir 'gradle.properties'
$lines = [System.Collections.Generic.List[string]]::new()
if (Test-Path $props) { foreach ($l in (Get-Content $props)) { $lines.Add($l) } }
$out = [System.Collections.Generic.List[string]]::new()
$sawJvm = $false
$sawDaemon = $false
foreach ($l in $lines) {
    if ($l -match '^\s*org\.gradle\.jvmargs\s*=') { $out.Add('org.gradle.jvmargs=-Xmx3g'); $sawJvm = $true }
    elseif ($l -match '^\s*org\.gradle\.daemon\s*=') { $out.Add('org.gradle.daemon=false'); $sawDaemon = $true }
    else { $out.Add($l) }
}
if (-not $sawJvm) { $out.Add('org.gradle.jvmargs=-Xmx3g') }
if (-not $sawDaemon) {
    $out.Add('# IRON STATIC: no persistent daemon (it hangs tools/deploy_android.ps1).')
    $out.Add('org.gradle.daemon=false')
}
[System.IO.File]::WriteAllText($props, (($out -join "`n") + "`n"))

# B1-04: androidx.profileinstaller (pulled in by AndroidX Core/Startup) adds an exported, permission-guarded
# ProfileInstallReceiver that tools\aab_check.ps1 rejects ("no exported component except the launcher"). Nothing in the
# game triggers profile installation, so remove the receiver in the merged manifest. Idempotent.
$manifest = Join-Path $buildDir 'src\main\AndroidManifest.xml'
if (Test-Path $manifest) {
    $mx = [System.IO.File]::ReadAllText($manifest)
    if ($mx -notmatch 'ProfileInstallReceiver') {
        $rm = '        <receiver android:name="androidx.profileinstaller.ProfileInstallReceiver" tools:node="remove" />' + "`n`n    </application>"
        $re = [regex]'(?m)^\s*</application>'
        $mx = $re.Replace($mx, $rm, 1)
        [System.IO.File]::WriteAllText($manifest, $mx, (New-Object System.Text.UTF8Encoding($false)))
    }
}
Write-Host "OK android template $templateVersion ready at $buildDir"
