# 05 - Meta Progression

Changelog: 2026-11-10 (R1-02, SimVersion 6: section 1.5 is now a SOFT cap, levels at or above `max(3, floor(0.6 * best_s1))` cost x3 instead of being locked; Foundry and run milestone step and multiplier, the cap k and minimum and the over-cap multiplier are data rows in `sim_constants.csv`; tune pending) - 2026-11-09 (FO-3: Foundry milestone x1.75 every 25 levels, new section 1.5 best-wave level cap, option E of the FO-2 study chosen by the user) - 2026-11-08 (M2-16: 1.3 implementation note on the Type C cap) - 2026-11-07 - Gauntlet and Incursion unlocks tagged P1, Cells P2 (online staging); N1-N4 approved (Lab/firmware rows tagged Launch stay as written).

Citations: `[META]` = meta_progression_systems.md, `[CIS]` = combat_and_in_run_systems.md. The research could not retrieve most per-level cost tables [META gaps], so every cost here is original. All numbers tunable. Each system is tagged **MVP / Launch / Post-launch**.

---

## 1. Foundry (permanent upgrades) - tag: MVP (4 stats), Launch (all rows) [CIS 2 Workshop equivalent]

The Foundry is a list of permanent upgrades paid in `data`. Every in-run stat id (02 section 7) has a Foundry row. A Foundry level raises that stat's **starting value for every deployment**; the player then adds temporary run levels on top. Stat resolution formulas are in 02 section 5. [Changed: The Tower merges workshop and in-run levels into one counter, which makes costs hard to reason about [CIS structural caveat]. Ours keeps two clear layers: permanent (multiplier/starting bonus) and temporary (run levels).]

### 1.1 Foundry cost
```
foundry_cost(F -> F+1) = ceil(fc0 * fg ^ F)            -- in data
unlock cost (first buy to make the row visible in runs) = 20 * c0_run   (data), gated by best S1 wave (02 gate column)
```
Lab `lab_foundry_discount` multiplies cost by `(1 - 0.01 * level)` (max level 30).

### 1.2 Type D (deep stats) rows
Foundry multiplier: `foundry_mult(F) = (1 + f * F) * foundry_milestone_mult ^ floor(F / foundry_milestone_step)` (1.75 and 25 in `data/sim_constants.csv` since R1-02, were code constants), F cap 200 (2026-11-09, FO-3: was `1.25 ^ floor(F / 10)`; the long-run curve is the same, 1.25^2.5 = 1.75, but the early F10/F20 bumps are gone).
| id | f | F cap | fc0 | fg | mult at F=25 / 50 / 100 / 200 |
|---|---|---|---|---|---|
| `laser_output` | 0.06 | 200 | 20 | 1.10 | 4.4 / 12.3 / 65.7 / 1,143 |
| `hull_integrity` | 0.06 | 200 | 20 | 1.10 | 4.4 / 12.3 / 65.7 / 1,143 |
| `nano_repair` | 0.05 | 200 | 25 | 1.10 | 3.9 / 10.7 / 56.3 / 968 |
| `plating_flat` | 0.05 | 200 | 40 | 1.10 | same as nano_repair |
Cumulative cost to reach F: `fc0 * (1.1^F - 1) / 0.1` -> for fc0 = 20: F=10: 319; F=25: 1.97e3; F=50: 2.33e4; F=100: 2.76e6; F=150: 3.24e8; F=200: 3.80e10. (Month-6 free target is F ~ 185 on core stats, see 04.)

### 1.3 Type C (capped) rows - generic rule
For every Type C stat in 02 section 7 (all other ids): `f_inc = r_inc` (same per-level step as the run row), `F_cap = floor(L_cap / 2)` (minimum 1, e.g. `razor_count` F_cap 2, `split_targets` F_cap 3), `fc0 = 2 * c0_run`, `fg = g_run`. Meaning: a Foundry level is a free starting run level, up to half of the run cap; the run cap is not increased. Resolved value: `clamp(base + r_inc*L + f_inc*F, hard_floor, hard_cap)`. Foundry levels do not count toward the run level cap `L_cap`. Cost examples: `crit_chance` F level 1 = 120 `data`, F=49 = 120 * 1.1^48 = 1.16e4; `scrap_yield` F=50 = 100 * 1.1^49 = 1.07e4.
(M2, **(impl)**) In code the cap is `max(1, floor(l_cap / 2))` and the Foundry step `f_inc` is the CSV `step` of the run row (no separate column); the Foundry ships in M3, so M2 only resolves F = 0.

### 1.4 Foundry UI rules
Each row shows: current value, next-level value, delta, cost, max, and time/`data` to afford at current farm rate (information is cheap and addresses "opaque systems"). Tap the cost button to buy one level, hold to repeat-buy (no buy-mode selector; 07 s2.2, 2026-11-08). A "Recommended" glow marks the cheapest stat whose next level is within 3 levels of a milestone (every 25 levels = x1.75 for D stats), else the cheapest affordable row; a row held back by the level cap (1.5) is never recommended. The row's milestone line reads "MILESTONE F25  x1.75".

### 1.5 Best-wave soft cap (FO-3, 2026-11-09; soft since R1-02, 2026-11-10, Q89)
Why: Data arrives fast enough that stacking one Foundry stat in the first minutes ran far ahead of the Day-1 pace (study: `docs/balance/foundry_early_power.md`, option E chosen by the user). The FO-3 version locked a row at the limit, which left the journey with no new best from day 5 to day 10 and thousands of Data it could not spend (review G-06), so the user chose a soft cap (Q89).
- The limit is `max(foundry_cap_min, floor(foundry_cap_k * best_s1))` (3 and 0.6 in `data/sim_constants.csv`), where `best_s1` is the best TIMED Sector 1 wave (the value the 7 gates use). At best wave 0 that is 3 levels, at wave 10 six, at wave 35 twenty-one, at wave 100 sixty.
- A level whose index (the level being bought from) is at or above the limit costs `foundry_over_cap_mult` times the normal cost (3.0 to start, flat). It is never forbidden. Compounding (`mult ^ levels_over`) is allowed only if the journey targets need it. Never above the row's own F cap.
- Levels already owned are never removed. A profile above the limit keeps them and pays the multiplied price for more until its best wave passes them.
- The row UI (1.4): the cost button stays enabled; an over-limit cost is shown in `Palette.OVER_LIMIT` (ember orange, 7.4:1 on the plate); the line reads "x3 COST UNTIL WAVE N", where N is the smallest best wave at which that level is back at the normal price; hold-to-buy stops at the first over-limit level (a fresh tap buys one level at the multiplied price); RECOMMENDED prefers rows below the limit; the tooltip explains the rule; the FO-1 explainer says higher levels cost more until you reach further waves. The Home and Results "affordable" badge counts only rows at the normal price.
- Tuning the three cap rows does not change the sim, so `ConfigHash` leaves them out and a run in progress is not ended (review C-07).
- Sectors 2 and later are not in the game before M6; the limit rule for them is open (09 Q87). Until it is decided only Sector 1 best wave counts.

## 2. R&D Lab (timed research) - tag: Launch (MVP: none; MVP has only Foundry) [META Labs]

### 2.1 Slots, timers, rush
- Slots: 1 at unlock (S1 wave 25), slot 2 free at S1 wave 50 (milestone), slot 3 for 250 `flux`, slot 4 for 700 `flux`. Max 4 [META: 5-6 incl. gem-bought 100/400/1400/3000; ours cheaper and fewer].
- **Duration formula (HARD):** `duration_h(L) = min(48, t0 * 1.35^L) * (1 - lab_speed_bonus)` where `L` is the research's current level (0-based), `lab_speed_bonus` = `0.015 * lab_speed_level` (max 0.30). **No research ever exceeds 48 h.** (If later content needs more, add levels, not time.) [META: timers of days; Labs the main time gate]
- **Cost formula:** `data = ceil(rc0 * 1.30^L) * (1 - lab_cost_discount)`.
- **Rush:** cost `ceil(remaining_hours * 3)` `flux` (round up per started hour), free if remaining < 10 min. **Ad assist:** `ad_lab_boost` removes 30 min of remaining time (max 6 per day, each only after the timer started). Mid-research switching: not allowed; cancelling refunds 100% `data` and loses progress (simple rule, fewer complaints than partial refunds).
- Notifications: push when a research completes (opt-in).
- Auto-queue (Launch): optional queue of up to 3 per slot is NOT included (it increases currency pressure; revisit post-launch).

Sample (t0 = 0.25 h, rc0 = 100):
| Level L | Duration | Data cost |
|---|---|---|
| 0 | 15 min | 100 |
| 4 | 50 min | 286 |
| 8 | 2.8 h | 816 |
| 10 | 5.0 h | 1,380 |
| 12 | 9.2 h | 2,330 |
| 14 | 16.7 h | 3,940 |
| 16 | 30.4 h | 6,650 |
| 18+ | 48 h (capped) | 11,200+ |
Rush for the 48 h research: 144 `flux`; 30.4 h: 92 `flux`.

### 2.2 Research catalogue
Columns: id | effect | per level | max level | t0 (h) | rc0 | unlock gate. Gates use best S1 wave.
**Core**
| id | Effect | Per level | Max | t0 | rc0 | Gate |
|---|---|---|---|---|---|---|
| `lab_game_speed` | Unlocks 3x at level 5, 4x at level 15 | thresholds | 15 | 0.5 | 200 | Lab unlock |
| `lab_speed` | Lab time reduction (`lab_speed_bonus`) | -1.5% | 20 | 1.0 | 400 | S1 w25 |
| `lab_cost_discount` | Research data cost | -1% | 25 | 1.0 | 400 | S1 w25 |
| `lab_foundry_discount` | Foundry cost | -1% | 30 | 0.5 | 300 | S1 w25 |
| `lab_start_scrap` | Starting `scrap` | +2 | 50 | 0.25 | 100 | Lab unlock |
| `lab_reinvest_cap` | Interest payout cap multiplier (x1 base to x3) | +0.1 | 20 | 1.0 | 600 | S1 w30 |
| `lab_standby_cap` | Standby Patrol cap | +30 min | 14 | 0.5 | 250 | S1 w30 |
| `lab_standby_eff` | Standby efficiency | +0.01 | 20 | 1.0 | 300 | S1 w30 |
| `lab_threat_sort` | Target priority: L1 `ranged_first`, `elite_first`; L2 `lowest_hp` | modes | 2 | 4 | 5000 | S1 w50 |
| `lab_patch_choices` | Patch offers 3 -> 4 | 1 | 1 | 12 | 20000 | S1 w50 |
| `lab_patch_interval` | Post-wave-50 draft spacing | -2.5% | 8 | 2 | 3000 | S1 w50 |
| `lab_patch_potency` | Patch bonus portion | +1% | 25 | 2 | 3000 | S1 w50 |
| `lab_patch_autopick` | Unlocks auto-pick priority list | 1 | 1 | 2 | 2000 | S1 w30 |
| `lab_auto_buy` | Unlocks auto-buy priority list | 1 | 1 | 4 | 5000 | S1 w40 |
**Tuning (stat multipliers)** - each gives an additive multiplier to the named stat, multiplicative with Foundry/firmware.
| id | Effect | Per level | Max | t0 | rc0 | Gate |
|---|---|---|---|---|---|---|
| `lab_tune_laser` | `laser_output` x(1+0.02L) | +2% | 100 | 0.25 | 100 | S1 w25 |
| `lab_tune_cycle` | `cycle_rate` x(1+0.01L) | +1% | 60 | 0.25 | 100 | S1 w25 |
| `lab_tune_hull` | `hull_integrity` x(1+0.02L) | +2% | 100 | 0.25 | 100 | S1 w25 |
| `lab_tune_repair` | `nano_repair` x(1+0.02L) | +2% | 100 | 0.25 | 100 | S1 w25 |
| `lab_tune_crit` | `crit_mult` +0.02L (additive on value) | +0.02 | 75 | 0.5 | 200 | S1 w30 |
| `lab_tune_range` | `optic_range` +0.2 m per L | +0.2 m | 60 | 0.5 | 200 | S1 w30 |
| `lab_tune_plating` | `plating_pct` hard cap +0.001 per L (max cap 0.93 total with firmware) | +0.1% | 30 | 1 | 500 | S1 w40 |
| `lab_tune_scrap` | `scrap_yield` x(1+0.01L) | +1% | 60 | 0.5 | 200 | S1 w25 |
| `lab_tune_data` | `data_yield` x(1+0.01L) | +1% | 60 | 0.5 | 200 | S1 w25 |
**Systems**
| id | Effect | Per level | Max | t0 | rc0 | Gate |
|---|---|---|---|---|---|---|
| `lab_adapt_filter` | Adaptation gain | -1.5% | 20 | 2 | 4000 | S1 w50 (Launch w/ N1) |
| `lab_overdrive_duration` | Overdrive +0.2 s/level | | 15 | 1 | 2000 | Overdrive unlock |
| `lab_overdrive_charge` | Overdrive charge rate | +2% | 25 | 1 | 2000 | Overdrive unlock |
| `lab_skip_lull` | Unlocks SKIP LULL button | 1 | 1 | 2 | 3000 | S1 w40 |
**Enemy studies** (generated rows): for each enemy type `T` in {skitter, dart, walker, lancer, aegis_node, shade, jammer, mender, siege_lance, siphon, brood, boss_hulk, boss_hive, boss_lance, boss_null}: `lab_foe_T_hp`, `lab_foe_T_atk`, `lab_foe_T_spd`: -1% per level to that type's hp / damage / speed (max level 25, i.e. -25%; boss lines -1% up to -20%), t0 = 1 h, rc0 = 800, unlocked once that type has first been seen. Tag: Launch. [CIS 5 per-enemy labs]
Mapping notes: no "Wall labs" (barricade has regular Foundry rows); no "Perk unlock lab" (all patches available from the start; gamble patches disclosed).

## 3. Weapon systems (ultimate-weapon equivalents) - tag: Launch (MVP: none) [META UW, CIS other in-run actives]

Nine auto-firing systems, re-themed and partly re-designed. Differences from The Tower: (1) **3 equipped slots** (more choice, less visual noise), (2) no toggle limit, (3) systems are paid with `cipher` to unlock and `data` to level, (4) `emp_pulse` and `singularity_charge` interact with the enemy design (jammers disable systems, convoys steal them).
- **Unlock cost by order owned** (`cipher`): 3, 20, 60, 120, 220, 380, 600, 900, 1,300 (total 3,603). The player picks which weapon to buy from **three random offers** that persist until bought (offers only reroll after a purchase) [META UW: 3 offers, equal odds]; the first purchase is free from the S1 w50 milestone.
- **Equip slots:** slot 1 free on first unlock; slot 2 free on second unlock; slot 3 costs 400 `flux`. Slot 4 Post-launch (module reward).
- **Behavior:** a system fires automatically when its cooldown reaches 0 and a valid target exists; cooldown timers scale with game speed. Toggling a system off/on resets its cooldown.
- **Levelling:** each system has three stats A, B, C, each level 0-40. `stat(L) = base + inc*L`, cost `ceil(wc0 * 1.15^L)` with `wc0` = 4,000 (A), 6,000 (B), 5,000 (C). A at L=40 costs 4,000 * 1.15^39 = 9.4e5; B 1.4e6; C 1.2e6. All three maxed ~3.6e6 `data` per system (affordable mid-game, aim: month 2-5).
- **UW+ (Post-launch):** after all nine owned, unlock a second ability per system with `cipher` 150-400 each (to be designed).
- Hits use a damage coefficient relative to the current `laser_output_final` shot; unless stated they use the pipeline from step 4 (global multipliers), may crit if marked, and obey step 8 reductions.

| id | Type | Effect | A: magnitude (base, +inc/L) | B: cooldown s (base, -dec/L, min) | C: size/duration (base, +inc/L) | Crit? |
|---|---|---|---|---|---|---|
| `arc_discharge` | arc | Lightning chains from target to 5 enemies, applies Shocked (+10% damage taken from all sources for 4 s) | damage 150%, +6% | 8.0, -0.06, 5.6 | jump range 8 m, +0.2 | yes |
| `emp_pulse` | arc | Expanding ring from Cinder (radius 28 m) damages and stuns enemies, disables `aegis_node` fields 5 s; bosses/convoy not stunned | damage 200%, +8% | 40, -0.5, 20 | stun 1.5 s, +0.05 | no |
| `micro_missiles` | blast | Launches 6 homing missiles at random enemies (blast radius 3 m) | damage/missile 120%, +5% | 12, -0.1, 8 | missiles 6, +0.2 (floor) | yes |
| `singularity_charge` | kinetic | Places a well at 0.85 x range on densest cluster: pulls enemies in (elites/bosses x0.25) for 5 s, 40% shot damage per second | pull duration 5.0 s, +0.1 | 45, -0.5, 25 | radius 10 m, +0.2 | no |
| `dilation_field` | none | Ring (radius 18 m) around Cinder slows enemies (bosses half effect) | slow 50%, +0.5% (max 70%) | 40, -0.4, 24 | duration 6 s, +0.15 | n/a |
| `nanite_cloud` | nano | Zone on densest cluster, 8 s, damage per second and 1 armor tear stack per 2 s | dps 40%, +2% | 30, -0.3, 18 | radius 10 m, +0.2 | no |
| `salvage_beacon` | utility | For duration: `scrap` x A and `data` x (1 + (A-1)*0.5) | multiplier 2.0, +0.02 | 80, -0.8, 48 | duration 12 s, +0.2 | n/a |
| `target_painter` | utility | Marks a 10 s zone: enemies inside take +A damage, shades revealed | +25%, +0.5% | 60, -0.6, 36 | radius 14 m, +0.2 | n/a |
| `proximity_grid` | blast | Drops 12 mines in a ring at 10 m; each mine 300% damage, 1 s stun, radius 3 m | damage 300%, +10% | 35, -0.4, 20 | mines 12, +0.2 (floor) | yes |
Interactions designed for synergy (documented in the Intel tab): `singularity_charge` + `salvage_beacon` (sync), `nanite_cloud` + `arc_discharge` (Shocked amplifies), `target_painter` + `micro_missiles`, `emp_pulse` + `aegis_node` counter. [META UW synergies]

## 4. Firmware chips (card equivalent) - tag: Launch (MVP: none) [META Cards]

- **Slots:** 3 at start (unlocked with the first chip, S1 w50), up to 8: slots 4-8 cost 100, 200, 350, 550, 800 `flux` (total 2,000). [META: gem slot costs up to 58,400; ours far cheaper because there are fewer chips]
- **Acquisition (disclosed odds):**
  - *Firmware pick* (45 `flux` or free from milestones/missions): offered **3 chips, choose 1**. Each offered chip is independently Common 62%, Rare 30%, Epic 8% (no duplicates within an offer). **Pity:** a pick that offers no Epic for 19 consecutive picks guarantees at least one Epic in the 20th. Odds are shown in the shop screen and in Settings > Odds. [Google Play requires disclosed odds for randomized paid items; pick-1-of-3 reduces frustration]
  - Free chips: weekly Ops chest (1 pick), Operation Pass tiers, sector log-fragment sets (1 chosen chip).
- **Levels (stars 1-5):** copies needed for next star: 2, 3, 5, 8 (total 19 copies for 5 stars). Duplicates are never wasted (they are the progress). Star effect scales as listed.
- **Presets (Launch):** 3 saved loadouts; extra presets 100 `flux` each (max 6).
- Chips are loaded at deployment start; equip changes are blocked in a run and in Gauntlet lock (Gauntlet limits to 5 slots, see 06).

| id | Rarity | Effect at 1 star | Effect at 5 stars |
|---|---|---|---|
| `fw_scrap_siphon` | Common | `scrap` gained x1.08 | x1.24 |
| `fw_data_miner` | Common | `data` gained x1.08 | x1.24 |
| `fw_quick_start` | Common | Start with scrap = 10 kills' worth at sector start level | 50 kills' worth |
| `fw_interest_core` | Common | `reinvest` rate x1.10 and cap x1.25 | x1.50 and cap x2.0 |
| `fw_scavenger` | Common | Normal kills have 0.10% chance to drop a `salvage_cache` | 0.50% |
| `fw_overclocker` | Rare | `laser_output` x1.10 | x1.50 |
| `fw_targeting_ai` | Rare | `crit_chance` +2 pts, `crit_mult` +0.10 | +10 pts, +0.50 |
| `fw_calibrator` | Rare | `optic_range` +2 m, `standoff` x1.10 | +10 m, x1.50 |
| `fw_burst_loader` | Rare | `burst_chance` +2 pts, `burst_duration` +0.5 s | +10 pts, +2.5 s |
| `fw_adaptive_filter` | Rare | Adaptation gain -10%, cap -5% | gain -50%, cap -25% |
| `fw_executioner` | Rare | Enemies below 20% HP take +20% damage | +100% |
| `fw_hull_weave` | Rare | `hull_integrity` x1.10 | x1.50 |
| `fw_reactive_plating` | Rare | `plating_pct` +3 pts | +15 pts |
| `fw_nano_surge` | Rare | `nano_repair` x1.15 | x1.75 |
| `fw_thorn_mesh` | Rare | `spike_return` +5 pts; at 3+ stars also reflects ranged hits | +25 pts |
| `fw_pace_trimmer` | Rare | Lull -10% (6 s -> 5.4 s) | -50% (3 s) |
| `fw_slow_aura` | Rare | Enemies within 20 m move -8% | -25% |
| `fw_swarm_bait` | Rare | Spawn count x1.2, `scrap`/`data` per kill x1.10 | x1.6, x1.30 |
| `fw_overdrive_governor` | Epic | Overdrive charge +15% | charge +45%; at 3+ stars auto-triggers at full meter when integrity > 40% (25% at 5 stars) |
| `fw_aegis_charge` | Epic | 1 charge (lethal hit negated; +1 per 20 waves) | 3 charges |
| `fw_reboot` | Epic | Once per run revive at 50% integrity, 10 s invulnerable | 70%, 14 s |
| `fw_meltdown` | Epic | Once per run: 15 s invulnerable, `laser_output` x30, integrity 25% | 21 s, x70 |
| `fw_purge` | Epic | Once per run: 500% shot arc damage to non-boss within 30 m + 6 s invulnerable | 1,500%, 40 m, 9 s |
| `fw_wave_skipper` | Epic | At each wave end 3% chance the next wave spawns nothing and counts as cleared (pays 110% of wave bonuses; levels rise normally) | 15% |
| `fw_turncoat` (Post-launch, with N5) | Epic | `turncoat_chance` 5% | 25% |
[CIS 6 cards; renames: Energy Shield -> `fw_aegis_charge`, Second Wind -> `fw_reboot`, Demon Mode -> `fw_meltdown`, Nuke -> `fw_purge`, Wave Skip -> `fw_wave_skipper`, Enemy Balance -> `fw_swarm_bait`.] Rarity counts: Common 5, Rare 13, Epic 6 (+1 Post-launch).

## 5. Hardware modules - tag: Post-launch [META Modules]

- Four slot types: `slot_weapon`, `slot_plating`, `slot_reactor`, `slot_cortex`; one module equipped per slot.
- Rarity ladder: Common (level cap 10), Uncommon (20), Rare (30), Epic (40), Prototype (50). Rarity multiplier on effect: x1.0, x1.5, x2.2, x3.2, x4.5.
- **Fusion (simpler than shards):** 3 modules of the same slot and rarity -> 1 module of the next rarity with an effect chosen from 3 offered. Commons and Uncommons fuse; Prototype is the top. No shards and no reroll currency; effect reroll costs `data` (`1e3 * 3^reroll_count`).
- Module level costs `data`: `ceil(500 * 1.25^L)`.
- Sources: boss drops (Common 2%, Uncommon 0.3% per boss kill, +Lab bonus), convoy drops (Post-launch), Gauntlet and Operation Pass rewards (Rare+), event shop (`merit`). Unwanted modules salvage to `data` (`50 * rarity_index^2 * farm_rate_minutes`... a simple fixed table in data files).
- 12 effects (3 per slot), value at Common (x rarity multiplier):
| id | Slot | Effect (Common) |
|---|---|---|
| `mod_focus_lens` | weapon | `crit_mult` +0.15 |
| `mod_capacitor` | weapon | Overdrive charge +10%, duration +0.4 s |
| `mod_rail_coil` | weapon | `standoff` x1.10, `optic_range` +1 m |
| `mod_ablative_shell` | plating | `plating_pct` +2 pts |
| `mod_ceramic_weave` | plating | `hull_integrity` x1.08 |
| `mod_spike_array` | plating | `spike_return` +3 pts |
| `mod_fusion_cell` | reactor | `nano_repair` x1.10 |
| `mod_scrap_loom` | reactor | `scrap_yield` x1.05 |
| `mod_data_tap` | reactor | `data_yield` x1.05 |
| `mod_threat_matrix` | cortex | `laser_output` x1.05 and `sensor_reach` +2 m |
| `mod_lag_injector` | cortex | `signal_lag_hp` and `signal_lag_atk` +0.5 pts |
| `mod_swarm_decoder` | cortex | Adaptation gain -6%, cap -3% |

## 6. Companion drones (bot equivalent) - tag: Launch [META Bots]

Four companions that orbit Cinder and fire an ability automatically on a timer. They are bought with `merit` (unlock prices 150, 300, 600, 900; recommended order scav, amp, volt, ember; mirrors the research's escalating bot prices [META Bots]), leveled with `data` (levels 1-10, `ceil(2e4 * 1.35^L)` per level), and persist across seasons. **Equip slots: 2** at Launch (3rd slot Post-launch via Operation Pass milestone). Respec of equipped drones is free (no reset fee) - changed from The Tower's 300-gem respec [META Bots].
| id | Ability (level 1) | Cooldown (s) | Per-level scaling | Notes |
|---|---|---|---|---|
| `drone_ember` | Fire burst radius 10 m, 150% shot damage (`blast`) | 20 | +10% damage, -3% cooldown | |
| `drone_volt` | Stun pulse radius 14 m, 2 s (bosses excluded) | 25 | +0.1 s stun, -3% cooldown | |
| `drone_scav` | Collects all `salvage_cache` automatically; every 40 s grants `scrap` x2 for 10 s | 40 | +0.5 s duration, -3% cooldown | helps idle play |
| `drone_amp` | Damage +50% for 8 s | 30 | +4% bonus, -3% cooldown | Overdrive stacks multiplicatively |
Bot+ equivalent (Post-launch): `cipher` unlocks a second ability at level 10.

## 7. Unlock order (gating)

Progress key: best wave reached in Sector 1 (`best_s1`) unless marked.
| Order | Trigger | Unlocks |
|---|---|---|
| 1 | Start | Run upgrades: `laser_output`, `cycle_rate`, `hull_integrity`, `nano_repair`; Foundry for those four (MVP). Tap/hold buying (07 s2.2). |
| 2 | First death | Foundry screen (tutorial) |
| 3 | `best_s1` 3 | Run: `scrap_yield` |
| 4 | `best_s1` 4 | `scrap_per_wave` |
| 5 | `best_s1` 5 | `crit_chance` |
| 6 | `best_s1` 6 | `data_yield` |
| 7 | `best_s1` 8 | `crit_mult`, `data_per_wave`, `pod_chance`, `pod_amount`; Patches (drafts) from wave 10 if reached |
| 8 | `best_s1` 10 | `optic_range`, `plating_pct` |
| 9 | `best_s1` 12 | `reinvest`, `push_chance`, `push_force` |
| 10 | `best_s1` 15 | `split_chance`, `split_targets`, `free_arms` |
| 11 | `best_s1` 20 | `standoff`, `spike_return`, `free_chassis`; Skin Burn exposure bonuses; Adaptation begins affecting at wave 20 |
| 12 | `best_s1` 25 | R&D Lab (slot 1), `plating_flat`, `free_systems`, `sensor_reach` (first `shade`) |
| 13 | `best_s1` 30 | `burst_chance`, `burst_duration`, `siphon_cell`; Sector 2 unlock; Standby Patrol; Overdrive |
| 14 | `best_s1` 35 | `razor_count`, `razor_speed` |
| 15 | `best_s1` 40 | `ricochet_chance`, `ricochet_targets`, `signal_lag_atk/hp`; Ops Board (missions) |
| 16 | `best_s1` 50 | Lab slot 2; firmware (3 slots) and first free pick; `shock_size`, `shock_rate`; first weapon-system offers (first system free); Salvage cache drops from elites; Sector milestone Premium offer |
| 17 | `best_s1` 60 | `mine_chance`, `mine_damage`; Gauntlet (tournaments, P1) |
| 18 | `best_s1` 70 | `fail_safe`; Incursions (events, P1); Cells (P2) |
| 19 | `best_s1` 80 | `barricade_hp`, `barricade_rebuild` |
| 20 | `best_s1` 100 | `overcrit_*`; Companion drones shop |
| 21 | `best_s1` 150 | `armor_tear_*` |
| 22 | Sector 3 clear w30 | Weapon slot 2 etc. as in section 3 |
| 23 | Sector 5 | Hardware modules (Post-launch) |
| 24 | Sector 8 | Convoys (Post-launch) |
Note: the Gauntlet at `best_s1` 60 matches the research pattern (events at S1 w70, tournaments at tier 1 w60 [ECON 4]).

## 8. Target progression timeline (free player, engaged, ~35 min/day)

| Time | Expected state | Sessions / feel |
|---|---|---|
| First session (0-12 min) | 3 runs; best S1 w20-25; Foundry on laser/hull/cycle; Patches seen once (waves 10, 20); first firmware tease not yet | Hook: wave 10 patch draft in run 1-2, first death after ~3 min, Foundry spend, run 2 better |
| Day 1 | Best S1 w35-45; Sector 2 unlocked (w30); Standby Patrol on; Lab slot 1 (w25); Ops Board; ~6e3 `data`; ~150 `flux` | 3 sessions of 10-15 min; first overnight research |
| Week 1 | Best S2 w45; Sector 3 unlocked; Lab slot 2; first 3 firmware slots; 1-2 weapon systems; first Gauntlet (Copper/Rivet) ~day 4; ~3e5 `data` | Habits form: missions + 2 timers/day |
| Month 1 | Best S4-S5 w40-60; 4-6 weapon systems; ~15 firmware chips at 1-3 stars, 5-6 slots; first companion; Lab 3 slots; Foundry F~100; ~2e7 `data` | Build identity (adaptation matters), Gauntlet league Alloy/Carbon |
| Month 6 | Best S8-S9 w100-150; all weapon systems except last 1-2; ~20 chips, 7-8 slots, many at 4-5 stars; modules (Post-launch) fill; Foundry F~185; ~1e10 `data` | Long goals: sector 10+, star ranks, league promotion |
Success is judged by the headless simulation matching these within +-30% wave.

## 9. Tags summary

| System | Tag |
|---|---|
| Foundry, 4 stats | MVP |
| Foundry, all rows | Launch |
| R&D Lab | Launch |
| Weapon systems (9) | Launch |
| Firmware chips (24) | Launch |
| Companion drones (4) | Launch |
| Hardware modules | Post-launch |
| Weapon UW+/companion Plus | Post-launch |
| Standby Patrol | Launch |
| Convoys, sectors 13-24 | Post-launch |
