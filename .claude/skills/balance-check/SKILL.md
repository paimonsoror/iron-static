---
name: balance-check
description: Check IRON STATIC game balance after an economy, upgrade, enemy or wave change - run the headless balance tools, compare against the GDD targets, and look for broken progressions, dead or dominant upgrade rows, and degenerate strategies. Use before committing any change to data/*.csv, Curves, rewards, costs or enemy stats, and when the user asks "is the balance OK?".
argument-hint: "[what changed, e.g. 'laser_output c0' or 'enemies.csv walker hp'] [profile, default fresh]"
---

# Balance check (IRON STATIC)

Adapted from the balance-check idea in Claude-Code-Game-Studios (MIT), rewritten for this repo's
tools. The sim is deterministic, so every number here is reproducible from a seed.

## Rules

- **No data means "not assessed".** List each input as FOUND or ABSENT first. A check whose input
  is missing is reported as `NOT ASSESSED - NO DATA`; never estimate it from an adjacent number.
- **Numbers live in the GDD and `data/*.csv`.** Never change them on your own initiative. Propose a
  change (CSV row, old value, new value, rationale), show its measured effect, and let the user
  decide. Accepted changes update the GDD section that owns the number (changelog line at the top).
- **Seeded and comparable.** Always state seed, run count, profile, policy and commit. Compare
  before/after with the same seeds.

## Inputs

| Input | Source |
|---|---|
| Targets | `data/targets.csv` (`profile,mode,metric,target,tolerance,source`; `purge` rows are info only until signed off); GDD `03_enemies_waves_tiers.md` section 6 (fresh x1 reaches wave 12; x2 24, x4 37, x10 60 once Foundry exists), `08_mvp_scope.md` FC1, FC9, FC10 |
| Formulas and tables | GDD `02_combat_in_run.md` sections 5-7, `03` sections 2-5, `04_economy.md`; `data/enemies.csv`, `data/run_upgrades.csv`, `data/sim_constants.csv` |
| Bot runs | `.\tools\balance_run.ps1 [-Profile fresh|file.json] [-Waves 100] [-Runs 20] [-Seed 1] [-Policy greedy4|all] [-Sector 1] [-Mode timed|purge]`; stdout lines start with `BALANCE` (table, `target ... PASS/WARN/FAIL`, `RESULT`), timing on stderr; exit 0 PASS/WARN, 1 FAIL row, 2 bad args/script error; writes `build/balance/curve.csv`, `build/balance/run0_buys.csv`. Capture stdout with `cmd /c "powershell -NoProfile -File tools\balance_run.ps1 > out.txt 2> err.txt"` (PS 5.1 `>` misses `Write-Host`). Reference (2026-11-08, M2): fresh/greedy4 p10 8, p50 9, p90 9 vs target 12 (PASS at -25%) |
| No-upgrade runs | `.\tools\sim_run.ps1 -Runs 20 -Seed 1` (death wave without purchases) |
| History | the results log in `docs/setup/balance_run.md` |
| Formula tests | `.\tools\test.ps1` (`test_curves`, `test_gdd_tables`, `test_stat_resolver`) |

If CSVs changed, run `.\tools\import_data.ps1` first and confirm `git diff src/data_gen` shows only
the expected `.tres` changes.

## Checks

1. **Targets**: the `balance_run` comparison rows (PASS / WARN / FAIL). Run both `-Mode timed` (default) and `-Mode purge` after a sim or economy change and report mean and median per mode; PURGE rows only ever WARN. FC10 bar: median within
   +-30% of the GDD table for each available profile.
2. **Before/after**: rerun the same command on the parent commit (use a temporary
   `git worktree add` in the scratchpad, never stash or reset the user's tree) and report the delta of
   p10/p50/p90 death wave and mean minutes. Flag a median shift above 15% that the change did not
   intend.
3. **Progression curve**: from `curve.csv`, scrap and data earned per wave should rise smoothly; flag
   plateaus (no growth for 5+ waves) or cliffs (a wave where income falls).
4. **Dead and dominant rows**: from `run0_buys.csv` (and the `all` policy), count levels bought per
   row. Flag rows never bought under `all` (possible trap or useless row; note that rows with no
   effect on the bot's score, such as `scrap_yield`, `reinvest`, `optic_range`, are skipped by
   design) and a single row taking more than 70% of purchases (dominant strategy).
5. **Policy gap**: if `all` dies much earlier than `greedy4`, extra rows may be traps; if the gap is
   zero, unlocks may not matter. Report the medians side by side.
6. **Threat mix**: the cause-of-death histogram; flag one enemy type causing more than 70% of deaths
   unless the change targeted it.
7. **Idle floor (FC9)**, once measurable: a run with only the first two upgrades bought should still
   reach wave 8 or more.
8. **Sanity**: no NaN/inf, no negative balances, BigNum warnings count zero (`BigNum.error_count`).

## Report

Append an entry to the results log in `docs/setup/balance_run.md`: date, commit, change under test,
command lines, the p10/p50/p90 table for each policy, target comparison, before/after deltas, one
verdict line per check (PASS / FLAG / NOT ASSESSED - NO DATA), and proposed changes (if any) with
their measured effect. Summarise in chat in three lines: verdict, biggest risk, recommended action.
