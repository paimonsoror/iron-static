# Decode a save container (.sav / .bak / run_snapshot.sav) with the real key and print it (M3-04).
# Exit 0 ok (JSON on stdout), 2 bad HMAC / unreadable / script error. Usage: .\tools\save_dump.ps1 <file>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$ansi = "\x1b\[[0-9;]*[A-Za-z]"
$sentryBenign = "ERROR: Sentry: Failed to initialize engine lifecycle tracking - SceneTree is unavailable."

if (-not (Test-Path -LiteralPath $Path)) { Write-Host "SAVE DUMP ERROR: no such file $Path"; exit 2 }
$full = (Resolve-Path -LiteralPath $Path).Path
$r = Invoke-GodotRetry @("--headless", "-s", "res://tools/save_dump.gd", "--", $full) -TimeoutSec 120
$text = $r.Output -replace $ansi, ""
$lines = @($text -split "`r?`n" | Where-Object { $_.Trim() -and $_.Trim() -ne $sentryBenign })
$ok = $false
$err = $false
foreach ($l in $lines) {
    if ($l -cmatch '^SAVE DUMP ERROR') { $err = $true; Write-Host $l; continue }
    if ($l -cmatch '^SAVE DUMP OK') { $ok = $true; [Console]::Error.WriteLine($l); continue }
    if ($l -cmatch 'SCRIPT ERROR|Parse Error|^ERROR:') { $err = $true; [Console]::Error.WriteLine($l); continue }
    if ($l -cmatch '^(Godot Engine|Sentry:|\[INFO\]|\[WARN\])') { [Console]::Error.WriteLine($l); continue }
    Write-Host $l
}
if ($err -or -not $ok) { exit 2 }
exit 0
