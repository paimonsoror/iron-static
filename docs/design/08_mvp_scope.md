# 08 - MVP Scope

Changelog: 2026-11-10 - section 1.7: Skin Burn damage-taken hardening (x0.85 / x0.70 / x0.55 in bands 1 / 2 / 3) is the first band modifier, added by R1-05; the other modifiers stay out - 2026-11-07 - number type changed to BigNum for currency/cost values from ROADMAP M2 (section 5); milestone sequencing superseded by `docs/ROADMAP.md` (section 3 note); MVP gate = end of ROADMAP M5, where FC1-FC12 are run; N2 approved, N1/N3/N4 approved for Launch, N5 deferred.

Purpose: the smallest playable build that proves the core loop is fun, playable on an Android emulator within the first few milestones. If this build is not fun, nothing else matters. The MVP deliberately contains **one sector, five enemies, ten run upgrades, two currencies, one meta screen and a small patch draft**.

All ids below are final ids from the other documents. Tag meanings are in 00 section 8.9.

---

## 1. Included (exact lists)

### 1.1 Core loop
- Deployment loop per 02 sections 1-6: arena, Cinder at center, auto-fire hitscan laser, wave timer 24 s (18 s spawn + 6 s lull), `N(w)`, spawn ring 52 m, nearest-target rule, death, results, redeploy.
- Damage pipeline: 02 section 8 steps 1-3, 4 (only global multipliers that exist in MVP: patches, Foundry), 5 (crit), 9 (floor/final), 10 (display rule). Steps 6, 7, 8 (overcrit, armor tear, enemy-side reductions) are cut.
- Intake pipeline: 02 section 12 steps 2-4 and 6 (no barricade, no reflect, no death-prevention chain except death itself).
- End-of-wave order: steps 1, 2, 6 (level increment, no skips), 7 (boss check), 5 (draft).
- Deterministic simulation with a run seed (required for later Gauntlets and for the headless balance sim).

### 1.2 Enemies (5)
`skitter`, `dart`, `lancer`, `walker`, `boss_hulk` (no plates). First waves per 03: skitter w1, dart w4, lancer w6, walker w8, boss every 10 waves. Spawn weights and slot costs per 03 section 5 (shade, jammer, mender, aegis_node excluded). Enemy scaling: `G_hp`, `G_atk` phases 1 and 2 (phase 3 implemented but unreachable in MVP tuning). Melee overclock bite: included. Stale-kill 50% rule: included. Elites, convoys, sector conditions: cut.

### 1.3 Run upgrades (10), tab layout
- ARMS: `laser_output`, `cycle_rate`, `crit_chance`, `crit_mult`, `optic_range`.
- CHASSIS: `hull_integrity`, `nano_repair`, `plating_pct`.
- SYSTEMS: `scrap_yield`, `reinvest`.
- Costs/caps/gates per 02 section 7. Unlock gates use best wave: all 10 are visible by `best_s1` 12 (gates 0, 0, 5, 8, 10, 0, 0, 10, 3, 12). Buy x1 / x10 / x100 / Max included. Milestone ring at every 25 run levels included. Intel tab: Stats panel and Wave panel only.

### 1.4 Currencies (2)
`scrap` and `data`. No `flux`, `cipher`, `merit` in the UI. Starting `scrap` = 20. `data` per kill and per wave per 03 section 3 (no `data_per_wave`/`data_yield` upgrades; `patch_extraction` and `patch_t_greed` affect `data`).

### 1.5 Patches (drafts) (9)
Draft waves per 02 section 10 (10, 20, 30, 40, 50, 75, 100, ...). 3 offers (70% standard, 15% gamble; the weapon-system 15% share goes to standard since no weapon systems exist). Included patches: standard `patch_overcharge`, `patch_plating`, `patch_rate`, `patch_extraction`, `patch_regen`, `patch_ceramic`; gamble `patch_t_glass`, `patch_t_greed`, `patch_t_hardhide`. Manual pick only (no auto-pick).

### 1.6 Meta feature (1)
**Foundry** with 4 rows only:
| id | Type | f / f_inc | F cap | fc0 | fg |
|---|---|---|---|---|---|
| `laser_output` | D | 0.06 | 200 | 20 | 1.10 |
| `hull_integrity` | D | 0.06 | 200 | 20 | 1.10 |
| `nano_repair` | D | 0.05 | 200 | 25 | 1.10 |
| `cycle_rate` | C | 0.04 | 50 | 50 | 1.12 |
Costs and multipliers per 05 section 1. Local persistent save (best wave, `data`, Foundry levels, settings). A "Recommended" glow on the cheapest row.

### 1.7 UI and feel
- Portrait layout: battlefield top 56%, panel bottom 44% (07 section 2.1) with the three upgrade tabs and cost buttons, wave/scrap/integrity HUD, speed button (1x/2x), pause.
- Home screen with DEPLOY and best wave; results screen; Foundry screen.
- Machine-vision vector look with the palette in 07 (enemy outline red on dark fill, amber HUD, Cinder bright center, beam line). Procedural shapes only.
- **Skin Burn visuals (N2, approved) included**: 12 skin wedges, four bands, embers and heartbeat/vignette at band 3. Modifiers (damage/regen bonuses) are NOT included in MVP (visual only), with one exception added by R1-05 (2026-11-10, review G-03): the frame hardens as the skin burns, damage taken x0.85 / x0.70 / x0.55 in bands 1 / 2 / 3 (`burn_dr_b1..3`, 02 section 12.1).
- Damage numbers per 07 section 5.5 (crit + milestone + cap rule).
- FTUE minutes 0-10 per 07 section 3 (without Lab/notification beats).
- Audio: placeholder SFX (laser shot, hit, enemy death, player hit, upgrade buy, wave start, boss warning, death, UI tap) and one looping ambient music track.
- Settings: sound, music, reduce motion, number format.

### 1.8 Dev tooling required with MVP
- A headless run simulator using the same simulation code (no rendering) that can play N runs with a scripted buy policy and output best wave, `data`, time. Needed to tune 03/04 numbers.
- Debug overlay: FPS, entity count, wave, enemy level, current formulas outputs.
- Data-driven tables for all numbers in 02/03/05 (ids as keys) so tuning needs no code change.

## 2. Explicitly cut (not in MVP)
Sectors 2-12 and sector selection; elites; all convoys; `aegis_node`, `shade`, `jammer`, `mender`; boss variants other than `boss_hulk`; battle conditions; adaptive swarm (N1) and damage types other than `laser` (kinetic, arc, blast, nano exist only in data); Overdrive (N4); salvage caches (N3); turncoat (N5, deferred to post-launch); weapon systems; companion drones; firmware; hardware modules; R&D Lab; Standby Patrol; Ops Board missions; Gauntlets; Incursions; Cells; Operation Pass; shop and all IAP; ads; `flux`, `cipher`, `merit`; cloud save and accounts; analytics beyond a local log; localization (English only, strings in a table); free upgrade rolls; interest cap lab; signal lag; log fragments and story cards (only the 3 opening lines); app-store assets.

## 3. Milestones to emulator playability (suggested order)

Note (2026-11-07): `docs/ROADMAP.md` supersedes this order and adds M0 (foundation) in front. Mapping: GDD M1 = ROADMAP M1 (which already includes all five MVP enemies and `boss_hulk` because content is data-driven); GDD M2 = ROADMAP M2; GDD M3 = ROADMAP M3; GDD M4 and M5 = ROADMAP M4 (patches, draft, feel, FTUE); GDD M6 = ROADMAP M5 (balance, perf, fun checks). The fun checks below are run at the end of ROADMAP M5, which is the MVP gate.
| M | Deliverable | Done when |
|---|---|---|
| M1 | Arena + Cinder + hitscan laser + skitter spawn ring + death | On the emulator: waves 1-3 run, Cinder auto-fires, losing integrity ends the run |
| M2 | Scrap, upgrade panel with 5 rows (laser_output, cycle_rate, hull_integrity, nano_repair, scrap_yield), cost formula, buy x1/x10/Max | Player can buy upgrades and the difference is visible in kill speed |
| M3 | Results, `data`, Foundry (4 rows), local save, redeploy | Foundry purchase persists across app restarts; run 2 is measurably stronger |
| M4 | Dart/lancer/walker/boss_hulk, remaining 5 upgrade rows, patches (9), draft UI | Wave 10 draft opens; boss at wave 10 spawns and can be killed |
| M5 | Skin Burn visuals, damage numbers, juice (hit sparks, kill shatter), 2x speed, placeholder audio, FTUE prompts | Visual and feel pass; first 10 minutes match 07 section 3 |
| M6 | Headless simulator + first balance pass against 03 section 6 targets; perf pass | Fun checks below executed; numbers within +-30% of targets |

## 4. Acceptance criteria ("fun checks")

Use 10 playtesters (mixed idle-game experience) on a mid-range Android device unless stated. "Pass" thresholds are first-pass.

| # | Check | How measured | Pass |
|---|---|---|---|
| FC1 | First run length and death | Timer from deploy to death for a fresh account with default prompts | 2-4 min; death at wave 9-14 for 8/10 testers |
| FC2 | Immediate understanding | Count of upgrades bought in the first 60 s with no text beyond the pointer | >= 2 for 9/10 testers |
| FC3 | Permanent progress is felt | Compare run 1 vs run 2 after one Foundry purchase session | run 2 best wave >= run 1 + 4 for >= 8/10; >= 7/10 can explain "permanent vs temporary" |
| FC4 | Redeploy loop | Unprompted redeploys in a 15 min session | >= 3 for 7/10 testers |
| FC5 | Readability | Show a frozen wave-50 screenshot (31 slots) for 1 s; ask to name the 3 enemy types | >= 8/10 correct; "which is dangerous" identified for lancer by 7/10 |
| FC6 | Performance | Reference device (4 GB RAM class, 1080x2400) | >= 55 FPS with 100 enemies and active beam; >= 30 FPS at 160 enemies; cold start <= 3 s to Home |
| FC7 | Patch choice | Wave-10 draft test | >= 6/10 can state each patch's effect; gamble patch chosen 15-50% of the time (not never, not always) |
| FC8 | Skin Burn legibility | Ask "what state is Cinder in?" mid-run | >= 8/10 correctly identify low-health band without reading numbers; no visible flicker at band thresholds |
| FC9 | Idle tolerance | Zero taps after the first two upgrades, 2x speed | Run still reaches wave >= 8 (so AFK is possible but suboptimal) |
| FC10 | Balance math | Headless sim of 1,000 runs per Foundry state | Median best wave within +-30% of 03 section 6 table for multipliers x1, x2, x4, x10 |
| FC11 | Determinism | Replay a seed twice (and at 1x vs 2x) | Identical outcomes (needed for tournaments and sim) |
| FC12 | Feel | "Would you play another run?" | >= 7/10 yes after 15 minutes |
**Kill/rework criteria:** if FC1, FC3 or FC4 fail, adjust base numbers, early curves and FTUE before building more meta. If FC5/FC6 fail, simplify shapes/glow before adding enemies. Meta layers (firmware, lab, weapons) start only after FC1-FC4, FC6 and FC10 pass.

## 5. Compatibility with other work
- Data tables (stats, costs, enemy tables, scaling constants) must be machine-readable and keyed by the stable ids in 00 section 8 so the technical architecture can load them from data files. Formulas (`G`, `N`, `D`, `foundry_mult`, cost) are specified in pseudocode in 02, 03 and 05.
- The simulation must be deterministic from `(seed, config, input log)`; speed multipliers must not change outcomes.
- Number type (changed 2026-11-07, 09 Q5): currency and cost values use a BigNum type (TECH_ARCHITECTURE section 3) from ROADMAP M2 and persist as strings, so the save format never needs a breaking migration; per-tick combat math (enemy HP, damage, stat values) stays double precision. The earlier "double is sufficient for MVP" statement is withdrawn.
- No technology choices are prescribed here; see TECH_ARCHITECTURE.md for the technical design.
