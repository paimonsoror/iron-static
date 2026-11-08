# Render baseline of the old look (V1-03)

Changelog: 2026-11-08 v1.0. Measured on AVD `tower_phone` (1080x2400, host GPU, GL Compatibility), debug APK, `--debug-perf`.
Reference for V1-20. Raw data: `build\render_bench\<stamp>\{windows.csv,summary.md,log_*.txt}` (not committed).

## What "old look" means here

Views of commit `b9a98aa` (V1-01 style frame commit, before V1-09's visual scale): camera 38 m, scale 1.0, procedural `ShapeMeshes`/`CinderView`/`ArenaBackground` draw code. Because V1-09 was landing in the working tree, the APK was built from a copy of the project (`C:\dev\tower_base`) with `src/view/*` and `src/ui/palette.gd` taken from `b9a98aa`. The HUD and upgrade panel are the **M2 ones** (the M1 baseline of 31.9 fps predates them). The sim is unchanged.

## Procedure (repeatable)

1. Cold boot: `adb emu kill`, `tools\run_emulator.ps1 -ColdBoot`, wait for boot.
2. Set export preset `command_line/extra_args="-- --debug-perf"`, deploy (`deploy_android.ps1` via `Start-Process`, poll for `== RUNNING`), restore `""`.
3. `powershell -NoProfile -File tools\render_bench.ps1 -Scenarios hold40,hold100,hold165,live165 -Seconds 180 -Warmup 20`
   Per scenario the script force-stops and relaunches the app, double-taps the overlay corner, taps the scenario button, hides the overlay, waits for the `[BENCH] load finished` log line, drops 20 s of warm-up and collects 10 s `[PERF]` windows (about 19) plus PSS every 10 s. Output: table + CSV. Options: `-Tier`, `-NoVsync`, `-HideBattlefield`, `-HideHud` (cost split).
4. Scenarios: `live165` = the M1 LOAD button (wave 60, sim running). `hold40/100/165` = load wave 14/19/30 then **sim paused** (static crowd of 45/101/162 enemies; render cost only, constant density; live density below saturation drifts every wave). Cinder kills nothing in either, so beams/particles are idle (same as M1).
5. Emulator state of the baseline run: cold boot 14 min earlier (android uptime 851 s, qemu age 14 min), fresh app launch per scenario, vsync on, tier HIGH, host otherwise idle (no `perf_bench`).

## Baseline table (HIGH, vsync on, 19 windows of 10 s each, 18 for hold165)

| scenario | enemies | fps avg | worst window | worst 1 s | frame ms avg | p95 frame ms | tick ms | draws | objects | prims | tex MB | vid MB | PSS MB first/last |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| hold40 | 45 | 24.6 | 21.9 | 13 | 41.2 | 58.5 | 0 (paused) | 115 | 501 | 15,035 | 24.3 | 31.2 | 203.7 / 203.9 |
| hold100 | 101 | 25.3 | 21.2 | 14 | 39.9 | 56.4 | 0 (paused) | 115 | 501 | 16,219 | 24.3 | 31.2 | 202.9 / 203.2 |
| hold165 | 162 | 27.7 | 23.8 | 16 | 36.7 | 51.4 | 0 (paused) | 115 | 501 | 17,491 | 24.3 | 31.2 | 202.4 / 202.6 |
| live165 (LOAD) | 165 | 25.5 | 21.4 | 12 | 40.0 | 58.9 | 1.39 | 116 | 502 | 17,511 | 24.3 | 31.2 | 202.8 / 203.1 |

Per-window rows of live165 (19 windows): `docs/playtests/v1/baseline_old_look.md`.

Cost split at 162 enemies (hold165, other run, 10 windows each): HUD+panel only (battlefield hidden) **54.9 fps**, 41 draws, 5.1k prims, 18.4 ms/frame. Battlefield only (HUD hidden) **29.6 fps**, 75 draws, 12.4k prims, 34.3 ms/frame. Both: 115 draws, 17.5k prims, 25-28 fps (frame times do not add exactly: 18+34 = 52 ms vs 37-40 ms measured, the GL pipeline overlaps).
Battlefield only at 45 enemies (hold40, HUD hidden): 33.6 fps, 75 draws, 9.9k prims (vs 29.6 fps at 162): enemies cost about 4 fps, the rest is constant.
Light/idle reference: normal run, 3-4 enemies, 121 draws: 15-23 fps (first minutes after cold boot, shader warm-up included).
Vsync off (`-NoVsync`, 90 s): hold165 26.7 fps, hold40 26.1 fps: **no change, vsync is not the cap here**.
Tier LOW on the old look (no consumer yet): no effect expected; one run read 21.3 fps at 36 min uptime, i.e. noise/uptime drift, not a tier effect.

Findings for V1-20:
- **Draw calls: the Performance monitor counts the whole frame.** The old look is 115 total = about 75 battlefield + about 41 UI (the budget of 25 refers to the battlefield; V1-20 must use the `-HideHud` split or subtract the UI figure of about 41).
- fps hardly depends on enemy count (24.6 to 27.7 from 45 to 162 enemies; the difference is within window noise of +-3 fps). The frame is dominated by a constant: the M2 HUD/panel (about 18 ms) and the constant part of the procedural battlefield (Cinder `_draw`, grid and rings: about 12k primitives, 75 draws, about 34 ms alone).
- `vid_mb` 31.2 and `tex_mb` 24.3 are flat (no leak); PSS 203 MB, flat (+0.3%). The 24.3 MB texture figure is mostly the font and UI atlases, not art sheets (V1-20 limit tex_mb <= 48 will include the new sheets).
- `rcpu_ms` (viewport CPU render time, in `[PERF]`) about 6-7 ms; `rgpu_ms` is always 0 on Compatibility (no GPU timestamps): GPU cost is not measurable directly, only by differences (hide layers, toggles). `proc_ms` (`TIME_PROCESS`) is larger than the frame time (about 57 ms vs 39) and is not additive; use it only to compare builds.

## The M1 (31.9 fps) versus style frame (58 fps) discrepancy

They measured different workloads, and neither number was a like-for-like of the shipping scene:
1. **Style frame (58 fps)**: no sim, no real HUD (a static mock of a few plates), 4 enemy MultiMeshes + bolts + 2 sprites, about 20 draws. 58 fps is the emulator's 60 Hz cap; the scene is light enough to hit it, so density showed no effect (it said so). Headroom was never measured because the frame was capped. This build (vsync on or off) never reaches the cap with the real scene, so the cap is irrelevant to the real game.
2. **M1 (31.9 fps)**: the real game, but with the M1 **placeholder** bottom panel (a label). The cost then was the old procedural battlefield alone (75 draws, about 12k primitives rebuilt each frame in `_draw`, about 34 ms, i.e. about 29.6 fps: matches M1's 31.9 within the swings and emulator drift).
3. **Now (about 25.5 fps)** = M1 battlefield + the M2 HUD and 4-tab upgrade panel with rows (41 draws, 5k prims, about 18 ms). This matches `docs/playtests/m2_emulator.md` (24-31 fps at 4-7 enemies, attributed there to qemu; it was the panel, with qemu degradation as a separate effect: hours of uptime gave 1-2 fps).
4. **LOAD-mode sim cost** is small: live165 (tick 1.39 ms) vs hold165 (sim paused): 25.5 vs 27.7 fps, inside noise.
5. **qemu degradation** is real but separate (uptime of hours): all numbers here are from 14-40 min uptime after a cold boot; the LOW run at 36 min was about 15-20% slower than the 14 min runs.

Consequence: the style frame number says the new MultiMesh sprite renderer is cheap; the real scene's cost is the UI and the procedural battlefield. V1-20 must compare full-scene numbers (HUD on) against 25.5 fps, and the HIGH acceptance of "28.7 fps" (10% under M1's 31.9) was set against a placeholder-panel baseline: **the honest baseline for the shipping UI is about 25.5 fps (hold/live165) on this emulator**, so the V1-20 target should be taken relative to this document (>= 23 fps at 10% under) unless the HUD gets cheaper (V1-16/17/18 plates may change the 41 UI draws, re-measure with `-HideBattlefield`).

## Instrumentation

`[PERF]` line keeps `fps= min= tick_ms= enemies= thr= lost=` and appends: `draws objects tex_mb vid_mb tier prims draws_max buf_mb frame_ms p95_ms max_ms proc_ms rcpu_ms rgpu_ms`. Source: `Performance` monitors `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, `RENDER_TEXTURE_MEM_USED`, `RENDER_VIDEO_MEM_USED`, `RENDER_BUFFER_MEM_USED`, `TIME_PROCESS` (all exist in 4.7.2 and are filled on Compatibility) plus `viewport_get_measured_render_time_cpu/gpu`. `smoke_android.ps1` parses the line unchanged (and now prints `draws`/`vid_mb` when present).

Debug overlay (double tap top-left): row 3 `HIGH MID LOW VSYNC`; row 4 `D40 D100 D165 RUN NOBF NOHUD`; `LOAD` as before. Args: `--debug-load-wave=<n>`, `--debug-hold`, `--debug-novsync`, `--quality=`, `--shake=`.

## Quality tiers (API)

`VisualQuality` (`src/view/visual_quality.gd`, Resource) fields: `tier` (enum `HIGH/MID/LOW`), `particle_cap` (400/200/80), `scanlines` (T/F/F), `motes` (T/F/F), `glow_sheets` (T/T/F), `sweep` (T/T/F), `range_pulse` (T/F/F), `vignette_pulse` (T/T/F), `impact_rings` (T/F/F), `sparks_per_hit` (6/6/2), `wedge_anim` (T/T/F), `shake_max_px` (10/5/5); `glow_strength(alive)` = density ramp 1.0 up to 40 alive, linear to 0.45 at 165 (0 when glow sheets are off). Presets `high() mid() low() for_tier(t)`, `parse_tier(text)` (unknown logs a warning, gives HIGH), `tier_from_args(args)`.
`VisualSettings` (`src/view/visual_settings.gd`, RefCounted): `quality`, `screen_shake` (`OFF/LOW/NORMAL`), `reduce_motion`, `scanline_intensity` (0.06), signal `quality_changed(tier)`, `set_tier(t)`, `effective_shake_px()`, `effective_scanlines()`, `VisualSettings.from_args(args)`. View code reads `Game.visual` (created by `Game._ready` from `--quality=` / `--shake=`) or, preferably, receives the object by injection; switch with `Game.visual.set_tier(VisualQuality.Tier.MID)` (debug overlay buttons do exactly this). Default HIGH; V1-20 decides whether MID becomes the default. No hook was added to `battle_view.gd` (V1-09's file): later view tasks wire `Game.visual` in.
