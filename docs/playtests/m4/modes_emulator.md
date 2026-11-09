# M4-12 Emulator verification: wave modes (2026-11-09)

Device: AVD `tower_phone` (emulator-5554, 1080x2400, gesture nav). Build: debug APK from worktree `C:\dev\tower_verify` at main `fa8c78f`
(clean checkout; old M3 probe edits stashed as "m3 verify probes"). First APK `extra_args=""`; the soak/perf APK was built with
`command_line/extra_args="-- --debug-perf"` and `export_presets.cfg` was restored to `""` afterwards (worktree only; main untouched).
Screenshots: `docs/playtests/m4/modes/modes_<step>_<what>.jpg` (540 px wide; full-size PNGs in `C:\dev\tower_verify\build\m4v\png\`, numbered in capture order).

Deviations from the spec text (all **(impl)**):
- Step 3 used a crafted save, not `--profile` / `tests/profiles/timed20.json` (neither exists): `tools/save_craft.gd bestwave 20` re-signs a pulled
  `profile.sav` with TIMED best 20 (sets both `best_wave["1"]` and `best_wave_by_mode["timed"]["1"]`) and was pushed back with `run-as`
  (profile.bak and the run snapshot removed first). No `tests/profiles/timed20.json` fixture was created.
- The one-time "PURGE MODE UNLOCKED" chip does not appear for a save that is merely loaded at best 20 (see Finding 1). It was verified with a second
  crafted save that carries the pending flag (`save_craft.gd modeflag purge`, writes `mode_unlock_pending` into the profile).
- Step 7 used `-MinFps 38` and `-Soak 120` (emulator baseline 42-45 fps, not 55).
- Two APKs, installed one after the other (never two deploys at once); the second install was `adb install -r` (data kept).

## Result table

| # | Step | Result | Evidence |
|---|---|---|---|
| 1 | Fresh profile: Home shows TIMED selected, PURGE locked with its condition | PASS | `modes_s1_home_fresh` (two segments above DEPLOY, TIMED highlighted, PURGE dimmed with lock icon); tap on PURGE: `modes_s1_purge_locked_condition` shows "Reach wave 20 in TIMED to unlock" + "Best TIMED wave: 0", TIMED stays selected (no mode switch) |
| 2 | Deploy TIMED: HUD time bar, 24 s waves | PASS | log `run started seed=1 run=1 mode=timed`; HUD "WAVE 1  17s" at about 7 s, "WAVE 2  17s" at about 30 s (`modes_s2_timed_hud_wave1`, `..._wave2`); checkpoint at tick 900 (30 s) |
| 3 | TIMED best 20: PURGE unlocked and "PURGE MODE UNLOCKED" | PASS with caveat (Finding 1) | `modes_s3_home_purge_unlocked_no_chip`: PURGE unlocked, summary "BEST W20", but no chip. `modes_s3_home_purge_unlocked_chip`: chip "PURGE MODE UNLOCKED" in the info panel under the picker once the flag is pending; it disappears on the next tap (`modes_s3_home_purge_selected`: PURGE selected, summary "NO DEPLOYMENT YET") |
| 4 | Deploy PURGE: "N LEFT", waves end on the last kill | PASS | log `run started seed=2 run=2 mode=purge`; HUD "WAVE 1  6 LEFT" -> "4 LEFT" -> next wave starts with the WAVE 2 banner and "7 LEFT" well before 24 s (`modes_s4_purge_hud_6_left`, `..._4_left`, `..._next_wave_banner`). The thin bar under the wave label fills with time (about 2 of 24 segments at 6 s, 5 at 12 s = the 60 s backstop) and resets to empty when the next wave starts. A run reached wave 13 in 6m30s (about 28 s per wave at 1x/2x mix) |
| 5 | Die: Results shows mode and the right record | PASS | PURGE death at wave 8: "PURGE MODE", "BEST PURGE 8" + "NEW BEST" (`modes_s5_results_purge_new_best`); PURGE death at wave 13: "BEST PURGE 13 NEW BEST" (`..._run3`); TIMED death at wave 8 with TIMED best 20: "TIMED MODE", "BEST TIMED 20", no NEW BEST, TIMED record unchanged by the PURGE runs (`modes_s5_results_timed`, Home `modes_s6_home_timed_best_unchanged` "BEST W20") |
| 6a | Kill app mid-PURGE (>= 30 s), reopen: boots to title, CONTINUE resumes in PURGE | PASS | `am force-stop` at tick > 1800; log `[CHECKPOINT] tick=1800 hash=7ef6187c...` == `[RESUME] tick=1800 hash=7ef6187c...`, `run resumed run=2 tick=1800`; title with CONTINUE (`modes_s6_title_continue_after_kill`); CONTINUE gives the paused overlay with "8 LEFT" in the HUD, i.e. PURGE (`modes_s6_resumed_paused_purge`). Repeated with the perf APK (install -r killed the app at wave 8, resumed in PURGE with "9 LEFT") |
| 6b | REDEPLOY repeats the last mode | PASS | after a PURGE results screen REDEPLOY logs `run started seed=3 run=3 mode=purge` (`modes_s6_redeploy_purge`) |
| 6c | Chosen mode remembered across restarts | PASS | after force-stop and relaunch (title -> CONTINUE), Home preselects PURGE with "BEST PURGE 13" (`modes_s6_home_purge_remembered`); tapping TIMED shows "BEST W20" (`modes_s6_home_timed_best_unchanged`) |
| 7 | Soak/perf smoke in PURGE | PASS (against the emulator baseline) | `smoke_android.ps1 -SkipDeploy -WaitSeconds 20 -Soak 120 -MinFps 38 -Serial emulator-5554` during a PURGE run (wave 8 to 13, `modes_s7_purge_wave13_smoke`): `SMOKE OK`, "Log clean (13079 lines)", 13 PERF samples after warm-up: fps 40.5-49.9 (mostly 47-50), lowest per-line min 25, tick_ms 0.19-0.27, draws 83-86, vid 81-82 MB. Spec's `-MinFps 55` is not reachable on this emulator |

Log scan over the whole session: no `SCRIPT ERROR`, `ERROR: Strings:`, `ERROR: ArtSlots:`, `FATAL`, `ANR`. Only the benign "Failed to load cached shader" and
`Property not found: 'xr/shaders/enabled'` warnings.

## Findings

1. **LOW/MEDIUM - unlock chip is only set after a bank.** `Game._on_run_ended` calls `ModeUnlockFlag.mark(...)` from `saves.last_unlocked_modes`, but `SaveService.load`
   also fills `last_unlocked_modes` (`apply_unlocks` at boot) and nothing marks it there. A profile that reaches TIMED best 20 by any path other than a banked
   run in this session (restored backup, imported/crafted save, a lowered CSV threshold) unlocks PURGE silently with no chip. The normal path (a TIMED death at
   wave 20) was NOT reproduced on the emulator (the chip display was verified with an injected flag); it is covered only by unit tests. Worth a manual TIMED run to wave 20 on the phone.
2. **LOW - Results can show a TIMED-driven frame unlock after a PURGE run.** Seeded profile (TIMED best 20, only VANGUARD unlocked): the first PURGE death showed
   "FRAME UNLOCKED: BULWARK, STRIKER" (`modes_s5_results_purge_new_best`). This follows from Q71 (frames gate on TIMED best, which was already 20) and from `bank` running
   `apply_unlocks`, so it is an artifact of the crafted save, not a mode leak; noted so nobody mistakes it for a PURGE bug.
3. **LOW - inconsistent best-line wording.** Home summary: TIMED "BEST W20" but PURGE "BEST PURGE 13"; Results: "BEST TIMED 20" / "BEST PURGE 13". Not a defect, but the Home TIMED line has no mode name.
4. **LOW - Home shows only the selected mode's record.** With PURGE selected the TIMED best (the gate for PURGE and frames) is not visible and vice versa; a fresh PURGE record shows "NO DEPLOYMENT YET" even
   though TIMED has runs (`modes_s3_home_purge_selected`). Could confuse; design call.
5. **LOW - layout (cosmetic, same family as M3 finding C4).** The TIMED/PURGE segments, the info panel, DEPLOY, the summary panel and the HOME/FOUNDRY buttons are edge to edge at 1080 px: the
   left of TIMED and the right of PURGE touch x=0 and x=1080, and the lower buttons end about 45 px above the bottom edge (inside the gesture-nav zone). The PURGE lock icon and label are left of centre;
   the label of the locked segment is dimmed to low contrast. No clipped text anywhere (6 LEFT, 11 LEFT, BEST PURGE 13 all fit; the timer label right edge is moved for PURGE as intended).
6. **INFO - run snapshot and resume look right.** `[CHECKPOINT]` costs 14-20 ms, 3.4-3.8 KB. The resume overlay says "RUN RESTORED / TAP TO RESUME" (PURGE state restored, quota count preserved).
7. **INFO - the thin PURGE backstop bar** is the same segmented strip under the wave label as the TIMED timer bar; there is no label saying it is a backstop. Its fill is easy to miss next to the
   wave-progress dashes (the two strips look alike). Consider a distinct colour or a "60 s" caption.
8. Not verified: a TIMED run reaching wave 20 (natural unlock) and its chip; a PURGE wave hitting the 60 s backstop (all observed waves ended by quota); PURGE with the boss wave (10); Standby/offline math.

## Reproduction notes
- Fresh install -> NEW GAME -> CONTINUE in the frame bay (y=2135) reaches Home; taps on Home: PURGE segment about (830, 2050) on a fresh profile, DEPLOY (540, 2260) before the nav buttons appear.
- Save craft: pull `files/save/profile.sav` with `run-as ... cat`, run `godot --headless --path C:\dev\tower_verify -s res://tools/save_craft.gd -- in.sav out.sav bestwave 20`, force-stop, `adb push` to
  /data/local/tmp, `chmod 644`, `run-as com.ironstatic.game cp ... files/save/profile.sav`, `rm files/save/profile.bak files/save/run_snapshot.sav`.
