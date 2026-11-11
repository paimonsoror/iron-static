# Service record

<span class="badge live">Implemented</span>

The **service record** is Cinder's lifetime ledger: how long you have played, how many machines of each kind you have destroyed, how much you have earned and spent, and how every frame has done. Open it from **Home**: the **RECORD** tab in the bottom row, next to HOME and FOUNDRY, appears after your first deployment. BACK (or the back gesture) returns to Home.

Everything is stored in your save file on the device. Nothing is sent anywhere. **RESET PROFILE** in Settings, or NEW GAME on a profile with progress, wipes it together with the rest of the profile.

## What it shows

The screen scrolls: drag anywhere on the list.

**General**

- **Time played:** time with the game open in the foreground, on any screen. Time with the game in the background does not count, and a single pause longer than a second between two frames (the phone sleeping, say) counts as one second.
- **Time deployed:** time spent in battle, counted in game time (30 ticks per second), so it does not depend on the game speed you chose.
- **Deployments:** all of them, then TIMED and PURGE separately, and the best wave of each mode.
- **Waves cleared:** waves that ended with Cinder alive. The wave a deployment ended in does not count.
- **Longest deployment.**

**Combat**

- **Machines destroyed,** and one row for **every enemy type** in the game, bosses included, under the names used in [Intel](intel.md) and Results.
- **Bosses destroyed, shots fired, critical hits and the crit rate** (critical hits over shots, shown to one decimal).
- **Damage dealt, highest single hit and hull damage taken.** Hull damage is the sum of the damage of every hit on Cinder, each hit counted in whole points as the combat log shows it. The highest hit is capped at 2,147,483,647, the width of the field the game's event stream uses.

**Economy**

- **Scrap earned and scrap spent,** over all deployments. Earned is everything that reached your scrap balance: kills and the interest from Reinvest. Spent is what upgrades cost.
- **Upgrades bought** (every level counts) and **patches picked.**
- **Data earned** and **data spent in the Foundry,** and the **Foundry levels bought.**

**Frames:** deployments and best wave for each frame.

Numbers follow the number format you chose in [Settings](settings.md); times read like `12h 05m`.

## When it updates

A deployment is added to the record **once, when it ends** (a death, or ABORT MISSION), at the same moment its data is banked. The deployment in progress is therefore not in the totals until it ends. A deployment that you leave and resume, even after the app was killed, is never counted twice or half: the counters that only the combat log knows are saved inside the run's own checkpoint, so the resumed deployment carries on from exactly where it stopped.

There is no offline or idle progress in the game, so nothing is added while the game is closed.

## Older saves

A save from before the service record existed is seeded the first time it loads, with what it already knew:

| Seeded | From |
|---|---|
| Deployments | the profile's own run count. The days the 30-day play log still holds are split into TIMED and PURGE; the rest appear as **earlier deployments** (mode unknown) |
| Time played | the play log's seconds for the last 30 days |
| Best waves, data earned, data spent, Foundry levels | read from the save itself, always exact |

Everything else (kills, shots, damage, scrap, waves cleared, longest deployment, per-frame lines) starts at zero on the seeding date. The screen says **TRACKED SINCE** with that date and, for a seeded save, a short note, so no number claims more than it knows.

!!! note "Deployments with missing totals"
    If an app update ends a deployment that was in progress, or a deployment was resumed from a checkpoint written by an older build, the game adds what it still knows (the deployment, the time, the wave, the kills, the data) but not the totals only the combat log has (shots, crits, hits, hull damage, scrap). The screen then says how many deployments are missing some totals.

## For developers

The record lives in the profile's `extra` dictionary under `record`, version 1, like the [play summary](settings.md): no save schema change, unknown keys survive, every read tolerates floats and damaged values. See `src/meta/recorder/` (`service_record.gd`, `run_tally.gd`, `run_totals.gd`, `record_seed.gd`, `record_reader.gd`, `play_timer.gd`).
