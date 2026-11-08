# Emulator smoke test (`tools/smoke_android.ps1`)

Changelog: 2026-11-07 v1.1 (M1-25: -MinFps, -Soak). 2026-11-07 v1.0 (M0-08).

One command that proves the installed app launched, logged no errors and drew something.

```powershell
.\tools\smoke_android.ps1                # deploy (export, install, launch), wait 35 s, check
.\tools\smoke_android.ps1 -SkipDeploy    # check the app that is already installed
```

Parameters: `-Package com.ironstatic.game -Preset IronStatic -WaitSeconds 35 -SkipDeploy -Serial "" -ExpectColor "#FFB000"`,
plus `-BlankThreshold 0.999`, `-MinFps <n>` (fps gate, below), `-Soak <seconds>` and `-PerfWarmup 40`.

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

## Soak and fps gate (M1-25)

```powershell
# build with "-- --debug-perf" in export_presets.cfg command_line/extra_args (restore "" afterwards), deploy, then:
.\tools\smoke_android.ps1 -SkipDeploy -WaitSeconds 30 -Soak 180 -MinFps 30
```

- `-Soak <seconds>`: after the wait and the first process check, the app keeps running for that long; every 15 s the script
  re-checks `pidof` (same pid, else "process died/restarted during soak") and the crash patterns
  (`FATAL EXCEPTION`, error-level `AndroidRuntime`, `SCRIPT ERROR`, `Force quitting`, `ANR in <package>`).
- `-MinFps <n>`: parses `[PERF] fps=.. min=.. tick_ms=.. enemies=..` from `logcat -d -v epoch`, drops lines in the first
  `-PerfWarmup` seconds (default 40, counted from the first `[PERF]` line minus 10 s), prints every parsed line and fails
  if the lowest per-line `fps` average is below `n`. No `[PERF]` lines at all is a failure (the build needs `--debug-perf`
  or `--debug-load`). `min` (lowest 1 s average inside a 10 s window) is printed but not gated.
- The `-ExpectColor` result is reported last, so the fps lines still print when the colour check fails. On the battle
  screen the amber HUD is small: `#FFB000` matched only 9 of the needed 20 samples (follow-up F1 in
  `docs/playtests/m1_emulator.md`); pass `-ExpectColor ""` to skip it.
- Safe to run in a cold-booted emulator only after the first launch has settled; the first launch after a cold boot can lose
  its process once (relaunch) - relaunch with `adb shell monkey -p com.ironstatic.game -c android.intent.category.LAUNCHER 1`.
