# Render all IRON STATIC audio (synth scripts in tools\audio_gen). Deterministic: same bytes every run.
# Usage: .\tools\audio_gen.ps1 [-Assets <dir>] [-Sketch <dir>]   (defaults: assets\audio and docs\playtests\a1)
# First run creates tools\audio_gen\.venv from tools\audio_gen\requirements.txt.
[CmdletBinding(PositionalBinding = $false)]
param([string]$Assets, [string]$Sketch)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"
Set-Location $RepoRoot
$venv = Join-Path $PSScriptRoot "audio_gen\.venv"
$vpy = Join-Path $venv "Scripts\python.exe"
if (-not (Test-Path $vpy)) {
    $py = (Find-Python) -split ' '
    $pyRest = @(); if ($py.Count -gt 1) { $pyRest = $py[1..($py.Count - 1)] }
    & $py[0] @pyRest -m venv $venv
    & $vpy -m pip install -q -r "$PSScriptRoot\audio_gen\requirements.txt"
}
$argList = @("-I", "$PSScriptRoot\audio_gen\render.py")
if ($Assets) { $argList += @("--assets", $Assets) }
if ($Sketch) { $argList += @("--sketch", $Sketch) }

$ErrorActionPreference = "Continue"
& $vpy @argList
exit $LASTEXITCODE
