# Test wrapper: import, run GdUnit4, parse output. Exit 0 pass, 1 test failure, 2 script/parse error,
# 3 zero tests, 4 tool failure. Last output line: TEST SUMMARY: ...
# Usage: .\tools\test.ps1 [-Path res://tests/unit] [-Suite test_smoke] [-Canary]
param(
    [string[]]$Path = @("res://tests/unit", "res://tests/sim"),
    [string]$Suite = "",
    [switch]$Canary
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

# Each checkout gets its own user:// (Godot on Windows puts it under %APPDATA%): parallel test runs in several git
# worktrees share the project name, so they shared user:// and clobbered each other's scratch files (flaky importer
# and save tests). This only affects this process tree; the game's real save location is unchanged.
$env:APPDATA = Join-Path $BuildRoot "test_appdata"
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null

$py = (Find-Python) -split ' '
$pyRest = @(); if ($py.Count -gt 1) { $pyRest = $py[1..($py.Count - 1)] }
$argList = @("$PSScriptRoot\test_runner.py", "--godot", $Godot, "--project", $RepoRoot)
if ($Canary) { $argList += "--canary" }
else {
    foreach ($p in $Path) { $argList += @("--path", $p) }
    if ($Suite) { $argList += @("--suite", $Suite) }
}
& $py[0] @pyRest -u @argList
exit $LASTEXITCODE
