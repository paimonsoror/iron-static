<#
.SYNOPSIS  Emulator smoke test: deploy (optional), check process and logcat, take a screenshot and check it is not blank.
.EXAMPLE   .\tools\smoke_android.ps1 -SkipDeploy
Prints SMOKE OK or "SMOKE FAIL: <reason>"; exit 0 / 1.
#>
param(
    [string]$Package = "com.ironstatic.game",
    [string]$Preset = "IronStatic",
    [int]$WaitSeconds = 35,
    [switch]$SkipDeploy,
    [string]$Serial = "",
    [string]$ExpectColor = "#FFB000",
    [double]$MinFps = 0,
    [double]$BlankThreshold = 0.999
)
$ErrorActionPreference = "Continue"
. "$PSScriptRoot\_common.ps1"

function Fail([string]$why) {
    Write-Host "SMOKE FAIL: $why"
    exit 1
}

$sel = @(); if ($Serial) { $sel = @('-s', $Serial) }

# adb writes daemon-start messages to stderr; never let that abort the script.
function Run-Adb { param([string[]]$A) $o = & $Adb @sel @A 2>&1; return ($o | ForEach-Object { "$_" }) }

if (-not $SkipDeploy) {
    $deploy = Join-Path $PSScriptRoot "deploy_android.ps1"
    $depArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $deploy, '-ProjectPath', $RepoRoot,
        '-Package', $Package, '-Preset', $Preset, '-LogSeconds', '5')
    if ($Serial) { $depArgs += @('-Serial', $Serial) }
    # Child process: deploy_android.ps1 uses ErrorActionPreference=Stop, which trips on adb stderr in some hosts.
    $dout = & powershell.exe @depArgs 2>&1 | ForEach-Object { "$_" }
    $dout | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { Fail "deploy failed (exit $LASTEXITCODE)" }
}

Write-Host "== Waiting $WaitSeconds s"
Start-Sleep -Seconds $WaitSeconds

$null = Run-Adb @('start-server')
$pidText = ((Run-Adb @('shell', 'pidof', $Package)) -join '').Trim()
if (-not $pidText -or $pidText -notmatch '^\d+') { Fail "process not running" }
Write-Host "== Process running (pid $pidText)"

# Log scan
$logLines = Run-Adb @('logcat', '-d')
$bad = @($logLines | Where-Object { $_ -match 'FATAL EXCEPTION|\sE\sAndroidRuntime|SCRIPT ERROR|Force quitting' })
if ($bad.Count -gt 0) {
    $bad | Select-Object -First 5 | ForEach-Object { Write-Host $_ }
    Fail "log contains errors ($($bad.Count) lines, first: $($bad[0].Trim()))"
}
Write-Host "== Log clean ($($logLines.Count) lines scanned)"

# Screenshot (cmd.exe from C:\ because UNC working directories break redirection)
$outDir = Join-Path $RepoRoot "build\smoke"
New-Item -ItemType Directory -Force $outDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$shot = Join-Path $outDir "$stamp.png"
$selStr = ''; if ($Serial) { $selStr = "-s $Serial " }
cmd.exe /c "cd /d C:\ && `"$Adb`" $($selStr)exec-out screencap -p > `"$shot`"" 2>&1 | Out-Null
if (-not (Test-Path $shot) -or (Get-Item $shot).Length -lt 1000) { Fail "screenshot failed" }
Copy-Item $shot (Join-Path $outDir "latest.png") -Force
Write-Host "== Screenshot $shot"

Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap($shot)
try {
    $counts = @{}
    $total = 0
    $near = 0
    $er = $null
    if ($ExpectColor) {
        $hex = $ExpectColor.TrimStart('#')
        $er = @([Convert]::ToInt32($hex.Substring(0, 2), 16), [Convert]::ToInt32($hex.Substring(2, 2), 16), [Convert]::ToInt32($hex.Substring(4, 2), 16))
    }
    for ($iy = 0; $iy -lt 64; $iy++) {
        $y = [int][Math]::Floor(($iy + 0.5) * $bmp.Height / 64)
        for ($ix = 0; $ix -lt 64; $ix++) {
            $x = [int][Math]::Floor(($ix + 0.5) * $bmp.Width / 64)
            $c = $bmp.GetPixel($x, $y)
            $key = ($c.R * 65536) + ($c.G * 256) + $c.B
            $counts[$key] = 1 + [int]$counts[$key]
            $total++
            if ($er) {
                $d = [Math]::Sqrt([Math]::Pow($c.R - $er[0], 2) + [Math]::Pow($c.G - $er[1], 2) + [Math]::Pow($c.B - $er[2], 2))
                if ($d -le 60) { $near++ }
            }
        }
    }
}
finally { $bmp.Dispose() }

$maxCount = ($counts.Values | Measure-Object -Maximum).Maximum
$frac = $maxCount / $total
Write-Host ("== Dominant color share {0:P1} of {1} samples, {2} distinct colors" -f $frac, $total, $counts.Count)
if ($frac -gt $BlankThreshold) { Fail ("screenshot is blank ({0:P1} of samples are one color)" -f $frac) }
if ($er) {
    Write-Host "== Samples near $ExpectColor : $near"
    if ($near -lt 20) { Fail "expected color $ExpectColor not found ($near samples within distance 60, need 20)" }
}
if ($MinFps -gt 0) { Write-Host "== -MinFps is reserved for M1-25 (no FPS probe yet); ignored" }

Write-Host "SMOKE OK"
exit 0
