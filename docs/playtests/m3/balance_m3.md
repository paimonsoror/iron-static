# M3 balance measurements (M3-08 Foundry, M3-24 frames; the 2026-11-09 retune section is at the end)

Date 2026-11-08. Sector 1, seeds 1..N (same seeds for every row), cap 100 waves, profile `fresh` unless stated.
Sim and goldens unchanged (`SimVersion` untouched, no `src/sim` edit). Output is byte-identical across two runs
(checked: `foundry_300` twice, `--frame all --policy none` twice). Measured in an isolated copy of HEAD plus this
task's files (the shared tree did not compile during the measurement because of another agent's in-progress
`game.gd`).

## M3-08 Foundry profiles ("run 2 is stronger")

Commands (20 runs each):

```
.\tools\balance_run.ps1 -Profile fresh -Waves 100 -Runs 20
.\tools\balance_run.ps1 -Profile tests\profiles\foundry_300.json -Runs 20
.\tools\balance_run.ps1 -Profile tests\profiles\foundry_1k.json -Runs 20
```

| Profile | Foundry levels | data spent | p10 | p50 | p90 | mean | mean game min | delta median vs fresh | delta mean vs fresh | GDD target |
|---|---|---|---|---|---|---|---|---|---|---|
| `fresh` | none | 0 | 8 | **9** | 9 | 8.70 | 3.23 | 0 | 0 | 12 (x1) |
| `foundry_300` | laser_output 5, hull_integrity 4, cycle_rate 2 | 325 | 11 | **11** | 12 | 11.20 | 4.37 | **+2 waves** | +2.50 | fresh + 4 (04 s3), i.e. 13 |
| `foundry_1k` | laser_output 12, hull_integrity 10, cycle_rate 4 | 997 | 21 | **22** | 27 | 23.90 | 9.31 | **+13 waves** | +15.20 | x2 = 24 (03 s6) (impl guess) |

Fresh output is unchanged from the pre-M3 numbers (p10 8, p50 9, p90 9, mean 3.23 min, deaths lancer 45%,
skitter 40%, dart 15%).

Acceptance: `foundry_300` median 11 is strictly above fresh 9, and `foundry_1k` (22) is at least `foundry_300`
(11). PASS.

**Flag for Q54 and the balance pass:** the first 300 data buy only **+2 waves (mean +2.5)** against the design
target of +4 (04 s3, FC3 "at least 4 waves"). That is exactly at the "flag if below +2" line. Cause of death
shifts to `boss_hulk` (45%) at wave 11-12: the wave-10 boss gate dominates the early curve, so the same
300 data in `foundry_1k` jumps +13. Track D measured laser_output F10 + hull_integrity F10 at median 21; the
`foundry_1k` mix (12/10/4) lands at 22, consistent. No Foundry or run-upgrade values were retuned.
`data/targets.csv` has `foundry_300` (13) and `foundry_1k` (24) rows; they are information only (a FAIL there is
reported as WARN) and the tolerance of 30% means 11 vs 13 prints PASS, so read the `FOUNDRY delta` line.

## M3-24 frame balance gate (40 runs, `fresh`, same seeds)

Commands:

```
.\tools\balance_run.ps1 -Frame all -Policy greedy4 -Runs 40
.\tools\balance_run.ps1 -Frame all -Policy none -Runs 40
.\tools\balance_run.ps1 -Profile tests\profiles\foundry_300.json -Frame all -Runs 40
```

### Before tuning (design 11 s1.2 starting values)

| Frame | greedy4 mean | median | delta vs VANGUARD | none mean | median | delta vs VANGUARD |
|---|---|---|---|---|---|---|
| VANGUARD | 8.68 | 9 | 0 | 7.88 | 8 | 0 |
| BULWARK (hull 1.6, cycle 0.75) | 5.42 | 5 | -37.5% | 5.05 | 5 | -35.9% |
| STRIKER (cycle 1.4, laser 0.9) | 11.00 | 11 | +26.8% | 8.75 | 9 | +11.1% |

Gate FAILED both ways with the starting values (BULWARK too weak everywhere, STRIKER too strong).

### Option P: parity-tuned values (NOT applied: they break the frame identities; `data/frames.csv` is back at the design values)

| Frame | greedy4 mean | median | p10 | p90 | delta vs VANGUARD | none mean | median | p10 | p90 | delta vs VANGUARD |
|---|---|---|---|---|---|---|---|---|---|---|
| VANGUARD | 8.68 | 9 | 8 | 9 | 0.0% | 7.88 | 8 | 7 | 8 | 0.0% |
| BULWARK | 8.95 | 9 | 8 | 9 | **+3.2%** | 8.00 | 8 | 8 | 8 | **+1.6%** |
| STRIKER | 9.32 | 9 | 9 | 10 | **+7.5%** | 5.08 | 5 | 5 | 5 | -35.6% |

Gate (design 11 s1.4, Q67):

| Criterion | Result |
|---|---|
| BULWARK greedy4 mean within +-10% of VANGUARD | +3.2% PASS |
| STRIKER greedy4 mean within +-10% of VANGUARD | +7.5% PASS |
| BULWARK wins idle (`--policy none`): mean above VANGUARD | 8.00 vs 7.88 PASS (margin 0.12 waves) |
| STRIKER wins greedy4: mean above VANGUARD | 9.32 vs 8.68 PASS |
| VANGUARD unchanged from pre-frame numbers | fresh p10 8, p50 9, p90 9, mean game 3.23 min PASS |
| Byte-identical across two runs | PASS |
| `--frame bogus` / `--frame salvager` / unknown Foundry id exit | 2 / 2 / 2 |

**Option P passes the gate with `data/frames.csv` tuning only (no sim change), but violates the identity bounds from the main agent (BULWARK cycle <= 0.80, STRIKER cycle >= 1.30). See the next section: inside the identity bounds the gate cannot be met.**

With the `foundry_300` profile (the Foundry stays shared, 40 runs, greedy4):

| Frame | mean | median | delta vs VANGUARD | delta median vs fresh same frame |
|---|---|---|---|---|
| VANGUARD | 11.13 | 11 | 0.0% | +2 |
| BULWARK | 11.98 | 12 | +7.6% | +3 |
| STRIKER | 10.95 | 11 | -1.6% | +2 |

STRIKER stays inside +-10% with the Foundry but no longer beats VANGUARD there (-1.6%); the gate is on the fresh
profile, so this is information for the balance pass.

### frames.csv tuning log (option P, steps 0-7; identity-bounded steps 8-14 below)

All runs 40 seeds, `fresh`. "none" = `--policy none`. Swept with a scratch script that sets the `FrameMods`
directly (same code path as the importer values); the final values were then imported and re-measured through
`balance_run` (identical numbers).

| # | Change | BULWARK greedy4 | BULWARK none | STRIKER greedy4 |
|---|---|---|---|---|
| 0 | starting values | 5.42 | 5.05 | 11.00 |
| 1 | cycle is the dominant lever: BULWARK cycle 0.75 -> 0.9 | 7.30 | 7.00 | - |
| 2 | BULWARK cycle 1.0, hull 1.6 / 2.0 | 9.20 / 9.53 | 8.00 / 8.00 | - |
| 3 | BULWARK cycle 0.95, hull 2.0 / 2.2 / 2.5 | 8.45 / 8.53 / 8.68 | 7.92 / 7.95 / 7.97 | - |
| 4 | BULWARK cycle 0.975, hull 2.0 (chosen) | **8.95** | **8.00** | - |
| 5 | STRIKER cycle 1.4 -> 1.1-1.3 (laser 0.9, hull 0.65) | - | - | 10.88-11.00 (a cliff at wave 11) |
| 6 | STRIKER cycle 1.0, laser 0.9, hull 0.65 / 0.5 | - | - | 9.55 / 9.32 |
| 7 | STRIKER cycle 1.0, laser 0.8, hull 0.65 (chosen) / 0.5 | - | - | **9.32** / 8.97 |

Sensitivities (per 40 seeds): `optic_mult` 0.92 -> 1.0 changes BULWARK by under 0.2 waves; the Bastion passive
changes nothing at these waves (identical means with and without it): it only bites later, so BULWARK's
identity is not tested by this gate. Each -0.1 on `cycle_mult` costs about 2 waves; hull x1.6 -> x2.0 adds only
about 0.3 waves.

Final values: BULWARK `hull_mult` 1.6 -> **2.0**, `cycle_mult` 0.75 -> **0.975** (plating +0.10, nano x1.3, optic
x0.92 unchanged); STRIKER `cycle_mult` 1.4 -> **1.0**, `laser_mult` 0.9 -> **0.8** (hull x0.65, nano x0.7, crit
+0.03 unchanged).

**Option P consequence (impl):** design 11 s1.2 and the frame bay card text need these numbers
(the cards are computed from the data, so the UI follows). STRIKER is now "fire rate x1.0, damage x0.8, hull
x0.65": its edge is the Overclock passive (up to +20% rate) and crit, not a base fire-rate bonus, and it
collapses when idle (-35.6%). The early game is extremely cycle-limited (the wave-10 boss gate), which is why a
+-10% band forces frames toward cycle 1.0; revisit after the Q54 retune.

## Identity-bounded search (main agent constraint) - GATE CANNOT BE MET, STOPPED

Bounds: STRIKER cycle >= 1.30, hull <= 0.75, laser 0.85..1.0; BULWARK cycle <= 0.80, hull >= 1.4. Levers used:
STRIKER hull/nano/crit/plating; BULWARK laser/plating/nano/optic/hull. Passive strength has no data lever (the
passives are fixed constants in `FrameMods`, and "none" would drop the identity), so it was not varied.
Same 40 seeds, `fresh`, VANGUARD greedy4 8.68 / none 7.88. Swept with a scratch script that sets `FrameMods`
directly (verified equal to `balance_run` on the earlier values). **`data/frames.csv` is back at the design
values (HEAD), the generated `.tres` and the tests that pin them are untouched.**

BULWARK (cycle 0.80, nano x1.3, plating +0.10, optic x0.92, Bastion), `none` = idle:

| laser_mult | hull | greedy4 mean (delta) | none mean (delta) |
|---|---|---|---|
| 1.0 (design cycle 0.75, hull 1.6) | 1.6 | 5.42 (-37.5%) | 5.05 (-35.9%) |
| 1.1 | 1.6 / 2.0 | 6.42 / 6.50 (-26%) | 6.00 / 6.00 (-24%) |
| 1.2 | 1.6 / 2.0 | 6.58 / 6.70 | 6.00 / 6.03 |
| 1.3 | 1.6 / 2.0 | 7.95 / 7.97 (-8.4%, in band) | 6.00 / 6.03 (-24%, loses idle) |
| 1.35 | 1.6 | 8.32 (-4.1%, in band) | 6.00 (-24%, loses idle) |
| 1.4 | 1.6 | 11.68 (+35%) | 6.08 |
| 1.5 | 1.6 | 11.85 (+37%) | 6.25 |
| 1.7 | 1.6 | 11.85 | 6.97 (-11.5%) |
| 1.85 | 1.6 | 11.88 | 7.70 (-2.3%) |
| 2.0 | 1.6 | 11.90 (+37%) | 8.65 (+9.8%, wins idle) |
| 1.4, hull 3.0 | 3.0 | 12.00 | 6.58 |

Result: the two BULWARK criteria are mutually exclusive inside the bounds. Staying within +-10% on greedy4 needs
laser <= 1.35 and then idle is 6.0 (-24%, no idle win); winning idle needs laser ~2.0 and then greedy4 is +37%.
Armor (hull x1.6 to x3.0) and optic barely matter; the early curve is gated by damage output at the wave-6/8/11/12
thresholds (death-wave cliffs), which cycle and laser move in steps.

STRIKER (cycle 1.30, laser 0.85, Overclock):

| hull | nano | crit | greedy4 mean (delta) |
|---|---|---|---|
| 0.65 (design) | 0.7 | +0.03 | 11.00 (+26.8%) with cycle 1.4, laser 0.9 |
| 0.5 | 0.3 / 0.7 | 0 / 0.03 | 11.00 (+26.7%) |
| 0.3 | 0.3 / 0.7 | 0 / 0.03 | 10.90-10.93 (+25.6-26%) |
| 0.2 | 0.1 | 0 | 10.50 (+21%) |
| 0.1 | 0.1 | 0 | 9.72 (+12.0%, plating -0.1/-0.3 no change) |
| 0.1 (cycle 1.35) | 0.1 | 0 | 10.07 (+16%) |
| 0.05 | 0.05 | 0 | 8.32 (-4.1%, no greedy win) |
| 0.1, Overclock off | 0.1 | 0 | 9.03 (+4.0%) |

Result: with a believable "limited armor" (hull 0.3-0.75) STRIKER is +26% (outside the band) because cycle 1.30 is
already past the wave-11 cliff. It re-enters the gate only at hull <= ~0.08 with nano <= 0.1 (a 5-8% hull and
almost no repair, a degenerate Cinder), or with Overclock off (not a data lever).

Closest identity-respecting results: BULWARK (cycle 0.8, laser 1.35, hull 1.6) is within the band on greedy4 (-4.1%)
but loses idle by 24%; STRIKER (cycle 1.3, laser 0.85, hull 0.1, nano 0.1) is +12.0% (2 points outside) with a 10%
hull. **The user must choose between identity and parity** (options: relax the cycle bounds to option P; or keep
identity and accept a wider band, for example +-30% like FC10, plus a different "wins one scenario" rule; or a sim
change such as scaling frame effects against the wave-gate thresholds, which this task may not do).
Interaction with Q54: all of this is on the current balance where early upgrades barely matter; a Q54 retune
(early return) should be done first, then re-run `-Frame all` and re-tune.

---

# Q54 early-curve retune and frame pass (2026-11-09, SimVersion 2)

User decision 2026-11-09: "Fix the early curve first". Order: (1) early-curve retune, (2) passive strengths as data, (3) BULWARK and STRIKER inside the identity bounds, (4) SimVersion bump and re-baselining. Everything was measured in an isolated copy of HEAD plus the files of this task (the shared tree did not compile: other agents' in-progress `src/ui` and `src/core` files). Sector 1, seeds 1..N (same seeds in every row), profile `fresh` unless stated, cap 100 waves in `balance_run`, 30-45 in the sweep tool.

## Commands

```
.\tools\balance_run.ps1 -Profile fresh -Waves 100 -Runs 40
.\tools\balance_run.ps1 -Profile tests\profiles\foundry_300.json -Runs 40
.\tools\balance_run.ps1 -Profile tests\profiles\foundry_1k.json -Runs 40
.\tools\balance_run.ps1 -Frame all -Policy greedy4 -Runs 40
.\tools\balance_run.ps1 -Frame all -Policy none -Runs 40
.\tools\balance_run.ps1 -Profile tests\profiles\foundry_300.json -Frame all -Runs 40
.\tools\balance_run.ps1 -Policy only:hull_integrity -Runs 40      # new policy: buys just that row
.\tools\balance_run.ps1 -Policy only:nano_repair -Runs 40
.\tools\balance_run.ps1 -Profile <json with best_wave_s1 10> -Policy only:plating_pct -Runs 40   # plating is gated at best wave 10
```

Tuning sweeps used a scratch tool (not committed) that applies `key=value` overrides to the loaded config (tuning, enemy, upgrade and frame fields) and runs N seeds; its numbers equal `balance_run` (checked: VANGUARD 11.55 / 8.13 and the frames 12.30 and 12.43 are identical).

## Step 1: early-curve retune

Diagnosis (old data, greedy4, laser base damage scaled by k to find the walls): k 1.0 gives 9, 1.2 gives 10.5, **1.4 to 1.8 gives 11 (flat)**, 2.0 gives 12 (mean 14), 2.5 gives 21-22 (a second flat at 20-21). The walls are the **boss waves** (wave 10 and 20: `boss_hulk` HP 607 at wave 10, 25x a skitter, killing 45% of old `foundry_300` runs) and the 2-shot to 3-shot kill thresholds (skitter HP 14 x 1.063^(w-1) against integer laser damage). Hull x2 adds +0.7 waves and x4 adds +2, so armor mattered little. `boss_hulk` hp_mult 25 to 10 lifted old `foundry_300` from 11.17 to 12.29 (14: 11.67, 18: 11.21). Fresh runs die before the boss, so they only move with income and cost.

### Data changes (final)

| File | Row | Old | New |
|---|---|---|---|
| `enemies.csv` | `boss_hulk` hp_mult | 25 | 8 |
| `sim_constants.csv` | `n_base` | 6 | 4 |
| `sim_constants.csv` | `start_scrap` | 20 | 60 |
| `run_upgrades.csv` | `laser_output` c0 / g | 15 / 1.09 | 10 / 1.108 |
| `run_upgrades.csv` | `hull_integrity` c0 / g | 15 / 1.09 | 10 / 1.108 |
| `run_upgrades.csv` | `nano_repair` step (p) | 0.10 | 0.60 |
| `run_upgrades.csv` | `plating_pct` step / c0 | 0.005 / 100 | 0.06 / 20 |
| `targets.csv` | `foundry_300` target | 13 | 16 (fresh 12 + 4) |

`g` 1.108 with `c0` 10 prices a level the same as the old curve near level 25 (15 x 1.09^25 and 10 x 1.108^25 are both about 129), so the change is front-loaded: early levels are 20-36% cheaper, later ones are not. This is what keeps `foundry_1k` near x2.

### Tuning log (24 seeds unless stated; fresh / foundry_300 / foundry_1k means)

| # | Change | fresh | f300 | f1k |
|---|---|---|---|---|
| 0 | old data | 8.68 (40) | 11.13 (40) | 24.65 (24) |
| 1 | boss hp_mult 12 | 8.71 | 12.0 | 26.75 |
| 2 | boss 12 + start_scrap 60 / 100 | 9.17 / 10.13 | 12.17 (60) | 26.83 (60) |
| 3 | boss 12 + laser/hull c0 10 (g 1.09) | 10.50 | - | - |
| 4 | boss 12 + c0 10 g 1.108 + start 60 (X1) | 10.63 | 15.21 | 27.94 (16 seeds) |
| 5 | X1 with start 100 (X2) | 10.79 | 15.88 | - |
| 6 | X1 + `scrap_k` 3 (X3) | 11.17 | **18.46** (too strong) | - |
| 7 | boss 8 + start 60 / 100 (Y1 / Y2) | 10.83 / 11.08 | 15.21 / 15.88 | - |
| 8 | **Y1 + `n_base` 4 (Y3, chosen)** | **11.88** (40 seeds: 11.90) | 15.75 | 28.13 |
| 9 | Y2 + nano step 0.3 | 11.21 | - | - |

`scrap_k` 3 was rejected (it moves `foundry_300` by +7 for +0.5 fresh). `start_scrap` is the cheapest lever because it does not move `foundry_1k` (26.75 to 26.83). Final tool numbers (40 seeds) are below.

### Before and after (40 seeds, `balance_run`)

| Profile | Before mean (median) | After mean (median) | Target | Result |
|---|---|---|---|---|
| `fresh` greedy4 | 8.68 (9) | **11.55 (12)**, p10 11, p90 12, 4.43 game min | 12 +-30% | PASS (dev +0.0%) |
| `foundry_300` | 11.13 (11) | **15.55 (16)**, delta median +4, mean +4.00 | fresh + 4 | PASS |
| `foundry_1k` | 24.65 (26), 24 seeds | **27.25 (27)**, delta median +15 | about x2 (24) | PASS in tolerance (+12.5%), about x2.3 of fresh |
| `fresh` idle (`--policy none`) | 7.88 (8) | 8.13 (8) | none | - |

Causes of death after (fresh): skitter 60%, dart 13%, lancer 13%, boss 8%, walker 8% (before: skitter 48%, lancer 33%). The old boss wall is gone; `foundry_300` now dies to lancers (58%) and skitters (28%).

### Check: early hull, plating and repair purchases extend runs (40 seeds, vs idle)

Rule: a bot that buys only that row must beat the idle mean (8.13) by at least +0.4 waves.

| Policy | mean | median | delta vs idle | Result |
|---|---|---|---|---|
| `none` | 8.13 | 8 | 0 | baseline |
| `only:hull_integrity` | 8.75 | 9 | **+0.62** | PASS |
| `only:nano_repair` | 8.70 | 9 | **+0.57** | PASS |
| `only:plating_pct` (best wave 10 profile; idle on that profile is also 8.13) | 8.60 | 9 | **+0.47** | PASS |

Before the retune (same method, measured during tuning): hull +0.62, nano repair +0.12 (step 0.10), plating +0.0 to +0.1 (c0 100, +0.5%), so nano and plating were useless early. Plating needs about +6% per level to register: +3% at c0 25 gave only +0.12, +5% at c0 20 gave +0.34, +8% at c0 15 gave +1.0 (too strong long term: the 0.90 cap is reached at level 12). +6% at c0 20 was taken between those points and measured above.

Side effect of nano step 0.6: the greedy4 bot now values `nano_repair` above `laser_output` at 20 scrap (its reference EHP counts 60 s of repair). Fresh stayed at 11.55, median 12.

## Step 2: passive strengths as data (sim change)

`data/frames.csv` has three new columns, imported into `FrameDef` and read into `FrameMods`: `bastion_cap_frac` (0.20, max share of max hull per hit), `overclock_per_kill` (0.01), `overclock_cap` (0.20). Defaults equal the old constants (`BASTION_HIT_CAP`, 1% per kill, kill cap 20). The Overclock charge uses integer fixed point (`inc * kills * round(per_kill * 100000) / 100000`, identical to the old `/ 100` for the default); the kill cap is `floor(cap / per_kill)`. `FrameMods.hash_text` only appends the strengths when they differ from the defaults, so a default frame keeps its config hash. New tests: `test_frame_bastion` and `test_frame_overclock` (custom strengths, defaults), `test_frame_data` (columns).

## Step 3: BULWARK and STRIKER inside the identity bounds

Bounds (user, HARD): STRIKER cycle >= 1.30, hull <= 0.75, laser 0.85..1.0; BULWARK cycle <= 0.80, hull >= 1.4. Gate: each within +-10% of VANGUARD (mean, 40 seeds, median reported) on a fresh profile; BULWARK wins idle; STRIKER wins greedy4.

Old design values on the new curve: BULWARK (hull 1.6, cycle 0.75) 7.75 greedy4 (-33%), 7.05 idle (-13%); STRIKER (cycle 1.4, laser 0.9, hull 0.65) 16.45 (+42%), idle 10.38 (+28%). The curve change moved the problem, not the cause: fire rate dominates.

Sweep (BULWARK cycle 0.80, nano x1.3, plating +0.10, optic x0.92; greedy4 / idle mean):

| laser_mult | hull | greedy4 | idle |
|---|---|---|---|
| 1.2 | 1.6 | 10.63 | 8.03 |
| 1.4 | 1.6 | 12.73 | 8.03 |
| 1.6 | 1.6 | 17.25 | 8.57 |
| 1.8 | 1.6 | 19.75 | 9.22 |
| 1.3 | 2.0 | 11.60 | 8.22 |
| 1.3 | 2.0, plating +0.20 | 11.90 | 8.28 |
| **1.3** | **3.0** | **12.30** | **8.70** |
| 1.3 | 3.0, plating +0.35, nano x2 | 12.75 | 9.22 |

Armor is the idle lever: laser alone cannot win idle without pushing greedy4 to +49%; hull x3.0 wins idle (+7.1%) at +6.5% greedy4.

STRIKER (cycle 1.30, laser 0.85, hull 0.5; greedy4 mean): base 14.03 (+21%); scrap x0.85 13.48, x0.7 12.73; Overclock 0.5% per kill and 10% cap 13.65; optic x0.85 13.10, x0.8 **12.43**, x0.75 11.95, x0.7 11.45. Reduced optic range is the lever that cuts STRIKER without touching the bounds (shorter reach, less time to kill dart and skitter). Optic x0.80 chosen (wins greedy4 by 0.88 waves).

Final `frames.csv` values: BULWARK hull 1.6 to **3.0**, cycle 0.75 to **0.80**, laser 1.0 to **1.3** (plating +0.10, nano x1.3, optic x0.92 unchanged). STRIKER cycle 1.4 to **1.30**, laser 0.9 to **0.85**, hull 0.65 to **0.50**, optic 1.0 to **0.80** (nano x0.7, crit +0.03 unchanged). Passive strengths unchanged (defaults).

Gate (fresh, 40 seeds, `balance_run -Frame all`):

| Frame | greedy4 mean | median | delta vs VANGUARD | idle mean | median | delta |
|---|---|---|---|---|---|---|
| VANGUARD | 11.55 | 12 | 0 | 8.13 | 8 | 0 |
| BULWARK | 12.30 | 12 | **+6.5%** | 8.70 | 9 | **+7.1%** |
| STRIKER | 12.43 | 12 | **+7.6%** | 8.45 | 8 | +4.0% |

| Criterion | Result |
|---|---|
| BULWARK greedy4 within +-10% | +6.5% PASS |
| STRIKER greedy4 within +-10% | +7.6% PASS |
| BULWARK wins idle | 8.70 vs 8.13 PASS |
| STRIKER wins greedy4 | 12.43 vs 11.55 PASS |
| Identity bounds (STRIKER cycle 1.30, hull 0.5, laser 0.85; BULWARK cycle 0.80, hull 3.0) | PASS |

With the `foundry_300` profile (40 seeds, greedy4): VANGUARD 15.55 (16), BULWARK 20.23 (+30.1%), STRIKER 17.98 (+15.6%). The frames scale better than VANGUARD once the Foundry multiplies their stats. The gate is the fresh profile, so this is informational; it is a Q67 follow-up (user decision: accept, or add a Foundry-profile gate).

## Step 4: SimVersion and re-baselining

`SimVersion.CURRENT` 1 to **2** (the data change alters every outcome; the sim code change of step 2 is hash-neutral for default frames). A snapshot saved under version 1 is discarded (`SimSnapshot.restore` already requires `sim_version == CURRENT`), so a run in flight across the update ends through the existing "run ended by update" path. The repo has no multi-version replay machinery, and an old `RunRecord` no longer verifies against a version 2 config hash (the config hash also changed because the data did).

Re-baselined (each is a pin of a number that the retune deliberately changed):

| Test | What changed | Why |
|---|---|---|
| `tests/sim/test_replay.gd` | `GOLDEN_SIM_VERSION` 2, `GOLDEN_CONFIG_HASH` 43ca2931...8337, `GOLDEN_FINAL_HASH` 49509380...eda0 (seed 7, 3000 ticks, scripted buys) | config and outcome changed by design. The command-shift test also tries a 40-tick shift: with start scrap 60 a 1-tick shift no longer crosses a shot |
| `test_frame_mods.gd`, `test_foundry_sim.gd` | `PRE_M3_CONFIG_HASH` equals the new default hash | the "neutral frame is bit-identical to no frame" and "all-zero Foundry is bit-identical" checks compare against the default config hash |
| `test_economy_system.gd` | start scrap 60 (62, 61, 67 after kills, float shadow base 60) | `start_scrap` 20 to 60 |
| `test_upgrade_system.gd` | scrap 20 set explicitly for the first-buy case; costs 10 and 12 | `c0` 10, `g` 1.108 |
| `test_policy_bot.gd` | with 20 scrap the first buy is any greedy4 row | nano step 0.6 makes `nano_repair` the bot's best ratio |
| `test_spawn_system.gd` | wave 1 has 6 skitters (was 8), boss wave normal slots 7-9 (was 9-11), alive-cap test cap 4 | `n_base` 4 |
| `test_gdd_tables.gd` | boss 8, laser/hull c0 10 g 1.108, nano 0.60, plating 0.06 c0 20 | data |
| `test_frame_data.gd`, `core/test_sim_config_foundry.gd`, `meta/test_frame_rules.gd` | BULWARK/STRIKER values; card deltas (BULWARK hull +200%, rate -20%, damage +30%; STRIKER rate +30%, damage -15%, hull -50%, range -20%; reference-follows-selection -66.7%) | final frame values |
| `core/test_run_controller_buy.gd` | scrap after a buy is below 60 | start scrap |
| `test_sim_snapshot.gd` via `snapshot_fields.gd` | the two new derived SimWorld vars are classified DERIVED | step 2 |

Not touched by me (UI-owned; they pin the old start scrap and fail, report to the owners): `tests/unit/ui/test_upgrade_panel_scene.gd` (`test_refresh_follows_scrap_and_does_not_mutate_world`, `test_row_cost_states_icon_and_maxed_plate`) and `tests/unit/ui/test_upgrade_row_model.gd` (`test_unaffordable_state_is_flagged_and_cost_is_formatted`): each assumes a `cycle_rate` row costing 25 is unaffordable at the default start scrap, which is now 60 (fix: set `world.economy.scrap` explicitly in those tests).
