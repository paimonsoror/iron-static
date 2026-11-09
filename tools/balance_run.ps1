# Balance runner wrapper (M2-14): "did I break the economy". Runs Godot headless on tools/balance_run.gd.
# stdout is deterministic ("BALANCE ..." lines); TIMING and engine noise go to stderr so two runs diff clean.
# Exit 0 ok (PASS/WARN), 1 a targets.csv row is FAIL, 2 script error or bad arguments.
# Usage: .\tools\balance_run.ps1 [-Profile fresh|file.json] [-Waves 100] [-Runs 20] [-Seed 1]
#        [-Policy greedy4|all|none] [-Sector 1] [-Frame vanguard|bulwark|striker|all]   (unknown flags are forwarded and rejected by the script)
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Profile = "fresh",
    [int]$Waves = 100,
    [int]$Runs = 20,
    [int]$Seed = 1,
    [string]$Policy = "greedy4",
    [int]$Sector = 1,
    [string]$Frame = "vanguard",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Extra = @()
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$ansi = "\x1b\[[0-9;]*[A-Za-z]"
# The Sentry GDExtension prints this benign line on every --script run.
$sentryBenign = "ERROR: Sentry: Failed to initialize engine lifecycle tracking - SceneTree is unavailable."

# Import first so new class_name scripts are in the global class cache; retry the transient Sentry DLL collision.
for ($attempt = 1; $attempt -le 3; $attempt++) {
    $imp = Invoke-GodotRetry @("--headless", "--import") -TimeoutSec 120
    $impText = $imp.Output -replace $ansi, ""
    $impBad = @($impText -split "`r?`n" | Where-Object {
            $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' -and $_.Trim() -ne $sentryBenign })
    if ($impBad.Count -eq 0 -or $impText -notmatch 'Error copying library') { break }
    Start-Sleep -Seconds 3
}
if ($impBad.Count -gt 0) {
    $impBad | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
    Write-Host "BALANCE FAILED (project import)"
    exit 2
}

$profileArg = $Profile
if ($Profile -ne "fresh" -and (Test-Path $Profile)) { $profileArg = (Resolve-Path $Profile).Path -replace '\\', '/' }
$argList = @("--headless", "-s", "res://tools/balance_run.gd", "--",
    "--profile", $profileArg, "--waves", "$Waves", "--runs", "$Runs", "--seed", "$Seed",
    "--policy", $Policy, "--sector", "$Sector", "--frame", $Frame)
if ($Extra.Count -gt 0) { $argList += $Extra }
$r = Invoke-GodotRetry $argList -TimeoutSec 900
$text = $r.Output -replace $ansi, ""
$lines = @($text -split "`r?`n" | Where-Object { $_.Trim() -and $_.Trim() -ne $sentryBenign })
foreach ($l in $lines) {
    # Only deterministic result lines go to stdout; engine banner, [INFO] noise and TIMING go to stderr.
    if ($l -cmatch '^(BALANCE |usage:)') { Write-Host $l } else { [Console]::Error.WriteLine($l) }
}

$bad = @($lines | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' -and $_ -cnotmatch '^BALANCE ERROR:' })
if ($bad.Count -gt 0) { Write-Host "BALANCE FAILED (script error)"; exit 2 }
if (@($lines | Where-Object { $_ -cmatch '^BALANCE ERROR:' }).Count -gt 0) { exit 2 }
if ($text -notmatch 'BALANCE OK') { Write-Host "BALANCE FAILED"; exit 2 }
if (@($lines | Where-Object { $_ -ceq 'BALANCE RESULT FAIL' }).Count -gt 0) { exit 1 }
exit 0
