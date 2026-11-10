# IRON STATIC - independent review (Fable, 2026-11)

Reviewed: branch `m4-review` at `951269d` (main after FO-3, SimVersion 5), 2026-11-10. Scope: gameplay, image quality, code efficiency, in that order of weight. Method: reading the GDD, architecture and task files; reading `src/`; the committed playtest and perf evidence; headless journeys and experiments on the committed build; my own 1080x2400 renders through the debug harnesses. Nothing under `src/`, `data/`, `tests/`, `tools/` or `assets/` is changed by this commit. Evidence files are in `docs/review/fable/` (`logs/`, `scripts/`, `renders/`).

## 1. Verdict

**Where it stands.** IRON STATIC is a carefully engineered, good-looking shell around a loop that does not yet give a person much to decide, to watch, or to come back for. In four days the project built a deterministic sim, a safe save system, a measurement tool chain and an art kit that many shipped idle games lack. What sits on top is the generic layer of the genre: ten stat rows, four permanent rows and nine stat patches. The parts of the project's own design that would make it distinct (the burn state as a mechanic, the swarm that adapts, anything the player actively does) are scheduled for M6.

The measurements are plain:
- On a fresh profile a random buyer does as well as the optimizing bot (11.9 against 11.7 waves). The wave-10 patch draft, the intended hook of run 1, changes the result by 0.3 waves.
- Cinder's skin-burn states, the signature of the game, are on screen for 12 seconds of a 4.5 minute first run and 13 seconds of a 30 minute late run. Death is a cliff, so defense is a trap and one patch family is always right.
- The field never holds more than about 35 enemies and kills come at under one per second. The single-target beam, not the spawn table, is what prevents a swarm.
- Everything unlocks within the first 15-20 minutes. By the second day a run takes 15 minutes at 2x, of which the first 40 % can not hurt Cinder. From day 5 to day 10 the simulated player sets no new best and ends up with Data they are not allowed to spend.

**Biggest risk.** The open beta. The build has about one session of novelty, no mechanism to bring a player back the next day, a progression wall inside the first week, no way to see what testers did, and no recorded human playtest behind it. An open test collects public ratings on exactly the part of the product that is weakest. The code and the release pipeline are ready; the game is not.

**Biggest opportunity.** The fix is not more meta systems, and most of it is already written in the GDD. Make the burn bands a state the player chooses to hold. Let the player of a targeting HUD designate targets. Let CHORUS answer the build. Put a real crowd on the field: the sim has about 25 times the headroom it uses. Because content is data-driven and the journey simulator exists, each of these is days of work and can be measured the same evening. Spend the next milestone on the ten minutes in the middle of a run, and hold Lab, firmware and backend work until people replay that middle by choice.

## 2. Top 10 shortlist

Ranked by value for effort.

| # | ID | Title | Impact | Effort |
|---|---|---|---|---|
| 1 | O-01 | Run the human fun checks (5-8 people, one phone) before the open test goes public | H | S |
| 2 | G-05 | Remove dead time: 4x/8x speed with auto fall-back, then deep deploy | H | S |
| 3 | G-02 | Drafts: first at wave 5, one card per family, one reroll; then rule-changing patches | H | S then M |
| 4 | G-03 | Make Skin Burn a played state: the frame hardens, burn pays, VENT lever | H | S then M |
| 5 | G-06 | Replace the hard Foundry cap with a soft one and give Data a second sink (the simulated player sets no new best from day 5 to day 10) | H | S |
| 6 | G-07 | Extend the unlock ladder to wave 100 and show the next unlock on Results | H | S-M |
| 7 | G-04 | Double the body count now; pull split and area fire forward, then go to a real swarm | H | M |
| 8 | G-08 | A reason to return: relay signal of the day, standing orders, minimal Standby Patrol | H | M |
| 9 | G-10 | One identity verb: designate targets (or protocol chip), CHORUS counts | H | M |
| 10 | I-03 + I-04 + I-05 | Beam afterglow, draft cards with icons and real numbers, readable secondary text | M | S |

The code findings do not make the top ten. That is the result, not an omission: C-02 (checkpoint hitch) and C-04 (cold start, unmeasured on a phone) are the two worth scheduling before the beta.

## 3. Findings

### Gameplay

How the numbers in this section were produced. All runs are headless on the committed build (951269d), no data or code changed, one Godot process at a time.
- `tools\journey_run.ps1 -Spend recommended -Deployments 16 -Seed 1 -Name rev_rec -SkipImport` and the same with `--deployments 40` (logs: `docs/review/fable/logs/journey16.csv`, `journey40.txt`, `journey40.csv`).
- Two temporary experiment scripts, deleted from `tools/` before the commit and kept as `docs/review/fable/scripts/rev_exp.gd.txt` and `rev_exp2.gd.txt`. Run as `godot --headless --path . -s res://tools/_rev_exp.gd -- <dist|policy|draft|late|perf>` and `-s res://tools/_rev_exp2.gd -- <bands|swarm>`. They build configs through `BalanceSetup.make_config` and play with the real `PolicyBot`, `UpgradeSystem` and `DraftSystem`.
- Three reference profiles: **fresh** (no Foundry; best wave 12 so all ten rows are visible), **mid** (Foundry L21 C16 H21 N21, best wave 35: the state of the journey after about 45 minutes of 2x play) and **late** (L42 C27 H41 N39, best wave 72: the state after about 2 hours of 2x play). 30 seeds per cell unless stated (the 40-seed distribution run used best wave 0 for the fresh profile, so only the four starting rows).
- A bot is not a person. Bot results bound what choices can be worth; they do not measure fun. See O-01.

#### G-01 In the first sessions it does not matter what the player buys; later it matters a little
- **Evidence** (`logs/exp_policy.txt`, mean death wave, 30 seeds):

  | Buy policy | Fresh | Mid |
  |---|---|---|
  | Optimizer over the 4 core rows (`greedy4`) | 11.7 | 45.5 |
  | Optimizer over all 10 rows (`all`) | 11.8 | 49.5 |
  | Always buy the cheapest row | 11.9 | 40.4 |
  | Buy a random affordable row | 11.9 | 40.3 |
  | Buy nothing | 8.2 | 20.5 |

  On a fresh profile a random buyer is as good as the optimizer (11.9 against 11.7), and the whole distribution is 10-14 waves wide with a median of 12 in every policy. In mid game a perfect optimizer beats a random buyer by 23 %. A fresh run contains 16-21 purchases in 4.5 minutes; a late run about 140 purchases in 29 minutes, under 5 per minute at 1x (`logs/exp_late.txt`).
- **Why it matters.** GDD 00 pillar 3 is "Builds with consequences. Builds are chosen, not defaulted to." Today the only choice with a consequence is whether to tap at all. A player feels that within two or three runs, even without being able to say it: nothing they try produces a different result. This is the root finding; most of the others are ways to fix it.
- **Recommendation.** Do not tune the ten stat rows further. Add things that change *how* Cinder fights, so that two players at the same wave look and play differently (G-02, G-04, G-10, G-11). As a cheap honesty check, add `random` and `cheapest` policies to `balance_run` and gate on "the optimizer beats random by at least 25 % on a fresh profile"; if a new system does not move that number it is not adding choice.
- **Impact** H, **effort** M (through the findings below), **risk** low.

#### G-02 Patches: invisible when the player first meets them, then the biggest lever in the game, and one answer is always right
- **Evidence** (`logs/exp_draft.txt`, mean death wave, greedy4 buyer, 30 seeds):

  | Draft policy | Fresh | Mid |
  |---|---|---|
  | No drafts at all | 11.4 | 35.9 (range 34-44) |
  | Take the first offer | 11.7 | 45.5 (range 30-57) |
  | Prefer OVERCHARGE (laser) | 11.7 | 47.8 |
  | Prefer RAPID CYCLE | 11.8 | 48.5 |
  | Prefer PLATING (hull) | 11.8 | 42.0 |
  | Prefer NANO REGEN | 11.6 | 41.9 |
  | Prefer CERAMIC | 11.6 | 41.6 |
  | Prefer EXTRACTION | 11.7 | 44.6 |
  | Always take a gamble if offered | 12.1 | 42.9 (min 27) |

  1. **Fresh:** the wave-10 draft changes the result by 0.3 waves. The first draft opens at the end of wave 10 (`data/sim_constants.csv`, `draft_first_wave`), and a first run dies at wave 10-12 (40 seeds: 3 die at wave 10 and never see a draft; `logs/exp_dist.txt`). GDD 05 s8 calls the wave-10 draft the hook of run 1-2. It is a menu shown one wave before death that changes nothing.
  2. **Mid:** drafts are worth +10 waves on average, more than the whole difference between a random and an optimal buyer (G-01).
  3. **One answer:** the two fire-power patches give +12 waves, the three defensive ones +6. With 9 patches and 6 standard ones there is no situation where PLATING is the right pick over RAPID CYCLE.
  4. **Luck, not choice:** which offer the player picks moves the mean by 1.5 waves (first 45.5, last 43.9, safe 44.9), but the spread with drafts is 30-57 against 34-44 without. The mid distribution is two clusters, 30-38 and 45-57 (`logs/exp_dist.txt`, "mid" line). The low cluster sits at the no-draft level, that is, runs whose picks did not help. Preferring a fire-power patch raises the median to 49-51 but leaves the bottom decile at 36-37, which is what happens if those seeds do not offer one early; there is no reroll. In the journey the same Foundry levels die at wave 27 in one run and wave 53 in the next (deployments 10 and 11). To the player this reads as the game being random.
- **Why it matters.** The draft is the only moment in a run that is presented as a decision (the game pauses, three cards appear). It needs to be felt in run 1 and be a real choice in run 50.
- **Recommendation.**
  1. First draft at wave 5, then 10, 15, 20, then every 10 (`draft_first_wave`, `draft_interval`). Run 1 then holds two drafts and the first is early enough to matter.
  2. Structure the offer: one ARMS, one CHASSIS, one SYSTEMS card per draft (plus the gamble roll), so the question is "what does this run need" and offer luck stops deciding the run. Add one reroll per draft.
  3. Replace half of the stat patches with rule patches that only this setting can have. Each should be visible on the field:
     - **SPLIT LENS**: the beam forks to a second target at 50 % damage (the GDD's `split_*`, pulled forward).
     - **ARC RETURN**: a kill inside 8 m sends a spark to the nearest enemy.
     - **HOT PLATES**: melee attackers take damage equal to a share of the hit while Cinder is in burn band 1 or deeper (ties to G-03).
     - **RELAY PULSE**: every 10th shot is a ring that hits everything inside half optic range.
     - **CHORUS JAMMER**: lancer bolts fly 40 % slower and the beam shoots bolts down when no enemy is in range.
     - **COLD CORE**: no regeneration; hull damage taken is halved (a defensive patch that is a real alternative).
     - **OVERWATCH**: the first shot at each new target is a guaranteed crit (LONGSHOT's passive as a patch).
  4. Make defense worth taking by fixing what makes it worthless (G-03).
- **Alternative.** Keep the nine patches and only do steps 1 and 2. That fixes the "inert in run 1" and "luck" problems for a day of work, but not the "one answer" problem.
- **Impact** H, **effort** M (steps 1-2 S), **risk** SimVersion bump; balance targets move.
- **Challenges a recorded decision:** GDD 02 s10 (draft waves 10, 20, ...; random offers, no reroll) and 08 s1.5 (the nine MVP patches).

#### G-03 Skin Burn, the signature of the game, is on screen for a few seconds per run; death is a cliff
- **Evidence** (`logs/exp2_bands.txt`, 20 seeds per profile, mean seconds at 1x):

  | Profile | Run length | Band 0 (intact) | Band 1 | Band 2 | Band 3 | Last time at 75 %+ hull to death |
  |---|---|---|---|---|---|---|
  | Fresh | 270 s | 258 s | 5.4 s | 2.8 s | 4.3 s | 10.3 s |
  | Mid | 1,131 s | 1,108 s | 12.2 s | 6.7 s | 4.0 s | 13.8 s |
  | Late | 1,773 s | 1,760 s | 5.8 s | 3.9 s | 3.4 s | 8.2 s |

  Cinder is intact for 96 %, 98 % and 99 % of a fresh, mid and late run. All three burn bands together are on screen for 12.5, 22.9 and 13.1 seconds.

  In ten late runs the wave where hull first fell below 50 % was the death wave itself in 6 runs, one wave earlier in 2, and two and five waves earlier in the other 2 (`logs/exp_late.txt`, `half_hp_wave` against `death`).
- **Why it matters.** The pitch is "Burn away what is left of being human", pillar 2 is "Escalation you can see", and FC8 tests whether players can read the burn bands. The four-band rig, the embers, the heartbeat vignette and the haze are the most original art in the game, and a player sees them for about 12 seconds in a 4.5 minute run, at 2x for 6 seconds, while looking at the upgrade panel. There is also no tension arc: the run is safe, then over. The same cliff is why defense is worthless (G-02, G-11): hull and repair do not buy time, because once enemy damage passes regeneration the end takes seconds.
- **Recommendation.** Make the burn bands a place the player lives in and chooses to stay.
  1. **The frame hardens as the skin burns** (the pitch already says "degrades and hardens"): damage taken x0.85 / x0.70 / x0.55 in bands 1 / 2 / 3. The last 75 % of the hull then lasts roughly twice as long, and plating and repair start to matter because time in the bands scales with them.
  2. **Burn pays**: laser output +10 % / +25 % / +45 % and Data yield +10 % / +20 % / +35 % in bands 1 / 2 / 3 (GDD 02 s12.1 plans small modifiers for Launch; pull them forward and make them large enough to plan around).
  3. **Give the player the lever**: a VENT button that stops nano repair while held or toggled, so a player can sit in band 2 on purpose for the bonus and release it when a boss arrives. This is the Overdrive idea (N4) expressed through the game's own signature instead of a generic meter. It is one command type in the input log and stays deterministic.
  4. Slow repair while enemies are in melee contact so the fight is a tug of war that can be watched, not an invisible race between two numbers.
- **Alternative.** Only do step 1 (one multiplier per band in `CinderState.apply_hit`, `src/sim/cinder_state.gd:27`). It is a half-day change that at least lets players see the art.
- **Impact** H, **effort** M (step 1 alone S), **risk** balance shifts later waves; re-run the journey.
- **Challenges a recorded decision:** GDD 08 s1.7 ("Skin Burn modifiers are NOT included in MVP (visual only)") and 02 s13 (N4 Overdrive at Launch).

#### G-04 There is no swarm: 20-35 enemies at most, under one kill per second
- **Evidence.**
  - Late runs: peak alive enemies 21-37, about 1,300 kills in 29 minutes = 0.75 kills per second (`logs/exp_late.txt`).
  - Real captures: wave 9, three enemies on screen (`docs/playtests/m4/m4_27/bw18.jpg`); the wave-10 boss with three skitters (`boss_warning_banner.jpg`); wave 13, six (`docs/playtests/m4/modes/modes_s7_purge_wave13_smoke.jpg`). My render of a bot-played run on the current build: `docs/review/fable/renders/battle_real_wave8.jpg` (I-01).
  - Cause: `N(w) = 4 + 2.4 * w^0.6` (13 slots at wave 10, 29 at wave 50, a walker costs 3), spawned evenly over 18 s (`src/sim/systems/wave_planner.gd`, `_fill_normals`: `secs = spawn_seconds * (used + u) / budget`), and one hitscan beam that hits one target (`src/sim/systems/laser_system.gd:28`). A "wave" is a steady drip with a pause.
  - Experiment, same total HP, damage and rewards per wave split over k times as many bodies (`logs/exp2_swarm.txt`, 12 seeds):

    | Profile | Bodies | Mean death wave | Peak alive | Kills per second | Sim tick |
    |---|---|---|---|---|---|
    | Fresh | x1 | 11.6 | 13 | 0.36 | 0.045 ms |
    | Fresh | x2 | 12.8 | 25 | 0.78 | 0.059 ms |
    | Fresh | x4 | 4.0 | 39 | 0.91 | 0.076 ms |
    | Mid | x1 | 46.7 | 22 | 0.64 | 0.062 ms |
    | Mid | x2 | 43.8 | 43 | 1.26 | 0.073 ms |
    | Mid | x4 | 11.1 | 59 | 1.47 | 0.102 ms |
    | Late | x1 | 74.0 | 27 | 0.78 | 0.071 ms |
    | Late | x2 | 73.8 | 50 | 1.58 | 0.082 ms |
    | Late | x4 | 26.5 | 127 | 1.91 | 0.137 ms |

    Twice the bodies costs nothing: the death wave moves by less than 3 waves and the kill rate doubles. Four times the bodies collapses the run (a fresh Cinder dies at wave 4), because a single-target beam can never kill more enemies per second than it fires shots (1 per second at the start, about 2 late). **The weapon, not the spawn table, is what forbids a swarm.** This was a sensitivity test with scaled constants (`n_base`, `n_coef`, `n_cap` x k; `hp0`, `d0`, `scrap_k`, non-boss `data_base` / k), not a balance proposal.
- **Why it matters.** The store text says "rogue machine swarms attack from every side". The art, the density-based glow, the 160-enemy caps and the performance work were all built for a crowd. The player gets a quiet radar screen with a few blips. A crowd melting is the core pleasure of this genre and it is absent.
- **Recommendation.**
  1. Now: double the body count at equal total wave HP (`n_base`, `n_coef`, `hp0`, `d0`, `scrap_k`, `data_base`). The experiment says it is close to balance-neutral; confirm with the journey tool. The sim cost is irrelevant (C-01).
  2. Then make the weapon able to face a crowd, because the single-target beam is the ceiling: pull `split_chance` / `split_targets` (GDD 02 s7.1, unlock at best wave 15 in 05 s7) and one area effect (`shock_size` ring or the RELAY PULSE patch from G-02) forward from M6, and raise the body count again to x4-x6 behind them.
  3. Give waves a shape: a seeded pattern per wave from a small set (even drip, front-loaded rush, two pincers using the existing flank groups, a late surge), named on the wave banner.
- **Impact** H, **effort** M, **risk** readability at 60+ bodies on a phone (the density glow ramp exists for this); retune needed.
- **Challenges a recorded decision:** GDD 03 s4.4 (`N(w)` constants) and 02 s6 (even spawn spacing).

#### G-05 Dead time: a late run is 25-33 minutes long and its first 40 % can not hurt you
- **Evidence.** `logs/exp_late.txt`, 10 seeds: run length 24.8-32.7 minutes at 1x (half that at 2x); first hull damage of the run at wave 24-45 (median 30) of 63-82. Journey: deployments 12-16 take 26.6-30.2 minutes each. In PURGE a mid-profile run averages 39.9 minutes at 1x (`logs/exp_policy.txt`, `mid_purge`). The speed button offers 1x and 2x only (`src/ui/hud.gd:20`). A real late-run tick costs 0.06 ms (C-01), so 8x would cost about 1 ms per frame.
- **Why it matters.** GDD 00 s3 promises "3-12 minute deployments". By the second day each attempt is a quarter of an hour at 2x, of which the first six minutes are a formality, and the outcome is decided in the last 10-15 seconds (G-03). FC4 (three unprompted redeploys in 15 minutes) can not pass at that length. This is the most common reason people stop playing games of this type.
- **Recommendation.** Pick one or two:
  1. **Deep deploy**: start a run at wave `floor(0.5 * best)` with the scrap a reference run would have banked by then (the journey tool can produce the table). Shown on Home as a second DEPLOY button once best is 30 or more. Removes the dead part, keeps the climb.
  2. **4x speed** unlocked at best wave 30 and 8x at 60, automatically falling back to 2x when hull drops below 75 % or a boss is alive. One constant plus a rule.
  3. **Overwatch**: while Cinder has taken no damage for 20 seconds the game runs at 4x by itself and says so on the HUD.
- **Impact** H, **effort** S (option 2) to M (option 1), **risk** option 1 changes the Data per minute curve; measure.
- **Challenges a recorded decision:** GDD 02 s14 (3x and 4x come from Lab research at Launch) and 00 s3 (session shape).

#### G-06 Progress slows after day 2 and stops from day 5 to day 10; the Foundry cap turns the wall into a locked door
- **Evidence.** Journey, recommended spend, seed 1, 40 deployments (`logs/journey40.txt`):

  | After deployment | Minutes of 2x play (cumulative) | Days at 35 min per day | Best wave | Run length at 2x | Foundry L / C / H / N | Data left unspent |
  |---|---|---|---|---|---|---|
  | 3 | 8 | first session | 15 | 2.8 min | 8 / 0 / 8 / 5 | 21 |
  | 9 | 39 | 1 | 35 | 6.9 min | 21 / 13 / 21 / 21 | 158 |
  | 12 | 69 | 2 | 71 | 14.2 min | 32 / 19 / 32 / 30 | 317 |
  | 16 | 126 | 4 | 76 | 15.1 min | 42 / 27 / 41 / 39 | 601 |
  | 19 | 171 | 5 | 81 | 16.2 min | 48 / 31 / 46 / 44 | 413 |
  | 31 | 351 | 10 | 81 | 15.2 min | 48 / 48 / 48 / 48 | 9,140 |
  | 34 | 398 | 11 | 84 | 16.7 min | 50 / 49 / 50 / 50 | 7,806 |
  | 35 | 418 | 12 | 104 | 20.8 min | 54 / 49 / 53 / 51 | 1,551 |
  | 40 | 513 | 15 | 104 | 19.6 min | 59 / 49 / 59 / 57 | 3,389 |

  Day 1 lands on the GDD target (wave 35). Day 2 jumps to 71. Then twelve deployments in a row (20 to 31, three hours of 2x play, about five days) set no new best. From deployment 21 the laser, hull and repair rows sit at their cap of 48 (`floor(0.6 * 81)`); by deployment 30 cycle rate is capped too, and after deployment 31 the player has 9,140 Data and nothing they are allowed to buy. Progress resumes only when a lucky run reaches wave 84, the cap moves to 50, the x1.75 milestone at F50 lands, and the next run jumps 20 waves.

  Mechanism: a Foundry level costs `fc0 * 1.10^F` Data and adds 0.06 to a multiplier that is already 3.5 at F42 (+1.7 % per level, about 1,100 Data), while enemy HP grows 6.3 % per wave (`g_hp_1`). The x1.75 milestones come every 25 levels. On top of that each row is capped at `floor(0.6 * best wave)` (`src/meta/foundry/foundry_rules.gd:16-39`): to buy levels the player must first beat their best wave, and to beat the best wave they need levels. A capped row shows a disabled button and "NEXT LEVEL AT WAVE N" in 2.6:1 gray (I-05).
- **Why it matters.** FO-3 solved "too fast on day 1" by tying the Foundry to best wave. It also (a) left the first session below its own target (wave 15 after three runs against 20-25, stated in the FO-2 report and unchanged), and (b) turned the long game into a loop where the only way forward is to repeat a 15-minute run until draft luck (G-02) produces a new best. With one sector, no Lab and no other sink, a beta tester feels the slowdown from the third day and within the first week has Data they are not allowed to spend.
- **Recommendation.**
  1. Replace the hard cap by a soft one: levels above `0.6 * best` cost x3 instead of being forbidden. A stacker is still slowed, nobody sees a lock, and Data always has a use.
  2. Give Data a second sink that is not raw power: buying patch rerolls, a starting patch, the deep-deploy start wave (G-05), frame mastery (G-11).
  3. Bring Sector 2 forward as the answer to the wall (a second ladder with `sector_offset_step` already implemented in the sim), even with the same five enemies and one new wave pattern.
  4. Fix the first session separately: raise early Data (`data_base`) or lower `fc0` for the first 5 levels so run 2 and 3 gain 4+ waves each (FC3).
- **Impact** H, **effort** S (1), M (2-3), **risk** re-opens the day-1 overshoot; the journey tool can check it in minutes.
- **Challenges a recorded decision:** FO-3 option E, GDD 05 s1.5 (best-wave level cap) and 09 Q87.

#### G-07 Everything the game has unlocks in the first 15-20 minutes
- **Evidence.** Unlock gates: rows at best wave 3, 5, 8, 10, 12 (`data/run_upgrades.csv`), BULWARK at 8, STRIKER at 15 (`data/frames.csv`), PURGE at 20 (`data/wave_modes.csv`). In the journey best wave 23 is reached in deployment 5, 15.5 minutes of 2x play. All five enemies are seen by wave 10 and all nine patches within a few drafts. After wave 20 the game never shows the player a new thing; SALVAGER (25) and LONGSHOT (40) exist in data but are switched off until M6.
- **Why it matters.** Unlocks are the cheapest "one more run" reason there is, and the ladder ends before the first session does.
- **Recommendation.** Stretch and extend the ladder to wave 100 using things that are cheap because the systems are data-driven: enable SALVAGER at 25 and LONGSHOT at 40 (their numbers are already in `frames.csv`; each needs one passive); a new patch joining the pool every 5 waves of best from 15 to 60 (G-02's rule patches); wave patterns (G-04) unlocking by best wave so new formations appear; a log fragment at every 5 waves (G-13); the 4x speed at 30 and deep deploy at 30 (G-05). Show the next two unlocks on the Results screen with a progress bar ("STRIKER: 3 WAVES TO GO").
- **Impact** H, **effort** S-M, **risk** low.

#### G-08 The beta build gives no reason to open the game tomorrow
- **Evidence.** No offline earnings (Standby Patrol is M6), no missions (Ops Board M6), no daily anything, no timers, no notifications. The profile already stores `farm_rate_1x` and `last_active_utc` for this purpose (`src/meta/profile/player_profile.gd:69-74`); the first is used only for the Foundry "~N TO AFFORD" estimate (`src/meta/foundry/foundry_service.gd:110-111`) and nothing reads the second.
- **Why it matters.** Day-1 return is the first number an open test is judged by, and the game has no mechanism aimed at it.
- **Recommendation**, in order of value for effort, all offline and deterministic:
  1. **Relay signal of the day**: one seeded daily deployment with a named condition from a table of 8-10 (STATIC STORM: optic range -25 %, scrap +40 %; DART TIDE: darts x3, walkers none; COLD RELAY: no repair, hull x2; CHORUS WATCHING: a boss every 5 waves, a draft per boss). Seed and condition come from the UTC date, so every player gets the same one and can compare without a backend. Own best per day, first clear pays a Data bonus.
  2. **Standing orders**: three small goals drawn per day from a list ("kill 40 lancers", "reach wave 20 as STRIKER", "finish a run with a gamble patch"), paid in Data.
  3. **Standby Patrol, minimal**: on return, pay `farm_rate_1x` x minutes away x 25 %, capped at 4 hours, with a "RELAY HELD: +N DATA" card. The EMA is already maintained.
- **Impact** H, **effort** M (item 3 alone S), **risk** device-clock cheating is harmless without leaderboards.
- **Challenges a recorded decision:** ROADMAP M6 placement of Standby Patrol and Ops Board; 08 s2 (both cut from MVP).

#### G-09 Every run is the same film
- **Evidence.** The seed changes spawn angles, the order of types inside a wave and the draft offers; nothing else. Skitters from wave 1, darts 4, lancers 6, walkers 8, the same boss at 10, 20, 30 (`data/enemies.csv`), the same type weights each run (`wave_planner.gd`, `weights_for_wave`). Without drafts the mid-profile death wave has p10 34, median 36, p90 37 over 30 seeds (`logs/exp_draft.txt`, `draft=none`): the run itself has almost no variance.
- **Why it matters.** Replayability is variance the player can respond to. Today the only variance is draft luck, which the player can not respond to (G-02).
- **Recommendation.** Per-run "relay conditions" as in G-08 item 1, but rolled for every normal run from a milder table and shown on the deploy button before the player commits ("SIGNAL: LANCER LINE - more lancers, fewer skitters"), so frame and first purchases can answer it. Named surge waves from G-04. A second boss type for wave 20, 40, ... (`boss_hive` is specified in GDD 03 s1.3).
- **Impact** M-H, **effort** M, **risk** low.

#### G-10 The identity mechanics exist on paper only: a targeting HUD where the player can not target
- **Evidence.** The premise is machine vision: "everything on screen is seen through Cinder's optics" (GDD 01, canon addition 5). The player's verbs in a run are: buy a row, pick a patch, change speed. Targeting is fixed to nearest (`laser_system.gd:28`). Lancers stop at 85 % of optic range and fire from there (`src/sim/systems/enemy_attack_system.gd:48-50`) while the beam works through melee enemies first; the player watches a ring of lancers shoot and can do nothing about it. Adaptive Swarm (N1), Salvage Caches (N3) and Overdrive (N4), the three mechanics the GDD lists as differentiators 8 and 9, are all M6.
- **Why it matters.** What is in the build is the generic part of the design; what is deferred is the part that would make someone describe this game to a friend.
- **Recommendation.** Before more meta, build one identity verb and playtest it:
  1. **Designate** (best fit for the setting): tap an enemy to paint it; the beam prefers it and deals +25 % to it; tap empty field to clear. For one-thumb play add a "protocol" chip above the panel that cycles NEAREST / RANGED FIRST / HEAVIEST / WEAKEST. Either is one new input-log command and a few lines in `LaserSystem.step`.
  2. **VENT / burn** from G-03 step 3.
  3. **CHORUS counts** (a light Adaptive Swarm that needs no damage types): every 10 waves CHORUS reads where the player's scrap went and answers in its lowercase voice on the banner: "chorus: counter-measure for ARMS" (the next ten waves bring more walkers and a plated boss) or "for CHASSIS" (more lancers and darts). The Intel tab shows the count. It punishes mono builds, which is the stated purpose of N1, with one table.
- **Impact** H, **effort** M each, **risk** must stay optional for idle play (default protocol NEAREST, VENT never required).
- **Challenges a recorded decision:** GDD 02 s3 (targeting rules, HARD) and ROADMAP M6 placement of N1/N3/N4.

#### G-11 Frames are stat presets, one of them is simply better, and nothing records what you did with each
- **Evidence.** Mid profile, optimizer buyer, 30 seeds (`logs/exp_policy.txt`, `mid_frames`): VANGUARD 49.5, BULWARK 50.6, STRIKER 56.3 (+14 %). The M3 balance gate was measured on a fresh profile only (GDD 11 s1.4; the doc notes BULWARK +30 % on `foundry_300`, and it is level with VANGUARD again by mid). Passives: BULWARK caps a hit at 20 % of hull, STRIKER gains up to +20 % fire rate per wave. The profile stores one best wave per mode, none per frame (`player_profile.gd:57-59`).
- **Why it matters.** GDD 11 added frames "for replayability". A frame that changes six multipliers replays the same run with different numbers, and since fire power beats defense everywhere (G-02), the glass cannon wins.
- **Recommendation.**
  1. One visible mechanic per frame instead of a passive modifier: STRIKER fires its twin emitter at two targets; BULWARK's plates return a share of melee damage and it can not repair above 80 % (so it lives in the burn bands, G-03); VANGUARD gets the designate bonus (G-10).
  2. Best wave per frame and per mode on Home and in the Frame Bay (3 x 2 records today). It is a small save field and gives six goals instead of one.
  3. Re-run the frame gate on the mid and late profiles, not only fresh.
- **Impact** M, **effort** M (item 2 alone S), **risk** save schema bump for item 2.

#### G-12 PURGE has no role
- **Evidence.** Mid profile: PURGE dies at wave 67.4 against TIMED 49.5 and takes 39.9 minutes against 19.6 (`logs/exp_policy.txt`). Fresh: 32.6 s per wave against 24 s (`docs/setup/balance_run.md:71`). PURGE records gate nothing and do not lift the Foundry cap (09 Q71), and its runs do not feed the offline rate (Q70).
- **Why it matters.** The mode that unlocks as the wave-20 reward is the slower, safer, longer way to play that advances nothing. A player who prefers it stops progressing.
- **Recommendation.** Make PURGE the fast mode its name suggests: next wave spawns the moment the field is clear *and* enemies spawn at 60 % of the ring radius, so a strong Cinder chews through waves in a few seconds each; score it by waves per minute. Or retire it and spend the slot on the daily signal (G-08). Either way let its record count for something.
- **Impact** M, **effort** S-M, **risk** low.
- **Challenges a recorded decision:** 09 Q68-Q73 (PURGE rules) and Q71.

#### G-13 The setting is written and unused
- **Evidence.** GDD 01 s5 specifies wave-1 whisper lines, CHORUS boss banners ("node 14 consolidating. 1 of 1 will pass."), sector briefings and 60 log fragments; the codex site has approved lore. In the build the entire narrative is three lines in the cold open (`ftue.cold.1` to `.3`) and the header "CINDER ASH-07". The boss banner says "WARNING / BOSS INCOMING" (`hud.boss_incoming`).
- **Why it matters.** Tone is the cheapest differentiator the project owns, and the HUD is already a text display.
- **Recommendation.** A `data/lines.csv` with 40 short lines and four hooks: run start whisper, boss approach (CHORUS counting, lowercase), band change (Cinder's system voice: "SKIN INTEGRITY 48 %"), and death ("relay six dark. 1,311 units spent." using the run's kill count). Log fragments as unlocks (G-07). Two days of writing and wiring.
- **Impact** M, **effort** S, **risk** none.

#### G-14 The idle contract is unclear
- **Evidence.** Not buying costs more than half the run (mid: 20.5 against 45-49 waves, G-01), so the game needs the player present for 15-40 minutes; while present there is under one meaningful action per 12 seconds and none of them is hard (G-01). There is no auto-buy (Lab research at Launch, GDD 02 s15) and no offline income (G-08).
- **Why it matters.** It is neither an active game (too little to do) nor an idle one (it stops when you leave and plays badly when you look away).
- **Recommendation.** Choose. My suggestion: lean idle in the buying and active in the verbs. Unlock auto-buy early (best wave 15) with three presets (BALANCED / ARMS FIRST / CHASSIS FIRST; `PolicyBot` already exists in `src/sim/ai/`), and put the player's attention on designate, vent and drafts (G-02, G-03, G-10).
- **Impact** M, **effort** S, **risk** auto-buy must be recorded through `command_buy` so replays hold (the bot already does this).
- **Challenges a recorded decision:** GDD 02 s15 (auto buy via Lab at Launch).

#### G-15 Pacing summary: first ten minutes, first hour, first day, first week
- **Evidence** (journey with the in-game RECOMMENDED spend, bot buyer, seed 1; times are 2x play; `logs/journey40.txt`).

  | Window | What the simulated player gets | Reading |
  |---|---|---|
  | First 10 minutes | Run 1: 2.2 minutes, dies at wave 11 after 16 purchases, one draft one wave before death. Runs 2-4 die at 14, 15, 18. The first enemy reaches firing range about 8-10 s after DEPLOY (09 Q53, still open) | Run 2 gains 3 waves and run 3 gains 1; FC3 asks for +4 after the first Foundry visit. The first session ends at wave 15-18 against a target of 20-25 (GDD 05 s8) |
  | First hour | 9 runs by minute 39, best wave 35. Every row, frame and mode unlocked by minute 15-20 (G-07). Two of the last four runs end below the previous best (34 then 28, 35 then 27) because of draft luck (G-02) | The hour is carried by the Foundry numbers going up. Nothing new appears in its second half |
  | First day (35 min) | Best wave 35, on the GDD target (35-45). Runs now last 5-7 minutes | Target met for the number, by a bot; no evidence about feel (O-01) |
  | Day 2 | One run jumps from 35 to 53 and the next to 71. Runs now last 10-14 minutes | The biggest step of the whole journey arrives without the player doing anything different: the 53 is draft luck on the same Foundry levels that died at 27 one run earlier, the 71 is the first x1.75 milestone (F25) bought with that run's Data |
  | Day 3 to day 10 | Best wave 71 to 81 in 100 minutes, then no new best for 180 minutes; Foundry rows locked; 9,140 Data unspendable (G-06). Each attempt is 15 minutes | This is where a tester stops |
  | Day 12 | Wave 84 lifts the cap to F50, the second milestone lands, the next run reaches 104 | Players who left on day 6 never see it |
- **Why it matters.** The shape is: a slow first session, one good day, a large unexplained jump, then a week of nothing. The interesting decisions and the visible spectacle are thin throughout (G-01 to G-04), so the curve is all there is to feel, and the curve has a hole in it.
- **Recommendation.** Use the journey tool as the pacing instrument it already is, with two additions: a "no new best for N deployments" counter and a "Data unspendable" flag in its output, and targets for both in `data/targets.csv` (for example: never more than 3 deployments without a new best in the first 30; unspendable Data never above one run's income). Then fix G-06 and re-run.
- **Impact** H, **effort** S for the instrument, **risk** none.

### Image quality

What I looked at: the committed emulator and phone captures under `docs/playtests/` (540 px JPG and full 1080 px PNG), and my own renders of the current build through the debug harnesses in `src/debug/` (windowed renderer, 1080x2400 SubViewports), saved half-size under `docs/review/fable/renders/`. Contrast figures are WCAG ratios measured from the PNG pixels with `tools/png_io.py` (script: `docs/review/fable/scripts/contrast.py.txt`).

Overall: the individual assets are good. Enemy sheets, icons, the HUD frame kit and the title scene are consistent with each other and with the art bible, and better than this genre usually has at prototype stage. The problems are composition and hierarchy: what a real phone screen contains at a real moment of play, what the eye is led to, and several screens that are layout drafts.

#### I-01 The real battlefield is mostly empty; the art was approved on scenes that play never produces
- **Evidence.** Real play: `docs/playtests/m4/m4_27/bw18.jpg` (wave 9: three enemies, each about 5 % of the screen width, on a 1080x1344 field), `boss_warning_banner.jpg` (wave 10 boss: three skitters), `r01_run1_pointer.jpg` (wave 1 after 7 seconds: nothing but the grid). My render of a bot-played run on the current build through `src/debug/dmgnum_shots.tscn`, which saves the *busiest* frame of the run: `renders/battle_real_wave8.jpg` (wave 8: three enemies and two barely visible damage numbers on a 1080x1344 field; the harness draws no HUD). Approval scenes: `docs/playtests/v1/V1-19_wave30_dense.png`, `V1-29_phone_live_wave20.png`, `V1-23_1080x2400_far.png`, all debug loads with 160 enemies in the sim and an invulnerable Cinder that kills nothing. The V1-19 report says so itself ("this is not a dense crowd test"). Skitter body size is 54 px at 1080 width (art bible, V1-GATE decision 2), under the 56 px the readability check asks for.
- **Why it matters.** The dense debug frames look like a game people would screenshot. The real frames look like a radar test pattern with a few icons on it. Store screenshots have to come from one or the other (O-05).
- **Recommendation.** This is G-04 seen from the art side: more bodies. Independent of that: (1) keep the minimum camera at 38 m for the first 15 waves so sprites are about 35 % larger while the field is sparse; (2) let kills leave wreck decals that stay for the run (one more MultiMesh, capped at 150), so the field fills with evidence of the fight and "escalation you can see" holds even with few live enemies; (3) re-capture the art sign-off pack from real runs at waves 5, 20 and 50.
- **Impact** H, **effort** M, **risk** decals need a cap and a LOW-tier switch.

#### I-02 Melee enemies stack on one point and bury Cinder at the moment that matters
- **Evidence.** `docs/playtests/v1/V1-29_phone_live_wave20.png` and `V1-19_wave30_dense.png`: walkers, skitters and the boss overlap each other and cover the lower left half of Cinder's plate ring. The sim has no enemy-enemy separation by design (`src/sim/systems/movement_system.gd` header: "no enemy-enemy collision") and the view draws each enemy at its sim position with a radial stand-off only (`ViewMath.map_pos`).
- **Why it matters.** The skin-burn rig is the signature (G-03) and it is hidden exactly when it changes: when Cinder is being hit. The eye also can not count the attackers.
- **Recommendation.** View-only slotting, no sim change: enemies inside the stand-off ring are assigned angular slots around Cinder per size class (walkers and the boss on an outer ring, skitters on the inner), eased over 0.2 s. Draw the boss under Cinder's ring, not over it.
- **Impact** M-H, **effort** M, **risk** beam end points and damage numbers must use the slotted position (both already read `EnemyRenderer.draw_pos`).

#### I-03 The laser, the one weapon in the game, is visible about 8 % of the time
- **Evidence.** `src/view/beam_math.gd:6` (`FADE_S = 0.08`): a shot draws for 80 ms; the starting fire rate is one shot per second (`data/run_upgrades.csv`, `cycle_rate` base 1.00) and beams only merge into a continuous line at 8 shots per second (`beam_math.gd:16`), which a first-week player does not reach (the late profile fires a few shots per second). The M4-27 report could not capture MK I against MK II "because the beam is only visible for about 100 ms per cycle" (finding F9). Of the six committed real-play battle captures I opened, one shows a beam (`bw18.jpg`).
- **Why it matters.** The identity line is a cyborg with a laser. For most of every second the screen shows a turret and some enemies with no visible link between them, and the MK II to MK IV beam tiers that were built in M4 are flashes too short to appreciate.
- **Recommendation.** Keep the 80 ms hot core, then leave an afterglow: the glow layer decays over 250-350 ms, and a faint scorch line stays on the floor for a second. At low fire rates stretch the hot phase to 120 ms. View-only.
- **Impact** M-H, **effort** S, **risk** overdraw from long additive quads; cap the afterglow count.

#### I-04 The patch draft, the one staged decision, is three text boxes
- **Evidence.** `docs/playtests/m4/m4_27/ftue4_draft.jpg`, `draft_purge_gamble.jpg`; my render of the current build `renders/draft.jpg` (the title now reads "WAVE 10 CLEARED", which fixes M4-27 finding F5, and a gray "PICKS:" line lists picks held). Cards carry a name and one line in capitals ("NANO REPAIR +50% PER PICK"). No icon although every stat has one (`docs/playtests/v1/V1-07_icons_105.png`), no color by family, no current-to-new value. Only the gamble card differs (dashed border), and its cost line is the same amber as everything else.
- **Why it matters.** FC7 asks that 6 of 10 testers can state each patch's effect. The card should make the effect obvious without reading.
- **Recommendation.** Per card: the stat icon at 160 px on the left in its family color (amber arms, teal chassis, scrap-gold systems), the name, then the concrete change for this run ("LASER 28.6 -> 32.9"), pick pips on the card itself (2 of 5), and for gambles the cost on a red-tinted lower half.
- **Impact** M, **effort** S, **risk** none.

#### I-05 Secondary text is thin and under contrast; the line that explains a locked Foundry row is the faintest thing on the screen
- **Evidence.** Measured on `docs/playtests/m4/fo3/capped_row_1080x2400.png`: "MILESTONE F25 x1.75" (`AMBER_DIM` #8A5F00 on #080B10) 3.5:1; the "CAP" label on the disabled button (#5C5546 on #0D1117) 2.6:1; "NEXT LEVEL AT WAVE 12" 6.2:1 but in a thin weight (lit pixels are 11 % of the text box against 32 % for the row title). `UNAFFORDABLE` #5C5546 is the same value 09 Q48 flagged at 2.56:1 on 2026-11-08 and is still open (`src/ui/palette.gd:21`). Body copy is Oxanium at a light weight in capitals: the Foundry explainer is 60 words of capitals (`docs/playtests/m4/fo1/phone_1080x2400.png`).
- **Why it matters.** WCAG asks 4.5:1 for text this size. The phone will be used outdoors and at low brightness. The strings below 4.5:1 are precisely the ones that tell the player why something is unavailable.
- **Recommendation.** Raise `UNAFFORDABLE` to about #8A8170 and `AMBER_DIM` text uses to #B88A1E (keep the dim value for lines and frames only). Use Oxanium at weight 500-600 for all body text (it is a variable font; set the weight in `theme_builder.gd`). Sentence case for anything longer than four words. Add the contrast assertion Q48 proposed to `test_theme_builder.gd`.
- **Impact** M, **effort** S, **risk** none.

#### I-06 Menu screens are stacks of full-width plates with large dead areas
- **Evidence.**
  - Home. A fresh profile is clean: one diorama, one plate, DEPLOY (`renders/home_fresh.jpg`). After a few runs it becomes eight stacked rows of plates and buttons with the diorama squeezed to a third of its size (`docs/playtests/m4/m4_27/sp04_home.jpg`): PR and DATA, diorama, best-wave plate, frame button, Foundry button, mode picker, unlock chip, DEPLOY, and a HOME / FOUNDRY bar that includes a "HOME" button on the Home screen. "PR 33" is never explained, and the selected mode's record replaces the other mode's.
  - Foundry (`docs/playtests/m4/fo3/capped_row_1080x2400.png`): four rows end at y 1450 of 2400; the lower 40 % is empty down to a DEPLOY button.
  - Frame Bay (`m4_27/f01_framebay.jpg`; current build `renders/frame_bay.jpg`): the frame art is a 230 px thumbnail in a card whose lower 40 % is empty; six comparison bars that all read 0 % for the default frame. The title screen has a much larger hero illustration of the same frame (`m4_27/t01_title.jpg`).
- **Why it matters.** These are the screens between runs, where the player decides to play again. They currently look like a settings menu.
- **Recommendation.** Frame Bay: the title hero art at full card width, stats below, swipe between frames. Foundry: rows fill the height (4 rows of about 420 px with a level track showing the next milestone and the cap marker). Home: keep the fresh layout as the played layout. One diorama, one DEPLOY, mode and frame as two chips on the diorama, records for both modes side by side, the Foundry count as a badge on one button, no HOME button, PR replaced by the best wave.
- **Impact** M, **effort** M, **risk** none.

#### I-07 Two different Cinders
- **Evidence.** Title, cold open and Frame Bay show a standing, broad-shouldered humanoid machine (`m4_27/t01_title.jpg`, `c02_coldopen_b.jpg`). In play Cinder is a circular plate ring with a side emitter, seen from above (`bw18.jpg`). Nothing connects the two; a new player goes from the cold open figure straight to the disc.
- **Why it matters.** The character is the differentiator named first in GDD 00 s4. In play it reads as a turret pad, and the "less human as it burns" theme can not be seen on a disc.
- **Recommendation.** Put the standing figure into the battle HUD as a small status portrait (left of the hull bar, about 150 px): the same silhouette, its plates charring and falling away with the burn band, flashing on hits. It is the art you already have, it gives the hull bar a face without breaking the faceless rule, and it makes band changes readable when the field is busy (FC8). Alternatively redraw the top-down rig with shoulders and a facing so it reads as a body from above; that is a larger art task.
- **Impact** M, **effort** S-M, **risk** HUD space at the top is tight on short screens.

#### I-08 Damage numbers are small, and Cinder's own damage is the hardest to read
- **Evidence.** `src/view/damage_number_model.gd:27`: sizes 30 / 44 / 56 / 36 / 34 px at 1080 width, lifetime 0.6 s. A 30 px digit on a 6.5 inch 1080-wide phone is about 1.5 mm tall. M4-27 finding F6: red Cinder numbers "sit on the bright hit flash and are hard to read" (`m4_27/cn3.jpg`).
- **Recommendation.** Normal hits 36 px; show Cinder's damage in the hull bar (a red chunk that drains, plus the number beside the bar) instead of on top of the flashing rig.
- **Impact** L-M, **effort** S, **risk** none.

#### I-09 Amber does every job, so nothing stands out
- **Evidence.** In `bw18.jpg` and `sp04_home.jpg` the same amber is used for frame lines, tab labels, the wave title, costs, the grid, range rings, button text and the beam. Teal appears only on the hull bar and blue only on Data. On Home every element is amber on near-black.
- **Why it matters.** The art bible's second test is "the eye goes to Cinder's core, then to the nearest threat". On the real, sparse field the brightest and largest shapes are the HUD frame and the range rings.
- **Recommendation.** Reserve full amber (#FFB000) for values and the one primary action per screen. Draw frames, dividers and the grid in `AMBER_DIM` at lower alpha. Use teal consistently for "yours and safe" (hull, repair, affordable), and give the DEPLOY and REDEPLOY buttons a filled style that nothing else uses.
- **Impact** M, **effort** S-M, **risk** check the colorblind palettes after.

#### I-10 Overlays collide with the things under them
- **Evidence.** FTUE: M4-27 findings F1-F3 are mostly fixed in the current build (the plate now sits in the field above the panel and below the Results card: `renders/ftue_run1_pointer.jpg`, `renders/ftue_results.jpg`); what remains is the arrow drawn over the CHASSIS and SYSTEMS tab labels, an arrow overlapping the HOME button on Results, and a SKIP HINTS button as large as the hint itself. Boss: `boss_warning_banner.jpg` (the banner covers the SCRAP and DATA plates; the boss sprite shows above and behind the top HUD bar). Tier banner against wave banner (F8). Stale footer "Next unlock at wave 3" at wave 11 (F7, visible in `ftue4_draft.jpg`).
- **Recommendation.** One banner lane under the HUD plates with a queue (wave, boss, tier-up never overlap). Clip the battlefield to the area below the top bar. Move the FTUE arrow to the side of its target and shrink SKIP HINTS to a text link. Hide the footer when nothing is pending.
- **Impact** M, **effort** S, **risk** none.

#### I-11 Progress makes the picture smaller
- **Evidence.** The camera fits the optic range: width = 2 x (range + 2 m), sprites shrink by sqrt(52 / camera) (art bible, V1-23 block; `src/view/view_math.gd`, `fit_width_m`, `sprite_factor`). Buying OPTIC RANGE from 24 m to its 80 m cap shrinks every sprite to about 70 % and pushes the lancer ring outward. Compare `docs/playtests/v1/V1-23_1080x2400_base.png` and `V1-23_1080x2400_far.png`.
- **Why it matters.** An upgrade whose visible effect is that Cinder and the enemies get smaller works against "escalation you can see".
- **Recommendation.** Cap the auto-fit at about 70 m and show range beyond it with an edge indicator; or keep the camera fixed and express range as a brighter, larger scan ring.
- **Impact** L-M, **effort** S, **risk** enemies hit off-screen again (the reason V1-23 exists); the edge indicator covers it.

**What is already right in the image** (not a finding; listed so the fixes above do not disturb it): per-type accent colors and silhouettes; the lancer ring forming on the optic circle; the red haze at low hull; the icon set; the results screen with the killer portrait and kill strip (`m4_27/rs01.jpg`, current build `renders/results.jpg`); the title scene; the accessibility palettes (`docs/playtests/m4/palettes/m4-24_palettes.jpg`).

### Code efficiency

Overall: the code is the strongest part of the project. The sim is data-oriented, allocation-free per tick, deterministic and well tested; the view is batched; UI refresh is throttled. I looked for per-frame waste and found little that a player would feel. The findings below are ordered by how much they matter, and the first one is the most important: the performance work has been aimed at a load the game never produces.

#### C-01 The performance budget targets a load that real play never reaches
- **Evidence.**
  - `tools\perf_bench.ps1` on this machine: `PERF avg_ms=1.752 p95_ms=2.146 max_ms=3.579 enemies=600 bolts=603`.
  - A real late run (Foundry L42/C27/H41/N39, death at wave 71, greedy bot), command `godot --headless -s res://tools/_rev_exp.gd -- perf` (script in `docs/review/fable/scripts/`): `tick_avg_us=62 p95_us=116 max_us=440`; the run never reached 120 alive enemies, and at death 22 enemies and 1 bolt were alive (`docs/review/fable/logs/perf.txt`).
  - Ten late runs (`-- late`): peak alive enemies 21-37 in every run (`docs/review/fable/logs/exp_late.txt`).
  - The design curve itself: `N(w) = min(200, floor(4 + 2.4 * w^0.6))` gives 13 slots at wave 10, 29 at wave 50, 42 at wave 100 (GDD 03 s4.5). The 160-enemy alive cap is not reachable before roughly wave 1000.
  - `docs/TECH_ARCHITECTURE.md` 2.7 budgets "Alive enemies (typical late) 100-200", and FC6, `render_bench.ps1` (`hold100`, `hold165`), `perf_bench` (600 + 600) and the V1 art sign-off screenshots (`V1-19_wave30_dense.png`, `V1-29_phone_live_wave20.png`) all use debug loads with an invulnerable, un-upgraded Cinder.
- **Why it matters.** The sim has roughly 25x headroom over what the game asks of it, and the render benchmarks describe a scene players do not see. Two consequences: (1) time has gone into a problem that does not exist yet; (2) the headroom is a free design resource that nobody is spending (see G-04 more bodies, G-05 higher game speed).
- **Recommendation.** Add a "real late run" scenario to the benches (replay a recorded wave-70 run with the HUD on) and gate on that. Keep the 600-enemy bench as a stress ceiling only. Spend the headroom on G-04 and G-05 before optimizing anything else in `src/sim`.
- **Impact** H (redirects effort), **effort** S, **risk** low.

#### C-02 Run checkpoint is synchronous on the main thread and does its work three times over
- **Evidence.** `src/save/save_scheduler.gd:11` (`CHECKPOINT_S = 30.0`), `src/core/run_checkpointer.gd:32-44`, `src/save/save_store.gd:38-53`. One checkpoint = `var_to_bytes` capture, zstd + HMAC encode, write tmp, **read tmp back, HMAC and decompress it, compare**, **read the live file, HMAC and decompress it**, two renames, then a full `state_hash()`. Measured here (desktop SSD, wave 71): capture 2.6 ms, whole checkpoint 9.9 ms average, 13.5 ms worst, 7.5 KB. On the emulator the project's own logs say 22-51 ms normally and 238 ms for the three-checkpoint burst on pause (`docs/tasks/M3.md:505`), at waves 1-5; never measured at a high wave or on a mid-range phone.
- **Why it matters.** A 22-51 ms stall is 1-3 dropped frames at 60 Hz every 30 seconds, in the one screen where smoothness is the product. Flash storage on a 2020 mid-range phone is slower and spikier than the emulator's host SSD.
- **Recommendation.** Capture on the main thread (it must be between ticks), then hand the bytes to `WorkerThreadPool` for encode, write and verify. Drop the decode of the old live file on every save (rename it to `.bak` unconditionally; `load()` already validates and falls back). Compute `state_hash()` only in debug builds. Alternative with less code: keep it synchronous but move it to the wave-end lull, when nothing is on screen.
- **Impact** M, **effort** S, **risk** low (covered by the existing save tests).

#### C-03 Texture memory is uncompressed and the phone reading is over the memory budget
- **Evidence.** All 21 `assets/art/src/*.svg.import` files have `compress/mode=0` (lossless, RGBA8 in VRAM). `docs/perf/v1_perf.md`: `tex_mb` 58.1-58.7 against a 48 MB hard limit (the doc argues art alone is about 25 MB), PSS 405.8-408.7 MB on the phone against the TECH_ARCHITECTURE 2.7 target of 350 MB (hard limit 500). That phone is a flagship foldable; the reference device is a 4 GB mid-range phone that nobody has measured (09 Q23).
- **Why it matters.** Android kills background apps by memory. An idle game that is evicted every time the player checks a message loses the run feeling (the checkpoint saves the state, but the cold start is long, see C-04).
- **Recommendation.** Bake the large static sheets (arena floor 5.8 MB, Cinder 4.2 MB, walker, boss, fx) to PNG at export and import them with ETC2/ASTC (the perf doc already notes this for the floor). Measure PSS on a 4 GB device before the open test.
- **Impact** M, **effort** M, **risk** banding on the floor gradient; check visually.

#### C-04 Cold start is far from the 3 second target and has not been measured on a phone
- **Evidence.** `docs/playtests/m3/M3-19_M3-32_verification.md` (M3-32.1): first launch 17 s to `boot ok`, warm launches 7-8 s, title visible after 10-12 s, on the emulator. Target: 3 s, hard limit 5 s (TECH_ARCHITECTURE 2.7, FC6). `docs/tasks/M4.md:360` records "boot splash shows for 10-25 s on a cold start". No phone number exists in the repo.
- **Why it matters.** Idle games are opened many times a day for short checks. Ten seconds of splash per open is the single most-repeated experience in the product.
- **Recommendation.** Measure on the phone first (it may be 2-3 s there; the emulator translates GL). If it is slow: log timestamps around `Game._ready`, table loads, `ArtSlots` texture loads and `ShaderWarmup`, show the title after the first of them and warm the battle shaders behind the title (the fade already exists for this).
- **Impact** M-H if confirmed, **effort** S to measure, **risk** none.

#### C-05 The game renders at full rate everywhere; battery has never been measured
- **Evidence.** `src/meta/settings/player_settings.gd:13` (`DEFAULT_FPS_CAP = 60`); no `low_processor_usage_mode` anywhere in `src/` (`git grep low_processor` is empty); Home, Foundry and Settings are static screens redrawn every frame; the title measured 47 fps at 21 ms average on the emulator with smoke and embers (M3-32.8). TECH_ARCHITECTURE 2.7 sets a battery budget (4 % per 10 minutes) with the note "measure"; no measurement exists.
- **Why it matters.** Session length in this genre is limited by heat and battery more than by content. A late run here is 25-33 minutes long (G-05).
- **Recommendation.** Turn on `OS.low_processor_usage_mode` on the static menu screens. In battle, drop to 30 fps automatically when the action is slow (fewer than N events per second) or offer a "battery saver" toggle next to the fps cap. Measure with `dumpsys batterystats` once on the phone.
- **Impact** M, **effort** S, **risk** low.

#### C-06 Outcome-affecting sim math uses `exp`, `log` and `pow`, against the determinism rule in the architecture doc
- **Evidence.** TECH_ARCHITECTURE 2.3 (line 166): "sim avoids transcendental functions in outcome-affecting paths". In the code: enemy HP and attack come from `exp(k * level)` (`src/sim/math/curves.gd:14-21`), wave size from `floori(base + coef * pow(w, power))` (`curves.gd:26`), upgrade costs from `ceil(c0 * pow(g, level))` (`curves.gd:58`), scrap from `roundi(k * pow(g_hp, power))` (`curves.gd:31`), the melee bite from `pow(1 + bite_gain, hits)` (`src/sim/systems/enemy_attack_system.gd:41`), and the sin/cos table is filled with `sin()`/`cos()` at run time (`src/sim/math/sin_cos_table.gd:28`). `floor`, `ceil` and `round` on these turn a one-ulp libm difference between ARM and x86 into a different integer.
- **Why it matters.** Not today: every replay and hash test runs on one architecture. It matters the day a server verifies phone runs (leaderboards at Launch, Gauntlets in P1) or a cloud save moves a run snapshot between devices. Fixing it after replays exist means a migration; fixing it now is cheap.
- **Recommendation.** Generate the growth, cost and slot tables once in the data importer (one machine) and ship them as integer or decimal-string tables in `src/data_gen/`; replace the bite `pow` by a small lookup. Add one CI job that runs the replay goldens on an ARM runner. Alternative: accept the documented "statistical plausibility" verification and delete the sentence in 2.3 so nobody relies on it.
- **Impact** M (future), **effort** M, **risk** low; needs a SimVersion bump.

#### C-07 Balance constants live in code, so every tuning change is a SimVersion bump that ends runs in progress
- **Evidence.** `src/meta/foundry/foundry_rules.gd:16-17` (`CAP_K`, `CAP_MIN`), `src/sim/math/curves.gd:5-6` (run and Foundry milestone step and multiplier). FO-3's own note: "milestone and cap constants live in `Curves` and `FoundryRules`, not in `sim_constants.csv`" (`docs/tasks/M4.md`, FO-3 status). SimVersion went 1 to 5 in three days. A snapshot from another SimVersion is not resumed; the run is banked and ended (`src/core/run_checkpointer.gd:79-88`).
- **Why it matters.** Once the beta is live, each balance patch will end every tester's run in progress and invalidate every recorded replay. The remote-config overlay planned in TECH_ARCHITECTURE 4.3 cannot reach constants compiled into scripts.
- **Recommendation.** Move the remaining tunables into `data/sim_constants.csv`. Decide the live policy now: a balance change applies to the next run, and a run in progress keeps the tuning it started with (store the tuning hash in the snapshot, which `ConfigHash` already computes).
- **Impact** M, **effort** S, **risk** low.

#### C-08 Per-frame view uploads are wasteful in shape but cheap in practice; leave them alone
- **Evidence.** `src/view/enemy_renderer.gd:229-232`: every frame, for each of 6 MultiMeshes, the full 512-instance transform buffer is uploaded and a new `Image` is created from the data array, converted RGBAF to RGBAH and uploaded as a texture (`src/view/multimesh_buffer.gd:44-49`), whether 0 or 500 instances are alive. `MultiMeshBuffer.fill` walks the whole enemy store once per type (5 passes). Measured CPU cost of all of it at a real late-run state: fill 0.12 ms and image conversion 0.03 ms per frame on this desktop (`-- perf`, `fill_6_passes_us=122 data_image_x6_us=32`). The GPU upload side could not be measured headless.
- **Why it matters.** It does not, at 20-40 enemies. I list it so nobody spends a task on it: it is 12 small allocations per frame and well under the 3 ms render-prep budget even at ten times the cost on a phone.
- **Recommendation.** No action now. If G-04 raises the body count, do the cheap part: one pass that buckets by type, and skip the upload for a slot whose count is 0 this frame and was 0 last frame.
- **Impact** L, **effort** S, **risk** none.

#### C-09 Debug harnesses ship in the release bundle and the bundle is at its size target
- **Evidence.** `export_presets.cfg:11` and `:66` exclude `tests/*, tools/*, docs/*, site/*` and some addons, but not `src/debug/*` (3,685 lines, 19 capture scenes) or `assets/art/probe`, `assets/art/style`. The beta AAB is 59,279,199 bytes (`docs/tasks/B1.md:68`) against the 60 MB target in TECH_ARCHITECTURE 2.7.
- **Recommendation.** Exclude `src/debug/*` and the style or probe art from the release preset (the one runtime reference, `main.gd` loading `style_frame.tscn`, is already behind `OS.is_debug_build()`), and run the existing `aab_check` to confirm nothing else referenced them.
- **Impact** L, **effort** S, **risk** a missed reference; the compile gate will catch it.

#### C-10 The draw-call split between HUD and battlefield is still an estimate
- **Evidence.** `docs/perf/v1_perf.md`: 74-77 draws total, battlefield "about 35 (estimate)" against a budget of 25 (hard 40); the `-HideHud` split "failed to run"; the old-look baseline measured the HUD and panel alone at 41 draws and 18 ms per frame on the emulator (`docs/perf/render_baseline.md`). The M4 additions (damage numbers, tier plates, sparks, motes, FTUE, draft) came after that measurement; the M4 soak read 83-86 draws (`docs/playtests/m4/modes_emulator.md`, step 7).
- **Why it matters.** The constant cost of the frame is the UI, not the enemies, and it is the part that grew during M4 without a re-measure.
- **Recommendation.** One phone session with `--debug-novsync`, HUD hidden and battlefield hidden, on the current build. Record uncapped fps so there is a headroom number instead of "60, pegged".
- **Impact** M, **effort** S, **risk** none.

#### C-11 Process weight: every number lives in four places
- **Evidence.** A tuning value such as the Foundry milestone exists in the GDD table (05 s1.2), the CSV or constant, the generated `.tres`, and `test_gdd_tables` plus golden hashes; FO-3 touched all of them plus three docs for two constants. The repo has about 33k lines of game code, 23k lines of tests (211 files) and 5.5k lines of design docs after four days of history (`git log`: 198 commits from 2026-11-07 to 2026-11-10).
- **Why it matters.** This is the right structure for a game whose rules are settled. The gameplay findings below say the rules are not settled: the next month should be spent changing mechanics quickly, and the current gates make each experiment expensive.
- **Recommendation.** Add an explicit "prototype lane": a `data/experiments/*.csv` overlay and a `SimVersion.EXPERIMENTAL` flag under which goldens and GDD-table tests are skipped, so a mechanic can be tried on the phone in an hour and only gets the full treatment when it is kept. Do not loosen the gates on main.
- **Impact** M, **effort** S, **risk** discipline: experiments must not leak into a release build (gate on `OS.is_debug_build()`).

### Other

#### O-01 No human has recorded a playtest; the fun checks have never been run, and the open beta is scheduled in parallel with them
- **Evidence.** `docs/playtests/m1_playtest.md` is a question sheet with every answer blank (6 of 6 `- Answer:` lines empty). Every other file under `docs/playtests/` is an agent-driven emulator verification (adb taps, screenshots). The fun checks FC1-FC12 (GDD 08 s4) are assigned to M5; `docs/ROADMAP.md` schedules B1 (open beta) "parallel with M5". GDD 08 s4 says: "If FC1, FC3 or FC4 fail, adjust base numbers, early curves and FTUE before building more meta." The only human signals in the repo are short owner remarks that triggered V1 ("low quality, flat, too small"), the visual tiers, and FO-1 to FO-3 ("Data accumulates pretty fast").
- **Why it matters.** The project has excellent machine evidence that the game works and almost no evidence that it is fun. Every gameplay finding in this report comes from bots and reading; five people with a phone for 20 minutes would confirm or kill most of them in an afternoon. An open test is public and collects store ratings from strangers.
- **Recommendation.** Before the open test: 5-8 people, one phone, FC1-FC4, FC7 and FC12 only, screen-recorded, no coaching. Keep the internal and closed test tracks (they are private) and hold the open track until FC4 ("3 unprompted redeploys in 15 minutes") and FC12 pass. This is the cheapest high-value task on the board.
- **Impact** H, **effort** S, **risk** none.
- **Challenges a recorded decision:** ROADMAP section 2 (B1 "parallel with M5") and the B1 goal of an open test of the MVP build.

#### O-02 The beta build can not tell you what players did
- **Evidence.** B1-04 removes ads, billing, crash reporting and the online plugins (correct for privacy and review). The only feedback channel is a form link in Settings (B1-08). Nothing records session count, run count, best wave per day or where players stop.
- **Why it matters.** The questions an open test should answer (do people start a second session, where do they stall) need numbers. A form gets a handful of opinionated replies.
- **Recommendation.** Keep the build free of network collection, and add a local "flight recorder": the profile already has `runs_total` and `farm_rate_1x`; add a 30-day ring of per-day counters (sessions, runs, minutes, best wave, last screen before quit). Show it in Settings as "COPY PLAY SUMMARY" so a tester can paste it into the form by choice. No permission and no privacy change is needed because nothing leaves the device unless the player pastes it.
- **Impact** M, **effort** S, **risk** state in the privacy text that the summary is only shared if the player pastes it.

#### O-03 No mid-range device has run the game
- **Evidence.** 09 Q23 is OPEN. The one phone measured is a current flagship foldable (`docs/perf/v1_perf.md`), which pegs 60 fps and still reads 405 MB PSS. FC6 names a 4 GB, 1080x2400 device.
- **Recommendation.** Buy or borrow one before the open test; Play's pre-launch report (B1-10) will run the AAB on a few real devices for free, so read its performance tab closely as a first look.
- **Impact** M, **effort** S, **risk** none.

#### O-04 The first-run hints say little, and one never fires
- **Evidence.** The placement problems of M4-27 findings F1-F3 are mostly fixed in the current build (I-10, `renders/ftue_run1_pointer.jpg`). What remains: the hint text is the single word "UPGRADE" (`ftue.upgrade`) for laser, cycle rate and hull alike; the hull hint is tied to first damage and did not appear in run 1 of the emulator pass because Cinder took no damage before wave 11 (finding F4); the draft gets one line ("PATCHES LAST THIS DEPLOYMENT") at the moment G-02 shows the choice does not matter yet.
- **Why it matters.** The first 60 seconds decide FC2 ("2 upgrades bought in the first minute") and the first Foundry visit decides FC3.
- **Recommendation.** A verb and a reason per hint ("TAP: MORE DAMAGE", "TAP: FIRE FASTER"). Fire the hull hint on first damage in any of the first three runs. Judge the result with people (O-01), not screenshots.
- **Impact** L-M, **effort** S, **risk** none.

#### O-05 Store text and art describe a different Cinder from the one on screen
- **Evidence.** `docs/release/store_listing.md` says "synthetic skin burns away" and calls Cinder "she"; the V1-GATE decision 4 changed the skin to gunmetal armor plates (art bible, gate block), and GDD 01 s3 says Cinder never speaks and has no face. The title and cold open show a standing humanoid machine; play shows a top-down disc (I-07). "Rogue machine swarms attack from every side" in the listing against 3 to 30 enemies on screen (G-04).
- **Recommendation.** Decide the canon once (pronoun, skin or plates) and align listing, codex and strings. Take store screenshots only from real runs, not debug crowds, or fix G-04 first so the real runs look like the listing.
- **Impact** L-M, **effort** S, **risk** misleading-screenshot complaints if debug crowds are used.

#### O-06 Name and trademark search is still open while store graphics are next
- **Evidence.** 09 Q31 (trademark and Play name search not done) and B1-06 (icon, feature graphic, screenshots) is the next unchecked agent task; B1-06 itself says Q31 must clear first.
- **Recommendation.** Do the search before any graphic bakes the name in. Owner task, one hour.
- **Impact** M, **effort** S.

#### O-07 Audio could not be judged; nobody has verified it on a device either
- **Evidence.** Every emulator session ran with `-no-audio` (`m4_27_emulator.md` "Not verifiable": boss drone, `sfx_tier_up`, haptics; M3-32.10 "NOT VERIFIED"). The audio is synthesized by script (A1). I can read the director code but can not hear the mix.
- **Recommendation.** One phone session with headphones, checking: does the laser shot become tiresome at 2-3 shots per second over 25 minutes, does the music change with intensity, is there a distinct sound for a kill, a milestone and a band change. Put it on the same sheet as O-01.
- **Impact** M, **effort** S.

#### O-08 Monetization design is fair on paper; one caution for later
- **Evidence.** GDD 06 s1 and s4: rewarded ads only, 12 per day, no interstitials, frames never sold, tournaments bracketed and not purchasable. Nothing of it is in the beta build.
- **Note.** The fairness rules are a real differentiator; keep them. The caution: several planned sinks (research rush, lab slots) monetize waiting. With runs already 25-33 minutes long and a progression wall inside the first week (G-06), adding timers on top will read as paywalls regardless of the rules. Fix pacing first, then add timers.
- **Impact** L now, **effort** none.

## 4. Keep doing

These are good and should not be traded away while fixing the findings above.

1. **The deterministic, pure sim and its tooling.** `sim_run`, `balance_run`, `journey_run`, replay goldens and state hashes made every gameplay measurement in this report possible in an evening. Most small teams never get this. The journey simulator in particular is the right instrument; point it at the questions in G-01 to G-06.
2. **Measure-then-decide balance work.** `docs/balance/foundry_early_power.md` states inputs found and absent, shows options with the same seeds and separates the proposal from the decision. I disagree with the option chosen (G-06), not with the method.
3. **Data-driven content and stable ids.** Enemies, upgrades, patches, frames, modes, visual tiers and strings are rows, not code. Adding the content this report asks for (patches, surge waves, unlock ladder) is mostly CSV work because of this.
4. **The art direction and its guardrails.** The enemy sheets, the icon set, the title scene and the HUD frame language are consistent and well above what is usual for a build this young. The per-type accent colors, the density-based glow reduction and the lancer ring are distinctive. The IP guardrails are clear and followed.
5. **Upgrade visual tiers (MK I to MK IV).** Purchases changing how Cinder and the beam look is the best "escalation you can see" feature in the build. Extend the idea (G-10, I-02) instead of adding new systems of the same kind as the stat rows.
6. **Honest verification notes.** The emulator reports list what was not seen, not verifiable or failed, and several findings here started from those notes. Keep writing them that way.
7. **Save safety.** Atomic write, backup, quarantine instead of delete, schema migration with fixtures, kill-and-resume drills with hash equality. Players never forgive a lost save; this is done properly.
8. **Accessibility from the start.** Colorblind palettes, high contrast, reduce motion, shake levels, haptics toggle, number format. Rare this early.
9. **The fairness rules in GDD 06** (rewarded-only ads, frames never sold, no paid tournament entries). They are a selling point; do not erode them when monetization arrives.
10. **Frames as unlocks earned by play, with a visible locked silhouette and condition.** The structure is right; it needs more substance (G-11) and more rungs (G-07).

## 5. Could not verify

**What I ran and reverted.** No file under `src/`, `data/`, `tests/`, `tools/` or `assets/` differs from `951269d` in this commit. All parameter changes were made in memory inside two temporary scripts (`tools/_rev_exp.gd`, `tools/_rev_exp2.gd`) and a PNG-to-JPG helper (`tools/_rev_jpg.gd`); all three were deleted and the first two are kept as text under `docs/review/fable/scripts/`. What they showed is in G-01 to G-06 and C-01, C-02, C-08: buy-policy and draft-policy sensitivity, death-wave distributions, time in each burn band, late-run dead time, a body-count scaling test (x1, x2, x4 at equal wave HP), real late-run tick cost, checkpoint cost and view-fill cost. The checkpoint timing wrote and removed files in `user://rev_tmp/`. The debug render harnesses were run with `--no-save --mute`, except the first (`dmgnum_shots`), which loaded and re-saved the local desktop profile as that harness normally does.

1. **Anything on a device.** No export, emulator, adb or phone was allowed. Frame rate, memory, cold start, battery, thermal behaviour, touch targets under a real thumb, haptics and the foldable layout are taken from the project's own notes (`docs/perf/`, `docs/playtests/`), which cover an emulator and one flagship phone. C-03, C-04, C-05 and C-10 are stated as risks for that reason.
2. **Whether the game is fun.** Every gameplay number here comes from bots. A bot buys instantly, never misreads a card and never gets bored. The findings say what choices *can* be worth and what is on screen; only people can say how it feels (O-01). In particular I could not test FC2, FC4, FC5, FC7, FC8 or FC12.
3. **Audio.** I did not listen to anything (O-07).
4. **GPU cost** of the per-frame buffer and data-texture uploads (C-08) and the current HUD against battlefield draw-call split (C-10). Headless runs have no GPU; the windowed harness on this machine uses desktop Intel graphics, which says nothing about a phone.
5. **The release bundle contents.** C-09 is read from `export_presets.cfg` and the size recorded in `docs/tasks/B1.md`; I did not build or open an AAB.
6. **Cross-architecture float divergence** (C-06). I showed that the code uses `exp`, `log` and `pow` in outcome paths; I did not demonstrate a diverging replay, which would need an ARM run.
7. **Journeys for BULWARK, STRIKER and PURGE after FO-3**, other seeds for the 40-deployment journey, and human spending patterns. The wall in G-06 is one seed set with one spend policy and a bot that takes the first patch offer; the mechanism (cap tied to best wave, 1.10 cost growth, milestone every 25) does not depend on the seed, but the exact days will move.
8. **The swarm experiment** (G-04) scales constants crudely (scrap per kill is floored at 1, so early income is not exactly preserved). It shows direction and the single-target ceiling, not a tuned proposal.
9. **The full test suite and lint** were not re-run; the brief says they pass. The experiment scripts were removed from `tools/` and `git status` shows only `docs/review/` in this commit.
10. **`site/` (codex) and `backend/`** were not reviewed.
11. **Some debug harness renders** include the tool's own framing (no HUD in `battle_real_*.jpg`, a plain backdrop behind the draft). I used them for composition and layout, not for final color.
