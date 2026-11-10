class_name JourneyArgs
extends RefCounted
## Argument parsing for tools/journey_run.gd (FO-2). Flags: --spend cheapest|laser|recommended|roundrobin|none,
## --deployments N, --seed S, --waves W, --frame ID, --mode timed|purge, --run-policy greedy4|all|none,
## --set key=value (repeatable in-memory override, see JourneyOverrides),
## --probe DATA, --profile FILE.json, --frames, --runs N, --name TEXT, --self-check.

const USAGE: String = (
	"usage: journey_run [--spend cheapest|laser|recommended|roundrobin|none] [--deployments N] [--seed S]"
	+ " [--waves W] [--frame ID] [--mode timed|purge] [--run-policy greedy4|all|none] [--set key=value]..."
	+ " [--probe DATA] [--profile FILE.json] [--frames] [--runs N] [--name TEXT] [--self-check]"
	+ "  (defaults: cheapest, 12, 1, 120, vanguard, timed, greedy4, 20 runs; the Foundry best-wave cap always applies)"
)
const SPEND_POLICIES: PackedStringArray = ["cheapest", "laser", "recommended", "roundrobin", "none"]
const RUN_POLICIES: PackedStringArray = ["greedy4", "all", "none"]
const MODES: PackedStringArray = ["timed", "purge"]

var spend: String = "cheapest"
var deployments: int = 12
var seed_value: int = 1
var waves: int = 120
var frame: String = "vanguard"
var mode: String = "timed"
var run_policy: String = "greedy4"
var sets: PackedStringArray = PackedStringArray()
## > 0: probe mode, spend this much Data from a fresh profile and compare `runs` seeds against fresh.
var probe: float = 0.0
var runs: int = 20
## Probe levels from a balance_run profile JSON instead of a spend, and measure every implemented frame.
var profile_file: String = ""
var frames_all: bool = false
var name_text: String = ""
var self_check: bool = false
var error: String = ""


static func parse(args: PackedStringArray) -> JourneyArgs:
	var out: JourneyArgs = JourneyArgs.new()
	var i: int = 0
	while i < args.size():
		var flag: String = args[i]
		if flag == "--self-check" or flag == "--frames":
			out.self_check = out.self_check or flag == "--self-check"
			out.frames_all = out.frames_all or flag == "--frames"
			i += 1
			continue
		if i + 1 >= args.size():
			out.error = "%s needs a value" % flag
			return out
		out.error = out._take(flag, args[i + 1])
		if not out.error.is_empty():
			return out
		i += 2
	return out


func _take(flag: String, raw: String) -> String:
	var err: String = ""
	match flag:
		"--spend":
			spend = raw
			err = _check(flag, raw, SPEND_POLICIES)
		"--run-policy":
			run_policy = raw
			err = _check(flag, raw, RUN_POLICIES)
		"--mode":
			mode = raw
			err = _check(flag, raw, MODES)
		"--frame":
			frame = raw
		"--name":
			name_text = raw
		"--profile":
			profile_file = raw
		"--set":
			if not raw.contains("=") or not raw.get_slice("=", 1).is_valid_float():
				err = "--set needs key=number ('%s')" % raw
			elif sets.append(raw):
				err = "append failed"
		"--probe":
			if not raw.is_valid_float() or raw.to_float() < 0.0:
				err = "%s needs a number >= 0" % flag
			else:
				probe = raw.to_float()
		"--deployments", "--seed", "--waves", "--runs":
			err = _take_int(flag, raw)
		_:
			err = "unknown argument '%s'" % flag
	return err


func _take_int(flag: String, raw: String) -> String:
	if not raw.is_valid_int():
		return "%s needs an integer value" % flag
	var value: int = raw.to_int()
	if flag != "--seed" and value < 1:
		return "%s must be at least 1" % flag
	match flag:
		"--deployments":
			deployments = value
		"--seed":
			seed_value = value
		"--waves":
			waves = value
		_:
			runs = value
	return ""


func _check(flag: String, raw: String, allowed: PackedStringArray) -> String:
	if allowed.has(raw):
		return ""
	return "%s must be one of %s" % [flag, ", ".join(allowed)]
