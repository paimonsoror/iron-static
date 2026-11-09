class_name BalanceRunArgs
extends RefCounted
## Argument parsing and target comparison for tools/balance_run.gd (M2-14). Kept out of the tool script so
## it is unit-testable. Flags: --profile fresh|<json path>, --waves W, --runs N, --seed S,
## --policy greedy4|all|none, --sector K, --frame ID|all (M3-24).

const USAGE: String = (
	"usage: balance_run [--profile fresh|FILE.json] [--waves W] [--runs N] [--seed S]"
	+ " [--policy greedy4|all|none] [--sector K] [--frame ID|all]  (defaults: fresh, 100, 20, 1, greedy4, 1, vanguard)"
)
const DEFAULT_WAVES: int = 100
const DEFAULT_RUNS: int = 20
const DEFAULT_SEED: int = 1
## `none` never buys (only the starting stats matter; M3-24).
const POLICIES: PackedStringArray = ["greedy4", "all", "none"]
const FRAME_ALL: String = "all"
const STATUS_PASS: String = "PASS"
const STATUS_WARN: String = "WARN"
const STATUS_FAIL: String = "FAIL"

var profile: String = "fresh"
var waves: int = DEFAULT_WAVES
var runs: int = DEFAULT_RUNS
var seed_value: int = DEFAULT_SEED
var policy: String = "greedy4"
var sector: int = 1
## Frame id from frames.csv, or `all` for the frames table. Validated against the data by the tool.
var frame: String = "vanguard"
## Empty when parsing succeeded, otherwise a one-line reason.
var error: String = ""


static func parse(args: PackedStringArray) -> BalanceRunArgs:
	var out: BalanceRunArgs = BalanceRunArgs.new()
	var int_flags: PackedStringArray = ["--waves", "--runs", "--seed", "--sector"]
	var i: int = 0
	while i < args.size():
		var flag: String = args[i]
		var is_int: bool = int_flags.has(flag)
		if not is_int and not ["--profile", "--policy", "--frame"].has(flag):
			out.error = "unknown argument '%s'" % flag
			return out
		if i + 1 >= args.size():
			out.error = "%s needs a value" % flag
			return out
		var raw: String = args[i + 1]
		if is_int:
			if not raw.is_valid_int():
				out.error = "%s needs an integer value" % flag
				return out
			var value: int = raw.to_int()
			if flag != "--seed" and value < 1:
				out.error = "%s must be at least 1" % flag
				return out
			match flag:
				"--waves":
					out.waves = value
				"--runs":
					out.runs = value
				"--seed":
					out.seed_value = value
				_:
					out.sector = value
		elif flag == "--policy":
			if not POLICIES.has(raw):
				out.error = "--policy must be greedy4, all or none"
				return out
			out.policy = raw
		elif flag == "--frame":
			if raw.is_empty():
				out.error = "--frame needs a value"
				return out
			out.frame = raw
		else:
			if raw.is_empty():
				out.error = "--profile needs a value"
				return out
			out.profile = raw
		i += 2
	return out


## Status of a measured value against a target with a relative tolerance: PASS within `tolerance`,
## WARN within 2x tolerance, FAIL beyond.
static func status(measured: float, target: float, tolerance: float) -> String:
	var dev: float = absf(measured - target) / maxf(absf(target), 0.000001)
	if dev <= tolerance + 0.000001:
		return STATUS_PASS
	if dev <= 2.0 * tolerance + 0.000001:
		return STATUS_WARN
	return STATUS_FAIL


## Worst of two statuses (FAIL > WARN > PASS).
static func worst(a: String, b: String) -> String:
	if a == STATUS_FAIL or b == STATUS_FAIL:
		return STATUS_FAIL
	if a == STATUS_WARN or b == STATUS_WARN:
		return STATUS_WARN
	return STATUS_PASS


## Whether a policy buys at all (`none` is the idle scenario).
static func buys(policy_name: String) -> bool:
	return policy_name != "none"
