class_name RunMode
extends RefCounted
## Which wave mode a new deployment uses (M4-08, Q75). Pure static. Order: the debug override (`--mode purge`,
## dev builds only, ignores the lock) wins; then the requested mode; then the profile's `last_mode`; a locked or
## unknown mode is never used (TIMED instead), so REDEPLOY repeats the last unlocked choice.


static func resolve(profile: PlayerProfile, requested: String, debug_override: String) -> String:
	if not debug_override.is_empty():
		return debug_override
	for id: String in [requested, profile.last_mode]:
		if not id.is_empty() and profile.mode_unlocked(id):
			return id
	return SimConfig.MODE_TIMED
