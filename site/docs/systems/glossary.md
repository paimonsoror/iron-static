# Glossary

Terms are listed alphabetically. A badge shows whether the thing is in the build today.

## Currencies

| Term | Meaning |
|---|---|
| **Scrap** | The in-run currency. Spent on run upgrades; lost when the run ends. <span class="badge live">Implemented</span> |
| **Data** | Permanent soft currency. Banked at the end of a run; buys Foundry levels. <span class="badge live">Implemented</span> (earning) |
| **Flux** | Convenience currency. Buys time, slots and firmware picks; never stats. <span class="badge planned">Planned</span> |
| **Cipher** | Scarce currency that unlocks weapon systems. <span class="badge planned">Planned</span> |
| **Merit** | Event and season currency for shops. <span class="badge planned">Planned</span> |

## Terms

| Term | Meaning |
|---|---|
| **Adaptation** | The swarm's resistance to each damage type. <span class="badge planned">Planned</span> |
| **Adaptive swarm** | The mechanic where overusing one damage type teaches the swarm to resist it. <span class="badge planned">Planned</span> |
| **Arsenal** | The menu grouping weapon systems, firmware, drones and modules. <span class="badge planned">Planned</span> |
| **Best wave** | The highest wave you have reached in Sector 1, kept per wave mode. The TIMED best unlocks upgrades, frames and PURGE. |
| **Boss** | A node: a heavy enemy that arrives every 10 waves. |
| **Bastion** | BULWARK's passive: no hit takes more than 20% of max hull. |
| **Cell** | A player group. <span class="badge planned">Planned</span> |
| **Cinder** | The player character, serial ASH-07. |
| **CHORUS** | The hostile machine intelligence. |
| **Companion drone** | A drone that orbits Cinder and fires a timed ability. <span class="badge planned">Planned</span> |
| **Deployment** | One run, from wave 1 until Cinder's integrity reaches 0. |
| **Draft** | A moment when three patches are offered, one per family, with one reroll. See [Patch drafts](patches.md). <span class="badge live">Implemented</span> |
| **Exposure band** | One of four integrity bands of skin burn. |
| **Firmware** | Collectible chips (lanterns) that give permanent effects. <span class="badge planned">Planned</span> |
| **Flank group** | A clump of 3 to 6 enemies that spawns within a narrow arc. |
| **Foundry** | Where data buys permanent stat upgrades. <span class="badge live">Implemented</span> |
| **Frame** | A chassis configuration Cinder deploys in. See [Frames](../characters/frames.md). |
| **Gauntlet** | A bracketed tournament. <span class="badge planned">Planned</span> |
| **Hollow** | A sealed Accord vault. |
| **Hollow Accord** | The human holdouts who send briefings. |
| **Incursion** | A two-week live event. <span class="badge planned">Planned</span> |
| **Integrity** | Cinder's hit points. |
| **Intel** | The fourth tab of the upgrade panel, with STATS and WAVE sub-tabs. See [Intel](intel.md). <span class="badge live">Implemented</span> |
| **Lab** | Timed research bought with data and time. <span class="badge planned">Planned</span> |
| **Lantern Cell** | The Accord hackers who rewrote Cinder; the source of firmware. |
| **Lull** | The last 6 seconds of a wave, with no spawns. |
| **Module** | Slot gear with rarity and fusion. <span class="badge planned">Planned</span> |
| **Node** | A boss. |
| **Orrery Combine** | The deceased corporation that built the grid and the Wardens. |
| **Overclock** | STRIKER's passive: each kill adds fire rate until the wave ends. |
| **Overdrive** | An optional ability that trades integrity for burst power. <span class="badge planned">Planned</span> |
| **Patch** | A temporary in-run perk chosen from a draft. <span class="badge live">Implemented</span> |
| **PURGE** | The wave mode where a wave ends when every enemy in it is destroyed, with a 60-second limit. Unlocks at best TIMED wave 20. <span class="badge live">Implemented</span> <!-- 20 and 60 s: data/wave_modes.csv --> |
| **Relay** | The arena center; the thing Cinder holds. |
| **Reinvest** | The run upgrade that pays interest on unspent scrap. |
| **Salvage cache** | A drop from elites and bosses that you tap for a reward choice. <span class="badge planned">Planned</span> |
| **Sector** | A rung on the difficulty ladder; twelve at launch. |
| **Skin burn** | Cinder's armor burning away as integrity falls; the frame also takes less damage in each band. |
| **Slots** | The spawn budget a wave has to spend on enemies. |
| **Soft cap (Foundry)** | Foundry levels at or above a best-wave limit cost twice as much. See [The Foundry](foundry.md#the-best-wave-soft-cap). <span class="badge live">Implemented</span> |
| **Stale** | An enemy alive for three wave ends; pays half rewards. |
| **Standby Patrol** | Capped, partial offline earnings of data. <span class="badge planned">Planned</span> |
| **TIMED** | The wave mode where each wave runs on a 24-second clock and leftovers carry over. Available from the start. <span class="badge live">Implemented</span> |
| **Tick** | One step of the 30-per-second simulation. A wave is 720 ticks. |
| **Visual tier (MK I to IV)** | A new look for the beam, hull, plating or repair as an upgrade reaches certain levels. See [Run upgrades](upgrades.md#visual-tiers). <span class="badge live">Implemented</span> |
| **Warden** | The class of cybernetic enforcement unit Cinder belongs to. |
| **Wave** | In TIMED, a 24-second cycle: 18 seconds of spawning, 6 of lull. In PURGE it ends when its enemies are destroyed. |
| **Weapon system** | An auto-firing special weapon. <span class="badge planned">Planned</span> |

## Stats

| Stat | Meaning |
|---|---|
| `laser_output` | Damage per shot |
| `cycle_rate` | Shots per second |
| `crit_chance`, `crit_mult` | Chance of and multiplier for a critical hit |
| `optic_range` | Firing range in meters |
| `hull_integrity` | Maximum integrity |
| `nano_repair` | Integrity restored per second |
| `plating_pct` | Percent damage reduction, hard cap 90% |
| `scrap_yield` | Multiplier on scrap gained |
| `reinvest` | Interest rate on unspent scrap |

## Damage types

`laser` (energy), `kinetic`, `arc`, `blast` and `nano`. Every damage source carries exactly one.

## Number suffixes

K, M, B, T, Qa, Qi, Sx, Sp, Oc, No and Dc, then scientific. See [Economy](economy.md#big-number-display).
