class_name JourneyPacing
extends RefCounted
## Pacing instrument math for the journey tool (R1-01, review G-15 and G-01). Pure statics over the per-deployment
## records `JourneySim.run` returns, so the streak and unspent-Data rules are unit-testable.
##   no_best_streak  deployments since the last new best (0 on a deployment that set one, +1 otherwise)
##   data_unspent    Data left after the deployment's spend step
## Summary: the longest streak within the first `STREAK_WINDOW` deployments and the largest unspent Data as a multiple
## of that deployment's own Data income. Targets are `journey` rows of data/targets.csv, report only (never a gate).

const STREAK_WINDOW: int = 30  ## the streak target covers the first 30 deployments
const TARGET_PROFILE: String = "journey"
const SESSION_DEPLOYMENTS: int = 3  ## GDD 05 section 8: the first session is 3 runs
const DAY_ONE_MINUTES_2X: float = 35.0  ## GDD 04 section 3
const M_STREAK: String = "journey_max_no_best_streak_30"
const M_UNSPENT: String = "journey_unspent_vs_income_max"
const M_BEST_3: String = "journey_best_after_3"
const M_BEST_DAY1: String = "journey_best_day1"


## Streak after a deployment: 0 when it set a new best, else the previous streak + 1.
static func next_streak(previous: int, new_best: bool) -> int:
	return 0 if new_best else previous + 1


## Largest `no_best_streak` among the first `window` records.
static func max_streak(records: Array[Dictionary], window: int = STREAK_WINDOW) -> int:
	var worst: int = 0
	for i: int in mini(window, records.size()):
		var s: int = records[i]["no_best_streak"]
		worst = maxi(worst, s)
	return worst


## Unspent Data as a multiple of the deployment's income; 0 when both are 0, INF when there was no income.
static func unspent_ratio(unspent: float, income: float) -> float:
	if unspent <= 0.0:
		return 0.0
	if income <= 0.0:
		return INF
	return unspent / income


## {ratio, dep} of the worst deployment (the first one on ties); {0.0, 0} for no records.
static func max_unspent(records: Array[Dictionary]) -> Dictionary:
	var worst: float = 0.0
	var dep: int = 0
	for r: Dictionary in records:
		var left: float = r["data_unspent"]
		var income: float = r["data"]
		var ratio: float = unspent_ratio(left, income)
		if ratio > worst:
			worst = ratio
			dep = r["dep"]
	return {"ratio": worst, "dep": dep}


## Index of the first deployment whose cumulative 2x play reaches Day 1 (35 min); -1 when never.
static func day_one_index(records: Array[Dictionary]) -> int:
	for i: int in records.size():
		var cum1: float = records[i]["cum_min_1x"]
		if cum1 / 2.0 >= DAY_ONE_MINUTES_2X:
			return i
	return -1


## The measured journey metrics by target name. Metrics the run is too short for are left out.
static func metrics(records: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	if records.is_empty():
		return out
	out[M_STREAK] = float(max_streak(records))
	var worst: Dictionary = max_unspent(records)
	out[M_UNSPENT] = worst["ratio"]
	if records.size() >= SESSION_DEPLOYMENTS:
		var best3: int = records[SESSION_DEPLOYMENTS - 1]["best_after"]
		out[M_BEST_3] = float(best3)
	var day: int = day_one_index(records)
	if day >= 0:
		var best_day: int = records[day]["best_after"]
		out[M_BEST_DAY1] = float(best_day)
	return out


## A `max` metric is an upper bound (pass at or below the target); the others are a target with a relative tolerance.
static func is_upper_bound(metric: String) -> bool:
	return metric.contains("max")


## PASS / WARN / FAIL of `value` against one targets.csv row (WARN within twice the tolerance, like balance_run).
static func status(metric: String, value: float, target: float, tolerance: float) -> String:
	if is_upper_bound(metric):
		return BalanceRunArgs.STATUS_PASS if value <= target + 0.000001 else BalanceRunArgs.STATUS_FAIL
	return BalanceRunArgs.status(value, target, tolerance)


## One "JOURNEY target ..." line per `journey` row of `table` whose metric was measured. Report only.
static func target_lines(table: CsvTable, measured: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for i: int in table.rows.size():
		if table.get_value(i, "profile") != TARGET_PROFILE:
			continue
		var metric: String = table.get_value(i, "metric")
		var target: float = table.get_value(i, "target").to_float()
		var tol: float = table.get_value(i, "tolerance").to_float()
		if not measured.has(metric):
			lines.append("JOURNEY target %s SKIP (not measured: run too short)" % metric)
			continue
		var value: float = measured[metric]
		var kind: String = "<=" if is_upper_bound(metric) else "~"
		lines.append(
			(
				"JOURNEY target %s measured=%.2f target%s%.2f %s (report only)"
				% [metric, value, kind, target, status(metric, value, target, tol)]
			)
		)
	return lines
