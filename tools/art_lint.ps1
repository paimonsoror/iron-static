# Static lint of art SVGs (rules: tools\art_rules.json, slot table: assets\art\slots.csv). Exit 0 pass, 1 errors, 2 tool error.
# Usage: .\tools\art_lint.ps1 [file.svg ...] [-SelfTest]   (default: every assets\art\src\**\*.svg)
[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$SelfTest,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Files
)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"
Set-Location $RepoRoot

$vpy = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (Test-Path $vpy) { $py = @($vpy) } else { $py = (Find-Python) -split ' ' }
$pyRest = @(); if ($py.Count -gt 1) { $pyRest = $py[1..($py.Count - 1)] }
$argList = @("-I", "$PSScriptRoot\art_lint.py")
if ($SelfTest) { $argList += "--self-test" }
foreach ($f in $Files) { if ($f) { $argList += $f } }
$ErrorActionPreference = "Continue"
& $py[0] @pyRest @argList
exit $LASTEXITCODE
