# Foundry early-power study (FO-2)

Date: 2026-11-09. Branch `m4-foundry-balance`, based on `main` dce40fb (SimVersion as of M4-15). Tool: `tools/journey_run.ps1` (documented in `docs/setup/balance_run.md`, section "Journey simulator"). Nothing in `data/*.csv`, `src/` or the GDD was changed; every option below is a measurement of an in-memory override or of a temporarily edited constant (list in section 9). **The numbers in section 7 are a PROPOSAL; the user chooses.**

## 1. Question

User playtest: "Data accumulates pretty fast, so a user can stack Foundry benefits quite early. Find a balance where the Foundry cannot be used too early to gain a significant advantage."

## 2. Inputs (balance-check rule: FOUND / ABSENT)

| Input | Status |
|---|---|
| `data/foundry.csv`, `run_upgrades.csv`, `sim_constants.csv`, `targets.csv`, `wave_modes.csv`, `frames.csv`, `enemies.csv` | FOUND |
| GDD 04 s2.2, s3, s7; 05 s1, s7, s8; 03 s3, s6; 02 s5-7; 11 s1.2 | FOUND |
| Targets used: first run ~190 Data, first session (3 runs) ~800 Data and best S1 w20-25, "+4 waves per ~300 Data", Day 1 (about 35 min of 2x play) ~6e3 Data and best w35-45 | FOUND (04 s3, 05 s8, 03 s6) |
| `tools/balance_run.gd` sim harness, `PolicyBot` greedy4, profiles `tests/profiles/foundry_300.json`, `foundry_1k.json` | FOUND |
| In-game RECOMMENDED glow (`FoundryRules.recommended`, used through `FoundryService.rows`) | FOUND (mirrored exactly, the tool calls the same code) |
| `data_per_wave` | ABSENT in the sim (an unimplemented hook; Data is only awarded per kill). Not measured. Per-wave Data would be a proposal, not a measurement |
| Standby Patrol, missions (Ops Board), Lab (`lab_foundry_discount`), sector milestone rewards, Data caches | ABSENT in the sim. Real Day-1 Data is higher than simulated by these sources, so the measured pace is an underestimate of a real player's Foundry budget |
| Week-1 / month-1 targets (S2-S5, 3e5 / 2e7 Data) | NOT ASSESSED - NO DATA: the sim plays sector 1 only (no sector change, no `R(s)` growth). The longest journey (16 deployments, 140-218 game minutes at 2x, about 4-6 days at 35 min/day) is the furthest the sim reaches |
| Real player behaviour (spend timing, 2x vs 1x, which rows) | ABSENT: bots only; policies below bracket plausible behaviour |

## 3. Method

- **Journey**: fresh profile, 16 consecutive deployments (seed = 1, 2, ..., 16, sector 1, TIMED, VANGUARD unless stated, wave cap 120, `PolicyBot` **greedy4** inside every deployment, first patch offer taken). After each death the run is banked through the real `PlayerProfile.bank_run` (all Data, also on death), then all banked Data is spent by the Foundry policy through the real `FoundryService` (costs, caps) one level at a time; if the policy's pick is not affordable it saves. Game minutes at 1x are `ticks / 30 / 60`; 2x is half.
- **Policies**: `cheapest` (cheapest next level), `laser` (all-in `laser_output`; spills into the cheapest other row only when a level cap blocks it), `recommended` (the RECOMMENDED glow rule: a Type D row within 3 levels of its x1.25 milestone, else the cheapest affordable; waits when the glowing row is not affordable), `roundrobin`, and `none` (control, never spends).
- **Probe**: fixed Data spent from a fresh profile, then 20 seeds (1-20) with and without those levels, greedy4, best wave 0 (the same setup as `balance_run -Profile foundry_300`; cross-checked, section 4.3).
- **Marks**: "after 3" = first session (3 runs); "35 min 2x" = first deployment that ends after 35 minutes of 2x play (GDD Day 1); "w45" = the deployment that first reaches best wave 45 (top of the Day-1 band) and the 2x minute it ended.
- **Determinism**: the same seeds give byte-identical lines; `-SelfCheck` (18 checks: argument parsing, override application and isolation, spend accounting equals level costs, cap, glow mirror, determinism, deployment 1 equals the `balance_run` setup, Data banked in full, probe) passes.
- **Commands** (all from the repo root, one Godot process at a time; outputs in `build/journey/<name>.csv`):

```
.\tools\journey_run.ps1 -SelfCheck
.\tools\journey_run.ps1 -Spend <none|cheapest|laser|recommended|roundrobin> -Deployments 16 -Seed 1 -Name base_<policy>
.\tools\journey_run.ps1 -Spend laser|recommended -Deployments 16 -Seed 101            # second seed set
.\tools\journey_run.ps1 -Spend laser|recommended -Deployments 16 -Frame bulwark|striker
.\tools\journey_run.ps1 -Spend laser -Deployments 16 -Mode purge
.\tools\journey_run.ps1 -Probe 300|800 -Spend <policy> -Runs 20
.\tools\journey_run.ps1 -ProfileFile tests/profiles/foundry_300.json|foundry_1k.json -Frames -Runs 20
Option A1: -Set sim.data_level_coef=0.02            Option A2: -Set enemies.data_scale=0.5
Option B1: -Set foundry.laser_output.fc0=40,foundry.hull_integrity.fc0=40,foundry.nano_repair.fc0=50,foundry.cycle_rate.fc0=100
Option B2: -Set foundry.laser_output.fg=1.14,foundry.hull_integrity.fg=1.14,foundry.nano_repair.fg=1.14,foundry.cycle_rate.fg=1.16
Option C : -CapK 0.5|0.6|0.65|0.75 [-CapMin 3|8]
Option D : constants edited temporarily (section 9), then the same journey/probe/profile commands
```

## 4. Baseline findings (real constants, seed 1, 16 deployments)

### 4.1 Journeys by Foundry policy

| Policy | Best after 3 runs (cum Data, 2x min) | First x1.25 (deployment, 2x min, best then) | Reaches w45 (deployment, 2x min, cum Data) | At the first deployment ending after 35 min 2x: best wave / cum Data (2x min) | After 16 runs: best wave (2x min) |
|---|---|---|---|---|---|
| none (control) | w12 (497, 6.7) | never | never | w13 / 2.6e3 (36.0) | w13 (36.0) |
| cheapest | w15 (640, 7.6) | 4, 11.1, w18 | 7, 34.2, 6.6e3 | **w57** / 1.06e4 (45.6) | w89 (164.9) |
| laser | **w24** (1073, 9.8) | 2, 5.0, w15 | 5, 26.2, 5.2e3 | **w62** / 1.01e4 (38.4) | w75 (176.5) |
| recommended | w15 (640, 7.6) | 3, 7.6, w15 | 7, 36.3, 7.5e3 | **w60** / 7.5e3 (36.3) | w89 (170.6) |
| roundrobin | w15 (592, 7.3) | 6, 19.5, w24 | 9, 44.6, 8.4e3 | **w55** / 8.4e3 (44.6) | w84 (140.8) |
| GDD target | w20-25, ~800 Data | - | - | w35-45, ~6e3 Data | - |

Second seed set (seeds 101-116): laser w23 after 3 runs (947 Data), w45 at 22.1 min, w65 at 45.5 min; recommended w16 (596 Data), w45 at 36.4 min, w49 at 36.4 min.

Per-deployment Data (laser, seed 1): 169, 271, 633, 1017, 3129, 4888, ... ; recommended: 169, 235, 236, 606, 913, 1362, 3977, 4167, 6011. The first run pays 169 Data against the GDD ~190 (-11%).

### 4.2 Where the Foundry runs ahead of the GDD pace, and by how much

- **First session (3 runs): not ahead for ordinary play.** Best wave after 3 runs is w15 for cheapest/recommended/roundrobin (GDD w20-25, 5 waves short) and cumulative Data 592-640 (GDD ~800, -20 to -26%). Only the all-in `laser` player is at the top of the band (w24, 1073 Data, +34% on Data; BULWARK all-in laser reaches w33 after 3 runs, STRIKER w27).
- **Straight after the first session it takes off.** Each policy has a step: best wave jumps by 20-26 waves in one deployment (cheapest w33 to w55, recommended w34 to w60, laser w31 to w52) (the cause was not isolated; it follows the second to fourth x1.25 milestone and the run-upgrade race it feeds). That deployment ends 25-35 minutes into 2x play.
- **Day 1 (35 min at 2x): +10 to +17 waves above the top of the GDD band** (w55-62 against 35-45; +22% to +38% over w45, +40 to +55% over the band midpoint), Data 7.5e3 to 1.06e4 against ~6e3 (+25% to +75%, and the sim has no missions or Standby Patrol, so a real player has more). The w45 mark is reached at 26 min (laser), 34 (cheapest), 36 (recommended) and 45 (roundrobin): all-in laser is ~9 minutes ahead of the 35-minute budget, the rest is on it.
- **Beyond Day 1** all policies reach w75-89 after 16 runs (140-176 min of 2x play, about 4-5 days); the GDD does not give a week-1 S1 wave (W1 is "best S2 w45"), so this is NOT ASSESSED against a target.
- **Control**: without any Foundry spending the same 16 runs end at w13 after 36 minutes of 2x play. The whole Day-1 progress comes from the Foundry (and the run-upgrade race it feeds).
- **Exploit vs. ordinary play**: `laser` all-in is the strongest first-session play (w24 after 3 runs, +34% Data) but the other three policies catch up by Day 1 and end higher after 16 runs (laser flattens at w75 because it never buys hull, cycle or repair). The user's observation ("stack benefits early") is true mostly of single-stat stacking in the first 10-25 minutes and of everybody after the first session.

### 4.3 Waves per 300 Data (probe, 20 seeds, best wave 0)

| Spend | policy / levels | Fresh p50 (mean) | With Foundry p50 (mean) | Gain (mean) | Per 300 Data | vs design +4 per 300 |
|---|---|---|---|---|---|---|
| ~300 | laser, L9 (275 Data) | 12 (11.8) | 18 (17.9) | +6.05 | +6.6 | 1.65x |
| ~300 | cheapest/recommended, L5 H4 N2 (271) | 12 (11.8) | 14 (14.5) | +2.65 | +2.9 | 0.7x |
| ~300 | roundrobin, L3 C2 H2 N2 (269) | 12 (11.8) | 14 (14.3) | +2.45 | +2.7 | 0.7x |
| profile | `foundry_300` L5 H4 C2 (325) | 12 | 16 | +4.15 | +3.8 | on design (balance_run target 16 PASS) |
| ~800 | laser, L16 (726) | 12 | **31 (31.0)** | +19.2 | +7.9 | **1.8x** (design +10.7) |
| ~800 | recommended, L10 H10 N4 (764) | 12 | 27 (26.4) | +14.6 | +5.7 | 1.4x |
| ~800 | cheapest, L9 H9 N7 (791) | 12 | 18 (18.4) | +6.55 | +2.5 | 0.6x |
| ~800 | roundrobin, L6 C5 H5 N5 (756) | 12 | 19 (18.8) | +7.0 | +2.8 | 0.6x |
| profile | `foundry_1k` L12 H10 C4 (997) | 12 | 30 (30.1) | +18.3 | +5.5 | target 24 +-30%: PASS (30 = +25%) |

So the design rate "+4 per 300" holds for a spread-out ~300 spend, but a concentrated spend of ~800 Data (the whole first session) gives +19 waves (w31) instead of the +11 the design implies, because the single row crosses its first x1.25 milestone at F10 (319 Data cumulative, with the second at F20 for 1.9e3 more). **The concentration plus the early milestone is what is "too early".**

`balance_run` cross-check (this tree): fresh p50 12 (target 12), `foundry_300` 16 (target 16), `foundry_1k` 30 (target 24, +25%, PASS within 30%; the probe reproduces these exactly).

### 4.4 When the first x1.25 milestone (F10 on a Type D row) is reached

Laser all-in: after 2 runs (5.0 min of 2x play, 440 Data banked, best w15). Recommended: after 3 runs (7.6 min, 640 Data). Cheapest: after 4 runs (11.1 min). Roundrobin: after 6 runs (19.5 min, 2.1e3 Data). The second (F20) follows 1.9e3 Data later (laser: run 4, 15.9 min). In all cases the first milestone is in the first session or right after it, i.e. well inside the first 20 minutes.

### 4.5 Frames and PURGE

- Start stats are unchanged by Foundry spending (frame multipliers apply last): with the `foundry_1k` levels fire rate (cycle) is VANGUARD 1.16, BULWARK 0.93, STRIKER 1.51 shots/s (ratios 1.0 : 0.80 : 1.30 exactly as in `frames.csv`), hull 200 / 600 / 100, plating 0 / 0.10 / 0. STRIKER fires ~63% faster than BULWARK and BULWARK keeps 6x STRIKER's hull; greedy4 does not buy plating, so BULWARK's armor edge is the flat 0.10.
- Journeys (frame played from its unlock wave: BULWARK 8, STRIKER 15), seed 1, laser: BULWARK w33 after 3 runs, w64 at 35.6 min; STRIKER w27 after 3 runs, w62 at 40 min. Recommended: BULWARK w23 after 3 runs, w59 at 35.4 min, w100 after 16 runs; STRIKER w15 after 3 runs (VANGUARD until w15), w69 at 43.6 min, w99 after 16. The frames run ahead of VANGUARD by the same mechanism, slightly more, so the early-power problem is not frame-specific.
- PURGE (info only, laser): w29 after 3 runs (1902 Data, 16.5 min 2x because PURGE waves are longer), w60 at 42.5 min, w79 after 16.

## 5. Options (same seeds 1-16, journey tables in `build/journey/*.csv`)

"Typical" = recommended policy, "stacker" = laser all-in. Columns: best wave after 3 runs / minutes of 2x play to w45 / best wave at the first deployment ending after 35 min / best after 16 runs.

| Option | Typical (rec) | Stacker (laser) | Verdict against the targets |
|---|---|---|---|
| **Baseline** | w15 / 36 min / **w60** / w89 | w24 / 26 / **w62** / w75 | Day 1 +15..+17 waves over the band; first session short for typical play |
| **A1** `sim.data_level_coef` 0.04 to 0.02 | not run | w24 / 26 / w62 / w75; cum Data -28% | no pace effect: income -28% costs about 3 Foundry levels (cost is exponential) |
| **A2** all enemy `data_base` x0.5 | w12 / 49 / **w34** / w69 | w14 / 34 / w54 / w72 | typical player hits the Day-1 band, but the first session is dead (w12 after 3 runs = no progress, 262 Data vs 800); stacker still w54 |
| **B1** all `fc0` x2 (laser/hull 40, nano 50, cycle 100) | w12 / 49 / w34 / w69 (identical to A2) | w14 / 34 / w54 / w72 | same as A2: halving income equals doubling costs; invisible to the player |
| **B2** `fg` +0.04 (1.14, cycle 1.16) | not run | w24 / 24 / w54 / w72 | first session unchanged (cost curves only bite above F15), Day 1 -8 waves for the stacker, late game -3 |
| **C** cap F <= max(3, floor(k x best wave)), k 0.5 / 0.6 / 0.65 / 0.75 (laser spills into other rows) | k 0.6: nearly unchanged (w15 / 34 / w57 / w89): rarely binds | k 0.5: w15 / 29 / w55 / w84; **k 0.6**: w16 / 36 / w60 / w92; k 0.65: w16 / 30 / w68 / w96; k 0.75: w24 / 26 / w62 / w91 | binds only single-stat stacking, and only until the player spreads (late game is then **higher**: w92 vs w75); Day 1 barely moves (w55-68) because the spread stack is itself strong; without the spill the stacker stalls (k 0.5: w18 for 12 runs, w30 after 16; D4 + k 0.6: w21 for 12 runs) |
| **D1** x1.25 every **25** levels (was 10) | w15 / 57 / **w35** / w69 | w19 / 28 / w54 / w68 | typical = inside the Day-1 band; late game -22% (w69 vs 89): gives up the long-run curve |
| **D2** x1.15 every 10 | w15 / 33 / w53 / w84 | w22 / 33 / w62 / w72 | too mild |
| **D3** x1.5 every 25 | w15 / 58 / **w35** / w73 | w19 / 30 / w62 / w72 | like D1, late game -18% |
| **D4** x1.75 every 25 (same long-run curve as the GDD: 1.25^2.5 = 1.75) | w15 / 60 / **w35** / w83 | w19 / 30 / **w64** / w75 | typical = inside the band, late game within 7%, stacker unchanged at Day 1 |
| **E = D4 + C(k 0.6)** | w15 / 55 / **w35** / w76 | w16 / 56 / **w35** / w84 | both play styles inside the Day-1 band; first session w15-16 (short of 20-25) |

Second seed set (101-116) for the key rows: baseline laser w23 / 22 min / w65 / w75, baseline rec w16 / 36 / w49 / w87; D4 laser w18 / 32 / w58 / w75, D4 rec w16 / 53 / **w35** / w76; E laser (k 0.6) w16 / 53 / **w35** / w75. Same picture.

D4 on the other two policies (seed 1): cheapest w15 / 56 / w35 / w83 (baseline w89), roundrobin w15 / 57 / w35 / w82 (baseline w84).

### 5.1 Fixed-spend and profile effects (balance_run targets, TIMED, VANGUARD, 20 seeds)

| | fresh p50 | `foundry_300` p50 (target 16) | `foundry_1k` p50 (target 24) | 800-Data laser | 800-Data recommended |
|---|---|---|---|---|---|
| Baseline | 12 | 16 PASS | 30 PASS (+25%) | w31 | w27 |
| A, B, C | 12 | 16 PASS | 30 PASS | A and C do not change what fixed levels are worth; B1 doubles the price of the same levels (`foundry_300` 325 to 650 Data) so an 800-Data stack buys about half the levels (not run as a probe) | A, C: unchanged |
| D1 / D3 / D4 (identical below F25) | 12 | 16 PASS | **24 PASS (on target)** | w25 (inside w20-25) | w18 (short) |
| D2 (x1.15 per 10) | 12 | 16 PASS | 28 PASS | w29 | w25 |

Under D1/D3/D4 `foundry_1k` falls from 30 to exactly the 24 the targets file expects, and the 800-Data stack falls from +19 to +13 waves (design +10.7). The "waves per 300" figures for concentrated spends become 5.6 (laser) instead of 7.9.

### 5.2 Frame identity check

Frame multipliers are applied after the Foundry, so fire-rate and hull ratios between frames are unchanged by every option (A, B, C, D: only Foundry cost, income, caps or the Foundry multiplier change, never `cycle_mult`/`hull_mult`/`plating_add`). Measured with `foundry_1k` (20 seeds, `-Frames`): fire rate 1.16 / 0.93 / 1.51 (VANGUARD / BULWARK / STRIKER) in the baseline and under every D variant (ratios 1 : 0.80 : 1.30), hull 200 / 600 / 100 in the baseline and 160 / 480 / 80 under D1-D4 (same 1 : 3 : 0.5 ratios; the F10 bump is gone), plating 0 / 0.10 / 0. Under D4 the frame journeys keep their relationship (recommended, seed 1: best after 3 runs VANGUARD w15, BULWARK w22, STRIKER w15 until its w15 unlock; first deployment after 35 min: VANGUARD w35, BULWARK w54, STRIKER w59). The balance_run tables for the frames with `foundry_1k` under D4: BULWARK p50 28, STRIKER 28, VANGUARD 24, all within the same band as before (baseline 36 / 34 / 30). **HARD rule holds in every option** (STRIKER clearly faster fire with 50% hull; BULWARK clearly slower fire with 3x hull and flat plating).

## 6. Findings that shape the choice

1. Income and cost knobs (A, B) are weak and blunt: both act through a 1.10^F cost curve, so -50% income or +100% cost removes only about 7 levels, and what they remove first is the first session (w12 after 3 runs) because the early levels are cheap and each one is a large relative gain. They are invisible to the player and slow the new player more than the stacker. A1 (-28% Data) has no measurable pace effect.
2. The early pace comes from stacking the first x1.25 milestones and from concentration. The two levers that address that directly are D (reshape the milestone) and C (limit concentration).
3. A level cap (C) is explicit and visible but needs new code, UI and a rule for sector 2+; with k too low it is a progression trap (the stacker stalls at w18-21 for 12 runs because best wave raises the cap and the cap limits best wave). From k 0.6 up with the Data spilling into other rows it only changes behaviour of single-stat stackers.
4. D4 is the same long-run curve as the GDD table (at F25/50/100/200 the multiplier is 4.4 / 12.3 / 65.7 / 1143 against 3.9 / 12.2 / 65 / 1128) with the early staircase (x1.25 at F10, again at F20) removed. That is why late pace is within 7% while Day 1 for ordinary play drops from w60 to w35. D1 and D3 also fix Day 1 but cost 18-22% of late pace.
5. D4 alone does not stop the single-stat stacker (laser w64 at 38 min), because that player simply keeps buying laser levels. D4 + C(0.6) does (w35, both styles).
6. The sim is not smooth: every policy has a step of +20 to +26 waves in one deployment around 25-35 minutes. Option effects therefore show up as a delay of that step by 1-4 deployments, which makes "best wave at 35 min" a coarse metric (it can change by 20 waves when the step moves by one run). Use "minutes to w45" next to it.

## 7. Recommendation (PROPOSAL, nothing applied)

**Recommended: E = D4 + C(k 0.6).** If the user wants the smallest change, **D4 alone** (it fixes the typical player and keeps the long-run curve; the single-stat stacker keeps w64 at 38 min).

Exact proposed changes:

1. **Foundry milestone (D4)** - `src/sim/math/curves.gd`: `MILESTONE_FOUNDRY_STEP` 10 to 25, `MILESTONE_FOUNDRY_MULT` 1.25 to 1.75; `src/meta/foundry/foundry_rules.gd`: `MILESTONE_STEP` 10 to 25 (and `NEAR_MILESTONE` may stay 3). Foundry stat resolution changes, so **SimVersion bump**; adjust `test_curves`/`test_gdd_tables`/foundry tests and the milestone label (`foundry.milestone` shows `F10` today, it will show F25/F50/...). GDD 05 s1.2: `foundry_mult(F) = (1 + f*F) * 1.75 ^ floor(F / 25)`, table at F=25/50/100/200: 4.4 / 12.3 / 65.7 / 1,143 (was 3.9 / 12.2 / 65 / 1,128); s1.4 "Recommended glow ... every 10 levels = x1.25" to "every 25 levels = x1.75"; GDD 02 s5 / 08 s1.3 mention if any. Type C rows are unaffected.
2. **Level cap (C)** - new rule: a Foundry row's maximum level is `max(3, floor(0.6 * best_wave_s1))` (and never above the row cap). Needs code in `FoundryRules.level_cap`/`FoundryService` (the cap is a function of the profile), a visible "next level at wave N" hint on a capped row (reuse the locked-row style of the run panel), and an open question for sectors 2+ (use best wave of the highest sector scaled by `sector_offset_step`, or total best level). GDD 05 s1.1 gets the rule and 05 s7/08 s1.3 a note. Because it binds only above 60% of the best wave, the typical player rarely sees it (k 0.6 moved the recommended w45 mark from 36 to 34 minutes) and the single-stat stacker meets it in the first session.
3. **No change** to `data/foundry.csv` (`fc0`, `fg`, `f`), `sim_constants.csv` (`data_level_coef`), `enemies.csv` (`data_base`) or `targets.csv`. `foundry_1k` then measures 24 (target 24) instead of 30.
4. Optional, not measured: raise the first-session level of the typical player (w15-16 after 3 runs against the GDD w20-25) by letting the first Foundry row cost less or the first-run Data be ~190 instead of 169; the first-session shortfall exists in the baseline already (typical play is w15) and is not caused by the proposal (D4 leaves it unchanged for ordinary play).

Expected result, seeds 1-16 and 101-116: both policies w35 at the first deployment ending after 35 min of 2x play (GDD w35-45), w45 reached after 53-56 min, w75-84 after 16 runs (baseline 75-89), `foundry_300` 16, `foundry_1k` 24.

Why not the others: A and B are invisible and kill the first session before they touch the stacker (A2/B1: w12 after 3 runs, 262 Data against 800); B2 moves only the stacker by 8 waves; C alone (any k) leaves the typical player at the baseline w60 on Day 1 and is a trap below k 0.6; D1/D3 cost 18-22% of the late game; D2 is too mild.

## 8. Limits of this study

- Bots, not players: greedy4 inside a run, five fixed Foundry policies. Real players use 2x speed, buy other rows (crit, optic, plating unlock at best wave 3-10; `all` equals greedy4 at low best waves per the M2 report), play 1x at times and take real patch choices (the bot takes the first offer).
- No Standby Patrol, missions, sector rewards, Lab, caches or ads: real Data in Day 1 is higher, so real Foundry power is higher than shown.
- Sector 1 only: week-1 and month-1 targets are NOT ASSESSED. D4 keeps the long curve by construction (same multiplier at multiples of 25), which is not a measurement of month 1.
- The step in every journey (section 6, item 6) makes single-run "best wave at 35 min" noisy; two seed sets agree on the ordering, not on the exact wave.
- 20-seed probes have a standard error of about 0.5-1 wave on the mean; journeys are single trajectories per seed set.
- Option C was prototyped in the journey tool only (cap enforced at spending time through the service's row caps); the real rule would be enforced in the profile/Foundry code and may interact with Standby Patrol (a capped Foundry makes Data accumulate unspent).
- `data_per_wave` is not a lever in this build.

## 9. What was measured with edited code

Everything except Option D used the repository constants and in-memory `-Set` overrides. Option D (D1-D4 and E) was measured with `Curves.MILESTONE_FOUNDRY_STEP` / `MILESTONE_FOUNDRY_MULT` and `FoundryRules.MILESTONE_STEP` edited in the working tree (D1: 25 / 1.25; D2: 10 / 1.15; D3: 25 / 1.5; D4 and E: 25 / 1.75), and reverted with `git checkout -- src/sim/math/curves.gd src/meta/foundry/foundry_rules.gd` after each batch. The committed tree has no change under `src/` or `data/` (the only tool-side effect is the new `tools/` code, which reads sim and meta code without changing it). Baseline, A, B and C runs were done before the first constant edit with the real constants; the final `balance_run` cross-check (section 4.3) was run on the reverted tree.
