# Dot-source from other scripts: . "$PSScriptRoot\_common.ps1"
# Provides $RepoRoot, $Godot, $Adb, Invoke-Godot, Find-Python, Write-Utf8NoBom.

$RepoRoot = Split-Path $PSScriptRoot -Parent

# Godot path comes from docs/setup/DEV_ENVIRONMENT.md; version pinned in tools/GODOT_VERSION.
$Godot = "C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$GodotVersionFile = Join-Path $PSScriptRoot "GODOT_VERSION"
$pinned = (Get-Content -Raw $GodotVersionFile).Trim()
$pinnedMajorMinor = ($pinned -split '\.')[0..1] -join '.'
if ($Godot -notmatch "\\godot\\$([regex]::Escape($pinnedMajorMinor))(\.\d+)?\\") {
    throw "tools/GODOT_VERSION ($pinned) major.minor does not match Godot path: $Godot"
}

$AndroidSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$Adb = "$AndroidSdk\platform-tools\adb.exe"

function Invoke-Godot {
    param([string[]]$ArgList, [int]$TimeoutSec = 300)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Godot
    $all = @('--path', $RepoRoot) + $ArgList
    $psi.Arguments = ($all | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.WorkingDirectory = $RepoRoot
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    try {
        [void]$p.Start()
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            try { $p.Kill() } catch { }
            throw "Godot timed out after $TimeoutSec s: $($psi.Arguments)"
        }
        $p.WaitForExit()
        $text = $outTask.Result + $errTask.Result
        return @{ ExitCode = $p.ExitCode; Output = $text }
    }
    finally {
        $p.Dispose()
    }
}

function Find-Python {
    # Returns a command string for Python >= 3.10 (e.g. "py -3.12" or "python").
    $candidates = @('py -3.12', 'py -3.11', 'py -3.10', 'python', 'python3')
    foreach ($c in $candidates) {
        $parts = $c -split ' '
        if (-not (Get-Command $parts[0] -ErrorAction SilentlyContinue)) { continue }
        try {
            $rest = @(); if ($parts.Count -gt 1) { $rest = $parts[1..($parts.Count - 1)] }
            $v = (& $parts[0] @rest --version 2>&1 | Out-String).Trim()
        } catch { continue }
        if ($v -match 'Python (\d+)\.(\d+)') {
            if ([int]$Matches[1] -gt 3 -or ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -ge 10)) { return $c }
        }
    }
    throw "Python >= 3.10 not found. Install Python 3.12 (python.org) and ensure 'py' or 'python' is on PATH."
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}
