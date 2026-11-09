class_name KillEntry
extends RefCounted
## One enemy type killed in the run (results kill strip, M4): its enemy id, how many, and whether it is a boss.
## `list` turns `RunStats.kills_by_type` (already part of the run snapshot and the state hash) into the strip order.

var id: String = ""
var count: int = 0
var boss: bool = false


## Entries for every type with at least one kill, most kills first (ties keep enemy table order, bosses are not
## moved: a boss is highlighted by the view, not sorted). `ids[i]` is the id of enemy type index `i`.
static func list(kills_by_type: PackedInt32Array, ids: PackedStringArray) -> Array[KillEntry]:
	var out: Array[KillEntry] = []
	for i: int in mini(kills_by_type.size(), ids.size()):
		if kills_by_type[i] <= 0:
			continue
		var e := KillEntry.new()
		e.id = ids[i]
		e.count = kills_by_type[i]
		e.boss = ids[i].begins_with("boss")
		var at: int = out.size()
		while at > 0 and out[at - 1].count < e.count:
			at -= 1
		out.insert(at, e)
	return out


## Localized enemy name (`enemy.name.<id>`), falling back to the upper-cased id for types without a string.
static func display_name(enemy_id: String) -> String:
	var key: String = "enemy.name." + enemy_id
	if Strings.has_key(key):
		return Strings.get_text(key)
	return enemy_id.to_upper()
