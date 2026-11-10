class_name PlaySummary
extends RefCounted
## The plain-text play summary the Settings button copies to the clipboard (R1-08): totals over the flight recorder's
## window, then the newest days. English text from `data/strings_en.csv` (`summary.*`). Stays on the device unless the
## player pastes it somewhere.
##
## Example:
##   IRON STATIC PLAY SUMMARY
##   Version 0.5.0-beta.1, 2026-11-10 UTC
##   Last 30 days: 3 days played, 5 sessions, 74 min
##   Runs: timed 12, purge 3
##   Best wave in that time: 38 (all-time timed 41, purge 33)
##   Deepest screen: foundry. Last screen before quit: results.
##   2026-11-10  sessions 2  min 31  runs 5  best 38  last results

const RECENT_DAYS: int = 7


static func build(profile: PlayerProfile, clock: ClockSource, version: String) -> String:
	var all: Dictionary = FlightRecorder.days(profile)
	var keys: Array = all.keys()
	keys.sort()
	var lines: PackedStringArray = PackedStringArray()
	lines.append(Strings.get_text("summary.title"))
	var today: String = FlightRecorder.day_key(clock.now_utc())
	lines.append(Strings.fill("summary.version", {"v": version, "date": today}))
	if keys.is_empty():
		lines.append(Strings.get_text("summary.none"))
		return "\n".join(lines)
	var sessions: int = 0
	var seconds: int = 0
	var best: int = 0
	var runs: Dictionary = {}
	var deepest: String = ""
	for k: Variant in keys:
		var day: Dictionary = all[k]
		sessions += FlightRecorder.int_of(day, "s")
		seconds += FlightRecorder.int_of(day, "sec")
		best = maxi(best, FlightRecorder.int_of(day, "b"))
		var r: Dictionary = _runs_of(day)
		for mode: Variant in r.keys():
			runs[mode] = FlightRecorder.int_of(runs, str(mode)) + FlightRecorder.int_of(r, str(mode))
		var d: String = str(day.get("d", ""))
		if FlightRecorder.SCREEN_RANK.get(d, -1) > FlightRecorder.SCREEN_RANK.get(deepest, -1):
			deepest = d
	var newest: Dictionary = all[keys[keys.size() - 1]]
	lines.append(
		Strings.fill(
			"summary.totals",
			{
				"n": str(FlightRecorder.KEEP_DAYS),
				"days": str(keys.size()),
				"sessions": str(sessions),
				"minutes": str(roundi(float(seconds) / 60.0))
			}
		)
	)
	lines.append(Strings.fill1("summary.runs", "runs", _runs_text(runs)))
	lines.append(
		Strings.fill(
			"summary.best",
			{
				"w": str(best),
				"timed": str(profile.best_wave_of_mode("timed", 1)),
				"purge": str(profile.best_wave_of_mode("purge", 1))
			}
		)
	)
	lines.append(Strings.fill("summary.screens", {"d": _dash(deepest), "l": _dash(str(newest.get("l", "")))}))
	var first: int = maxi(keys.size() - RECENT_DAYS, 0)
	for i: int in range(keys.size() - 1, first - 1, -1):
		var day: Dictionary = all[keys[i]]
		lines.append(_day_line(str(keys[i]), day))
	return "\n".join(lines)


static func _day_line(key: String, day: Dictionary) -> String:
	var r: Dictionary = _runs_of(day)
	var total: int = 0
	for mode: Variant in r.keys():
		total += FlightRecorder.int_of(r, str(mode))
	var values: Dictionary[String, String] = {
		"date": key,
		"s": str(FlightRecorder.int_of(day, "s")),
		"m": str(roundi(float(FlightRecorder.int_of(day, "sec")) / 60.0)),
		"r": str(total),
		"b": str(FlightRecorder.int_of(day, "b")),
		"l": _dash(str(day.get("l", "")))
	}
	return Strings.fill("summary.day", values)


static func _runs_of(day: Dictionary) -> Dictionary:
	var v: Variant = day.get("r", null)
	if v is Dictionary:
		var out: Dictionary = v
		return out
	return {}


## "timed 12, purge 3" (modes sorted), "none" when no run was recorded.
static func _runs_text(runs: Dictionary) -> String:
	var modes: Array = runs.keys()
	modes.sort()
	var parts: PackedStringArray = PackedStringArray()
	for m: Variant in modes:
		parts.append("%s %d" % [str(m), FlightRecorder.int_of(runs, str(m))])
	return ", ".join(parts) if not parts.is_empty() else Strings.get_text("summary.runs_none")


static func _dash(text: String) -> String:
	return text if not text.is_empty() else "-"
