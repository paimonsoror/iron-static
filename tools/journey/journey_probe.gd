class_name JourneyProbe
extends RefCounted
## Probe mode of the journey tool (FO-2): a fixed set of Foundry levels against a fresh start, over `args.runs` seeds.
## The levels come from `--probe DATA` (spend that much Data from a fresh profile by the `--spend` policy) or from
## `--profile FILE.json` (balance_run's profile format: foundry_levels, name). Overrides (`--set`) apply to both
## the fresh and the boosted runs. With `--frames` every implemented frame is measured (gates ignored), else
## `--frame`. Prints, per frame, the resolved start stats (frame identity: cycle rate, plating, hull) and the
## death wave p50/mean without and with the levels, and for a profile the `data/targets.csv` status.

const TARGETS_PATH: String = "res://data/targets.csv"


static func run(args: JourneyArgs, overrides: JourneyOverrides) -> String:
	var sim: JourneySim = JourneySim.new(args, overrides)
	var levels: Dictionary = {}
	var label: String = ""
	var bought: int = 0
	if not args.profile_file.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args.profile_file))
		if typeof(parsed) != TYPE_DICTIONARY:
			return "profile file not readable: %s" % args.profile_file
		var dict: Dictionary = parsed
		var raw: Dictionary = dict.get("foundry_levels", {})
		for key: Variant in raw.keys():
			var level_raw: Variant = raw[key]
			var level_num: float = level_raw if (level_raw is int or level_raw is float) else 0.0
			levels[str(key)] = int(level_num)
		label = str(dict.get("name", args.profile_file.get_file().get_basename()))
	else:
		sim.profile.data = BigNum.from_float(args.probe)
		bought = sim.spender.spend(sim.profile, sim.make_service(false))
		levels = sim.profile.foundry.duplicate()
		label = "spend_%s_%d" % [args.spend, int(args.probe)]
	var defs: Array[FoundryDef] = overrides.foundry_defs()
	var cost: float = 0.0
	for def: FoundryDef in defs:
		var lvl: int = levels.get(def.id, 0)
		cost += FoundryRules.total_cost(def, 0, lvl, FoundryRules.NO_LIMIT, sim.foundry_tuning()).to_float()
	print(
		(
			"JOURNEY probe label=%s levels=%s cost=%.0f bought=%d left=%.0f runs=%d"
			% [label, JSON.stringify(levels), cost, bought, sim.profile.data.to_float(), args.runs]
		)
	)
	var frames: PackedStringArray = BalanceSetup.implemented_frames() if args.frames_all else [args.frame]
	for frame_id: String in frames:
		_frame(sim, args, label, levels, cost, frame_id)
	return ""


static func _frame(
	sim: JourneySim, args: JourneyArgs, label: String, levels: Dictionary, cost: float, frame_id: String
) -> void:
	var a: StatBlock = SimWorld.new(sim.make_config(1, 0, {}, frame_id)).stats
	var b: StatBlock = SimWorld.new(sim.make_config(1, 0, levels, frame_id)).stats
	print(
		(
			"JOURNEY probe frame=%s start cycle=%.2f->%.2f plating=%.2f->%.2f hull=%.0f->%.0f laser=%.1f->%.1f"
			% [
				frame_id,
				a.cycle_rate,
				b.cycle_rate,
				a.plating_pct,
				b.plating_pct,
				a.hull_integrity,
				b.hull_integrity,
				a.laser_output,
				b.laser_output
			]
		)
	)
	var fresh: PackedInt32Array = PackedInt32Array()
	var with_f: PackedInt32Array = PackedInt32Array()
	for r: int in range(args.runs):
		var s: int = args.seed_value + r
		var base: Dictionary = JourneySim.play(sim.make_config(s, 0, {}, frame_id), args.run_policy, args.waves)
		var boosted: Dictionary = JourneySim.play(sim.make_config(s, 0, levels, frame_id), args.run_policy, args.waves)
		var dw_a: int = base["death_wave"]
		var dw_b: int = boosted["death_wave"]
		if fresh.append(dw_a) or with_f.append(dw_b):
			push_error("JourneyProbe: append failed")
	var p50_a: int = SimRunArgs.percentile(fresh, 50)
	var p50_b: int = SimRunArgs.percentile(with_f, 50)
	var mean_a: float = SimRunArgs.mean(fresh)
	var mean_b: float = SimRunArgs.mean(with_f)
	print(
		(
			"JOURNEY probe frame=%s fresh p50=%d mean=%.2f foundry p50=%d mean=%.2f delta_p50=%+d delta_mean=%+.2f"
			% [frame_id, p50_a, mean_a, p50_b, mean_b, p50_b - p50_a, mean_b - mean_a]
		)
	)
	if cost > 0.0:
		print(
			(
				"JOURNEY probe frame=%s waves_per_300_data=%+.2f (mean gain scaled by 300/%.0f)"
				% [frame_id, (mean_b - mean_a) * 300.0 / cost, cost]
			)
		)
	if frame_id == "vanguard" and not args.profile_file.is_empty():
		_targets("fresh", p50_a)
		_targets(label, p50_b)


## One line per data/targets.csv timed row of `profile_name` against the measured median.
static func _targets(profile_name: String, p50: int) -> void:
	var table: CsvTable = CsvTable.load_file(TARGETS_PATH)
	for i: int in table.rows.size():
		if table.get_value(i, "profile") != profile_name or BalanceRunArgs.row_mode(table, i) != "timed":
			continue
		var target: float = table.get_value(i, "target").to_float()
		var tol: float = table.get_value(i, "tolerance").to_float()
		var st: String = BalanceRunArgs.status(float(p50), target, tol)
		print(
			(
				"JOURNEY probe target %s median_death_wave measured=%d target=%.0f tol=%.0f%% %s"
				% [profile_name, p50, target, tol * 100.0, st]
			)
		)
