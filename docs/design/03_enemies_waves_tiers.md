# 03 - Enemies, Waves, Scaling and Sectors

Changelog: 2026-11-09 (Q54 early-curve retune, SimVersion 2: `boss_hulk` hp_mult 25 to 8, `n_base` 6 to 4, start scrap 60; section 4.4 and 4.5 samples recomputed, new section 4.7 records the retune and the targets it meets) - 2026-11-07 (M1-26: section 3 and 1.1 implementation notes: scrap_yield at kill time, lancer bolt speed) - number-type note in section 4.6 updated: BigNum for currency/cost values (09 Q5 resolved); enemy HP and damage stay double.

Citations: `[CIS n]` = combat_and_in_run_systems.md. All numbers are first-pass and tunable; formulas (shape) are HARD unless said otherwise. The research found **no published enemy HP/damage formula** [CIS 5 gaps], so everything in section 4 is original design intended to reproduce the feel (exponential growth, partial skips, per-sector rewards) described in [CIS 5 inferences].

---

## 1. Enemy roster

Units: speed in m/s; `hp_mult`, `dmg_mult` multiply the base enemy values at the current enemy level (section 4); `slots` = spawn budget cost; `scrap_mult` multiplies the per-kill `scrap`; `data_base` is the type's base `data` per kill before level/sector scaling. Enemy radius in m. "First" = (sector, wave) where it can first spawn; in later sectors a type is available from wave 1.

### 1.1 Normal units
| id | Group | Role / behavior | hp_mult | dmg_mult | speed | radius | slots | scrap_mult | data_base | First | Tag |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `skitter` | normal | Basic scrapper crawler. Walks straight at Cinder, melee 1 hit/s | 1.0 | 1.0 | 3.5 | 0.6 | 1 | 1.0 | 1 | S1 w1 | MVP |
| `dart` | normal | Fast aerial drone. Rushes Cinder, melee | 0.8 | 0.8 | 7.35 | 0.5 | 1 | 1.5 | 2 | S1 w4 | MVP |
| `walker` | normal | Heavy siege walker. Slow, high HP, melee, strong hits | 5.0 | 1.5 | 2.1 | 1.4 | 3 | 3.0 | 4 | S1 w8 | MVP |
| `lancer` | normal | Ranged. Stops at attack range `max(16, 0.85 * optic_range)` capped 48 m, fires a visible magenta bolt every 2 s (dmg_mult applies to bolt) | 1.0 | 1.2 | 4.2 | 0.7 | 1 | 1.5 | 2 | S1 w6 | MVP |
| `aegis_node` | support | Shield projector. Slow; 12 m field: friendly enemies inside take -40% damage; razor ring and shock ring cannot affect enemies inside. Max 1 spawn per wave; cooldown 10 waves (9 from S4, 8 from S7, 7 from S10); max 6 alive. Weak melee | 3.0 | 0.5 | 1.4 | 1.0 | 2 | 1.5 | 3 | S1 w30 | Launch |
| `shade` | stealth | Cloaked infiltrator (drawn as a faint outline, ~15% opacity, no glow). Cannot be targeted until within `sensor_reach` (12 m base) or inside a `target_painter` zone; decloaks when it attacks | 0.9 | 1.4 | 6.3 | 0.6 | 1 | 2.0 | 3 | S1 w25 | Launch |
| `jammer` | support | EMP emitter. Hovers at 20 m; every 12 s disables one random equipped weapon system for 4 s (if none equipped: disables Overdrive for 4 s). No damage | 1.5 | 0 | 3.0 | 0.8 | 2 | 2.0 | 3 | S2 w10 | Launch |
| `mender` | support | Repair carrier. Holds at 26 m; heals up to 6 allies within 10 m for 4%/s of their max HP (bosses 1%/s) | 2.0 | 0 | 2.4 | 0.9 | 2 | 2.0 | 3 | S2 w15 | Launch |

### 1.2 Elites (share a spawn chance; immune to razor ring, shock ring, singularity pull beyond 25%, instant effects) [CIS 4 Elites]
| id | Behavior | hp_mult | dmg_mult | speed | radius | scrap_mult | data_base | First | Notes | Tag |
|---|---|---|---|---|---|---|---|---|---|---|
| `siege_lance` | Walks to 30 m, plants, charges 20 s (visible growing line), then fires a beam for 2.5 x its dmg that ignores barricade; repeats. Immune to push | 3.0 | 2.5 | 1.4 | 1.2 | 3.0 | 6 | S1 elite_step>=1 | [CIS 4 Ray] | Launch |
| `siphon` | Attaches at contact; drains 1.5% of max integrity per second; suppresses `nano_repair` and `siphon_cell` while attached; immune to push | 4.0 | 0 | 1.4 | 1.0 | 3.0 | 6 | S2 | [CIS 4 Vampire; changed: lower drain 2%->1.5%, ours also stops attached-state repair only] | Launch |
| `brood` | Splits on death: gen0 hp x3.0; each death creates 2 children for 3 generations (total 14 children): gen1 hp x1.0, gen2 hp x0.4, gen3 hp x0.15; children speed x1.3 | 3.0 | 0.8 | 2.1 | 1.0 | 3.0 | 6 | S3 | [CIS 4 Scatter] | Launch |

**Elite spawn chance (per wave, all elite types pooled):** `elite_step(w, s) = clamp(floor((w + 6*(s-1) - 50) / 40) + 1, 0, 8)`; chance by step = `[0, 0.05, 0.10, 0.20, 0.30, 0.45, 0.60, 0.80, 1.00]`. Max elites per wave: 1 for steps 1-5, 2 for steps 6-7, 3 at step 8. Elite types in the pool: S1 `siege_lance`; S2+ adds `siphon`; S3+ adds `brood`. Each kill drops one `salvage_cache` (N3). [CIS 4 elite ladder 1,4,9,...,100%; changed to a gentler ladder starting at wave 50 and 6 waves earlier per sector.]

### 1.3 Bosses ("nodes") [CIS 4 Boss]
| id | Behavior | hp_mult | dmg_mult | speed | radius | scrap_mult | data_base | Notes | Tag |
|---|---|---|---|---|---|---|---|---|---|
| `boss_hulk` | Heavy node. Melee. Loses a "plate" every 25% HP lost (plated = -30% damage taken, lasts 6 s after the plate falls). Push force x0.25 | 8 | 3.0 | 1.4 | 3.0 | 5.0 | 15 | S1 | MVP (without plates) |
| `boss_hive` | Spawner node. Stays at 30 m; every 8 s emits 6 `dart` (hp_mult x0.5 as drones; no scrap/data) | 22 | 1.0 | 1.2 | 2.6 | 5.0 | 15 | S2 | Launch |
| `boss_lance` | Artillery node. Stops at 34 m; every 3 s fires a heavy bolt (4 x dmg) with a 1 s warning ring on Cinder; immune to razor | 20 | 4.0 | 1.0 | 2.4 | 5.0 | 15 | S3 | Launch |
| `boss_null` | EMP node. Walks to 18 m; every 15 s disables all weapon systems and Overdrive for 3 s; takes x0.5 `arc` damage | 24 | 2.0 | 1.5 | 2.8 | 5.0 | 15 | S4 | Launch |
Sector boss rotation is in the sector table. Bosses are immune to push from shock ring (force x0.25 from `push`), singularity pull x0.25, dilation field x0.5, and stuns. Boss kill: 3 `salvage_cache`, 8% chance of a log fragment, 2% chance of a common `module` drop (Post-launch). Thorns (`spike_return`) apply at 50%. [CIS 4 Boss]

### 1.4 Convoy units (Post-launch, S8+) [CIS 4 Fleets; renamed, re-tuned]
Convoys are rare high-HP units that arrive with 10-15 escorts and are immune to razor, shock, push and singularity.
| id | Behavior | hp_mult | dmg_mult | speed | scrap_mult | data_base | Tag |
|---|---|---|---|---|---|---|---|
| `intruder` | Runs at Cinder; each hit disables one random equipped weapon system for the run until the intruder dies; deals no damage; blocked by barricade | 20 | 0 | 7.35 | 3 | 8 | Post-launch |
| `relay_mast` | Stays 42 m out; pulses x1.15 hp and speed to allies within 14 m (max 6 stacks, not bosses) | 20 | 0 | 0.8 | 3 | 8 | Post-launch |
| `howitzer` | Stops at 40 m; fires a returning blast shot dealing x1.4 more each time it hits; escorts: lancer + intruder | 20 | 3 | 1.0 | 3 | 8 | Post-launch |
Convoy cadence: `convoy_interval(s) = 150 - 15 * (s - 8)` waves (S8 150, S9 135, S10 120, S11 105, S12 90), first at `interval / 2`. Escorts: 10-15 drawn from {lancer, dart, skitter, walker} (separate 24-slot pool). Drops: 4 `flux` (counted once per day at most) and a module drop chance (Post-launch).

### 1.5 Counters and silhouettes
| id | Counter / design response | Vector silhouette (machine-vision vector) |
|---|---|---|
| `skitter` | Anything; push + razor; spike_return | Small isosceles triangle, 3 thin leg lines each side, red outline #FF2D4B, dark fill |
| `dart` | Higher cycle_rate, split shots, range | Thin chevron arrow with a trailing 3-line wake, magenta-red |
| `walker` | High `laser_output`, armor tear, standoff | Wide trapezoid with a thick double outline and 4 stubby legs, heavier stroke |
| `lancer` | Range, focus-fire `ranged_first` | Diamond with a long barrel line to the front; fires magenta diamonds |
| `aegis_node` | Prioritize it (shock/razor useless inside); emp_pulse disables fields 5 s | Hexagon ring with an inner dotted circle; field drawn as a thin dashed circle |
| `shade` | `sensor_reach`, `target_painter`, high cycle_rate | Dashed, nearly transparent triangle outline; ripples as it moves |
| `jammer` | Kill first; spread weapon-system reliance | Small circle with 4 radial spikes and a pulsing ring |
| `mender` | Burst it; `nanite_cloud`; split shots | Cross shape in a circle with a green-tinted thin beam to allies |
| `siege_lance` | Kill before charge completes (long range, burst); barricade does NOT block | Tripod (3 lines meeting at a triangle head), growing line while charging |
| `siphon` | Burst before attach; plating irrelevant | Crescent with hooks that latch on Cinder, drips amber arc lines |
| `brood` | Splash, mines, arc_discharge, shock ring | Octagon that visibly cracks, children are progressively smaller octagons |
| `boss_hulk` | Armor tear, burst, standoff | Large square-hex with plates drawn as separable bars |
| `boss_hive` | Kill darts via razors/shock, burst the node | Large circle with 6 port holes; spawns drift out |
| `boss_lance` | Barricade + plating; burst while it charges | Long thin rectangle with a rotating cannon line |
| `boss_null` | Keep core stats strong; arc is weak against it | Ring with a null symbol (slashed circle) in the center |
| `intruder` | Barricade absorbs; burst | Thin dart with hook; magenta |
| `relay_mast` | Range/focus first | Tall isosceles with concentric pulse rings |
| `howitzer` | Plating + heal | Wide trapezoid with an upward barrel line |

## 2. Hit points and attack of each type (formulas)

```
enemy_hp(type, l_hp)    = HP0 * G_hp(l_hp)   * hp_mult(type)       HP0 = 14
enemy_dmg(type, l_atk)  = D0  * G_atk(l_atk) * dmg_mult(type)      D0  = 2      -- damage per hit
```
`l_hp`, `l_atk` are the enemy health level and attack level (section 4). Boss/elite stats use the same formula with their multipliers. Ranged bolts use `enemy_dmg`.

## 3. Rewards per kill

```
scrap_per_kill(type, l) = max(1, round(2 * G_hp(l) ^ 0.55)) * scrap_mult(type) * scrap_yield_total
data_per_kill(type, l, s) = data_base(type) * (1 + 0.04 * l) * R(s) * data_yield_total
```
**(impl, M1)** `scrap_yield_total` is read from Cinder's stat block at the moment of the kill (a purchase affects only later kills); the stale 50% multiplier is applied last. `l` = enemy health level incl. sector offset (section 4). `R(s)` = sector reward multiplier. Stale enemies pay 50%. `scrap` follows `G_hp^0.55` so purchasing power tracks enemy toughness at a slightly lower exponent (intentional: the run is a race that the player eventually loses). [CIS 3: base cash $1 for waves 1-9 then linear steps; ours is smooth to avoid cliffs and to keep costs meaningful at all depths.]

## 4. Scaling formulas (original design)

### 4.1 Enemy level
Enemy health level and attack level start at `1 + offset(s)` and each rises by 1 per wave end unless skipped (accumulator, 02 section 9 step 6). With no skips: `l = w + offset(s)`. With skips: `l = w + offset(s) - skips_so_far`. Sector offset `offset(s) = 25 * (s - 1)`.

### 4.2 Growth curve (three phases)
```
G_hp(l):
   l <= 200:        exp(k1 * (l - 1))                           k1 = ln(1.063)  (6.3% per level)
   200 < l <= 600:  exp(k1*199 + k2 * (l - 200))                k2 = ln(1.032)  (3.2% per level)
   l > 600:         exp(k1*199 + k2*400 + k3 * (l - 600))       k3 = ln(1.022)  (2.2% per level)
G_atk(l): same shape with k1a = ln(1.058), k2a = ln(1.028), k3a = ln(1.018)
```
**Intent.**
- *Ramp (levels 1-200):* fast exponential growth. Early power spikes (Foundry, patches, milestone x1.5 jumps) have to be earned; every ~11 levels the enemy HP doubles. A new player's wave 1-12 feels fast; veterans see the run end around levels 60-200 depending on meta.
- *Siege (200-600):* growth slows to roughly 1 doubling per 22 levels so deep runs (month 1-6) remain winnable by compounding meta multipliers (milestone x1.25 per 10 Foundry levels, firmware, modules).
- *Endless (600+):* slower again (1 doubling per 32 levels) but gated by "Overrun" (4.3). Enemy attack grows slightly slower than HP in every phase so that survivability stats (integrity, plating) stay relevant without overwhelming damage stats.
A later headless simulation should tune `k1,k2,k3,k1a..k3a`, `HP0`, `D0`, N(w), cost `g` factors and Foundry growth so that the expected-wave targets in section 6 are met.

### 4.3 Overrun (anti-endless pressure) [CIS 1 Overheat since v28 analog] (Launch)
After enemy level exceeds 1500 (i.e. after 1500 - offset(s) waves), each wave end adds `overrun_stacks += 1`. Effects per stack: enemy hp growth rate +0.1% extra per level beyond the curve, enemy spawn count +0.2% (cap +100%), and skip chance reduced by 0.05 percentage points (floor 0). Intended to bound extremely long idle runs and server/device cost. Tunable; may move to level 2500 later.

### 4.4 Spawn count
`N(w) = min(200, floor(4 + 2.4 * w^0.6))` slots per wave (independent of sector). Increases with wave number, not level, so enemy density rises slowly and readability is preserved (about 103 slots at wave 500; 6 at wave 1, 13 at wave 10 (n_base 6 to 4 on 2026-11-09, Q54)).

### 4.5 Sample values (type `skitter`, hp_mult=1; Sector 1 unless noted)
Per-type values = this x type mult. Level `l = w + offset`.

| Wave | l | Enemy HP | Enemy atk/hit | Slots N(w) | Scrap/kill (base) | Data/kill (base x skitter) | Boss HP (x25) | Boss atk (x3) |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 14 | 2.0 | 6 | 2 | 1.04 | 112 | 6 |
| 10 | 10 | 24 | 3.3 | 13 | 3 | 1.40 | 194 | 10 |
| 50 | 50 | 279 | 32 | 29 | 10 | 3.0 | 2.23e3 | 95 |
| 100 | 100 | 5.93e3 | 531 | 42 | 56 | 5.0 | 4.74e4 | 1.59e3 |
| 500 | 500 | 3.39e10 | 5.91e8 | 103 | 2.90e5 | 21 | 2.71e11 | 1.77e9 |
| 1000 | 1000 | 4.77e15 | 1.17e13 | 155 | 1.97e8 | 41 | 3.82e16 | 3.51e13 |

Per-sector examples (skitter; HP / atk per hit / scrap per kill / data per kill including R(s)):
| Sector | offset | R(s) | w=1 | w=100 | w=500 |
|---|---|---|---|---|---|
| S2 | 25 | 1.60 | 64 / 8.2 / 5 / 3.3 | 2.73e4 / 2.17e3 / 129 / 9.6 | 7.45e10 / 1.18e9 / 4.5e5 / 35 |
| S4 | 75 | 4.10 | 1.37e3 / 137 / 25 / 17 | 5.79e5 / 3.64e4 / 692 / 33 | 3.60e11 / 4.69e9 / 1.06e6 / 98 |
| S6 | 125 | 10.49 | 2.90e4 / 2.3e3 / 133 / 63 | 5.86e6 / 2.98e5 / 2473 / 105 | 1.36e12 / 1.46e10 / 2.2e6 / 273 |
| S8 | 175 | 26.84 | 6.16e5 / 3.85e4 / 716 / 216 | 2.83e7 / 1.18e6 / 5880 / 322 | 4.05e12 / 3.56e10 / 4.0e6 / 752 |
| S10 | 225 | 68.72 | 6.05e6 / 3.06e5 / 2516 / 690 | 1.37e8 / 4.71e6 / 13982 / 962 | 1.20e13 / 8.70e10 / 7.3e6 / 2.06e3 |
| S12 | 275 | 175.92 | 2.92e7 / 1.22e6 / 5983 / 2.12e3 | 6.61e8 / 1.87e7 / 33248 / 2.81e3 | 3.56e13 / 2.12e11 / 1.3e7 / 5.63e3 |
(For skip-free play; actual enemy levels run lower when skips are bought.)

### 4.6 Reference implementation
```
def G(l, k1, k2, k3):
    if l <= 200: return exp(k1*(l-1))
    if l <= 600: return exp(k1*199 + k2*(l-200))
    return exp(k1*199 + k2*400 + k3*(l-600))
def N(w): return min(200, int(4 + 2.4 * w**0.6))
```
Enemy HP and damage use double precision (`G_hp(3000)` is about 1e44 times scaling, far below 1e308). Currency and cost values use the BigNum type from ROADMAP M2 (09 Q5 resolved; TECH_ARCHITECTURE section 3); display via the big-number format in 04.

**(impl, M1)** `lancer_bolt_speed` = 18 m/s (`data/sim_constants.csv`; the GDD gave no bolt speed). It is a first-pass number: a bolt crosses the 48 m maximum range in about 2.7 s. Revisit with the first playtest.

### 4.7 Early-curve retune (Q54, SimVersion 2, 2026-11-09)
Measured with `tools\balance_run.ps1` (sector 1, seeds 1-40, `greedy4`); full tables and the tuning log are in `docs/playtests/m3/balance_m3.md`. Death waves were walled by the wave-10 boss (kills 45% of the old `foundry_300` runs) and by 2-vs-3-shot kill thresholds; a laser multiplier of x1.4 to x1.8 left the old fresh median stuck at 11 and x2.5 jumped it to 21.

| Change | Old | New |
|---|---|---|
| `boss_hulk` hp_mult (1.3) | 25 | 8 |
| `n_base` (4.4) | 6 | 4 |
| `start_scrap` (02 section 7.4) | 20 | 60 |
| `laser_output`, `hull_integrity` c0 / g (02 section 7) | 15 / 1.09 | 10 / 1.108 (cheap early, same price near level 25) |
| `nano_repair` p | 0.10 | 0.60 |
| `plating_pct` step / c0 | +0.005 / 100 | +0.06 / 20 |

Results (median, mean over 40 seeds): fresh `greedy4` 9 (8.68) to 12 (11.55), target 12 +-30%; `foundry_300` 11 to 16 (+4 over fresh, target +4); `foundry_1k` 26 to 27 (27.25), roughly x2.3 of fresh (target about x2, inside the 30% tolerance of `data/targets.csv`). Early single-row purchases extend an idle run: hull +0.62, nano repair +0.57, plating +0.47 waves (mean over 40 seeds). The hp curve (`g_hp_*`, `hp0`) and the scrap formula are unchanged.

## 5. Type weights and slot filling

Weights (drawn per slot, ramping in over 10 waves from first appearance in that sector): `skitter 100`, `dart 30`, `lancer 22`, `walker 18`, `shade 12`, `jammer 8`, `mender 8`; `aegis_node` is spawned by its own cooldown rule (1.2). A drawn type that costs more slots than remaining is rejected up to 3 times, then replaced by `skitter`. Walker slots=3 and support slots=2 keep density in line with N(w).

Wave composition at sample waves (S1, rough): w1-3: 100% skitter; w10: ~60% skitter, 20% dart, 12% lancer, 8% walker; w40: ~48% skitter, 14% dart, 14% lancer, 14% walker (by weight), plus occasional shade; w100: elites per ladder.

## 6. First-pass headless estimates (rough fluid model; validates curve plausibility only)
A crude queue model (greedy buying of laser_output, cycle_rate, hull_integrity, nano_repair; enemy melee only; Foundry multipliers on damage/integrity only) gave:
| Foundry multiplier on damage and integrity | Estimated wave reached (S1) |
|---|---|
| x1 (new account) | 12 |
| x2 | 24 |
| x4 | 37 |
| x10 | 60 |
| x30 | 82 |
| x100 | 112 |
| x1000 | 162 |
This is the intended slope: each doubling of permanent power is worth 12-14 waves early and 5-6 waves late; the full systems (firmware, modules, research, weapon systems, companions) add a further ~x10-x100 by month 6. **Expected progression targets (to be validated by the real simulation):**
| Player state | Best sector and wave | Typical enemy level `l` |
|---|---|---|
| First deployment | S1 w11-13 | 12 |
| End of first session (3 runs) | S1 w20-25 | 22 |
| End of day 1 | S1 w35-45 (S2 unlocked at w30) | 40 |
| End of week 1 | S2 w45 (S3 unlocked) | 70-95 |
| End of month 1 | S4-S5, waves 40-60 | 115-165 |
| End of month 6 | S8-S9, waves 100-150 | 280-340 |
| Year 1 | S11-S12 | 350-450 |

## 7. Boss cadence [CIS 4 Boss, 5 tiers]
- A boss spawns on every wave `w` where `w % boss_interval(s) == 0` (not wave 0). `boss_interval(s)`: 10 for S1-S6, 9 for S7, 8 for S8, 7 for S9, 6 for S10, 5 for S11-S12 (condition `bc_more_bosses`). [CIS 5: 10 -> 5 by tier]
- Boss id by sector (rotation) is in 01. Boss is added to the wave's normal spawn at 60% of N(w).
- Boss spawn: fixed point at t=2 s for S1-S6; random time in 1-12 s from S7. Warning ring on spawn edge for 1.5 s.
- A boss unresolved after 3 wave-ends pays 50% (stale), and a second boss does not replace it (max 8 alive).

## 8. Sectors (difficulty tiers)

`R(s) = 1.6^(s-1)`: S1 1.00, S2 1.60, S3 2.56, S4 4.10, S5 6.55, S6 10.49, S7 16.78, S8 26.84, S9 42.95, S10 68.72, S11 109.95, S12 175.92. [CIS 5 tier coin bonus 1.0 -> 103 over 24 tiers; ours 1.0 -> 176 over 12 so each sector is a clearer step.] `R(s)` multiplies `data` earned from kills, wave data, and sector-milestone rewards, but not `scrap` or `flux`.

| s | id | Name | offset | Unlock rule | R(s) | Boss interval | Elite step 1 at wave | Battle conditions | Tag |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `s01` | Quiet Yards | 0 | Start | 1.00 | 10 | 50 | none | MVP |
| 2 | `s02` | Pylon Fields | 25 | S1 wave 30 | 1.60 | 10 | 44 | none | Launch |
| 3 | `s03` | Glasswater | 50 | S2 wave 40 | 2.56 | 10 | 38 | none | Launch |
| 4 | `s04` | Ashfall Ring | 75 | S3 wave 50 | 4.10 | 10 | 32 | `bc_armored` | Launch |
| 5 | `s05` | Hollow Gate | 100 | S4 wave 60 | 6.55 | 10 | 26 | + `bc_kinetic_hardened` | Launch |
| 6 | `s06` | Furnace Mile | 125 | S5 wave 70 | 10.49 | 10 | 20 | + `bc_arc_hardened`, `bc_lag_penalty` | Launch |
| 7 | `s07` | Static Orchard | 150 | S6 wave 80 | 16.78 | 9 | 14 | + `bc_blast_hardened`, `bc_push_resist` | Launch |
| 8 | `s08` | The Long Convoy | 175 | S7 wave 90 | 26.84 | 8 | 8 | + `bc_nano_hardened`; convoys (Post-launch) | Launch (convoys Post-launch) |
| 9 | `s09` | Salt Bridge | 200 | S8 wave 100 | 42.95 | 7 | 2 | + `bc_aegis_plus` | Launch |
| 10 | `s10` | Cradle Works | 225 | S9 wave 100 | 68.72 | 6 | 1 (immediate) | + `bc_hive_surge` | Launch |
| 11 | `s11` | Choir Hall | 250 | S10 wave 100 | 109.95 | 5 | 1 | + `bc_jam_surge` | Launch |
| 12 | `s12` | Orrery Seat | 275 | S11 wave 100 | 175.92 | 5 | 1 | all of the above, scaled | Launch |
| 13-24 | `s13`..`s24` | Deep Network | 25*(s-1) | previous wave 150 | 1.6^(s-1) capped growth review | 5 | 1 | tbd | Post-launch |

(Offsets are lower than the unlock wave on the previous sector, so a new sector's wave 1 is always easier than the player's last wave on the previous one: unlock waves 30/40/50/... exceed the +25 step. [CIS 5: 100 waves unlock, 300 from T16; ours 30 early to hit the "S2 on day 1" pacing in 04/05.])

### 8.1 Battle conditions (scaled by sector) [CIS 5 battle conditions, re-tuned]
All conditions apply to enemies; values use `s` (sector number). `+` in the table means cumulative with earlier sectors.
| id | Effect | Value |
|---|---|---|
| `bc_armored` | Normal-group enemies (not dart, support) spawn with `armor_hits` that negate hits (02 step 8d) | `2 * (s - 3)` hits: S4 2, S8 10, S12 18 [CIS 5: 10-95 at T15-T24] |
| `bc_kinetic_hardened` | Kinetic damage taken (razors, shock, spikes) | x(1 - 0.15 - 0.05*(s-5)) capped 0.60 |
| `bc_arc_hardened` | Arc damage taken | x(1 - 0.15 - 0.05*(s-6)) capped 0.60 |
| `bc_blast_hardened` | Blast damage taken (mines, missiles) | x(1 - 0.15 - 0.05*(s-7)) capped 0.60 |
| `bc_nano_hardened` | Nano damage taken | x(1 - 0.15 - 0.05*(s-8)) capped 0.60 |
| `bc_lag_penalty` | Reduces `signal_lag_*` effectiveness | -0.025 * (s - 5) absolute (S6 -2.5% to S12 -17.5%) |
| `bc_push_resist` | Reduces push force | x(1 - 0.10*(s-6)) floor x0.35 |
| `bc_aegis_plus` | `aegis_node` field radius +4 m and cooldown -2 waves | fixed |
| `bc_hive_surge` | `brood` gets 1 extra generation | fixed |
| `bc_jam_surge` | `jammer` EMP every 8 s and affects 2 systems | fixed |
`bc_more_bosses` is represented by the boss interval column. Laser is never hardened by sector (it is the baseline weapon); laser pressure comes only from adaptation (02 section 8.1). Gauntlets reuse these conditions with their own overrides (06).

## 9. Wave Info (Intel tab) contents (spec)
Fields: wave, sector, enemy levels (hp/atk), per-type spawn weight %, per-type hp/atk/speed/mass at this level, N(w), wave timer, lull, elite step and chance, next boss wave, next draft wave, adaptation % per type, active battle conditions, stale count, active/spawn counts. [CIS 5 Wave Info]

## 10. Tags summary
MVP: skitter, dart, walker, lancer, boss_hulk (no plates), sector S1, N(w), G(l) phases 1-2. Launch: aegis_node, shade, jammer, mender, three elites, three more bosses, S2-S12, conditions, adaptation, overrun. Post-launch: convoys, S13-S24.
