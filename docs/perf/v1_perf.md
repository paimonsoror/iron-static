# V1 render performance (V1-20)

Changelog: 2026-11-08 v1.0 (first measurement; partial, see "What is missing"). Compare with `docs/perf/render_baseline.md` (old look, emulator) and the art bible 9.2-9.4 budgets.

Builds measured: A) working tree at about 11:40 (commit 5e16c3c, V1-14, before the camera auto-fit) with `--debug-perf`; this is the build of every table below. B) a V1-26 candidate (`C:\dev\tower_v126`, cf895d8 plus the particle texelFetch files) was built and installed on the emulator and the phone, but its bench runs failed (emulator degraded, phone dropped off adb), so there are no [PERF] numbers for it.

## Devices

| Device | Details |
|---|---|
| Emulator `tower_phone` | 1080x2400, host GPU (Intel Iris Plus, GLES translator), qemu uptime stated per table |
| **Phone (the number that matters for FC6)** | Google Pixel 11 Pro Fold, Tensor G6, Android 17, arm64-v8a, GPU **PowerVR C-Series CXTP** through **ANGLE on Vulkan 1.4** (Godot prints `OpenGL ES 3.2 (ANGLE ... PowerVR ...)`), cover display 1080x2342 at 120 Hz (the game ran at **60 fps**, Godot's frame pacing / vsync, not the panel's 120). The inner display (2076x2152) was off during all runs: **the unfolded layout is untested**. Phone screencap needs `-d <display id>` (`dumpsys SurfaceFlinger --display-id`, the cover screen was ...801153). |

## Tables (HIGH, vsync on, windows of 10 s, warm-up 20 s, 8-10 windows, build A)

### Phone, HIGH (host idle, USB only)

| scenario | enemies | fps avg | worst window | worst 1 s | frame ms / p95 | draws | objects | prims | tex MB | vid MB | PSS MB first/last |
|---|---|---|---|---|---|---|---|---|---|---|---|
| hold165 | 162 | 60.0 | 59.9 | 59 | 16.7 / 17.0 | 76 | 255 | 1,106 | 58.1 | 64.6 | 405.8 / 406 |
| live165 (LOAD, tick 1.03 ms) | 165 | 60.0 | 59.9 | 59 | 16.7 / 17.0 | 77 | 257 | 1,820 | 58.1 | 64.6 | 408.7 / 408.7 |
| hold100 | 101 | 60.0 | 60.0 | 60 | 16.7 / 17.0 | 76 | 255 | 970 | 57.6 | 64.1 | 403.7 / 405.5 |

FC6 reading: **>= 55 fps at 100 enemies and >= 30 fps at 160 hold on the reference device: met on this phone for build A** (pegged at the 60 Hz pacing; headroom not measured because the cap is hit; run `--debug-novsync` / the VSYNC button to see the uncapped number). PSS 405 MB is high compared with the emulator's 208 MB (phone counts graphics memory; flat over the run: +0.3 %).

### Emulator, HIGH, 6-30 min after a cold boot (host mostly idle; a phone bench ran concurrently on the same adb)

| scenario | enemies | fps avg | worst window | worst 1 s | frame ms / p95 | draws | tex MB | vid MB | PSS MB |
|---|---|---|---|---|---|---|---|---|---|
| hold165 | 162 | 45.5 | 41.7 | 26 | 22.2 / 31.1 | 76 | 58.5 | 65.1 | 207.8 / 208 |
| live165 | 165 | 42.4 | 38.3 | 20 | 23.8 / 33.1 | 77 | 58.5 | 65.1 | 209.1 / 208.7 |
| hold100 | 101 | 36.1 | 30.9 | 6 | 28.5 / 46.4 | 76 | 58.7 | 65.2 | 207.6 / 207.6 |

Baseline (old look, `render_baseline.md`): hold165 27.7, live165 25.5, hold100 25.3 fps, 115 draws, tex 24.3 MB. So at HIGH the new look is **faster than the old procedural battlefield** on this emulator (about +60 % at 165 enemies), because the MultiMesh sprites replaced about 12k procedural primitives per frame and the draw total fell from 115 to 76. The acceptance "HIGH at 165 enemies >= 28.7 fps" is met (42-45 fps) **when the emulator is healthy**.

### Emulator, MID and LOW, second cold boot (22-40 min uptime, the host was busy with exports/builds of other agents)

| tier | scenario | fps avg | worst window | worst 1 s | frame ms / p95 | draws | prims |
|---|---|---|---|---|---|---|---|
| MID | hold165 | 26.5 | 15.2 | 3 | 39.4 / 66.8 | 75 | 1,058 |
| MID | live165 | 25.3 | 21.4 | 10 | 40.0 / 67.5 | 76 | 1,422 |
| MID | hold100 | 29.7 | 25.0 | 8 | 34.1 / 55.9 | 75 | 922 |
| LOW | hold165 | 25.3 | 22.4 | 6 | 40.2 / 66.6 | 74 | 1,044 |
| LOW | live165 | 26.5 | 20.2 | 4 | 37.8 / 65.9 | 75 | 1,198 |
| LOW | hold100 | 37.6 | 34.6 | 5 | 26.9 / 38.1 | 74 | 908 |

**These do not rank the tiers.** The first MID/LOW attempt at 73-100 min qemu uptime collapsed to 11 fps (and the LOW run failed to load): known qemu degradation. The second attempt, after a cold boot, still ran slower than HIGH did 30 min earlier (HIGH 42-45 fps vs MID/LOW 25-30), the opposite of what the tier switches (fewer particles, no scanlines, no glow sheets) should do. The host was loaded by Gradle exports of parallel agents. The emulator cannot rank tiers here; the tier cost is better judged on the phone (60 fps pegged on HIGH, nothing to gain) or a quiet host. Tier effect measured indirectly: prims 1,106 -> 1,044 and draws 76 -> 74 (HIGH -> LOW).

## Budgets and flags

| Item | Budget (art bible 9.2/9.4) | Measured | Verdict |
|---|---|---|---|
| Total draws (HUD + battlefield) | battlefield <= 25 (hard 40) | 74-77 total. Baseline UI was about 41 draws (old HUD) so the battlefield is **about 35** (estimate; the `-HideHud` split failed to run because `debug_overlay` / `main.gd` hide the HUD node and the bench wait for `[BENCH] load finished` timed out twice on the degraded emulator) | **Over the soft 25, under the hard 40.** Not verified by split. |
| tex_mb (monitor) | art <= 48 MB | **58.1-58.7 MB** (phone and emulator) | The monitor counts everything: fonts, UI atlas, viewport buffers and art. The art sheets alone (RGBA8, no mipmaps except fx) sum to about **25 MB** (floor 5.8, cinder 4.2 + glow 1.0, walker 2.4 + 0.6, boss 1.6 + 1.6, fx 2.8 with mips, lancer 0.8 + 0.2, dart 0.7 + 0.2, skitter 0.6 + 0.15, ui_kit 0.8, bolt 0.1, icons about 1.6): **the art budget (30 MB target, 48 hard) holds; the monitor reading of 58 is not a breach of the art budget**. The earlier "49.2 vs 48" was the same total reading, which keeps growing with each task (24.3 old look -> 49 -> 58). |
| PSS | <= 240 MB and flat (+-5 %) | emulator 207-209 MB flat; phone 406-409 MB flat | emulator OK; phone has no budget, flag for review (graphics memory counted on the Tensor) |
| sim tick | unchanged | live165 1.03 ms (phone), 1.46 ms (emulator) | OK |
| Sim untouched | `git diff --stat -- src/sim src/meta src/save data` empty | empty | OK |

## Recommendations (no code change was made for these)

1. **Battlefield draws 35 -> <= 25 (low risk, ordered by gain):** (a) merge the arena passes: arena floor + overlay are two full-rect `ColorRect` passes plus the motes (3 draws); with the V1-23 procedural floor they could be one shader; (b) draw the 5 enemy MultiMeshes in fewer draws only if the types share one sheet atlas (all five sheets have different sizes; atlas would also fix texture state changes); (c) the Cinder rig is 3 draws, the beam renderer 2, particles 2: nothing cheap there. Re-measure with the HUD hidden before changing anything: the 35 is an estimate.
2. **Texture memory:** drop `mipmaps` only on `fx_sheet` if the particles are never minified (saves 0.7 MB); remove the unused reserved/placeholder cells later; VRAM compression of the arena floor (5.8 MB) is the one big win (floor is a dark smooth gradient: ETC2 would give 1.4 MB) but the SVG importer is lossless-only: it needs the floor baked to a PNG source (V1-08 follow-up, visual risk of banding, so not done blind).
3. **Do not use the emulator to rank tiers** (see above). Use the phone, with `--debug-novsync`, to see headroom above 60 fps before choosing a default.
4. **Default quality tier recommendation:** keep **HIGH** as the default on devices of the Pixel 11 / Tensor class (held 60 fps at 165 enemies with all FX on, tier cost irrelevant), and ship **MID** as the fallback for unknown GPUs until the M6 auto-detect exists (no device data exists for a 2020 mid-range phone). No `VisualQuality` default change was made.

## What is missing (phone-only or re-run)

- [PERF] on the V1-26 build on the phone and the smoke test with the foldable fix (`tools/smoke_android.ps1` now captures per display id and keeps the valid PNG; it was not run on the phone).
- MID/LOW on the phone; battlefield-only and HUD-only draws (`-HideHud`, `-HideBattlefield`) on a healthy emulator or the phone.
- 180 s soak and boss wave 61 under load (spec scenarios 2 and 3) at the three tiers.
- Inner (unfolded) display layout and fps.
- `perf_bench.ps1 -Check` (needs the emulator stopped; the sim was not changed, so it should pass).

## Gotchas found

- The first launch after an emulator cold boot can show "System UI isn't responding": tap Wait, relaunch the app, give it 60 s (shader compile).
- The qemu emulator degrades after about an hour: fps fell from 42 to 11 at 85 min and the load scenario stopped finishing; cold boot before every measurement block and note the uptime.
- `render_bench.ps1` `-HideHud` / `-HideBattlefield` waits for `[BENCH] load finished`; on the degraded emulator it timed out (150 s). Use a cold-booted emulator and `-BootWait 60`.
- On the foldable, plain `adb exec-out screencap` prints a text warning before the PNG (corrupt file): pass `-d <id>`.
- A shared adb server restarts whenever a Godot export runs; a phone on USB can drop off for minutes (benches with `-Serial` then fail with "device not found").
- Phone `svc power stayon true` was set for the session (screen stays on while charging); it can be switched off in Developer options "Stay awake".
