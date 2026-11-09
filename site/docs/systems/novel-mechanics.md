# Novel mechanics

Four mechanics are IRON STATIC's own: **skin burn**, the **adaptive swarm**, **salvage caches** and **overdrive**. A fifth, the turncoat protocol, is deferred beyond launch.

| Mechanic | One-line idea | Status |
|---|---|---|
| [Skin burn](skin-burn.md) | Integrity bands change Cinder's look and (later) give comeback bonuses | Visuals <span class="badge live">Implemented</span>; bonuses <span class="badge planned">Planned M6</span> |
| [Adaptive swarm](#adaptive-swarm) | The swarm resists your dominant damage type | <span class="badge planned">Planned M6</span> |
| [Salvage caches](#salvage-caches) | Elites and bosses drop caches you tap for a choice | <span class="badge planned">Planned M6</span> |
| [Overdrive](#overdrive) | A button that trades integrity for a burst of power | <span class="badge planned">Planned M6</span> |
| [Turncoat protocol](#turncoat-protocol) | Killed machines briefly fight for Cinder | <span class="badge planned">Planned Post-launch</span> |

!!! note
    The mechanics marked Planned are not in the simulation yet. This page describes their design so you know what is coming.

## Adaptive swarm

<span class="badge planned">Planned M6</span>

CHORUS keeps statistics on how Cinder kills and its swarm learns. At the end of each wave the game measures what share of your damage came from each damage type. From **wave 20** on, for each type:

- If your share is **above 45 percent**, the swarm gains resistance to it (more the further above 45 percent).
- If your share is **below 20 percent**, resistance to it fades by 2 points.

The swarm's resistance is capped at 50 percent in Sector 1, rising 2 points per sector to 72 percent in Sector 12. A pure single-type build reaches the cap about 20 waves after wave 20; a build split evenly never gains any.

The HUD will show five small bars (one per type), enemies will be outlined in the color of the type they resist most, and the Intel view will show exact percentages, in the story's words: `chorus: counter-measure for LASER at 18%`. Firmware and research will reduce the gain. The point is to make builds a real choice rather than stacking one stat. See [CHORUS and the swarms](../lore/chorus.md).

## Salvage caches

<span class="badge planned">Planned M6</span>

Elites and bosses drop **salvage caches** (one per elite, three per boss). **Tap** a cache to choose its reward from three: a **scrap burst**, a **repair**, or an **overdrive charge**. A cache you ignore **auto-collects after 8 seconds at half value**, so idlers lose little and active players get something to do. Caches have large touch targets, and a companion drone can collect them automatically.

## Overdrive

<span class="badge planned">Planned M6</span>

An optional active ability, the only one in the game. A meter fills from damage you deal; a full meter is about three waves of damage regardless of scaling. Tap **OVERDRIVE** for **8 seconds** of:

- fire rate x1.75 and damage x1.5,
- weapon cooldowns ticking twice as fast,

at the cost of integrity draining **1.2 percent of maximum per second** (it ends early at 15 percent integrity), followed by a **5-second heat soak** at fire rate x0.6. It cannot be triggered while invulnerable. Firmware will trigger it automatically so idle players keep pace; the design target is that manual use is worth no more than about 12 percent extra waves.

## Turncoat protocol

<span class="badge planned">Planned Post-launch</span>

Killed darts, lancers, jammers and menders may reboot as friendly units for 10 seconds at half stats, at most six at once, with a chance that comes only from firmware and patches. It is deferred beyond launch.

Next: [Lab, Arsenal and Standby Patrol](meta-planned.md).
