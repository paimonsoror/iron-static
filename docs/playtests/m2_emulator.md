# M2 emulator verification (M2-15)

- Date: 2026-11-08. Device: AVD `tower_phone` (1080x2400, host GPU Intel Iris Plus). Build: debug APK of the working tree (uncommitted, includes the strings fix below).
- Method: `adb shell input tap/swipe/motionevent` scripted session, `adb exec-out screencap`, every screenshot viewed.

## Inputs

| Input | Status |
|---|---|
| Running emulator | FOUND (cold-booted once mid-task, see FPS) |
| Debug build with upgrade panel | FOUND (4 deploys: first one showed raw string keys, see Bug 1) |
| Screenshots | FOUND (`docs/playtests/m2/`) |
| `user://runs/last_run.json` | FOUND (pulled with `run-as`) |
| `[PERF]` lines | FOUND only in a temporary `--debug-perf` deploy (preset restored to `""` afterwards) |

## Bug 1 (FIXED, the user saw it): every label showed its string key

First deploy: `hud.wave`, `tab.arms`, `upgrade.laser_output`, `row.level`, `row.value`, `panel.next_unlock` everywhere. Logcat: `Strings: res://data/strings_en.csv: file not found`. Cause: `data/` has a `.gdignore`, so Godot never exports it; `Strings` read the CSV with `FileAccess`. An `include_filter="data/strings_en.csv"` did NOT help (verified by deploying; reverted to `""`).
Fix **(impl)**: the importer now also writes `src/data_gen/strings_en.tres` (new `StringTable` resource, `src/data_defs/string_table.gd`: `keys`/`texts` PackedStringArrays, byte-identical on rerun, skipped when the CSV is absent); `Strings` loads it first and falls back to the CSV. Tests: `test_strings.gd` (generated table exists and equals the CSV), `test_importer.gd` (strings CSV in the copied tables, file count 19). Lint clean, tests 344/0 failures. APK check: the APK zip lists `assets/src/data_gen/strings_en.tres` and `string_table.gdc`; the 4th and later screenshots show real names. Not done: a "every UI key resolves" scene test, `number_suffixes.csv` still uses the NumberFormat const fallback (same export problem, harmless), and the `docs/setup/android_export.md` note (docs/setup untouched on purpose).

## Screenshots (all viewed)

| File | What it shows |
|---|---|
| `01_battle_fresh.png` | Fresh battle, wave 1, `SCRAP 20`, `DATA 0`, hull `100 / 100`. Panel: tabs ARMS (selected) / CHASSIS / SYSTEMS / INTEL, `BUY x1 x10 x100 MAX` (x1 selected), 2 rows: LASER OUTPUT `L0` `10 > 11` cost `15` (amber, affordable), CYCLE RATE `L0` `1 > 1.04` cost `25` (dim gray, unaffordable), then `Next unlock at wave 3`. Rows are placeholder cream squares for icons. The ARMS tab shows only 2 of the 4 starting rows (the other 2 are on CHASSIS). |
| `02_after_buy.png` | After tapping the laser cost button once: `SCRAP 5`, LASER OUTPUT `L1` `11 > 12`, next cost `17` now gray. 20 to 5 and cost 17 as specified. |
| `03_amber_affordable.png` | Later in the run, `SCRAP 17`: cost `17` turned amber (affordable) while CYCLE RATE `25` stays gray. |
| `04_buy_x10_chassis.png` | CHASSIS tab with `x10` selected (highlighted). HULL INTEGRITY `100 > 110` cost 15 (gray at scrap 5), NANO REPAIR `1 > 1.1` cost 20. Icons are gray-white squares (chassis color). |
| `05_tab_systems_fresh.png` | SYSTEMS tab on a fresh save: no rows, only `Next unlock at wave 3` (locked-row hint). |
| `06_tab_intel.png` | INTEL tab: `INTEL: coming in a later update` stub. |
| `07_tooltip_attempt_nothing_shown.png` | Long press on a row (finger held about 1 s): NO tooltip visible. See Bug 2. |
| `08_debug_overlay.png` | Debug overlay open (double tap): buttons B0-B3, AUTO, LOAD, BW0, BW12, BW100, text block, `BEST WAVE 0 (BW sets it; applies next run)`. Panel below unaffected. |
| `09_results.png` | Results overlay: `DEPLOYMENT ENDED`, `WAVE REACHED 8`, `TIME 3m 05s`, `KILLS 78`, `CAUSE LANCER` (red), `DATA +99` (blue), `SCRAP 167`, `BEST --`, `REDEPLOY` button. Dimmed battle and panel behind. |
| `10_bw12_arms.png` | New run after `BW12`: ARMS now has 5 rows (3rd CRIT CHANCE `2.0% > 2.8%` cost 60 partly visible) and a thin scrollbar at the right edge. |
| `11_bw12_arms_scrolled.png` | ARMS scrolled: CRIT CHANCE, CRIT MULT `x1.5 > x1.55` (80), OPTIC RANGE `24m > 24.4m` (40). x10 shows a half-highlighted border (see observations). |
| `12_bw12_chassis.png`, `13_bw12_chassis_scrolled.png` | CHASSIS: HULL INTEGRITY 15, NANO REPAIR 20 (amber at scrap 20), PLATING `0.0% > 0.5%` 100. All 3 fit; the swipe changes nothing. |
| `14_bw12_systems.png` | SYSTEMS: SCRAP YIELD `x1 > x1.02` 50, REINVEST `0% > 0.06%` 300, tan icons. No hint line (nothing locked). Total 5 + 3 + 2 = 10 rows. |
| `15_max_mode_after_buy.png` | MAX mode selected; buy applied (scrap 20 to 11 after earning, laser `L1`, next 17). |

Not captured: a milestone gold ring (needs a row within 3 levels of level 25; at L0 with 20 scrap it is not reachable in a short session; cost curves make it a mid-run state, so M2-16/the user should look for it at about level 22 of laser output), and the tooltip (Bug 2).

## Verified tap coordinates (1080x2400)

| Control | Tap (x, y) | Verified |
|---|---|---|
| Tabs ARMS / CHASSIS / SYSTEMS / INTEL | (140, 1430) / (406, 1430) / (672, 1430) / (938, 1430) | each by screenshot |
| Buy mode x1 / x10 / x100 / MAX | (210, 1586) / (456, 1586) / (702, 1586) / (948, 1586) | x1, x10, MAX by screenshot; x100 same geometry |
| Row 1 / row 2 cost button | (890, 1782) / (890, 2022) | row 1 purchase verified; with the scrollbar shown (BW12, 5-row tab) the button is 8 px left (use x 882) |
| Row 3 (partly visible) | y about 2263 | seen, not tapped |
| Scroll the list | `input swipe 540 2250 540 1500 500` | ARMS tab |
| SPEED button | (775, 87) | `1x` to `2x`, persists across REDEPLOY |
| Debug overlay show/hide | `input tap 40 40; input tap 40 40` | row 1 y=365, row 2 y=465 as given; BW12 at (221, 465) confirmed |
| REDEPLOY | (540, 1455) (button spans x 100-980, y 1380-1530) | tapped, new run started |

Timing note: two `adb shell input` calls in one command can swallow the second tap (one tab tap was lost); keep a short sleep between taps.

## Acceptance

| Item | Verdict | Evidence |
|---|---|---|
| Panel works on the emulator, buy applies | PASS | 02, 15: scrap 20 to 5, `L1`, cost 17 |
| Tabs, buy modes, locked hint, 10 rows after BW12, INTEL stub | PASS | 01, 04, 05, 06, 10-14 |
| Results fields `TIME`, `DATA +n`, `BEST --` | PASS | 09 |
| Amber affordable vs gray unaffordable | PASS | 01 (15 amber, 25 gray), 03 |
| Readable at 1080x2400 | PASS with notes | names and values large; gray cost text is low contrast (below) |
| Touch targets not overlapping | PASS | tabs 148 px, buy bar 148 px, cost buttons 316x148 with gaps; no overlap in any screenshot |
| Long-press tooltip | FAIL / UNVERIFIED | Bug 2 |
| `SMOKE OK` | see below |
| `last_run.json` exists and parses | PASS | below |

## Smoke and FPS

`.\tools\smoke_android.ps1 -SkipDeploy -WaitSeconds 120 -MinFps 30` on a `--debug-perf` build (temporary preset edit, restored): log clean, process alive, amber color check passed (95 of 65536 samples), but **SMOKE FAIL: fps 24.1 below MinFps 30** (12 samples after warm-up: 24.1 to 31.4 average, mins 9 to 28, tick_ms 0.17 to 0.23, 4 to 7 enemies). Known emulator limit (Q23/Q40, M1 saw 14-34); script not loosened. Worse run before a cold boot: the emulator ran the same build at `fps=1.2` (qemu had been up for hours; debug overlay showed `FPS 2`), and recovered after `adb emu kill` + `-ColdBoot`. Treat qemu slowdown over time as the likely cause, not the panel; but the panel was never measured in a clean M1-style soak, so M2-16 should compare. A plain smoke on the final non-perf build is recorded at the end of this file.

## last_run.json

`adb shell run-as com.ironstatic.game cat files/runs/last_run.json` works (debug build). 345 bytes, parses as JSON (dict): `best_wave_s1 0`, `command_count 1`, `commands "76,0,1"` (tick 76, buy index 0, count 1), `config_hash`, `death_wave 8`, `debug_invulnerable false`, `final_hash`, `final_tick 5571`, `format 1`, `ruleset standard`, `sector 1`, `seed 1`, `sim_version 1`. Consistent with the screen (wave 8, 3m 05s = 5550 ticks, one purchase).

## Bug 2 (NOT fixed): long-press tooltip never appeared

Tried `input swipe x y x y 700/2000`, with 2 px movement, and `input motionevent DOWN ... sleep 1 ... UP` on the name area and the empty bottom of a row: no tooltip in any screenshot (07). The row code (`upgrade_row.gd`, `_gui_input` starts a 0.4 s timer on a left press; tooltip lives 3 s) looks right and unit tests pass, so the suspect is the touch path: `ScrollContainer` touch handling or emulated mouse events do not deliver a held press to the row (or the press was consumed as the start of a scroll). Needs a human long-press on a real finger to tell injection artifacts from a real bug; if real, follow-up for M2-12/M2-10 (e.g. handle `InputEventScreenTouch`, or set the scroll container to not intercept).

## Observations

- x10 one-handed: tabs and the buy bar sit at y 1356-1660 of 2400, i.e. about 30 percent up from the bottom edge; the x10 button (456, 1586) is reachable for a right-hand thumb on a tall phone only with a stretch, and the cost buttons (right side, y 1710-2340) are comfortable. The buy bar is above the rows, so changing mode means a reach up and back. Suggest the user judges on a real device.
- The BUY label eats a quarter of the buy bar row, shrinking each mode button to 238 px wide and tab and mode columns do not line up.
- Row text: names (about 38 px) and `a > b` values (mono, bold) are legible; the `L0` level text is small and dim and the mono/Oxanium zero looks like the letter O (`L0` reads `LO`). The `L1`-style level is the only place the zero matters.
- Gray (unaffordable) cost numbers are very faint (about 15 percent luminance against the dark button): readable but easy to miss, and 17 vs 25 cannot be told apart in a glance at distance; amber is clearly distinct.
- Only 2 rows are fully visible on a fresh ARMS tab and ARMS has 5 rows; the spec's "about 3 rows" holds; rows are 231 px tall with a lot of empty space inside (value text fills little of the row).
- Row icons are flat placeholder squares (cream = arms, gray-white = chassis, tan = systems).
- The hint `Next unlock at wave 3` sits in the scroll list; on SYSTEMS fresh it is the only content, leaving a big empty panel.
- Scrap went unspent: at wave 8 the player had 163 scrap with only 1 purchase (idle-style but the panel does not signal "you can buy" beyond amber text; no row badge or tab notification).
- Wave 1 is very quiet (about 8 s without a visible enemy, first kills at 10 s); a fresh run can look idle.
- The x10 button showed a half-highlighted border after a panel swipe (11): probably a stuck hover/focus style from the earlier tap.
- Speed 2x persists across REDEPLOY (1x/2x state is app-level), unlike the best wave.

## Visual quality (honest view for the visual pass)

The battlefield is a 3-concentric-ring dark grid with a tiny turret (about 150 px wide on a 1080 px screen) and enemies that are 25 px thin red wireframes: most of the 1344 px battle area is empty black, the fight is hard to read, there is no glow, bloom, hit flash, damage numbers or particle feedback (a laser is one thin yellow line), no background texture or depth, and 1 px ring/grid lines are barely visible. HUD: the cyan hull bar is a flat full-width block with plain text, scrap and data are bare text without icons, the wave timer bar is a thin dull brown strip; the panel is functional but flat: identical dark rounded rectangles with 2 px amber outlines, placeholder color squares instead of icons, one font weight, dim gray secondary text, large unused space inside rows and below the list. Results screen is clean but plain centered text. It reads as a developer prototype, not a finished game; the structure and spacing are fine, the art/effects layer is absent.

## Questions for the user's M2 playtest

1. Does a held finger on a row show the tooltip (Bug 2)?
2. Is x10/x100/MAX reachable and does the buy bar's position above the rows feel right?
3. Is gray cost text too faint?
4. Is the first minute too quiet; is spending 15 scrap on laser vs hull the intended first choice?
5. Does a gold milestone ring appear near level 22-24 (not reachable in this session)?
6. Do you want ARMS/CHASSIS split so a fresh run shows only 2 rows per tab, or one merged list early on?

## Final state

Preset: `command_line/extra_args=""` and `include_filter=""` (restored). Emulator running with the final non-perf debug build, app restarted so the best wave is 0.

Plain smoke on the final non-perf build (`-SkipDeploy -WaitSeconds 40`): **SMOKE OK** (log clean, 2307 lines; amber share 96 of 65536 samples).

## M2-16 follow-ups (2026-11-08)

- `number_suffixes.csv` now ships as `src/data_gen/number_suffixes.tres` (`NumberSuffixTable`), `NumberFormat` loads it first; `docs/setup/android_export.md` has the `.gdignore` export rule and an APK-contents check; `tests/unit/ui/test_ui_string_keys.gd` guards missing UI keys (HUD, panel with 10 rows, results overlay, every `upgrade.<id>`).
- Bug 2 (tooltip): headless test `tests/unit/ui/test_row_long_press.gd` (panel in a SubViewport, real ScrollContainer) shows the tooltip after a held mouse press, none on a short tap or after a drag. The row only handled mouse events; it now also handles raw touch/drag events. The adb injection is the likely cause of the miss; a human long-press is still needed (09 Q57).
- The observations above are tracked as 09 Q48-Q56.
