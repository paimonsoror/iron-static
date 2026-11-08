<#
.SYNOPSIS  Emulator smoke test: deploy (optional), check process and logcat, take a screenshot and check it is not blank.
.EXAMPLE   .\tools\smoke_android.ps1 -SkipDeploy
.EXAMPLE   .\tools\smoke_android.ps1 -SkipDeploy -WaitSeconds 40 -Soak 180 -MinFps 30
-MinFps parses "[PERF] fps=.. min=.. tick_ms=.. enemies=.." lines (needs --debug-perf / --debug-load in the build) after a
PerfWarmup-second warm-up and fails if the lowest per-line fps average is below MinFps.
-ImagePath <png> runs only the screenshot checks (blank + ExpectColor) on that file, no device needed (self-test).
-Soak keeps the app running that many seconds after the wait, re-checking pid and crash patterns every 15 s.
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
    [int]$Soak = 0,
    [int]$PerfWarmup = 40,
    [double]$BlankThreshold = 0.999,
    [string]$ImagePath = "",
    [int]$GridSize = 256,
    [double]$MinColorShare = 0.0005
)
$ErrorActionPreference = "Continue"
$colorFail = ""
. "$PSScriptRoot\_common.ps1"

function Fail([string]$why) {
    Write-Host "SMOKE FAIL: $why"
    exit 1
}

$sel = @(); if ($Serial) { $sel = @('-s', $Serial) }

# adb writes daemon-start messages to stderr; never let that abort the script.
function Run-Adb { param([string[]]$A) $o = & $Adb @sel @A 2>&1; return ($o | ForEach-Object { "$_" }) }

if (-not $ImagePath) {
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

    $CrashPattern = 'FATAL EXCEPTION|\sE\sAndroidRuntime|SCRIPT ERROR|Force quitting|ANR in ' + [regex]::Escape($Package)

    if ($Soak -gt 0) {
        Write-Host "== Soak $Soak s (check every 15 s)"
        $t0 = Get-Date
        while (((Get-Date) - $t0).TotalSeconds -lt $Soak) {
            Start-Sleep -Seconds ([Math]::Min(15, [Math]::Max(1, [int]($Soak - ((Get-Date) - $t0).TotalSeconds))))
            $p2 = ((Run-Adb @('shell', 'pidof', $Package)) -join '').Trim()
            if (-not $p2 -or $p2 -notmatch '^\d+') { Fail ("process died during soak after {0:N0} s" -f ((Get-Date) - $t0).TotalSeconds) }
            if ($p2 -ne $pidText) { Fail "process restarted during soak (pid $pidText -> $p2)" }
            $cb = @(Run-Adb @('logcat', '-d') | Where-Object { $_ -match $CrashPattern })
            if ($cb.Count -gt 0) { Write-Host $cb[0]; Fail "crash pattern in log during soak: $($cb[0].Trim())" }
            Write-Host ("   t={0,4:N0} s alive pid {1}" -f ((Get-Date) - $t0).TotalSeconds, $p2)
        }
    }

    # Log scan
    $logLines = Run-Adb @('logcat', '-d')
    $bad = @($logLines | Where-Object { $_ -match $CrashPattern })
    if ($bad.Count -gt 0) {
        $bad | Select-Object -First 5 | ForEach-Object { Write-Host $_ }
        Fail "log contains errors ($($bad.Count) lines, first: $($bad[0].Trim()))"
    }
    Write-Host "== Log clean ($($logLines.Count) lines scanned)"
}

if ($ImagePath) {
    $shot = $ImagePath
    if (-not (Test-Path $shot)) { Fail "image not found: $shot" }
} else {
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
}

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
    for ($iy = 0; $iy -lt $GridSize; $iy++) {
        $y = [int][Math]::Floor(($iy + 0.5) * $bmp.Height / $GridSize)
        for ($ix = 0; $ix -lt $GridSize; $ix++) {
            $x = [int][Math]::Floor(($ix + 0.5) * $bmp.Width / $GridSize)
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
    $need = [Math]::Max(1, [int][Math]::Ceiling($MinColorShare * $total))
    Write-Host "== Samples near $ExpectColor : $near of $total (need $need = $($MinColorShare * 100) percent)"
    if ($near -lt $need) { $colorFail = "expected color $ExpectColor not found ($near of $total samples within distance 60, need $need)" }
}
if ($ImagePath) {
    if ($colorFail) { Fail $colorFail }
    Write-Host "SMOKE OK (image only)"
    exit 0
}
if ($MinFps -gt 0) {
    $ep = @(Run-Adb @('logcat', '-d', '-v', 'epoch'))
    $perf = @()
    foreach ($l in $ep) {
        if ($l -match '^\s*(\d+\.\d+)\s.*\[PERF\] fps=([\d.]+) min=([\d.]+) tick_ms=([\d.]+) enemies=(\d+)') {
            $perf += [pscustomobject]@{
                T = [double]$Matches[1]; Fps = [double]$Matches[2]; Min = [double]$Matches[3]
                TickMs = [double]$Matches[4]; Enemies = [int]$Matches[5]
            }
        }
    }
    if ($perf.Count -eq 0) { Fail "no [PERF] lines in logcat (build needs --debug-perf or --debug-load)" }
    # Lines are 10 s apart; the first appears about 10 s after launch, so launch is about first.T - 10.
    $cut = $perf[0].T - 10 + $PerfWarmup
    $use = @($perf | Where-Object { $_.T -ge $cut })
    if ($use.Count -eq 0) { Fail "no [PERF] lines after the $PerfWarmup s warm-up ($($perf.Count) lines total); wait longer" }
    $i = 0
    foreach ($u in $use) {
        $i++
        Write-Host ("   perf {0,2}: fps={1,6:N1} min={2,6:N1} tick_ms={3,6:N2} enemies={4}" -f $i, $u.Fps, $u.Min, $u.TickMs, $u.Enemies)
    }
    $lowest = ($use | Measure-Object -Property Fps -Minimum).Minimum
    Write-Host ("== PERF samples after warm-up: {0}, lowest fps average {1:N1} (MinFps {2})" -f $use.Count, $lowest, $MinFps)
    if ($lowest -lt $MinFps) { Fail ("fps {0:N1} below MinFps {1}" -f $lowest, $MinFps) }
}

if ($colorFail) { Fail $colorFail }  # reported after the fps check so both results are printed
Write-Host "SMOKE OK"
exit 0
