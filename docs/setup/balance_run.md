# Balance runner (`tools/balance_run.ps1`, M2-14)

Changelog: 2026-11-10 (R1-01: `-Policy cheapest|random`, the report-only "optimizer vs random on fresh" line, journey `streak`/`unspent` columns, the pacing summary and the `journey` rows of targets.csv) - 2026-11-09 (M4-15: the draft pick policy, section "Patch drafts") - 2026-11-09 (M4-10: `-Mode timed|purge`, `mode` column in targets.csv, PURGE row) - 2026-11-09 (`--policy only:<row id>`, Q54 retune) - 2026-11-08 (M3-08, M3-24: Foundry profiles, `--frame`, `--policy none`, frames table, mean line, frame tuning log) - 2026-11-07 created (M2-14).

The standard "did I break the economy" check (TECH_ARCHITECTURE 10.3). Required in the definition of
done for every economy or sim change: paste the output in the commit message and compare it to
`data/targets.csv`.

## Command

```
.\tools\balance_run.ps1 -Profile fresh -Waves 100 -Runs 20 -Seed 1 -Policy greedy4 [-Sector 1] [-Frame vanguard] [-Mode timed]
```

| Flag | Default | Meaning |
|---|---|---|
| `-Profile` | `fresh` | `fresh` (best_wave_s1 0, no Foundry) or a JSON file: `{"name": "...", "best_wave_s1": 0, "foundry_levels": {"laser_output": 5, ...}, "total_cost": 325}`. `foundry_levels` is `{Foundry row id: level}` and goes through `SimConfigLoader.apply_foundry` (M3-08); an unknown id exits 2. `total_cost` is informational (a test recomputes it). Checked-in profiles: `tests/profiles/foundry_300.json`, `foundry_1k.json`. |
| `-Waves` | 100 | cap: a run that is still alive after this wave reports death wave = cap |
| `-Runs` | 20 | seeds are `Seed .. Seed+Runs-1` |
| `-Seed` | 1 | first seed |
| `-Policy` | `greedy4` | `PolicyBot` policy: `greedy4`, `all`, `none` (never buys: only the starting stats matter, M3-24), `cheapest` or `random` (R1-01 honesty-check buyers over every visible row: always the cheapest next level, or a random affordable row from the stream `policy_random` of the config seed) or `only:<row id>` (buys only that run-upgrade row, e.g. `only:hull_integrity`; used in the Q54 retune to check that early hull, plating and repair purchases extend runs; a gated row such as `plating_pct`, best wave 10, needs a profile whose `best_wave_s1` has unlocked it) |
| `-Sector` | 1 | sector number (sets `SimConfig.sector`) |
| `-Frame` | `vanguard` | Cinder frame id from `data/frames.csv` (implemented ones: vanguard, bulwark, striker), or `all` to run every implemented frame on the same seeds and print a frames table (M3-24). Unknown or unimplemented id exits 2. |

| `-Mode` | `timed` | wave mode (M4-10): `timed` or `purge` (a wave ends when its spawn quota is dead, 60 s backstop). `bogus` exits 2. Non-timed runs add ` mode=purge` to the header, a `BALANCE mode=purge mean_seconds_per_wave=` line (real seconds per wave against the 24 s TIMED wave) and `mode=purge` in the target lines. `tools/sim_run.ps1` takes `--mode purge` as a forwarded flag. |

Unknown flags exit 2 with a usage line. Exit codes: 0 ok (PASS or WARN), 1 a `data/targets.csv` row is
`FAIL`, 2 bad arguments or script error. The Godot part takes about 10 to 13 s for 20 runs; the wrapper adds
an import step (about 5 s, more if it has to retry the Sentry DLL collision).

## Output

stdout (deterministic, every line starts with `BALANCE`; byte-identical across executions):

- header line, then one `BALANCE run seed=.. death_wave=.. minutes=.. cause=.. kills=.. hash=..` line per run
- `BALANCE death_wave p10= p50= p90=` (nearest rank), `BALANCE mean_game_minutes=`
- `BALANCE cause <enemy id> <count> (<pct>)`: cause-of-death histogram (`survived` when the wave cap was reached)
- `BALANCE curve wave=N ...`: excerpt (waves 1, 5, 10, ...) of the per-wave averages
- `BALANCE target <profile> <metric> measured= target= tol= dev= PASS|WARN|FAIL (<source>)` per
  `targets.csv` row of the profile, then `BALANCE RESULT PASS|WARN|FAIL` and `BALANCE OK`

stderr: `TIMING wall=.. game=.. speedup=..`, engine banner and `[INFO]` lines. Files (in `build/balance/`):

- `curve.csv`: `wave,runs,avg_scrap_earned,avg_data_earned` (per-wave averages over runs that finished that wave)
- `run0_buys.csv`: `tick,wave,upgrade,level` purchase timeline of run 0 (from `world.input_log`)

## Targets (`data/targets.csv`)

`profile,mode,metric,target,tolerance,source` (M4-10; `mode` is `timed` or `purge`, a file without the column reads as all timed; rows are compared only for the mode being run). Tolerance is relative: PASS within it, WARN within 2x, FAIL beyond.
`fresh,median_death_wave,12,0.30,gdd:03 s6` (GDD 03 section 6; FC10 requires +-30%). For `fresh` that means
PASS 8.4-15.6, WARN 4.8-8.4 and 15.6-19.2, FAIL outside. Rows for the Foundry profiles (x2 24, x4 37,
x10 60) are added when the Foundry exists (M3+). A profile with no rows prints a notice and passes.
The only measured metric today is `median_death_wave` (p50, nearest rank).

## First-pass measurement (M2-14, seeds 1-20, sector 1, `fresh`)

| Policy | p10 | p50 (median) | p90 | mean game min | vs target 12 +-30% |
|---|---|---|---|---|---|
| `greedy4` | 8 | **9** | 9 | 3.23 | PASS (dev -25%, inside the 8-18 first-pass window, not flagged) |
| `all` | 8 | **9** | 9 | 3.23 | identical to `greedy4` |

`all` equals `greedy4` bit for bit (same hashes): at best wave 0 only the four starting rows are visible,
and the bot never buys rows that do not change `ref_dmg * ref_ehp` (scrap_yield, reinvest, ...), so the
extra rows never win. Even with `best_wave_s1 = 12` (all rows visible) the median stays 9. The GDD estimate
of 12 therefore sits 25% above what the greedy bot reaches; the median is at the low edge of the +-30% band
(8.4), so M5 balancing should look at the early curve (about 13 scrap/wave at wave 1, 23 at wave 5) before
the Foundry targets. Deaths: lancer 45%, skitter 40%, dart 15%. The result is a measurement, nothing was tuned.

## M4-10 PURGE targets

`purge,fresh,median_death_wave` is 16 (tolerance 30%, source `impl`), measured with `-Profile fresh -Mode purge -Waves 100 -Runs 20` (greedy4, seeds 1-20: p10 12, p50 16, p90 20, mean 15.95, 8.67 game minutes, 32.6 s per wave against 24 s TIMED; TIMED same seeds: p50 12, mean 11.50, 4.44 min). Every PURGE row is information only (a FAIL prints as WARN) until the user signs off the numbers.

## Gotchas

- The wrapper prints only `BALANCE`/`usage:` lines to stdout (via `Write-Host`): to capture them to a file
  from PowerShell use `cmd /c "powershell -NoProfile -File tools\balance_run.ps1 > out.txt 2> err.txt"`
  (`>` in PS 5.1 does not redirect `Write-Host`).
- The wrapper retries the transient Sentry DLL copy collision (`Invoke-GodotRetry`, 15 s waits), so a run
  overlapping other Godot processes can take a minute of wall time with nothing wrong.
- A running emulator inflates the timing numbers (like `perf_bench`); the output itself is unaffected.

## M3 additions (M3-08 Foundry profiles, M3-24 frames)

- New stdout lines: `BALANCE death_wave_mean=` (after the percentile line); for a profile with `foundry_levels`
  `BALANCE FOUNDRY delta median vs fresh: +N waves (...; mean +x.xx)` against a silent fresh run on the same seeds;
  with `-Frame all` one header and block per implemented frame (header gets ` frame=<id>` for non-VANGUARD) and a
  closing `BALANCE frames frame=.. policy=.. mean=.. median=.. p10=.. p90=.. delta_mean_vs_vanguard=..%` table.
- R1-01: a fresh-profile run with `greedy4`/`all` also prints `BALANCE optimizer vs random on fresh: ... (report only)`, the same seeds with the `random` buyer. The review (G-01) measured 11.7 against 11.9; it is the honesty check that later phases which make buying matter should open a gap on. Not a gate.
- `-Policy none` never buys (the runner skips `PolicyBot`); `targets.csv` rows are only compared for VANGUARD with a
  buying policy. Foundry profile target rows (`foundry_300` 13, `foundry_1k` 24) are information only: a FAIL
  there is printed as WARN (**impl**).
- `tools/sim_run.ps1` takes `--foundry id=level,...` and `--frame <id>` (forwarded flags).
- Shared config building is `BalanceSetup` (`src/core/balance_setup.gd`).
- Measured numbers, the frame gate and the `data/frames.csv` tuning log: `docs/playtests/m3/balance_m3.md`
  (fresh 9; `foundry_300` 11 = +2 waves, `foundry_1k` 22 = +13; frames BULWARK +3.2% / STRIKER +7.5% greedy4,
  BULWARK +1.6% idle with parity-tuned option P; gate NOT met inside the identity bounds, see the report).

## Patch drafts (M4-15)

From SimVersion 4 a run opens a patch draft at the end of waves 10, 20, ... (then 75, 100, ...) in both modes, and the
world does not step until a pick is made. Headless runs would stall, so `balance_run` and `sim_run` settle every
open draft before each tick with `PolicyBot.settle_draft`: **the first offer (slot 0)**, for every policy including
`none`. It goes through `world.command_pick`, so the pick is logged (`CMD_PICK`) and the run stays replayable. The
offers themselves come from the seeded `rng_draft` stream, so the "first offer" is deterministic per seed. The
bot does not weigh patches (no ranking, no gamble avoidance): median death waves therefore include a random patch
at wave 10 and 20, which is what the changed medians in the M4-15 commit measure. The game build has no overlay
until M4-16; until then `RunController` auto-picks the first offer as a stopgap.

## Journey simulator (FO-2, `tools/journey_run.ps1`)

`balance_run` plays one deployment per seed. The journey simulator plays N deployments in a row on one profile: run upgrades are bought inside a deployment by the same `PolicyBot` (`-RunPolicy greedy4` by default), and between deployments all banked Data is spent in the Foundry by a named policy through the real `PlayerProfile.bank_run` and `FoundryService`. It answers pacing questions ("how fast does best wave and Data grow when the player stacks the Foundry"), which a single-run median cannot. Report and measurements: `docs/balance/foundry_early_power.md`.

```
.\tools\journey_run.ps1 -Spend recommended -Deployments 16 -Seed 1 [-Waves 120] [-Frame vanguard|bulwark|striker] [-Mode timed|purge] [-Name text]
.\tools\journey_run.ps1 -Probe 800 -Spend laser -Runs 20            # fixed spend from a fresh profile vs fresh, 20 seeds
.\tools\journey_run.ps1 -ProfileFile tests/profiles/foundry_300.json -Frames -Runs 20   # profile vs fresh per frame, with the start stats and targets.csv status
.\tools\journey_run.ps1 -SelfCheck                                  # 20 checks of the tool itself
```

| Flag | Meaning |
|---|---|
| `-Spend` | `cheapest` (cheapest next level), `laser` (all-in `laser_output`), `recommended` (mirrors the Foundry RECOMMENDED glow, `FoundryRules.recommended`; waits when the glowing row is not affordable yet), `roundrobin`, `none` (control: never spends). Spending is one level at a time until the pick is unaffordable. |
| `-Deployments`, `-Seed`, `-Waves` | deployment `i` uses seed `Seed + i - 1`; `Waves` caps a deployment (a capped one is marked `capped`, its Data still banks) |
| `-Frame` | a non-VANGUARD frame is played from the first deployment after its `unlock_best_wave` (`frames.csv`) is reached; earlier ones use VANGUARD |
| `-Mode` | `timed` or `purge`; progress (best wave) is that mode's record (info only) |
| `-Set` | in-memory overrides, nothing on disk changes: `sim.<SimTuning key>=v`, `enemy.<id>.data_base=v`, `enemies.data_scale=x`, `foundry.<row id>.<f\|f_cap\|fc0\|fg>=v` (comma separated) |
| (cap) | since FO-3 the real best-wave Foundry level cap (`FoundryRules.wave_cap`, GDD 05 s1.5) always applies to the journey's spending; the FO-2 `-CapK`/`-CapMin` prototype flags are gone. `-Probe` lifts it (`FoundryService.wave_cap_enabled = false`) because it spends on a fresh profile |
| `-Probe`, `-ProfileFile`, `-Frames`, `-Runs` | probe mode (see above) |
| `-SkipImport` | skip the wrapper's import step (batches; the first call must import so the new `class_name` scripts are known) |

stdout lines start with `JOURNEY` (deterministic; TIMING goes to stderr): one `dep=` line per deployment (death wave, best wave, Data earned and cumulative, Data spent and left, `streak` = deployments since the last new best, `unspent` = Data left after the spend, Foundry levels L/C/H/N, game minutes at 2x, state hash), then `mark` lines: after 3 deployments (first session), at 35 minutes of 2x play (Day 1), the first Foundry milestone (F25 since FO-3), last, then (R1-01) a `pacing` line (longest no-new-best streak in the first 30 deployments; largest unspent Data as a multiple of that deployment's Data income) and report-only `target` lines against the `journey` rows of `data/targets.csv` (best after 3 deployments 20-25, Day 1 35-45, streak at most 4, unspent at most 1.5x income; `max` metrics are upper bounds; never a gate). File: `build/journey/<name>.csv`. Exit 0 ok, 2 bad arguments, script error or failed self-check. Run one Godot process at a time. Sources: `tools/journey_run.gd`, `tools/journey/*.gd`. The x1.75-per-25-levels milestone (was x1.25 per 10 before FO-3) is a code constant (`Curves`), not a `-Set` key.

## Results log: FO-2 journey study (2026-11-09, base main dce40fb, sim as of M4-15)

Change under test: none to the game. New tool `tools/journey_run.ps1` (above) and the study `docs/balance/foundry_early_power.md`. `balance_run` cross-check on the tree (seeds 1-20, greedy4, TIMED, VANGUARD): fresh p10 11 / p50 12 / p90 13 (target 12 PASS), `foundry_300` p50 16 (+4 waves, target 16 PASS), `foundry_1k` p50 30 (target 24, +25%, PASS within 30%).

Journeys (seeds 1-16, greedy4 inside runs, all banked Data spent between runs):

| Foundry policy | best after 3 runs (cum Data) | w45 reached | first deployment ending after 35 min of 2x play | after 16 runs |
|---|---|---|---|---|
| none (control) | w12 (497) | never | w13 | w13 |
| cheapest | w15 (640) | 34 min | w57, 1.06e4 Data | w89 |
| laser | w24 (1073) | 26 min | w62, 1.01e4 | w75 |
| recommended | w15 (640) | 36 min | w60, 7.5e3 | w89 |
| roundrobin | w15 (592) | 45 min | w55, 8.4e3 | w84 |

GDD: first session w20-25 and ~800 Data; Day 1 w35-45 and ~6e3 Data. Verdicts: first session PASS/FLAG (typical play 5 waves short, laser all-in on target); Day 1 FLAG (ahead by 10-17 waves, 25-75% more Data); waves per 300 Data FLAG for concentrated spends (laser 800 Data: +19 waves, 1.8x the design +4 per 300); week 1 / month 1 NOT ASSESSED - NO DATA (sector 1 only). Options measured with the same seeds (A income, B costs, C cap tied to best wave, D milestone reshape, E = D4 + C): see the report; proposed (not applied): x1.75 every 25 Foundry levels (instead of x1.25 every 10) plus a cap of max(3, floor(0.6 * best wave)) per row, which puts both the typical and the single-stat stacker at w35 on Day 1 with the long-run curve intact (late pace within 7%). Option D numbers were measured with `Curves.MILESTONE_FOUNDRY_*` and `FoundryRules.MILESTONE_STEP` temporarily edited and reverted.

## Results log: FO-3 Foundry retune (2026-11-10, base main 552ecb1, SimVersion 4 to 5)

Change under test: Foundry milestone x1.75 per 25 levels (was x1.25 per 10) and the best-wave level cap `max(3, floor(0.6 * best_wave_s1))` per row (GDD 05 s1.2, s1.5). Same seeds as FO-2 (journey seeds 1-16 and 101-116, VANGUARD TIMED, greedy4). Baseline numbers are the FO-2 report's (section 4.1 and 5, same tool and seeds; the tool's spending now goes through the real cap).

| Journey (seed 1) | after 3 runs | at the first deployment ending after 35 min 2x | after 16 runs | FO-2 baseline (Day 1 / 16 runs) |
|---|---|---|---|---|
| VANGUARD recommended | w15 | w35 (39.4 min) | w76 (126 min) | w60 / w89 |
| VANGUARD laser | w16 | w35 (39.7 min) | w84 (129 min) | w62 / w75 |
| BULWARK recommended | w22 | w54 (38.5 min) | w84 | w59 / w100 |
| STRIKER recommended | w15 | w59 (45.4 min) | w85 | w69 / w99 |
| BULWARK laser | w25 | w69 (47.3 min) | w84 | w64 / - |
| STRIKER laser | w22 | w55 (38.0 min) | w85 | w62 / - |
| VANGUARD recommended, seeds 101+ | w16 | w36 (35.2 min) | w75 | w49 / w87 |
| VANGUARD laser, seeds 101+ | w16 | w35 (36.9 min) | w75 | w65 / w75 |

`balance_run` (20 seeds, greedy4, TIMED, VANGUARD): fresh p50 12 (target 12 PASS), `foundry_300` 16 (target 16 PASS), `foundry_1k` 24 (target 24 PASS; was 30). Frames with `foundry_1k` (`journey_run -ProfileFile ... -Frames`): fire rate 1.16 / 0.93 / 1.51 (1 : 0.80 : 1.30), hull 160 / 480 / 80 (1 : 3 : 0.5), plating 0 / 0.10 / 0; p50 24 / 28 / 28 (VANGUARD / BULWARK / STRIKER). The profile JSONs keep `best_wave_s1` 0 (they are applied directly to the config, not bought, so the cap does not touch them; they sit above the cap of a real profile and are grandfathered levels).
