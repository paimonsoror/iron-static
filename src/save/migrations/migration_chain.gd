class_name MigrationChain
extends RefCounted
## Chained, pure schema migrations (TECH_ARCHITECTURE 5.2, M3-04).
##
## THE RULE: the table holds one `func(doc: Dictionary) -> Dictionary` per step; `table[i]` migrates schema
## `i + 1` to `i + 2`. Real steps live in `src/save/migrations/migrate_v{N}_to_v{N+1}.gd` (static `apply`)
## and are registered in `SaveSchema.migrations()`. Any change to the serialized shape needs, in the same
## change: `SaveSchema.CURRENT` + 1, a migration step, and a new `tests/fixtures/save_v{N}.json` (the shape
## guard in `test_save_schema` fails otherwise). A migration never deletes a field it does not own: keep
## the data for one version. A migration must not mutate its input (work on a deep copy).
##
## `run` returns `{"ok": bool, "doc": Dictionary, "error": String, "from": int, "to": int}` (impl: a
## status dictionary instead of a bare document so a downgrade or a gap is an error, never a guess).


static func run(doc: Dictionary, from: int, to: int, table: Array[Callable]) -> Dictionary:
	var res: Dictionary = {"ok": false, "doc": doc, "error": "", "from": from, "to": to}
	if to < from:
		res["error"] = "downgrade refused (%d -> %d)" % [from, to]
		return res
	if from < 1:
		res["error"] = "invalid source version %d" % from
		return res
	var cur: Dictionary = doc.duplicate(true)
	for v: int in range(from, to):
		var idx: int = v - 1
		if idx >= table.size() or not table[idx].is_valid():
			res["error"] = "missing migration v%d -> v%d" % [v, v + 1]
			return res
		var step: Callable = table[idx]
		var out: Variant = step.call(cur)
		if not out is Dictionary:
			res["error"] = "migration v%d -> v%d returned no document" % [v, v + 1]
			return res
		var next_doc: Dictionary = out
		cur = next_doc
		cur["schema_version"] = v + 1
	res["ok"] = true
	res["doc"] = cur
	return res
