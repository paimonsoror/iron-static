# The Foundry

<span class="badge live">Implemented</span> The Foundry screen, four rows, and saving your levels. It opens once you have finished your first deployment. More rows are <span class="badge planned">Planned</span> for later milestones.

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

![The Foundry with four rows and a RECOMMENDED tag](../assets/img/foundry.jpg){ width="260" }

The top of the screen shows your **DATA** and a preview line, "NEXT RUN PR a -> b", with the Power Rating change your purchases would give. Each row shows its level (`F8`), its current and next value with the change, the next milestone (`F10  x1.25`), the cost, and whether it is affordable now or "~N TO AFFORD" at your current earn rate. A **RECOMMENDED** tag marks the cheapest milestone-adjacent stat. **Tap** the cost button to buy a level; **hold** to repeat-buy, the same way as in a deployment. There is no buy-mode selector. Buying saves your profile.

You reach the Foundry from Home (a chip tells you how many rows you can afford) and from the results screen. DEPLOY on the Foundry starts the next run directly. Back returns to the screen you came from. Until you finish your first deployment the Foundry is hidden.

## Design target

A new player should be able to spend their first banked data on two or three stats and feel the difference on the next run, aiming for about 4 more waves per 300 data. In the latest balance run, 300 data spent across Laser Output, Hull Integrity and Cycle Rate raised the median death wave by 4 (12 to 16), and about 1,000 data roughly doubled it.

Next: [Saving and resuming](save-resume.md).
