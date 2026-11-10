extends SceneTree
## Headless journey simulator (FO-2). Run through tools\journey_run.ps1.
## From a fresh profile: N consecutive deployments. Inside a deployment the run upgrades are bought by balance_run's
## PolicyBot (greedy4 by default); between deployments all banked Data goes into the Foundry by a named policy
## (cheapest, laser, recommended, roundrobin, none; see tools/journey/journey_spend.gd). Banking, best wave, Foundry
## costs and caps use the real PlayerProfile / FoundryService / FoundryRules. See docs/balance/foundry_early_power.md.
## Usage: godot --headless --path . -s res://tools/journey_run.gd -- [--spend P] [--deployments N] [--seed S]
##   [--waves W] [--frame ID] [--mode timed|purge] [--run-policy greedy4|all|none] [--set key=value]...
##   [--cap-k K --cap-min M] [--probe DATA | --profile FILE.json] [--frames] [--runs N] [--name TEXT] [--self-check]
## In-memory overrides (--set): sim.<key>, enemy.<id>.data_base, enemies.data_scale, foundry.<id>.<f|f_cap|fc0|fg>.
## stdout (deterministic, every line starts with "JOURNEY"): header, one "dep" line per deployment, marks
## (after 3 deployments, at 35 min of 2x play, first x1.25 milestone, last), "JOURNEY OK". Probe mode prints the
## death-wave gain of a fixed Data spend. TIMING goes to its own line (the wrapper sends it to stderr).
## File: build/journey/<name>.csv (one row per deployment). Exit code: 0 ok, 2 bad arguments, error or failed check.

const OUT_DIR: String = "res://build/journey"
const SESSION_DEPLOYMENTS: int = 3  ## GDD 05 section 8: the first session is 3 runs
const DAY_ONE_MINUTES_2X: float = 35.0  ## GDD 04 section 3: about 35 active minutes per day at 2x
const ROWS: PackedStringArray = ["laser_output", "cycle_rate", "hull_integrity", "nano_repair"]


func _initialize() -> void:
	var args: JourneyArgs = JourneyArgs.parse(OS.get_cmdline_user_args())
	if not args.error.is_empty():
		_fail(args.error)
		return
	if args.self_check:
		quit(JourneySelfCheck.run())
		return
	var overrides: JourneyOverrides = JourneyOverrides.parse(args.sets)
	if not overrides.error.is_empty():
		_fail(overrides.error)
		return
	var frame_err: String = BalanceSetup.frame_error(args.frame)
	if not frame_err.is_empty():
		_fail(frame_err)
		return
	var t0: int = Time.get_ticks_usec()
	if args.probe > 0.0 or not args.profile_file.is_empty():
		print(_header(args, overrides, "probe"))
		var probe_err: String = JourneyProbe.run(args, overrides)
		if not probe_err.is_empty():
			_fail(probe_err)
			return
	else:
		if not _journey(args, overrides):
			_fail("cannot write %s" % OUT_DIR)
			return
	print("TIMING wall=%.2fs" % (float(Time.get_ticks_usec() - t0) / 1000000.0))
	print("JOURNEY OK")
	quit(0)


func _fail(message: String) -> void:
	print("JOURNEY ERROR: %s" % message)
	print(JourneyArgs.USAGE)
	quit(2)


func _header(args: JourneyArgs, overrides: JourneyOverrides, what: String) -> String:
	var cap: String = "none" if args.cap_k <= 0.0 else "k=%s,min=%d" % [args.cap_k, args.cap_min]
	var sets: String = "none" if overrides.is_empty() else overrides.describe()
	return (
		"JOURNEY %s spend=%s frame=%s mode=%s run_policy=%s seed=%d waves=%d cap=%s set=%s"
		% [what, args.spend, args.frame, args.mode, args.run_policy, args.seed_value, args.waves, cap, sets]
	)


func _journey(args: JourneyArgs, overrides: JourneyOverrides) -> bool:
	print(_header(args, overrides, "journey deployments=%d" % args.deployments))
	var sim: JourneySim = JourneySim.new(args, overrides)
	var records: Array[Dictionary] = sim.run()
	var csv: String = (
		"dep,seed,frame,best_before,death_wave,capped,best_after,data,cum_data,spent,left,"
		+ "laser_output,cycle_rate,hull_integrity,nano_repair,minutes_1x,cum_min_1x,cum_min_2x,hash\n"
	)
	for r: Dictionary in records:
		var lv: Dictionary = r["levels"]
		var cum1: float = r["cum_min_1x"]
		print(
			(
				(
					"JOURNEY dep=%d seed=%d frame=%s death_wave=%d best=%d data=%.0f cum_data=%.0f spent=%.0f left=%.0f"
					+ " L=%d C=%d H=%d N=%d min1x=%.2f cum_min_2x=%.2f hash=%s%s"
				)
				% [
					r["dep"],
					r["seed"],
					r["frame"],
					r["death_wave"],
					r["best_after"],
					r["data"],
					r["cum_data"],
					r["spent"],
					r["left"],
					lv.get("laser_output", 0),
					lv.get("cycle_rate", 0),
					lv.get("hull_integrity", 0),
					lv.get("nano_repair", 0),
					r["minutes_1x"],
					cum1 / 2.0,
					r["hash"],
					" capped" if r["capped"] else "",
				]
			)
		)
		csv += (
			"%d,%d,%s,%d,%d,%s,%d,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%d,%.3f,%.3f,%.3f,%s\n"
			% [
				r["dep"],
				r["seed"],
				r["frame"],
				r["best_before"],
				r["death_wave"],
				r["capped"],
				r["best_after"],
				r["data"],
				r["cum_data"],
				r["spent"],
				r["left"],
				lv.get("laser_output", 0),
				lv.get("cycle_rate", 0),
				lv.get("hull_integrity", 0),
				lv.get("nano_repair", 0),
				r["minutes_1x"],
				cum1,
				cum1 / 2.0,
				r["hash"],
			]
		)
	_print_marks(records)
	var name_text: String = args.name_text
	if name_text.is_empty():
		name_text = "%s_%s_%s" % [args.spend, args.frame, args.mode]
	return _write_file(name_text + ".csv", csv)


## Marks against the GDD pace: after the 3-run first session, at 35 min of 2x play (Day 1), first x1.25 milestone.
func _print_marks(records: Array[Dictionary]) -> void:
	_mark("after_%d_deployments" % SESSION_DEPLOYMENTS, records, SESSION_DEPLOYMENTS - 1)
	var day_one: int = -1
	var first_ms: int = -1
	for i: int in records.size():
		var cum2: float = records[i]["cum_min_1x"] / 2.0
		if day_one < 0 and cum2 >= DAY_ONE_MINUTES_2X:
			day_one = i
		var lv: Dictionary = records[i]["levels"]
		for id: String in ["laser_output", "hull_integrity", "nano_repair"]:
			var level: int = lv.get(id, 0)
			if first_ms < 0 and level >= FoundryRules.MILESTONE_STEP:
				first_ms = i
	_mark("at_35_min_2x", records, day_one)
	_mark("first_x1.25_milestone", records, first_ms)
	_mark("last", records, records.size() - 1)


func _mark(label: String, records: Array[Dictionary], index: int) -> void:
	if index < 0 or index >= records.size():
		print("JOURNEY mark %s not reached" % label)
		return
	var r: Dictionary = records[index]
	var cum1: float = r["cum_min_1x"]
	var levels: Dictionary = r["levels"]
	print(
		(
			"JOURNEY mark %s dep=%d best=%d cum_data=%.0f cum_min_2x=%.1f (1x %.1f) levels_sum=%d"
			% [label, r["dep"], r["best_after"], r["cum_data"], cum1 / 2.0, cum1, _level_sum(levels)]
		)
	)


func _level_sum(levels: Dictionary) -> int:
	var total: int = 0
	for id: String in ROWS:
		var level: int = levels.get(id, 0)
		total += level
	return total


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
