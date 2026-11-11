class_name RecordSeed
extends RefCounted
## Builds the first Service Record of a profile. A fresh profile starts at zero, dated by its creation. A profile
## that already has progress (a save from before the record existed) keeps what it knows exactly and starts the rest at
## zero on the seeding date; `seeded` = 1 makes the screen say so:
##   - deployments: `runs_total`, split by wave mode for the days the flight recorder still holds (30 days), the rest is
##     "before tracking" (`runs_pre`, mode unknown);
##   - time played: the flight recorder's seconds of those days;
##   - best waves, data earned and spent, Foundry levels are read live from the profile, never copied.
## Kills, shots, damage, scrap, waves cleared, longest deployment and the per-frame lines start at zero.


static func build(profile: PlayerProfile, clock: ClockSource) -> Dictionary:
	var rec: Dictionary = {"v": ServiceRecord.VERSION, "since": clock.now_utc(), "seeded": 0}
	if not profile.has_progress():
		if profile.created_utc > 0:
			rec["since"] = profile.created_utc
		return rec
	rec["seeded"] = 1
	var runs: Dictionary = {}
	var seen: int = 0
	var play: int = 0
	var days: Dictionary = FlightRecorder.days(profile)
	for key: Variant in days.keys():
		var day: Variant = days[key]
		if not day is Dictionary:
			continue
		var d: Dictionary = day
		play += FlightRecorder.int_of(d, "sec")
		var by_mode: Variant = d.get("r", null)
		if by_mode is Dictionary:
			var r: Dictionary = by_mode
			for mode: Variant in r.keys():
				var n: int = FlightRecorder.int_of(r, str(mode))
				runs[str(mode)] = RecordReader.int_of(runs, str(mode)) + n
				seen += n
	rec["runs"] = runs
	rec["runs_pre"] = maxi(profile.runs_total - seen, 0)
	rec["play_s"] = play
	return rec
