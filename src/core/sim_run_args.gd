class_name SimRunArgs
extends RefCounted
## Argument parsing and summary statistics for tools/sim_run.gd (M1-16). Kept out of the tool script so
## it is unit-testable. Flags: --runs N, --seed S, --max-waves W (all integers, N and W at least 1),
## --foundry id=level,... (M3-08), --frame ID (M3-24) and --mode timed|purge (M4-10).

const USAGE: String = (
	"usage: sim_run [--runs N] [--seed S] [--max-waves W] [--foundry id=level,...] [--frame ID]"
	+ " [--mode timed|purge]  (defaults: 20, 1, 200, none, vanguard, timed)"
)
const DEFAULT_RUNS: int = 20
const DEFAULT_SEED: int = 1
const DEFAULT_MAX_WAVES: int = 200

var runs: int = DEFAULT_RUNS
var seed_value: int = DEFAULT_SEED
var max_waves: int = DEFAULT_MAX_WAVES
## `id=level,id=level` as typed (parsed and validated by BalanceSetup in the tool); empty = no Foundry.
var foundry: String = ""
var frame: String = "vanguard"
var mode: String = "timed"
## Empty when parsing succeeded, otherwise a one-line reason.
var error: String = ""


static func parse(args: PackedStringArray) -> SimRunArgs:
	var out: SimRunArgs = SimRunArgs.new()
	var i: int = 0
	while i < args.size():
		var flag: String = args[i]
		if not ["--runs", "--seed", "--max-waves", "--foundry", "--frame", "--mode"].has(flag):
			out.error = "unknown argument '%s'" % flag
			return out
		if flag == "--foundry" or flag == "--frame" or flag == "--mode":
			if i + 1 >= args.size() or args[i + 1].is_empty():
				out.error = "%s needs a value" % flag
				return out
			if flag == "--foundry":
				out.foundry = args[i + 1]
			elif flag == "--mode":
				if not BalanceRunArgs.MODES.has(args[i + 1]):
					out.error = "--mode must be timed or purge"
					return out
				out.mode = args[i + 1]
			else:
				out.frame = args[i + 1]
			i += 2
			continue
		if i + 1 >= args.size() or not args[i + 1].is_valid_int():
			out.error = "%s needs an integer value" % flag
			return out
		var value: int = args[i + 1].to_int()
		if flag == "--seed":
			out.seed_value = value
		elif value < 1:
			out.error = "%s must be at least 1" % flag
			return out
		elif flag == "--runs":
			out.runs = value
		else:
			out.max_waves = value
		i += 2
	return out


## Nearest-rank percentile (p in 0..100) of an unsorted list; 0 for an empty list.
static func percentile(values: PackedInt32Array, p: int) -> int:
	if values.is_empty():
		return 0
	var sorted: PackedInt32Array = values.duplicate()
	sorted.sort()
	var rank: int = ceili(float(p) / 100.0 * float(sorted.size()))
	return sorted[clampi(rank - 1, 0, sorted.size() - 1)]


## Mean of the values; 0.0 for an empty list.
static func mean(values: PackedInt32Array) -> float:
	if values.is_empty():
		return 0.0
	var total: int = 0
	for v: int in values:
		total += v
	return float(total) / float(values.size())
