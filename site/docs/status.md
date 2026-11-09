# Development status

IRON STATIC is in active development. This page says what you can play today and what is coming. Last updated 2026-11-09.

## What is in the build today

<span class="badge live">Implemented</span>

- The full in-run loop: deployments, 24-second waves, spawn rings, flank groups, stale-enemy rule.
- Cinder with an auto-firing hitscan laser, crits and range.
- Five enemies: skitter, dart, lancer, walker and the boss hulk (without its plate mechanic).
- Ten run upgrades in three tabs, with tap and hold-to-buy and formula tooltips.
- Skin burn: four exposure bands with ember particles, a low-integrity haze and a heartbeat.
- The results screen with best-wave gain, data banked and its new total, a frame-unlocked line, and REDEPLOY, FOUNDRY and HOME; pause, 1x and 2x speed.
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

## In progress: milestone M4

<span class="badge planned">In progress</span>

- **Wave modes.** You will choose a mode before each deployment. **TIMED** is today's game: 24-second waves, leftovers carry over. **PURGE** ends each wave when every enemy in it is destroyed, with a 60-second limit so a wave can never stall. PURGE unlocks when your best TIMED wave reaches 20, and each mode keeps its own best wave. The rules and the separate records are being built now; the mode picker on Home comes next.
- Later in M4: the wave-10 patch draft, the Intel tab, damage numbers, haptics, more accessibility settings and a guided first ten minutes.

## Roadmap

| Milestone | Goal | Status |
|---|---|---|
| M0 Foundation | Project, tests, lint, export, CI | Done |
| M1 Core combat | Deterministic simulation, auto-battle, five enemies, waves, skin-burn bands | Done |
| M2 In-run economy | Scrap, ten upgrades, big numbers, panel, results | Done |
| V1 Visual pass | Illustrated vector art, effects, styled HUD, mobile hardening | Done apart from on-device verification |
| A1 Audio pass | Synthesized sound effects and adaptive music | Done |
| M3 Meta loop | Data banking, Foundry, saving and resume, title screen, frames | Done (2026-11-09) |
| M4 Wave modes, patches and first-time experience | TIMED and PURGE wave modes, patch draft, Intel tab, damage numbers, haptics, tutorial | In progress: wave modes first |
| M5 MVP validation | Balance, real-device performance, fun checks | <span class="badge planned">Planned</span> |
| M6 Launch content | Lab, weapon systems, firmware, drones, adaptive swarm, caches, overdrive, more sectors, Standby Patrol, two more frames | <span class="badge planned">Planned</span> |
| M7 Online and release | Accounts, cloud save, purchases, ads, store release | <span class="badge planned">Planned</span> |
| After launch | Gauntlets, Incursions, Operation Pass, Cells | <span class="badge planned">Planned</span> |

## Known numbers

After the early-curve rebalance, a fresh profile dies around wave 12 in the median in the balance runs, which is the design target. A few Foundry levels add about 4 waves (300 data) and roughly double the run at about 1,000 data. The three frames land within about 10 percent of VANGUARD on a fresh profile. On a Pixel 11 Pro Fold the game holds 60 frames per second with 165 enemies on screen.

## How this codex is made

The codex is written from the game's design documents and checked against its data tables and code. Where the game and a design document disagree, the game data wins here. All numbers are first-pass and can change as balance is tuned.
