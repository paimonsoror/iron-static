# Sim perf bench wrapper (M1-17). Runs Godot headless on tools/perf_bench.gd and judges by output text.
# Exit 0 ok, 1 regression (--check) or no PERF OK, 2 script error or bad arguments.
# Usage: .\tools\perf_bench.ps1 [-Check] [-UpdateBaseline]
param(
    [switch]$Check,
    [switch]$UpdateBaseline
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$ansi = "\x1b\[[0-9;]*[A-Za-z]"
# The Sentry GDExtension prints this benign line on every --script run.
$sentryBenign = "ERROR: Sentry: Failed to initialize engine lifecycle tracking - SceneTree is unavailable."

# Import first so new class_name scripts are in the global class cache. Parallel Godot processes can
# collide on Sentry's DLL copy (transient): retry up to 3 times.
for ($attempt = 1; $attempt -le 3; $attempt++) {
    $imp = Invoke-Godot @("--headless", "--import") -TimeoutSec 120
    $impText = $imp.Output -replace $ansi, ""
    $impBad = @($impText -split "`r?`n" | Where-Object {
            $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' -and $_.Trim() -ne $sentryBenign })
    if ($impBad.Count -eq 0 -or $impText -notmatch 'Error copying library') { break }
    Start-Sleep -Seconds 3
}
if ($impBad.Count -gt 0) {
    $impBad | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
    Write-Host "PERF FAILED (project import)"
    exit 2
}

$argList = @("--headless", "-s", "res://tools/perf_bench.gd", "--")
if ($Check) { $argList += "--check" }
if ($UpdateBaseline) { $argList += "--update-baseline" }
$r = Invoke-Godot $argList -TimeoutSec 600
$text = $r.Output -replace $ansi, ""
$lines = @($text -split "`r?`n" | Where-Object { $_.Trim() -and $_.Trim() -ne $sentryBenign })
foreach ($l in $lines) {
    if ($l -cmatch '^PERF') { Write-Host $l }
}

$bad = @($lines | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' })
if ($bad.Count -gt 0) { $bad | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" }; Write-Host "PERF FAILED (script error)"; exit 2 }
if (@($lines | Where-Object { $_ -cmatch '^PERF ERROR:' }).Count -gt 0) { exit 2 }
if (@($lines | Where-Object { $_ -ceq 'PERF CHECK FAILED' }).Count -gt 0) { exit 1 }
if ($text -notmatch 'PERF OK') { Write-Host "PERF FAILED"; exit 1 }
exit 0
