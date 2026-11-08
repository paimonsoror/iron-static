# Headless sim runner wrapper (M1-16). Runs Godot headless on tools/sim_run.gd and judges by output text.
# stdout is deterministic (CSV lines, SUMMARY, SIM RUN OK); TIMING lines go to stderr so two runs diff clean.
# Exit 0 ok, 1 sim failed (no SIM RUN OK), 2 script/parse error or bad arguments.
# Usage: .\tools\sim_run.ps1 [-Runs 20] [-Seed 1] [-MaxWaves 200] [--any-other-flag forwarded to the script]
param(
    [int]$Runs = 20,
    [int]$Seed = 1,
    [int]$MaxWaves = 200,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Extra = @()
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$ansi = "\x1b\[[0-9;]*[A-Za-z]"
# The Sentry GDExtension prints this benign line on every --script run.
$sentryBenign = "ERROR: Sentry: Failed to initialize engine lifecycle tracking - SceneTree is unavailable."

# Import first so new class_name scripts are in the global class cache (same as import_data.ps1).
# Parallel Godot processes can collide on Sentry's DLL copy at import (transient): retry up to 3 times.
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
    Write-Host "SIM RUN FAILED (project import)"
    exit 2
}

$argList = @("--headless", "-s", "res://tools/sim_run.gd", "--")
if ($Extra.Count -gt 0) {
    $argList += $Extra   # raw flags: lets the script report unknown flags itself
}
else {
    $argList += @("--runs", "$Runs", "--seed", "$Seed", "--max-waves", "$MaxWaves")
}
$r = Invoke-Godot $argList -TimeoutSec 900
$text = $r.Output -replace $ansi, ""
$lines = @($text -split "`r?`n" | Where-Object { $_.Trim() -and $_.Trim() -ne $sentryBenign })
foreach ($l in $lines) {
    # Only deterministic result lines go to stdout; engine banner, Sentry/[INFO] noise and TIMING go to stderr.
    if ($l -cmatch '^(-?\d+,|SUMMARY |SIM RUN |usage:)') { Write-Host $l } else { [Console]::Error.WriteLine($l) }
}

$bad = @($lines | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' -and $_ -cnotmatch '^SIM RUN ERROR:' })
if ($bad.Count -gt 0) { Write-Host "SIM RUN FAILED (script error)"; exit 2 }
if (@($lines | Where-Object { $_ -cmatch '^SIM RUN ERROR:' }).Count -gt 0) { exit 2 }
if ($text -notmatch 'SIM RUN OK') { Write-Host "SIM RUN FAILED"; exit 1 }
exit 0
