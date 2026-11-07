# The Tower - Idle Tower Defense: Combat Loop and In-Run Systems

Source key (all fetched 2026-11-07 via public APIs):
- FW = community Fandom wiki, read through its MediaWiki API (wikitext). Base: https://the-tower-idle-tower-defense.fandom.com/wiki/ . Some pages cite patches up to v27.3 (Dec 2025) and v28.3, so they are reasonably current. Individual numbers are not dated. Direct WebFetch of Fandom returned HTTP 402/403; the api.php endpoint worked.
- NW = Notion community wiki, https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7 (Enemies, Fleets, Battle Conditions, Boss pages). Read through Notion's public loadPageChunk API because the HTML is JS-rendered. NW appears older than FW on some numbers (flagged below).

Structural caveat: meta-progression (Workshop, Labs, Cards, Modules) sets the starting value of every stat; in a run the player spends cash to raise the same stats. Level ranges below are Workshop level ranges, which are also the in-run level ranges.

## 1. Moment-to-moment loop, targeting, firing, damage intake, run end

### Takeaway
The tower sits in the screen centre and auto-fires at enemies inside a circular range (base 30 m, max 69.5 m from the Workshop). Enemies walk in from all sides, hit the tower in melee (or shoot from range), and the run (a "round") ends when tower HP reaches 0. Waves repeat forever (26 s spawn phase + 9 s cooldown), so a run is an endurance test of enemy scaling against your upgrades.

### Cited Findings
- Round = entire run: starts at wave 1, ends when you die. Wave = a 26.00 s spawn phase plus a 9.00 s cooldown with no spawns at 1x speed; next wave starts when both timers finish; cooldown is halved in tournaments. — [FW Gameplay](https://the-tower-idle-tower-defense.fandom.com/wiki/Gameplay)
- Tower is at screen centre; the Workshop (Attack/Defense/Utility tabs) is a bottom menu; upgrades are bought during a round with cash and outside rounds with coins. — [FW Gameplay](https://the-tower-idle-tower-defense.fandom.com/wiki/Gameplay), [FW Attack Upgrades](https://the-tower-idle-tower-defense.fandom.com/wiki/Attack_Upgrades)
- Range sets projectile reach (base 30 m, +0.5 m per level, 79 levels, max 69.5 m) and also the firing distance of Ranged enemies. — [FW Range](https://the-tower-idle-tower-defense.fandom.com/wiki/Range/Description), [NW Tower Range](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7)
- Ranged enemy attack range = (TowerRange - 30 m) x 0.75 + 30 m (range 30 m -> 30 m; 69.5 m -> 59.625 m). NW also lists "75 m -> 30 m", which contradicts the formula; treat as a doc error. — [NW Ranged](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7)
- Targeting: default nearest enemy in range; the "Target Priority" lab (unlock tier 4 wave 150, 2 levels) lets the player choose one enemy type to focus (L1) or sort priority across types (L2). — [FW Target Priority](https://the-tower-idle-tower-defense.fandom.com/wiki/Target_Priority)
- Damage per meter: bonus damage depends on enemy distance from tower in whole metres (rounds down); Damage x DPM% x range(m); 200 levels, base 0%, max 5.9% per metre. — [FW Damage Per Meter](https://the-tower-idle-tower-defense.fandom.com/wiki/Damage_Per_Meter)
- Enemy melee heat-up: each melee hit is 4% stronger than the previous (not ranged shots, Ray beam, Vampire drain). Coin decay: enemies still alive 3+ waves after spawning pay 50% coins. Enemy mass rises 4% per wave alive (knockback weakens). — [FW Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Enemies)
- On-screen caps: 120 Normal, 8 of each Elite type (+ up to 20 Scatter splits), 10 Bosses, 10 of each Fleet type plus 30 escorts. — [FW Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Enemies)
- Damage intake: Defense % applies first, then Defense Absolute; e.g. 100 dmg, 25% def, 50 abs -> 100 x 0.75 - 50 = 25. Defense % hard cap 98%. — [FW Defense Absolute](https://the-tower-idle-tower-defense.fandom.com/wiki/Defense_Absolute), [FW Defense Percent](https://the-tower-idle-tower-defense.fandom.com/wiki/Defense_Percent)
- eHP = (Health + DefAbs) / (1 - Def%); with Chrono Field: (Health/(1-CF%) + DefAbs)/(1-Def%). Recovery packages can push HP above max (up to x16.5). — [FW Health](https://the-tower-idle-tower-defense.fandom.com/wiki/Health)
- Death-prevention priority: Death Defy (chance) -> Energy Shield (negates one hit per charge) -> Second Wind (revive at 50% HP + 10-40 s invulnerability, once per round) -> Demon Mode (300x projectile damage + invincibility 180-300 s, once per round) -> Nuke (smart auto gives 15 s invulnerability since v27.3, Dec 2025). — [FW Death Defy](https://the-tower-idle-tower-defense.fandom.com/wiki/Death_Defy), [FW Second Wind](https://the-tower-idle-tower-defense.fandom.com/wiki/Second_Wind), [FW Demon Mode](https://the-tower-idle-tower-defense.fandom.com/wiki/Demon_Mode)
- Game speed: max raised by lab/perk (cap 6.25, displayed 6.3); wiki says x5 behaves closer to x4; all timers scale with it. — [FW Game Speed](https://the-tower-idle-tower-defense.fandom.com/wiki/Game_Speed)
- Overheat (since v28): after clearing wave 4,500 on any tier an Overheat panel appears; effects start at wave 15,000 on Tier 1 (each higher tier 250 waves earlier): Skip Decay 1%/wave and extra fleets every 100 waves; intended to shorten very long runs. — [FW Tiers](https://the-tower-idle-tower-defense.fandom.com/wiki/Tiers)
- Heat levels can stop orbs/instant-kill effects from killing outright, scaling their damage instead. — [FW Orbs](https://the-tower-idle-tower-defense.fandom.com/wiki/Orbs)

### Inferences
- Core loop for an original game: auto-aim nearest target within radius R; enemies melee-contact the tower with an escalating per-hit multiplier; the only fail state is HP 0, so a run is a race between exponential enemy scaling and exponential upgrade growth.
- The two-timer wave (spawn window then dead time) plus cash-per-wave at the end gives a natural cadence for interest and free-upgrade rolls.

### Gaps
- No single documented projectile damage pipeline (crit, super crit, DPM, rend, multishot order). Only land-mine damage formula is given: LandMineDmg% x Damage x (1 + CritFactor x CritChance) x (1 + SuperCritMult x SuperCritChance x CritChance) — [FW Land Mine](https://the-tower-idle-tower-defense.fandom.com/wiki/Land_Mine)
- Base enemy HP/damage per wave and spawn-rate formula: not found (section 5).

## 2. In-run upgrade categories and every individual upgrade

### Takeaway
Three Workshop tabs (Attack, Defense, Utility), each stat has a fixed level cap and linear per-level increment (except Damage/Health/Regen with 5000-6000 levels). Costs on the wiki are Workshop coin costs; an in-run cash cost curve is not separately published.

### Cited Findings
**Attack** ([FW Attack Upgrades](https://the-tower-idle-tower-defense.fandom.com/wiki/Attack_Upgrades))
- Damage: base 6 at level 1; 6000 levels; value ~1.05K at L100, 521K at L2000, 8.85M at L4000, 71.1M at L6000. Coin cost: L1 30, L100 80.7K, L1000 23.6M, L5000 868M, then a cost cliff (L5100 1.82B, L6000 5.1T). — [FW Damage/Cost](https://the-tower-idle-tower-defense.fandom.com/wiki/Damage/Cost)
- Attack Speed: base 1.00/s, +0.05/level, 99 levels, max 5.95. Also speeds projectile travel until the Light Speed Shots lab. Cost L1 30, L2 56, L10 725, L20 3.11K. — [FW Attack Speed](https://the-tower-idle-tower-defense.fandom.com/wiki/Attack_Speed/Description)
- Critical Chance: 1% start, +1%/level, 79 levels, max 80% Workshop (cards +11%, mastery +10%, sub-module +10%, relics +16%; over 100% only helps UW damage). Critical Factor: base x1.2, +0.1/level, 150 levels, max x16.2. — [FW Critical Hits](https://the-tower-idle-tower-defense.fandom.com/wiki/Critical_Hits)
- Range: 30 m base, +0.5 m/level, 79 levels, max 69.5 m.
- Damage/Meter: see section 1 (max 5.9% per metre).
- Multishot: Chance +0.50%/level, 99 levels, max 49.5%; Targets start 2, +1/level, 7 levels, max 9 (needs enough enemies in range). — [FW Multishot](https://the-tower-idle-tower-defense.fandom.com/wiki/Multishot/Description)
- Rapid Fire: Chance +0.40%/level, 85 levels, max 34%; fires x4 faster; Duration 99 levels, max 5.55 s. — [FW Rapid Fire](https://the-tower-idle-tower-defense.fandom.com/wiki/Rapid_Fire/Description)
- Bounce Shot: Chance +0.80%/level, 85 levels, max 68%; Targets base 1, +1/level, 7 levels, max 8 (14 with Bounce Shot perk); Range 2.0 m +0.1 m/level, 60 levels, max 8.0 m. Bounce-targeted enemies are not knocked toward the tower; projectile chases its chosen target. — [FW Bounce Shot](https://the-tower-idle-tower-defense.fandom.com/wiki/Bounce_Shot/Description)
- Super Crit: Chance +0.2%/level, 100 levels, max 20% (rolled only after a crit); Mult base x1.2, +0.1/level, 120 levels, max x13.2; total on super crit = CritFactor x SuperCritMult. — [FW Super Critical](https://the-tower-idle-tower-defense.fandom.com/wiki/Super_Critical/Description)
- Rend Armor: Chance 0.10% +0.10%/level, 299 levels, max 30%; Mult +0.001x per level, max 0.3x per application; permanent per-enemy damage-taken multiplier for tower projectiles only, stacking to 800%. — [FW Rend Armor](https://the-tower-idle-tower-defense.fandom.com/wiki/Rend_Armor/Description)
- Unlock order/cost in the Workshop (coins): Range 50, Damage/Meter 50, Multishot 400, Rapid Fire 1,500, Bounce Shot 10,000, Super Crit 100M, Rend Armor 500B (same pages).

**Defense** ([FW Defense Upgrades](https://the-tower-idle-tower-defense.fandom.com/wiki/Defense_Upgrades))
- Health: base 10, 6000 levels (L100 21.6K, L600 2.85M; cost L1 30). — [FW Health/Cost](https://the-tower-idle-tower-defense.fandom.com/wiki/Health/Cost)
- Health Regen: HP per second, 6000 levels; cards x2.6 (mastery x5), Second Wind mastery x10 for 400 waves; perks up to x8.8 (trade-off) or x5.94. — [FW Health Regen](https://the-tower-idle-tower-defense.fandom.com/wiki/Health_Regen)
- Defense %: +0.5%/level, 99 levels, max 49.5% Workshop; all sources total capped at 98%. — [FW Defense Percent](https://the-tower-idle-tower-defense.fandom.com/wiki/Defense_Percent)
- Defense Absolute: flat subtraction after Def%; 5000 levels. — [FW Defense Absolute](https://the-tower-idle-tower-defense.fandom.com/wiki/Defense_Absolute)
- Thorns: reflects % of the enemy's MAX health when it hits the tower (also ranged attackers; only 50% to bosses); +1%/level, 99 levels, max 99% (49.5% bosses); does not trigger lifesteal; Protectors cut thorn damage 60% in their field; Fleets resist 85% and take it on current HP. — [FW Thorn Damage](https://the-tower-idle-tower-defense.fandom.com/wiki/Thorn_Damage), [FW Fleet Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Fleet_Enemies)
- Lifesteal: heals % of damage dealt on every tower projectile hit (incl. bounce/multishot); 80 levels, max 4.46%. — [FW Lifesteal](https://the-tower-idle-tower-defense.fandom.com/wiki/Lifesteal)
- Knockback: Chance +1%/level, 80 levels, max 80%; Force base 0.4, +0.142/level, 40 levels, max 6.08 (unitless; heavier enemies pushed less; Ray and Fleets immune). — [FW Knockback](https://the-tower-idle-tower-defense.fandom.com/wiki/Knockback)
- Orbs: Orb Speed base 0.4 rpm +0.15/level, 38 levels, max 6.10. Orb count: 4 Workshop levels (+1 each), +2 perk, +2 ancestral sub-module, +2 Vault = up to 12 clockwise, plus up to 3 counter-clockwise card orbs. Orbs instantly kill normal enemies they touch (not Bosses, Elites, Fleets, or enemies under a Protector). Workshop orbs have 60 m minimum orbit radius; orb is 10 m wide. Boss damage only via Orb Boss Hit lab (up to 2% max HP per hit). — [FW Orbs](https://the-tower-idle-tower-defense.fandom.com/wiki/Orbs), [NW Orbs](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7)
- Shockwave: Size base 0.6 +0.05/level, 35 levels, max 2.35; Frequency base 20 s, -0.15 s/level, 40 levels, min 14 s (hard cap 7 s from other sources). Pushes enemies away (not bosses). — [FW Shockwave](https://the-tower-idle-tower-defense.fandom.com/wiki/Shockwave)
- Land Mines: Chance (enemy death may drop a mine) +0.6%/level, 50 levels, max 30%; Damage base 100% of tower damage +10%/level, 200 levels, max 2100%; Radius 50 levels, total 1.5; explodes after a timer. — [FW Land Mine](https://the-tower-idle-tower-defense.fandom.com/wiki/Land_Mine)
- Death Defy: +0.4%/level, 75 levels, max 30% chance to ignore a lethal hit. — [FW Death Defy](https://the-tower-idle-tower-defense.fandom.com/wiki/Death_Defy)
- Wall: blocks enemies until its HP is 0, then rebuilds (does not block while rebuilding). Wall Health = % of tower HP: 20% start, +0.1%/level, 1800 levels, max 200%; Wall Rebuild 300 levels of -2 s each (hard cap 150 s); rebuild pushes enemies away. Wall Regen lab (tier 10 wave 70) heals wall as % of tower regen; Wall Fortification lab (60 levels, +20% each) lets the wall overheal. — [FW Wall](https://the-tower-idle-tower-defense.fandom.com/wiki/Wall), [FW Wall Fortification](https://the-tower-idle-tower-defense.fandom.com/wiki/Wall_Labs/Wall_Fortification)

**Utility**
- Cash Bonus: multiplier on all cash, x1.00 +0.01/level, 149 levels, max x2.49; does not scale interest. Cash/Wave: 0 base, +4/level, 149 levels, max 596; multiplied by Cash Bonus, paid after cooldown, before interest. — [FW Cash Bonus](https://the-tower-idle-tower-defense.fandom.com/wiki/Cash_Bonus), [FW Cash Per Wave](https://the-tower-idle-tower-defense.fandom.com/wiki/Cash_Per_Wave)
- Coins/Kill Bonus: x1.00 +0.01/level, 149 levels, max x2.49. Coins/Wave: base 1, +1/level, 149 levels, max 150. — [FW Coins Per Kill Bonus](https://the-tower-idle-tower-defense.fandom.com/wiki/Coins_Per_Kill_Bonus), [FW Coins Per Wave](https://the-tower-idle-tower-defense.fandom.com/wiki/Coins_Per_Wave)
- Interest/Wave: +0.06%/level, 99 levels, max 5.94% of unspent cash at wave end; (cash + CashPerWave x CashBonus) x rate; payout cap per wave: base $50, Max Interest lab raises to $15,000, Cash enhancement up to x7 = $105,000. — [FW Interest](https://the-tower-idle-tower-defense.fandom.com/wiki/Interest), [FW Currency/Cash](https://the-tower-idle-tower-defense.fandom.com/wiki/Currency/Cash)
- Free Upgrades (Attack, Defense, Utility separate): chance after each wave to level a random stat of that tab for free; +0.5%/level, 99 levels, max 49.5% each; over 100% rolls extra upgrades; never picks a maxed stat; card+perk can reach 90.75%. — [FW Free Upgrades](https://the-tower-idle-tower-defense.fandom.com/wiki/Free_Upgrades)
- Recovery Packages: per-wave chance to spawn an auto-applied heal. Package Chance base 6%, +0.4%/level, 60 levels, max 30% (up to 82% with lab+card+substat); Recovery Amount base 14% max HP, +0.4%/level, 300 levels, max 134%; Max Recovery base x1.00, +0.031/level, 500 levels, max x16.5 of max HP (regen/lifesteal cannot overheal). — [FW Recovery Packages](https://the-tower-idle-tower-defense.fandom.com/wiki/Recovery_Packages)
- Enemy Attack Level Skip and Enemy Health Level Skip: chance per wave that the enemy stat level does not rise; 699 levels, 0.05% +0.05%/level, max 35% (labs add more); deterministic since v26 (50% skips every other wave). Tier 14+ battle condition "Enemy Level Skip Reduction" subtracts 2.5% (T14) to 42.5% (T24). — [FW Enemy Level Skip](https://the-tower-idle-tower-defense.fandom.com/wiki/Enemy_Level_Skip), [FW Tiers](https://the-tower-idle-tower-defense.fandom.com/wiki/Tiers)
- Starting Cash: runs begin with $80; lab adds $5/level up to $575. — [FW Currency/Cash](https://the-tower-idle-tower-defense.fandom.com/wiki/Currency/Cash)
- Buy multiplier (x1/x10/x100/Max, no discount) is a lab. — [FW Buy multiplier](https://the-tower-idle-tower-defense.fandom.com/wiki/Buy_multiplier)

**Other in-run actives (mention only):** Golden Tower (cash+coin multiplier window), Black Hole (pulls enemies; epicentre at 0.85 x tower range), Death Wave, Chain Lightning, Smart Missiles, Spotlight, Inner Land Mines, Poison Swamp, Chrono Field; Wave Skip card (chance to skip a wave for 1.1x income), Wave Accelerator (shrinks cooldown), Intro Sprint (fast-forward +10 waves per step, no coins). — [FW Wave Skip](https://the-tower-idle-tower-defense.fandom.com/wiki/Wave_Skip), [FW Intro Sprint](https://the-tower-idle-tower-defense.fandom.com/wiki/Intro_Sprint), [NW Black Hole](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7)

### Inferences
- Pattern: linear per-level increments with hard caps for chance stats (30-80%), and very deep 5000-6000-level pools for Damage/Health/Regen/DefAbs. Cost grows super-linearly (Damage ~30 at L1, 23.6M at L1000, then a steep cliff past L5000).
- Unlock chain gates complexity: simple stats first, specials (multishot, rapid fire, bounce, orbs, shockwave, mines, death defy, wall) unlocked progressively with increasing coin costs.

### Gaps
- In-run cash cost per level for each stat is not stated anywhere I read. Wiki tables give Workshop coin costs; they may be identical to cash costs, unconfirmed.
- Only Damage, Attack Speed, Health cost tables inspected in detail; other "/Cost" subpages exist on the wiki.

## 3. Cash economy and relation to coins

### Takeaway
Cash is run-only (reset on death; start $80) and funds in-run stat levels; coins are the permanent currency earned in the run (per kill and per wave) and spent outside on Workshop, Labs and Modules. Both scale with enemy type and wave; coins also with tier.

### Cited Findings
- Cash sources: kills, completing waves (Cash/Wave from wave 2), Interest, skipped waves, Golden Tower. Leftover cash is lost when the run ends. — [FW Currency/Cash](https://the-tower-idle-tower-defense.fandom.com/wiki/Currency/Cash)
- Enemy base cash value: $1 for waves 1-9, +$1 every 10 waves until wave 200 (100-109 = $11, 190-219 = $20), then +$1 every 20 waves (wave 300 $25, 500 $35, 1000 $60, 2000 $110, 5000 $260). Type multipliers: Basic x1; Fast/Ranged/Protector x1.5; Tank and Elites x3; Boss x5. — [FW Currency/Cash](https://the-tower-idle-tower-defense.fandom.com/wiki/Currency/Cash)
- End-of-wave order: Cash/Wave x Cash Bonus first, then Interest on that total. — [FW Interest](https://the-tower-idle-tower-defense.fandom.com/wiki/Interest)
- Coins: earned from kills, per wave, daily/weekly missions, tournaments, milestones; spent on Workshop, Labs, Modules. Permanent coin multipliers come from Milestones/events/real money; temporary from cards, modules, bots, UWs. — [FW Gameplay](https://the-tower-idle-tower-defense.fandom.com/wiki/Gameplay)
- Coin base per enemy: Basic 0 (only via Critical Coin card), Fast 2, Ranged 2, Protector 3, Tank 4, Boss 5, Elites 4, Fleets 4. Coins/Kill formula: (Workshop x CPK lab + CPK mod) x (1 + enhancement) x (1 + 0.15 x perk qty) x (1.8 x (1 + trade-off lab)). Tier coin bonus multiplies coins (table in section 5). — [FW Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Enemies), [FW Coins Per Kill Bonus](https://the-tower-idle-tower-defense.fandom.com/wiki/Coins_Per_Kill_Bonus)
- Coin decay: kills 3+ waves after spawn pay 50%. — [FW Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Enemies)
- Enemy Balance card: ~1.8x enemies spawn, boosting cash per kill (the card multiplier is cash only; coins rise via enemy count). Wave Skip: x1.1 income per skipped wave (compounding); Cash/Wave and Interest still paid. — [FW Enemy Balance](https://the-tower-idle-tower-defense.fandom.com/wiki/Enemy_Balance), [FW Wave Skip](https://the-tower-idle-tower-defense.fandom.com/wiki/Wave_Skip)
- Gems float on screen during rounds; Elite Cells drop from elites and speed up lab slots. — [FW Gameplay](https://the-tower-idle-tower-defense.fandom.com/wiki/Gameplay), [NW Cells](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7)
- Meta feed-in (one line): Workshop, Labs, Cards, Modules, Bots and UWs set a run's starting stats and multipliers; Workshop Enhancements add up to 4x multipliers per stat. — [NW Workshop Enhancements](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7)

### Inferences
- Cash buys power now (resets each run); coins buy permanent starting power. Interest rewards hoarding, in tension with spending cash on upgrades; the interest cap ($50 base) keeps early hoarding from dominating.

### Gaps
- Exact stacking of tier coin bonus with other coin multipliers is only partly stated.

## 4. Enemy types

### Takeaway
Four groups: Normal (Basic, Fast, Tank, Ranged, Protector; share 100% spawn chance per wave), Elite (Ray, Vampire, Scatter; immune to orbs/death ray/shockwave/black hole), Boss (every 10 waves, more often from Tier 14), and Fleets (Saboteur, Commander, Overcharge; large HP, escorts, tier 14+). Stats are multiples of a Basic enemy at the current wave.

### Cited Findings
Stat table (health x basic, speed x basic, base coins, cash multiplier) — [FW Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Enemies):

| Enemy | Health | Speed | Coins | Cash |
|---|---|---|---|---|
| Basic | x1 | x1 | 0 | x1 |
| Fast | x1 | x2.1 (up to ~x3.9 from wave 750) | 2 | x1.5 |
| Tank | x5 | x0.6 | 4 | x3 |
| Ranged | x1 | x1.2 | 2 | x1.5 |
| Protector | x0.6 | x0.4 | 3 | x1.5 |
| Boss | x20 | x0.4 | 5 | x5 |
| Vampire | x2 | x0.4 | 4 | x3 |
| Ray | x1 | x0.4 | 4 | x3 |
| Scatter | x2 | x0.6 | 4 | x3 |
| Saboteur | x20 | x2.1+ | 4 | x3 |
| Commander | x20 | x0.2 | 4 | x3 |
| Overcharge | x20 | x0.2 | 4 | x3 |

NW lists older values (Fast 2x speed, Tank 50% speed and 5x HP, Boss 30% speed, Scatter 2x HP, Ray 2x basic damage beam) — [NW Fast/Tank/Boss pages](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7); FW is treated as more recent.
- Basic: no special traits. Fast: rushes the tower. Tank: slow, 5x HP. Ranged: stops at its attack range (section 1) and shoots; thorns still affect ranged attackers.
- Protector: tier 2+; max 1 spawn per wave with cooldown 10 waves (9 from T4, 8 from T7, 7 from T10), max 10 alive; field around it stops instant kills (orbs, death ray) and reduces damage taken by enemies inside: NW says 60% reduction, FW's Protector blurb says 40% less (conflict; FW's thorns text says 60% for thorns); Protectors cannot be hurt by orbs. — [FW Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Enemies), [NW Protector](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7)
- Elites: share a spawn chance that steps 1%, 4%, 9%, 16%, 25%, 36%, 49%, 64%, 81%, 100%; wave needed for each step falls ~10% per tier (33% shown needs wave 8000 on T1, 2033 on T14, 620 on T24); max 1 per wave, 2 at high waves; kills drop Elite Cells. — [FW Elite Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Elite_Enemies)
  - Ray: charges 30 s then fires a beam of 2x basic damage; immune to knockback.
  - Vampire: drains 2% of tower max HP per second and disables Health Regen and Lifesteal (not Wall Regen) while attacking; modifiers cannot alter it.
  - Scatter: splits 4 times into 2 each (up to 16 children); children have 1x, 1/4, 1/9, 1/16 of basic HP; a guide counts 31 hits taken per Scatter. — [FW Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Enemies), [Tier-Specific Guide](https://the-tower-idle-tower-defense.fandom.com/wiki/Tier-Specific_Guide)
- Boss: 0% spawn on normal waves, 100% on boss waves (every 10 waves on T1-13; every 9, 8, 7, 6 on T14-17, every 5 from T18). T1-6 boss spawns at a fixed point; T7+ at a random time 5%-75% of the wave. Immune to orbs (except Orb Boss Hit lab), Death Ray, Shockwave, Black Hole. Drops common module 2%, rare 0.5%, reroll shards 15% (base). Thorns do 50% to bosses. — [FW Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Enemies), [NW Boss](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7)
- Fleets (tier 14+, plus very high waves on every tier: T1 from wave 15,000, each higher tier 250 waves earlier, every 100 waves): spawn with 10-15 escorts (Overcharge+Ranged, Commander+Tank, Saboteur+Fast; separate 30-slot pool). Immune to Orbs, Death Ray, Shockwave, knockback, Black Hole; 85% thorns resistance; 50% resistance to Chrono Field/stuns; Plasma Cannon cannot target them. — [FW Fleet Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Fleet_Enemies)
  - Saboteur: runs at tower; each hit lowers a random UW's level by 1 (disabled at 0), restored on death; deals 0 damage; wall blocks it.
  - Commander: stays out of range; pulses 1.15x health, mass and speed to enemies in its area, cap 8 boosts per enemy; not bosses.
  - Overcharge: stops inside range, fires a returning projectile that deals 1.4x more per hit (older NW: doubles); damage locked to wave-1 damage of that tier; fires a final projectile on death.
  - Fleet frequency (first wave / waves per fleet): T14 2495/1000, T15 1495/750, T16 995/500, T17 495/250, T18 95/100, T19 45/50, T20 wave 5 and 1 per 10 waves, T21 2 per 10, T22-24 3 per 10. Fleet drops: reroll shards (80%) or module shards.
- Per-enemy labs (meta) permanently change each type's attack/health/speed.
- Counters: orbs/black hole/death ray/shockwave for Normal; thorns without knockback, or knockback + DPS, for Elites; Plasma Cannon, Energy Net and thorns for Bosses; wall absorbs Saboteur. — [Tier-Specific Guide](https://the-tower-idle-tower-defense.fandom.com/wiki/Tier-Specific_Guide), [FW Fleet Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Fleet_Enemies)

### Inferences
- Enemy design uses orthogonal axes (speed, HP multiplier, ranged vs melee, immunities, auras); immunity to the cheapest instant-kill tool (orbs) is what makes elites/bosses/fleets the late-game check.

### Gaps
- Base per-wave enemy damage and HP are not published (visible only in the in-game Wave Info tab).

## 5. Waves, scaling, tiers, battle conditions

### Takeaway
Waves are 35 s (26 s spawn + 9 s cooldown). Tiers 1-24 are static difficulty ladders: each multiplies coin rewards (1.0 up to 103x), and from T14 adds fixed Battle Conditions. A tier unlocks by reaching wave 100 on the previous (wave 300 for T16+). Enemy stat growth per wave is by "enemy levels" that Level Skips can skip.

### Cited Findings
- Tier unlock: 100 waves on the current tier unlocks the next; tiers 16-24 require 300 waves on the previous tier. (NW's Tier 14 page: "Reaching wave 100 unlocks tier 15"; a guide notes the jump to 300 starts at T15/T16.) — [FW Tiers](https://the-tower-idle-tower-defense.fandom.com/wiki/Tiers), [NW Tier 14](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7), [FW Rushing Tiers](https://the-tower-idle-tower-defense.fandom.com/wiki/Rushing_Tiers)
- Tier coin bonus: T1 1.0, T2 1.8, T3 2.6, T4 3.4, T5 4.2, T6 5.0, T7 5.8, T8 6.6, T9 7.5, T10 8.7, T11 10.3, T12 12.2, T13 14.7, T14 17.6, T15 21.3, T16 25.2, T17 29.1, T18 33.0, T19 40.0, T20 48.0, T21 60.0, T22 72.0, T23 86.0, T24 103.0. — [FW Tiers](https://the-tower-idle-tower-defense.fandom.com/wiki/Tiers)
- Tier battle conditions (static, T14+): More Bosses (every 9 waves at T14 down to 5 at T18+); Orb Resistance and Death Ray Resistance (50% dmg at T14 down to 5% at T19+); Thorns and Plasma Cannon Resistance (80% at T14 to 5% at T22+); Enemy Level Skip Reduction (2.5% at T14 to 42.5% at T24); Knockback Resistance and Armored Enemies from T15 (armor blocks N hits: 10 at T15, +10 per tier, 95 at T24); enemy "Ultimates": Protector (T16+), Tank (T17+), Ray faster/Scatter more HP/Vampire more drain (T18+), Fast (T19+), Boss overheal (T20+), Mass Enforcement (T21+), Saboteur through-wall chance (T22+), Commander (T23+), Overcharge scaling (T24). — [FW Tiers](https://the-tower-idle-tower-defense.fandom.com/wiki/Tiers), [NW Battle Conditions](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7)
- Tournaments reuse battle conditions with variable wave counts and no perks; Copper tournament has none. — [NW Battle Conditions](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7), [FW Perks](https://the-tower-idle-tower-defense.fandom.com/wiki/Perks)
- After each wave enemy attack level and health level rise unless skipped (up to 35% Workshop chance plus labs); Wave Info tab shows total skips per run. — [NW Wave Info](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7), [FW Enemy Level Skip](https://the-tower-idle-tower-defense.fandom.com/wiki/Enemy_Level_Skip)
- Wave Info tab (tap wave counter) shows spawn chance, health, attack, speed, mass per enemy, wave timer, wave cooldown, protector radius, drop chances, active enemies/spawn rate. — [NW Wave Info](https://the-tower.notion.site/1bf91383b93f80b39962d0d6d4cd07a7)
- Run-length context: first perk at wave 200, all 79 perks at wave 23,150; Overheat on Tier 1 from wave 15,000; i.e. runs of thousands of waves are normal late game. — [FW Perks](https://the-tower-idle-tower-defense.fandom.com/wiki/Perks), [FW Tiers](https://the-tower-idle-tower-defense.fandom.com/wiki/Tiers)
- Daily mission coin rewards scale with highest tier unlocked (25 coins per mission at T1, 500,000,000 at T18, per a guide). — [Tier-Specific Guide](https://the-tower-idle-tower-defense.fandom.com/wiki/Tier-Specific_Guide)

### Inferences
- Likely structure: enemy HP and attack are per-wave "levels" that grow every wave (unless skipped), times a per-tier base; coin bonus per tier is ~+0.8 linear on T1-8 then accelerates. For an original game, per-wave exponential growth with partial skips and a per-tier reward multiplier reproduces the feel.

### Gaps
- Exact formula for enemy health/damage by wave and by tier: not found on FW, NW, or search; only visible in-game. A Notion "Kill Wave Calculator for Death Wave" exists but its formula was not retrievable.
- Spawn rate (enemies per second per wave): not found.
- One 12-tier "101 waves per tier" claim from a low-quality fan guide is outdated (game now has 24 tiers); ignored.

## 6. In-run modifiers: perks, cards, battle conditions

### Takeaway
Perks are the in-run draft: from wave 200 you pick 1 of 2-4 random perks (none in tournaments); each offered perk is 68% standard, 12% trade-off, 20% Ultimate Weapon perk. Battle conditions are the enemy-side modifiers (tier 14+ and tournaments).

### Cited Findings
- Cadence: first perk at wave 200; base waves-per-perk becomes 250 after 20 perks, 300 after 30, 350 after 40; reduced by the Waves Required lab and the Perk Wave Requirement perk. Cumulative: 1st at 200, 20th at 4,000, 30th at 6,500, 40th at 9,500, all 79 at 23,150. Offers are fixed per run (no reroll); labs raise choices to 4, ban perks, guarantee first choice, auto-pick by ranking. — [FW Perks](https://the-tower-idle-tower-defense.fandom.com/wiki/Perks)
- Math: additive perks Total = Base x Qty x (1 + SPB); multiplicative perks Total = (1 + Base x Qty) x (1 + SPB); SPB = Standard Perk Bonus lab (up to +25%). — [FW Perks](https://the-tower-idle-tower-defense.fandom.com/wiki/Perks)
- Standard perks (max picks): x1.20 Max Health (5), x1.15 Damage (5), x1.15 all coin bonuses (5), x1.15 Defense Absolute (5), x1.15 Cash Bonus (5), x1.75 Health Regen (5), Interest x1.50 (5), Land Mine Damage x3.50 (5), +5% Free Upgrade chance (5), Defense % +4 (5), Bounce Shot +2 targets (3), Perk Wave Requirement -20% (3), Orbs +1 (2), Unlock random Ultimate Weapon (1), +1 max game speed (1). — [FW Perks](https://the-tower-idle-tower-defense.fandom.com/wiki/Perks)
- Trade-off perks: x1.5 damage but bosses x8 HP; x1.8 coins but max HP -70%; enemies -50% HP but regen and lifesteal -90%; enemy damage -50% but tower damage -50%; ranged enemies shorter range but x3 damage; enemy speed -40% but damage x2.5; x12 cash per wave but kills give no cash; regen x8 but max HP -60%; boss HP -70% but boss speed +50%; lifesteal x2.5 but knockback force -70%. Improve-Trade-off lab adds up to +10% to benefits only. — [FW Perks](https://the-tower-idle-tower-defense.fandom.com/wiki/Perks)
- UW perks: +4 smart missiles, swamp radius x1.5, +1 death wave, extra inner mines set, golden tower bonus x1.5, chain lightning damage x2, chrono +5 s, black hole +12 s, spotlight x1.5. — [FW Perks](https://the-tower-idle-tower-defense.fandom.com/wiki/Perks)
- Guide math: with perks, defense can reach 99.1% effective (incl. enemy damage -55%) and regen up to x45.6, while damage gains only ~+80%, so perks favor defensive builds. — [Tier-Specific Guide](https://the-tower-idle-tower-defense.fandom.com/wiki/Tier-Specific_Guide)
- Cards (meta loadout active in run): Health, Damage, Cash, Coins, Wave Skip, Wave Accelerator, Energy Shield, Second Wind, Demon Mode, Intro Sprint, Enemy Balance, Slow Aura etc.; effects covered above where in-run relevant.
- Tier 14+ battle conditions: see section 5.

### Inferences
- Perks are a wave-threshold draft with strong risk/reward trade-offs; maps well to a "milestone pick" system in an original game.

### Gaps
- Full card effect list (meta, out of scope).

## 7. Commonly cited builds and strategies, and why they work

### Takeaway
Because enemies scale endlessly, builds split into tier-rushing/blender thorns (progression), health/eHP builds, hybrid, glass cannon farming at high tiers, and "devo" coin-farming variants that deliberately weaken the tower so enemies stack up and die inside UW multiplier windows.

### Cited Findings
- Blender Thorns: Knockback keeps normal enemies at the edge of range, Orbs at the edge instakill them, Plasma Cannon plus Thorns two-shot bosses; used to reach wave 100 and unlock the next tier. — [Tier-Specific Guide](https://the-tower-idle-tower-defense.fandom.com/wiki/Tier-Specific_Guide)
- Bosses are only susceptible to Thorns, Plasma Cannon and Energy Net; once Plasma Cannon removes ~54% of boss HP it can be one-shot by Thorns if max HP is high enough. — [Tier-Specific Guide](https://the-tower-idle-tower-defense.fandom.com/wiki/Tier-Specific_Guide)
- Health build: buy cheap short Defense stats first so Free Upgrades hit Health; keep Damage:Health cost near 1:1 to 1:2; weakness vs Protectors; "buy health, keep buying health", thorns topped off, orb speed maxed, shockwave pushes enemies into orbs. — [FW Health Build](https://the-tower-idle-tower-defense.fandom.com/wiki/Health_Build), [FW Strategies](https://the-tower-idle-tower-defense.fandom.com/wiki/Strategies)
- Hybrid: equal investment in damage and health; for T1-T11; T12 needs a well-developed Wall, then switch to Glass Cannon; top tournament players still use hybrid. — [FW Hybrid Guide](https://the-tower-idle-tower-defense.fandom.com/wiki/Hybrid_Guide)
- Devo: set Attack Speed, Multishot, Rapid Fire, Bounce, Orbs, Land Mine chance, Free Upgrades to 0 so the tower kills slowly; enemies pile up (held by wall/regen/knockback/thorns tuning) so that when Black Hole + Golden Tower (+ Death Wave/Smart Missiles) sync, many enemies die inside the multiplier window; cash mid-run goes into offense stats. Variants: Max Devo, Orb Devo, SMAX Devo, Orbless (kills only inside Spotlight zones; survives via wall, permanent BH or glass-cannon juggling; suited to 7000+ wave runs). — [FW SMAX Devo](https://the-tower-idle-tower-defense.fandom.com/wiki/SMAX_Devo), [FW Orbless Guide](https://the-tower-idle-tower-defense.fandom.com/wiki/Orbless_Guide), [FW Devo Guide](https://the-tower-idle-tower-defense.fandom.com/wiki/Devo_Guide) (marked out of date after v0.24.4)
- Defensive farming: keep enemies alive with Knockback or perma-Black Hole, then kill them together while GT + DW + BH are up; orb kills earn x1.4 coins with Extra Orbs mastery lvl 9. — [Tier-Specific Guide](https://the-tower-idle-tower-defense.fandom.com/wiki/Tier-Specific_Guide)
- Tier rushing: swap to a one-off build (Death Defy, Energy Shield, Plasma Cannon, Second Wind, Demon Mode, Nuke, Intro Sprint) to hit early wave milestones (~100); stops working past T15 as resistances grow and unlock cost rises to 300 waves. — [FW Rushing Tiers](https://the-tower-idle-tower-defense.fandom.com/wiki/Rushing_Tiers)
- eHP reasoning: thorns reflect % of enemy max HP, so survivability (Health, Def%, DefAbs, regen, wall) lets thorns/orbs do the killing; Def% caps at 98%, so after that Health/regen/wall scale. — [FW Health](https://the-tower-idle-tower-defense.fandom.com/wiki/Health), [FW Defense Percent](https://the-tower-idle-tower-defense.fandom.com/wiki/Defense_Percent)
- Pushing vs farming: coin value halves for enemies alive 3+ waves (a cost to stacking), and higher waves/tiers raise coin income; Overheat and skip decay limit ultra-long runs. — [FW Enemies](https://the-tower-idle-tower-defense.fandom.com/wiki/Enemies), [FW Tiers](https://the-tower-idle-tower-defense.fandom.com/wiki/Tiers)

### Inferences
- Glass cannon (offense-heavy) works when enemies die before reaching the tower; wiki says it is preferred from about T12 onward for farming. This is inferred from the Hybrid page; the Glass Cannon page itself was not read.
- Design lesson: any non-scaling "instant kill" (orbs, black hole, death wave) is an efficient farming engine that elites/bosses/fleets are explicitly immune to, forcing a real stat check.

### Gaps
- No access to r/TheTowerGame or Discord content for the latest (late 2026) meta. Wiki pages cite patches up to v27.3 (Dec 2025) and v28.3; the current game version was not confirmed.
