# Rasterize SVGs with Godot's ThorVG (same rasterizer as the SVG importer) and save PNGs to look at.
#
#   powershell -NoProfile -File tools\svg_render.ps1 assets\art\src\skitter.svg
#   powershell -NoProfile -File tools\svg_render.ps1 -Scale 2 -Bg "#07090C" -Out build\svg assets\art\src\*.svg
#
# Default: scale 1.0, background #07090C (the game's Void color; pass -Bg "" for transparent),
# output build\svg\<name>.png. Exit 0 only if every file rendered.
[CmdletBinding(PositionalBinding = $false)]
param(
    [double]$Scale = 1.0,
    [string]$Bg = "#07090C",
    [string]$Out = "build\svg",
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Files
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

if (-not $Files -or $Files.Count -eq 0) { Write-Host "usage: svg_render.ps1 [-Scale 1.0] [-Bg #07090C] [-Out build\svg] file.svg ..."; exit 2 }

$resolved = @()
foreach ($f in $Files) {
    $items = @(Get-ChildItem -Path (Join-Path $RepoRoot $f) -ErrorAction SilentlyContinue)
    if ($items.Count -eq 0) { $items = @(Get-ChildItem -Path $f -ErrorAction SilentlyContinue) }
    if ($items.Count -eq 0) { Write-Host "SVG FAIL ${f}: not found"; exit 1 }
    foreach ($it in $items) { $resolved += $it.FullName }
}

$outAbs = if ([System.IO.Path]::IsPathRooted($Out)) { $Out } else { Join-Path $RepoRoot $Out }
$godotArgs = @("--headless", "-s", "res://tools/svg_render.gd", "--", "--out", $outAbs, "--scale", "$Scale")
if ($Bg -ne "") { $godotArgs += @("--bg", $Bg) }
$godotArgs += $resolved

$r = Invoke-GodotRetry $godotArgs -TimeoutSec 300
$lines = @($r.Output -split "`r?`n" | Where-Object { $_ -match '^SVG ' })
foreach ($l in $lines) { Write-Host $l }
if (-not ($lines -match '^SVG RENDER DONE')) { Write-Host "SVG RENDER ERROR: no summary (script error?)"; Write-Host $r.Output; exit 1 }
if ($lines -match 'fail=[1-9]') { exit 1 }
exit 0
