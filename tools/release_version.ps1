<#
.SYNOPSIS  Single source of truth for the app version (B1-02): release/version.json.
.DESCRIPTION
  versionName = MAJOR.MINOR.PATCH, plus -beta.BUILD while stage is "beta".
  versionCode = MAJOR*1000000 + MINOR*10000 + PATCH*100 + BUILD (BUILD 1..99), must stay <= 2,100,000,000.
  -Show           print name and code.
  -Bump <part>    build|patch|minor|major: edit version.json (lower parts reset: build to 1, others to 0).
  -Apply          write name/code into every preset of export_presets.cfg, config/version in project.godot and
                  the VERSION const in src/core/game.gd. Idempotent. Refuses a code lower than the one now in
                  the presets or in git HEAD (Play never accepts a lower code).
  -Check          exit 1 if the targets differ from version.json (no writes).
  Dot-source with -NoRun to reuse Get-ReleaseVersion.
#>
param([switch]$Show, [ValidateSet('', 'build', 'patch', 'minor', 'major')][string]$Bump = '', [switch]$Apply, [switch]$Check, [switch]$NoRun)
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
$VersionFile = Join-Path $RepoRoot 'release\version.json'
$MaxCode = 2100000000

function Write-LfNoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
}
function Read-LfText([string]$Path) { return ([System.IO.File]::ReadAllText($Path) -replace "`r`n", "`n") }

function Get-ReleaseVersion {
    param([string]$Path = $VersionFile)
    $j = Get-Content -Raw $Path | ConvertFrom-Json
    foreach ($f in 'major', 'minor', 'patch', 'build') {
        if ($null -eq $j.$f -or $j.$f -isnot [int] -and $j.$f -isnot [long] -or $j.$f -lt 0) { throw "version.json: '$f' must be a non-negative integer" }
    }
    if ($j.minor -gt 99 -or $j.patch -gt 99) { throw "version.json: minor and patch must be 0..99 for the code formula" }
    if ($j.build -lt 1 -or $j.build -gt 99) { throw "version.json: build must be 1..99 (bump patch instead)" }
    $stage = [string]$j.stage
    $name = "$($j.major).$($j.minor).$($j.patch)"
    if ($stage -eq 'beta') { $name += "-beta.$($j.build)" } elseif ($stage -ne '') { throw "version.json: stage must be 'beta' or ''" }
    $code = [int]$j.major * 1000000 + [int]$j.minor * 10000 + [int]$j.patch * 100 + [int]$j.build
    if ($code -gt $MaxCode) { throw "versionCode $code exceeds $MaxCode" }
    return [pscustomobject]@{ Major = [int]$j.major; Minor = [int]$j.minor; Patch = [int]$j.patch; Stage = $stage; Build = [int]$j.build; Name = $name; Code = $code }
}

function Get-TargetState {
    # Returns the version strings currently written in the three targets.
    $presets = Read-LfText (Join-Path $RepoRoot 'export_presets.cfg')
    $codes = @([regex]::Matches($presets, '(?m)^version/code=(\d+)$') | ForEach-Object { [int]$_.Groups[1].Value })
    $names = @([regex]::Matches($presets, '(?m)^version/name="([^"]*)"$') | ForEach-Object { $_.Groups[1].Value })
    $proj = Read-LfText (Join-Path $RepoRoot 'project.godot')
    $pm = [regex]::Match($proj, '(?m)^config/version="([^"]*)"$')
    $game = Read-LfText (Join-Path $RepoRoot 'src\core\game.gd')
    $gm = [regex]::Match($game, '(?m)^const VERSION: String = "([^"]*)"$')
    return [pscustomobject]@{ Codes = $codes; Names = $names; Project = $pm.Groups[1].Value; Game = $gm.Groups[1].Value }
}

function Invoke-Apply {
    $v = Get-ReleaseVersion
    $cur = Get-TargetState
    $floor = 0
    foreach ($c in $cur.Codes) { if ($c -gt $floor) { $floor = $c } }
    $headText = (& git -C $RepoRoot show 'HEAD:export_presets.cfg' 2>$null) -join "`n"
    foreach ($m in [regex]::Matches($headText, '(?m)^version/code=(\d+)')) { if ([int]$m.Groups[1].Value -gt $floor) { $floor = [int]$m.Groups[1].Value } }
    if ($v.Code -lt $floor) { throw "Refusing to lower versionCode: version.json gives $($v.Code), presets/HEAD already have $floor" }

    $pp = Join-Path $RepoRoot 'export_presets.cfg'
    $t = Read-LfText $pp
    $t = [regex]::Replace($t, '(?m)^version/code=\d+$', "version/code=$($v.Code)")
    $t = [regex]::Replace($t, '(?m)^version/name="[^"]*"$', "version/name=`"$($v.Name)`"")
    Write-LfNoBom $pp $t

    $gp = Join-Path $RepoRoot 'project.godot'
    $t = Read-LfText $gp
    if ($t -match '(?m)^config/version=') { $t = [regex]::Replace($t, '(?m)^config/version="[^"]*"$', "config/version=`"$($v.Name)`"") }
    else { $t = $t -replace '(?m)^(config/name="[^"]*")$', "`$1`nconfig/version=`"$($v.Name)`"" }
    Write-LfNoBom $gp $t

    $sp = Join-Path $RepoRoot 'src\core\game.gd'
    $t = Read-LfText $sp
    $t = [regex]::Replace($t, '(?m)^const VERSION: String = "[^"]*"$', "const VERSION: String = `"$($v.Name)`"")
    Write-LfNoBom $sp $t
    Write-Host "Applied $($v.Name) (code $($v.Code))"
}

function Test-InSync {
    $v = Get-ReleaseVersion
    $s = Get-TargetState
    $bad = @()
    if ($s.Codes.Count -eq 0 -or @($s.Codes | Where-Object { $_ -ne $v.Code }).Count) { $bad += "export_presets version/code ($($s.Codes -join ',')) != $($v.Code)" }
    if ($s.Names.Count -eq 0 -or @($s.Names | Where-Object { $_ -ne $v.Name }).Count) { $bad += "export_presets version/name ($($s.Names -join ',')) != $($v.Name)" }
    if ($s.Project -ne $v.Name) { $bad += "project.godot config/version '$($s.Project)' != $($v.Name)" }
    if ($s.Game -ne $v.Name) { $bad += "game.gd VERSION '$($s.Game)' != $($v.Name)" }
    return $bad
}

if (-not $NoRun) {
    if ($Bump) {
        $j = Get-Content -Raw $VersionFile | ConvertFrom-Json
        switch ($Bump) {
            'build' { $j.build++ }
            'patch' { $j.patch++; $j.build = 1 }
            'minor' { $j.minor++; $j.patch = 0; $j.build = 1 }
            'major' { $j.major++; $j.minor = 0; $j.patch = 0; $j.build = 1 }
        }
        $ordered = [ordered]@{ major = $j.major; minor = $j.minor; patch = $j.patch; stage = $j.stage; build = $j.build }
        $tmp = Join-Path $env:TEMP "version.$([guid]::NewGuid()).json"
        Write-LfNoBom $tmp (($ordered | ConvertTo-Json -Compress) + "`n")
        try { $null = Get-ReleaseVersion -Path $tmp } catch { Remove-Item $tmp -Force; throw }   # validate (build > 99 etc.) before writing
        Move-Item -Force $tmp $VersionFile
    }
    if ($Apply) { Invoke-Apply }
    if ($Check) {
        $bad = Test-InSync
        if ($bad.Count) { $bad | ForEach-Object { Write-Host "OUT OF SYNC: $_" }; exit 1 }
        Write-Host "version targets in sync"
    }
    if ($Show -or (-not $Bump -and -not $Apply -and -not $Check)) {
        $v = Get-ReleaseVersion
        Write-Host "versionName $($v.Name)  versionCode $($v.Code)"
    }
}
