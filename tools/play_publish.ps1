# Publish IRON STATIC to Google Play (dry run by default). Docs: docs/release/play_publish.md
# Usage: .\tools\play_publish.ps1 release build\release\ironstatic-<name>-<code>.aab [--auth-check|--validate|--commit]
#        .\tools\play_publish.ps1 listing [--validate|--commit] ;  .\tools\play_publish.ps1 --self-test
# Runs python in isolated mode (-I), using the venv OUTSIDE the repo (default C:\dev\tools\venvs\play, or $env:PLAY_VENV).
# The key path comes from secrets.local.json ("play_service_account_json") or $env:PLAY_SERVICE_ACCOUNT_JSON.
# Exit: 0 ok, 1 refused/failed, 2 usage/config.
[CmdletBinding(PositionalBinding = $false)]
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"
Set-Location $RepoRoot
$venv = if ($env:PLAY_VENV) { $env:PLAY_VENV } else { 'C:\dev\tools\venvs\play' }
$vpy = Join-Path $venv 'Scripts\python.exe'
if (Test-Path $vpy) { $py = @($vpy) } else { $py = (Find-Python) -split ' ' }
$pyRest = @(); if ($py.Count -gt 1) { $pyRest = $py[1..($py.Count - 1)] }
$ErrorActionPreference = "Continue"
& $py[0] @pyRest -I "$PSScriptRoot\play_publish.py" @Rest
exit $LASTEXITCODE
