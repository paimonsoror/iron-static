# The Foundry

!!! planned "Planned: milestone M3"
    The Foundry's rules, data and cost formulas are built, but the Foundry screen and data saving are in production. You cannot buy Foundry levels in today's build.

The **Foundry** is where **data** becomes permanent power. A Foundry level raises a stat's **starting value for every deployment**; you then add temporary run levels on top.

Two clear layers:

| Layer | Bought with | Lasts |
|---|---|---|
| Run levels | Scrap | One deployment |
| Foundry levels | Data | Forever |

## How a stat is resolved

```text
final = base * run factor * Foundry multiplier * other multipliers
```

Other multipliers include the [frame](../characters/frames.md) you chose. Foundry levels do not count toward a run upgrade's level cap, and the Foundry is shared by all frames.

## The four launch rows

| Row | Kind | Per-level factor `f` | Foundry level cap | Base cost `fc0` | Cost growth |
|---|---|---|---|---|---|
| Laser Output | D | 0.06 | 200 | 20 | x1.10 |
| Hull Integrity | D | 0.06 | 200 | 20 | x1.10 |
| Nano Repair | D | 0.05 | 200 | 25 | x1.10 |
| Cycle Rate | C | step of the run row (+0.04) | 50 | 50 | x1.12 |

More rows follow with later milestones.

## Formulas

**Cost** of the next level, in data:

```text
foundry_cost(F -> F + 1) = ceil(fc0 * fg ^ F)
```

**Type D rows** (Laser Output, Hull Integrity, Nano Repair) multiply:

```text
foundry_mult(F) = (1 + f * F) * 1.25 ^ floor(F / 10)
```

Every 10 Foundry levels is a x1.25 milestone, and the Foundry highlights the cheapest row that is about to reach one.

| Foundry level | Laser Output or Hull multiplier | Total data to reach it (fc0 = 20) |
|---|---|---|
| 10 | x2.0 | 319 |
| 25 | x3.9 | 1,967 |
| 50 | x12.2 | 23,278 |
| 100 | x65.2 | 2.76 million |

**Type C rows** (Cycle Rate) add instead: a Foundry level is a free starting run level, up to half of the run cap (so Cycle Rate has 50). The run cap is not raised.

**Unlocking** a row that is gated by best wave costs a one-time amount of data, about 20 times its run base cost.

## What the screen shows

Each row will show its current value, the next value, the change, the cost, the maximum, and how long it would take to afford at your current earn rate. A "Recommended" glow marks the cheapest milestone-adjacent stat. **Tap** the cost button to buy a level; **hold** to repeat-buy. There is no buy-mode selector.

## Design target

A new player should be able to spend their first banked data (about 800) on two or three stats and feel the difference on the next run, aiming for about 4 more waves per 300 data.

Next: [Saving and resuming](save-resume.md).
