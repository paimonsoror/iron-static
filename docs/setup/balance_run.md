# Balance runner (`tools/balance_run.ps1`, M2-14)

Changelog: 2026-11-09 (`--policy only:<row id>`, Q54 retune) - 2026-11-08 (M3-08, M3-24: Foundry profiles, `--frame`, `--policy none`, frames table, mean line, frame tuning log) - 2026-11-07 created (M2-14).

The standard "did I break the economy" check (TECH_ARCHITECTURE 10.3). Required in the definition of
done for every economy or sim change: paste the output in the commit message and compare it to
`data/targets.csv`.

## Command

```
.\tools\balance_run.ps1 -Profile fresh -Waves 100 -Runs 20 -Seed 1 -Policy greedy4 [-Sector 1] [-Frame vanguard]
```

| Flag | Default | Meaning |
|---|---|---|
| `-Profile` | `fresh` | `fresh` (best_wave_s1 0, no Foundry) or a JSON file: `{"name": "...", "best_wave_s1": 0, "foundry_levels": {"laser_output": 5, ...}, "total_cost": 325}`. `foundry_levels` is `{Foundry row id: level}` and goes through `SimConfigLoader.apply_foundry` (M3-08); an unknown id exits 2. `total_cost` is informational (a test recomputes it). Checked-in profiles: `tests/profiles/foundry_300.json`, `foundry_1k.json`. |
| `-Waves` | 100 | cap: a run that is still alive after this wave reports death wave = cap |
| `-Runs` | 20 | seeds are `Seed .. Seed+Runs-1` |
| `-Seed` | 1 | first seed |
| `-Policy` | `greedy4` | `PolicyBot` policy: `greedy4`, `all`, `none` (never buys: only the starting stats matter, M3-24) or `only:<row id>` (buys only that run-upgrade row, e.g. `only:hull_integrity`; used in the Q54 retune to check that early hull, plating and repair purchases extend runs; a gated row such as `plating_pct`, best wave 10, needs a profile whose `best_wave_s1` has unlocked it) |
| `-Sector` | 1 | sector number (sets `SimConfig.sector`) |
| `-Frame` | `vanguard` | Cinder frame id from `data/frames.csv` (implemented ones: vanguard, bulwark, striker), or `all` to run every implemented frame on the same seeds and print a frames table (M3-24). Unknown or unimplemented id exits 2. |

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

`profile,metric,target,tolerance,source`. Tolerance is relative: PASS within it, WARN within 2x, FAIL beyond.
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
- `-Policy none` never buys (the runner skips `PolicyBot`); `targets.csv` rows are only compared for VANGUARD with a
  buying policy. Foundry profile target rows (`foundry_300` 13, `foundry_1k` 24) are information only: a FAIL
  there is printed as WARN (**impl**).
- `tools/sim_run.ps1` takes `--foundry id=level,...` and `--frame <id>` (forwarded flags).
- Shared config building is `BalanceSetup` (`src/core/balance_setup.gd`).
- Measured numbers, the frame gate and the `data/frames.csv` tuning log: `docs/playtests/m3/balance_m3.md`
  (fresh 9; `foundry_300` 11 = +2 waves, `foundry_1k` 22 = +13; frames BULWARK +3.2% / STRIKER +7.5% greedy4,
  BULWARK +1.6% idle with parity-tuned option P; gate NOT met inside the identity bounds, see the report).
