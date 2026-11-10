# Development status

IRON STATIC is in active development. This page says what you can play today and what is coming. Last updated 2026-11-10.

## What is in the build today

<span class="badge live">Implemented</span>

- The full in-run loop: deployments, waves, spawn rings, flank groups, stale-enemy rule.
- Cinder with an auto-firing hitscan laser, crits and range.
- Five enemies: skitter, dart, lancer, walker and the boss hulk (without its plate mechanic).
- Ten run upgrades in three tabs, with tap and hold-to-buy and formula tooltips.
- Skin burn: four exposure bands with ember particles, a low-integrity haze and a heartbeat.
- The results screen with the enemy that destroyed Cinder, best-wave gain, data banked and its new total, a kill strip, unlock chips, and REDEPLOY, FOUNDRY and HOME; pause and a speed button.
- Android back gesture handling and automatic pause when the app goes to the background.
- Synthesized sound effects and adaptive music; an animated machine-vision arena.

## Added by milestone M3

<span class="badge live">Implemented</span>

- The **title screen** (CONTINUE, NEW GAME, SETTINGS) with the selected frame as its hero and a wind-and-metal ambience, and the NEW GAME confirmation that resets your profile.
- **Home**, between deployments: Cinder, Power Rating, data, best wave and the next unlock.
- The **Foundry**: four permanent rows bought with data, tap and hold-to-buy, a Recommended tag.
- **Three frames** (VANGUARD, BULWARK, STRIKER) with the Bastion and Overclock passives, unlocked at best wave 8 and 15, and the **frame bay**, opened from the FRAME chip on Home (and from NEW GAME).
- The **Settings screen**, including a Data section with a double-confirmed profile reset.
- **Saving**: crash-safe writes, a backup copy, tamper detection, resume after the app is killed, and a save when the app goes to the background.
- An **early-curve rebalance**: more starting scrap, cheaper first upgrade levels and a softer first boss.

M3 closed on 2026-11-09 after checks on a real phone: the pause screen, the back gesture, resume from the title's CONTINUE and the save-problem screen were all fixed and confirmed on the device.

## Built in milestone M4

<span class="badge live">Implemented</span> M4's features are all in the build. Its exit check (M4-28) is running now, so the milestone is not closed yet.

- **Wave modes.** You choose **TIMED** (the original 24-second waves, leftovers carry over) or **PURGE** (each wave ends when every enemy in it is destroyed, with a 60-second limit) on Home. PURGE unlocks when your best TIMED wave reaches 20, and each mode keeps its own best wave. See [Wave modes](systems/run-loop.md#wave-modes). <!-- numbers: data/wave_modes.csv -->
- **Patch drafts.** At fixed waves the game offers three temporary perks, one card per family. See [Patch drafts](systems/patches.md).
- **The Intel tab**, with STATS and WAVE panels. See [Intel](systems/intel.md).
- **Damage numbers** for crits and meaningful hits, and the red numbers for damage Cinder takes. See [Combat](systems/combat.md#damage-numbers).
- **Haptics** with a Settings switch, plus colorblind and high-contrast modes. See [Settings](systems/settings.md).
- **Guided first runs**: a cold open, short pointers and hints, and a Foundry explainer. See [Your first runs](systems/first-runs.md).
- **Upgrade visual tiers MK I to IV** for the laser beam, hull plates, plating sparks and repair motes, with a tier-up moment. See [Visual tiers](systems/upgrades.md#visual-tiers).
- Also in the build: a Foundry explainer, an About section in Settings and an image-first results screen.

## Built in the R1 feel pass (Phase A)

<span class="badge live">Implemented</span> After an independent review of the build, the first part of a feel pass (R1, Phase A) is merged:

- **Draft rework.** Drafts at waves 5, 10, 15 and 20, then every 10 up to 50, then every 25; one ARMS, one CHASSIS and one SYSTEMS card; one reroll; gambles.
- **Speeds 1x, 2x, 4x and 8x.** 4x unlocks at best TIMED wave 30 and 8x at 60, with an automatic fall-back to 2x when hull is low or a boss is alive. See [Game speed](systems/controls.md#game-speed).
- **Burn hardening.** Cinder takes less damage as its skin burns away. See [The frame hardens](systems/skin-burn.md#the-frame-hardens).
- **The Foundry soft cap.** Higher levels cost twice as much until you reach further waves. See [The best-wave soft cap](systems/foundry.md#the-best-wave-soft-cap).
- **Beam afterglow and floor scorch**, so you can read where the beam went between shots.
- **A local play summary**: COPY PLAY SUMMARY in Settings copies a short text to the clipboard; nothing leaves the device. See [Settings](systems/settings.md).
- **Readable text and contrast**: heavier body text, sentence case for explanations, a contrast test, larger damage numbers.
- A starting stash of 230 scrap and a retune of the early curve and the patch sizes.

## What comes next

The next step is a phone playtest with five to eight people. After that comes the open beta track on Google Play. Until then there is no public release. The review follow-up also lists phone checks (start-up time, saving, battery) and larger work on the crowd, the identity of the game and reasons to return; none of that is in the build yet.

## Roadmap

| Milestone | Goal | Status |
|---|---|---|
| M0 Foundation | Project, tests, lint, export, CI | Done |
| M1 Core combat | Deterministic simulation, auto-battle, five enemies, waves, skin-burn bands | Done |
| M2 In-run economy | Scrap, ten upgrades, big numbers, panel, results | Done |
| V1 Visual pass | Illustrated vector art, effects, styled HUD, mobile hardening | Done apart from on-device verification |
| A1 Audio pass | Synthesized sound effects and adaptive music | Done |
| M3 Meta loop | Data banking, Foundry, saving and resume, title screen, frames | Done (2026-11-09) |
| M4 Wave modes, patches and first-time experience | TIMED and PURGE wave modes, patch draft, Intel tab, damage numbers, haptics, guided first runs, upgrade visual tiers | Features built; exit check (M4-28) running |
| R1 Review follow-up (feel pass) | Draft rework, speeds up to 8x, burn hardening, Foundry soft cap, beam afterglow, play summary, readable text | Phase A merged; phone playtest with five to eight people is next, before the open beta track |
| M5 MVP validation | Balance, real-device performance, fun checks | <span class="badge planned">Planned</span> |
| M6 Launch content | Lab, weapon systems, firmware, drones, adaptive swarm, caches, overdrive, more sectors, Standby Patrol, two more frames | <span class="badge planned">Planned</span> |
| M7 Online and release | Accounts, cloud save, purchases, ads, store release | <span class="badge planned">Planned</span> |
| After launch | Gauntlets, Incursions, Operation Pass, Cells | <span class="badge planned">Planned</span> |

## Known numbers

The balance targets (`data/targets.csv`, first-pass) for a fresh profile with patch drafts are a median death wave of about 14 in TIMED and about 16 in PURGE, about 20 after spending 300 data in the Foundry and about 27 after 1,000 data. They are checked with headless balance runs and will move as the game is tuned. On a Pixel 11 Pro Fold the game held 60 frames per second with 165 enemies on screen in the last device measurement.

## How this codex is made

The codex is written from the game's design documents and checked against its data tables and code. Where the game and a design document disagree, the game data wins here. All numbers are first-pass and can change as balance is tuned.
