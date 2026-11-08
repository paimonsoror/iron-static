# Pixel check of the art sheets (tools\art_check.gd): sheet sizes, alpha outside cells, margins, coverage and the
# enemy silhouette guard. Parses the output and never trusts the Godot exit code.
# Exit 0 pass, 1 findings, 2 script error or no summary. With -Canary it checks a deliberately broken sheet
# (tests\art_canary, an element outside its cell) and exits 0 only if the tool DETECTS the defect.
# Usage: .\tools\art_check.ps1 [-Only <file substring>] [-Quiet] [-Canary]
param(
    [string]$Only = "",
    [switch]$Quiet,
    [switch]$Canary
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"
Set-Location $RepoRoot

$ansi = "\x1b\[[0-9;]*[A-Za-z]"
$godotArgs = @("--headless", "-s", "res://tools/art_check.gd", "--")
if ($Canary) { $godotArgs += @("--slots", "res://tests/art_canary/slots.csv", "--dir", "res://tests/art_canary/") }
if ($Only) { $godotArgs += @("--only", $Only) }
if ($Quiet) { $godotArgs += "--quiet" }

$r = Invoke-GodotRetry $godotArgs -TimeoutSec 600
$text = $r.Output -replace $ansi, ""
$lines = @($text -split "`r?`n")
$art = @($lines | Where-Object { $_ -match '^ART ' })
$bad = @($lines | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error' })
foreach ($l in $art) { Write-Host $l }
$sum = @($art | Where-Object { $_ -match '^ART CHECK SUMMARY' })
if ($bad.Count -gt 0 -or $sum.Count -eq 0) {
    Write-Host "ART CHECK TOOL ERROR: script error or no summary"
    foreach ($b in ($bad | Select-Object -First 10)) { Write-Host "    $b" }
    if ($sum.Count -eq 0) { Write-Host $text }
    exit 2
}
$m = [regex]::Match($sum[0], 'fail=(\d+)')
$fails = [int]$m.Groups[1].Value
if ($Canary) {
    $detected = @($art | Where-Object { $_ -match '^ART FAIL .*alpha outside cells' })
    if ($fails -gt 0 -and $detected.Count -gt 0) { Write-Host "CANARY OK: art_check detected the planted defect (alpha outside cells)"; exit 0 }
    Write-Host "CANARY FAILED: art_check did not flag the planted element outside its cell"
    exit 1
}
if ($fails -gt 0) { Write-Host "ART CHECK FAILED ($fails)"; exit 1 }
Write-Host "ART CHECK OK"
exit 0
