extends SceneTree
## Sim tick perf bench (M1-17). Run through tools\perf_bench.ps1.
## Usage: godot --headless --path . -s res://tools/perf_bench.gd -- [--update-baseline] [--check]
## Holds 600 enemies and 600 bolts alive on an invulnerable Cinder for 900 ticks and times SimWorld.step()
## (top-up spawning is outside the timed section). Runs REPEATS fresh worlds and reports the one with the
## lowest average (best-of, to cut desktop noise). Prints:
##   PERF avg_ms=.. p95_ms=.. max_ms=.. enemies=.. bolts=..
## --update-baseline writes res://tests/perf_baseline.json; --check fails if avg is >10% worse than it.

const TICKS: int = 900
const REPEATS: int = 3
const TARGET_ENEMIES: int = 600
const TARGET_BOLTS: int = 600
const BOLT_CAPACITY: int = 700
const RING_MIN_M: float = 10.0
const RING_MAX_M: float = 50.0
const BOLT_SPEED_MPS: float = 12.0
const BOLT_DAMAGE: float = 1.0
const AVG_BUDGET_MS: float = 4.0
const REGRESSION_LIMIT: float = 1.10
const BASELINE_PATH: String = "res://tests/perf_baseline.json"

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _initialize() -> void:
	var update: bool = false
	var check: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a == "--update-baseline":
			update = true
		elif a == "--check":
			check = true
		else:
			print("PERF ERROR: unknown argument '%s'" % a)
			print("usage: perf_bench [--update-baseline] [--check]")
			quit(2)
			return
	var best: Dictionary = {}
	for r: int in range(REPEATS):
		var result: Dictionary = _run_once()
		var avg: float = result["avg_ms"]
		var best_avg: float = best.get("avg_ms", INF)
		if avg < best_avg:
			best = result
	print("PERF avg_ms p95_ms max_ms enemies bolts")
	print(
		(
			"PERF avg_ms=%.3f p95_ms=%.3f max_ms=%.3f enemies=%d bolts=%d"
			% [
				best["avg_ms"],
				best["p95_ms"],
				best["max_ms"],
				best["enemies"],
				best["bolts"],
			]
		),
	)
	var avg_ms: float = best["avg_ms"]
	if avg_ms > AVG_BUDGET_MS:
		print("PERF NOTE: average %.3f ms is over the %.1f ms budget" % [avg_ms, AVG_BUDGET_MS])
	if update:
		_write_baseline(best)
	if check and not _check(avg_ms):
		print("PERF CHECK FAILED")
		quit(1)
		return
	print("PERF OK")
	quit(0)


func _run_once() -> Dictionary:
	_rng.seed = 12345
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.debug_invulnerable = true
	cfg.tuning.alive_cap_normal = TARGET_ENEMIES  # world sizes its enemy store from the caps
	var world: SimWorld = SimWorld.new(cfg)
	world.projectiles = ProjectileStore.new(BOLT_CAPACITY)  # default 512 slots is below 600 bolts
	var types: int = cfg.enemies.size() - 1  # skip the boss (last row)
	var times_ms: PackedFloat64Array = PackedFloat64Array()
	var enemy_sum: int = 0
	var bolt_sum: int = 0
	for i: int in range(TICKS):
		_top_up(world, types)
		enemy_sum += world.enemies.alive_count
		bolt_sum += world.projectiles.alive_count
		var t0: int = Time.get_ticks_usec()
		world.step()
		times_ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	var sorted: PackedFloat64Array = times_ms.duplicate()
	sorted.sort()
	var total: float = 0.0
	for v: float in times_ms:
		total += v
	return {
		"avg_ms": total / float(TICKS),
		"p95_ms": sorted[ceili(0.95 * float(TICKS)) - 1],
		"max_ms": sorted[TICKS - 1],
		"enemies": roundi(float(enemy_sum) / float(TICKS)),
		"bolts": roundi(float(bolt_sum) / float(TICKS)),
	}


func _top_up(world: SimWorld, types: int) -> void:
	while world.enemies.alive_count < TARGET_ENEMIES:
		var p: Vector2 = _ring_point(_rng.randf_range(RING_MIN_M, RING_MAX_M))
		if world.debug_spawn_enemy(_rng.randi_range(0, types - 1), p.x, p.y) < 0:
			break
	while world.projectiles.alive_count < TARGET_BOLTS:
		var p: Vector2 = _ring_point(_rng.randf_range(RING_MIN_M, RING_MAX_M))
		var v: Vector2 = -p.normalized() * BOLT_SPEED_MPS
		if world.debug_spawn_bolt(p.x, p.y, v.x, v.y, BOLT_DAMAGE) < 0:
			break


func _ring_point(radius: float) -> Vector2:
	return Vector2.from_angle(_rng.randf_range(0.0, TAU)) * radius


func _write_baseline(best: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
	if f == null:
		print("PERF ERROR: cannot write %s" % BASELINE_PATH)
		return
	f.store_string(JSON.stringify(best, "\t", true) + "\n")
	f.close()
	print("PERF baseline written to %s" % BASELINE_PATH)


func _check(avg_ms: float) -> bool:
	if not FileAccess.file_exists(BASELINE_PATH):
		print("PERF ERROR: no baseline at %s (run with --update-baseline)" % BASELINE_PATH)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	if not parsed is Dictionary:
		print("PERF ERROR: baseline is not a JSON object")
		return false
	var base: Dictionary = parsed
	var base_avg: float = base.get("avg_ms", 0.0)
	var limit: float = base_avg * REGRESSION_LIMIT
	print("PERF check: avg %.3f ms vs baseline %.3f ms (limit %.3f ms)" % [avg_ms, base_avg, limit])
	return avg_ms <= limit
