# Combat

<span class="badge live">Implemented</span>

## The laser

Cinder's only weapon at the start is the **laser**: a hitscan beam, meaning it hits instantly and cannot miss a target in range. It is drawn as a short-lived line from the active emitter to the target with a quick fade.

| | Base value |
|---|---|
| Damage per shot (`laser_output`) | 10 |
| Shots per second (`cycle_rate`) | 1.0 |
| Range (`optic_range`) | 24 meters |
| Crit chance (`crit_chance`) | 2 percent |
| Crit multiplier (`crit_mult`) | x1.5 |

Damage types are tagged per source: `laser`, `kinetic`, `arc`, `blast` and `nano`. Only `laser` exists today; the rest arrive with weapon systems and matter for the [adaptive swarm](novel-mechanics.md#adaptive-swarm).

## Targeting

Cinder fires at the **nearest living enemy inside its range**, measured from the center. Ties go to the earliest spawn. The choice is made again on every shot; there is no lock-on.

Other targeting modes (ranged first, elites first, lowest health) are <span class="badge planned">Planned M6</span> as research.

## Range

Range is how far Cinder can hit, 24 meters at the start and up to 80. The camera zooms so Cinder's whole range is always on screen. Range also controls where lancers stop to shoot: they hold at 85 percent of your range, between 16 and 48 meters, so more range both lets you hit them and pushes them back.

## Crits

Each shot rolls `crit_chance`. A crit multiplies damage by `crit_mult`. Crit chance is capped at 85 percent. Crits show a larger bracketed number and a brighter flare. An overcrit tier (a rare second multiplier on top of a crit) is <span class="badge planned">Planned M6</span>.

## How a hit is calculated

For each shot the game applies, in order:

1. Base laser output, with your upgrade level and permanent bonuses.
2. Global multipliers.
3. The crit roll.
4. A minimum of 1 damage; overkill is discarded.

More steps (split shots, ricochet, standoff, armor tear, adaptation and field reductions) are <span class="badge planned">Planned M6</span>.

## Damage taken

When an enemy hits Cinder:

1. **Plating percent** removes a fraction of the damage, up to 90 percent.
2. **Flat plating** subtracts a fixed amount afterward <span class="badge planned">Planned M6</span>.
3. A **5 percent minimum** always gets through, so defense never makes Cinder immune.
4. The rest comes off **integrity**.

Integrity returns slowly through `nano_repair`. Buying `hull_integrity` raises maximum integrity and heals by the same amount immediately.

### Death prevention <span class="badge planned">Planned M6</span>

A chain of save effects will fire in order when a lethal hit lands: a fail-safe roll, an aegis charge, a reboot, a meltdown and a purge, then an optional ad revive. Each logs a visible message so you know why you lived. Today, integrity 0 ends the deployment.

## What you see

The arena is a machine-vision display: an animated polar grid with range rings and a radar sweep. Enemies flash when hit and burst into shards when they die. Damage numbers (crits and big hits only, to stay readable) are <span class="badge planned">Planned M4</span>.

![Wave 20 crowd with the boss hulk](../assets/img/crowd_boss.png){ width="260" }

Next: [Run upgrades](upgrades.md).
