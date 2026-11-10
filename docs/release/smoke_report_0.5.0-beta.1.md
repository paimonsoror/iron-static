# Smoke report 0.5.0-beta.1 (code 50001), B1-07

Status: emulator half done 2026-11-10. Phone half is open and needs the user (section "Phone (user present)").

**Package rename (2026-11-10, after the emulator run):** the package ID changed from `com.normalexception.game` to `com.normalexception.games.ironstatic` (09 Q30/Q79, user decision, before any Play upload). The builds in the table below carry the old ID. The phone session installs a test-key AAB rebuilt with the new ID; its sha256 is recorded in the phone section. Uninstall any old `com.normalexception.game` test install first: it is a separate app.

## Build under test

| Item | Value |
|---|---|
| File | `build\release\ironstatic-0.5.0-beta.1-50001-TESTKEY.aab` (git-ignored) |
| sha256 | `46d072e822b896a0a9c0ab49c02e3e1a5c3d69cc2580b3bc419a12a1509d3328` (rebuilt after the B1-07-A fix; the emulator run below used the first build, sha256 `adec380351faf8cee0d8f598330ed821cdcf31f6d17379f86795fa607e627ca1`, which differs only by the overlay gate) |
| Matches the `.sha256` written by `release_build.ps1` | yes (checked by `tools\aab_install.ps1` on every install, and by hand) |
| Size | 58,934,439 B (56.2 MB) (first build: 58,934,283 B) |
| Built from | branch `b1-smoke` at 2aa7f26 (main 2111d9c plus the B1-07-A fix), clean tree, `tools\release_build.ps1 -TestKey` |
| Signed with | the throwaway test key (`build\testkey\`). **NOT upload-ready.** |
| `aab_check.ps1` | PASS: targetSdk 36, minSdk 24, permissions = `VIBRATE` only, allowBackup false, game category, only the launcher alias is exported, `PAGE_ALIGNMENT_16K`, `zipalign -P 16` ok, 4/4 `.so` LOAD alignment 2**14 with RELRO, size 56.2 MB |

**Re-do item for the real upload AAB.** The upload keystore does not exist yet (user's open item), so this run proves the build pipeline and the content, not the file that will be uploaded. When the upload-key AAB exists, repeat on that file: (1) record its sha256 and compare with the `.sha256` next to it, (2) `tools\aab_check.ps1`, (3) `tools\aab_install.ps1 -Aab <file> -Serial emulator-5554 -Uninstall` (it uses the test or debug keystore for the local APK, never the upload key), (4) a short run to Results. The size and the content will not change, the signer will.

**Upload-key AAB (built 2026-11-10 on main 413734f, clean tree, `toolselease_build.ps1`):** `buildelease\ironstatic-0.5.0-beta.1-50001.aab` (git-ignored), 56.21 MB, sha256 `edec05e775b7f5db9f1d61d14475c8963cd19e4e6fe3d875a95c65c227c871db` (matches its `.sha256`). Signer = the upload key, certificate SHA-256 `FF:38:E9:CC:47:E2:4A:42:70:0A:5F:C6:93:39:18:7E:44:B5:8E:9C:1A:CC:7B:52:4B:7A:05:16:80:EC:33:BC` (after the first upload, Play Console > App integrity > Upload key certificate must show the same value). Re-do items: (1) sha256 done, (2) `aab_check` PASS (same results as the test-key build), `play_publish release` dry run PASS (package `com.normalexception.games.ironstatic`, 50001, 0.5.0-beta.1, notes 356/500). (3) and (4) not run on the emulator: the local APK would be re-signed with the test key and carry the same content already tested above; the install of this file through the internal testing track (Google-signed APKs) replaces them and is recorded in the phone section.

## Emulator

| Item | Value |
|---|---|
| AVD | `tower_phone`, serial `emulator-5554`, cold boot 51 s |
| Android | 15, API 35 |
| ABI | x86_64 (the bundle carries arm64-v8a and x86_64) |
| Page size | 4096 (not a 16 KB image; 16 KB behaviour is covered by the `aab_check` alignment checks only) |
| Renderer | OpenGL ES 3.0 Compatibility, emulator translator on an Intel GPU |

## Install

`tools\aab_install.ps1` (new): verifies the sha256, runs bundletool 1.18.3 `build-apks --mode=universal` signed with the test keystore, then `install-apks --device-id emulator-5554`, launches through the launcher alias and scans the log.

| Item | Result |
|---|---|
| Install | success, versionName 0.5.0-beta.1, versionCode 50001, minSdk 24, targetSdk 36; `install-apks` 9 to 27 s |
| Launch | `am start -W` ok, TotalTime 1.1 s to 6.0 s (this is the window, not the first Godot frame) |
| Time to first frame, fresh install, cold app, sampled by screenshot polling | about 2 s Android splash, about 5.5 s IRON STATIC logo on black (first Godot frame), about 11 s title screen with buttons. This is an emulator figure; the phone figure is open (see below) |

Note: `com.godot.game.GodotApp` is not exported, so `am start -n pkg/com.godot.game.GodotApp` fails with a SecurityException. Use the alias `com.godot.game.GodotAppLauncher` (the script does).

## Scripted 3-minute run (fresh install)

Driven with `adb -s emulator-5554 shell input tap` at coordinates taken from `screencap` captures (1080x2400): title NEW GAME (540,2080), Frame Bay CONTINUE (540,2135), skip the cold-open (540,1200), speed 2x (875,180), buy LASER OUTPUT (880,2050) and CYCLE RATE (880,2245), draft card (540,1090 or 1220), Results HOME (540,1905).

| Step | Result |
|---|---|
| Cold open (RELAY 06 ONLINE ...), tap to skip | ok |
| Run 1 start, upgrades bought | ok (start scrap 229; laser and cycle rate bought repeatedly) |
| Wave-5 draft | appears after wave 5 ("WAVE 5 CLEARED", 3 cards, REROLL ALL), pick works, hull 100 to 112 after Plating. A second draft appears after wave 10 |
| Death | run 1: wave 13 after 4 m 58 s (killer WALKER). Run 3 (clean log run, scripted end to end): Results at about 3 m 20 s into the app session, best wave 15 |
| Results | opens, stats, killer tile, TIMED label, NEW BEST, FRAME UNLOCKED: BULWARK, REDEPLOY / FOUNDRY / HOME |
| Return Home | the deploy screen (CINDER ASH-07, BEST TIMED, DEPLOY) shows with banked DATA |
| Process | alive the whole time, no ANR, no crash |

Run 3 was done twice more than needed because the first two runs started before a continuous `logcat` capture; run 3 has the full-session log (14,798 lines) used for the counts below.

## First-run hints (R1 build, wave-5 draft)

Hints come from `data/ftue.csv` (FTUE beats). Screenshots are in `docs/release/smoke_0.5.0-beta.1/`.

| Hint | Seen | Evidence |
|---|---|---|
| Laser hint at run start, "TAP: MORE DAMAGE" pointing at LASER OUTPUT | yes | `hint_laser.jpg` |
| Rate hint after the first kill, "TAP: FIRE FASTER" pointing at CYCLE RATE | yes, replaced the laser hint at the first kill (DATA 0 to 1) | `hint_rate.jpg` |
| Never two at once | yes: every captured frame (about 190) shows at most one hint box | all frames |
| Hull hint on first damage, "TAP: SURVIVE LONGER" pointing at CHASSIS | yes | `hint_hull.jpg` (run 1, wave 8, bar still 112/112 when it appeared); followed by "HOLD TO BUY SEVERAL" |
| Draft note at the wave-5 draft | yes: "Patches last this deployment. One reroll per draft." under the title | `hint_draft_note.jpg` |
| Death note (`death_note`, text key `results.title`) | not visible by design: the CSV target is `none`, so it is a silent beat that completes at once. Nothing on screen to capture | `data/ftue.csv` |
| Results FOUNDRY pointer, "FOUNDRY - UPGRADES STAY", FOUNDRY button outlined and pulsing | yes | `results_foundry_pointer.jpg` |

Also seen: "DART - FAST" label on the first dart, wave 6 (hint order in the CSV has it before the hull hint).

Observation (low): in run 2 (no upgrades bought) the first damage arrived while the DART label was still up, and the player died about 13 s later, before the queued hull hint was shown (`drop_pending` on run end). Run 3 profiles still get it in run 2 or 3 (`max_runs` 3). Not a defect, noted for the playtest.

## Log scan (full session, 14,798 lines, run 3 plus install and launch)

| Pattern | Count |
|---|---|
| `SCRIPT ERROR` | 0 |
| `ArtSlots:` | 0 |
| `Strings:` | 0 |
| `FATAL` | 0 |
| `ERROR` (case-sensitive) | 0 |
| ANR / Force quitting / process died | 0 |
| E-priority lines from the game (informational) | 5, all benign, quoted below |

```
E SurfaceSyncGroup: Failed to receive transaction ready in 1000ms. Marking SurfaceSyncGroup(wmsSync-VRI[GodotAppLauncher]#1) as ready   (x3, first frame on the emulator)
E godot   : WARNING: Failed to load cached shader, recompiling.
E godot   :    at: _load_from_cache (drivers/gles3/shader_gles3.cpp:615)
```

The shader-cache warning appears once per first launch after an install (nothing cached yet). A first-frame stall of about 1 s on the emulator (SurfaceSyncGroup) is expected. A plain case-insensitive `ERROR` match gives 114 hits, all system lines such as `artd: ... I/O error`; `aab_install.ps1` therefore matches case-sensitively.

## Debug features in the release build

| Feature | Reachable in the release AAB? | How checked |
|---|---|---|
| `--debug-perf`, `--debug-load`, `--debug-load-wave`, `--hold`, `--style-frame`, `--mode` | no | guarded by `OS.is_debug_build()` in `src/core/game.gd`; also the intent extra `command_line_params` was passed on the emulator and the app logged `with parameters []` (the release template ignores it), and no `[PERF]` line appeared |
| `--probe-services` | no | `services.gd` requires `OS.is_debug_build()`; same intent test, no "boot probe requested" line; log shows `services: billing=stub ads=stub` |
| Style frame scene | no | `src/debug/*` is excluded from the beta preset and `main.gd` also checks `is_debug_build()` |
| `--no-save`, `--mute`, `--quality=`, `--shake=` | not reachable (intent extras ignored), and not harmful if they were | `game.gd` / `visual_settings.gd` |
| **On-device debug overlay (double tap or 0.8 s long press in the top-left 100 px corner)** | **YES, reachable** | see bug B1-07-A |

### Bug B1-07-A (Medium to High): the on-device debug overlay is live in the release build

`src/ui/debug_overlay.gd` toggles on two taps (or a long press) inside the top-left 100x100 px square during a run. It is not guarded by `OS.is_debug_build()` or any feature flag, and `src/ui/debug_overlay.tscn` is not excluded. In the AAB on the emulator, `adb shell "input tap 40 40; input tap 40 40"` during a run showed the overlay (`BUG_debug_overlay_in_release.jpg`): buttons B0..B3, AUTO, LOAD (restarts as the wave-60 invulnerable scenario), BW0 / BW12 / BW100 (set the in-memory best wave), HIGH / MID / LOW quality, VSYNC, D40 / D100 / D165 / RUN, NOBF / NOHUD, plus FPS, SIM, DRAWS, and the build string. It is also an on-screen proof for testers that this is a debug-grade build. Risks: a tester can hit it by accident (the corner is under the status/notch area on many phones), the BW buttons change the in-memory best wave (shown on Results as the best; saved at the next save), and the LOAD / D buttons start an invulnerable high-load scenario that could pollute feedback. It does not touch the save path directly, so it is not a security issue.

Fix (commit 2aa7f26): `DebugOverlay.gestures_enabled` defaults to `OS.is_debug_build()`; `_input` and `toggle()` return at once when false and `_ready` calls `set_process_input(gestures_enabled)`. `show()`/`hide()`/`visible` still work, and the `main.gd` handlers are only reachable through the overlay buttons, so they stay unguarded. Tests: `tests/unit/ui/test_debug_overlay_gate.gd` (7 cases: disabled double tap, long press, raw input events and `toggle()` stay hidden; `hide/show` still work; enabled double tap and long press still toggle). ui folder: 478 tests, 0 failures; lint OK. Rebuilt test-key AAB passes `aab_check`. Not re-run on the emulator (not restarted); step 9 of the phone checklist re-checks it on a device.

Other `OS.is_debug_build()`-guarded paths found: `game.gd` (args, above), `services.gd` (probe), `main.gd` (style frame). Nothing else is guarded or reachable.

## Screenshots (in `docs/release/smoke_0.5.0-beta.1/`, from the AAB-derived APK)

- Title: `title.jpg`
- Home (deploy screen with banked DATA): `home_deploy.jpg`
- Battle: `battle_wave2.jpg` (hints: `hint_laser.jpg`, `hint_rate.jpg`, `hint_hull.jpg`, `hint_draft_note.jpg`)
- Results with FOUNDRY pointer: `results_foundry_pointer.jpg`
- Bug evidence: `BUG_debug_overlay_in_release.jpg` (it also shows the overlay's numbers on the emulator: FPS 44, DRAWS 112 at wave 4, quality HIGH; the emulator renderer is not representative of a phone)

## Problems

| ID | Severity | Problem |
|---|---|---|
| B1-07-A | Medium to High | Debug overlay reachable by a two-tap on the top-left corner in the release AAB (above). Fix before upload |
| B1-07-B | Low | The cold first launch after install shows a black or splash-only screen for about 5 s and the title at about 11 s on the emulator; the phone number is open (the old note says about 30 s) |
| B1-07-C | Info | `Failed to load cached shader, recompiling` warning (E priority) on each first launch after install, benign |
| B1-07-D | Info | Hull hint can be missed in a run that ends within about 12 s of the first damage; it returns in run 2 or 3 |
| B1-07-E | Info | This AAB is test-key signed; the upload-key AAB needs the re-do listed at the top |
| B1-07-F | Info | Emulator page size is 4 KB; no 16 KB system image run was done here |

No error-level lines. Install, run, Results, Home and uninstall all passed on the emulator.

## Cleanup

The game was uninstalled from the emulator (`pm list packages` shows nothing for `normalexception`), which wipes the emulator save. The emulator was shut down.

---

## Phone (user present)

**Status: NOT DONE. Everything below is empty until the user is present.** Target device: the user's Pixel, adb serial `65211FDDJ001TH`. No adb command was ever run against it in this task.

Order matters: installing a different build or uninstalling wipes the test save, so do the play session first and the optional debug build last.

**Build for the phone session** (rebuilt 2026-11-10 on main d186adf, after the package rename): `build\release\ironstatic-0.5.0-beta.1-50001-TESTKEY.aab`, 58,935,656 B, sha256 `a456d8cfdb5a9f67b760cc33cfe2d02f4e33cfb0225469ddd05c7b117b1cf97a`. `aab_check` PASS; `bundletool dump manifest` shows `package="com.normalexception.games.ironstatic"`, versionCode 50001, versionName 0.5.0-beta.1; no `release/store` images in the bundle; `release/version.json` present. First uninstall any old `com.normalexception.game` install on the phone (a separate app). Since testers install from Play (user decision 2026-11-10), the phone session can use the internal-track install of the upload-key AAB instead; a sideloaded test-key build of the same package must be uninstalled before Play can install over it (different signer).

### Checklist

1. [ ] Plug in the phone, unlock it, accept the USB debugging prompt. Check `adb devices` lists `65211FDDJ001TH` as `device`. Note the model and Android version: `adb -s 65211FDDJ001TH shell getprop ro.product.model` and `... ro.build.version.release`. Page size: `adb -s 65211FDDJ001TH shell getconf PAGE_SIZE` (16384 on a 16 KB device).
2. [ ] Fix the upload-key AAB first if it exists by then, and run the re-do item at the top of this file. If it does not exist yet, use the test-key AAB above and say so in the sign-off.
3. [ ] Install the APK derived from the same AAB (never touches other packages):
   `powershell -File tools\aab_install.ps1 -Aab build\release\ironstatic-0.5.0-beta.1-50001-TESTKEY.aab -Serial 65211FDDJ001TH -NoLaunch`
   Install result: ______
4. [ ] Cold-start timing. Force stop, then launch by tapping the icon with a stopwatch (or `adb -s 65211FDDJ001TH shell am start -W -n com.normalexception.games.ironstatic/com.godot.game.GodotAppLauncher`). Time to first frame (any Godot frame): ______ s. Time to the title with buttons: ______ s.
5. [ ] Play for 10 minutes: cold open, run 1 with upgrades, the wave-5 draft, death, Results, the FOUNDRY pointer, run 2, Foundry purchases, Settings, one pause and resume, one app switch away and back, screen lock and unlock.
6. [ ] fps feel (smooth / occasional stutter / bad), at a crowded wave: ______
7. [ ] Haptics (on kills, damage, UI taps; Settings toggle works): ______
8. [ ] Hints: laser at run start, rate after first kill, hull on first damage, draft note, Results FOUNDRY pointer: ______
9. [ ] Double-tap and long-press (about 1 s) the top-left corner during a run. The debug overlay must NOT open (B1-07-A fix). Result: ______
10. [ ] `adb -s 65211FDDJ001TH logcat -d | findstr /C:"SCRIPT ERROR" /C:"ArtSlots:" /C:"Strings:" /C:"FATAL"` counts: ______
11. [ ] Screenshots (Home, Battle) saved to `docs/release/smoke_0.5.0-beta.1/phone_*.jpg`: ______
12. [ ] Uninstall (wipes the test save, warn the tester): `adb -s 65211FDDJ001TH uninstall com.normalexception.games.ironstatic`. Skip this if step 13 is about to run, it replaces the package anyway.
13. [ ] **Optional, last.** Real-device draw-call and fps reading. The M4-28 emulator run showed about 70 battlefield draw calls against a hard limit of 40 (`docs/perf/m4_stress.md`); a phone reading matters. Install a debug build (preset `IronStatic`, `tools\deploy_android.ps1 -Serial 65211FDDJ001TH` with `--debug-perf`, see `docs/setup/android_export.md`), play to a crowded wave (about 20+), then read the `[PERF]` lines: `adb -s 65211FDDJ001TH logcat -d | findstr "[PERF]"`. Record fps, min, tick_ms, draws, vid_mb: ______. A debug build is signed with a different key, so installing it over the release build needs an uninstall first, which wipes the save. That is why this step is last.

### Sign-off

Phone model / Android / page size: ______

Time to first frame: ______ s

fps feel: ______   Haptics: ______

Result: [ ] PASS  [ ] FAIL, reasons: ______

User sign-off (name or "ok" and date): ______
