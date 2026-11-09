<#
.SYNOPSIS  Audit a release AAB: manifest, 16 KB page alignment, size (B1-03).
.DESCRIPTION
  tools\aab_check.ps1 <file.aab> [-AllowedPermissions a,b] [-AuditOut docs\release\aab_audit_table.md] [-KeepWork]
  Checks (a) merged base manifest via bundletool: targetSdk 36, minSdk 24, permission list == allowed list
  (default android.permission.VIBRATE), allowBackup false, game category, no exported component besides the launcher
  activity; (b) bundletool dump config has PAGE_ALIGNMENT_16K; (c) every lib/arm64-v8a and lib/x86_64 .so in a universal
  APK has LOAD alignment >= 2**14 (llvm-objdump -p) and zipalign -c -P 16 passes; (d) prints size and the 3 biggest files.
  Exit: 0 PASS, 1 FAIL, 2 error (missing tool/input).
#>
param(
    [Parameter(Mandatory)][string]$Aab,
    [string[]]$AllowedPermissions = @('android.permission.VIBRATE'),
    [string]$AuditOut = '',
    [switch]$KeepWork
)
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
$Java = 'C:\dev\tools\jdk-17\bin\java.exe'
$Sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$verLines = Get-Content (Join-Path $PSScriptRoot 'bundletool_version.txt')
$btVer = $verLines[0].Trim()
$btSha = ($verLines[1] -replace '^sha256=', '').Trim()
$Bundletool = "C:\dev\tools\bundletool\bundletool-all-$btVer.jar"
$BuildTools = Get-ChildItem "$Sdk\build-tools" -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$Zipalign = Join-Path $BuildTools.FullName 'zipalign.exe'
$Objdump = Get-ChildItem "$Sdk\ndk\*\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-objdump.exe" -ErrorAction SilentlyContinue | Select-Object -Last 1

function Stop2([string]$m) { Write-Host "ERROR: $m" -ForegroundColor Red; exit 2 }
function Run([string]$exe, [string[]]$a) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = ($a | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
    $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $o = $p.StandardOutput.ReadToEndAsync(); $e = $p.StandardError.ReadToEndAsync()
    $p.WaitForExit()
    return @{ Code = $p.ExitCode; Out = $o.Result; Err = $e.Result }
}
function Bt([string[]]$a) { return Run $Java (@('-jar', $Bundletool) + $a) }

if (-not (Test-Path -LiteralPath $Aab)) { Stop2 "file not found: $Aab" }
$Aab = (Resolve-Path -LiteralPath $Aab).Path
foreach ($t in @($Java, $Bundletool, $Zipalign)) { if (-not (Test-Path $t)) { Stop2 "tool missing: $t (see docs/setup/DEV_ENVIRONMENT.md)" } }
if (-not $Objdump) { Stop2 'llvm-objdump not found in the NDK' }
if ((Get-FileHash $Bundletool -Algorithm SHA256).Hash.ToLower() -ne $btSha) { Stop2 'bundletool jar hash differs from tools/bundletool_version.txt' }

$fails = New-Object System.Collections.Generic.List[string]
function Check([bool]$ok, [string]$label, [string]$detail) {
    if ($ok) { Write-Host "[PASS] $label  $detail" } else { Write-Host "[FAIL] $label  $detail" -ForegroundColor Red; $script:fails.Add($label) }
}
Write-Host "AAB: $Aab"
if ($Aab -match 'TESTKEY') { Write-Host 'NOTE: test-key bundle, NOT upload-ready.' -ForegroundColor Yellow }

# (a) manifest
$m = Bt @('dump', 'manifest', "--bundle=$Aab")
if ($m.Code -ne 0) { Write-Host $m.Err; Check $false 'bundletool dump manifest' 'failed (not an AAB?)'; Write-Host 'AAB CHECK: FAIL'; exit 1 }
[xml]$x = $m.Out
$ns = New-Object System.Xml.XmlNamespaceManager($x.NameTable); $ns.AddNamespace('android', 'http://schemas.android.com/apk/res/android')
$A = 'http://schemas.android.com/apk/res/android'
$man = $x.DocumentElement
$sdk = $man.SelectSingleNode('uses-sdk')
$tgt = $sdk.GetAttribute('targetSdkVersion', $A); $min = $sdk.GetAttribute('minSdkVersion', $A)
Check ($tgt -eq '36') 'targetSdkVersion' "= $tgt (want 36)"
Check ($min -eq '24') 'minSdkVersion' "= $min (want 24)"
$perms = @($man.SelectNodes('uses-permission | uses-permission-sdk-23') | ForEach-Object { $_.GetAttribute('name', $A) } | Sort-Object -Unique)
$want = @($AllowedPermissions | Sort-Object -Unique)
Check (-not (Compare-Object $perms $want)) 'permissions' "[$($perms -join ', ')] (allowed [$($want -join ', ')])"
$app = $man.SelectSingleNode('application')
$ab = $app.GetAttribute('allowBackup', $A)
Check ($ab -eq 'false') 'allowBackup' "= '$ab' (want false)"
$cat = $man.GetAttribute('appCategory', $A); $cat2 = $app.GetAttribute('appCategory', $A); $isGame = $app.GetAttribute('isGame', $A)
Check (($cat -eq 'game') -or ($cat2 -eq 'game') -or ($isGame -eq 'true')) 'game category' "appCategory='$cat$cat2' isGame='$isGame'"
$exp = @()
foreach ($n in $app.SelectNodes('activity | activity-alias | service | receiver | provider')) {
    if ($n.GetAttribute('exported', $A) -eq 'true') {
        $isLauncher = $null -ne $n.SelectSingleNode("intent-filter[action/@*[local-name()='name' and .='android.intent.action.MAIN']][category/@*[local-name()='name' and .='android.intent.category.LAUNCHER']]")
        if (-not (($n.LocalName -in 'activity', 'activity-alias') -and $isLauncher)) { $exp += "$($n.LocalName):$($n.GetAttribute('name', $A))" + $(if ($n.GetAttribute('permission', $A)) { ' (perm-guarded)' } else { '' }) }
    }
}
Check ($exp.Count -eq 0) 'exported components' "unexpected: [$($exp -join ', ')]"
$comps = @($app.SelectNodes('activity | activity-alias | service | receiver | provider') | ForEach-Object { "$($_.LocalName):$($_.GetAttribute('name', $A))" })
Write-Host "  components: $($comps -join '; ')"

# (b) bundle config
$c = Bt @('dump', 'config', "--bundle=$Aab")
Check (($c.Code -eq 0) -and ($c.Out -match 'PAGE_ALIGNMENT_16K')) 'bundletool dump config' "PAGE_ALIGNMENT_16K present: $($c.Out -match 'PAGE_ALIGNMENT_16K')"
if ($c.Out -notmatch 'PAGE_ALIGNMENT_16K') { Write-Host ($c.Out -replace '\s+', ' ') }

# (c) universal APK, native libs
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("aabcheck_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $work | Out-Null
$apks = Join-Path $work 'u.apks'
$b = Bt @('build-apks', "--bundle=$Aab", "--output=$apks", '--mode=universal', '--overwrite')
if ($b.Code -ne 0) { Write-Host $b.Err; Check $false 'bundletool build-apks' 'failed'; Write-Host 'AAB CHECK: FAIL'; exit 1 }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($apks, (Join-Path $work 'apks'))
$apk = Join-Path $work 'apks\universal.apk'
$zp = Run $Zipalign @('-c', '-P', '16', '-v', '4', $apk)
$zpTail = (($zp.Out -split "`r?`n") | Where-Object { $_ } | Select-Object -Last 1)
Check ($zp.Code -eq 0) 'zipalign -c -P 16 -v 4' "exit $($zp.Code): $zpTail"
$z = [System.IO.Compression.ZipFile]::OpenRead($apk)
$libs = @()
try {
    foreach ($e in $z.Entries) {
        if ($e.FullName -match '^lib/(arm64-v8a|x86_64)/.+\.so$') {
            $dest = Join-Path $work ($e.FullName -replace '/', '_')
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest)
            $libs += [pscustomobject]@{ Entry = $e.FullName; Path = $dest; Size = $e.Length; Stored = ($e.CompressedLength -eq $e.Length) }
        }
    }
}
finally { $z.Dispose() }
Check ($libs.Count -gt 0) 'native libs found' "$($libs.Count) .so files (arm64-v8a + x86_64)"
$rows = @()
foreach ($l in $libs) {
    $o = Run $Objdump.FullName @('-p', $l.Path)
    $aligns = @([regex]::Matches($o.Out, '(?m)^\s*LOAD .*align 2\*\*(\d+)') | ForEach-Object { [int]$_.Groups[1].Value })
    $relro = $o.Out -match '(?m)^\s*RELRO '
    $minA = if ($aligns.Count) { ($aligns | Measure-Object -Minimum).Minimum } else { -1 }
    $ok = ($minA -ge 14)
    $rows += [pscustomobject]@{ Lib = $l.Entry; LoadAlign = if ($minA -ge 0) { "2**$minA" } else { 'none' }; Relro = $relro; Ok = $ok; Size = $l.Size }
    if (-not $ok) { Check $false "16 KB LOAD alignment $($l.Entry)" "min align 2**$minA (< 2**14)" }
}
$bad = @($rows | Where-Object { -not $_.Ok })
Check ($bad.Count -eq 0 -and $rows.Count -gt 0) '16 KB LOAD alignment (all .so)' "$($rows.Count - $bad.Count)/$($rows.Count) ok"
$rows | ForEach-Object { Write-Host ("  {0,-48} LOAD {1,-6} relro={2,-5} {3,10:N0} B" -f $_.Lib, $_.LoadAlign, $_.Relro, $_.Size) }
$noRelro = @($rows | Where-Object { -not $_.Relro })
Check ($noRelro.Count -eq 0) 'GNU_RELRO segment present' "$($rows.Count - $noRelro.Count)/$($rows.Count) libs"

# (d) size
$mb = [math]::Round((Get-Item $Aab).Length / 1MB, 2)
$zz = [System.IO.Compression.ZipFile]::OpenRead($Aab)
try { $top = $zz.Entries | Sort-Object Length -Descending | Select-Object -First 3 | ForEach-Object { '{0,11:N0} B  {1}' -f $_.Length, $_.FullName } } finally { $zz.Dispose() }
Write-Host "size: $mb MB"
Write-Host 'biggest files:'; $top | ForEach-Object { Write-Host "  $_" }
Check ($mb -le 150) 'size <= 150 MB' "$mb MB"

if ($AuditOut) {
    $t = @('| Library | LOAD alignment | RELRO | Size (B) |', '|---|---|---|---|') + ($rows | ForEach-Object { "| $($_.Lib) | $($_.LoadAlign) | $($_.Relro) | $($_.Size) |" })
    [System.IO.File]::WriteAllText($AuditOut, ($t -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
}
if (-not $KeepWork) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
if ($fails.Count -gt 0) { Write-Host "AAB CHECK: FAIL ($($fails -join '; '))" -ForegroundColor Red; exit 1 }
Write-Host 'AAB CHECK: PASS' -ForegroundColor Green
exit 0
