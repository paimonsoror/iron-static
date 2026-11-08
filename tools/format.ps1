# Format GDScript with gdformat (line length 120, same as lint) and normalize line endings to LF.
# gdformat on Windows writes CRLF, which fails the repo's encoding-crlf rule; always format via this script.
#
#   powershell -NoProfile -File tools\format.ps1                       # every file lint checks
#   powershell -NoProfile -File tools\format.ps1 src\sim\math tests\unit\sim\test_rng.gd
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Paths)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$venv = Join-Path $RepoRoot '.venv'
$gdformat = Join-Path $venv 'Scripts\gdformat.exe'
$vpy = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path $gdformat)) { throw "gdformat not found; run tools\lint.ps1 once to create .venv" }

Push-Location $RepoRoot
try {
    if (-not $Paths -or $Paths.Count -eq 0) {
        $files = @(& $vpy "$PSScriptRoot\lint_repo.py" --list-gd | Where-Object { $_ })
    } else {
        $files = @()
        foreach ($p in $Paths) {
            if (Test-Path $p -PathType Container) {
                $files += @(Get-ChildItem $p -Recurse -Filter *.gd | ForEach-Object { $_.FullName })
            } elseif (Test-Path $p) {
                $files += (Resolve-Path $p).Path
            } else {
                throw "No such file or folder: $p"
            }
        }
    }
    if ($files.Count -eq 0) { Write-Host "No .gd files to format"; exit 0 }

    & $gdformat --line-length 120 @files
    $code = $LASTEXITCODE

    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $fixed = 0
    foreach ($f in $files) {
        $full = if ([System.IO.Path]::IsPathRooted($f)) { $f } else { Join-Path $RepoRoot $f }
        if (-not (Test-Path $full)) { continue }
        $text = [System.IO.File]::ReadAllText($full)
        if ($text.Contains("`r`n")) {
            [System.IO.File]::WriteAllText($full, $text.Replace("`r`n", "`n"), $utf8)
            $fixed++
        }
    }
    Write-Host "format: $($files.Count) file(s) checked, $fixed converted CRLF->LF"
    exit $code
} finally {
    Pop-Location
}
