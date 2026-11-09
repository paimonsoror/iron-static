class_name ModeUnlockFlag
extends RefCounted
## One-time "PURGE MODE UNLOCKED" chip flag (M4-08). Lives in the profile's `extra` dictionary (no schema field):
## `mark` records the ids a bank just unlocked, the Home picker shows the chip while `pending` is non-empty and
## `clear` ends it. Pure static.

const KEY: String = "mode_unlock_pending"


static func mark(profile: PlayerProfile, ids: Array[String]) -> void:
	if ids.is_empty():
		return
	var all: Array = pending_raw(profile)
	for id: String in ids:
		if not all.has(id):
			all.append(id)
	profile.extra[KEY] = all


## Ids waiting for their chip (strings only; anything else in the key is ignored).
static func pending(profile: PlayerProfile) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in pending_raw(profile):
		if v is String:
			out.append(v)
	return out


static func pending_raw(profile: PlayerProfile) -> Array:
	var v: Variant = profile.extra.get(KEY, [])
	if v is Array:
		var a: Array = v
		return a.duplicate()
	return []


## Removes the flag. True when there was one.
static func clear(profile: PlayerProfile) -> bool:
	return profile.extra.erase(KEY)
