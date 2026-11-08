class_name DataImporter
extends RefCounted
## CSV to .tres importer core (M1-02). `run(data_dir, out_dir)` reads sim_constants.csv, enemies.csv and
## run_upgrades.csv, validates everything, and only when there are no errors writes the generated
## resources (byte-identical on every run, see TresWriter). `tools/import_data.gd` is the CLI wrapper.
## Tables with zero rows are valid (enemies, run_upgrades); sim_constants must define every key.

const TUNING_SCRIPT: String = "res://src/data_defs/sim_tuning.gd"
const ENEMY_SCRIPT: String = "res://src/data_defs/enemy_def.gd"
const ENEMY_TABLE_SCRIPT: String = "res://src/data_defs/enemy_table.gd"
const UPGRADE_SCRIPT: String = "res://src/data_defs/run_upgrade_def.gd"
const UPGRADE_TABLE_SCRIPT: String = "res://src/data_defs/upgrade_table.gd"
const STRING_TABLE_SCRIPT: String = "res://src/data_defs/string_table.gd"
const GEN_RES_DIR: String = "res://src/data_gen/"
const CONSTANT_COLUMNS: PackedStringArray = ["key", "value", "source", "note"]
const ENEMY_COLUMNS: PackedStringArray = [
	"id",
	"group",
	"shape",
	"hp_mult",
	"dmg_mult",
	"speed",
	"radius",
	"slots",
	"scrap_mult",
	"data_base",
	"spawn_weight",
	"first_wave",
	"behavior_id",
	"tag",
]  # gdlint: ignore=max-line-length
const UPGRADE_COLUMNS: PackedStringArray = [
	"id",
	"tab",
	"kind",
	"base",
	"step",
	"l_cap",
	"hard_cap",
	"c0",
	"g",
	"gate_best_wave",
	"tag",
]  # gdlint: ignore=max-line-length

var errors: PackedStringArray = PackedStringArray()
## Generated file name (no directory) to file text; filled by run().
var files: Dictionary = {}


## Imports data_dir into out_dir. Returns true on success; otherwise see `errors` (nothing is written).
func run(data_dir: String, out_dir: String) -> bool:
	errors = PackedStringArray()
	files = {}
	_build_constants(CsvTable.load_file(data_dir.path_join("sim_constants.csv")))
	_build_enemies(CsvTable.load_file(data_dir.path_join("enemies.csv")))
	_build_upgrades(CsvTable.load_file(data_dir.path_join("run_upgrades.csv")))
	_build_strings(data_dir.path_join("strings_en.csv"))
	if not errors.is_empty():
		return false
	return _write_all(out_dir)


func _load_error(table: CsvTable) -> bool:
	if table.error.is_empty():
		return false
	errors.append_array(PackedStringArray([table.error]))
	return true


func _build_constants(table: CsvTable) -> void:
	if _load_error(table):
		return
	var rd: DataRowReader = DataRowReader.new("sim_constants.csv")
	var types: Dictionary = _tuning_types()
	var props: Dictionary = {}
	if rd.check_columns(table, CONSTANT_COLUMNS):
		for r: int in table.rows.size():
			var key: String = table.get_value(r, "key")
			var ctx: String = "row %d (%s)" % [r + 1, key]
			rd.text(ctx + " key", key)
			var source: String = rd.text(ctx + " source", table.get_value(r, "source"))
			rd.require(source == "impl" or source.begins_with("gdd:"), ctx, "source must be 'impl' or 'gdd:<section>'")
			if not types.has(key):
				rd.fail("%s: unknown key (no var in sim_tuning.gd)" % ctx)
			elif props.has(key):
				rd.fail("%s: duplicate key" % ctx)
			elif types[key] == TYPE_INT:
				props[key] = rd.integer(ctx + " value", table.get_value(r, "value"))
			else:
				props[key] = rd.number(ctx + " value", table.get_value(r, "value"))
		for k: String in types:
			if not props.has(k):
				rd.fail("missing key '%s'" % k)
	errors.append_array(rd.errors)
	if rd.errors.is_empty():
		var sorted_props: Dictionary = {}
		var keys: Array = props.keys()
		keys.sort()
		for k: String in keys:
			sorted_props[k] = props[k]
		files["sim_tuning.tres"] = TresWriter.resource_text("SimTuning", TUNING_SCRIPT, sorted_props)


## Maps every var declared in sim_tuning.gd to its Variant type (TYPE_INT or TYPE_FLOAT).
func _tuning_types() -> Dictionary:
	var types: Dictionary = {}
	var script: GDScript = load(TUNING_SCRIPT)
	for p: Dictionary in script.get_script_property_list():
		var usage: int = p["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			types[p["name"]] = p["type"]
	return types


func _build_enemies(table: CsvTable) -> void:
	if _load_error(table):
		return
	var rd: DataRowReader = DataRowReader.new("enemies.csv")
	var seen: Dictionary = {}
	var ids: PackedStringArray = PackedStringArray()
	var pending: Dictionary = {}
	if rd.check_columns(table, ENEMY_COLUMNS):
		for r: int in table.rows.size():
			var id: String = table.get_value(r, "id")
			var ctx: String = "row %d (%s)" % [r + 1, id]
			rd.snake_id(ctx + " id", id)
			if seen.has(id):
				rd.fail("%s: duplicate id" % ctx)
			seen[id] = true
			var hp_mult: float = rd.number(ctx + " hp_mult", table.get_value(r, "hp_mult"))
			var dmg_mult: float = rd.number(ctx + " dmg_mult", table.get_value(r, "dmg_mult"))
			var speed: float = rd.number(ctx + " speed", table.get_value(r, "speed"))
			var radius: float = rd.number(ctx + " radius", table.get_value(r, "radius"))
			var slots: int = rd.integer(ctx + " slots", table.get_value(r, "slots"))
			var scrap_mult: float = rd.number(ctx + " scrap_mult", table.get_value(r, "scrap_mult"))
			var data_base: float = rd.number(ctx + " data_base", table.get_value(r, "data_base"))
			var weight: float = rd.number(ctx + " spawn_weight", table.get_value(r, "spawn_weight"))
			var first_wave: int = rd.integer(ctx + " first_wave", table.get_value(r, "first_wave"))
			rd.require(hp_mult > 0.0, ctx, "hp_mult must be > 0")
			rd.require(dmg_mult >= 0.0, ctx, "dmg_mult must be >= 0")
			rd.require(speed >= 0.0, ctx, "speed must be >= 0")
			rd.require(radius > 0.0, ctx, "radius must be > 0")
			rd.require(slots >= 1, ctx, "slots must be >= 1")
			rd.require(scrap_mult >= 0.0, ctx, "scrap_mult must be >= 0")
			rd.require(data_base >= 0.0, ctx, "data_base must be >= 0")
			rd.require(weight >= 0.0, ctx, "spawn_weight must be >= 0")
			rd.require(first_wave >= 1, ctx, "first_wave must be >= 1")
			var p: Dictionary = {"id": id}
			p["group"] = rd.text(ctx + " group", table.get_value(r, "group"))
			p["shape"] = rd.text(ctx + " shape", table.get_value(r, "shape"))
			p["hp_mult"] = hp_mult
			p["dmg_mult"] = dmg_mult
			p["speed"] = speed
			p["radius"] = radius
			p["slots"] = slots
			p["scrap_mult"] = scrap_mult
			p["data_base"] = data_base
			p["spawn_weight"] = weight
			p["first_wave"] = first_wave
			p["behavior_id"] = rd.text(ctx + " behavior_id", table.get_value(r, "behavior_id"))
			p["tag"] = rd.text(ctx + " tag", table.get_value(r, "tag"))
			pending[id] = p
			ids.append_array(PackedStringArray([id]))
	errors.append_array(rd.errors)
	if not rd.errors.is_empty():
		return
	var res_paths: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var file_name: String = "enemy_%s.tres" % id
		var props: Dictionary = pending[id]
		files[file_name] = TresWriter.resource_text("EnemyDef", ENEMY_SCRIPT, props)
		res_paths.append_array(PackedStringArray([GEN_RES_DIR + file_name]))
	files["enemy_table.tres"] = TresWriter.table_text("EnemyTable", ENEMY_TABLE_SCRIPT, "defs", ENEMY_SCRIPT, res_paths)


func _build_upgrades(table: CsvTable) -> void:
	if _load_error(table):
		return
	var rd: DataRowReader = DataRowReader.new("run_upgrades.csv")
	var seen: Dictionary = {}
	var ids: PackedStringArray = PackedStringArray()
	var pending: Dictionary = {}
	if rd.check_columns(table, UPGRADE_COLUMNS):
		for r: int in table.rows.size():
			var id: String = table.get_value(r, "id")
			var ctx: String = "row %d (%s)" % [r + 1, id]
			rd.snake_id(ctx + " id", id)
			if seen.has(id):
				rd.fail("%s: duplicate id" % ctx)
			seen[id] = true
			var kind: String = rd.text(ctx + " kind", table.get_value(r, "kind"))
			rd.require(kind == "D" or kind == "C", ctx, "kind must be D or C")
			var l_cap: int = rd.integer(ctx + " l_cap", table.get_value(r, "l_cap"))
			var cap_text: String = table.get_value(r, "hard_cap")
			var hard_cap: float = 0.0
			if not cap_text.is_empty():
				hard_cap = rd.number(ctx + " hard_cap", cap_text)
			var c0: float = rd.number(ctx + " c0", table.get_value(r, "c0"))
			var g: float = rd.number(ctx + " g", table.get_value(r, "g"))
			var gate: int = rd.integer(ctx + " gate_best_wave", table.get_value(r, "gate_best_wave"))
			rd.require(g > 1.0, ctx, "g must be > 1")
			rd.require(l_cap > 0, ctx, "l_cap must be > 0")
			rd.require(c0 >= 0.0, ctx, "c0 must be >= 0")
			rd.require(gate >= 0, ctx, "gate_best_wave must be >= 0")
			var p: Dictionary = {"id": id}
			p["tab"] = rd.text(ctx + " tab", table.get_value(r, "tab"))
			p["kind"] = kind
			p["base"] = rd.number(ctx + " base", table.get_value(r, "base"))
			p["step"] = rd.number(ctx + " step", table.get_value(r, "step"))
			p["l_cap"] = l_cap
			p["has_hard_cap"] = not cap_text.is_empty()
			p["hard_cap"] = hard_cap
			p["c0"] = c0
			p["g"] = g
			p["gate_best_wave"] = gate
			p["tag"] = rd.text(ctx + " tag", table.get_value(r, "tag"))
			pending[id] = p
			ids.append_array(PackedStringArray([id]))
	errors.append_array(rd.errors)
	if not rd.errors.is_empty():
		return
	var res_paths: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var file_name: String = "upgrade_%s.tres" % id
		var props: Dictionary = pending[id]
		files[file_name] = TresWriter.resource_text("RunUpgradeDef", UPGRADE_SCRIPT, props)
		res_paths.append_array(PackedStringArray([GEN_RES_DIR + file_name]))
	files["upgrade_table.tres"] = TresWriter.table_text(
		"UpgradeTable", UPGRADE_TABLE_SCRIPT, "defs", UPGRADE_SCRIPT, res_paths
	)


## strings_en.csv (optional) to strings_en.tres: the CSV is gdignored and not exported, the .tres is.
func _build_strings(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var table: CsvTable = CsvTable.load_file(path)
	if _load_error(table):
		return
	if table.column_index("key") < 0 or table.column_index("text") < 0:
		errors.append_array(PackedStringArray(["strings_en.csv: header must be key,text"]))
		return
	var seen: Dictionary = {}
	var keys: PackedStringArray = PackedStringArray()
	var texts: PackedStringArray = PackedStringArray()
	for r: int in table.rows.size():
		var key: String = table.get_value(r, "key")
		if key.is_empty() or seen.has(key):
			errors.append_array(
				PackedStringArray(["strings_en.csv row %d: empty or duplicate key '%s'" % [r + 1, key]])
			)
			continue
		seen[key] = true
		keys.append(key)
		texts.append(table.get_value(r, "text"))
	if not errors.is_empty():
		return
	var out: String = '[gd_resource type="Resource" script_class="StringTable" format=3]\n\n'
	out += '[ext_resource type="Script" path="%s" id="1_script"]\n\n' % STRING_TABLE_SCRIPT
	out += '[resource]\nscript = ExtResource("1_script")\n'
	out += "keys = PackedStringArray(%s)\n" % _quoted_list(keys)
	out += "texts = PackedStringArray(%s)\n" % _quoted_list(texts)
	files["strings_en.tres"] = out


func _quoted_list(values: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for v: String in values:
		parts.append(TresWriter.fmt_string(v))
	return ", ".join(parts)


func _write_all(out_dir: String) -> bool:
	var err: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	if err != OK:
		errors.append_array(PackedStringArray(["cannot create %s (error %d)" % [out_dir, err]]))
		return false
	_remove_stale(out_dir)
	var names: Array = files.keys()
	names.sort()
	for n: String in names:
		var f: FileAccess = FileAccess.open(out_dir.path_join(n), FileAccess.WRITE)
		if f == null:
			errors.append_array(PackedStringArray(["cannot write %s" % out_dir.path_join(n)]))
			return false
		var content: String = files[n]
		f.store_string(content)
		f.close()
	return true


## Deletes generated files that no longer correspond to a CSV row (renamed or removed ids).
func _remove_stale(out_dir: String) -> void:
	var dir: DirAccess = DirAccess.open(out_dir)
	if dir == null:
		return
	for n: String in dir.get_files():
		var ours: bool = (
			n == "sim_tuning.tres" or n == "strings_en.tres" or n.begins_with("enemy_") or n.begins_with("upgrade_")
		)
		if ours and n.ends_with(".tres") and not files.has(n):
			var rm: Error = dir.remove(n)
			if rm != OK:
				errors.append_array(PackedStringArray(["cannot remove stale %s" % n]))
