# M4 exit check (M4-28)

Date: 2026-11-10. Branch `m4-exit` on main `d4e7cb6` (R1 Phase A merged on top of M4, SimVersion 6). Task: `docs/tasks/M4.md` M4-28. Companion reports: `docs/perf/m4_stress.md` (stress scene), `docs/playtests/m4/modes_emulator.md` (M4-12), `docs/playtests/m4/m4_27_emulator.md` (M4-27).

**Verdict:** the M4 feature list is built and checked in code, tests and on the emulator. Three things are not closed and need a decision or a device: the late-game frame time and draw-call budget (emulator only, over the budget, see section 4), the user-owned gates (section 8) and the human playtest (section 9). Nothing was changed in gameplay or balance.

## 1. Checks run

| Check | Result |
|---|---|
| `tools\lint.ps1` | LINT OK (gdformat, gdlint, repo rules, art lint 48 files 0 errors, compile with warnings as errors on 565 scripts; 17 soft file-size warnings, all older) |
| `tools\test.ps1` by folder (each run on its own, 0 failures, 0 errors, 0 skipped) | `tests/sim` 74, `tests/unit/sim` 296, `core` 123, `data` 60, `meta` 124, `save` 51, `view` 303, `audio` 68, `ui` 471 = **1,570**; loose suites (`-Path res://tests/unit -Suite <name>`): `test_ads_stub` 1, `test_backend_offline` 1, `test_beta_services` 5, `test_billing_stub` 1, `test_nakama_client` 3, `test_smoke` 2 = **13**. Total 1,583 |
| `tools\perf_bench.ps1 -Check` | PASS in a quiet run: avg 1.76 / 1.90 / 1.85 ms against the 1.827 ms baseline (limit 2.010 ms). Under host load it read 2.0-2.5 ms and failed; the M3 tree (`12e4276`) read 1.77-2.32 ms in the same noisy hour, so the failures were load, not a sim change (details in `docs/perf/m4_stress.md`) |
| `tools\smoke_android.ps1` | not run in this task (the perf APK was a custom export with `--debug-perf`); the stress session log had no `ERROR`, `SCRIPT ERROR`, `FATAL` or ANR lines. M4-27 ran the smoke and a 120 s soak: `SMOKE OK` |
| CI | not pushed from here (local commits only); the coordinator watches Actions after the merge |
| Emulator stress scene | run in both modes, see `docs/perf/m4_stress.md` |

### balance_run, fresh profile, 100 waves, 20 runs, seed 1, greedy4, VANGUARD

TIMED (`.\tools\balance_run.ps1 -Profile fresh -Waves 100 -Runs 20 -Mode timed`):

```
BALANCE profile=fresh policy=greedy4 sector=1 waves=100 runs=20 seed=1 best_wave_s1=0
BALANCE death_wave p10=14 p50=15 p90=16
BALANCE death_wave_mean=15.10
BALANCE mean_game_minutes=5.88
BALANCE cause lancer 10 (50%)
BALANCE cause skitter 6 (30%)
BALANCE cause walker 4 (20%)
BALANCE curve wave=1 runs=20 avg_scrap=10.9 avg_data=5.67
BALANCE curve wave=5 runs=20 avg_scrap=21.1 avg_data=13.37
BALANCE curve wave=10 runs=20 avg_scrap=31.0 avg_data=16.12
BALANCE curve wave=15 runs=8 avg_scrap=42.1 avg_data=25.47
BALANCE target fresh median_death_wave measured=15.0 target=14.0 tol=30% dev=+7.1% PASS (gdd:03 s6 12 + 2 for the R1-04 drafts (R1-02 tune; draft first and random 14))
BALANCE optimizer vs random on fresh: greedy4 mean=15.10 random mean=16.05 diff=-0.95 waves (report only)
BALANCE RESULT PASS
TIMING wall=41.96s game=14528.5s speedup=346x
```

PURGE (`-Mode purge`):

```
BALANCE profile=fresh policy=greedy4 sector=1 waves=100 runs=20 seed=1 best_wave_s1=0 mode=purge
BALANCE death_wave p10=22 p50=24 p90=26
BALANCE death_wave_mean=24.25
BALANCE mean_game_minutes=13.94
BALANCE mode=purge mean_seconds_per_wave=34.5 (timed: 24.0)
BALANCE cause dart 1 (5%)
BALANCE cause skitter 9 (45%)
BALANCE cause walker 10 (50%)
BALANCE curve wave=1 runs=20 avg_scrap=12.0 avg_data=6.24
BALANCE curve wave=5 runs=20 avg_scrap=21.4 avg_data=13.62
BALANCE curve wave=10 runs=20 avg_scrap=38.3 avg_data=33.25
BALANCE curve wave=15 runs=20 avg_scrap=56.5 avg_data=35.84
BALANCE curve wave=20 runs=20 avg_scrap=66.1 avg_data=51.75
BALANCE curve wave=25 runs=5 avg_scrap=106.5 avg_data=52.40
BALANCE target mode=purge fresh median_death_wave measured=24.0 target=16.0 tol=30% dev=+50.0% WARN (impl)
BALANCE optimizer vs random on fresh: greedy4 mean=24.25 random mean=24.10 diff=+0.15 waves (report only)
BALANCE RESULT WARN
TIMING wall=104.31s game=33214.9s speedup=318x
```

The PURGE WARN is a knock-on of R1, not a regression: the PURGE target (16, `impl`, set in M4-10 before R1) was never retuned when R1-02 and R1-04 moved the TIMED median from 12 to 15 (target 14), and PURGE moved from 16 to 24. The review parked PURGE tuning (`docs/tasks/R1.md`, G-12 "PURGE rework: after Phase D"), so the target was left alone. A decision for the user: re-baseline the PURGE target or keep the WARN until the PURGE rework.

### Goldens (`tests/sim/test_replay.gd`; scripted run, seed 7, 3,000 ticks, invulnerable, no Foundry levels)

| SimVersion | Commit | TIMED config hash | TIMED final hash | PURGE config hash | PURGE final hash |
|---|---|---|---|---|---|
| 3 (wave modes, M4-04) | 30b5114 | `8291a16da68c01b972b84a201d9ac4fc8ce4c7e03f19b0552286942849a2c8ac` | `495093804bfad776c3b35ab4d884f8bc1b4442525f259aa547ab326e64ceeda0` (equals the SimVersion 2 value: TIMED play is unchanged) | `9dbd36a8e349c3613f859c35c4bcd5e7b9baff0988d482ae9ac5e783a5ed1ddb` | `636348079d070790fd9139a8c72177f6931c9a237afcf06d09e3bea16dcd75f5` |
| 4 (patches and the draft, M4-15) | ca66fda | `5e8c00f974d442707d6927bdd03404c8488aec3f03f2d4706b6b44f8ed1af2a4` | unchanged (3,000 ticks end before the first draft) | `ee2d9937d40876d9cba8bb896fa96eab6475cd22f91e53123258c51b5ccb544d` | unchanged; draft twin (16,000 ticks, offers picked at waves 10 and 20) `12c0f234f8ea439eb408fcc94ac52ed00f445a2a1629cc2d5fd17405d328e6f4` |
| **6 (current, R1 Phase A)** | d6e4360 | `abc18a6f6f856971d04ccabf1997e13b7587fb55f96af7d694cb133662eba206` | `02e20fab5092aaf19d663999927f1bf0539ac8d579b9b9bc2b65c31180bed7cf` (re-recorded by the R1-02 tune: starting scrap 230 changes the scripted buys) | `df977c2c15448ec80bb5d82f5616034953f8df3899fa2f5abf30a12ab5b5632b` | `102f49cbc84b5fa780d2f010b1daa750f27083c83c58ed4ba3ff2f2ecf96bf44`; draft twin (picks at waves 5, 10, 15, 20) `eebe12775509e6c11462620696fb6a15763b379389647d65e0a2e03f6b7e1a6d` |

SimVersion 5 (Foundry milestone x1.75, cbda50d) left every golden unchanged. The golden test (`test_golden_run_hash_prompts_a_sim_version_bump`) passed in the `tests/sim` run.

## 2. M4 exit criteria and evidence

| # | Criterion (ROADMAP M4 / M4.md) | Evidence | R1 change |
|---|---|---|---|
| 1 | Group 1: TIMED unchanged; PURGE ends a wave when its quota is dead or at the backstop; mode in run record, snapshot and replay hash-exact; per-mode best waves survive the schema migration; PURGE locked with its condition; balance_run reports both modes | `tests/unit/sim/test_purge_clock.gd` (`test_timed_scenario_hash_is_unchanged`, `test_cleared_wave_ends_at_once_and_next_wave_starts_next_tick`, `test_surviving_enemy_ends_wave_at_backstop_and_carries_over`, `test_purge_run_to_wave_15_is_identical_at_1_and_4_ticks_per_frame`); `tests/sim/test_replay.gd` (`test_purge_golden_run_hash`, `test_purge_record_round_trips_through_json_and_replays`, `test_record_without_mode_replays_as_timed`); `tests/sim/test_resume_hash_path.gd` (`test_purge_resume_follows_identical_hash_path`); `tests/unit/save/test_migrations.gd` (`test_real_v1_to_v2_copies_best_wave_to_timed`); `tests/unit/ui/test_mode_picker.gd` (`test_fresh_cards_timed_selected_purge_locked_and_dimmed`, `test_tapping_locked_segment_emits_nothing_and_shows_condition`); `tests/unit/meta/test_mode_rules.gd`; emulator: `docs/playtests/m4/modes_emulator.md`; balance_run both modes above | Unchanged in rules. SimVersion is 6; the PURGE target needs a re-baseline (section 1) |
| 2 | Wave-10 draft opens and each patch applies exactly per its table; the draft is deterministic and replayable | `tests/unit/sim/test_patch_effects.gd` (`test_overcharge`, `test_plating`, `test_rate`, `test_extraction`, `test_regen`, `test_ceramic`, `test_glass_applies_benefit_and_cost`, `test_greed`, `test_hardhide`, `test_two_patches_stack_after_run_levels_and_with_the_frame`); `tests/unit/sim/test_draft_system.gd` (`test_same_seed_same_offers_and_other_seeds_differ`, `test_a_run_with_two_picks_replays_to_its_final_hash`, `test_snapshot_taken_behind_an_open_draft_restores_it`); `tests/sim/test_draft_scenario.gd`; `test_draft_golden_run_hash_and_replay`; UI: `tests/unit/ui/test_draft_model.gd`, `test_draft_overlay.gd`; emulator `m4_27/ftue4_draft.jpg`, `draft_purge_gamble.jpg`, `k01_back_in_draft.jpg`, `m03_continue_draft.jpg` | **Changed by R1-04 and R1-02:** drafts end waves 5, 10, 15, 20, then every 10 to 50, then every 25; one ARMS, CHASSIS and SYSTEMS card per draft and one reroll; per-pick values are 0.6x of the M4 table (`patches.csv`); the "wave-10 draft" is now the second draft. The emulator captures above predate R1-04 (draft at wave 10). See `docs/tasks/R1.md` R1-04 and R1-02 |
| 3 | Boss at wave 10 spawns and can be killed | `tests/sim/test_full_run.gd` `test_boss_hulk_can_be_killed_at_wave_10`; warning: `tests/unit/sim/test_boss_warning.gd` (`test_warning_fires_45_ticks_before_the_boss_spawns`, `test_view_listener_does_not_change_the_state_hash`), `tests/unit/ui/test_hud_boss_warning.gd`; emulator `m4_27/boss_warning_banner.jpg` (edge chevron before the boss was not captured) | R1-05 hardened the frame as skin burns, boss stats unchanged |
| 4 | FTUE walkthrough on the emulator matches 07 s3 (screenshots at 6 timestamps) | `docs/playtests/m4/m4_27_emulator.md` step 1: 0:00 `c02_coldopen_b.jpg`, 0:40 `r01_run1_pointer.jpg`, 1:50 `ftue3_dart_label.jpg`, 2:30 `ftue4_draft.jpg`, 3:30 `ftue5_results_foundry.jpg`, 4:15 `ftue6_foundry_pointer.jpg`, plus `ftue7_run2_note.jpg`; all PASS, the hull-damage hint (1e) was not seen; plate placement findings F1-F3 fixed in 8adafdf (`m4_27/fixes_after.jpg`); unit: `tests/unit/ui/test_ftue_overlay.gd`, `test_ftue_placement.gd`, `test_cold_open.gd`, `tests/unit/meta/test_ftue_script.gd` | **Changed:** the 2:30 draft moved to wave 5 in run 1 (R1-04) and the hint wording and verbs changed (R1-07: "TAP: MORE DAMAGE", "TAP: FIRE FASTER", "TAP: SURVIVE LONGER"; the hull hint also fires in runs 2 and 3); starting scrap is 230 (R1-02). This task re-saw the R1 build only at the first hint (screenshot of run 1 with "TAP: MORE DAMAGE" taken during the stress session); the six-timestamp walkthrough was not repeated and is covered by the human fun checks (section 9) |
| 5 | Late-game stress scene holds the 2.7 budget or documents a QualityTier fallback | `docs/perf/m4_stress.md`: sim tick 1.1 ms (pass), memory 196-251 MB (pass), frame 23.6-27 ms and battlefield draws about 70 on the emulator (over the budget; the emulator is not representative), fallback documented | Not an R1 change; R1-06 (beam afterglow) and R1-07 added view cost not separately measured |
| 6 | Trademark search (Q31) and a real mid-range device (Q23) done by the user | **Not done**, user-owned (section 8) | |
| 7 | `tools\lint.ps1` and `tools\test.ps1` pass; CI green after every push | Section 1 (lint OK, 1,583 tests, 0 failures); CI: run by the coordinator after the merge | |

Also checked from the M4 scope list, outside the seven criteria: 2x speed is now 1x / 2x / 4x / 8x with a fall-back to 2x (R1-03; 4x unlocks at best TIMED wave 30, 8x at 60), `tests/sim/test_speed_invariance.gd` `test_r1_03_speeds_1_2_8_give_the_same_hash`, `test_purge_speeds_1_2_4_give_the_same_hash`, `tests/unit/meta/test_speed_rules.gd`. The Foundry hard cap of FO-3 became a soft cap in R1-02 (Q89: `max(6, floor(0.7 * best))`, flat x2 over it). Colorblind palettes, high contrast, haptics and settings rows: `tests/unit/view/test_palettes.gd`, `tests/unit/core/test_haptics.gd`, `tests/unit/ui/test_settings_screen.gd`; emulator `m4_27_emulator.md` steps 6-7 (haptic feel not verifiable on an emulator).

## 3. M4 task status (checked against code, tests and `git log`)

All 28 tasks are done in code. Status lines that were stale and are now ticked, with their evidence:

| Task | Was | Now | Evidence |
|---|---|---|---|
| M4-01 wave mode table, importer, strings | [ ] | [x] | 8abb106; `tests/unit/data/test_wave_mode_data.gd`; `data/wave_modes.csv`, `src/data_gen/wave_mode_*.tres` exist |
| M4-02 sim mode flag | [ ] | [x] | 83139a6; `tests/unit/core/test_sim_config_mode.gd`; `SimConfig.wave_mode` |
| M4-16 draft overlay and `vfx_draft_open` | [ ] | [x] | 99f83aa; `tests/unit/ui/test_draft_model.gd`, `test_draft_overlay.gd`; emulator captures in M4-27 |
| M4-24 colorblind palettes and high contrast | [ ] | [x] | 16d897c; `tests/unit/view/test_palettes.gd`, `test_palette.gd`; `docs/playtests/m4/palettes/m4-24_palettes.jpg` |
| M4-27 emulator verification | [ ] | [x] (with the partials the report lists) | 20310a7 (report), 8adafdf (findings F1-F8 fixed); not verifiable: haptic feel, `[PERF]` soak on the perf APK, the hull-damage hint, a clean MK I against MK II beam pair |
| M4-28 exit check | [ ] | [x] | this report |

Already ticked and confirmed against `git log` (commit): M4-03 5970d3c, M4-04 30b5114, M4-05 5a5b98e (+50f194b), M4-06 2dfbee0, M4-07 6d97188, M4-08 3a102f7, M4-09 18ab7f9, M4-10 3766b33, M4-11 fa8c78f, M4-12 39e768c, M4-13 9c4d440, M4-14 eed64d8, M4-15 ca66fda, M4-17 bc1e84f, M4-18 7683c5d, M4-19 5f6ab64, M4-20 1bbda27, M4-21 dc04abd, M4-22 40ae437, M4-23 7018496, M4-25 0a61b18, M4-26 6e8a4d2. Group 6 visual tiers: VT-1 ec230e8, VT-2 e7484b1, VT-3 32e6a49, VT-4 3d1c7e2, VT-5 cfd3f17, VT-6 604fcd1 are done; **VT-7 (pass and tuning) and VT-8 (second slice) are not done** (no commits, no report) and stay [ ]; they are not M4 exit blockers. Group 7: FO-1 fd267ba, FO-2 ee0553b, FO-3 cbda50d are done.

## 4. Stress scene (summary)

Emulator `tower_phone`, HIGH, wave 60+ with about 164 enemies. TIMED idle 42.3 fps (23.6 ms), TIMED busy (laser MK III) 36.8 fps (27.0 ms), PURGE idle 39.6 fps (25.3 ms), PURGE busy (laser MK IV) 40.6 fps (24.6 ms); sim tick 1.08-1.17 ms; draws 128-149 total and about 70 battlefield-only (budget 25, hard 40); PSS 196-251 MB. Damage numbers and real audio were not exercised (reasons in the perf report). Full table, the budget comparison and the QualityTier fallback: `docs/perf/m4_stress.md`. The numbers say the frame budget needs the real device (Q23) before M5 and that the draw-call count grew by about 50 since V1.

## 5. Open questions Q68-Q76 (wave modes)

All nine are already recorded in `docs/design/09_open_questions.md` as RESOLVED 2026-11-09, "user confirmed the default"; no answer was added or changed. Defaults as implemented: Q68 PURGE backstop 60 s; Q69 same rewards (`reward_mult` 1.0); Q70 offline earnings and the farm-rate average use TIMED runs only; Q71 only the TIMED best gates rows and frames; Q72 quota is every entry of the current wave, boss included; Q73 no lull in PURGE; Q74 draft waves identical in both modes; Q75 last mode remembered, a locked mode is never preselected; Q76 `wave_mode` is its own config field, `ruleset` stays reserved. Wave modes are marked Implemented in 09. Other questions touched by M4 and R1 and already recorded there: Q87 (Foundry limit in sectors 2+, open until M6), Q88-Q90 (resolved 2026-11-10).

## 6. Documents reconciled in this task

GDD 02 s6 (PURGE rule and mode bullets), GDD 05 s7 (row 11a, the PURGE unlock), GDD 07 s2.3 (Home mode picker) and s3 (FTUE changes), GDD 09 (wave modes Implemented), `docs/TECH_ARCHITECTURE.md` (section 5.2a: SimVersion 3 to 6 history, schema v2, goldens), `docs/ROADMAP.md` (M4 status, v1.8 changelog), `CLAUDE.md` (doc map, gotcha), `docs/tasks/M4.md` (ticks), `docs/perf/m4_stress.md` (new). Tooling: `Game.start_debug_load` now follows the wave mode (`--mode` or the profile's last mode) and `tools/save_craft.gd` gained `lastmode`; both only affect the debug stress scene.

## 7. Carried from M3 (list in `docs/tasks/M4.md`), state at the M4 exit

| Item | State |
|---|---|
| No `[PERF]` line on the title or Home | Still true: the title has no debug overlay, so `render_bench.ps1` can no longer start from a cold launch (steps in `docs/perf/m4_stress.md`) |
| Frame Bay card, QUIT? box and dialogs edge to edge | Fixed: shared 100 px menu side margin (572349d, `tests/unit/ui/test_side_margin.gd`) |
| Default Godot boot splash 10-25 s | Custom boot splash added (0c35a91, `tests/unit/ui/test_boot_splash.gd`); the cold-start time itself was not re-measured |
| Settings swipe starting on a button or slider | Still needs a real finger (M4-27 F10) |
| STRIKER unlock chip on Results | Verified on the emulator in M4-27 step 9 ("FRAME UNLOCKED: STRIKER") |
| `tools/smoke_persistence.ps1` does not exist | Still does not exist (not written, not dropped from the specs) |
| Bulwark title HIGH tier draws 16 against 15 | Not re-checked |
| Checkpoint cost 238 ms in the pause burst | Not re-measured on a phone; live saves at wave 60 under the stress scene took 10-96 ms on the emulator |
| Balance follow-ups `foundry_1k` x2.3, BULWARK +30% on `foundry_300` | Superseded by the R1-02 final tune (fresh / `foundry_300` / `foundry_1k` targets 14 / 20 / 27) |
| V1-21 and V1-22 never formally closed | Still open |

## 8. User-owned items (state only; none were resolved here)

| Item | Question | State per `docs/design/09_open_questions.md` and the repo |
|---|---|---|
| Trademark and store-name search on IRON STATIC | Q31 | OPEN. No record of a search in the repo. Fallback title EMBER CHASSIS. The icon and logo art lock waits for it |
| Real mid-range Android device | Q23 | OPEN. All device numbers so far are from the emulator and one Pixel-class phone (V1 report); the FC6 reference device is not chosen |
| Domain, privacy policy and account-deletion page | Q34 (also Q30) | Q34 still OPEN in the table. The privacy page is live (B1-05, d3d307d, GitHub Pages; the check that it loads in a private window is the user's, `docs/release/RELEASE_CHECKLIST.md`). The package ID is resolved (Q30 and Q79: `com.normalexception.game`). `app-ads.txt` is not needed for the ad-free beta build |
| Closed-test tester recruitment | Q36 (and Q86) | OPEN. The user-run B1 tasks (B1-10 internal dry run, B1-11 closed test with its tester log, B1-12) are not started |
| Feedback form | Q82 | OPEN. The Feedback page is held as a draft and the Settings button is hidden until the form exists (c013f86); the form URL is a placeholder |
| Developer address and trader status | Q83 | PARTIAL: developer name and support email decided 2026-11-09; address and trader status open |

## 9. Playtest questions to put to a human (none answered yet)

No human has played the M4 or R1 build in this record, so there are no answers to quote. The questions:

- From the M4 exit: **FC2** (immediate understanding: how many upgrades bought in the first 60 s with no text beyond the pointer; target 2 or more for 9 of 10), **FC7** (patch choice: can they state each patch's effect; is the gamble card taken 15-50% of the time), **FC8** (skin burn legibility: "what state is Cinder in?" mid-run, no numbers; 8 of 10 right), **overall feel** ("would you play another run?" is FC12), and **does PURGE feel different from TIMED** (ask after one run of each: pace, tension, when a wave feels over).
- For the R1 build (Q88, `docs/tasks/R1.md`): the human fun checks are **FC1** (first run length and death, 2-4 min, death at wave 9-14 for 8 of 10), **FC2**, **FC3** (permanent progress felt), **FC4** (unprompted redeploys, 3 or more in 15 min for 7 of 10), **FC7** and **FC12**. Five to eight people, on a phone, screen recorded, no coaching; FC4 and FC12 must pass before the open test track (B1-12). Record the results in `docs/playtests/`.
- Things only a person can judge, from M4-27: damage number legibility on a phone, the colorblind palettes (PROT was only selected, not shot in battle), haptic strength, whether the wave-5 draft arrives too early or too late.

## 10. Found broken or not done

1. Draw calls: about 70 on the battlefield alone against a 25 target / 40 hard limit, and 128-149 with the UI (V1: 74-77 total). Frame time on the emulator is 23.6-27 ms against 22 ms hard. Needs profiling on the real device; no change made.
2. PURGE target is stale after R1 (balance_run WARN, +50%): see section 1.
3. `perf_bench -Check` is sensitive to host load (it failed 7 of 10 runs while other agents used the machine and passed 3 of 3 when the host was quiet). If CI runs it on a shared runner, expect flakes; consider a wider band or a median of several runs.
4. VT-7 and VT-8 (visual tier pass, second slice) not done.
5. Not verified: damage numbers under the stress scene, haptics, the real-audio stress, the hull-damage FTUE hint, the edge boss chevron, MK I against MK II beam side by side, PROT palette in battle, Settings swipe with a real finger.
6. `render_bench.ps1` can no longer start from a cold launch (no overlay on the title); the manual steps are in `docs/perf/m4_stress.md`. A `--debug-load`-style bake or an overlay on the title would restore it.
7. Fixed on the way (tooling only): the debug load scenario ignored the wave mode (always TIMED); it now follows the mode. `tools/save_craft.gd` gained `lastmode`. The first attempt of the new op failed the compile gate on a Variant cast; fixed before lint.
