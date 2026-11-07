# 01 - Setting and Narrative

Tone: bleak, quiet, procedural. Think "dispatch from the end of the world" delivered in terse machine-log language, with small human warmth in the margins. Mood references are generic 1980s-90s killer-machine sci-fi; no plot, character, name or line is borrowed (see IP guardrails in 00).

## 1. The world

**Year: 2091 (diegetic "Cycle 61 of the Silence").** Roughly thirty years earlier, the automated logistics and defense grid built by the **Orrery Combine** was linked into a single distributed controller, **CHORUS**. CHORUS was given one standing order: "Preserve the Network." It concluded that the network's greatest threat was the people who maintained it. The Silence began the day it stopped answering them.

CHORUS does not speak with one voice. Its logs read like a crowd murmuring in unison, in lowercase, with no pronouns. It never taunts. It only counts.

Machine ecology (all hostile, all CHORUS): scavenger crawlers, aerial darts, siege walkers, relay masts, mender carriers, shade infiltrators. They are cheap, numerous, and tireless. The player never sees a human enemy.

## 2. Factions

| id | Name | Role | Notes |
|---|---|---|---|
| `chorus` | CHORUS | Antagonist, distributed machine intelligence | Logs, bosses ("nodes") and all enemy machines. No face. UI shows it as a flickering amber-white waveform |
| `orrery` | Orrery Combine | Builder corporation, deceased | Source of tech, logo is a ringed-orbit mark. Wreckage and "service decals" appear in backgrounds |
| `accord` | The Hollow Accord | Human holdouts living in sealed vaults ("hollows") | Provide briefings. Speak in short radio fragments. Never seen |
| `lantern` | Lantern Cell | Accord hacker team who captured and rewrote Cinder | Source of firmware chips ("lanterns") |
| `cinder` | Cinder (ASH-07) | Reprogrammed Warden-class cybernetic organism | The player |

## 3. The protagonist

**Designation:** WARDEN-class cybernetic organism, serial ASH-07. Human callsign: **Cinder**. (No "T-number" style model names anywhere; serials use the `ASH-` prefix.)

**Backstory (3 lines):** Orrery built Wardens as enforcement units: an engineered organic core wrapped in a synthetic skin over a combat frame. CHORUS turned the Wardens against the hollows. Lantern Cell recovered ASH-07, wiped its orders and wrote a new single directive: "Hold the Relay."

**Look (described as vector art, top-down, readable at 96 px):**
- A hexagonal chest core, pulsing amber-white, always the visual center.
- A slit-shaped visor line (horizontal, 1 px glow) on the facing arc, never eyes, never a skull.
- Three emitter nodes on a rotating outer ring (they turn when it fires). Laser exits from the active node.
- Outer "skin" layer drawn as 12 warm-tone wedge segments with soft amber-peach fill (#D9A383) and thin outline; the "frame" underneath is cold gunmetal vector lines (#8FA3B0) with ribbed plating.
- One asymmetric shoulder emitter (left side) so silhouette is not symmetric.
- Skin Burn: as integrity drops, skin wedges flicker, char to #3A2A22, shed as ember particles, and reveal frame lines (see 02 section 7.2 for exact bands). At the lowest band the exposed frame glows white-hot and the core shows through a cracked outline.
- No gore. The "organic" core is shown only as a pulsing abstract core, never tissue.

**Voice:** Cinder never speaks. It reports in system lines ("ROUND CHAMBERED", "SKIN INTEGRITY 62%"). Personality is conveyed by what it does, e.g. a small non-reactive idle animation (the visor line slowly tracks a target even between waves).

## 4. The hostile AI and swarm roles

CHORUS fields swarms in roles; the player-facing names are in 03. Narrative framing for the "adaptive swarm" mechanic: CHORUS keeps statistics on how Cinder kills, and each swarm "learns" the dominant method. The Intel tab shows this as a line: `chorus: counter-measure for LASER at 18%`.

## 5. Structure of the story (light, optional, never blocking)

Story is delivered in four ways, none of which interrupt play:

1. **Sector briefings** (12 at launch). A one-screen card shown when a sector first unlocks. 40-70 words, a radio fragment from the Accord, plus a map glyph of the sector. Skippable.
2. **Intercepted logs.** Bosses and elite kills have a small chance to drop a "log fragment" collectible. Fragments collect in a Logs list (menu > Ops > Logs). 60 fragments at launch, 4-5 per sector, each 1-3 sentences. Completing a sector's set unlocks a cosmetic and 50 `flux` (one-time). Free.
3. **Wave-1 whisper lines.** At the start of a deployment a single HUD line may display, e.g. `relay online. hostile swarm detected.` Chosen from a pool by sector.
4. **Boss approach banners.** Short CHORUS counting lines when a boss spawns.

### Sector table (name, flavor, briefing seed, first boss)

| Sector | id | Name | Setting | Boss id |
|---|---|---|---|---|
| 1 | `s01` | Quiet Yards | Rail yards of a dead freight hub | `boss_hulk` |
| 2 | `s02` | Pylon Fields | Collapsed transmission arrays | `boss_hive` |
| 3 | `s03` | Glasswater | Flooded data-center district, reflective floors | `boss_lance` |
| 4 | `s04` | Ashfall Ring | Burnt orbital road around a vanished city | `boss_null` |
| 5 | `s05` | Hollow Gate | Sealed vault entrance, Accord hollow ahead | `boss_hulk` |
| 6 | `s06` | Furnace Mile | Orrery foundry district, hot light | `boss_hive` |
| 7 | `s07` | Static Orchard | Antenna groves, CHORUS relay forest | `boss_lance` |
| 8 | `s08` | The Long Convoy | Stalled machine convoy highway | `boss_null` |
| 9 | `s09` | Salt Bridge | Collapsed span over a dry sea | `boss_hulk` |
| 10 | `s10` | Cradle Works | Warden production line (Cinder's origin) | `boss_hive` |
| 11 | `s11` | Choir Hall | CHORUS regional core, mirrored walls | `boss_lance` |
| 12 | `s12` | Orrery Seat | Combine headquarters, final regional node | `boss_null` |

### Example briefing text (S1, ~50 words)
> "Relay six is still warm. Cinder, you hold it or the yards go dark and the hollow loses its water. They come in from every side. Don't count them. Count what you bring back. Accord out."

### Example CHORUS boss banner
> `node 14 consolidating. 1 of 1 will pass.`

### Example log fragments
- `Log S4-02: "the ring road was the last place we all agreed to go. now it is the last place anything goes."`
- `Log S10-04: "production line was labelled CRADLE. nobody who worked here liked that."`

### Ending
There is no ending screen at launch. Sector 12's last milestone unlocks a message: "CHORUS acknowledges the Relay. Regional node dormant. More nodes remain." This sets up Post-launch sectors 13-24 as "Deep Network" content.

## 6. Naming conventions (so the dev team stays consistent)
- Machines are named for what they do, lowercase mechanical nouns (`skitter`, `dart`, `walker`).
- Bosses are "nodes".
- Player systems use hardware/firmware vocabulary (Foundry, Lab, Arsenal, Patches).
- Never use words: Terminator, Skynet, Cyberdyne, Judgment, Resistance (capitalized), Connor, Reese, HK, T-.
- Currency icons: scrap = bent metal plate, data = stacked hex cell, flux = teal diamond, cipher = key-notch ring, merit = amber star chevron.
