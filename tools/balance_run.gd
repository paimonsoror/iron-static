extends SceneTree
## Headless balance runner (M2-14). Run through tools\balance_run.ps1.
## Usage: godot --headless --path . -s res://tools/balance_run.gd -- [--profile fresh|FILE.json] [--waves W]
##   [--runs N] [--seed S] [--policy greedy4|all|none|cheapest|random] [--sector K] [--frame ID|all]
##   [--mode timed|purge]
## stdout (deterministic, every line starts with "BALANCE"): header, per-run lines, death wave percentiles and
## mean, mean game minutes, cause-of-death histogram, curve excerpt, target comparison, RESULT and "BALANCE OK".
## A profile with foundry_levels (M3-08) applies them through SimConfigLoader.apply_foundry and prints a
## "BALANCE FOUNDRY delta" line against a silent fresh run on the same seeds. `--frame all` (M3-24) runs every
## implemented frame in frames.csv and prints a frames table. `--policy none` never buys. `--mode purge` (M4-10)
## runs PURGE waves, labels the header and target lines with the mode and compares the `purge` rows.
## R1-01: a fresh-profile run with a buying optimizer (greedy4 / all) also prints a report-only "optimizer vs random on
## fresh" line (the same seeds with the `random` policy; the review measured 11.7 against 11.9). The honesty check for
## later phases that make buying matter; not a gate.
## Wall-clock info is on a "TIMING" line (the wrapper sends it to stderr).
## Files: build/balance/curve.csv (per-wave averages), build/balance/run0_buys.csv (run 0 purchases).
## Exit code: 0 ok, 1 when a target row is FAIL, 2 on bad arguments or a script error.

const OUT_DIR: String = "res://build/balance"
const TARGETS_PATH: String = "res://data/targets.csv"
const CURVE_EXCERPT_STEP: int = 5
const BASE_FRAME: String = "vanguard"


func _initialize() -> void:
	var args: BalanceRunArgs = BalanceRunArgs.parse(OS.get_cmdline_user_args())
	if not args.error.is_empty():
		_fail_args(args.error)
		return
	PolicyBot.draft_mode = args.draft
	var profile_name: String = args.profile
	var best_wave: int = 0
	var foundry: Dictionary = {}
	if args.profile != "fresh":
		var loaded: Dictionary = _load_profile(args.profile)
		if loaded.has("error"):
			_fail_args(str(loaded["error"]))
			return
		profile_name = str(loaded["name"])
		best_wave = loaded["best_wave_s1"]
		foundry = loaded["foundry_levels"]
	var frames: PackedStringArray = PackedStringArray([args.frame])
	if args.frame == BalanceRunArgs.FRAME_ALL:
		frames = BalanceSetup.implemented_frames()
	for frame_id: String in frames:
		var frame_err: String = BalanceSetup.frame_error(frame_id)
		if not frame_err.is_empty():
			_fail_args(frame_err)
			return
	var t0: int = Time.get_ticks_usec()
	var total_ticks: int = 0
	var overall: String = BalanceRunArgs.STATUS_PASS
	var table: Array[Dictionary] = []
	for frame_id: String in frames:
		var res: Dictionary = _run_set(args, frame_id, profile_name, best_wave, foundry, true)
		if res.has("error"):
			print("BALANCE ERROR: %s" % res["error"])
			quit(2)
			return
		total_ticks += res["ticks"]
		table.append(res)
		if not foundry.is_empty():
			var fresh: Dictionary = _run_set(args, frame_id, "fresh", 0, {}, false)
			total_ticks += fresh["ticks"]
			print(
				(
					"BALANCE FOUNDRY delta median vs fresh: %+d waves (fresh p50=%d, %s p50=%d; mean %+.2f)"
					% [res["p50"] - fresh["p50"], fresh["p50"], profile_name, res["p50"], res["mean"] - fresh["mean"]]
				)
			)
		# Targets are for the standard buyer on the neutral frame (greedy4); idle runs have none.
		if frame_id == BASE_FRAME and args.policy != "none":
			var p50: int = res["p50"]
			var measured: Dictionary = {"median_death_wave": float(p50)}
			overall = BalanceRunArgs.worst(overall, _compare_targets(profile_name, measured, args.mode))
	if frames.size() > 1:
		_print_frames_table(table, args.policy)
	total_ticks += _print_optimizer_vs_random(args, table)
	print("BALANCE RESULT %s" % overall)
	var elapsed: float = float(Time.get_ticks_usec() - t0) / 1000000.0
	var game_s: float = float(total_ticks) / float(Ticks.TICK_RATE)
	print("TIMING wall=%.2fs game=%.1fs speedup=%.0fx" % [elapsed, game_s, game_s / maxf(elapsed, 0.000001)])
	print("BALANCE OK")
	quit(1 if overall == BalanceRunArgs.STATUS_FAIL else 0)


## Runs `args.runs` seeds with one frame and prints the usual block when `verbose`. Returns
## {frame, p10, p50, p90, mean, ticks} or {error}.
func _run_set(
	args: BalanceRunArgs, frame_id: String, profile_name: String, best_wave: int, foundry: Dictionary, verbose: bool
) -> Dictionary:
	if verbose:
		var frame_part: String = "" if frame_id == BASE_FRAME else " frame=%s" % frame_id
		var mode_part: String = "" if args.mode == "timed" else " mode=%s" % args.mode
		print(
			(
				"BALANCE profile=%s policy=%s sector=%d waves=%d runs=%d seed=%d best_wave_s1=%d%s%s"
				% [
					profile_name,
					args.policy,
					args.sector,
					args.waves,
					args.runs,
					args.seed_value,
					best_wave,
					frame_part,
					mode_part
				]
			)
		)
	var death_waves: PackedInt32Array = PackedInt32Array()
	var minutes_sum: float = 0.0
	var total_ticks: int = 0
	var causes: Dictionary[String, int] = {}  # label -> count; labels inserted in first-seen order, printed sorted
	var wave_scrap: PackedFloat64Array = PackedFloat64Array()
	var wave_data: PackedFloat64Array = PackedFloat64Array()
	var wave_runs: PackedInt32Array = PackedInt32Array()
	var buys_csv: String = ""
	var buys: bool = BalanceRunArgs.buys(args.policy)
	for r: int in range(args.runs):
		var run_seed: int = args.seed_value + r
		var cfg: SimConfig = BalanceSetup.make_config(run_seed, args.sector, best_wave, foundry, frame_id, args.mode)
		var world: SimWorld = SimWorld.new(cfg)
		var bot: PolicyBot = PolicyBot.new(args.policy)
		var prev_wave: int = world.wave
		var prev_scrap: float = 0.0
		var prev_data: float = 0.0
		while not world.is_over() and world.wave <= args.waves:
			@warning_ignore("return_value_discarded")  # every policy, also "none", takes the first offer (M4-15)
			PolicyBot.settle_draft(world)
			if buys and world.tick % PolicyBot.THINK_INTERVAL == 0:
				bot.think(world)
			world.step()
			if world.wave != prev_wave:
				_add_wave(wave_scrap, wave_data, wave_runs, prev_wave, world, prev_scrap, prev_data)
				prev_wave = world.wave
				prev_scrap = world.run.scrap_earned
				prev_data = world.run.data_earned
		var survived: bool = not world.is_over()
		var death_wave: int = args.waves if survived else world.run.death_wave
		death_waves.append(death_wave)
		total_ticks += world.tick
		var minutes: float = float(world.tick) / float(Ticks.TICK_RATE) / 60.0
		minutes_sum += minutes
		var cause: String = _cause_label(world, survived)
		var prior: int = causes.get(cause, 0)
		causes[cause] = prior + 1
		if verbose:
			print(
				(
					"BALANCE run seed=%d death_wave=%d minutes=%.2f cause=%s kills=%d hash=%s"
					% [run_seed, death_wave, minutes, cause, world.run.kills, world.state_hash()]
				)
			)
		if r == 0:
			buys_csv = _buys_csv(world)
	var out: Dictionary = {
		"frame": frame_id,
		"p10": SimRunArgs.percentile(death_waves, 10),
		"p50": SimRunArgs.percentile(death_waves, 50),
		"p90": SimRunArgs.percentile(death_waves, 90),
		"mean": SimRunArgs.mean(death_waves),
		"ticks": total_ticks,
	}
	if not verbose:
		return out
	print("BALANCE death_wave p10=%d p50=%d p90=%d" % [out["p10"], out["p50"], out["p90"]])
	print("BALANCE death_wave_mean=%.2f" % out["mean"])
	print("BALANCE mean_game_minutes=%.2f" % (minutes_sum / float(args.runs)))
	if args.mode != "timed":
		# Real time per wave against the fixed 24 s TIMED wave (Q69): only printed for non-TIMED modes.
		var waves_total: int = 0
		for dw: int in death_waves:
			waves_total += dw
		print(
			(
				"BALANCE mode=%s mean_seconds_per_wave=%.1f (timed: %.1f)"
				% [
					args.mode,
					float(total_ticks) / float(Ticks.TICK_RATE) / maxf(float(waves_total), 1.0),
					float(Ticks.WAVE_TICKS) / float(Ticks.TICK_RATE)
				]
			)
		)
	var labels: Array[String] = causes.keys()
	labels.sort()
	for label: String in labels:
		var n: int = causes[label]
		print("BALANCE cause %s %d (%.0f%%)" % [label, n, 100.0 * float(n) / float(args.runs)])
	_print_curve_excerpt(wave_scrap, wave_data, wave_runs)
	if (
		not _write_file("curve.csv", _curve_csv(wave_scrap, wave_data, wave_runs))
		or not _write_file("run0_buys.csv", buys_csv)
	):
		return {"error": "cannot write %s" % OUT_DIR}
	return out


## R1-01: report-only honesty line, "optimizer vs random on fresh". Runs the `random` buyer on the same seeds for a
## fresh profile when the policy is an optimizer; returns the extra ticks simulated (0 when nothing was printed).
func _print_optimizer_vs_random(args: BalanceRunArgs, table: Array[Dictionary]) -> int:
	if args.profile != "fresh" or not ["greedy4", "all"].has(args.policy):
		return 0
	var base: Dictionary = {}
	for res: Dictionary in table:
		if res["frame"] == BASE_FRAME:
			base = res
	if base.is_empty():
		return 0
	var random_args: BalanceRunArgs = BalanceRunArgs.new()
	random_args.waves = args.waves
	random_args.runs = args.runs
	random_args.seed_value = args.seed_value
	random_args.sector = args.sector
	random_args.mode = args.mode
	random_args.policy = PolicyBot.POLICY_RANDOM
	var rnd: Dictionary = _run_set(random_args, BASE_FRAME, "fresh", 0, {}, false)
	var opt_mean: float = base["mean"]
	var rnd_mean: float = rnd["mean"]
	print(
		(
			"BALANCE optimizer vs random on fresh: %s mean=%.2f random mean=%.2f diff=%+.2f waves (report only)"
			% [args.policy, opt_mean, rnd_mean, opt_mean - rnd_mean]
		)
	)
	return rnd["ticks"]


## One line per frame: mean and median death wave and the mean delta against VANGUARD (first row).
func _print_frames_table(table: Array[Dictionary], policy: String) -> void:
	var base_mean: float = table[0]["mean"]
	for res: Dictionary in table:
		var mean: float = res["mean"]
		var delta: float = 100.0 * (mean - base_mean) / maxf(base_mean, 0.000001)
		print(
			(
				"BALANCE frames frame=%s policy=%s mean=%.2f median=%d p10=%d p90=%d delta_mean_vs_vanguard=%+.1f%%"
				% [res["frame"], policy, res["mean"], res["p50"], res["p10"], res["p90"], delta]
			)
		)


func _fail_args(message: String) -> void:
	print("BALANCE ERROR: %s" % message)
	print("usage: " + BalanceRunArgs.USAGE.trim_prefix("usage: "))
	quit(2)


## Reads a profile JSON: {"best_wave_s1": int, "foundry_levels": {id: level}, "name": str (optional)}.
func _load_profile(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "profile file not found: %s" % path}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"error": "profile is not a JSON object: %s" % path}
	var dict: Dictionary = parsed
	var name_text: String = str(dict.get("name", path.get_file().get_basename()))
	var foundry: Dictionary = dict.get("foundry_levels", {})
	var foundry_err: String = BalanceSetup.foundry_error(foundry)
	if not foundry_err.is_empty():
		return {"error": foundry_err}
	var clean: Dictionary = {}
	for key: Variant in foundry.keys():
		var raw: Variant = foundry[key]
		var level: float = raw if (raw is int or raw is float) else -1.0
		if level < 0.0:
			return {"error": "foundry level of '%s' must be a non-negative integer" % str(key)}
		clean[str(key)] = int(level)
	var best: int = dict.get("best_wave_s1", 0)
	return {"name": name_text, "best_wave_s1": best, "foundry_levels": clean}


func _add_wave(
	scrap: PackedFloat64Array,
	data: PackedFloat64Array,
	counts: PackedInt32Array,
	finished_wave: int,
	world: SimWorld,
	prev_scrap: float,
	prev_data: float
) -> void:
	while counts.size() < finished_wave:
		var failed: bool = scrap.append(0.0)
		failed = data.append(0.0) or failed
		failed = counts.append(0) or failed
		if failed:
			push_error("balance_run: append failed")
	scrap[finished_wave - 1] += world.run.scrap_earned - prev_scrap
	data[finished_wave - 1] += world.run.data_earned - prev_data
	counts[finished_wave - 1] += 1


func _cause_label(world: SimWorld, survived: bool) -> String:
	if survived:
		return "survived"
	var idx: int = world.run.death_cause
	if idx < 0 or idx >= world.config.enemies.size():
		return "none"
	return world.config.enemies[idx].id


func _buys_csv(world: SimWorld) -> String:
	var out: String = "tick,wave,upgrade,level\n"
	var levels: PackedInt32Array = PackedInt32Array()
	if levels.resize(world.config.upgrades.size()) != OK:
		push_error("balance_run: resize failed")
	levels.fill(0)
	var log: InputLog = world.input_log
	for i: int in log.size():
		var row: int = log.arg_a[i]
		levels[row] += log.arg_b[i]
		var wave: int = 1 + floori(float(log.ticks[i]) / float(Ticks.WAVE_TICKS))
		out += "%d,%d,%s,%d\n" % [log.ticks[i], wave, world.config.upgrades[row].id, levels[row]]
	return out


func _curve_csv(scrap: PackedFloat64Array, data: PackedFloat64Array, counts: PackedInt32Array) -> String:
	var out: String = "wave,runs,avg_scrap_earned,avg_data_earned\n"
	for w: int in counts.size():
		if counts[w] == 0:
			continue
		var n: float = float(counts[w])
		out += "%d,%d,%.2f,%.2f\n" % [w + 1, counts[w], scrap[w] / n, data[w] / n]
	return out


func _print_curve_excerpt(scrap: PackedFloat64Array, data: PackedFloat64Array, counts: PackedInt32Array) -> void:
	for w: int in counts.size():
		var wave: int = w + 1
		if counts[w] == 0 or (wave != 1 and wave % CURVE_EXCERPT_STEP != 0):
			continue
		var n: float = float(counts[w])
		print(
			"BALANCE curve wave=%d runs=%d avg_scrap=%.1f avg_data=%.2f" % [wave, counts[w], scrap[w] / n, data[w] / n]
		)


## Prints one line per targets.csv row of this profile and returns the worst status (PASS when none).
func _compare_targets(profile_name: String, measured: Dictionary, mode_id: String) -> String:
	var table: CsvTable = CsvTable.load_file(TARGETS_PATH)
	if not table.error.is_empty():
		print("BALANCE ERROR: %s" % table.error)
		return BalanceRunArgs.STATUS_FAIL
	var overall: String = BalanceRunArgs.STATUS_PASS
	var found: int = 0
	for i: int in table.rows.size():
		if table.get_value(i, "profile") != profile_name or BalanceRunArgs.row_mode(table, i) != mode_id:
			continue
		found += 1
		var metric: String = table.get_value(i, "metric")
		var target: float = table.get_value(i, "target").to_float()
		var tol: float = table.get_value(i, "tolerance").to_float()
		if not measured.has(metric):
			print("BALANCE target %s %s SKIP (metric not measured)" % [profile_name, metric])
			continue
		var value: float = measured[metric]
		var st: String = BalanceRunArgs.status(value, target, tol)
		if BalanceRunArgs.info_only(profile_name, mode_id) and st == BalanceRunArgs.STATUS_FAIL:
			st = BalanceRunArgs.STATUS_WARN  # (impl) Foundry profile and PURGE rows are information only
		var mode_label: String = "" if mode_id == "timed" else "mode=%s " % mode_id
		overall = BalanceRunArgs.worst(overall, st)
		var dev: float = 100.0 * (value - target) / maxf(absf(target), 0.000001)
		print(
			(
				"BALANCE target %s%s %s measured=%.1f target=%.1f tol=%.0f%% dev=%+.1f%% %s (%s)"
				% [mode_label, profile_name, metric, value, target, tol * 100.0, dev, st, table.get_value(i, "source")]
			)
		)
	if found == 0:
		print("BALANCE target no rows for profile '%s' mode '%s' in data/targets.csv" % [profile_name, mode_id])
	return overall


func _write_file(file_name: String, text: String) -> bool:
	var dir: String = ProjectSettings.globalize_path(OUT_DIR)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var f: FileAccess = FileAccess.open(dir + "/" + file_name, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true
