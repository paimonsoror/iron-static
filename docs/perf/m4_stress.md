# M4 late-game stress scene (M4-28)

Changelog: 2026-11-10 v1.0. First measurement of the M4 build (SimVersion 6, R1 Phase A merged, main `d4e7cb6` plus the debug-load mode fix below) against `docs/TECH_ARCHITECTURE.md` section 2.7. Earlier numbers: `docs/perf/render_baseline.md` (old look) and `docs/perf/v1_perf.md` (V1 look).

## What was run

- Device: AVD `tower_phone` (x86_64, 1080x2400, host GPU, `-no-audio`), cold boot 2 min before the first run, one emulator session for all rows. Host: other agents were rendering and testing at the same time, so every emulator number is a rough figure (see "How far to trust it").
- Build: debug APK of this worktree, export preset `IronStatic` with `command_line/extra_args="-- --debug-perf"` (restored to `""` afterwards, `git diff export_presets.cfg` is empty), tier HIGH, vsync on.
- Scene: the existing debug LOAD scenario (overlay double tap, `LOAD`): invulnerable run fast-forwarded to wave 60 with every draft settled by the first offer (the headless draft policy), then played live at 1x. About 163-165 enemies alive (skitters in the ring, several boss hulks near Cinder), tick cost about 1.1 ms. Sampling: the `[PERF]` line every 10 s via `adb logcat`, first 20 s after "load finished" dropped.
- Both modes: TIMED on a fresh profile, PURGE after crafting the profile (`tools/save_craft.gd lastmode purge`: TIMED best 20, PURGE unlocked and preselected). The load scenario used to ignore the mode and always run TIMED; `Game.start_debug_load` now starts the mode the player would get (`--mode` override, else the profile's last mode). The HUD showed "15 LEFT" in the PURGE run.
- Two variants per mode: **idle** (laser L0, nothing bought, Cinder deals non-lethal hits only) and **busy** (the scrap of the load bought into laser output and cycle rate by hold-to-buy: TIMED laser L24 MK III, PURGE laser L30 MK IV, tier plates, motes, beam tier and tier-up moment all live).
- Also: `tools\perf_bench.ps1 -Check` (desktop, emulator stopped).

## Results (emulator, HIGH, windows of 10 s)

| scene | windows | enemies | fps avg | worst window | worst 1 s | frame ms avg | p95 ms | sim tick ms | draws avg / max | objects | prims | tex MB | vid MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TIMED idle (wave 62) | 12 | 164 | 42.3 | 40.0 | 12 | 23.6 | 30.1 | 1.09 | 128 / 140 | 346 | 2,318 | 85.8 | 92.3 |
| TIMED busy (laser L24, wave 67-70) | 8 | 164 | 36.8 | 35.9 | 21 | 27.0 | 33.7 | 1.13 | 134 / 144 | 362 | 2,613 | 86.9 | 93.4 |
| TIMED battlefield only (`NOHUD`) | 5 | 165 | 45.2 | 39.4 | 32 | 22.2 | 28.3 | 1.17 | about 70 | 121 | 1,580 | 86.9 | 93.4 |
| PURGE idle (wave 60) | 10 | 163 | 39.6 | 38.6 | 29 | 25.3 | 31.8 | 1.14 | 149 / 160 | 394 | 2,590 | 84.8 | 91.3 |
| PURGE busy (laser L30, wave 62) | 8 | 163 | 40.6 | 38.7 | 21 | 24.6 | 30.2 | 1.08 | 147 / 157 | 393 | 2,257 | 85.1 | 91.6 |

Other readings: PSS 196 MB (TIMED idle) and 245 MB (PURGE busy), flat; render CPU time (`rcpu_ms`) 2.6-3.7 ms; checkpoint writes during the runs (`[SAVE] ok live`) took 10-96 ms; the log had no `ERROR`, `SCRIPT ERROR`, `FATAL` or ANR lines apart from the benign "Failed to load cached shader". Screenshots (540 px wide): `docs/playtests/m4/exit/stress_timed_wave62_idle.jpg`, `stress_timed_wave70_laser_mk3.jpg`, `stress_purge_wave60.jpg`, `stress_purge_wave62_laser_mk4.jpg`, and the Home mode picker `home_mode_picker_purge_selected.jpg`.

The PURGE rows have more draws mostly because that profile (TIMED best 20) has more upgrade rows unlocked and visible in the panel; the battlefield-only split was measured in TIMED only.

## Against TECH_ARCHITECTURE 2.7

| Budget | Target / hard limit | Measured | Verdict |
|---|---|---|---|
| Frame time at 1x, late game | 16.6 ms / 22 ms | 23.6-27.0 ms on the emulator (36.8-42.3 fps) | **Over the hard limit on the emulator**, which is not representative (Q40; the V1 phone run held 60 fps at 165 enemies, but that was before M4 and on the V1 look). Needs the real device (Q23). |
| Sim step | 1.5 ms at 200 enemies / 8 ms | 1.08-1.17 ms at 163-165 enemies; desktop `perf_bench -Check` 1.76 / 1.90 / 1.85 ms avg at 600 enemies and 603 bolts (limit 2.01 ms) | PASS |
| Render prep (CPU) | 3 ms / 5 ms | `rcpu_ms` 2.6-3.7 ms | PASS at the target edge |
| Draw calls (battlefield) | 25 / 40 | about 70 battlefield-only; 128-149 with HUD and panel | **FAIL**: V1 measured 74-77 total (about 35 battlefield estimated). M4 and R1 added about 50 draws. Not profiled which layer; candidates: tier plates and motes, damage numbers, afterglow, tier banner, FTUE and draft overlays (not open here), the taller panel. |
| Alive enemies | 100-200 | 163-165 | in range |
| Resident memory | 350 MB / 500 MB | 196-251 MB PSS | PASS |
| Texture memory (art bible 9) | art <= 48 MB | monitor 85-87 MB (V1: 58 MB); the monitor counts fonts, UI atlas and viewport buffers as well as art | flag, not split out |
| Cold start, APK size, battery | 3 s, 60 MB, 4% per 10 min | not measured here; AAB 56.2 MB at R1-08 (`docs/tasks/R1.md`) | open for the device |

Not exercised: **damage numbers** (the laser at L24-30 does not kill wave-60 enemies and a hit under 1% of the target's hull shows no number, so the layer was idle; the 24-number case is covered by `tests/unit/view/test_damage_number_layer.gd` for the pool and by `m4_27_emulator.md` step 5 on the phone-sized screen at low waves), **audio on a device** (the emulator runs `-no-audio`; the audio director ran against the dummy output), **patches as a stat effect** (the draft settles by the first offer during the fast-forward; the Intel panel was not opened), MID and LOW tiers (the V1 report already showed the emulator cannot rank tiers).

## QualityTier fallback

The ladder in TECH_ARCHITECTURE 2.7 stays the plan: `VisualQuality` presets HIGH / MID / LOW (`particle_cap`, scanlines, motes, glow sheets, sweep, impact rings, sparks per hit) never change the sim. Recommendation, unchanged from `v1_perf.md`: HIGH is the default on Pixel-class phones, MID is the fallback for unknown GPUs until the M6 auto-detect. No default was changed. The draw-call overshoot is a view-side problem (merge passes, one atlas for enemy sheets, fewer overlay nodes) and should be profiled on the real device before any tier change; it does not affect the sim or any save.

## How far to trust it

The emulator ran with other Godot and Gradle jobs on the host; the V1 reports showed 20-60% swings between runs from host load and qemu uptime. The same load changed the desktop `perf_bench` between 1.77 and 2.55 ms avg until the host went quiet: three `-Check` runs with the emulator stopped and no other Godot running gave 1.76, 1.90 and 1.85 ms (limit 2.01 ms), and the M3 tree (`12e4276`) measured 1.77-2.32 ms in the same noisy conditions, so no sim regression is indicated. Use the draw-call counts (stable) more than the fps figures.

## Repeat

1. Free memory 2.5 GB or more, no `java.exe`; export with the preset's `extra_args="-- --debug-perf"` (never commit it), install, cold boot the emulator.
2. NEW GAME, frame bay CONTINUE, tap the cold open, double tap the top-left corner, `LOAD` (781,365), double tap again to hide the overlay; wait for `[BENCH] load finished`, drop 20 s, read `[PERF]` lines. For PURGE: pull `files/save/profile.sav` with `run-as`, `godot --headless -s res://tools/save_craft.gd -- in.sav out.sav lastmode purge`, push it back, remove `profile.bak` and `run_snapshot.sav`, CONTINUE, DEPLOY, then the same overlay steps. Hold-to-buy: `input swipe x y x y 7000` on a cost button.
3. `tools\render_bench.ps1` cannot drive this build directly any more because the title screen comes first and has no overlay; the steps above replace its launch part.
