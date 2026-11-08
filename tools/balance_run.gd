extends SceneTree
## Headless balance runner (M2-14). Run through tools\balance_run.ps1.
## Usage: godot --headless --path . -s res://tools/balance_run.gd -- [--profile fresh|FILE.json] [--waves W]
##   [--runs N] [--seed S] [--policy greedy4|all] [--sector K]
## stdout (deterministic, every line starts with "BALANCE"): header, per-run lines, death wave percentiles,
## mean game minutes, cause-of-death histogram, curve excerpt, target comparison, RESULT and "BALANCE OK".
## Wall-clock info is on a "TIMING" line (the wrapper sends it to stderr).
## Files: build/balance/curve.csv (per-wave averages), build/balance/run0_buys.csv (run 0 purchases).
## Exit code: 0 ok, 1 when a target row is FAIL, 2 on bad arguments or a script error.

const OUT_DIR: String = "res://build/balance"
const TARGETS_PATH: String = "res://data/targets.csv"
const CURVE_EXCERPT_STEP: int = 5


func _initialize() -> void:
	var args: BalanceRunArgs = BalanceRunArgs.parse(OS.get_cmdline_user_args())
	if not args.error.is_empty():
		_fail_args(args.error)
		return
	var profile_name: String = args.profile
	var best_wave: int = 0
	if args.profile != "fresh":
		var loaded: Dictionary = _load_profile(args.profile)
		if loaded.has("error"):
			_fail_args(str(loaded["error"]))
			return
		profile_name = str(loaded["name"])
		best_wave = loaded["best_wave_s1"]
	print(
		(
			"BALANCE profile=%s policy=%s sector=%d waves=%d runs=%d seed=%d best_wave_s1=%d"
			% [profile_name, args.policy, args.sector, args.waves, args.runs, args.seed_value, best_wave]
		)
	)
	var t0: int = Time.get_ticks_usec()
	var death_waves: PackedInt32Array = PackedInt32Array()
	var minutes_sum: float = 0.0
	var total_ticks: int = 0
	var causes: Dictionary[String, int] = {}  # label -> count; labels inserted in first-seen order, printed sorted
	var wave_scrap: PackedFloat64Array = PackedFloat64Array()
	var wave_data: PackedFloat64Array = PackedFloat64Array()
	var wave_runs: PackedInt32Array = PackedInt32Array()
	var buys_csv: String = ""
	for r: int in range(args.runs):
		var run_seed: int = args.seed_value + r
		var cfg: SimConfig = SimConfigLoader.load_default(run_seed)
		cfg.sector = args.sector
		cfg.best_wave_s1 = best_wave
		var world: SimWorld = SimWorld.new(cfg)
		var bot: PolicyBot = PolicyBot.new(args.policy)
		var prev_wave: int = world.wave
		var prev_scrap: float = 0.0
		var prev_data: float = 0.0
		while not world.is_over() and world.wave <= args.waves:
			if world.tick % PolicyBot.THINK_INTERVAL == 0:
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
		print(
			(
				"BALANCE run seed=%d death_wave=%d minutes=%.2f cause=%s kills=%d hash=%s"
				% [run_seed, death_wave, minutes, cause, world.run.kills, world.state_hash()]
			)
		)
		if r == 0:
			buys_csv = _buys_csv(world)
	var elapsed: float = float(Time.get_ticks_usec() - t0) / 1000000.0
	var p50: int = SimRunArgs.percentile(death_waves, 50)
	print(
		(
			"BALANCE death_wave p10=%d p50=%d p90=%d"
			% [SimRunArgs.percentile(death_waves, 10), p50, SimRunArgs.percentile(death_waves, 90)]
		)
	)
	print("BALANCE mean_game_minutes=%.2f" % (minutes_sum / float(args.runs)))
	var labels: Array[String] = causes.keys()
	labels.sort()
	for label: String in labels:
		var n: int = causes[label]
		print("BALANCE cause %s %d (%.0f%%)" % [label, n, 100.0 * float(n) / float(args.runs)])
	var curve: String = _curve_csv(wave_scrap, wave_data, wave_runs)
	_print_curve_excerpt(wave_scrap, wave_data, wave_runs)
	if not _write_file("curve.csv", curve) or not _write_file("run0_buys.csv", buys_csv):
		print("BALANCE ERROR: cannot write %s" % OUT_DIR)
		quit(2)
		return
	var overall: String = _compare_targets(profile_name, {"median_death_wave": float(p50)})
	print("BALANCE RESULT %s" % overall)
	var game_s: float = float(total_ticks) / float(Ticks.TICK_RATE)
	print("TIMING wall=%.2fs game=%.1fs speedup=%.0fx" % [elapsed, game_s, game_s / maxf(elapsed, 0.000001)])
	print("BALANCE OK")
	quit(1 if overall == BalanceRunArgs.STATUS_FAIL else 0)


func _fail_args(message: String) -> void:
	print("BALANCE ERROR: %s" % message)
	print("usage: " + BalanceRunArgs.USAGE.trim_prefix("usage: "))
	quit(2)


## Reads a profile JSON: {"best_wave_s1": int, "foundry_levels": {...}, "name": str (optional)}.
func _load_profile(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "profile file not found: %s" % path}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"error": "profile is not a JSON object: %s" % path}
	var dict: Dictionary = parsed
	var name_text: String = str(dict.get("name", path.get_file().get_basename()))
	var foundry: Dictionary = dict.get("foundry_levels", {})
	if not foundry.is_empty():
		# (impl) the sim has no Foundry yet (M3+): foundry_levels is ignored.
		print("BALANCE warn foundry_levels ignored (the Foundry does not exist yet)")
	var best: int = dict.get("best_wave_s1", 0)
	return {"name": name_text, "best_wave_s1": best}


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
func _compare_targets(profile_name: String, measured: Dictionary) -> String:
	var table: CsvTable = CsvTable.load_file(TARGETS_PATH)
	if not table.error.is_empty():
		print("BALANCE ERROR: %s" % table.error)
		return BalanceRunArgs.STATUS_FAIL
	var overall: String = BalanceRunArgs.STATUS_PASS
	var found: int = 0
	for i: int in table.rows.size():
		if table.get_value(i, "profile") != profile_name:
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
		overall = BalanceRunArgs.worst(overall, st)
		var dev: float = 100.0 * (value - target) / maxf(absf(target), 0.000001)
		print(
			(
				"BALANCE target %s %s measured=%.1f target=%.1f tol=%.0f%% dev=%+.1f%% %s (%s)"
				% [profile_name, metric, value, target, tol * 100.0, dev, st, table.get_value(i, "source")]
			)
		)
	if found == 0:
		print("BALANCE target no rows for profile '%s' in data/targets.csv" % profile_name)
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
