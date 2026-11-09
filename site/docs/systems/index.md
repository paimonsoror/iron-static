# Game systems

This section explains every system in IRON STATIC: what it does, the numbers behind it, and whether you can use it yet.

!!! tip "Reading the badges"
    <span class="badge live">Implemented</span> is in the current build. <span class="badge planned">Planned</span> is designed but not playable; the milestone is named. See [Development status](../status.md).

## The shape of the game

```text
 kills ──> scrap ──> run upgrades (temporary, reset every deployment)
   │
   └─> data ──> Foundry (permanent) ──> a stronger start for the next deployment
```

You **deploy**, spend **scrap** to get stronger for the length of that deployment, and eventually fall. The **data** you recovered is banked and buys permanent upgrades, so the next deployment starts further ahead.

## Pages

| Page | What it covers | Status |
|---|---|---|
| [The run loop and waves](run-loop.md) | Deployments, wave timing, spawning, enemy scaling | <span class="badge live">Implemented</span> |
| [Combat](combat.md) | Targeting, the laser, crits, range, damage taken | <span class="badge live">Implemented</span> |
| [Run upgrades](upgrades.md) | All ten upgrades, formulas, costs, tap and hold-to-buy | <span class="badge live">Implemented</span> |
| [Skin burn](skin-burn.md) | The four exposure bands | Visuals implemented, bonuses <span class="badge planned">Planned M6</span> |
| [Economy and currencies](economy.md) | The five currencies, sources and sinks | scrap and data implemented; rest <span class="badge planned">Planned</span> |
| [The Foundry](foundry.md) | Permanent upgrades and their formulas | <span class="badge live">Implemented</span> |
| [Saving and resuming](save-resume.md) | Autosave, resume after the app is killed, New Game | <span class="badge live">Implemented</span> |
| [Novel mechanics](novel-mechanics.md) | Adaptive swarm, salvage caches, overdrive, skin burn | mostly <span class="badge planned">Planned M6</span> |
| [Lab, Arsenal and Standby Patrol](meta-planned.md) | Research, weapon systems, firmware, drones, offline earnings | <span class="badge planned">Planned M6</span> |
| [Settings and accessibility](settings.md) | Options and accessibility features | Screen implemented; more options <span class="badge planned">Planned M4</span> |
| [Controls](controls.md) | Touch, back gesture, auto-pause | <span class="badge live">Implemented</span> |
| [Look and sound](audio-visual.md) | Visual and audio direction | <span class="badge live">Implemented</span> |
| [Glossary](glossary.md) | Every term in one place | |

## One rule worth knowing

Every number on these pages comes from the game's data tables, which are first-pass and are tuned by simulation. When a number changes, this codex changes with it.
