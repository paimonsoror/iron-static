# Development status

IRON STATIC is in active development. This page says what you can play today and what is coming. Last updated 2026-11-08.

## What is in the build today

<span class="badge live">Implemented</span>

- The full in-run loop: deployments, 24-second waves, spawn rings, flank groups, stale-enemy rule.
- Cinder with an auto-firing hitscan laser, crits and range.
- Five enemies: skitter, dart, lancer, walker and the boss hulk (without its plate mechanic).
- Ten run upgrades in three tabs, with tap and hold-to-buy and formula tooltips.
- Skin burn: four exposure bands with ember particles, a low-integrity haze and a heartbeat.
- The results screen, redeploy with a new seed, pause, 1x and 2x speed.
- Android back gesture handling and automatic pause when the app goes to the background.
- Synthesized sound effects and adaptive music; an animated machine-vision arena.

## Built in the engine, no screens yet

Part of the current milestone (M3) exists in code and data but is not reachable from the game yet, so it is labelled <span class="badge planned">Planned</span> throughout this codex: the Foundry rules and four rows, banking data between deployments, the save format with crash-safe writes and run resume, the three frames in the simulation, and the settings model. The title screen, Home, Foundry and frame bay screens are in production.

## Roadmap

| Milestone | Goal | Status |
|---|---|---|
| M0 Foundation | Project, tests, lint, export, CI | Done |
| M1 Core combat | Deterministic simulation, auto-battle, five enemies, waves, skin-burn bands | Done |
| M2 In-run economy | Scrap, ten upgrades, big numbers, panel, results | Done |
| V1 Visual pass | Illustrated vector art, effects, styled HUD, mobile hardening | Nearly complete |
| A1 Audio pass | Synthesized sound effects and adaptive music | Sound effects done, wiring in progress |
| M3 Meta loop | Data banking, Foundry, saving and resume, title screen, frames | In progress |
| M4 Patches and first-time experience | Patch draft, Intel tab, damage numbers, haptics, tutorial | <span class="badge planned">Planned</span> |
| M5 MVP validation | Balance, real-device performance, fun checks | <span class="badge planned">Planned</span> |
| M6 Launch content | Lab, weapon systems, firmware, drones, adaptive swarm, caches, overdrive, more sectors, Standby Patrol, two more frames | <span class="badge planned">Planned</span> |
| M7 Online and release | Accounts, cloud save, purchases, ads, store release | <span class="badge planned">Planned</span> |
| After launch | Gauntlets, Incursions, Operation Pass, Cells | <span class="badge planned">Planned</span> |

## Known numbers

A fresh profile currently dies around wave 9 on average; the design target is about wave 12, and the first balance pass accepts that gap. On a Pixel 11 Pro Fold the game holds 60 frames per second with 165 enemies on screen.

## How this codex is made

The codex is written from the game's design documents and checked against its data tables and code. Where the game and a design document disagree, the game data wins here. All numbers are first-pass and can change as balance is tuned.
