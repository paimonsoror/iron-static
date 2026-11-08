# M3-25 Title style frame report

Scope: art and debug scene only (no `src/ui` flow, sim, meta, save, data). VANGUARD silhouette only (BULWARK/STRIKER silhouettes were deferred by the main agent, so the three-frame silhouette criteria 6 and the `_bulwark/_striker` shots are not produced). No emulator or phone was available: all captures are desktop (OpenGL 3.3 Compatibility, Intel Iris Plus) and there is no on-device fps.

## What was built
- Art (assets/art/title/src, slot table `assets/art/title/title_slots.csv`, same schema as `assets/art/slots.csv`): `sky_glow`, `spires_far`, `hulks_mid`, `ridge_near` (with the perch plateau), `ridge_front`, `logo` (two cells, IRON gunmetal / STATIC amber, hand-built stencil letters as paths), `sil_vanguard` + `sil_vanguard_glow` (core halo, core, visor slit, 3 emitter lenses; additive).
- Shaders: `assets/shaders/title_smoke.gdshader` (3-octave fbm, premultiplied, one shader for dark and amber-lit smoke), `title_logo.gdshader` (diagonal light sweep, 0.15 s tear in two bands, R/B channel split, sparkles).
- Scene: `src/debug/title_frame.tscn` + `title_frame*.gd` (stage, logo, buttons, debug row, capture series). Run: `godot --path . res://src/debug/title_frame.tscn -- [--quality=low] [--reduce-motion] [--tf-hide]`; captures: `-- --tf-shots=<dir>`. The `--title-frame` boot arg in `Game`/`Main` is NOT wired (those files belong to others; M3-28 or main adds a 2-line hook like `--style-frame`).
- Buttons (CONTINUE amber-active, NEW GAME, SETTINGS): ui_kit plates, 640x160 px rows, one custom Control draws plates then labels (2 draws instead of 6).
- Layout: art stage 2160 wide, bottom anchored; portrait crops the centre, wide (1990x1920) shows more wasteland, UI column stays centred.

## Measurements (desktop, menu hidden, fade finished; `metrics.txt`)
| Tier | Draw calls | Smoke layers | Embers | Notes |
|---|---|---|---|---|
| HIGH (scanlines on) | 15 | 3 | yes | on target; +1 transient while a flare is on screen (16) |
| HIGH, scanlines off | 14 | 3 | yes | |
| MID | 13 | 2 | yes (fewer) | scanlines off per tier |
| LOW | 11 | 1 | none, no flare | |
| HIGH reduce motion | 14 | 3 (frozen) | none | |
| HIGH wide 1990x1920 | 15 | 3 | yes | |
Texture memory of the title sheets: 22.0 MB RGBA8 (under the 30 MB art budget, but the title screen should free it on leaving). Desktop fps is 59-60 (vsync-bound, not meaningful for the phone). Draw plan actual: 5 parallax + 3 smoke + 1 glow + 1 silhouette + 1 embers + 1 logo + 2 buttons + 1 scanline overlay = 15. Merge candidates if the phone is over budget: scanline/vignette overlay into the front smoke, silhouette+glow into one additive material.

## Acceptance
1. All files exist; every SVG passes `art_lint.py --slots title_slots.csv` (0 errors, 0 warnings). PASS.
2. `art_check.gd` with the title table: all 8 sheets spec size, no alpha outside cells (after a glow-margin fix). PASS. Emulator/smoke_android: NOT RUN (no emulator).
3. Captures exist and are non-blank (see list). On-device launch: not run.
4. LOW has exactly 1 smoke layer and no embers: test in `tests/unit/view/test_title_frame.gd`. Draw calls per tier above; fps on device not measured.
5. Reduce motion freezes drift, shimmer (logo uniforms zeroed), flare, embers, smoke offset: test covers drift, embers, flare.
6. Silhouette difference: not applicable (VANGUARD only).
7. No edits in src/sim, src/meta, src/save, data (this agent touched none). Note: while running, `src/sim/entities/enemy_store.gd` printed parse errors from another agent's in-progress work; they do not affect the title scene.

## Palette and IP self-check
Hex values come from the art-bible list (lint reports no off-palette warnings). Roles: amber = Cinder, logo STATIC and light; gunmetal = machines and IRON; the only red is a dim hostile vent (#7A1E30) on two dead hulks/nodes. No skull, no paired eyes (Cinder has one horizontal slit), no chrome, no franchise names or shapes; ids and file names are original. Logo letters are plain geometric stencil forms.

## Captures (docs/playtests/m3/)
`M3-25_title_high.png`, `_mid`, `_low`, `_reduce_motion`, `_wide` (1990x1920), `_flare`, `_glitch` (full frame during tear), `M3-25_logo_closeup.png` and `M3-25_logo_glitch.png` (2x crops). Not produced: `_bulwark`, `_striker`.

## Checklist for the user (yes/no)
1. Smoky, a wasteland of metal and machine? 2. Is the Cinder silhouette readable and does the pose fit? (BULWARK/STRIKER silhouettes still to be drawn.) 3. Logo shimmer too much or too little? 4. Embers and flare tone? 5. Does LOW still look like the same place? 6. Palette fits the HUD style? 7. Button placement one-handed (bottom third, 160 px rows)? 8. Anything that reads as a copy of a known franchise?

## Known gaps and suggestions
- Mid hulks are blocky silhouettes; production art should add leg detail and more varied wrecks. Cinder's raised left emitter reads a little like a fist.
- Stencil letter spacing is wide (the word spans 880 px); tighten if the logo should feel denser.
- Slot rows live in `title_slots.csv`, not `slots.csv`, to avoid breaking `ArtSlots`/`art_check` (they resolve files under `assets/art/src/`); M3-26 merges them.
- Flare also brightens the sky and near ridge via modulate above 1.0 (works on desktop Compatibility; verify on the phone).

M3-TITLE-GATE: waiting for user approval; no title production task (M3-26, M3-27, M3-28) may start.

## M3-TITLE-GATE decision (2026-11-08)
User: **APPROVED WITH FIXES** (go to production). Fixes required in M3-26: denser, more detailed wreckage (broken mechs, cables, gears, plating instead of blocky hulks), smoke reaching up into the empty top third of the sky, and a cleaner Cinder silhouette (the raised left arm must not read as a fist). Hero figure: the **selected frame** (VANGUARD, BULWARK or STRIKER) stands on the ridge, so the title needs a silhouette per frame.
