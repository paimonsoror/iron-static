# Dot-source from other scripts: . "$PSScriptRoot\_common.ps1"
# Provides $RepoRoot, $BuildRoot, $Godot, $Adb, Invoke-Godot, Find-Python, Write-Utf8NoBom.

$RepoRoot = Split-Path $PSScriptRoot -Parent

# Godot path comes from docs/setup/DEV_ENVIRONMENT.md; version pinned in tools/GODOT_VERSION.
# CI (docs/release/ci_release.md) overrides the tool locations with environment variables; unset means the local defaults.
#   IRONSTATIC_GODOT = full path of the Godot console exe;  IRONSTATIC_JDK = JDK 17 home;  IRONSTATIC_BUNDLETOOL = bundletool jar.
$Godot = "C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$GodotVersionFile = Join-Path $PSScriptRoot "GODOT_VERSION"
$pinned = (Get-Content -Raw $GodotVersionFile).Trim()
$pinnedMajorMinor = ($pinned -split '\.')[0..1] -join '.'
if ($env:IRONSTATIC_GODOT) { $Godot = $env:IRONSTATIC_GODOT }
elseif ($Godot -notmatch "\\godot\\$([regex]::Escape($pinnedMajorMinor))(\.\d+)?\\") {
    throw "tools/GODOT_VERSION ($pinned) major.minor does not match Godot path: $Godot"
}
$JdkHome = if ($env:IRONSTATIC_JDK) { $env:IRONSTATIC_JDK } else { 'C:\dev\tools\jdk-17' }

# build/ holds nested projects and PNGs; .gdignore keeps Godot from scanning it.
$BuildRoot = Join-Path $RepoRoot "build"
if (-not (Test-Path $BuildRoot)) { New-Item -ItemType Directory -Path $BuildRoot | Out-Null }
$gdIgnore = Join-Path $BuildRoot ".gdignore"
if (-not (Test-Path $gdIgnore)) { [System.IO.File]::WriteAllText($gdIgnore, "") }

$AndroidSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$Adb = "$AndroidSdk\platform-tools\adb.exe"

# Invoke-Godot starts the non-console exe. Its stdout and stderr are redirected to pipes here, so output is still
# captured. The *_console.exe wrapper sometimes never exits after the real Godot has exited: `--headless --import`
# hung in 3 of 6 runs, while this exe exited in 6 of 6, in about 13 s (2026-11-10). $Godot stays the console exe for
# scripts that call it directly with `&`, because PowerShell does not wait for a GUI-subsystem exe in that case.
$GodotNoConsole = $Godot -replace '_console\.exe$', '.exe'

function Invoke-Godot {
    param([string[]]$ArgList, [int]$TimeoutSec = 300)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = if (Test-Path $GodotNoConsole) { $GodotNoConsole } else { $Godot }
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
            # Kill the whole tree: the *_console.exe wrapper starts the real Godot as a child, and killing only the
            # wrapper left that child running and holding the project, so later runs hung too (2026-11-09).
            & taskkill.exe /PID $p.Id /T /F 2>&1 | Out-Null
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

# Parallel Godot processes can collide on the temp copy of a GDExtension library (Sentry):
# "Failed to open ...~libsentry...dll" / "Error copying library". That is transient, so retry.
$TransientGodotPattern = '~lib\S*\.(dll|so)|Error copying library|Error loading extension'

function Invoke-GodotRetry {
    param([string[]]$ArgList, [int]$TimeoutSec = 300, [int]$Retries = 2, [int]$WaitSec = 15)
    $r = Invoke-Godot $ArgList -TimeoutSec $TimeoutSec
    for ($n = 1; $n -le $Retries -and ($r.Output -match $TransientGodotPattern); $n++) {
        Write-Host "Transient GDExtension copy error; retrying Godot ($n/$Retries) in $WaitSec s"
        Start-Sleep -Seconds $WaitSec
        $r = Invoke-Godot $ArgList -TimeoutSec $TimeoutSec
    }
    return $r
}
