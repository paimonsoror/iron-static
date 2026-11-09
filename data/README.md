# data/

Balance and content tables as CSV. The importer (`tools\import_data.ps1`, M1-02) turns them into `src/data_gen/*.tres`. Never hand-edit `src/data_gen/`.

Every CSV table must have:

- A header row as the first line.
- A first column `id` holding a snake_case id taken from the GDD (`docs/design/`); ids are never invented here.
- UTF-8 encoding without BOM, LF line endings.
- No currency or cost values outside `BigNum` string form where the GDD requires it.
- Cross-table references by GDD id only.

## Importer (M1-02)

`.\tools\import_data.ps1` reads `data/sim_constants.csv`, `enemies.csv` and `run_upgrades.csv`, validates them, and rewrites `src/data_gen/*.tres` (byte-identical when the CSV did not change; run it twice and `git status` shows nothing). Options: `-DataDir`, `-OutDir`, `-SkipImport` (skips the project re-import that registers new `class_name` scripts). It fails (exit 1, `IMPORT ERROR:` lines, nothing written) on an unknown or missing column, missing value, duplicate id, `g <= 1`, `l_cap <= 0`, negative `c0`, negative `spawn_weight`, non-finite numbers, an unknown or missing `sim_constants` key, or a malformed CSV row. Edit CSV only; never hand-edit `src/data_gen/`.

CSV syntax: header row first, comma separated, `"` quoting (`""` escapes a quote), lines starting with `#` are comments, blank lines are ignored. This folder has a `.gdignore` so Godot does not try to import the CSVs as translations; the importer reads them with `FileAccess`.

### Tables (M1)

- `sim_constants.csv` (`key,value,source,note`): one row per tunable, one typed var per key in `src/data_defs/sim_tuning.gd` (unknown or missing keys fail). `source` is `gdd:<doc section>` or `impl` (implementation-chosen first-pass value to be confirmed in the GDD). Becomes `sim_tuning.tres`. Adding a tunable means adding a var to `sim_tuning.gd` and a row here.
- `enemies.csv` (`id,group,shape,hp_mult,dmg_mult,speed,radius,slots,scrap_mult,data_base,spawn_weight,first_wave,behavior_id,tag`): GDD 03 section 1.1 and 1.3. Row order is the enemy type index (0 skitter, 1 dart, 2 walker, 3 lancer, 4 boss_hulk). Becomes `enemy_<id>.tres` per row plus `enemy_table.tres`.
- `run_upgrades.csv` (`id,tab,kind,base,step,l_cap,hard_cap,c0,g,gate_best_wave,tag`): GDD 02 section 7, gates from GDD 08 section 1.3. `kind` D: `step` is `p` of the D formula; C: `step` is the per-level increment. Empty `hard_cap` means none (`has_hard_cap` false). Becomes `upgrade_<id>.tres` per row plus `upgrade_table.tres`.
- `wave_modes.csv` (`id,implemented,unlock_best_timed_wave,backstop_s,reward_mult,sort,source,note`): wave modes (M4-01, Q68-Q76), imported to `WaveModeDef` files plus `WaveModeTable`. `unlock_best_timed_wave` is the best TIMED wave needed to unlock (0 = from the start); `backstop_s` is the PURGE wave time limit (0 = none, the 24 s wave clock rules); `reward_mult` scales per-kill rewards (1.0 both modes); `sort` is the picker order. Rules: ids unique, `timed` present, implemented and unlocked at 0, `backstop_s` > 0 for any non-timed implemented mode, `reward_mult` > 0, `sort` unique.
- `patches.csv` (`id,kind,stat,op,per_pick,max_picks,cost_stat,cost_op,cost_value,name_key,desc_key,tag,source`): the MVP in-run patches (M4-13, GDD 02 s10), imported by `DataPatchTable` to `PatchDef` files (`<id>.tres`) plus `PatchTable` (row order = patch index). `kind` standard or gamble; `op` bonus (`stat x (1 + per_pick x qty)`), mult (`stat x per_pick^qty`) or add (`plating_pct` points); `stat` may list several stats separated by `;` (`patch_extraction`, impl). A gamble names its cost (`cost_stat`, `cost_op` always mult, `cost_value`); a standard row leaves the cost cells empty. Stats: laser_output, hull_integrity, cycle_rate, scrap_yield, data_yield, nano_repair, plating_pct, enemy_damage. Strings: `name_key`, `desc_key`, and for gambles `<desc_key minus .desc>.cost`. The `draft_*` keys in `sim_constants.csv` are not part of the config hash until M4-15.
