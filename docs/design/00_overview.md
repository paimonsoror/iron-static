# 00 - Overview, Pillars, Titles, IP Guardrails, Glossary (IRON STATIC)

Changelog: 2026-11-07 - working title confirmed as **IRON STATIC** (codename `ironstatic`, provisional Android applicationId `com.ironstatic.game`); novel mechanics N1-N4 approved, N5 turncoat protocol deferred to post-launch; Standby Patrol approved; online rollout staged (Launch: accounts, cloud save, leaderboards; P1: Gauntlets, Incursions, Operation Pass; P2: Cells). See 09 and `docs/ROADMAP.md`.

Status: first-pass GDD v0.1 (2026-11-07). All numbers marked "tunable" are first-pass and meant to be tuned later by a headless balance simulation. Research citations use `[CIS]` = combat_and_in_run_systems.md, `[META]` = meta_progression_systems.md, `[ECON]` = economy_monetization_liveops.md, `[GENRE]` = genre_landscape_and_theme.md (all in the research_notes folder).

Document set: 00 overview | 01 setting | 02 combat | 03 enemies/waves/sectors | 04 economy | 05 meta | 06 monetization/liveops | 07 UX/art/audio | 08 MVP | 09 open questions.

---

## 1. High concept

**IRON STATIC** is a one-handed, portrait idle-defense game. You are CINDER, a reprogrammed combat cyborg bolted to the last working relay of a dead city. Rogue machine swarms pour in from every direction; Cinder auto-fires a thin laser, and you spend salvaged scrap mid-deployment to make it stronger, faster and harder to kill. When Cinder falls the deployment ends, the data you recovered is banked, and you spend it on permanent upgrades, research, weapon systems, firmware chips and companion drones so the next deployment goes deeper. The look is a machine-vision targeting HUD: glowing vector lines, amber and red on black, with Cinder's synthetic skin burning away to reveal the armored frame as integrity drops.

One-line pitch: "Hold the last relay. Burn away what is left of being human. Go deeper every time."

## 2. Design pillars

1. **Glanceable and one-handed.** Everything essential is reachable by the right thumb in the bottom 45% of the screen. A run needs zero taps to progress; taps only make it faster or smarter.
2. **Escalation you can see.** Numbers grow, the swarm gets denser, and Cinder's body visibly degrades and hardens. Every threshold crossing has a visual and audio beat.
3. **Builds with consequences.** Investing in one damage type teaches the swarm to resist it (adaptive swarm). Builds are chosen, not defaulted to.
4. **Respect the player's time.** Five currencies maximum, research timers capped at 48 h, every wait rushable with an ad-earnable currency, no forced ads, no interstitials, everything explained in-game.
5. **Fair competition.** Tournaments are bracketed by power rating, run on a normalized rule set, and cannot be bought into beyond a small free allowance.

## 3. Audience

- Primary: 18-40, existing idle/incremental players (The Tower, Idle Heroes style players) who like spreadsheets in disguise, play 4-6 short sessions per day and check timers.
- Secondary: 1980s-90s sci-fi fans (nostalgia for machine-war mood) who want a low-effort, atmospheric time-sink.
- Rating target: Teen (ESRB T / PEGI 12 equivalent): machine-vs-machine violence, no gore, no human enemies, no real-world brands or weapons.
- Session shape: 3-12 minute deployments at 1x-2x speed, 5-10 minute check-in sessions, one long "overnight" research/standby cycle.

## 4. Differentiators vs The Tower and its clones

| # | Differentiator | The Tower / clones | Ours |
|---|---|---|---|
| 1 | Theme and mood | Abstract tower, themes are skins [GENRE A1] | Cinder: a protagonist with a face-less silhouette, narrative sectors, intercepted logs. Fills the open "cyborg idle central-tower" niche [GENRE A2] |
| 2 | Currencies | ~10 currencies, a repeated complaint [ECON 7] | 5 (`scrap`, `data`, `flux`, `cipher`, `merit`). Event/guild/tournament/key currencies are merged into `merit` and `cipher` |
| 3 | Wait times | Lab timers of days, gem rush [META Labs] | Hard cap 48 h per research, rush = 3 flux/hour, ad can shave 30 min (capped), free rush under 10 min |
| 4 | Ads | "Prepare to watch many ads" [ECON 3] | Rewarded only, opt-in, global cap 12/day, never mid-run, ad-free claim pass |
| 5 | Tournament fairness | Spend-adjacent perception [ECON 7 gaps] | Power-rating brackets, normalized rules, max 3 attempts, zero paid entries |
| 6 | Opaque systems | Wiki dependency, hidden formulas [CIS gaps] | In-game "Intel" tab showing every stat formula result and enemy scaling |
| 7 | Dead time | Slow rounds/dead time criticized [GENRE A1, Wittle Defender] | 24 s waves (18 spawn + 6 lull at 1x), skip-lull button, draft choices from wave 10 |
| 8 | Build pressure | Instant-kill "devo" farming meta [CIS 7] | Adaptive Swarm punishes mono-damage; razor ring is damage-based, not instakill |
| 9 | Novel mechanics | none | Skin Burn, Adaptive Swarm, Salvage Caches, Overdrive (all approved 2026-11-07); Turncoat Protocol deferred to post-launch (02 section 13) |
| 10 | Offline | None confirmed [ECON 2] | Standby Patrol: capped, partial-efficiency offline earnings (04) |

## 5. Internal mapping table (dev team only; never expose in store listing, UI or marketing)

| Our system / id | Genre equivalent (The Tower) | What we changed |
|---|---|---|
| deployment (run) | round | Same concept; shorter waves |
| wave, sector | wave, tier | 12 sectors at launch (not 24), offset-based difficulty |
| `scrap` | cash | Same role; cost curves our own |
| `data` | coins | Also pays research and weapon upgrades |
| `flux` | gems | Earnable via capped ads, sold for IAP; also buys lab slots and firmware picks |
| `cipher` | power stones | Also tournament rewards; unlocks weapon systems |
| `merit` | medals + guild tokens + keys | One currency for events, guild, season |
| Foundry | Workshop | Multiplicative layer separate from in-run levels (transparent) |
| Lab (R&D) | Labs | 48 h cap, 4 slots max |
| Weapon systems | Ultimate weapons | 9 re-themed, 3 equip slots |
| Firmware chips | Cards | Pick-1-of-3 pulls, disclosed odds |
| Hardware modules | Modules | 3-to-1 fusion, no shards |
| Companion drones | Bots | Bought with `merit` |
| Patches | Perks | From wave 10, not wave 200 |
| Sector milestones | Milestones | Free + one-time premium column |
| Gauntlet | Tournament | Power-rating brackets, normalized |
| Incursions | Events | Same 2-week shape |
| Cells | Guilds | Post-launch |
| Standby Patrol | (none) | New |
| Operation Pass | Event pass/Milestone Premium | Cosmetic and convenience only |

## 6. Working-title candidates and Google Play collision check

**Decision (2026-11-07): the working title is IRON STATIC**, codename `ironstatic`, with EMBER CHASSIS as the fallback. The Android applicationId is `com.normalexception.games.ironstatic` (user decision 2026-11-10, replacing `com.normalexception.game` of 2026-11-09 and the provisional `com.ironstatic.game`; permanent once uploaded to Play Console, 09 Q30). The trademark and Google Play name search below has not been done yet (09 Q31).

Method: web search per title on 2026-11-07. Web search cannot enumerate Google Play directly, so "no results" is not proof of availability. Before commit: search Google Play, USPTO TESS/TSDR, EUIPO and run a domain/social handle check; consult an IP lawyer [GENRE B2].

| # | Title | Search result (2026-11-07) | Note |
|---|---|---|---|
| 1 | **IRON STATIC** | No game listing found; only unrelated "Iron ..." titles | Evokes machine noise. Top pick. "Iron" prefix is crowded (Iron Marines) but the full phrase appears free |
| 2 | **EMBER CHASSIS** | No exact match; unrelated "Ember District/Harbor" developer titles | Directly echoes the skin-burn mechanic. Top pick |
| 3 | **NULL DIRECTIVE** | No Play listing; "Omega Directive" (itch.io) is a different title | Strong tone; generic words, low trademark strength. Top pick |
| 4 | COLD CIRCUIT | No game found; only unrelated idle-defense titles | Good alt |
| 5 | RUSTLIGHT PROTOCOL | No exact match | Long for an icon label |
| 6 | REDLINE SENTINEL | No exact match; "Sentinel 519: Saga" exists (different) | "Sentinel" is a crowded word |
| 7 | WIREHEART | No game found | Short; could suit a protagonist-led brand |
| 8 | CHROME VIGIL | No game found | "Chrome" may read as the browser |
| 9 | BURNOUT PROTOCOL | No game found; "Burnout" is a racing franchise name | Risky (Burnout racing IP) |
| 10 | ASHEN CORE | No match; "CoreCollapse DarkWave" (different) | Soft |

Avoid: any title containing "Terminator", "Skynet", "Cyberdyne", "Judgment", "Tower" (The Tower collision), "Cyborg Royale" (existing) or "Rogue Defense" (existing, "rogue AI" framing) [GENRE A2]. Recommendation: lead with **IRON STATIC**, hold **EMBER CHASSIS** as the fallback, and treat the working codename in code as `ironstatic`.

## 7. IP guardrails

### DO
- Use the generic tropes: cyborgs, machine uprisings, drones, walkers, bleak future, wasteland, red HUD overlays as a concept, EMP, nanites [GENRE B2 inferences].
- Use original names for everything: protagonist Cinder, hostile AI CHORUS, builder corporation Orrery Combine, human holdouts the Hollow Accord.
- Give Cinder a distinct silhouette: faceless slit visor, hexagonal chest core, asymmetric shoulder emitter, top-down radial vector emblem.
- Use a multi-color HUD (amber primary, teal friendly, red hostile, magenta enemy fire) so no single frame matches a franchise's red-tint trade dress [GENRE B1 inferences].
- Write original text, original music, original SFX.
- Keep the mechanics (generic) but not The Tower's icon, UI layout, names, tables or text [GENRE B2].
- Run a final naming/art review with an IP lawyer before store submission.

### DON'T
- No franchise names or marks: Terminator, Skynet, Cyberdyne, T-800, T-1000, T-X, any "T-number" model names, Hunter-Killer or "HK", Judgment Day, Resistance/Tech-Com framing, Sarah/John Connor, Kyle Reese, Miles Dyson.
- No signature lines: "I'll be back", "Hasta la vista", "Come with me if you want to live", "No fate".
- No chrome skull endoskeleton with glowing red eyes, no half-flesh face, no scrolling-text red Terminator-vision readout copy, no Brad Fiedel-style anvil/synth melody lookalike [GENRE B1].
- No time-travel plot, no liquid-metal shapeshifter enemy, no T-shaped logos.
- Never write "Terminator-like" or "inspired by Terminator" in listing text, keywords, tags, screenshots or press.
- Do not use "Tower" in the title, icon or UI nouns in a way that suggests The Tower; our central object is "Cinder" and "the Relay".
- Do not reuse The Tower's exact enemy names, upgrade names, tier names, number tables or UI iconography.
- No real company names (note Cyberdyne Inc. is a real robotics company [GENRE B1]); "Orrery Combine" must be trademark-checked.

## 8. Glossary (stable ids)

### 8.1 Currencies (5)

| id | Display | Persistence | One-line |
|---|---|---|---|
| `scrap` | SCRAP | Resets each deployment | In-run currency for temporary stat levels |
| `data` | DATA | Permanent | Soft meta currency: Foundry, Lab, weapon-system levels, module levels |
| `flux` | FLUX | Permanent | Premium-adjacent currency: rush, lab slots, firmware picks, cosmetics. Earnable via capped ads |
| `cipher` | CIPHER | Permanent | Scarce progression currency: unlocks weapon systems, companion upgrades. From Gauntlets, milestones |
| `merit` | MERIT | Permanent, shop prices reset per season | Social/live-ops currency: events, Cells, Operation Pass shop |

### 8.2 Core game terms

| id | Term | Definition |
|---|---|---|
| `cinder` | Cinder | The protagonist; stationary at arena center |
| `relay` | The Relay | Diegetic name for the arena center / spawn target |
| `deployment` | Deployment | One run, wave 1 until integrity reaches 0 |
| `wave` | Wave | 24 s cycle (18 s spawn phase + 6 s lull at 1x) |
| `sector` | Sector | Difficulty ladder (S1-S12 launch). Equivalent of a tier |
| `integrity` | Integrity | Cinder's hit points |
| `exposure_band` | Exposure band | One of 4 visual/mechanical integrity bands (skin burn) |
| `foundry` | Foundry | Permanent stat upgrades bought with `data` |
| `lab` | R&D Lab | Timed research bought with `data` + time |
| `arsenal` | Arsenal | Menu grouping: weapon systems, firmware, modules, companions |
| `weapon_system` | Weapon system | Auto-firing special weapon (9), 3 equip slots |
| `firmware` | Firmware chip | Collectible, levelled by duplicates (1-5 stars), equipped in slots |
| `module` | Hardware module | Slot-type gear with rarity and fusion (post-launch) |
| `companion` | Companion drone | Timed-ability drone (4) |
| `patch` | Patch | In-run draft choice (perk equivalent) |
| `draft` | Draft | A moment when 3 patches are offered |
| `adaptation` | Adaptation | Swarm resistance per damage type (novel) |
| `overdrive` | Overdrive | Optional active ability |
| `salvage_cache` | Salvage cache | Elite/boss drop, tap for a choice |
| `turncoat` | Turncoat | Hacked enemy that fights for you briefly (N5, deferred to post-launch) |
| `standby_patrol` | Standby Patrol | Offline earnings system |
| `gauntlet` | Gauntlet | Tournament |
| `incursion` | Incursion | Live event |
| `cell` | Cell | Guild |
| `ops_board` | Ops Board | Daily/weekly missions |
| `operation_pass` | Operation Pass | Season pass |
| `sector_milestone` | Sector milestone | One-time wave goals with rewards |
| `power_rating` | Power Rating (PR) | Matchmaking number, `PR = 10 * log10(ref_dmg * ref_hp)` (see 06) |
| `intel` | Intel tab | In-game wave/enemy/stat info panel |

### 8.3 Damage types
`laser` (energy), `kinetic`, `arc`, `blast`, `nano`. Every damage source is tagged with exactly one (see 02 section 8).

### 8.4 Stat ids (in-run and Foundry share ids; full tables in 02 and 05)
Arms: `laser_output`, `cycle_rate`, `crit_chance`, `crit_mult`, `optic_range`, `standoff`, `split_chance`, `split_targets`, `burst_chance`, `burst_duration`, `ricochet_chance`, `ricochet_targets`, `overcrit_chance`, `overcrit_mult`, `armor_tear_chance`, `armor_tear_mult`.
Chassis: `hull_integrity`, `nano_repair`, `plating_pct`, `plating_flat`, `spike_return`, `siphon_cell`, `push_chance`, `push_force`, `razor_count`, `razor_speed`, `shock_size`, `shock_rate`, `mine_chance`, `mine_damage`, `fail_safe`, `barricade_hp`, `barricade_rebuild`.
Systems: `scrap_yield`, `scrap_per_wave`, `data_yield`, `data_per_wave`, `reinvest`, `free_arms`, `free_chassis`, `free_systems`, `pod_chance`, `pod_amount`, `signal_lag_atk`, `signal_lag_hp`, `sensor_reach`.

### 8.5 Enemy ids (full table in 03)
`skitter`, `dart`, `walker`, `lancer`, `aegis_node`, `shade`, `jammer`, `mender`, `siege_lance`, `siphon`, `brood`, `boss_hulk`, `boss_hive`, `boss_lance`, `boss_null`, `intruder`, `relay_mast`, `howitzer`.

### 8.6 Weapon system ids
`arc_discharge`, `emp_pulse`, `micro_missiles`, `singularity_charge`, `dilation_field`, `nanite_cloud`, `salvage_beacon`, `target_painter`, `proximity_grid`.

### 8.7 Companion ids
`drone_ember`, `drone_volt`, `drone_scav`, `drone_amp`.

### 8.8 Number format and units
Distances in meters (`m`), time in seconds (`s`) at 1x speed, percentages stored as fractions in data (0.25 = 25%). Big-number display rules are in 04.

### 8.9 Feature tags
Every system in the docs is tagged **MVP**, **Launch** or **Post-launch**. MVP = the first playable build (08). Launch = the 1.0 store release. Post-launch = scheduled after launch.
