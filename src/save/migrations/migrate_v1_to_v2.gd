class_name MigrateV1ToV2
extends RefCounted
## Schema 1 to 2 (M4-06): the v1 `best_wave` becomes the TIMED record of `best_wave_by_mode`, TIMED is the only
## unlocked mode and the last mode. `best_wave` stays (the profile keeps writing it as the TIMED mirror). The
## PURGE unlock is decided on first load by `ModeRules` (a migration has no data tables). Never mutates `doc`.


static func apply(doc: Dictionary) -> Dictionary:
	var out: Dictionary = doc.duplicate(true)
	var raw: Variant = out.get("profile", null)
	if not raw is Dictionary:
		return out  # a malformed profile is reported by PlayerProfile.from_dict
	var profile: Dictionary = raw
	var timed: Dictionary = {}
	var old: Variant = profile.get("best_wave", null)
	if old is Dictionary:
		var old_d: Dictionary = old
		timed = old_d.duplicate(true)
	if not profile.has("best_wave_by_mode"):
		profile["best_wave_by_mode"] = {"timed": timed}
	if not profile.has("modes_unlocked"):
		profile["modes_unlocked"] = ["timed"]
	if not profile.has("last_mode"):
		profile["last_mode"] = "timed"
	return out
