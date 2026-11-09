# Lab, Arsenal and Standby Patrol

!!! planned "Planned: milestone M6 and later"
    Everything on this page is designed and **not in the build**. It is documented so you can see where the game is heading. Numbers are first-pass and will change.

## R&D Lab

Timed research bought with **data** and **time**, unlocked at best wave 25 in Sector 1.

- **Slots:** one at unlock, a second free at best wave 50, a third for 250 flux and a fourth for 700 flux. Maximum 4.
- **No research ever takes longer than 48 hours.** If more depth is needed, more levels are added, not more time.
- **Duration** grows with research level: `min(48 h, t0 * 1.35^level)` reduced by Lab Speed research (up to 30 percent). **Cost** is `ceil(rc0 * 1.30^level)` data.
- **Rush:** 3 flux per remaining hour (rounded up), **free when less than 10 minutes remain**. A rewarded ad can shave 30 minutes (up to 6 a day).
- Cancelling refunds all the data and loses the progress. Research completion can notify you (opt-in).

The catalogue covers game speed (3x at research level 5, 4x at level 15), Lab and Foundry discounts, starting scrap, interest cap, target-priority modes, patch choices, auto-buy and auto-pick lists, stat tuning (laser, cycle, hull, repair, crit, range, plating, scrap and data yield), adaptation filters, overdrive, the skip-lull button, and **enemy studies** that reduce a given enemy's health, damage or speed.

## Arsenal

Four groupings:

- **Weapon systems.** Nine auto-firing special weapons, three equipped slots. Unlocked with cipher (costs 3, 20, 60, 120, 220, 380, 600, 900 and 1,300) from three random offers, levelled with data. Slot 3 costs 400 flux.

| System | Type | Effect |
|---|---|---|
| Arc Discharge | arc | Lightning chains to five enemies and marks them to take more damage |
| EMP Pulse | arc | A ring that damages and stuns, and shuts down aegis fields |
| Micro Missiles | blast | Six homing missiles at random enemies |
| Singularity Charge | kinetic | A well that pulls the densest cluster together |
| Dilation Field | none | A ring around Cinder that slows enemies |
| Nanite Cloud | nano | A damage zone that also tears armor |
| Salvage Beacon | utility | For a time, scrap and data gains are multiplied |
| Target Painter | utility | A zone where enemies take extra damage and shades are revealed |
| Proximity Grid | blast | Drops a ring of twelve mines around Cinder that stun and explode |

- **Firmware chips** (called *lanterns* in the story). Collectible, levelled by duplicates from 1 to 5 stars, equipped in slots. Pulled with flux as **pick 1 of 3**, with disclosed odds. Chips include death-prevention effects (aegis charge, reboot, meltdown, purge), an overdrive governor and an adaptive filter.
- **Companion drones.** Four drones that orbit Cinder and fire a timed ability: Ember (a fire burst), Volt (a stun pulse), Scav (collects salvage caches and boosts scrap) and Amp (a damage boost). Bought with merit, levelled with data.
- **Hardware modules.** Slot gear with rarity and 3-to-1 fusion. Post-launch.

## Standby Patrol

While the app is closed, Cinder keeps a **Standby Patrol** in your chosen sector.

```text
standby data = farm rate * minutes away (up to the cap) * efficiency
```

| | Start | Research raises it to |
|---|---|---|
| Time cap | 4 hours | 11 hours (+30 min per level, 14 levels) |
| Efficiency | 20% | 40% (+1 point per level, 20 levels) |

- It earns **data only**: no scrap, flux, cipher, merit, drops, caches, or milestones, and it never advances best wave.
- When you return, a window shows time away and data gained, with an optional **"Double (watch ad)"** button (twice a day). No guilt text.
- If only the phone's own clock is available, the claim is capped at 4 hours; trusted-server time is used when online.
- Standby is a one-line calculation, not a simulation. It is meant to reward returning, not replace playing.

## Missions, Gauntlets, Incursions and more <span class="badge planned">Planned Post-launch</span>

The design adds an **Ops Board** (daily and weekly missions), **sector milestones** (one-time wave goals with rewards), **Gauntlets** (bracketed tournaments with normalized rules and no paid entries), **Incursions** (two-week live events), an **Operation Pass** (cosmetic and convenience only) and **Cells** (player groups).

Next: [Settings and accessibility](settings.md).
