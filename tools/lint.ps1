# Lint: gdformat --check, gdlint, repo rules, compile gate (warnings-as-errors). Exit 0 only if all pass.
# Usage: .\tools\lint.ps1 [-SkipCompile]
param([switch]$SkipCompile)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"
Set-Location $RepoRoot

$venv = Join-Path $RepoRoot ".venv"
$vpy = Join-Path $venv "Scripts\python.exe"
if (-not (Test-Path $vpy)) {
    $py = (Find-Python) -split ' '
    $pyRest = @(); if ($py.Count -gt 1) { $pyRest = $py[1..($py.Count - 1)] }
    & $py[0] @pyRest -m venv $venv
    if ($LASTEXITCODE -ne 0) { throw "venv creation failed" }
}
$req = Join-Path $PSScriptRoot "requirements.txt"
$stamp = Join-Path $venv ".req_hash"
$hash = (Get-FileHash $req -Algorithm SHA256).Hash
if (-not (Test-Path $stamp) -or (Get-Content -Raw $stamp).Trim() -ne $hash) {
    & $vpy -m pip install -q --disable-pip-version-check -r $req
    if ($LASTEXITCODE -ne 0) { throw "pip install failed" }
    Set-Content -Path $stamp -Value $hash
}

$ErrorActionPreference = "Continue"  # native stderr must not throw in PS 5.1
$failed = @()
function Step([string]$name, [bool]$ok, [string]$detail = "") {
    if ($ok) { Write-Host "[PASS] $name $detail" }
    else { Write-Host "[FAIL] $name $detail"; $script:failed += $name }
}
$ansi = "\x1b\[[0-9;]*[A-Za-z]"

# Files to lint: .gd under src, tests, tools; skips dirs with a .lintignore (fixtures, parse canary).
$files = @(& $vpy "$PSScriptRoot\lint_repo.py" --list-gd | Where-Object { $_ })

if ($files.Count -gt 0) {
    $out = & "$venv\Scripts\gdformat.exe" --line-length 120 --check @files 2>&1 | Out-String
    $ok = ($LASTEXITCODE -eq 0)
    Step "gdformat" $ok
    if (-not $ok) { Write-Host $out }
    $out = & "$venv\Scripts\gdlint.exe" @files 2>&1 | Out-String
    $ok = ($LASTEXITCODE -eq 0)
    Step "gdlint" $ok
    if (-not $ok) { Write-Host $out }
} else { Step "gdformat/gdlint" $true "(no files)" }

$out = & $vpy "$PSScriptRoot\lint_repo.py" 2>&1 | Out-String
$ok = ($LASTEXITCODE -eq 0)
Step "repo rules" $ok (($out.Trim() -split "`n") | Select-Object -Last 1)
if (-not $ok -or $out -cmatch "WARN ") { Write-Host $out }

# Art SVG rules (V1-02): rules file freshness, lint over assets/art/src, lint self-test on the bad fixtures.
$out = & $vpy "$PSScriptRoot\art_rules_gen.py" --check 2>&1 | Out-String
Step "art rules current" ($LASTEXITCODE -eq 0) $out.Trim()
$out = & $vpy -I "$PSScriptRoot\art_lint.py" 2>&1 | Out-String
$ok = ($LASTEXITCODE -eq 0)
Step "art lint (assets/art/src)" $ok (($out.Trim() -split "`n") | Select-Object -Last 1)
if (-not $ok -or $out -match "\bERROR\b") { Write-Host $out }
$out = & $vpy -I "$PSScriptRoot\art_lint.py" --self-test 2>&1 | Out-String
$ok = ($LASTEXITCODE -eq 0)
Step "art lint self-test (expected failures)" $ok (($out.Trim() -split "`n") | Select-Object -Last 1)
if (-not $ok) { Write-Host $out }

# Play publishing tool: offline self-test (fake API, no network, no Google libraries; docs/release/play_publish.md)
$out = & $vpy -I "$PSScriptRoot\play_publish.py" --self-test 2>&1 | Out-String
$ok = ($LASTEXITCODE -eq 0)
Step "play_publish self-test" $ok (($out.Trim() -split "`n") | Select-Object -Last 1)
if (-not $ok) { Write-Host $out }

# Release pipeline files: SHA-pinned actions, secrets only in the job with environment: release (docs/release/ci_release.md)
$out = & $vpy -I "$PSScriptRoot\check_workflows.py" --self-test 2>&1 | Out-String
$ok = ($LASTEXITCODE -eq 0)
Step "workflow rules self-test (expected failures)" $ok (($out.Trim() -split "`n") | Select-Object -Last 1)
if (-not $ok) { Write-Host $out }
$out = & $vpy -I "$PSScriptRoot\check_workflows.py" 2>&1 | Out-String
$ok = ($LASTEXITCODE -eq 0)
Step "workflow rules (release.yml)" $ok (($out.Trim() -split "`n") | Select-Object -Last 1)
if (-not $ok) { Write-Host $out }

if (-not $SkipCompile) {
    # Import first so global classes (GdUnit4, class_name) resolve. Compile via tools/compile_check.gd
    # (autoloads exist in that mode; `--check-only` does not know them and fails on `Log`/`Game`).
    $bad = @()
    $imp = Invoke-GodotRetry @("--headless", "--import") -TimeoutSec 300
    $impText = $imp.Output -replace $ansi, ""
    $bad += @($impText -split "`r?`n" | Where-Object { $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:' })
    for ($i = 0; $i -lt $files.Count; $i += 60) {
        $chunk = @($files[$i..([Math]::Min($i + 59, $files.Count - 1))] | ForEach-Object { "res://$_" })
        $r = Invoke-GodotRetry (@("--headless", "-s", "res://tools/compile_check.gd", "--") + $chunk) -TimeoutSec 300
        $text = $r.Output -replace $ansi, ""
        $bad += @($text -split "`r?`n" | Where-Object {
            $_ -cmatch 'SCRIPT ERROR|Parse Error|ERROR:|Warning treated as error|Failed to instantiate|COMPILE FAIL' })
        if ($text -notmatch "COMPILE SUMMARY: checked=$($chunk.Count) ") { $bad += "compile_check did not finish (no summary)" }
    }
    Step "compile (warnings-as-errors)" ($bad.Count -eq 0) "($($files.Count) scripts)"
    foreach ($b in ($bad | Select-Object -First 20)) { Write-Host "    $b" }
} else { Write-Host "[SKIP] compile" }

if ($failed.Count -gt 0) { Write-Host "LINT FAILED: $($failed -join ', ')"; exit 1 }
Write-Host "LINT OK"
exit 0
