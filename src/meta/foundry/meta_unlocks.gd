class_name MetaUnlocks
extends RefCounted
## Meta-progression unlock gates for the MVP (GDD 05 section 7 rows 1-2, M3-06). Pure static.

const NAV_HOME: StringName = &"home"
const NAV_FOUNDRY: StringName = &"foundry"


## The Foundry screen appears after the first death (a banked run). All four rows are usable from then on.
static func foundry_screen_unlocked(profile: PlayerProfile) -> bool:
	return profile.runs_total >= 1


## Visible bottom-nav entries; locked entries are hidden, not grayed (07 section 2.3).
static func visible_nav(profile: PlayerProfile) -> Array[StringName]:
	var out: Array[StringName] = [NAV_HOME]
	if foundry_screen_unlocked(profile):
		out.append(NAV_FOUNDRY)
	return out


## (run upgrade row index, gate wave) of the next locked run row, or (-1, 0): the Home hint.
static func next_unlock_line(upgrades: Array[RunUpgradeDef], best_wave: int) -> Vector2i:
	return UnlockRules.next_unlock(upgrades, best_wave)
