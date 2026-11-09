# M3 balance measurements (M3-08 Foundry, M3-24 frames)

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
