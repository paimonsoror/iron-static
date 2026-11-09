# M3-19 and M3-32 emulator verification (2026-11-08)

**Resolution in main (2026-11-09):** screenshots are stored downscaled (540 px wide JPG; full-size PNGs stayed in the verify worktree).
Bug A was fixed in main as `00ad64c` (`PauseOverlay` uses `set_anchors_and_offsets_preset`; the same bug was seen on the phone), so the
worktree's `_fit_overlay` was not taken; `fdff4ff` also makes the overlay resume on a completed tap only (a gesture-nav back swipe no longer
resumes). Bug B's `minimum_size_changed` fix was ported with a regression test (`test_save_problem_screen_fits_the_view_after_wrapping`,
reproduces the 5717 px column without the fix).

Device: AVD `tower_phone` (emulator-5554, 1080x2400), debug APK built from worktree `C:\dev\tower_verify` (origin/main `a8f7d3b`)
with `command_line/extra_args="-- --debug-perf"` (later `-- --debug-perf --quality=low`; restored to `""` afterwards).
APK size 179.4 MB (site/* not yet excluded in this tree). Screenshots: `docs/playtests/m3/verify/NN_*.jpg` (referenced below).
Helper tools (untracked, in the worktree only): `tools/save_craft.gd` (re-sign a profile with edits: bestwave, frames, frames2, select, schema),
`tools/layout_probe.gd` (headless layout probe used for bug B).

IMPORTANT: two blocking UI bugs were found (A: pause overlay, B: save-problem screen). Two tiny fixes are applied in the worktree only
(`src/ui/mobile_shell.gd`, `src/ui/flow/menu_screen.gd`, 11 lines, not committed). From the third build on, the device ran WITH these fixes;
drills 2 and 3 (first build) ran before them. `tools\test.ps1 -Path res://tests/unit/ui`: 296 tests, 0 failures with the fixes.

## Result table

| # | Item | Result | Evidence |
|---|---|---|---|
| M3-19.0 | Fresh install -> title has no CONTINUE -> NEW GAME -> frame bay -> Home -> DEPLOY -> death -> results -> Foundry/Redeploy/Home | PASS | 02, 03, 04, 05, 07, 08; log `[SAVE] boot load status=FRESH` |
| M3-19.1 | Foundry persistence (tap and hold buys survive force-stop) | PASS | 08/09 (tap F1 laser, hold bought hull F2, DATA 79 -> 17); after `am force-stop`: `status=OK`, profile dump `foundry {hull_integrity 2, laser_output 1}`, data `1.732e1`, PR 32 -> 33 on Home (11) |
| M3-19.2 | Kill mid-wave with pause (HOME key + force-stop) | PASS | `[CHECKPOINT] tick=747 hash=57fdf6c7f8c0fd1dbd4e77a7f5986eb40d37225e9f9968720ce92dfa1f8693c6` == `[RESUME] tick=747 hash=57fdf6c7...693c6`; `run resumed run=2 tick=747`; boots straight into the paused battle (12, 38) |
| M3-19.3 | Kill without pause (periodic checkpoint then `am force-stop`) | PASS | `[CHECKPOINT] tick=1646 hash=27fb8b8cac809a4a882ad9ea279bf6291cec03d10a966929fbff1e96a855611f` == `[RESUME] tick=1646 hash=27fb8b8c...611f` |
| M3-19.3b | `kill -9` of the process (run-as) | PASS | `[CHECKPOINT] tick=2546 hash=9693d8f5368f428b303b97c49219745d8242d1d45bc261154fa63bcab9e14e3f` == `[RESUME] tick=2546 hash=9693d8f5...4e3f` (new pid confirmed) |
| M3-19.4 | Corrupt live file -> RECOVERED from .bak | PASS | `[SAVE] boot load status=RECOVERED`, live file rewritten, toast "SAVE RESTORED FROM BACKUP" (18b), profile = the backup's content (19) |
| M3-19.5 | Corrupt both -> Save problem screen, files intact, START NEW PROFILE -> `*.corrupt`, Home with 0 data | PASS with bug B (build 1 FAIL, blank screen) | sha256 before launch = after launch = `d2782dacded40afab67be915548353adfd098a5406520f82fb04d05779733fae` (sav and bak); after START NEW PROFILE `profile.corrupt` and `profile.corrupt.1` both `d2782dac...3fae`; Home DATA 0 (20, 22) |
| M3-19.6 | Newer-schema file -> TOO_NEW screen, no writes | PASS | schema u16=2 re-signed file; `status=TOO_NEW problem=2`; sha256 sav and bak unchanged `dc18e84dbe296ace413e54a88dede67ab3b157921d9c8c20ca48220ffcecbb0a`; screen 21 |
| M3-19.7 | Redeploy timing | measured, under 10 s | (a) results -> REDEPLOY -> `run started`: about 1 s after the tap (banked 22:03:52.6, started 22:03:56.7 including ~3 s of my screenshot delay). (b) results -> FOUNDRY -> buy -> DEPLOY: banked 22:07:19.5 -> `run started` 22:07:28.5 = 9.0 s with three scripted taps and 2 s sleeps between (about 5 s of scripting overhead); DEPLOY tap -> run started 0.36 s. A human is well under 10 s |
| M3-19.8 | Settings mute + reduce motion + 30 fps + scientific persist and apply | PASS | 25 (changed), profile dump `fps_cap 30, muted true, number_format scientific, reduce_motion true`, 27 (after force-stop and relaunch, all four shown) ; title shimmer off with reduce motion, number sample `1.23e7` |
| M3-19.9 | Back gesture per screen | PASS (see notes) | Settings -> title (28); title -> QUIT? dialog (29); back again closes the dialog (30); Home -> toast BACK AGAIN TO EXIT (50); Foundry -> Home (55); Settings -> Home (56); Results -> Home (53); battle -> pause overlay (40), second back exits the app (pidof empty); NEW GAME dialog: back closes (43) |
| M3-19.10 | Snapshot cost on device | measured | `[CHECKPOINT] ms=` 22-51 ms in normal operation, 25-29 ms on resume, maximum seen 238 ms (the burst of 3 checkpoints when the app is paused; bytes 3408-3528, waves 1-5). Not run at wave 40 (no preset arg baked) |
| M3-19.11 | smoke_android `-SkipDeploy -WaitSeconds 120 -MinFps 30` | PASS (with the app in battle) | `SMOKE OK`, 10 PERF samples, lowest avg fps 32.3. NOTE: from the title the same command prints `SMOKE FAIL: no [PERF] lines` because the title and Home emit no `[PERF]` (see gap 1) |
| M3-19.12 | Screenshots: Home fresh/after runs, Foundry with glow, Results new best, Settings, Save problem, resume overlay | PASS | 04, 11/19, 08 (RECOMMENDED glow), 07, 23-27, 20/21, 13_resume_overlay_fixed |
| M3-19.13 | logcat errors only from the allowlist, no `ERROR: Strings:`/`ArtSlots:` | PASS | smoke log scan clean ("Log clean (6223 lines scanned)"); only emulator audio HAL `pcmWrite` warnings (emulator started with `-no-audio`) |
| M3-32.1 | Cold boot: title fade-in, time to first interactive frame, HIGH and LOW tier screenshots | PASS (numbers below) | 02 (HIGH), 66 (LOW, BULWARK hero). First cold launch after install: process start 21:49:44 -> `boot ok` 21:50:01 (17 s, includes shader compile), title visible about 1.4 s later; warm launches after force-stop: `OnResume` -> `boot ok` about 7-8 s, title toast/art visible about 10-12 s after launch |
| M3-32.2 | NEW GAME -> frame bay -> Home -> DEPLOY with each unlocked frame; stats in HUD | PASS | seeded profile (all frames unlocked, zero progress, so NEW GAME skips the dialog): bay shows STRIKER (32), BULWARK (33), VANGUARD (34). HUD hull on DEPLOY: VANGUARD 100/100 (37 first take), BULWARK 300/300, laser 13, cycle 0.8 (37); STRIKER 50/50, laser 8.5, cycle 1.3 (51). These match the balance table below |
| M3-32.3 | Frame selection persists across force-stop | PASS | profile dump `frame_selected bulwark` after SELECT; relaunch resumed BULWARK run with 300/300 hull (38); STRIKER shown on Home and title hero after reload (31, 49) |
| M3-32.4 | NEW GAME with progress: dialog, NO keeps, YES creates `*.reset` with equal sha256 | PASS | dialog 42; back closes (43); NO keeps (44, sav sha `6d1ae0bea9b26ba5ce7d96880218d63a4ac562bbc5aff639adc1975cf081b921` unchanged); YES -> bay (45) with `profile.sav.reset` sha `6d1ae0be...b921` (equal) and `profile.bak.reset` sha `fc87ba58459add8c031d8409ddadfb932895e4695ddb05158d5aafb52fcd6da8` (equal to the old backup); fresh profile VANGUARD, PR 32 |
| M3-32.5 | Settings > Data double confirm | PASS | RESET PROFILE -> "ALL PROGRESS IS LOST" (46) -> "LAST CHANCE: 0 DATA AND BEST WAVE 0 WILL BE LOST" (47) -> YES -> files `profile.sav.reset.1`, `profile.bak.reset.1`, lands on title (48) |
| M3-32.6 | CONTINUE with and without a run snapshot | FAIL against design 11 / PASS as implemented | without snapshot: CONTINUE -> Home (11). With a snapshot the app boots straight into the paused battle and never shows the title (12, 38) because `AppFlow.boot_screen(resumed)` returns BATTLE. design 11 section "Flow" says boot -> TITLE, CONTINUE -> the resumed run. See bug C |
| M3-32.7 | Back on title (QUIT?), frame bay, dialogs | PASS for title/dialogs; frame bay back not exercised | 29, 30, 43; the bay BACK button was not pressed, hardware back in the bay was not captured |
| M3-32.8 | Title draw calls and frame time at 60 s idle per tier | PARTIAL | the title emits no `[PERF]` line. SurfaceFlinger latency of the game surface (126 frames, adb, after 60-100 s idle): HIGH tier, FPS cap 60, motion on: avg 21.1 ms (47.5 fps), p50 19.7, p95 36.6, max 87 (60); HIGH, cap 30: avg 33.4 ms, p95 37.3 (58); LOW tier (`--quality=low`), cap 30: avg 33.4 ms (28.4-30 fps), p95 36.5 (66). Draw calls on the title are not measurable (battle `[PERF]` only) |
| M3-32.9 | Unlock chip on Results after crossing a best wave | PASS for BULWARK (8); STRIKER (15) NOT verified | fresh profile, no upgrades, died at wave 8: "FRAME UNLOCKED: BULWARK" chip, `run banked unlocked=["bulwark"]`, NEW BEST (07). A profile seeded to best 14 died at wave 12 and again at ~9 in two tries (64), so the 15 crossing was not reached. Unlock logic itself is exercised only for wave 8 |
| M3-32.10 | Ambience audible on title/Home, silent in battle | NOT VERIFIED | emulator runs with `-no-audio` and the test profile was muted; cannot hear. No `ERROR: AudioSlots:` in smoke |
| M3-32.11 | Title hero swap | PASS | VANGUARD (02), STRIKER (31), BULWARK (66) |
| M3-32.12 | smoke_android, `PERSISTENCE OK` script | smoke PASS; `tools/smoke_persistence.ps1` does not exist | the task files list that script as a deliverable; it was not written (drills run by hand with `run-as`, `tools/save_craft.gd`, sha256 from `run-as sha256sum`) |
| bg | Background/resume | PASS | HOME key during Home then relaunch: still Home (57); HOME key in battle: pause with checkpoint + `[SAVE]` (drill 2); `FOCUS_OUT` pause path as per V1-24 |

## Frame balance table (frame bay, 38/32/33/34, matches data/frames.csv)

| Frame | Hull | Fire rate | Damage | Range | Crit | Repair | PR | HUD at DEPLOY (no Foundry) |
|---|---|---|---|---|---|---|---|---|
| VANGUARD | 0% | 0% | 0% | 0% | 0% | 0% | 32 | 100/100 hull, laser 10, cycle 1 |
| BULWARK (unlock best wave 8) | +200% | -20% | +30% | -8% | 0% | +30% | 36 (+14%) | 300/300, laser 13, cycle 0.8 |
| STRIKER (unlock best wave 15) | -50% | +30% | -15% | -20% | +150% | -30% | 30 (-6%) | 50/50, laser 8.5, cycle 1.3 |

## Bugs found

### A. Pause overlay renders as a tiny top-left card (BLOCKER for the paused/resume UX) - FIXED IN WORKTREE
- `src/ui/mobile_shell.gd` `setup()`: `PauseOverlay.new()` is added as a child of `MobileShell`, which is a plain `Node`, so its FULL_RECT anchors
  and CENTER card have no parent size: the overlay has size 0, shows a clipped card ("RESUME / N TO EXIT", no title, no dim) at (0,0) and does
  not catch taps (screenshots 12, 13_resume_overlay, 14). Tapping the HUD play button unpauses but leaves the clipped card on screen.
- Repro: DEPLOY, press the HUD pause button (or HOME key then reopen, or kill the app mid-run and reopen).
- Fix (applied): `_fit_overlay()` sets `_overlay.position = 0` and `size = get_viewport().get_visible_rect().size` on setup and on `size_changed`.
  Verified on device: PAUSED / RUN RESTORED / TAP TO RESUME / BACK AGAIN TO EXIT centered with dim (13_resume_overlay_fixed, 38, 40).
  Alternative: parent the overlay under a `CanvasLayer`.

### B. Save problem screen (CORRUPT) is blank, START NEW PROFILE unreachable (BLOCKER) - FIXED IN WORKTREE
- `src/ui/flow/menu_screen.gd` `_layout()` sets `content.size = r.size` while the autowrap labels are measured at width 1: the VBox is
  inflated to about 5717 px tall (headless probe `tools/layout_probe.gd`: `content size=(1080,5717) min=(567,522)`) and never shrinks back
  because `_layout` only reruns on the screen's own `resized`. The column is centered in the 5717 px box, so the CORRUPT heading, body and button
  sit around y=2500-3100, off screen: the screen is completely dark and the only way out is the back gesture (quits). TOO_NEW is
  drawn but far too low (heading at y~1980, screenshot 21 from build 1).
- Repro: damage `profile.sav` and `profile.bak` (`run-as`, flip bytes) and launch. Log shows `status=CORRUPT problem=1`, the screen is blank.
- Fix (applied): `content.minimum_size_changed.connect(_layout)` in `MenuScreen._ready()`. Probe after: `content size=(1080,2400)`; on device the heading,
  three-line body and START NEW PROFILE button are centered (20), tapping it works (22). Other MenuScreens are probably affected in milder form
  when their labels wrap (title QUIT? box and dialog buttons are edge to edge, see C).
- The blank buggy screenshot of build 1 was overwritten by the fixed capture (file `20_save_problem_corrupt.jpg` is the fixed build; `21` is the build-1 TOO_NEW).

### C. Smaller findings and spec deviations (not fixed)
1. **Boot with a run snapshot skips the title** (`AppFlow.boot_screen`): design 11 says title first, CONTINUE -> resumed run. Decide which is intended.
2. **KNOWN (fix in progress, reported by main): the frame bay is reachable only via NEW GAME**; unlocked BULWARK/STRIKER cannot be selected from Home
   without a reset (NEW GAME with progress asks to erase). I used a seeded zero-progress profile to reach the bay.
3. Title and Home emit no `[PERF]` line and nothing logs the title draw calls: `smoke_android.ps1 -MinFps` fails with "no [PERF] lines" unless the
   app is already in battle; M3-32.8 cannot be measured the way the task states (used SurfaceFlinger latency instead).
4. The bay card, QUIT? box, NEW GAME and RESET dialogs and Home buttons draw edge to edge at the 1080 px width with no side margin (bay card left edge at x=0;
   YES/NO plates touch the screen edges in 29); cosmetic.
5. The very first screen after `am start` on a cold process shows the default Godot boot splash (18 first capture) for 10-25 s; consider a project boot splash/black.
6. Settings scroll: an `adb input swipe` that starts on a button or the slider (y=1400, 1800) did not scroll the list; starting on a panel title did. Could be the swipe
   speed vs Godot's scroll deadzone, worth a finger check on the phone.
7. Home with progress: gear icon only; the first run after NEW GAME shows no Foundry/Home buttons by design (nav appears after the first death).
8. Hold-buy in the Foundry bought two levels of the row under the finger when the first purchase reflowed the list (RECOMMENDED header disappears and rows shift by about 50 px);
   in the capture the hold started on a row that moved. Not an accidental purchase of a different row (hull F0->F2), but the shifting rows are worth a look for FC4 question 5.
9. First-run balance: an empty-handed fresh profile (no buys) reached wave 8 and unlocked BULWARK on run 1 (07); the M3 playtest question 11 depends on this.
10. After `NEW GAME` reset the previous settings (muted, reduce motion, fps 30, scientific) stayed in effect (title shown without shimmer); only Settings > Reset profile
    was not checked for settings reset. Probably intended (settings are device-level), mention in 09 if so.

## Perf numbers (emulator, not representative of the Pixel)
- Battle `[PERF]` (HIGH tier, cap 60): fps 21.6-36.3 average per 10 s window, frame_ms 29.5-45 (first windows during shader compile), draws 60-85, tick_ms 0.23-0.56, tex 84.7 MB, vid 90.9 MB.
- Battle LOW tier (cap 30): fps 26.9-29.4, frame_ms 34.0-34.5, draws 78-81, tex 81-82 MB.
- smoke `-MinFps 30`: 10 samples 32.3-36.3, SMOKE OK.
- Title: see M3-32.8 row.

## Not verified
- STRIKER unlock crossing (15) with the chip; striker frame data otherwise verified from the bay and HUD.
- Ambience audio (no emulator audio, muted).
- Draw-call count on the title; `[CHECKPOINT]` at wave 40.
- Wide/foldable layouts (emulator only, phone-sized AVD).
- Frame bay hardware-back and BACK button.
- `tools/smoke_persistence.ps1` does not exist (task deliverable not written by this pass).
