<#
.SYNOPSIS  Build the signed beta Android App Bundle (B1-01). Output: build\release\ironstatic-<name>-<code>.aab
.DESCRIPTION
  Signing: reads secrets.local.json (gitignored) fields android_release_keystore_path / _user / _password and
  hands them to the child Godot process as GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD. Nothing secret is
  printed or written into the repo. See docs/setup/android_export.md "Release AAB" and docs/setup/signing.md.
  -TestKey  signs with a throwaway keystore generated under build\testkey\ (gitignored). The output is named
            ...-TESTKEY.aab and must NEVER be uploaded to Play.
  -RunTests also run the full test suite first.   -AllowDirty skip the clean-tree check (loud warning).
  -Preset   export preset name (default IronStaticBeta; canary: pass a bad name to see the failure path).
  Exit: 0 ok, 1 build/verification failure, 2 usage/secrets error.
#>
param(
    [switch]$TestKey,
    [switch]$RunTests,
    [switch]$AllowDirty,
    [string]$Preset = 'IronStaticBeta',
    [string]$SecretsPath = ''
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"
$Jdk = 'C:\dev\tools\jdk-17'
$Keytool = Join-Path $Jdk 'bin\keytool.exe'
$Jarsigner = Join-Path $Jdk 'bin\jarsigner.exe'
if (-not $SecretsPath) { $SecretsPath = Join-Path $RepoRoot 'secrets.local.json' }

function Fail([string]$msg, [int]$code = 1) { Write-Host "FAIL: $msg" -ForegroundColor Red; exit $code }
function Invoke-Git { & git -C $RepoRoot @args }
function Invoke-Native([string]$Exe, [string[]]$NativeArgs) {
    $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try { return (& $Exe @NativeArgs 2>&1 | ForEach-Object { "$_" }) } finally { $ErrorActionPreference = $old }
}

Set-Location $RepoRoot
if ($RepoRoot -like '\\*') { Fail 'run from a local drive path, not \\wsl$' 2 }

# 1. clean tree
$dirty = @(Invoke-Git status --porcelain)
if ($dirty.Count -gt 0) {
    if ($AllowDirty) { Write-Host "WARNING: building from a dirty tree (-AllowDirty):`n$($dirty -join "`n")" -ForegroundColor Yellow }
    else { Fail "git tree is not clean (commit or stash, or pass -AllowDirty):`n$($dirty -join "`n")" 2 }
}

# 2. signing material (before any long step)
$keyPath = ''; $keyUser = ''; $keyPass = ''
if ($TestKey) {
    $dir = Join-Path $BuildRoot 'testkey'
    New-Item -ItemType Directory -Force $dir | Out-Null
    $keyPath = Join-Path $dir 'NOT-FOR-UPLOAD-test.keystore'
    $pwFile = Join-Path $dir 'NOT-FOR-UPLOAD-test.pw'
    $keyUser = 'testkey'
    if (-not ((Test-Path $keyPath) -and (Test-Path $pwFile))) {
        $newPass = [guid]::NewGuid().ToString('N')
        if (Test-Path $keyPath) { Remove-Item $keyPath -Force }
        $null = Invoke-Native $Keytool @("-genkeypair", "-keystore", $keyPath, "-storepass", $newPass, "-keypass", $newPass, "-alias", $keyUser, "-keyalg", "RSA", "-keysize", "2048", "-validity", "3650", "-dname", "CN=IronStatic TEST KEY NOT FOR UPLOAD, O=local test")
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $keyPath)) { Fail 'could not generate the throwaway test keystore' }
        [System.IO.File]::WriteAllText($pwFile, $newPass)
    }
    $keyPass = ([System.IO.File]::ReadAllText($pwFile)).Trim()
    Write-Host '*** TEST KEY MODE: the AAB is for local verification only. NEVER upload it to Play. ***' -ForegroundColor Yellow
}
else {
    if (-not (Test-Path $SecretsPath)) { Fail "secrets file not found: $SecretsPath (copy secrets.local.json.example, see docs/setup/signing.md; or use -TestKey for a local-only build)" 2 }
    $sec = Get-Content -Raw $SecretsPath | ConvertFrom-Json
    foreach ($f in 'android_release_keystore_path', 'android_release_keystore_user', 'android_release_keystore_password') {
        if (-not $sec.PSObject.Properties[$f] -or [string]::IsNullOrWhiteSpace([string]$sec.$f)) { Fail "secrets.local.json is missing field '$f'" 2 }
    }
    $keyPath = [string]$sec.android_release_keystore_path
    $keyUser = [string]$sec.android_release_keystore_user
    $keyPass = [string]$sec.android_release_keystore_password
    if (-not (Test-Path -LiteralPath $keyPath)) { Fail "keystore file does not exist: $keyPath" 2 }
    $full = (Resolve-Path -LiteralPath $keyPath).Path
    $repoFull = (Resolve-Path $RepoRoot).Path.TrimEnd('\') + '\'
    if ($full.StartsWith($repoFull, [System.StringComparison]::OrdinalIgnoreCase)) { Fail "keystore is inside the repo working tree ($full); keep it outside" 2 }
    $keyPath = $full
}

# 3. version stamp
. "$PSScriptRoot\release_version.ps1" -NoRun
$ver = Get-ReleaseVersion
& "$PSScriptRoot\release_version.ps1" -Apply
$after = @(Invoke-Git status --porcelain)
if ($after.Count -gt $dirty.Count) {
    Write-Host (Invoke-Git diff -U0 -- export_presets.cfg project.godot src/core/game.gd | Out-String)
    if (-not $AllowDirty) { Fail 'applying the version changed tracked files: commit the stamped version first (the diff above)' 2 }
}
Write-Host "Version $($ver.Name) (code $($ver.Code))"

# 4. optional tests
if ($RunTests) {
    & powershell -NoProfile -File "$PSScriptRoot\test.ps1"
    if ($LASTEXITCODE -ne 0) { Fail 'tests failed' }
}

# 5. template, import, export
& powershell -NoProfile -File "$PSScriptRoot\setup_android_template.ps1"
if ($LASTEXITCODE -ne 0) { Fail 'Gradle template setup failed' }
$outDir = Join-Path $BuildRoot 'release'
New-Item -ItemType Directory -Force $outDir | Out-Null
$raw = Join-Path $outDir 'ironstatic-beta.aab'
if (Test-Path $raw) { Remove-Item $raw -Force }
$imp = Invoke-GodotRetry @('--headless', '--import') -TimeoutSec 300
$start = Get-Date
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keyPath
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $keyUser
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $keyPass
try {
    $r = Invoke-GodotRetry @('--headless', '--export-release', $Preset, $raw) -TimeoutSec 1200
}
finally {
    Remove-Item Env:\GODOT_ANDROID_KEYSTORE_RELEASE_PATH, Env:\GODOT_ANDROID_KEYSTORE_RELEASE_USER, Env:\GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
}
$lines = $r.Output -split "`r?`n"
$lines | Where-Object { $_ -match 'ERROR|FAILED|error:' } | ForEach-Object { Write-Host ($_.Replace($keyPass, '***')).Trim() }
if (-not (Test-Path $raw) -or (Get-Item $raw).LastWriteTime -lt $start) {
    Fail "export produced no new AAB at $raw (Godot exit code $($r.ExitCode)); preset '$Preset'"
}

# 6. signer check
$cert = (Invoke-Native $Keytool @("-printcert", "-jarfile", $raw)) -join "`n"
if ($cert -match 'Android Debug') { Remove-Item $raw -Force; Fail 'the AAB is signed with the Android DEBUG certificate: release signing was not applied' }
if ($cert -notmatch 'SHA256:') { Remove-Item $raw -Force; Fail 'could not read a signer certificate from the AAB (unsigned?)' }
$sha1 = [regex]::Match($cert, 'SHA1:\s*([0-9A-F:]+)').Groups[1].Value
$sha256c = [regex]::Match($cert, 'SHA256:\s*([0-9A-F:]+)').Groups[1].Value
$isTest = $cert -match 'TEST KEY NOT FOR UPLOAD'
if ($isTest -and -not $TestKey) { Remove-Item $raw -Force; Fail 'signed with the test key but -TestKey was not given' }
$jsv = (Invoke-Native $Jarsigner @("-verify", $raw)) -join " "
if ($jsv -notmatch 'jar verified') { Fail "jarsigner verify failed: $jsv" }

$suffix = ''
if ($isTest) { $suffix = '-TESTKEY' }
$final = "ironstatic-$($ver.Name)-$($ver.Code)$suffix.aab"
$finalPath = Join-Path $outDir $final
Move-Item -Force $raw $finalPath
$hash = (Get-FileHash $finalPath -Algorithm SHA256).Hash.ToLower()
[System.IO.File]::WriteAllText("$finalPath.sha256", "$hash  $final`n")

# 7. size record
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($finalPath)
try { $top = $zip.Entries | Sort-Object Length -Descending | Select-Object -First 8 | ForEach-Object { '{0,10:N0} B  {1}' -f $_.Length, $_.FullName } }
finally { $zip.Dispose() }
$mb = [math]::Round((Get-Item $finalPath).Length / 1MB, 2)
$report = @("file: $final", "size_mb: $mb", "sha256: $hash", "signer_sha1: $sha1", "signer_sha256: $sha256c", "test_key: $isTest", 'top files (uncompressed bytes):') + $top
[System.IO.File]::WriteAllText("$finalPath.txt", ($report -join "`n") + "`n")
Write-Host ($report -join "`n")
if ($mb -gt 150) { Write-Host "WARNING: AAB is $mb MB (> 150 MB). B1-04 should shrink it." -ForegroundColor Yellow }
if ($isTest) {
    Write-Host '*************************************************************' -ForegroundColor Red
    Write-Host '* SIGNED WITH THE THROWAWAY TEST KEY. NOT UPLOAD-READY.     *' -ForegroundColor Red
    Write-Host '*************************************************************' -ForegroundColor Red
}
else { Write-Host "OK: $finalPath" -ForegroundColor Green }
exit 0
