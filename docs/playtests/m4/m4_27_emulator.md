# M4-27 Emulator verification: patches, Intel, numbers, haptics, FTUE, visual tiers (2026-11-09)

Device: AVD `tower_phone` (emulator-5554, 1080x2400, gesture nav, cold boot, `-no-snapshot-save`). Build: debug APK from worktree `C:\dev\tower_verify`
at `267c684` (0.5.0-beta.1 / 50001), `extra_args=""` (never changed for the installed APK). Fresh install (uninstall first). No audio device (`-no-audio`).
Screenshots: `docs/playtests/m4/m4_27/<name>.jpg` (540 px wide; full-size PNGs in `C:\dev\tower_verify\build\m4_27\png\`, `sel\` holds the chosen set).
Times are wall-clock from the first tap; the player was a script (adb taps), so timings are faster than a human 07 s3 run.

Deviations: (1) The perf APK (`--debug-perf`) could not be exported: the second Godot export hung in Gradle for 25+ minutes and then failed
(`Project export for preset "IronStatic" failed`). `export_presets.cfg` WAS edited to `-- --debug-perf` (both presets, lines 51 and 106) for that attempt and is RESTORED to `""` (verified).
So the soak ran `smoke_android.ps1 -SkipDeploy -WaitSeconds 10 -Soak 120` without `-MinFps`, and fps was measured with `dumpsys SurfaceFlinger --latency` instead of `[PERF]`.
(2) The first emulator start failed with the disk-space FATAL; retried after the main agent freed space (4.9 GB free). AVD snapshots were not touched.
(3) adb dropped ("daemon not running / device offline") 5 times during the session, so some taps in a batch were lost; screenshots were re-taken.

## Result table

| # | Step | Result | Evidence |
|---|---|---|---|
| 1 | FTUE fresh install (6 timestamps) | PASS with findings F1-F4 | below |
| 1a | 0:00 cold open: 3 amber lines, Cinder fades in, TAP TO SKIP | PASS | `c02_coldopen_b` (RELAY 06 ONLINE / HOSTILE SWARM DETECTED / HOLD THE RELAY, dark Cinder with amber glow, "TAP TO SKIP"). Tap skips it into run 1 |
| 1b | 0:40 pointer on `laser_output` ("UPGRADE") + SKIP HINTS | PASS | `r01_run1_pointer`: amber triangle on the LASER OUTPUT row, "UPGRADE" plate with SKIP HINTS. Row shows `MK I / NEXT LOOK AT L5` |
| 1c | scrap / cycle-rate hint | PASS (not separately captured) | after buying laser the UPGRADE pointer moved to CYCLE RATE (`r04_buy5_flash` pointer on the cycle row, scrap 3). The "scrap rising" line is the generic `hud.scrap` beat (silent) |
| 1d | 1:50 DART - FAST label (waves 5-8) | PASS | `ftue3_dart_label` (wave 6, "DART - FAST" plate + SKIP HINTS over the field, dart in play) |
| 1e | hull hint after first damage | NOT SEEN | Cinder was not damaged in run 1 until wave 11, after the hint window; `first_damage_taken` beat was never observed on screen (see F5) |
| 1f | 2:30 wave-10 draft with the explanation line | PASS | `ftue4_draft`: "PATCH DRAFT: WAVE 10", "PATCHES LAST THIS DEPLOYMENT", three cards. No gamble card in this offer (see 2) |
| 1g | 3:30 death -> Results with FOUNDRY pulse | PASS with F2 | `ftue5_results_foundry`: gold-ringed "FOUNDRY 4 AFFORDABLE" button, plate "FOUNDRY - UPGRADES STAY" + arrow |
| 1h | 4:15 Foundry guided pointer | PASS with F3 | `ftue6_foundry_pointer`: ring on LASER OUTPUT row (RECOMMENDED chip), "HOLD TO BUY SEVERAL" plate |
| 1i | run 2 note | PASS | `ftue7_run2_note`: "FOUNDRY LEVELS CARRY OVER" plate at run 2 start |
| 1j | SKIP HINTS / hints end after run 2 / CONTINUE never shows cold open | PASS | run 3 Results and run had no FTUE plates. After kill + relaunch, title shows CONTINUE (NEW GAME asks "START OVER?"), CONTINUE goes straight to the run, no cold open |
| 2 | Patch draft wave 10, TIMED | PASS | `ftue4_draft`, `draft2_second_offer`, `n02_after_pick`: pick of PLATING raised hull 150 -> 180 in Intel STATS (`n03_intel`: HULL INTEGRITY 180, LASER 15 = BASE 10 x1.5) |
| 2 | Patch draft, PURGE | PASS | `draft_purge_gamble`: GLASS CANNON gamble card has a dashed amber border, "GAMBLE" tag and both sides ("LASER OUTPUT x1.5" / "COST: HULL INTEGRITY x0.7"). Picked it: hull 100 -> 70 (`pg05_intel_wave` 70/70) |
| 2 | gamble card seen in TIMED | NOT SEEN | 4 TIMED drafts + 2 PURGE drafts; only 1 gamble card appeared (15% per slot by design, plausible) |
| 2 | back during a draft -> pause menu, resume -> draft | PASS | `k01_back_in_draft` (PAUSED over the dimmed draft), `k02_resume_to_draft` (draft intact) |
| 2 | kill app during a draft, CONTINUE restores it | PASS | `force-stop` at the draft; `[RESUME] tick=7200 hash=7c0af04d...` equals the last `[CHECKPOINT] tick=7200 hash=7c0af04d...`; CONTINUE shows "RUN RESTORED" over the draft (`m03_continue_draft`); RESUME returns to the draft, pick applied |
| 3 | Boss warning | PASS (edge chevron not captured) | chevron "v" next to the wave counter at waves 7, 8, 9 (`hull_l5_plates`, `p01`/`bw18`); `boss_warning_banner`: "WARNING / BOSS INCOMING" plate with hazard stripes as the wave-10 boss enters at the top edge. The edge chevron before the boss and the drone sound were not captured (no audio device; no log line) |
| 4 | Intel STATS / WAVE sub-tabs | PASS | `n03_intel` (CINDER STATS: laser, cycle rate, DPS, hull), `n04_intel_wave` (CURRENT WAVE, MODE, TIME LEFT, NEXT BOSS IN 9 WAVES, NEXT DRAFT). Values change between visits (hull 177 -> 175, time 20 s -> 12 s) |
| 4 | PURGE quota / backstop | PASS | `pg05_intel_wave`: "QUOTA 12 LEFT / BACKSTOP IN 50s", "MODE: PURGE" |
| 5 | Damage numbers | PARTIAL, see F6 | white normal numbers ("13", "15"), amber crit in brackets "[20]" (`cn2`), red Cinder damage ("44", "83") on Cinder (`p01_nano5`, `cn3`). Normal numbers are about 28 px tall at 1080 (small but legible); red Cinder numbers sit on the bright hit flash and are hard to read. Reduce-motion ON: a stack of Cinder numbers on top of each other was NOT confirmed (at most 2 red numbers visible at once in 12 shots; no overlap seen), so the suspected issue is neither confirmed nor ruled out |
| 6 | Haptics | NOT VERIFIABLE on emulator | no vibration/haptic log line exists and `dumpsys vibrator_manager` has no history. HAPTICS toggle: off persisted across force-stop (`se04`, `sp02_settings_persist`) |
| 7 | Colorblind / high contrast live + persist | PASS | DEUT: skitters become magenta/violet, low-integrity bar magenta, boss pink (`cb_deut_2`, `cn2`, `cn3`). TRIT + high contrast on Home and in battle: Cinder ring turns pale green, arena floor dimmed (`sp04_home`, `pg02`). Settings (haptics off, DEUT, reduce motion on) persisted across force-stop (`sp02_settings_persist`). PROT only selected, not deployed (not separately captured) |
| 8 | Visual tiers | PASS with F7-F9 | see below |
| 8a | LASER L5 -> banner + flash + row | PASS | `r04_buy5_flash`: banner "LASER MK II / BEAM OUTPUT TIER UP" (amber top/bottom lines, teal sub line) above Cinder; row chip "MK II" (amber fill) and teal "NEXT LOOK AT L12" (`r05_buy5_banner`). 3 s later the line was dim again (`b02`) |
| 8b | thicker MK II beam | PARTIAL | beam seen in `bw18` (thin amber line with white core at MK I there) vs. the MK II frames; a clean side-by-side was not captured because the beam is only visible for about 100 ms per cycle |
| 8c | hull L5 -> plates | PASS | `hull_l5_plates`, `y01` (4 gunmetal corner plates with amber trim around the ring), row "MK II" |
| 8d | nano L5 -> motes | PASS | `z30`: small teal motes drifting around Cinder, row "MK II" (motes are subtle, about 8 px) |
| 8e | plating L8 -> deflection sparks on hit | PASS | `plating_l8_sparks`: row "PLATED II"; teal-white spark at the hit point on the plate edge while skitters attack |
| 8f | resume must not replay a tier banner | PASS | `n01_resume_no_banner` / `m03_continue_draft`: after kill + CONTINUE at laser L5 the row shows "MK II" with no banner and no teal line |
| 9 | Pause, Results, mode picker, PURGE regression | PASS | `pa01_pause` (RESUME / ABORT MISSION / EXIT GAME, ABORT asks for confirmation), `rs01` + `cur` (image-first Results: killer card, stat tiles, kill strip, REDEPLOY/FOUNDRY/HOME, "FRAME UNLOCKED: STRIKER" chip after PURGE best 19). Mode picker with crafted TIMED best 20: PURGE unlocked and chip "PURGE MODE UNLOCKED" shown (`sp04_home`). PURGE run reached wave 19; "N LEFT" HUD, boss wave and draft all work |
| 10 | Soak | PASS, fps below baseline | `smoke_android.ps1 -SkipDeploy -WaitSeconds 10 -Soak 120 -Serial emulator-5554` (no `-MinFps`, see Deviations): `SMOKE OK`, "Log clean (107399 lines scanned)", app alive at t=36/71/106/143 s. Fps from `dumpsys SurfaceFlinger --latency` (127-frame windows, tiers on, DEUT/TRIT + high contrast + reduce motion on, PURGE, 2x speed): 37.2, 30.2, 31.8, 38.9, 34.8 fps; in battle after the draft 34.7 / 36.2 / 37.5 fps; worst frame gap 43-165 ms. Lower than the 42-50 fps baseline, but a stuck Gradle export and other agents' Godot processes were loading the host at the same time, and high contrast was on. Not a clean number: re-measure on a quiet host |
| 11 | 2x speed pair | PASS | HUD shows "1x" / "2x"; in the 2x PURGE run waves 3 -> 11 completed in about 80 s (screens `h02`, `pg03`). No separate 1x/2x timer pair was captured |

Log scan: no `SCRIPT ERROR`, `ERROR: Strings:`, `ERROR: ArtSlots:`, `ERROR: Haptics:`, `ERROR: Palette:`, `FATAL`, `ANR`. Only the benign "Failed to load cached shader, recompiling".

## Findings

1. **F1 LOW - FTUE plate covers the row it points at.** The UPGRADE plate sits on top of the laser row's name and level, so the row the player is told to use is half hidden (`r03_after_buy4`).
2. **F2 MEDIUM - Results FTUE plate hides content.** "FOUNDRY - UPGRADES STAY" plate and its arrow cover the kill strip counts (the "x75 / x11" text) and the REDEPLOY label (`ftue5_results_foundry`). The pointer targets FOUNDRY but the plate is drawn above REDEPLOY.
3. **F3 LOW/MEDIUM - Foundry hint plate covers the CYCLE RATE row and part of HULL**, the pointer arrow is drawn under the laser row pointing up (`ftue6_foundry_pointer`). Also in the Foundry rows: the page-dot indicator overlaps the first row; "AFFORDABLE" is cut by the RECOMMENDED chip; "NEXT MILESTONE F10 x1.x" is cut at the right edge.
4. **F4 LOW - FTUE hint timing.** Hints expire after 12 s; the `first_damage_taken` hull hint (1e) never appeared in run 1 because Cinder took no damage before wave 11 with an upgrade-heavy script. Needs a human run to judge.
5. **F5 LOW - draft wave label.** The draft says "WAVE 10" while the HUD already shows WAVE 11 (and, in TIMED, the wave-10 boss is still alive behind it). The draft opens with enemies on the field and the boss on screen.
6. **F6 LOW - damage number legibility.** Red Cinder damage numbers are small and low-contrast against the bright hit flash (`cn3`); normal enemy numbers are about 13 sp. The reduce-motion stacking suspicion could not be reproduced in 12 samples (not conclusive).
7. **F7 LOW - hint "Next unlock at wave 3"** stays on the Arms/Chassis rows' footer at waves 4-11 (`s01`, `ch01`, `p01`): the line is stale after wave 3 is passed.
8. **F8 LOW - banner placement.** The tier-up banner is drawn at y about 620-770 (above Cinder) while the spec says "top of the battle field, below the HUD bar"; it can collide with the wave banner (`r05_buy5_banner` shows the wave banner instead of the tier-up banner when both fire; the MK II banner was captured only in `r04`).
9. **F9 INFO - MK II beam hard to verify.** The beam is visible only for a few frames; a still of MK I vs MK II needs a debug hold. Motes (MK II) are subtle.
10. **F10 LOW - Settings.** "SCIENTIFIC" is truncated to "SCIENTIFI"; vertical swipe scrolling in Settings does not work with `adb input swipe` (needs `input draganddrop`), same as the M3 carried item (real-finger check still pending).
11. **F11 INFO - Home Cinder has no plates** at hull L5 (Home is a profile view, not a run), consistent with the spec; Foundry hull levels do not draw plates.
12. **F12 LOW - tooling.** `run_emulator.ps1` prints "Starting tower_phone ..." and then waits silently when the emulator dies on the disk-space check; the FATAL line is only visible with `-RedirectStandardOutput`. adb dropped 5 times mid-session; second Godot export hung in Gradle (25+ min) and failed.
13. **F13 INFO - mode unlock chip works now.** With a crafted TIMED best 20 the PURGE chip appeared on first Home visit (M4-12 finding 1 not reproduced; the profile was reloaded once).

## Not verifiable on the emulator
- Haptics feel, and haptic log lines (none exist); boss warning drone and `sfx_tier_up` (no audio device; no audio log).
- Real-finger scroll on Settings (F10); real-phone fps.
- The boss edge chevron before the boss, PROT palette on battle, MK II beam side-by-side.

## Reproduction notes
- Title (CONTINUE layout): CONTINUE (540,1890), NEW GAME (540,2080), SETTINGS (540,2270); fresh title: NEW GAME (540,2080) then Frame Bay CONTINUE (540,2135), cold open: tap anywhere.
- Battle with FTUE plate: rows at y 2050/2240 (buy button x=885); hold-to-buy via `input swipe x y x y 3500`. Settings scroll: `input draganddrop 540 1425 540 300 1200`.
- Save craft: `adb exec-out run-as com.ironstatic.game cat files/save/profile.sav > in.sav`; `godot --headless --path C:\dev\tower_verify -s res://tools/save_craft.gd -- in.sav out.sav bestwave 20`; push with `MSYS_NO_PATHCONV=1 adb push out.sav /data/local/tmp/` then `run-as ... cp` + remove `profile.bak` and `run_snapshot.sav`.
