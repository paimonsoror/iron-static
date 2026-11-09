class_name DataPatchTable
extends RefCounted
## Importer helper for data/patches.csv (M4-13), split from DataMetaTables for the file-size cap.
## Returns `{"files": Dictionary, "errors": PackedStringArray}`; a missing CSV gives no files and no errors.

const PATCH_SCRIPT: String = "res://src/data_defs/patch_def.gd"
const PATCH_TABLE_SCRIPT: String = "res://src/data_defs/patch_table.gd"
const COLUMNS: PackedStringArray = [
	"id",
	"kind",
	"stat",
	"op",
	"per_pick",
	"max_picks",
	"cost_stat",
	"cost_op",
	"cost_value",
	"name_key",
	"desc_key",
	"tag",
	"source",
]
const KINDS: PackedStringArray = ["standard", "gamble"]
const OPS: PackedStringArray = ["bonus", "mult", "add"]
## Stats a patch may change (`add` only on PLATING_PCT_ADD).
const STATS: PackedStringArray = [
	"laser_output",
	"hull_integrity",
	"cycle_rate",
	"scrap_yield",
	"data_yield",
	"nano_repair",
	"plating_pct",
	"enemy_damage",
]
const ADD_STATS: PackedStringArray = ["plating_pct"]


static func patches(path: String) -> Dictionary:
	var out: Dictionary = {"files": {}, "errors": PackedStringArray()}
	if not FileAccess.file_exists(path):
		return out
	var table: CsvTable = CsvTable.load_file(path)
	var errs: PackedStringArray = PackedStringArray()
	if not table.error.is_empty():
		errs.append(table.error)
		out["errors"] = errs
		return out
	var rd: DataRowReader = DataRowReader.new("patches.csv")
	var seen: Dictionary = {}
	var ids: PackedStringArray = PackedStringArray()
	var pending: Dictionary = {}
	if rd.check_columns(table, COLUMNS):
		for r: int in table.rows.size():
			var id: String = table.get_value(r, "id")
			var ctx: String = "row %d (%s)" % [r + 1, id]
			rd.snake_id(ctx + " id", id)
			if seen.has(id):
				rd.fail("%s: duplicate id" % ctx)
			seen[id] = true
			pending[id] = _row(rd, table, r, ctx)
			ids.append(id)
	errs.append_array(rd.errors)
	out["errors"] = errs
	if errs.is_empty():
		_emit(out, ids, pending)
	return out


static func _row(rd: DataRowReader, table: CsvTable, r: int, ctx: String) -> Dictionary:
	var p: Dictionary = {"id": table.get_value(r, "id")}
	var kind: String = rd.text(ctx + " kind", table.get_value(r, "kind"))
	rd.require(KINDS.has(kind), ctx, "kind must be standard or gamble")
	p["kind"] = kind
	var stat_text: String = rd.text(ctx + " stat", table.get_value(r, "stat"))
	var op: String = rd.text(ctx + " op", table.get_value(r, "op"))
	rd.require(OPS.has(op), ctx, "op must be bonus, mult or add")
	var stat_list: PackedStringArray = stat_text.split(";", false)
	for s: String in stat_list:
		rd.require(STATS.has(s), ctx, "unknown stat '%s'" % s)
		if op == "add":
			rd.require(ADD_STATS.has(s), ctx, "op add is only valid on plating_pct")
	p["stat"] = stat_text
	p["op"] = op
	var per_pick: float = rd.number(ctx + " per_pick", table.get_value(r, "per_pick"))
	rd.require(per_pick > 0.0, ctx, "per_pick must be > 0")
	p["per_pick"] = per_pick
	var max_picks: int = rd.integer(ctx + " max_picks", table.get_value(r, "max_picks"))
	rd.require(max_picks > 0, ctx, "max_picks must be > 0")
	p["max_picks"] = max_picks
	_cost(rd, table, r, ctx, kind, p)
	p["name_key"] = rd.text(ctx + " name_key", table.get_value(r, "name_key"))
	p["desc_key"] = rd.text(ctx + " desc_key", table.get_value(r, "desc_key"))
	p["tag"] = rd.text(ctx + " tag", table.get_value(r, "tag"))
	return p


static func _cost(rd: DataRowReader, table: CsvTable, r: int, ctx: String, kind: String, p: Dictionary) -> void:
	var cost_stat: String = table.get_value(r, "cost_stat")
	var cost_op: String = table.get_value(r, "cost_op")
	var cost_text: String = table.get_value(r, "cost_value")
	if kind == "gamble":
		rd.text(ctx + " cost_stat", cost_stat)
		rd.require(STATS.has(cost_stat), ctx, "unknown cost_stat '%s'" % cost_stat)
		rd.require(cost_op == "mult", ctx, "cost_op must be mult")
		var v: float = rd.number(ctx + " cost_value", cost_text)
		rd.require(v > 0.0, ctx, "cost_value must be > 0")
		p["cost_stat"] = cost_stat
		p["cost_op"] = cost_op
		p["cost_value"] = v
	else:
		rd.require(
			cost_stat.is_empty() and cost_op.is_empty() and cost_text.is_empty(), ctx, "a standard patch has no cost"
		)
		p["cost_stat"] = ""
		p["cost_op"] = ""
		p["cost_value"] = 1.0


static func _emit(out: Dictionary, ids: PackedStringArray, pending: Dictionary) -> void:
	var files: Dictionary = {}
	var res_paths: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var file_name: String = "%s.tres" % id
		var props: Dictionary = pending[id]
		files[file_name] = TresWriter.resource_text("PatchDef", PATCH_SCRIPT, props)
		res_paths.append(DataMetaTables.GEN_RES_DIR + file_name)
	files["patch_table.tres"] = TresWriter.table_text("PatchTable", PATCH_TABLE_SCRIPT, "defs", PATCH_SCRIPT, res_paths)
	out["files"] = files
