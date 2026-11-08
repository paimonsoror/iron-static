extends SceneTree
## Headless sim runner (M1-16). Run through tools\sim_run.ps1.
## Usage: godot --headless --path . -s res://tools/sim_run.gd -- [--runs N] [--seed S] [--max-waves W]
## stdout (deterministic, byte-identical across executions): one CSV line per run
## "seed,death_wave,game_seconds,kills,scrap_earned,data_earned,hash", then
## "SUMMARY runs=N death_wave p10=.. p50=.. p90=..", then "SIM RUN OK". Seeds are seed, seed+1, ...
## A run that survives max-waves reports death_wave = max-waves.
## Wall-clock info is on lines starting "TIMING" (excluded from the identity check; the wrapper sends
## them to stderr). Also writes build/sim/last.csv (with a header line).

const CSV_HEADER: String = "seed,death_wave,game_seconds,kills,scrap_earned,data_earned,hash"
const OUT_DIR: String = "res://build/sim"


func _initialize() -> void:
	var args: SimRunArgs = SimRunArgs.parse(OS.get_cmdline_user_args())
	if not args.error.is_empty():
		print("SIM RUN ERROR: %s" % args.error)
		print(SimRunArgs.USAGE)
		quit(2)
		return
	var lines: PackedStringArray = PackedStringArray()
	var death_waves: PackedInt32Array = PackedInt32Array()
	var total_ticks: int = 0
	var t0: int = Time.get_ticks_usec()
	for r: int in range(args.runs):
		var run_seed: int = args.seed_value + r
		var world: SimWorld = SimWorld.new(SimConfigLoader.load_default(run_seed))
		while not world.is_over() and world.wave <= args.max_waves:
			world.step()
		var death_wave: int = world.run.death_wave if world.is_over() else args.max_waves
		death_waves.append(death_wave)
		total_ticks += world.tick
		var line: String = (
			"%d,%d,%.2f,%d,%.2f,%.2f,%s"
			% [
				run_seed,
				death_wave,
				float(world.tick) / float(Ticks.TICK_RATE),
				world.run.kills,
				world.run.scrap_earned,
				world.run.data_earned,
				world.state_hash(),
			]
		)
		lines.append(line)
		print(line)
	var elapsed: float = float(Time.get_ticks_usec() - t0) / 1000000.0
	print(
		(
			"SUMMARY runs=%d death_wave p10=%d p50=%d p90=%d"
			% [
				args.runs,
				SimRunArgs.percentile(death_waves, 10),
				SimRunArgs.percentile(death_waves, 50),
				SimRunArgs.percentile(death_waves, 90),
			]
		),
	)
	_write_csv(lines)
	var game_s: float = float(total_ticks) / float(Ticks.TICK_RATE)
	var speedup: float = game_s / maxf(elapsed, 0.000001)
	print("TIMING wall=%.2fs game=%.1fs speedup=%.0fx" % [elapsed, game_s, speedup])
	print("SIM RUN OK")
	quit(0)


func _write_csv(lines: PackedStringArray) -> void:
	var dir: String = ProjectSettings.globalize_path(OUT_DIR)
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		print("SIM RUN ERROR: cannot create %s" % dir)
		return
	var f: FileAccess = FileAccess.open(dir + "/last.csv", FileAccess.WRITE)
	if f == null:
		print("SIM RUN ERROR: cannot write %s/last.csv" % dir)
		return
	f.store_string(CSV_HEADER + "\n" + "\n".join(lines) + "\n")
	f.close()
