---
name: soak-test
description: Run and report an IRON STATIC soak test on the Android emulator or a device - an extended deployment that watches for crashes, frame-rate drift, memory growth, state build-up and fun fatigue. Use for milestone soak checks (M1-25, M5 perf pass) or whenever a change might leak or degrade over time.
argument-hint: "[minutes, default 3] [normal|load] [milestone label, e.g. m1]"
---

# Soak test (IRON STATIC)

A soak test runs one deployment for an extended period and records how stability, performance and
memory change over time. It complements the quick smoke test (`tools\smoke_android.ps1`), the CPU
bench (`tools\perf_bench.ps1`) and headless runs (`tools\sim_run.ps1`). Adapted from the soak-test
idea in Claude-Code-Game-Studios (MIT), rewritten for this repo's tools and folders.

## Rule: no data means "not assessed"

Before writing any conclusion, list each input below as FOUND or ABSENT. A section whose input is
absent is reported as `NOT ASSESSED - NO DATA`. Never estimate, infer from another source, or leave
a number for "later". Fun and feel are never assessed by an agent: they are questions for the user.

## Inputs

| Input | How to get it |
|---|---|
| Running emulator/device | `.\tools\run_emulator.ps1` (add `-ColdBoot` if adb shows "offline"; add `-PublicDns` only when ads are involved) |
| Debug build of the current commit | `.\tools\deploy_android.ps1 -ProjectPath C:\dev\tower -Package com.normalexception.game -Preset IronStatic` |
| `[PERF]` lines (`fps`, `min`, `tick_ms`, `enemies`) | debug overlay enabled, or the `--debug-perf` / `--debug-load` user args via the export preset `command_line/extra_args` (see `docs/setup/DEV_ENVIRONMENT.md`; Android strips intent extras). Revert the preset afterwards. |
| Memory samples | `adb shell dumpsys meminfo com.normalexception.game` (TOTAL PSS) |
| Crash/error scan | `adb logcat -d` filtered for `FATAL EXCEPTION`, error-level `AndroidRuntime`, `SCRIPT ERROR`, `ANR in com.normalexception.game` |
| Screenshots | `cmd /c "cd /d C:\ && adb exec-out screencap -p > C:\dev\tower\build\soak\<name>.png"` (must run from `C:\`) |
| Process alive | `adb shell pidof com.normalexception.game` |

If `tools\smoke_android.ps1` has `-Soak`/`-MinFps` options (added in M1-25), prefer them for the run
and log parsing, and use this skill for the extra sampling and the report.

## Procedure

1. Note the commit (`git log -1 --oneline`), device (AVD `tower_phone` or the phone model), mode
   (`normal` = a real deployment; `load` = `--debug-load`, invulnerable at wave 60 to hold the
   enemy cap) and planned duration. Default 3 minutes (M1); 30 minutes for the M5 perf pass.
2. `adb logcat -c`, launch the app, wait 40 s for warm-up (first launch also compiles shaders, about
   30 s of black screen) and start the clock.
3. Every 30 s (or every 60 s for runs over 10 minutes): capture `pidof`, TOTAL PSS, and the latest
   `[PERF]` line. Take screenshots at the start, middle and end, plus any wave-10 boss or anything
   odd. Save raw logs and samples under `build\soak\<label>_<yyyyMMdd_HHmm>\` (git-ignored).
4. At the end, dump `adb logcat -d` once to the same folder and scan it for the crash patterns.
5. Run `.\tools\perf_bench.ps1 -Check` on the dev machine so CPU cost is judged even when the
   emulator's GPU (Intel Iris) limits fps.

## What to judge

| Category | Measure | Flag when |
|---|---|---|
| Stability | crashes, ANRs, `SCRIPT ERROR`, process restarts | any occurrence |
| Performance | fps avg and min per sample; `tick_ms` | avg below the milestone target (M1: 30 fps at about 160 enemies, or documented shortfall with headless numbers); last quarter's avg fps more than 10% below the first quarter's (drift) |
| Memory | TOTAL PSS over time after warm-up | growth over 10% from the first post-warm-up sample to the last, or a steady upward slope with no plateau |
| State build-up | `enemies` vs the alive caps (160 normal, 8 boss), event-ring loss counter, `spawn_throttled` if exposed by the debug overlay | counts above caps, a nonzero ring-loss counter, or values that only grow |
| Visuals | screenshots | missing enemies or beam, wrong skin-burn stage, HUD overlap, unreadable text |
| Fun fatigue | user only | always listed as questions for the user, never scored |

## Report

Write `docs\playtests\<label>_soak.md` (for example `m1_soak.md`, or the file the task names, such as
`docs/playtests/m1_emulator.md`) containing:

- Header: commit, date, device, mode, duration, build type.
- Inputs table with FOUND / ABSENT.
- Sample table: time, alive, PSS (MB), fps avg, fps min, tick_ms, enemies.
- One verdict line per category above: PASS, FLAG (with the evidence) or NOT ASSESSED - NO DATA.
- Screenshot list with a one-line description of what each shows, after actually viewing it.
- Questions for the user (feel, readability, fatigue) and follow-up tasks for anything flagged.

Commit the report and the screenshots the task asks for (`docs/playtests/<label>/`), not the raw
logs in `build\`.
