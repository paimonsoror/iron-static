# V1-01 Style frame report (spec items 4-7)

Scene: `src/debug/style_frame.tscn` (launch arg `--style-frame`, debug builds; `--debug-perf` adds `[PERF]` lines). Captured on `tower_phone` (1080x2400, GL Compatibility, host GPU) with the real 1080x2400 layout, camera 32 m, visual scale 1.5, stand-off 72 px.

## Most representative screenshots (all in `docs/playtests/v1/`)

1. `C:\dev\tower\docs\playtests\v1\V1-01_full_40.png` - full screen, 40 enemies, 2 bosses, 12 bolts, 3 beams, HUD mock.
2. `C:\dev\tower\docs\playtests\v1\V1-01_full_165.png` - dense, 165 enemies ring formation (`V1-01_full_165_clump.png` = clumped).
3. `C:\dev\tower\docs\playtests\v1\V1-01_cinder_b3.png` (and `V1-01_cinder_b0.png`) - Cinder rig at 1x, band 3 vs band 0.
4. `C:\dev\tower\docs\playtests\v1\V1-01_enemies_closeup.png` - 2x crop: skitters, darts, walker, lancers.
5. `C:\dev\tower\docs\playtests\v1\V1-01_boss.png` - boss hulk 2x.
6. `C:\dev\tower\docs\playtests\v1\V1-01_old_vs_new.png` - left half new look, right half old procedural look (`V1-01_old_only.png` = full old look).
7. Also: `V1-01_hud.png` (same frame as full_40), `V1-01_cam38_vs_cam32.png` (top 32 m, bottom 38 m), `V1-01_glow_ab.png` (glow on | glow sheets off | environment glow on, 680x520 crops).

## Checklist for the user (yes / no)

1. Is Cinder readable and distinct (plated skin, emitter ring, shoulder lens, core)?
2. Are the four regular enemies plus boss distinguishable at density (`full_165`)? (The "five types" of the task text are skitter, dart, walker, lancer, boss_hulk.)
3. Does it feel bigger and fuller than the M2 screenshots?
4. Are the HUD plates the right sci-fi tone?
5. Is the plated skin acceptable (Q42)?
6. Camera 32 vs 38 (Q41): which one?
7. Scanline intensity (Q44): 0.06 default, toggle `SCAN` (0 = off).
8. Icon style (Q45): bold flat glyphs on a chamfered plate (as drawn) vs thin outline.

## Acceptance (V1-01 items 1-9)

| # | Result | Evidence |
|---|---|---|
| 1 `svg_support.md` >= 10 features | not re-checked by this agent (art/probe agent's deliverable) | file exists in `docs/art/` |
| 2 files exist + allowlist | PARTIAL | all my files exist; allowlist script not run by me (V1-02 lint owns it) |
| 3 imported texture sizes | PASS (sizes) | one-off script `build/tex_check.gd`: cinder 1024x1024, cinder_glow 512x512, skitter 768x192, dart 1024x160, walker 1536x384, lancer 864x224, boss 640x640, bolt 256x64, plus all glow sheets at half size, fx_sheet 1024x512, ui_kit 512x384, arena_floor 1080x1344: all PASS. "Alpha outside cells = 0" was not checked by me |
| 4 launches on tower_phone, smoke passes, screenshots | PASS | `smoke_android.ps1 -SkipDeploy -Soak 30 -MinFps 20` printed `SMOKE OK` (37 PERF samples, lowest avg 53.6 fps); 10 required screenshots exist (non-blank, viewed) |
| 5 signature features visible | PASS (agent review) | closeup + crowd: skitter splayed legs, dart magenta thruster wake + swept wings, walker pistons/hazard stripe on front plate, lancer long barrel + magenta lens, boss reactor and clamp arms |
| 6 on-screen sizes within 10% | PASS with caveat | measured on an isolated-sprite desktop capture of the same scene (`sf_measure.png`, script `build/measure.ps1`, 1080x2400, black background, glow off): Cinder emitter ring outer diameter 210 px (expected 209; frame disc 200 by construction), skitter extent across legs 86 px (expected 1.35 x 64 = 86), dart length 93 px (expected 90 incl. thrusters), lancer 124 px bbox rotated (barrel to 58 -> 116 expected, glow adds), boss incl. arms 404 px tall (arms 300 texels x 2/3 x 2 = 400), boss hull 296 px by art spec. Caveat: enemies rotate toward Cinder, so bbox is not the plain body width; walker bbox (235x266 rotated, with legs) was not decomposed to a 140 px body width; sprite scale 0.5 px/texel (0.667 boss) is the same code path for all, verified by the others |
| 7 fps at 40/100/165 | PASS | table below; 165 enemies >= 25 fps |
| 8 `git diff --stat -- src/sim src/meta src/save data` empty | PASS | empty. `tools\test.ps1`: 351 tests, 0 failures. `tools\lint.ps1`: gdformat and gdlint PASS, repo rules PASS; the compile step FAILS only on files not mine (`src/core/data_text_tables.gd` / `data_importer.gd` parse error "Casting Variant to PackedStringArray is unsafe", in-progress change by another agent; my scripts compile) |
| 9 gate line | PASS | last line of this report |

## Measurements

fps on `tower_phone` (mean of 4 consecutive 10 s `[PERF]` windows, Godot reports fps = 1/frame time averaged; the emulator tops out at ~60):

| Config | fps |
|---|---|
| 40 enemies, glow on | 58.5 (59.5 on a second run) |
| 100 enemies | 58.8 |
| 165 enemies, ring | 57.7 |
| 165 enemies, clumped | 58.2 |
| 165 enemies clumped, glow sheets off | 57.5 (first window 52.5 right after the toggle) |
| 40 enemies, glow sheets off | 59.0 |
| 40 enemies, **environment glow A/B on** | **43.0** (-26% vs 58.5-59.5) |

Notes: an earlier, noisier pass (first minute after boot, taps overlapping a capture run) read 28-45 fps at 40, 18-21 at 100/165; these were not reproduced on repeat runs and are attributed to shader warm-up and concurrent adb input. The emulator is vsync-capped, so density did not move fps in this scene (all draws are 4 enemy MultiMeshes + 2 boss sprites + 1 bolt MultiMesh); real-device cost is unmeasured. Walker/boss overdraw at 165 is the first suspect if a device ever drops.

**Environment glow cost: about 26% fps (58.5 -> 43).** That fails the art bible section 10 adoption criterion (a) (< 10%), so environment glow stays off by default. The look gain is small (a faint bloom around Cinder core, beams and flash discs: see the third panel of `V1-01_glow_ab.png`). Settings used: Canvas background, glow threshold 0.7, intensity 0.9, bloom 0.1, `background_canvas_max_layer = 0` with the HUD on CanvasLayer 1.

## Rules / limitations (what I could not meet or chose)

- **(impl)** Cinder assembly follows `build/svg/cinder/assembled_onscreen_b0_b3.svg` (shadow 0.575 scale at +8,+12; shoulder at -125,-22). The integrity tick strip has no reference placement: drawn as a small gauge 122 px under Cinder (probably not its intended place).
- **(impl)** B1/B2 use `CinderWedges` states with seam/ember glows and crack from band 2; not tuned.
- **(impl)** Arena shader ColorRect sits above sprites (scanlines/vignette dim sprites too; the grid ring overlays enemies faintly). The floor's seam ring and the shader's 10 m grid ring double up as expected. At camera 38 the floor art stays at 1.0 scale (only the shader grid and sprites rescale).
- **(impl)** Camera 38 = same formation in meters, whole world group scaled 28.4/33.75 (sprites, stand-off, beams); more empty arena at the edges.
- **(impl)** Old look side-by-side: split at x=540 (left new, right old, old at 28.4 px/m with radii 0.6/0.5/1.4/0.7/3.0 m, no stand-off, no boss/bolt/beam FX).
- Formation: 40 = 22 skitter / 8 dart / 3 walker / 6 lancer approx (types 55/20/7/15 %), 12 contact skitters at the 72 px stand-off max, positions seeded and relaxed so crowds overlap by 20-40%; the density-165 frame is deliberately overlapped.
- Hit flash: first 3 instances of each type flash every 0.9 s (90 ms); bosses flash together (shared material).
- Muzzle/impact use `flare_star_4`, `halo_soft`, `flash_disc`, `ring_thin`, `spark_a/b/c`; beams are stacked additive lines (no `beam_strip`), so glow edge is stepped, not smooth.
- Debug button rows sit in the empty bottom of the panel mock; they were hidden for all screenshots (HIDE button; `.` at bottom right shows them again).
- `export_presets.cfg` `command_line/extra_args` was set to `-- --style-frame --debug-perf` for the capture build and restored to `""` afterwards; a normal build was redeployed and the emulator is on the regular game (`run started seed=1`).

## Issues in the art (for a later polish pass)

- Heavy red glow haze on enemies at 165 density reads as one red mass; dart/skitter silhouettes separate only by their outlines (consider lowering `glow_strength` above 100 enemies).
- Skitter legs are detached thin strokes at 0.5 px/texel; lines are ~2 px and shimmer on motion.
- Cinder frame_hot + halo_core on band 0 wash the wedge plates peach (core halo at 0.7 reads strong); B3 reads well.
- Heading weight of `Oxanium-Variable` needed an explicit `wght` variation (default instance is light): `ThemeBuilder` already does this; the mock used the same.
- Environment glow barely changes the image, see above.

## Suggested changes

1. Keep baked additive glow; drop environment glow (26% cost).
2. Fade enemy glow to ~0.6 above 100 enemies and drop grid (already `grid_fade`) to keep readability.
3. Cap walkers in dense waves visually (or draw them under skitters) so contact skitters stay readable.
4. Decide on a real placement for the integrity ticks (ring arc?) before V1-04.
5. Replace the stepped beam glow with a `beam_strip` texture in V1 production.

V1-GATE: waiting for user approval; no art production task (V1-04 to V1-08) may start.
