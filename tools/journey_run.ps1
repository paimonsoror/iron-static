# Journey simulator wrapper (FO-2): consecutive deployments with Foundry spending between them. Runs Godot headless on
# tools/journey_run.gd. stdout is deterministic ("JOURNEY ..." lines); TIMING and engine noise go to stderr.
# Exit 0 ok, 2 script error, bad arguments or a failed self-check. Run ONE at a time (memory); never in parallel.
# Usage: .\tools\journey_run.ps1 [-Spend cheapest|laser|recommended|roundrobin|none] [-Deployments 12] [-Seed 1] [-Waves 120]
#        [-Frame vanguard] [-Mode timed|purge] [-RunPolicy greedy4] [-Probe 0 -Runs 20] [-Name text]
#        [-ProfileFile tests/profiles/foundry_300.json] [-Frames] [-SkipImport] [-Set "sim.data_level_coef=0.03","foundry.laser_output.fc0=40"] [-SelfCheck]
# Flags not listed are forwarded to the script as given (--flag value).
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Spend = "cheapest",
    [int]$Deployments = 12,
    [int]$Seed = 1,
    [int]$Waves = 120,
    [string]$Frame = "vanguard",
    [string]$Mode = "timed",
    [string]$RunPolicy = "greedy4",
    [double]$Probe = 0,
    [int]$Runs = 20,
    [string]$Name = "",
    [string]$ProfileFile = "",
    [switch]$Frames,
    [switch]$SkipImport,
    [string[]]$Set = @(),
    [switch]$SelfCheck,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Extra = @()
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$ansi = "\x1b\[[0-9;]*[A-Za-z]"
$sentryBenign = "ERROR: Sentry: Failed to initialize engine lifecycle tracking - SceneTree is unavailable."

# Import first so the new class_name scripts are in the global class cache (same retry as balance_run).
$impBad = @()
for ($attempt = 1; $attempt -le 3 -and -not $SkipImport; $attempt++) {
    $imp = Invoke-GodotRetry @("--headless", "--import") -TimeoutSec 120
    $impText = $imp.Output -replace $ansi, ""
    $impBad = @($impText -split "`r?`n" | Where-Object {
            $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' -and $_.Trim() -ne $sentryBenign })
    if ($impBad.Count -eq 0 -or $impText -notmatch 'Error copying library') { break }
    Start-Sleep -Seconds 3
}
if ($impBad.Count -gt 0) {
    $impBad | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
    Write-Host "JOURNEY FAILED (project import)"
    exit 2
}

$argList = @("--headless", "-s", "res://tools/journey_run.gd", "--")
if ($SelfCheck) { $argList += "--self-check" }
else {
    $argList += @("--spend", $Spend, "--deployments", "$Deployments", "--seed", "$Seed", "--waves", "$Waves",
        "--frame", $Frame, "--mode", $Mode, "--run-policy", $RunPolicy,
        "--runs", "$Runs")
    if ($Probe -gt 0) { $argList += @("--probe", "$Probe") }
    if ($Name) { $argList += @("--name", $Name) }
    if ($ProfileFile) { $argList += @("--profile", $ProfileFile) }
    if ($Frames) { $argList += "--frames" }
    foreach ($s in $Set) { foreach ($one in ($s -split ";")) { if ($one) { $argList += @("--set", $one) } } }  # several overrides: -Set "a=1;b=2"
}
if ($Extra.Count -gt 0) { $argList += $Extra }
$r = Invoke-GodotRetry $argList -TimeoutSec 3000
$text = $r.Output -replace $ansi, ""
$lines = @($text -split "`r?`n" | Where-Object { $_.Trim() -and $_.Trim() -ne $sentryBenign })
foreach ($l in $lines) {
    if ($l -cmatch '^(JOURNEY |usage:)') { Write-Host $l } else { [Console]::Error.WriteLine($l) }
}

$bad = @($lines | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' -and $_ -cnotmatch '^JOURNEY ERROR:' })
if ($bad.Count -gt 0) { Write-Host "JOURNEY FAILED (script error)"; exit 2 }
if (@($lines | Where-Object { $_ -cmatch '^JOURNEY ERROR:' }).Count -gt 0) { exit 2 }
if ($SelfCheck) {
    if (@($lines | Where-Object { $_ -ceq 'JOURNEY SELFCHECK PASS' }).Count -eq 1) { exit 0 }
    Write-Host "JOURNEY FAILED (self-check)"; exit 2
}
if ($text -notmatch 'JOURNEY OK') { Write-Host "JOURNEY FAILED"; exit 2 }
exit 0
