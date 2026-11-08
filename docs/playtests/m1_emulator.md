# M1 emulator verification and soak (M1-25)

- Commit: `fb5aa36` (M1-23/24) plus uncommitted M1-25 changes (see "Fixes made during this task").
- Date: 2026-11-07. Device: AVD `tower_phone` (1080x2400, host GPU: Intel Iris Plus, OpenGL ES 3.0 translator). Build: debug APK (Gradle).
- Modes: **normal** (`--debug-perf` via export preset, natural deployment, one REDEPLOY) and **load** (`LOAD` button in the debug overlay on top of `--debug-perf`: invulnerable run fast-forwarded to wave 60).
- Durations: normal run 5.5 min of samples (two deployments); load run 4 min 50 s of `[PERF]` lines at about 165 enemies, of which a 181 s soak was supervised by `smoke_android.ps1 -Soak 180` (pid checked every 15 s).

## Inputs

| Input | Status |
|---|---|
| Running emulator | FOUND (cold-booted twice, see stability) |
| Debug build of the current tree | FOUND (3 deploys; data fix and overlay fix included from deploy 2 and 3) |
| `[PERF]` lines | FOUND (`build\soak\normal\`, `build\soak\load\`; raw logcat saved there) |
| Memory samples (`dumpsys meminfo` TOTAL PSS) | FOUND |
| Crash/error scan of `adb logcat -d` | FOUND (patterns: `FATAL EXCEPTION`, error-level `AndroidRuntime`, `SCRIPT ERROR`, `ANR in com.ironstatic.game`, `Force quitting`) |
| Screenshots | FOUND (`docs/playtests/m1/`) |
| `perf_bench -Check` | FOUND |

## Samples

Normal run (seed 1 then seed 2). `t` = seconds since first sample; the run died at wave 8 (2:50) at t about 190 s, REDEPLOY at t about 200 s, the second deployment also died at wave 8 (2:53).

| t (s) | alive | PSS (MB) | fps avg | fps min | tick_ms | enemies |
|---|---|---|---|---|---|---|
| 1 | yes | 186.9 | 20.2 | 12 | 0.21 | 4 |
| 32 | yes | 193.2 | 28.1 | 17 | 0.20 | 3 |
| 62 | yes | 193.4 | 27.7 | 19 | 0.19 | 4 |
| 92 | yes | 193.4 | 29.3 | 19 | 0.19 | 6 |
| 123 | yes | 193.9 | 26.8 | 19 | 0.21 | 11 |
| 153 | yes | 194.8 | 34.2 | 27 | 0.20 | 10 |
| 184 | yes | 194.8 | 20.1 | 9 | 0.24 | 3 |
| 214 | yes (seed 2) | 194.8 | 13.6 | 9 | 0.29 | 5 |
| 245 | yes | 194.8 | 16.2 | 7 | 0.19 | 4 |
| 276 | yes | 194.8 | 18.0 | 15 | 0.18 | 5 |
| 306 | yes | 194.8 | 18.0 | 13 | 0.18 | 6 |

Load run (wave 60 and up, about 165 enemies; two samplers overlapped, so some rows are 1 s apart; one process, pid 3859, throughout):

| t (s) | alive | PSS (MB) | fps avg | fps min | tick_ms | enemies |
|---|---|---|---|---|---|---|
| 1 (before LOAD) | yes | 186.7 | 21.1 | 2 | 0.21 | 3 |
| 21 | yes | 186.5 | 33.7 | 26 | 0.73 | 163 |
| 42 | yes | 186.6 | 32.7 | 31 | 0.80 | 164 |
| 63 | yes | 186.6 | 31.5 | 17 | 1.27 | 165 |
| 83 | yes | 186.6 | 33.1 | 25 | 1.21 | 165 |
| 104 | yes | 186.8 | 34.1 | 29 | 1.18 | 165 |
| 124 | yes | 186.8 | 34.5 | 32 | 1.30 | 165 |
| 144 | yes | 186.8 | 32.7 | 27 | 1.15 | 165 |
| 165 | yes | 186.8 | 28.4 | 16 | 1.23 | 165 |
| 185 | yes | 186.6 | 33.1 | 25 | 1.21 | 165 |
| 206 | yes | 186.8 | 34.1 | 29 | 1.18 | 165 |
| 226 | yes | 186.8 | 34.5 | 32 | 1.30 | 165 |
| 247 | yes | 187.1 | 33.1 | 25 | 1.22 | 165 |

All 22 `[PERF]` windows inside the supervised soak (enemies at least 160, 10 s each): fps average 31.9 (lowest window 27.4, highest 34.5), lowest 1 s dip 12 fps, tick_ms average 1.17 (max 1.39). Windows after the supervised soak (22:16:50 on) dropped to 22.4-29 fps while the host was running `perf_bench` in parallel, so they are not counted.

## Verdicts

- **Stability: PASS for the app, FLAG for the emulator.** Load soak 181 s supervised plus about 4 min 50 s of `[PERF]` windows, same pid, no `FATAL EXCEPTION`, error-level `AndroidRuntime`, `SCRIPT ERROR`, ANR or `Force quitting` (9421 lines scanned by the script, 12,556 in the final dump: 0 matches). Normal run: 0 matches. The first load attempt ended when the **emulator itself hung** (`qemu-system-x86_64.exe` AppHang, Windows event 22:08:03, process killed by Windows) after about 100 s at 165 enemies on wave 68; nothing in the app log before that. Cold boot fixed it and the repeat run was clean. After a cold boot the first launch also lost its process once (`relaunching` activity, process died 22:10:48 with no crash trace; second launch fine). The user had an Intel graphics driver download open, so an old host GPU driver is the prime suspect for the qemu hang. Not reproduced.
- **Performance: FLAG (documented shortfall, marginal).** At about 165 enemies the emulator averages 31.9 fps with windows between 27.4 and 34.5 fps and dips to 12 fps (below the 30 fps target in 6 of 22 windows). In a normal run with 3-11 enemies it shows 14-34 fps with large swings, so the emulator (host GL translator, not the sim) is the limit: sim cost is 0.2 ms/tick normal and 1.2 ms/tick at wave 60. Drift: first quarter 32.0 fps vs last quarter 31.6 (no drift inside the soak). Headless cross-check (`tools\perf_bench.ps1 -Check`, 600 enemies + 603 bolts, idle host): avg 1.68-1.73 ms/tick, p95 2.1 ms, max 3.4 ms vs baseline 1.827 ms: **PERF OK** (an earlier run while the load emulator was still running measured 2.80 ms and failed; the host CPU was shared). Per TECH_ARCHITECTURE 2.7 the CPU numbers (about 30x under the 33 ms frame) say the sim is not the bottleneck; a real device is needed for a verdict on rendering. `smoke_android.ps1 -SkipDeploy -MinFps 30` over this log would report lowest window 27.4 fps and FAIL (as documented above).
- **Memory: PASS.** Normal: 186.9 MB first sample, 194.8 MB plateau from t = 153 s (+4.2%, flat afterwards). Load: 186.5 -> 187.1 MB over 4 min at 165 enemies (+0.3%).
- **State build-up: PASS (with an observation).** Enemies stay at 163-166 (alive caps 160 normal plus up to 8 for bosses; no value above 168). Debug overlay shows `THROTTLED no`, 1 tick per frame. `spawn_throttled` and the event-ring loss counter are not exposed in the overlay or `[PERF]` line: **NOT ASSESSED - NO DATA** for those two. Observation: in load mode Cinder (1 hp, invulnerable, no upgrades) kills nothing after wave 61 (scrap 738 and data 392 do not change between wave 61 and 69, enemy positions are identical), so the field is saturated by design of the scenario.
- **Visuals: PASS with notes** (see screenshots). Enemies are recognizable by shape and color but small at 1080 px width; no black screen after the first launch.
- **Fun fatigue: not assessed (user).**

## Screenshots (`docs/playtests/m1/`, all viewed)

| File | What it shows |
|---|---|
| `mid_wave.png` | Normal run, wave 6, hp 100/100 (teal bar), SCRAP 105 DATA 60. Cinder centered with amber ring/wedges (band 0, all 12 skin wedges), teal integrity ring, polar grid and three amber range rings; two red dart enemies far out (about 13 px) at upper left. HUD readable: WAVE 6, wave timer bar, `1x`, `PAUSE`, hp bar with numbers, SCRAP (cream) / DATA (blue). Lower 44 percent is the dark `UPGRADES: M2` placeholder. Beam not in frame (80 ms fade). |
| `band3_natural_wave7.png` | Normal run, wave 7, hp 25/100 (red bar, red integrity arc): natural band 3 with all skin gone, white-hot frame and cracked core outline; a skitter at Cinder, a magenta enemy bolt, red enemies around the ring. |
| `results_overlay.png` | `DEPLOYMENT ENDED` overlay: WAVE REACHED 8, TIME 02:50, KILLS 68, CAUSE SKITTER (red), DATA 82 (blue), SCRAP 139, REDEPLOY button (amber outline, y about 1517 on the 1080x2400 screen); battlefield dimmed behind. Layout clean, all text readable. REDEPLOY worked (log `run started seed=2`). |
| `boss_wave61_load.png` | Load mode (wave 60 fast-forward; screenshot at wave 61, about 165 enemies, hp 1/100): two large red hexagonal boss hulks (one on top of Cinder, one upper left), many red skitter/dart/lancer shapes on the outer ring, about 20 magenta enemy bolts. Frame is busy but Cinder, bosses, bolts and HUD stay distinguishable. |
| `load_160_enemies.png` | Load mode at wave 68 with the overlay hidden; same scene as above after 7 more waves (positions frozen: field saturated). |
| `band0.png` | Forced B0 (screenshot in load mode, wave 68): all 12 wedges intact skin, teal-gray frame ribs, glowing hex core, visor arc. |
| `band1.png` | Forced B1: three wedges dark charred (matches the spec indices 2, 7, 10), nine skin. |
| `band2.png` | Forced B2 (wave 69): eight wedges gone (frame ribs visible between), four charred, white-cream frame brighter. |
| `band3.png` | Forced B3 (wave 69): all wedges gone, white-hot frame with a cracked core outline, matches the natural band 3 in `band3_natural_wave7.png`. |

Beam: no screenshot caught the hitscan beam clearly (80 ms fade vs screencap latency of several hundred ms); a short amber stroke is faintly visible next to Cinder in `band3_natural_wave7.png`. **Beam visibility is therefore not confirmed by a screenshot**; the user should check it live.

## Fixes made during this task

1. **Blocking bug: all sim data was zero on Android.** The first deploy showed `0 / 0` hp, wave 12 after 5 minutes, no enemies, Cinder a 1-px dot and no results overlay (`[PERF] enemies=0` for 5 minutes). Cause: the `src/data_defs/*.gd` classes use plain `var` fields (not `@export`), and the export converts `.tres` to binary `.res` by default, which stores only exported properties, so every def loaded with default 0 values. Fix: `project.godot` gets `[editor] export/convert_text_resources_to_binary=false` (text `.tres` are packed as is). Verified: after the fix hp 100/100, enemies spawn, death at wave 8. **(impl)** Alternative if preferred later: mark def fields `@export`.
2. Debug overlay line 4 used `%.3g`, which GDScript does not support: the overlay printed `G_HP %.3g SKITTER HP %.3g` and logged `String formatting error: unsupported format character` four times per second while shown. Changed to `%.3f` in `src/ui/debug_overlay.gd` (line 142). Included in the final deploy (not exercised after the fix).
3. `tools/smoke_android.ps1`: `-Soak <s>`, `-MinFps <n>`, `-PerfWarmup` added; crash pattern now includes `ANR in <package>`; the `-ExpectColor` failure is now reported after the fps check so both results print. See `docs/setup/smoke_test.md`.

## Follow-ups

- **F1 (M2):** `-ExpectColor #FFB000` matches only 9 of 4096 samples on the battle screen (needs 20): the HUD is mostly dim amber and small text. The default is only valid for the title screen of M0. Either lower the requirement per screen or sample the HUD strip. Not run to success in-battle; the soak-pass line is from the crash/pid/fps checks.
- **F2:** enemies are small (roughly 15-30 px per shape) on a 1080 px wide screen; check readability on a real phone.
- **F3:** expose `spawn_throttled` and event-ring loss in `[PERF]` or the overlay so state build-up can be assessed.
- **F4:** real-device fps check (emulator swings 14-34 fps even with few enemies; host GPU driver suspected).
- **F5:** `deploy_android.ps1` can hang the calling shell because the adb server it spawns inherits the output pipe; run it with output redirected to files (see gotchas).

## Questions for the user

1. Does the game feel fair? A fresh Cinder dies at wave 8 in about 2:50 both times (seed 1 and 2); is that the intended first-run length?
2. Can you see the laser beam while playing (it flashes 80 ms)? Is it readable against the grid?
3. Are the enemy shapes big and distinct enough to tell skitter, dart, lancer and walker apart at arm's length? Are bosses clear?
4. Is the skin burn progression (bands 1, 2, 3) noticeable during real play, or too subtle at this Cinder size?
5. Any stutter you notice at 1x that the numbers above hide? Does the emulator hang again for you?
