class_name DataFtueTable
extends RefCounted
## Importer helper for data/ftue.csv (M4-25), split out of DataImporter for the file-size cap.
## Returns `{"files": Dictionary, "errors": PackedStringArray}`; a missing CSV gives no files and no errors.

const DEF_SCRIPT: String = "res://src/data_defs/ftue_beat_def.gd"
const TABLE_SCRIPT: String = "res://src/data_defs/ftue_table.gd"
const COLUMNS: PackedStringArray = ["id", "trigger", "target", "text_key", "max_runs"]


## `upgrades` = Dictionary keyed by run_upgrades.csv ids; string keys are read from `data_dir`/strings_en.csv.
static func ftue(path: String, upgrades: Dictionary, data_dir: String) -> Dictionary:
	var out: Dictionary = {"files": {}, "errors": PackedStringArray()}
	if not FileAccess.file_exists(path):
		return out
	var table: CsvTable = CsvTable.load_file(path)
	var errs: PackedStringArray = PackedStringArray()
	if not table.error.is_empty():
		errs.append(table.error)
		out["errors"] = errs
		return out
	var rd: DataRowReader = DataRowReader.new("ftue.csv")
	var seen: Dictionary = {}
	var ids: PackedStringArray = PackedStringArray()
	var pending: Dictionary = {}
	var keys: Dictionary = _string_keys(data_dir)
	if rd.check_columns(table, COLUMNS):
		for r: int in table.rows.size():
			var id: String = table.get_value(r, "id")
			var ctx: String = "row %d (%s)" % [r + 1, id]
			rd.snake_id(ctx + " id", id)
			if seen.has(id):
				rd.fail("%s: duplicate id" % ctx)
			seen[id] = true
			pending[id] = _row(rd, table, r, ctx, upgrades, keys)
			ids.append(id)
		rd.require(seen.has("cold_open"), "cold_open", "row 'cold_open' is missing")
	errs.append_array(rd.errors)
	out["errors"] = errs
	if errs.is_empty():
		_emit(out, ids, pending)
	return out


static func _row(
	rd: DataRowReader, table: CsvTable, r: int, ctx: String, upgrades: Dictionary, keys: Dictionary
) -> Dictionary:
	var p: Dictionary = {"id": table.get_value(r, "id")}
	var trigger: String = rd.text(ctx + " trigger", table.get_value(r, "trigger"))
	rd.require(FtueScript.TRIGGERS.has(trigger), ctx, "unknown trigger '%s'" % trigger)
	p["trigger"] = trigger
	var target: String = rd.text(ctx + " target", table.get_value(r, "target"))
	rd.require(_target_ok(target, upgrades), ctx, "bad target '%s'" % target)
	p["target"] = target
	var key: String = rd.text(ctx + " text_key", table.get_value(r, "text_key"))
	rd.require(keys.has(key), ctx, "unknown text_key '%s'" % key)
	p["text_key"] = key
	var runs: int = rd.integer(ctx + " max_runs", table.get_value(r, "max_runs"))
	rd.require(runs >= 1 and runs <= FtueScript.MAX_RUNS, ctx, "max_runs must be 1 to %d" % FtueScript.MAX_RUNS)
	p["max_runs"] = runs
	return p


static func _target_ok(target: String, upgrades: Dictionary) -> bool:
	if FtueScript.FIXED_TARGETS.has(target):
		return true
	if target.begins_with(FtueScript.ROW_PREFIX):
		return upgrades.has(target.substr(FtueScript.ROW_PREFIX.length()))
	return target.begins_with(FtueScript.FOUNDRY_PREFIX) and target.length() > FtueScript.FOUNDRY_PREFIX.length()


static func _string_keys(data_dir: String) -> Dictionary:
	var keys: Dictionary = {}
	var strings: CsvTable = CsvTable.load_file(data_dir.path_join("strings_en.csv"))
	for r: int in strings.rows.size():
		keys[strings.get_value(r, "key")] = true
	return keys


static func _emit(out: Dictionary, ids: PackedStringArray, pending: Dictionary) -> void:
	var files: Dictionary = {}
	var res_paths: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var file_name: String = "ftue_%s.tres" % id
		var props: Dictionary = pending[id]
		files[file_name] = TresWriter.resource_text("FtueBeatDef", DEF_SCRIPT, props)
		res_paths.append(DataMetaTables.GEN_RES_DIR + file_name)
	files["ftue_table.tres"] = TresWriter.table_text("FtueTable", TABLE_SCRIPT, "defs", DEF_SCRIPT, res_paths)
	out["files"] = files
