# Regenerate the Google Play store graphics (B1-06) into release/store and validate them.
#
#   powershell -NoProfile -File tools\store_assets.ps1            # everything
#   powershell -NoProfile -File tools\store_assets.ps1 -ValidateOnly
#
# Steps: icon (ThorVG from assets/icons/icon.svg), battle shots (docs_shots at 1080x1920), menu shots (store_shots),
# feature graphic (title banner harness, --tf-banner-play), RGB PNG conversion, then tools\store_assets.py validation.
# Godot runs one at a time, and only while at least 2.5 GB of RAM is free and no Gradle/java build is running.
# Intermediate captures go to build\store (git-ignored). See docs/release/store_assets.md.
[CmdletBinding()]
param([switch]$ValidateOnly)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"
Set-Location $RepoRoot

$Out = Join-Path $RepoRoot 'release\store'
$Work = Join-Path $RepoRoot 'build\store'
# phone_01..08 in store order: the capture (in build\store) behind each file
$PhoneOrder = @('crowd', 'draft', 'upgrades', 'foundry', 'frames', 'results', 'title', 'home')

function Wait-Machine {
    for ($i = 0; $i -lt 40; $i++) {
        $free = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB
        $busy = @(Get-Process java, gradle -ErrorAction SilentlyContinue).Count
        if ($free -ge 2.5 -and $busy -eq 0) { return }
        Write-Host ("waiting: {0:N1} GB free, {1} java/gradle process(es)" -f $free, $busy)
        Start-Sleep -Seconds 30
    }
    throw 'machine stayed busy for 20 minutes'
}

function Run-Godot([string[]]$GodotArgs, [string]$Marker, [int]$Timeout = 600) {
    Wait-Machine
    $r = Invoke-GodotRetry $GodotArgs -TimeoutSec $Timeout
    if ($r.Output -match 'SCRIPT ERROR|Parse Error') { Write-Host $r.Output; throw "Godot script error in: $GodotArgs" }
    $n = @($r.Output -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($Marker) }).Count
    if ($n -eq 0) { Write-Host $r.Output; throw "no '$Marker' line from: $GodotArgs" }
}

if (-not $ValidateOnly) {
    New-Item -ItemType Directory -Force $Out, $Work | Out-Null
    Get-ChildItem $Work -File -ErrorAction SilentlyContinue | Remove-Item -Force

    # 1. icon: 128 viewBox x4 = 512, transparent background
    & "$PSScriptRoot\svg_render.ps1" -Scale 4 -Bg '' -Out 'build\store\icon' 'assets\icons\icon.svg'
    if ($LASTEXITCODE -ne 0) { throw 'svg_render failed' }
    Copy-Item (Join-Path $Work 'icon\icon.png') (Join-Path $Out 'icon_512.png') -Force

    # 2. battle shots at 1080x1920, then menu shots, then the feature graphic (one Godot at a time)
    $win = @('--windowed', '--resolution', '540x600')
    Run-Godot ($win + @('res://src/debug/docs_shots.tscn', '--', '--dx-out=build/store', '--dx-size=1080x1920',
            '--dx-only=crowd,draft,upgrades', '--dx-speed=2', '--mute', '--no-save')) '[DX]'
    Run-Godot ($win + @('res://src/debug/store_shots.tscn', '--', '--ss-out=build/store', '--mute', '--no-save')) '[SS]'
    Run-Godot ($win + @('res://src/debug/title_frame.tscn', '--', '--tf-banner-play=build/store', '--mute', '--no-save')) '[BANNER]'

    # 3. phone shots as 24-bit RGB PNG (no alpha), in store order; the feature graphic is already RGB
    Get-ChildItem $Out -Filter 'phone_*' | Remove-Item -Force
    $stage = Join-Path $Work 'rgb'
    $ins = @(); $names = @()
    foreach ($n in $PhoneOrder) {
        $f = Join-Path $Work "$n.png"
        if (-not (Test-Path $f)) { throw "missing capture $f" }
        $ins += $f
    }
    Run-Godot (@('--headless', '--script', 'res://src/debug/png_rgb.gd', '--', "--out=$stage") + $ins) '[RGB]'
    for ($i = 0; $i -lt $PhoneOrder.Count; $i++) {
        Copy-Item (Join-Path $stage "$($PhoneOrder[$i]).png") (Join-Path $Out ('phone_{0:D2}.png' -f ($i + 1))) -Force
    }
    Copy-Item (Join-Path $Work 'feature_1024x500.png') (Join-Path $Out 'feature_1024x500.png') -Force
}

# 4. validate (plain Python, no packages)
$py = (Find-Python) -split ' '
$pyRest = @(); if ($py.Count -gt 1) { $pyRest = $py[1..($py.Count - 1)] }
& $py[0] @pyRest -I (Join-Path $PSScriptRoot 'store_assets.py') --dir $Out
exit $LASTEXITCODE

