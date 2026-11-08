# Emulator smoke test (`tools/smoke_android.ps1`)

Changelog: 2026-11-07 v1.0 (M0-08).

One command that proves the installed app launched, logged no errors and drew something.

```powershell
.\tools\smoke_android.ps1                # deploy (export, install, launch), wait 35 s, check
.\tools\smoke_android.ps1 -SkipDeploy    # check the app that is already installed
```

Parameters: `-Package com.ironstatic.game -Preset IronStatic -WaitSeconds 35 -SkipDeploy -Serial "" -ExpectColor "#FFB000"`,
plus `-BlankThreshold 0.999` and `-MinFps` (reserved for M1-25, currently ignored).

## Checks (in order)

1. `adb shell pidof <package>` must return a pid, else `SMOKE FAIL: process not running`.
2. `adb logcat -d` is scanned for `FATAL EXCEPTION`, ` E AndroidRuntime`, `SCRIPT ERROR`, `Force quitting`.
3. Screenshot to `build\smoke\<yyyyMMdd_HHmmss>.png` (copied to `build\smoke\latest.png`), taken by `cmd.exe` from `C:\`.
4. A 64x64 grid of pixels is sampled with `System.Drawing`: fail if more than `BlankThreshold` of samples are one colour,
   and fail if fewer than 20 samples are within RGB distance 60 of `-ExpectColor`.

Prints `SMOKE OK` (exit 0) or `SMOKE FAIL: <reason>` (exit 1).

## Decisions and gotchas

- **(impl)** The spec says fail at more than 99% one colour. The title screen is a dark background with a line of text, so
  99.3% of grid samples are background and the check would always fail. Default is now 99.9%; the expected-colour check
  still catches a screen that is only the clear colour.
- **(impl)** Only `AndroidRuntime` lines at error level count. The `monkey` launcher itself logs `D/I AndroidRuntime`
  lines (VM start, "Calling main entry ...Monkey") on every launch, which would be false positives.
- With `-SkipDeploy` the log scan sees whatever is in the logcat buffer. `deploy_android.ps1` clears logcat before launch;
  if an old crash is in the buffer run `adb logcat -c` and relaunch.
- Expected-colour margin on the title screen is thin (about 22 of the required 20 samples at 1080x2400) because the
  text is small relative to the grid. If the title layout shrinks, raise sampling density or lower the requirement.
- Deploy is run as a child `powershell.exe`: `deploy_android.ps1` uses `ErrorActionPreference=Stop`, and adb's
  "daemon not running; starting now" stderr line aborts it inside some hosts (e.g. an agent shell with `2>&1`).
- Wait times: 35 s default covers the first-launch shader compile; after an emulator cold boot wait 20-30 s before running.
