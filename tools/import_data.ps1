# CSV to .tres importer wrapper (M1-02). Runs Godot headless on tools/import_data.gd and judges by output text.
# Exit 0 ok, 1 data errors (IMPORT ERROR lines), 2 script/parse error, 4 tool failure. Last line: IMPORT OK/FAILED.
# Usage: .\tools\import_data.ps1 [-DataDir data] [-OutDir src\data_gen] [-SkipImport]
param(
    [string]$DataDir = "",
    [string]$OutDir = "",
    [switch]$SkipImport
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$ansi = "\x1b\[[0-9;]*[A-Za-z]"
# The Sentry GDExtension prints this benign line on every --script run.
$sentryBenign = "ERROR: Sentry: Failed to initialize engine lifecycle tracking - SceneTree is unavailable."

function Get-BadLines([string]$raw) {
    $text = $raw -replace $ansi, ""
    return @($text -split "`r?`n" | Where-Object {
        $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' -and $_.Trim() -ne $sentryBenign })
}

function Resolve-DataPath([string]$p, [string]$default) {
    if (-not $p) { return $default }
    if ([System.IO.Path]::IsPathRooted($p)) { return $p.Replace('\', '/') }
    return (Join-Path $RepoRoot $p).Replace('\', '/')
}

# Import first so new class_name scripts are in the global class cache (same as test.ps1/lint.ps1).
if (-not $SkipImport) {
    $imp = Invoke-Godot @("--headless", "--import") -TimeoutSec 120
    $bad = Get-BadLines $imp.Output
    if ($bad.Count -gt 0) {
        Write-Host "godot --import reported errors:"
        $bad | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
        Write-Host "IMPORT FAILED (project import)"
        exit 2
    }
}

$argList = @("--headless", "-s", "res://tools/import_data.gd", "--")
$argList += @("--data-dir", (Resolve-DataPath $DataDir "res://data"))
$argList += @("--out-dir", (Resolve-DataPath $OutDir "res://src/data_gen"))
$r = Invoke-Godot $argList -TimeoutSec 120
$text = $r.Output -replace $ansi, ""
$text -split "`r?`n" | Where-Object { $_.Trim() -and $_.Trim() -ne $sentryBenign } | ForEach-Object { Write-Host $_ }

$bad = Get-BadLines $r.Output
$dataErrors = @($bad | Where-Object { $_ -cmatch '^IMPORT ERROR:' })
$engineErrors = @($bad | Where-Object { $_ -cnotmatch '^IMPORT ERROR:' })
if ($engineErrors.Count -gt 0) { Write-Host "IMPORT FAILED (script error)"; exit 2 }
if ($dataErrors.Count -gt 0 -or $text -notmatch 'IMPORT OK') { exit 1 }
exit 0
