# Test wrapper: import, run GdUnit4, parse output. Exit 0 pass, 1 test failure, 2 script/parse error,
# 3 zero tests, 4 tool failure. Last output line: TEST SUMMARY: ...
# Usage: .\tools\test.ps1 [-Path res://tests/unit] [-Suite test_smoke] [-Canary]
param(
    [string]$Path = "res://tests/unit",
    [string]$Suite = "",
    [switch]$Canary
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$py = (Find-Python) -split ' '
$pyRest = @(); if ($py.Count -gt 1) { $pyRest = $py[1..($py.Count - 1)] }
$argList = @("$PSScriptRoot\test_runner.py", "--godot", $Godot, "--project", $RepoRoot)
if ($Canary) { $argList += "--canary" }
else {
    $argList += @("--path", $Path)
    if ($Suite) { $argList += @("--suite", $Suite) }
}
& $py[0] @pyRest -u @argList
exit $LASTEXITCODE
