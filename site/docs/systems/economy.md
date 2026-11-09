# Economy and currencies

IRON STATIC uses **five currencies at most**. Each has a clear job, and none is ever converted into a stat for money.

| Currency | Persists? | Used for | Status |
|---|---|---|---|
| **Scrap** | Run only | Temporary run upgrades | <span class="badge live">Implemented</span> |
| **Data** | Permanent | Foundry, research, weapon-system levels | Earned in runs today; spending and saving <span class="badge planned">Planned M3</span> |
| **Flux** | Permanent | Rushing timers, extra lab and firmware slots, firmware picks, cosmetics | <span class="badge planned">Planned M6</span> |
| **Cipher** | Permanent | Unlocking weapon systems, companion upgrades | <span class="badge planned">Planned M6</span> |
| **Merit** | Permanent (shop prices reset each season) | Event, Cell and pass shops | <span class="badge planned">Planned Post-launch</span> |

## Scrap

- **Earned** from kills (instantly), from interest (Reinvest), and later from wave bonuses and salvage caches.
- **Spent** on [run upgrades](upgrades.md).
- You start each deployment with 20. It is **lost when the run ends**. There is no cap.
- Payouts are rounded down to whole scrap with the fraction carried forward.

Scrap per kill follows enemy health, so buying power tracks enemy toughness: `max(1, round(2 * G_hp^0.55)) * type multiplier * scrap yield`.

## Data

- **Earned** from kills (more for tougher types and higher levels), and later from sector milestones, missions and Standby Patrol.
- **Banked in full when the run ends**, even on death. Stale kills pay half.
- **Spent** on the [Foundry](foundry.md), and later research, weapon systems and companions.

Per kill: `data = base * (1 + 0.04 * level) * sector reward * data yield`. A first run banks roughly 190 data.

## Flux, cipher and merit <span class="badge planned">Planned</span>

These three are **not in the build yet**. The design is:

| | Free sources | Sinks |
|---|---|---|
| **Flux** | Capped rewarded ads, daily missions, weekly chest, one-time sector milestones, a few in-run orbs | Lab rush (3 flux per remaining hour, free under 10 minutes), lab slots 3 and 4, firmware picks and slots, a third weapon slot, cosmetics |
| **Cipher** | Sector milestones, Gauntlet rewards | Unlocking the nine weapon systems and later companion upgrades |
| **Merit** | Missions, events, Cells, pass | Event and Cell shops, season pass shop |

**Fairness rules** (a design commitment):

- Flux only buys time, convenience slots and firmware picks. It cannot buy tournament entries, direct data or cipher, or any stat.
- A free player earns roughly 60 flux on a typical engaged day and 84 at most.
- Cipher is intentionally scarce: about 15 in the first week and about 150 in the first month for a free player.
- Rewarded ads are opt-in, capped at 12 views a day, and never appear mid-run. There are no interstitials and no forced ads.
- Chance-based pulls (firmware picks) will disclose their odds.

## Big-number display

Numbers are floored when shown, to three significant digits:

| Range | Shown as |
|---|---|
| 0 to 999 | `847` |
| 1,000 to 999,999 | `12.4K`, `847K` |
| Beyond | `M`, `B`, `T`, `Qa`, `Qi`, `Sx`, `Sp`, `Oc`, `No`, `Dc` (up to 1e33), then scientific such as `1.23e45` |

Internally scrap, data and costs use a big-number type that cannot overflow, stored as text such as `1.5e12`. A **Number format** setting (Short, Scientific, Engineering) is in the settings model; see [Settings](settings.md).

## Pacing targets <span class="badge planned">Planned</span>

First-pass targets for an engaged free player (about 35 minutes a day at 2x):

| | Day 1 | Week 1 | Month 1 | Month 6 |
|---|---|---|---|---|
| Data earned (cumulative) | 6e3 | 3e5 | 2e7 | 1e10 |
| Typical best wave | S1 w40 | S2 w45 | S5 w50 | S9 w120 |

These are targets for the balance work, not promises.

Next: [The Foundry](foundry.md).
