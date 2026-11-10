<#
.SYNOPSIS  Render baseline bench on the emulator (V1-03): fps, frame-time, draw calls, memory at ~40 / ~100 / ~165 enemies.
.DESCRIPTION
Needs a debug build installed with "-- --debug-perf" in export_presets.cfg command_line/extra_args (restore "" afterwards).
Per scenario the script launches the app fresh (force-stop, monkey), opens the debug overlay by double tap in the
top-left corner, taps the scenario button (coordinates are 1080-wide base px = physical px on tower_phone), hides the
overlay, waits for the "[BENCH] load finished" log line, discards -Warmup seconds, then collects the 10 s [PERF]
windows for -Seconds and samples PSS (dumpsys meminfo) every 10 s.
Scenarios:  live165  = LOAD button: wave 60 live (sim runs; the M1 reference scenario, about 165 enemies)
            hold40 / hold100 / hold165 = static crowd (sim paused when wave 14 / 19 / 30 is reached; render cost only)
            live40 / live100 are not offered: the live count drifts every wave (no steady density below saturation).
Options:    -Tier high|mid|low (overlay tier button), -NoVsync (overlay VSYNC button: uncapped fps, true throughput),
            -HideBattlefield (NOBF: HUD and panel only), -HideHud (NOHUD: battlefield only): cost split by difference.
Outputs under build\render_bench\<stamp>\: log.txt (raw logcat), windows.csv, summary.md; prints the summary table.
.EXAMPLE   powershell -NoProfile -File tools\render_bench.ps1
.EXAMPLE   powershell -NoProfile -File tools\render_bench.ps1 -Scenarios hold165,live165 -Seconds 90 -NoVsync -Tag novsync
#>
param(
    [string[]]$Scenarios = @("hold40", "hold100", "hold165", "live165"),
    [int]$Seconds = 120,
    [int]$Warmup = 20,
    [int]$BootWait = 40,
    [string]$Tier = "high",
    [switch]$NoVsync,
    [switch]$HideBattlefield,
    [switch]$HideHud,
    [string]$Tag = "",
    [string]$Package = "com.normalexception.games.ironstatic",
    [string]$Serial = ""
)
$ErrorActionPreference = "Continue"
$Scenarios = @($Scenarios | ForEach-Object { $_ -split "," } | Where-Object { $_ })  # -File passes a,b as one string
. "$PSScriptRoot\_common.ps1"

function Fail([string]$why) { Write-Host "RENDER BENCH FAIL: $why"; exit 1 }
$sel = @(); if ($Serial) { $sel = @('-s', $Serial) }
function Run-Adb { param([string[]]$A) $o = & $Adb @sel @A 2>&1; return ($o | ForEach-Object { "$_" }) }

# Overlay button centers (base px; see src/ui/debug_overlay.tscn).
$Buttons = @{
    live165 = @(781, 365); hold40 = @(81, 665); hold100 = @(221, 665); hold165 = @(361, 665)
    high = @(81, 565); mid = @(221, 565); low = @(361, 565); vsync = @(501, 565); nobf = @(641, 665); nohud = @(781, 665)
}

# An adb server restart (any tool that exports with Godot restarts it) can leave the emulator offline for a while.
function Wait-Adb {
    for ($i = 0; $i -lt 10; $i++) {
        $null = Run-Adb @('start-server')
        if (((Run-Adb @('get-state')) -join '').Trim() -eq 'device') { return }
        $null = Run-Adb @('reconnect', 'offline')
        Start-Sleep -Seconds 3
    }
}
function Get-AppPid {
    for ($i = 0; $i -lt 4; $i++) {
        $t = ((Run-Adb @('shell', 'pidof', $Package)) -join '').Trim()
        if ($t -match '^\d+') { return $t }
        Wait-Adb
    }
    return ''
}
function Show-Overlay { $null = Run-Adb @('shell', 'input tap 40 40; input tap 40 40'); Start-Sleep -Seconds 1 }
function Tap([string]$name) {
    $b = $Buttons[$name]
    $null = Run-Adb @('shell', "input tap $($b[0]) $($b[1])")
    Start-Sleep -Milliseconds 700
}
function Get-Log { return @(Run-Adb @('logcat', '-d', '-v', 'epoch')) }
function Get-Pss {
    $t = (Run-Adb @('shell', 'dumpsys', 'meminfo', $Package)) -join "`n"
    if ($t -match 'TOTAL PSS:\s+(\d+)') { return [math]::Round([double]$Matches[1] / 1024.0, 1) }
    if ($t -match '(?m)^\s+TOTAL\s+(\d+)') { return [math]::Round([double]$Matches[1] / 1024.0, 1) }
    return 0.0
}

$null = Run-Adb @('start-server')
$state = ((Run-Adb @('get-state')) -join '').Trim()
if ($state -ne 'device') { Fail "no device online (state '$state'); cold boot the emulator: tools\run_emulator.ps1 -ColdBoot" }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outDir = Join-Path $RepoRoot "build\render_bench\$stamp"
New-Item -ItemType Directory -Force $outDir | Out-Null

# Emulator state for the record.
$devUp = ((Run-Adb @('shell', 'cat /proc/uptime')) -join '').Trim().Split(' ')[0]
$qemu = Get-Process -Name 'qemu-system-x86_64*' -ErrorAction SilentlyContinue | Select-Object -First 1
$hostUp = 'unknown'
if ($qemu) { $hostUp = ("{0:N0} min" -f ((Get-Date) - $qemu.StartTime).TotalMinutes) }
$model = ((Run-Adb @('shell', 'getprop ro.product.model')) -join '').Trim()
Write-Host "== Emulator: $model, android uptime $devUp s, qemu process age $hostUp"

$rows = New-Object System.Collections.Generic.List[object]
$notes = @()
foreach ($scn in $Scenarios) {
    if (-not $Buttons.ContainsKey($scn)) { Fail "unknown scenario '$scn'" }
    $label = $scn; if ($HideBattlefield) { $label += '+nobf' }; if ($HideHud) { $label += '+nohud' }
    Write-Host "== Scenario $label (tier $Tier, vsync $(if ($NoVsync) { 'off' } else { 'on' }))"
    $null = Run-Adb @('shell', 'am', 'force-stop', $Package)
    Start-Sleep -Seconds 2
    $null = Run-Adb @('logcat', '-c')
    $null = Run-Adb @('shell', 'monkey', '-p', $Package, '-c', 'android.intent.category.LAUNCHER', '1')
    Start-Sleep -Seconds $BootWait
    $pidText = Get-AppPid
    if (-not $pidText) { Fail "app not running after launch (scenario $scn)" }

    Show-Overlay
    if ($Tier -ne 'high') { Tap $Tier }
    if ($NoVsync) { Tap 'vsync' }
    Tap $scn
    if ($HideBattlefield) { Tap 'nobf' }
    if ($HideHud) { Tap 'nohud' }
    Show-Overlay   # second double tap hides the overlay again (no per-frame text work during the measurement)

    # Wait for the load to finish (up to 150 s).
    $finishT = 0.0; $finishEnemies = 0
    $t0 = Get-Date
    while (((Get-Date) - $t0).TotalSeconds -lt 150) {
        Start-Sleep -Seconds 3
        $hit = @(Get-Log | Where-Object { $_ -match '^\s*(\d+\.\d+)\s.*\[BENCH\] load finished wave=(\d+) enemies=(\d+)' })
        if ($hit.Count -gt 0) {
            $null = $hit[-1] -match '^\s*(\d+\.\d+)\s.*\[BENCH\] load finished wave=(\d+) enemies=(\d+)'
            $finishT = [double]$Matches[1]; $finishEnemies = [int]$Matches[3]
            break
        }
    }
    if ($finishT -eq 0.0) { Fail "load did not finish for scenario $scn (emulator hung? cold boot and retry once)" }
    Write-Host "   load finished at device t=$finishT, enemies=$finishEnemies; warm-up $Warmup s, collecting $Seconds s"

    $pss = @()
    $t1 = Get-Date
    while (((Get-Date) - $t1).TotalSeconds -lt ($Warmup + $Seconds)) {
        Start-Sleep -Seconds 10
        $p2 = Get-AppPid
        if ($p2 -ne $pidText) { Fail "process died or restarted during $scn (pid $pidText -> $p2)" }
        $pss += [pscustomobject]@{ T = ((Get-Date) - $t1).TotalSeconds; Mb = (Get-Pss) }
    }

    $lines = Get-Log
    $lines | Set-Content -Encoding ASCII (Join-Path $outDir "log_$label.txt")
    $crash = @($lines | Where-Object { $_ -match 'FATAL EXCEPTION|\sE\sAndroidRuntime|SCRIPT ERROR|ANR in ' })
    if ($crash.Count -gt 0) { Fail "crash pattern in log during ${scn}: $($crash[0].Trim())" }
    $n = 0
    foreach ($l in $lines) {
        if ($l -notmatch '^\s*(\d+\.\d+)\s.*\[PERF\] (fps=.*)$') { continue }
        $t = [double]$Matches[1]; $kv = @{}
        foreach ($m in [regex]::Matches($Matches[2], '(\w+)=([^\s]+)')) { $kv[$m.Groups[1].Value] = $m.Groups[2].Value }
        if ($t -lt ($finishT + $Warmup)) { continue }
        if (-not $kv.ContainsKey('draws')) { Fail "[PERF] line lacks render fields (old build?): $l" }
        $idx = [int](($t - $finishT) - $Warmup)
        $pssNear = 0.0
        if ($pss.Count -gt 0) { $pssNear = ($pss | Sort-Object { [math]::Abs($_.T - ($t - $finishT)) } | Select-Object -First 1).Mb }
        $n++
        $rows.Add([pscustomobject]@{
                Scenario = $label; Win = $n; Enemies = [int]$kv['enemies']; Fps = [double]$kv['fps']; Min = [double]$kv['min']
                FrameMs = [double]$kv['frame_ms']; P95Ms = [double]$kv['p95_ms']; MaxMs = [double]$kv['max_ms']
                ProcMs = [double]$kv['proc_ms']; TickMs = [double]$kv['tick_ms']; Draws = [int]$kv['draws']
                DrawsMax = [int]$kv['draws_max']; Objects = [int]$kv['objects']; Prims = [int]$kv['prims']
                TexMb = [double]$kv['tex_mb']; VidMb = [double]$kv['vid_mb']; RCpuMs = [double]$kv['rcpu_ms']
                RGpuMs = [double]$kv['rgpu_ms']; PssMb = $pssNear; Tier = $kv['tier']
            })
    }
    if ($n -eq 0) { Fail "no [PERF] windows collected for $scn" }
    Write-Host "   $n windows"
    $rows | Export-Csv -NoTypeInformation -Encoding ASCII (Join-Path $outDir "windows.csv")
}

$rows | Export-Csv -NoTypeInformation -Encoding ASCII (Join-Path $outDir "windows.csv")
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("Render bench $stamp tag='$Tag' tier=$Tier vsync=$(if ($NoVsync) { 'off' } else { 'on' }) window=$Seconds s warmup=$Warmup s")
[void]$sb.AppendLine("Emulator: $model, android uptime $devUp s, qemu process age $hostUp")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| scenario | windows | enemies | fps avg | fps min window | worst 1s dip | frame ms avg | p95 ms | proc ms | tick ms | draws | objects | prims | tex MB | vid MB | PSS MB first/last |")
[void]$sb.AppendLine("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
foreach ($g in ($rows | Group-Object Scenario)) {
    $r = @($g.Group)
    function Avg([string]$p) { return (($r | Measure-Object -Property $p -Average).Average) }
    $q = [math]::Max(1, [int][math]::Floor($r.Count / 4))
    $first = [math]::Round((($r | Select-Object -First $q | Measure-Object -Property PssMb -Average).Average), 1)
    $last = [math]::Round((($r | Select-Object -Last $q | Measure-Object -Property PssMb -Average).Average), 1)
    [void]$sb.AppendLine(("| {0} | {1} | {2:N0} | {3:N1} | {4:N1} | {5:N0} | {6:N1} | {7:N1} | {8:N2} | {9:N2} | {10:N1} | {11:N0} | {12:N0} | {13:N1} | {14:N1} | {15} / {16} |" -f `
                $g.Name, $r.Count, (Avg 'Enemies'), (Avg 'Fps'), (($r | Measure-Object -Property Fps -Minimum).Minimum), `
            (($r | Measure-Object -Property Min -Minimum).Minimum), (Avg 'FrameMs'), (Avg 'P95Ms'), (Avg 'ProcMs'), (Avg 'TickMs'), `
            (Avg 'Draws'), (Avg 'Objects'), (Avg 'Prims'), (Avg 'TexMb'), (Avg 'VidMb'), $first, $last))
}
$sum = $sb.ToString()
[System.IO.File]::WriteAllText((Join-Path $outDir "summary.md"), $sum, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ""
Write-Host $sum
Write-Host "Output: $outDir"
Write-Host "RENDER BENCH OK"
exit 0
