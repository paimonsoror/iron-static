# Skin burn

Cinder's armor plates burn away as its integrity drops, exposing the frame underneath. It is the game's signature image and the clearest way to read how close Cinder is to falling.

<span class="badge live">Implemented</span> The four visual bands and the frame hardening (less damage taken). <span class="badge planned">Planned M6</span> The damage and repair bonuses.

![Cinder in the four exposure bands](../assets/img/skin_bands.png)

## The four bands

Let `f` be integrity divided by maximum integrity.

| Band | Integrity | What you see | Damage taken | Comeback bonus (Planned) |
|---|---|---|---|---|
| **0** | Above 75% | Armor intact: all twelve plates, a steady core | full | none |
| **1** | 50% to 75% | **Scorch.** Three plates char and flake; ember particles and small sparks | x0.75 (25% less) | +6% damage, +20% nano repair |
| **2** | 25% to 50% | **Exposed.** Eight of the twelve plates are gone; frame ribs show; the display flickers | x0.55 (45% less) | +12% damage, +40% nano repair |
| **3** | 25% or below | **White-hot.** The frame glows white-hot, the core shows through a cracked outline, a heartbeat pulses and a red vignette closes in | x0.35 (65% less) | +18% damage, +60% nano repair |

The band label and a crackle sound mark each change. In the worst band a heartbeat sound pulses in time with the low-integrity haze.

## The frame hardens

<!-- Numbers: data/sim_constants.csv rows burn_dr_b1, burn_dr_b2, burn_dr_b3. Order: src/sim/cinder_state.gd apply_hit. -->

As the skin burns away, the frame underneath takes less damage. In band 1 Cinder takes 25 percent less damage from every hit, in band 2 45 percent less and in band 3 65 percent less. The reduction is applied after [plating](upgrades.md#what-each-upgrade-is-for) and before the BULWARK frame's hit cap, so it multiplies whatever plating let through. It makes the last bands last longer instead of ending the run at once, and it is the first gameplay effect of skin burn.

The [Intel](intel.md) STATS tab shows the current reduction in its BURN HARDENING row, and names the band.

![Skin burn band 2: the hull bar is orange, Cinder's plates are scorched, and Intel shows BURN HARDENING at minus 45 percent](../assets/img/burn_intel.jpg){ width="260" }

<sub>A debug scenario: an invulnerable Cinder set to 40 percent integrity at wave 20.</sub>

## Hysteresis

Bands change with **5 percent hysteresis**: you only leave a band after integrity has crossed the threshold by another 5 percent. That stops the look flickering between two bands when integrity hovers near a line.

## Going back up

Plates do not grow back while integrity is falling. When integrity recovers to a better band, they **re-form one by one over about 1.5 seconds**.

## The bonuses

From the Launch milestone each band lost will also give Cinder more damage and faster repair. The idea is a comeback mechanic: the more the skin burns, the harder Cinder hits. Today the bands change how Cinder looks and how much damage it takes; the damage and repair bonuses in the table are planned.

A patch (Planned) will scale the bonuses and start the burn 5 percent lower.

## Why it matters

Integrity is invisible in most idle games: a number on a bar. Here you can see it from across the room. For the story reading, see [What burns away](../lore/burning-away.md).

Next: [Economy and currencies](economy.md).
