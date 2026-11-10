# 02 - Combat and In-Run Systems

Changelog: 2026-11-10 (R1-03: game speed 1x/2x/4x/8x; 4x unlocks at best TIMED wave 30 and 8x at 60 instead of the Lab `game_speed` levels; above 2x the speed falls back to 2x while the hull is under 75% or a boss is alive (returns at 80%); s14 rewritten). Earlier: 2026-11-09 (Q54 early-curve retune, SimVersion 2: start scrap 60, laser_output and hull_integrity c0 10 / g 1.108, nano_repair p 0.60, plating_pct +0.06 per level at c0 20; see 03 section 4.7) - 2026-11-08 (M2-16: section 7.5 buying and recording rules, section 14 speed note) - 2026-11-07 (M1-26: section 6 implementation notes: flank probability, spawn carry-over, `next_wave_is_boss`, `damage_dealt`, integer `CINDER_HIT`) - novel mechanics N1-N4 approved at their scope tags; N5 deferred to post-launch (section 13). Wave timing, speed cap and caps here are the source of truth for TECH_ARCHITECTURE (720-tick wave at 30 Hz).

All numbers are first-pass and **tunable** unless marked HARD (a rule, not a balance number). Borrowed mechanics are cited to the research notes: `[CIS n]` = combat_and_in_run_systems.md section n. "Changed" notes say what we altered and why.

---

## 1. The run loop (deployment)

1. **Start.** Player taps DEPLOY on the Home screen. Cinder spawns at arena center (0,0). Starting `scrap` = 20 (+Lab `start_scrap`). All run levels reset to 0. Sector, equipped firmware, weapon systems and companions are fixed for the run.
2. **Wave cycle (1x speed).** Each wave = 18 s spawn phase + 6 s lull = 24 s. HARD: the next wave starts when the 24 s timer ends, whether or not enemies remain. Lull halves in Gauntlets (3 s). [CIS 1: 26+9 s; changed to 18+6 because shorter waves cut dead time, a cited complaint in [GENRE A1].]
3. **Combat.** Cinder auto-fires the laser at the nearest enemy in range. Enemies spawn on a ring (radius 52 m, off-screen), walk toward Cinder, and attack at melee contact (2.0 m) or at their own attack range. Kills pay `scrap` instantly and bank `data` into the run total.
4. **Spend.** The player taps upgrade rows in the bottom panel (Arms / Chassis / Systems tabs), spending `scrap` for temporary levels. Unspent scrap earns interest (`reinvest`).
5. **End of wave.** Resolved in the exact order of section 9.
6. **Drafts.** At scheduled waves the game pauses (auto-picks in 12 s of real time if idle and "auto-pick" is on) and shows 3 patches (section 10).
7. **Death.** When integrity reaches 0 and the death-prevention chain (section 11) is exhausted, the run ends. The results screen shows waves, time, kills, `data` banked, best-wave delta, cause of death. `data` earned this run is banked in full (no loss on death). `scrap` is lost.
8. **Between runs.** Spend `data` in Foundry/Lab/Arsenal, then redeploy. Target time from death to redeploy: under 10 s for a returning player.

Typical run length target at 1x (no fast-forward): 2-4 min (first runs, waves 8-15), 8-12 min (day 7, waves 40-70), 15-25 min (month 1+, waves 100+, normally played at 2x).

## 2. Arena, units, ranges
- Arena is a circle, radius 52 m (spawn ring). Camera shows about 38 m horizontally (portrait). Distances in meters from Cinder center.
- Cinder hit radius 2.0 m. Melee enemies stop at 2.0 m. Enemies are circles with radius 0.6-1.8 m depending on type (see 03).
- Maximum alive on screen (HARD, performance and readability): 160 normal, 6 of each elite type (+20 brood splits), 8 bosses, 8 of each convoy type plus 24 escorts. [CIS 1: 120/8/10 caps; raised normal cap because beams, not projectiles, are our main damage.]
- Projectile readability: the laser is **hitscan** (instant). Rendering draws a short-lived beam line (80 ms fade). This keeps "thousands of shots" cheap and readable. Only missiles (micro_missiles), mines and enemy fire exist as moving entities.

## 3. Targeting rules (HARD)
Eligible targets: alive, revealed (not cloaked), within `optic_range` of Cinder center.
- **Default mode `nearest`:** choose the eligible enemy with the smallest distance to Cinder; tie-break lowest spawn id. Re-evaluated on every shot (no target lock). [CIS 1]
- **Lab `threat_sort` (Launch)** unlocks target priority modes: `nearest`, `ranged_first` (lancer, howitzer, relay_mast first), `elite_first`, `lowest_hp`. Within a priority group use nearest. [CIS 1 Target Priority; changed from "one type" to 4 simple modes for clarity.]
- **Split shots** (`split_chance`) choose the next nearest eligible enemies, distinct from the primary and each other.
- **Ricochet** jumps to the nearest eligible enemy within 6 m of the last hit not already hit by this shot.
- Cloaked enemies (`shade`) become eligible when within `sensor_reach` (base 12 m) or inside a `target_painter` zone.
- Enemies inside an `aegis_node` field remain targetable but take reduced damage.

## 4. The starting laser ("Laser Cycle")
Cinder begins with only this attack:
- Hitscan beam, damage type `laser`, base damage 10 per shot (`laser_output` base), 1.00 shots/s (`cycle_rate` base), range 24 m (`optic_range` base), no crit (`crit_chance` base 2%, `crit_mult` base x1.5 unlock later).
- The beam is a single thin line from the active emitter node to the target with a short glow. Hit flash on target.
- Tutorial intent: wave 1 skitters have 14 HP so each dies in 2 shots, which is visible and satisfying; the first upgrade (`laser_output` level 1 = 11 dmg, cost 15 `scrap`) is affordable immediately from the 20 starting `scrap`; the tutorial prompts it.

## 5. Stat resolution (how every stat is computed) (HARD)

Each stat has up to three inputs: Foundry level `F` (permanent, see 05), run level `L` (this deployment, section 7), and external multipliers `M` (firmware, lab, modules, companions, patches, weapon systems, sector conditions).

Two stat types:

**Type D (deep, multiplicative)** - `laser_output`, `hull_integrity`, `nano_repair`, `plating_flat`:
```
run_factor(L)     = (1 + p * L) * 1.5 ^ floor(L / 25)            -- p given per stat, L <= 400
foundry_mult(F)   = (1 + f * F) * 1.25 ^ floor(F / 10)           -- f given per stat in 05, F <= 200
final = base * run_factor(L) * foundry_mult(F) * PRODUCT(M)
```
The `1.5^floor(L/25)` "overclock milestone" gives a visible jump every 25 levels (UI flashes a gold ring on the row). [Original twist; research shows linear per-level increments [CIS 2].]

**Type C (capped linear)** - everything else:
```
final = clamp( base + r_inc * min(L, L_cap) + f_inc * min(F, F_cap), hard_floor, hard_cap ) then * PRODUCT(M) where the stat is a multiplier-type, else + SUM(additive bonuses)
```
Chance stats are additive across sources and clamped at their `hard_cap`. Multiplier-type stats (marked "mult" in tables) multiply by external multipliers.

**Cost of the next run level** (HARD formula): `cost(L -> L+1) = ceil(c0 * g^L)` in `scrap`. Buy-x10/x100/Max sum sequential costs, no discount. Buy-multiplier x1/x10/x100/Max is free from the start (not a lab, unlike [CIS 2]; changed to remove friction).

## 6. Wave timing and spawn rules (HARD)
- `T_wave = 24 s` (game seconds). Spawn phase `0 <= t < 18`; lull `18 <= t < 24`.
- Spawn count (slots) `N(w) = min(200, floor(6 + 2.4 * w^0.6))`. Sample: w1=8, w10=15, w50=31, w100=44, w500=105, w1000=157.
- Each enemy type costs `slots` (03). Fill N slots by drawing from the available type weights (03 section 5) until slots are used. Slot overflow of at most 2 is allowed.
- Spawn times: for slot index i (0-based) `t_i = 18 * (i + u_i) / N`, `u_i` uniform [0,1) seeded.
- Spawn angle: 60% uniform random; 40% in "flank groups" of 3-6 enemies within +-10 degrees to make clumps readable.
- **(impl, M1)** Flank groups: a slot starts a flank group with probability `p = f / (f + (1 - f) * mean_group)` (`f` = `flank_fraction` 0.4, `mean_group` = (3+6)/2) so that about 40% of enemies, not 40% of groups, end up in groups.
- **(impl, M1)** Spawn carry-over: entries held back by the alive caps at the end of a wave are carried into the next wave's plan and spawn first at tick 0. Bound: at most `plan capacity / 2` carried entries (the oldest win); the rest are dropped and counted in `plan.dropped_carry` (planner overflow in `plan.dropped_slots`). With default caps neither counter is nonzero in a normal run; both are in the state hash and the debug overlay.
- **(impl, M1)** `next_wave_is_boss` is true while the wave AFTER the current one is a boss wave (it is recomputed at each wave end as `is_boss_wave(ending + 2)`), so the UI can show the chevron one wave ahead. `run.damage_dealt` counts the full damage of each laser shot, including overkill. The `CINDER_HIT` event carries the intake damage rounded to an integer (display only; Cinder's hp is tracked as a float).
- Boss waves: boss spawns at t=2 s (S1-S6) or random in [1, 12] s (S7+), plus the normal N(w) slots at 60% count.
- Lull: no spawns. A "SKIP LULL" button (Launch) ends the lull early; it also grants +0 rewards (no exploit).
- Enemy "stale" rule: enemies alive 3 or more wave-ends after they spawned pay 50% `scrap` and `data` (HARD). [CIS 1 coin decay; kept to discourage stalling.]
- Enemy hardening: +4% mass per wave alive so knockback weakens (HARD). [CIS 1]
- Melee overclock bite: each consecutive melee hit by the same enemy deals +3% more than the previous, cap x2.0 (HARD). [CIS 1: 4%; changed to 3% with a cap, for predictability.]

## 7. In-run upgrades

All rows reset at deployment start. A row is **visible** in the run only if unlocked in Foundry (gate column; see unlock order in 05). `c0`,`g` define cost `ceil(c0 * g^L)`. "L cap" is the maximum run level. Values are **before** Foundry/external multipliers. Gate "S1 w N" = best wave reached in Sector 1 must be >= N (then the permanent unlock is bought with `data` in the Foundry; a Foundry unlock costs 20 x the c0 of that row, tunable).

### 7.1 ARMS (offense) - tab id `arms`

| id | Effect | Type | Base | Run inc / level | L cap | Hard cap | c0 | g | Gate |
|---|---|---|---|---|---|---|---|---|---|
| `laser_output` | Damage per laser shot | D, p=0.10 | 10 | (see D formula) | 400 | none | 10 | 1.108 | start |
| `cycle_rate` | Shots per second | C | 1.00 | +0.04 | 100 | 12.0 | 25 | 1.12 | start |
| `crit_chance` | Chance a shot crits | C | 0.02 | +0.008 | 98 | 0.85 | 60 | 1.10 | S1 w5 |
| `crit_mult` | Crit damage multiplier | C | 1.50 | +0.05 | 150 | none | 80 | 1.085 | S1 w8 |
| `optic_range` | Firing range (m) | C | 24 | +0.4 | 100 | 80 | 40 | 1.10 | S1 w10 |
| `standoff` | Damage +x per whole meter of target distance (0.0004/level = 0.04% per m per level) | C | 0 | +0.0004 | 100 | 0.06 | 120 | 1.10 | S1 w20 |
| `split_chance` | Chance a shot also hits extra targets (secondary shots deal 60% damage) | C | 0 | +0.005 | 80 | 0.60 | 200 | 1.11 | S1 w15 |
| `split_targets` | Extra targets per split | C | 1 | +1 | 6 | 8 | 1500 | 2.4 | S1 w15 |
| `burst_chance` | Chance per shot to trigger Burst (x3 cycle rate) | C | 0 | +0.004 | 85 | 0.50 | 300 | 1.11 | S1 w30 |
| `burst_duration` | Burst length (s) | C | 2.0 | +0.05 | 70 | 8.0 | 300 | 1.12 | S1 w30 |
| `ricochet_chance` | Chance a shot bounces | C | 0 | +0.008 | 85 | 0.85 | 600 | 1.11 | S1 w40 |
| `ricochet_targets` | Bounces per shot (each bounce 50% of previous damage) | C | 1 | +1 | 7 | 14 | 3000 | 2.2 | S1 w40 |
| `overcrit_chance` | Chance a crit becomes an overcrit (rolled only after a crit) | C | 0 | +0.002 | 100 | 0.30 | 20000 | 1.12 | S1 w100 |
| `overcrit_mult` | Extra multiplier on overcrit | C | 1.50 | +0.08 | 120 | none | 25000 | 1.12 | S1 w100 |
| `armor_tear_chance` | Chance a hit applies a tear stack to that enemy | C | 0.002 | +0.001 | 250 | 0.40 | 100000 | 1.05 | S1 w150 |
| `armor_tear_mult` | Per-stack bonus damage taken from Cinder's weapons; total from tears capped at +700% | C | 0.02 | +0.0014 | 200 | 0.30 | 100000 | 1.05 | S1 w150 |

Notes. `standoff` formula: `damage *= 1 + standoff * floor(distance_m)` where distance is enemy-to-Cinder-center at the moment of the shot. [CIS 2 Damage/Meter; changed to a smaller max (6%/m vs 5.9%/m similar) but gated later, and it is explained with an on-screen distance ring at 10/20/30 m.] Burst: when triggered, `cycle_rate` x3 for `burst_duration` s; re-trigger rolls are ignored while active. Ricochet damage: bounce k deals `0.5^k` of the primary hit. Super-crit equivalent is named **overcrit**. Rend equivalent is **armor tear**. [CIS 2]

### 7.2 CHASSIS (defense) - tab id `chassis`

| id | Effect | Type | Base | Run inc / level | L cap | Hard cap | c0 | g | Gate |
|---|---|---|---|---|---|---|---|---|---|
| `hull_integrity` | Max integrity (HP) | D, p=0.10 | 100 | (D formula) | 400 | none | 10 | 1.108 | start |
| `nano_repair` | Integrity restored per second | D, p=0.60 | 1.0 | (D formula) | 400 | none | 20 | 1.09 | start |
| `plating_pct` | Damage reduction fraction (all sources sum, hard cap 0.90) | C | 0 | +0.06 | 99 | 0.90 | 20 | 1.10 | S1 w10 |
| `plating_flat` | Flat damage subtracted after percent reduction | D, p=0.10 | 1 | (D formula) | 400 | none | 200 | 1.09 | S1 w25 |
| `spike_return` | Reflect fraction of attacker MAX health when it hits (bosses use 50% of value, elites 30%) | C | 0 | +0.01 | 60 | 0.60 | 500 | 1.11 | S1 w20 |
| `siphon_cell` | Heal fraction of damage dealt by Cinder weapons | C | 0 | +0.0005 | 80 | 0.05 | 800 | 1.10 | S1 w30 |
| `push_chance` | Chance a hit on Cinder knocks the attacker back | C | 0 | +0.01 | 80 | 0.85 | 150 | 1.10 | S1 w12 |
| `push_force` | Knockback force (unitless; divided by enemy mass) | C | 0.4 | +0.14 | 40 | 6.0 | 300 | 1.15 | S1 w12 |
| `razor_count` | Orbiting razors (each hits for 200% of current laser shot, 0.5 s per-enemy cooldown, type `kinetic`) | C | 0 | +1 | 4 | 12 | 2500 | 5.0 | S1 w35 |
| `razor_speed` | Orbit speed (degrees per second) | C | 40 | +10 | 38 | 420 | 400 | 1.12 | S1 w35 |
| `shock_size` | Shock ring radius (m) | C | 6 | +0.4 | 35 | 22 | 1500 | 1.12 | S1 w50 |
| `shock_rate` | Seconds between shock rings (lower is better) | C | 22 | -0.18 | 40 | min 7 | 1500 | 1.12 | S1 w50 |
| `mine_chance` | Chance a kill drops a mine | C | 0 | +0.006 | 50 | 0.40 | 4000 | 1.12 | S1 w60 |
| `mine_damage` | Mine damage as multiple of current laser shot (type `blast`, radius 3.5 m, arms after 1 s) | C | 1.0 | +0.1 | 200 | none | 3500 | 1.07 | S1 w60 |
| `fail_safe` | Chance to ignore a lethal hit (first step of death prevention) | C | 0 | +0.004 | 75 | 0.40 | 8000 | 1.10 | S1 w70 |
| `barricade_hp` | Barricade ring HP as fraction of max integrity | C | 0.20 | +0.001 | 800 | 3.0 | 6000 | 1.012 | S1 w80 |
| `barricade_rebuild` | Seconds to rebuild a destroyed barricade (lower better) | C | 120 | -0.3 | 300 | min 20 | 6000 | 1.02 | S1 w80 |

Notes. `razor_count` changed from The Tower's instant-kill orbs [CIS 2 Orbs] to damage-based hits: instant-kill farming ("devo") dominated its meta and made elites/bosses the only real check [CIS 7]. Razors are not blocked by anything but cannot damage enemies inside an `aegis_node` field (they bounce). `plating_pct` hard cap 0.90 (The Tower: 0.98 [CIS 1]); changed so eHP growth stays tied to Integrity/Repair. `plating_flat` has a minimum-damage floor (section 12). Barricade: ring radius 6 m; blocks melee and enemy projectiles; while destroyed it does not block; rebuild pushes enemies within 10 m outward. Spike return does not trigger siphon_cell. [CIS 2 Wall/Thorns]

### 7.3 SYSTEMS (utility) - tab id `systems`

| id | Effect | Type | Base | Run inc / level | L cap | Hard cap | c0 | g | Gate |
|---|---|---|---|---|---|---|---|---|---|
| `scrap_yield` | Multiplier on all `scrap` gained (mult) | C | 1.00 | +0.02 | 100 | 3.0 base (external mults stack on top) | 50 | 1.10 | S1 w3 |
| `scrap_per_wave` | End-of-wave `scrap` bonus = level x 0.5 kills' worth at current scrap per kill | C | 0 | +0.5 | 100 | 50 | 60 | 1.10 | S1 w4 |
| `data_yield` | Multiplier on all `data` gained (mult) | C | 1.00 | +0.02 | 100 | 3.0 base | 80 | 1.10 | S1 w6 |
| `data_per_wave` | End-of-wave `data` bonus = level x 1 skitter-kill's data at current level | C | 0 | +1 | 100 | 100 | 100 | 1.10 | S1 w8 |
| `reinvest` | Interest: fraction of unspent `scrap` paid at wave end (after wave bonus); payout cap per wave = 0.5 x that wave's kill `scrap` income (Lab `reinvest_cap` raises to x3) | C | 0 | +0.0006 | 99 | 0.0594 | 300 | 1.11 | S1 w12 |
| `free_arms` | Chance after each wave to give 1 free level to a random non-maxed unlocked ARMS stat (>1.0 rolls extra levels) | C | 0 | +0.005 | 99 | 0.99 | 400 | 1.12 | S1 w15 |
| `free_chassis` | Same for CHASSIS | C | 0 | +0.005 | 99 | 0.99 | 400 | 1.12 | S1 w20 |
| `free_systems` | Same for SYSTEMS | C | 0 | +0.005 | 99 | 0.99 | 400 | 1.12 | S1 w25 |
| `pod_chance` | Chance per wave a repair pod appears | C | 0.06 | +0.004 | 60 | 0.82 | 200 | 1.11 | S1 w8 |
| `pod_amount` | Pod heal as fraction of max integrity (cannot overheal) | C | 0.10 | +0.003 | 200 | 1.50 | 200 | 1.04 | S1 w8 |
| `signal_lag_atk` | Per-wave chance that the enemy attack level does not rise (accumulator, see section 9) | C | 0 | +0.0005 | 700 | 0.60 | 2000 | 1.01 | S1 w40 |
| `signal_lag_hp` | Same for enemy health level | C | 0 | +0.0005 | 700 | 0.60 | 2000 | 1.01 | S1 w40 |
| `sensor_reach` | Radius (m) within which cloaked enemies are revealed | C | 12 | +0.6 | 60 | 60 | 150 | 1.12 | S1 w25 |

Notes. `reinvest` order: wave bonuses first, then interest on the total. [CIS 2 Interest] Free upgrade rolls never pick maxed stats and only pick stats unlocked for this run. [CIS 2 Free Upgrades] `signal_lag_*` replace The Tower's "Enemy Level Skip" [CIS 2]. Repair pods are auto-collected after 3 s on the field (so they are not a tap chore).

### 7.4 Starting-run values (before any Foundry)
`scrap` 60 (was 20 until SimVersion 2), laser_output 10, cycle_rate 1.0, range 24, integrity 100, repair 1.0/s, all others locked. This gives wave ~11-13 on the first deployments with greedy buying (first-pass headless estimate, see 03 section 6).

### 7.5 Buying and recording rules (M2, **(impl)**)
- Buy modes x1, x10, x100, Max. A partial multi-buy is allowed: with `scrap` for only 7 of 10 levels, x10 buys 7 (cost is the exact sequential sum `ceil(c0 * g^L)` level by level); it buys nothing only when not even one level is affordable. Max buys until the cap or the money runs out.
- A buy that purchases zero levels (maxed row, gated row, nothing affordable) is rejected and is NOT written to the input log; the log (`tick,index,count`) records accepted buys only, with the requested count (1, 10, 100 or -1).
- A buy issued while the game is paused is applied before the next simulated tick, so it is logged with the current `world.tick` and replays identically.
- `hull_integrity` raises max integrity and current integrity by the same delta (buying armor mid-fight also heals that amount); `nano_repair` changes only the rate.
- Policy bot (`greedy4` buys among the four starting rows, `all` among every visible row): picks the row with the best `ref_dmg * ref_ehp` gain per cost and skips rows with zero gain (`scrap_yield`, `reinvest`, `optic_range`, ...), so those rows are never bought and unspent `scrap` can pile up; if the best row is unaffordable it waits and saves.
- Best wave (`best_wave_s1`, gates row visibility) is updated only by real runs that end by death; debug-loaded (`load`) runs never update it. A run copies the current best wave into its config at start.

## 8. Damage pipeline (exact order of operations) (HARD)

For each Cinder weapon hit on an enemy `e`:
1. **Base.** `D0 = laser_output_final` for laser hits. Other sources use their own base (razor: 2.0 x laser_output_final; mine: mine_damage x laser_output_final; weapon systems: % of laser_output_final per 05). Tag the hit with its damage type: `laser` | `kinetic` | `arc` | `blast` | `nano`.
2. **Source coefficient.** Multiply by the source factor: primary shot 1.0; split secondary 0.6; ricochet bounce k: 0.5^k; razor, mine, weapon-system factors as in their tables.
3. **Standoff.** `D1 = D * (1 + standoff * floor(dist_m))` (applies to laser, split and ricochet hits using the distance at the hit).
4. **Global damage multipliers.** `D2 = D1 * PRODUCT(damage_mult sources)`: firmware, Lab tuning, modules, companion `drone_amp`, patches, overdrive (x1.5), `target_painter` (+25%), exposure bonus (+6% per band lost), sector conditions on Cinder, etc. All are multiplicative.
5. **Crit.** Roll `crit_chance_final`; on success `D3 = D2 * crit_mult_final`; else `D3 = D2`. (Weapon-system hits can crit if the system lists it; default: they inherit the crit state of their trigger shot if any, else they do not crit.)
6. **Overcrit.** If step 5 crit succeeded, roll `overcrit_chance_final`; on success `D4 = D3 * overcrit_mult_final`; else `D4 = D3`. Total on overcrit = crit_mult x overcrit_mult. [CIS 2 Super Crit]
7. **Armor tear.** `D5 = D4 * (1 + min(7.0, tear_stacks_on_e * armor_tear_mult_final))` (stacks live on the enemy; permanent for that enemy; Cinder weapons only). If this hit rolled `armor_tear_chance`, add one stack after computing (so the application hit does not benefit).
8. **Enemy-side reductions (multiplicative).**
   a. Sector/enemy-type resistance (e.g. battle condition `bc_razor_hardened` reduces `kinetic` by 0.5).
   b. **Adaptation:** `x (1 - adaptation[type])` (section 8.1, Launch).
   c. **Field reduction:** inside an `aegis_node` field `x 0.60`.
   d. **Armored hits:** if `e.armor_hits > 0`, the whole hit is negated and `armor_hits -= 1` (battle condition `bc_armored`).
9. **Final.** `Dfinal = max(1, floor(D5 * reductions))`, reduce by shield/overheal state (bosses with `overheal`), subtract from enemy HP. Overkill is discarded. Lifesteal (`siphon_cell`) heals `Dfinal_actual * siphon_cell` where Dfinal_actual is damage actually removed from HP.
10. **Display.** Show damage number only if the hit is a crit, overcrit or >= 1% of target max HP, or among the top 6 numbers per 0.5 s (readability; see 07).

Weapon-system hit coefficients are defined in 05. Instant-kill effects do not exist (see razor note).

### 8.1 Adaptive Swarm (N1, APPROVED 2026-11-07; tag Launch; see section 13)
Tracks damage dealt per type during each wave. At wave end (step 8 of section 9):
```
share[t] = damage_dealt_this_wave[t] / total_damage_dealt_this_wave           (if total == 0 skip)
if wave >= 20:
   for t in types:
      if share[t] > 0.45: A[t] += 0.025 * (share[t] - 0.45) / 0.55
      elif share[t] < 0.20: A[t] -= 0.020
      A[t] = clamp(A[t], 0, A_cap)
A_cap(sector s) = 0.50 + 0.02 * (s - 1)               -- S1 0.50 ... S12 0.72
```
Firmware `fw_adaptive_filter` and module `mod_swarm_decoder` multiply gain by (1 - reduction) and A_cap by (1 - reduction/2). A pure single-type build reaches the cap in about 20 waves after wave 20; a 50/50 split never gains. Visual: enemies draw a thin outline ring colored for the type they have most resistance to; HUD shows 5 small bars (L K A B N). Intel tab shows exact percentages. Off in MVP (single damage type).

## 9. End-of-wave resolution order (HARD)
When the 24 s wave timer ends (wave w -> w+1):
1. Pay `scrap_per_wave` x (Cash Bonus: `scrap_yield`) and `data_per_wave` x (`data_yield`).
2. Interest (`reinvest`) on unspent `scrap` including step 1; clamp by payout cap.
3. Free upgrade rolls (arms, chassis, systems), in that order.
4. Repair pod roll (`pod_chance`); pod spawns near Cinder.
5. Draft check: if `w` equals a draft wave, open the draft after steps 6-8.
6. Enemy level increment: separately for hp and atk, `acc += signal_lag_x_final`; if `acc >= 1` then skip this increment and `acc -= 1`, else level += 1. (Deterministic accumulator. [CIS 2 Level Skip v26: deterministic].)
7. Boss check for wave w+1 (is w+1 a boss wave).
8. Adaptation update (8.1) if enabled.
9. Stale cleanup: mark enemies older than 3 wave-ends as stale (50% payout).
10. Overdrive and weapon-system cooldown ticks continue unaffected.
Wave-level bonuses are never paid for skipped (Fast-forwarded) waves because there is no skip; the Wave Skip firmware instead has its own rule (05).

## 10. In-run perk choices: Patches (draft)

Draft waves: `n`-th draft occurs at wave `W_n = 10 * n` for n = 1..5 (10, 20, 30, 40, 50), then `W_n = 50 + 25 * (n - 5)` (75, 100, 125, ...). Lab `patch_interval` and patch `patch_draft_speed` reduce the post-50 spacing. [CIS 6: first perk at wave 200; changed to wave 10 so build choice appears in the first run.]
- Offer: 3 distinct patches (Lab `patch_choices` raises to 4). Offer mix per slot: 70% standard, 15% gamble, 15% weapon-system patch (if no weapon system equipped this 15% becomes standard). [CIS 6: 68/12/20]
- Offers are random but seeded by run seed; no reroll. A patch at max picks is excluded.
- Pick time: unlimited in manual mode; "auto-pick" setting chooses by a player-ordered priority list (Lab `patch_autopick` unlocks it, Launch).
- Not available in Gauntlets (matches [CIS 6]) so tournaments test build and Foundry rather than luck.

Math: additive patches `total = base_stat * (1 + bonus * qty)`; multiplicative `total = base * mult^qty`; both then multiplied by the Lab `patch_potency` bonus (up to +25%) on the bonus portion. [CIS 6 Math]

### 10.1 Standard patches
| id | Effect | Per pick | Max picks | Tag |
|---|---|---|---|---|
| `patch_overcharge` | laser_output x (1 + 0.15 qty) | +15% | 5 | MVP |
| `patch_plating` | hull_integrity x (1 + 0.20 qty) | +20% | 5 | MVP |
| `patch_rate` | cycle_rate x (1 + 0.10 qty) | +10% | 5 | MVP |
| `patch_extraction` | scrap_yield and data_yield x (1 + 0.15 qty) | +15% | 5 | MVP |
| `patch_regen` | nano_repair x (1 + 0.50 qty) | +50% | 5 | MVP |
| `patch_ceramic` | plating_pct + 0.04 qty (additive) | +4 pts | 5 | MVP |
| `patch_reinvest` | reinvest rate x (1 + 0.5 qty) | +50% | 3 | Launch |
| `patch_razors` | razor_count + 1 qty | +1 | 2 | Launch |
| `patch_free_level` | free_arms/chassis/systems + 0.04 qty each | +4 pts | 5 | Launch |
| `patch_ricochet` | ricochet_targets + 2 qty | +2 | 3 | Launch |
| `patch_draft_speed` | post-wave-50 draft spacing x (1 - 0.20 qty) | -20% | 3 | Launch |
| `patch_mines` | mine_damage x (1 + 1.0 qty) | +100% | 5 | Launch |
| `patch_overdrive_cell` | overdrive charge rate x (1 + 0.25 qty) | +25% | 4 | Launch |
| `patch_sweep` | sensor_reach + 8 m qty; shades take +25% damage qty | | 3 | Launch |
| `patch_graft` | exposure bonuses x (1 + 0.5 qty) and skin burn begins 5% lower | | 2 | Launch |
| `patch_turncoat` | turncoat_chance + 0.05 qty (see N5; deferred, post-launch) | +5% | 3 | Post-launch |

### 10.2 Gamble patches (trade-offs; always show both sides) [CIS 6 trade-offs, re-tuned]
| id | Benefit | Cost | Max | Tag |
|---|---|---|---|---|
| `patch_t_glass` | laser_output x1.5 | hull_integrity x0.70 | 1 | MVP |
| `patch_t_greed` | data yield x1.8 | hull_integrity x0.50 | 1 | MVP |
| `patch_t_hardhide` | enemy damage x0.60 | laser_output x0.60 | 1 | MVP |
| `patch_t_slow_swarm` | enemy speed x0.65 | enemy damage x1.8 | 1 | Launch |
| `patch_t_hoard` | wave-end `scrap` payout x12 of expected kill scrap | kills give no `scrap` | 1 | Launch |
| `patch_t_sprint` | lull 6 s -> 3 s | enemy count x1.3 | 1 | Launch |
| `patch_t_blind_spot` | adaptation gain x0.4 | crit_mult x0.70 | 1 | Launch |
| `patch_t_redline` | overdrive duration x1.5 | overdrive self-damage x2 | 1 | Launch |

### 10.3 Weapon-system patch
`patch_w_boost`: when offered it names one equipped weapon system: its magnitude x1.5 and cooldown x0.75 for this run; max 3 picks per system. Launch.

## 11. Death-prevention order (HARD)
When a hit would reduce integrity to 0 or less, evaluate in this order; the first that succeeds stops the chain:
1. `fail_safe` roll (in-run stat): on success the hit is ignored entirely (no integrity loss).
2. `aegis_charge` (firmware `fw_aegis_charge`): consumes 1 charge, negates the hit. Charges per run: 1 at 1 star up to 3 at 5 stars; +1 charge regenerates every 20 waves.
3. `reboot` (firmware `fw_reboot`, once per run): restore integrity to 50% of max and grant 10 s invulnerability (up to 14 s at 5 stars).
4. `meltdown` (firmware `fw_meltdown`, once per run): 15 s invulnerability, laser_output x30 (cycle unchanged), integrity set to 25%; skin burns completely (band D visuals) and the HUD shows MELTDOWN.
5. `purge` (firmware `fw_purge`, once per run): all non-boss enemies within 30 m take 500% of current laser shot (type `arc`), plus 6 s invulnerability.
6. Death: `ad_revive` offer (once per run, not in Gauntlets, opt-in).
[CIS 1 order: Death Defy -> Energy Shield -> Second Wind -> Demon Mode -> Nuke; kept the order, merged "energy shield" into the lethal-hit chain so that it is not wasted on trivial hits, and renamed.] Every step logs a visible HUD message so the player understands why they survived.

## 12. Damage intake pipeline (enemy hits Cinder) (HARD)
For enemy hit with raw damage `R` (computed from enemy damage level, type multiplier, melee-bite stacks, sector conditions):
1. **Barricade** (if alive): absorbs the hit fully into barricade HP (melee and projectiles). If barricade HP reaches 0 it breaks (no carry-over).
2. `R1 = R * (1 - min(0.90, plating_pct_final))`.
3. `R2 = max(R1 - plating_flat_final, 0.05 * R1)` - 5% minimum damage floor (HARD; The Tower has no floor [CIS 1]; added so defense stats never grant true immunity).
4. `R3 = R2 * PRODUCT(damage_taken multipliers)` (patches, sector conditions, `overdrive` heat soak, etc.).
5. Reflect: if `spike_return_final > 0`, deal `spike_return * attacker_max_hp` (x0.5 boss, x0.3 elite) to the attacker as `kinetic`. Not applied to ranged shots from lancers (they are not in contact) except via firmware `fw_thorn_mesh`.
6. Integrity `-= R3`. If <= 0 run section 11.
Exposure Band recalculated after every integrity change.

Defense effective HP: `eHP = (integrity + plating_flat) / (1 - plating_pct)` - displayed in Intel.

### 12.1 Skin Burn: integrity bands (N2, APPROVED 2026-11-07; visuals MVP, modifiers Launch)
`f = integrity / max_integrity`
| band id | Condition | Visual | Modifier (Launch) |
|---|---|---|---|
| `exp_0` | f > 0.75 | Skin intact: 12 wedges, warm | none |
| `exp_1` | 0.50 < f <= 0.75 | Scorch: 3 wedges char and flake, ember particles, small sparks | +6% damage, +20% nano_repair |
| `exp_2` | 0.25 < f <= 0.50 | Exposed: 8 of 12 wedges gone, frame ribs visible, flicker | +12% damage, +40% nano_repair |
| `exp_3` | f <= 0.25 | White-hot frame, cracked core outline, heartbeat pulse, red vignette | +18% damage, +60% nano_repair |
Bands change with 5% hysteresis (a band is re-entered only when f crosses back by 5%) to avoid flicker. Skin wedges do not regrow within a run when going down, but re-form one by one over 1.5 s when integrity returns to a better band. Cosmetic variants (Operation Pass) swap the wedge material (not the silhouette).

## 13. New mechanics (approved by the user on 2026-11-07, except N5)

**Approval status:**

| id | Status | Tag |
|---|---|---|
| N1 `adaptive_swarm` | APPROVED | Launch |
| N2 `skin_burn` | APPROVED | Visuals MVP, modifiers Launch |
| N3 `salvage_cache` | APPROVED | Launch |
| N4 `overdrive` | APPROVED | Launch |
| N5 `turncoat_protocol` | DEFERRED to post-launch (P2); `patch_turncoat` and `fw_turncoat` stay Post-launch | Post-launch |


| id | Mechanic | Why | Scope cost | Tag | Risk |
|---|---|---|---|---|---|
| N1 `adaptive_swarm` | Swarm gains resistance to your dominant damage type during a run (8.1) | Creates real build choice; counters "mono build" meta; strong theme ("CHORUS learns") | Medium: 5 damage types tagged, per-wave tracking, 5 HUD bars, tuning. 2-3 dev days + balance | Launch | Can frustrate players if opaque; mitigated by HUD and per-type Lab/firmware reducers |
| N2 `skin_burn` | Skin degrades with integrity; exposure bands give small comeback bonuses (12.1) | Signature visual identity, readable health state, comeback mechanic | Low: visuals 2 days (MVP), modifiers 0.5 day | Visual MVP, modifiers Launch | Minimal |
| N3 `salvage_cache` | Elites/bosses drop caches: tap to pick the best of three reward types (scrap burst / repair / overdrive charge); un-tapped caches auto-collect at 50% after 8 s | Gives active players something to do without penalizing idlers; thematic salvage | Low-Medium: 1 entity, tap handling, 3 outcomes, drone_scav automation | Launch | Tap precision on busy screen: use generous hit boxes (min 56 dp), auto-collect |
| N4 `overdrive` | Meter fills from damage dealt; tap OVERDRIVE for 8 s: cycle x1.75, damage x1.5, weapon cooldown ticks x2, but integrity drains 1.2% max per second (floor 15%), then 5 s heat soak (cycle x0.6). Auto-trigger with firmware `fw_overdrive_governor` | Optional active skill, the only active in an idle genre; risk/reward ties to skin burn visuals | Medium: meter, button, drain, VFX | Launch | Must not become mandatory: Gauntlets allow it, but auto-governor exists so idlers keep pace (balance so manual gain <= 12% extra waves) |
| N5 `turncoat_protocol` | Chance for killed `dart`, `lancer`, `jammer`, `mender` to reboot as a turncoat fighting for Cinder for 10 s at 50% stats, max 6 at once (`turncoat_chance` from firmware/patches only) | Thematic ("reprogrammed machine") and fun swarm visuals | Medium: friendly-AI pathing, targeting rules, caps | Post-launch | Performance; keep entities simple |

Overdrive numbers: meter 0-100; `charge += (hp_removed_from_enemies / reference_wave_hp(l)) * 33.3` where `reference_wave_hp(l) = N(w) * hp_skitter(l)`; so a full meter is about 3 waves of damage regardless of scaling. Trigger at 100. Drain: integrity `-= 0.012 * max_integrity * dt`; overdrive ends early if integrity <= 15%. Cannot trigger during invulnerability states.

## 14. Game speed
- Settings 1x, 2x always; **4x unlocks at best TIMED wave 30 and 8x at wave 60** (R1-03, Q90; replaces the planned Lab `game_speed` 3x/4x; the unlock constants live in `SpeedRules`, meta layer, not in `sim_constants.csv`, so the config hash is unchanged). HARD: all game timers (waves, cooldowns, durations, regen) scale with speed; the simulation remains deterministic regardless of speed (same state hash at 1x, 2x and 8x, FC11). Cap is now 8x (`TickDriver.MAX_TICKS_PER_FRAME` 8). **Fall-back:** above 2x the effective speed drops to 2x while Cinder's hull is below 75% or a boss is alive, and returns to the chosen speed at 80% hull with no boss; the same in PURGE. The HUD shows the chosen speed dimmed and the effective one lit. At 4x and 8x the view sheds load (SFX voices, haptic buy ticks, damage numbers, sparks and kill particles at 0.5 and 0.25, `SpeedLoad`).
- (M2, **(impl)**) The HUD speed button cycles the unlocked speeds only (the next speed unlock shows in the Home unlock chip); the chosen speed is app-level, so it persists across REDEPLOY and is not part of the sim config (speed changes ticks per frame, never the tick).
- Gauntlets run at the player's max speed but the score is wave-based, not time-based, so speed does not affect fairness.
- Ads and drafts pause the game; backgrounding the app pauses the run (Standby Patrol is a separate simulated system, 04).

## 15. Other in-run rules
- **Intel tab** (tap wave counter): shows for the current wave: enemy spawn weights, hp, atk, speed, mass per type, N(w), adaptation %, draft in X waves, boss in X waves, stale count, active conditions. Opaque systems were a cited complaint [CIS gaps], so every formula output is visible.
- **Wave counter and boss warning:** 3 waves before a boss wave the HUD shows a small amber chevron; the boss spawn has a 1.5 s warning ring on the spawn edge.
- **Pause:** pause any time; Gauntlets do not allow pause beyond 10 s per run (anti-abuse).
- **Auto-pick draft** (Launch), **auto buy** (Lab `auto_buy`, Launch): player-defined priority list; buys in order when affordable.
- **Revive via ad** (`ad_revive`): integrity to 50%, 8 s invuln, keeps run; once per run.
