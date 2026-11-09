class_name DataMetaTables
extends RefCounted
## Importer helpers (split from DataImporter for the file-size cap): the meta tables foundry.csv (M3-05)
## and frames.csv (M3-21). Each builder returns `{"files": Dictionary, "errors": PackedStringArray}`;
## a missing CSV gives no files and no errors (like the text tables).

const FOUNDRY_SCRIPT: String = "res://src/data_defs/foundry_def.gd"
const FOUNDRY_TABLE_SCRIPT: String = "res://src/data_defs/foundry_table.gd"
const FRAME_SCRIPT: String = "res://src/data_defs/frame_def.gd"
const FRAME_TABLE_SCRIPT: String = "res://src/data_defs/frame_table.gd"
const WAVE_MODE_SCRIPT: String = "res://src/data_defs/wave_mode_def.gd"
const WAVE_MODE_TABLE_SCRIPT: String = "res://src/data_defs/wave_mode_table.gd"
const WAVE_MODE_COLUMNS: PackedStringArray = [
	"id",
	"implemented",
	"unlock_best_timed_wave",
	"backstop_s",
	"reward_mult",
	"sort",
	"source",
	"note",
]
const GEN_RES_DIR: String = "res://src/data_gen/"
const FOUNDRY_COLUMNS: PackedStringArray = ["id", "kind", "f", "f_cap", "fc0", "fg", "tag"]
const FRAME_COLUMNS: PackedStringArray = [
	"id",
	"name_key",
	"role_key",
	"passive_key",
	"unlock_best_wave",
	"implemented",
	"hull_mult",
	"plating_add",
	"nano_mult",
	"cycle_mult",
	"optic_mult",
	"laser_mult",
	"crit_add",
	"crit_mult_mult",
	"scrap_mult",
	"data_mult",
	"passive",
	"bastion_cap_frac",
	"overclock_per_kill",
	"overclock_cap",
	"tag",
]  # gdlint: ignore=max-line-length
## Numeric frame columns with their neutral value (multipliers 1.0, adds 0.0).
const FRAME_NUMBERS: Dictionary = {
	"hull_mult": 1.0,
	"plating_add": 0.0,
	"nano_mult": 1.0,
	"cycle_mult": 1.0,
	"optic_mult": 1.0,
	"laser_mult": 1.0,
	"crit_add": 0.0,
	"crit_mult_mult": 1.0,
	"scrap_mult": 1.0,
	"data_mult": 1.0,
}
const PASSIVES: PackedStringArray = ["none", "bastion", "overclock", "scrap_tithe", "first_sight"]
## Passives the sim implements in M3 (an `implemented` frame may only use these).
const SIM_PASSIVES: PackedStringArray = ["none", "bastion", "overclock"]


## foundry.csv to FoundryDef files plus FoundryTable. `upgrade_kinds` maps run upgrade id to its kind.
static func foundry(path: String, upgrade_kinds: Dictionary) -> Dictionary:
	var out: Dictionary = {"files": {}, "errors": PackedStringArray()}
	var table: CsvTable = _load(path, out)
	if table == null:
		return out
	var rd: DataRowReader = DataRowReader.new("foundry.csv")
	var seen: Dictionary = {}
	var ids: PackedStringArray = PackedStringArray()
	var pending: Dictionary = {}
	if rd.check_columns(table, FOUNDRY_COLUMNS):
		for r: int in table.rows.size():
			var id: String = table.get_value(r, "id")
			var ctx: String = "row %d (%s)" % [r + 1, id]
			rd.snake_id(ctx + " id", id)
			if seen.has(id):
				rd.fail("%s: duplicate id" % ctx)
			seen[id] = true
			var kind: String = rd.text(ctx + " kind", table.get_value(r, "kind"))
			rd.require(kind == "D" or kind == "C", ctx, "kind must be D or C")
			if not upgrade_kinds.has(id):
				rd.fail("%s: unknown id (no row in run_upgrades.csv)" % ctx)
			else:
				var run_kind: String = upgrade_kinds[id]
				rd.require(run_kind == kind, ctx, "kind differs from run_upgrades.csv")
			var f_text: String = table.get_value(r, "f")
			var f: float = 0.0
			if kind == "D":
				f = rd.number(ctx + " f", f_text)
				rd.require(f > 0.0, ctx, "f must be > 0 for kind D")
			else:
				rd.require(f_text.is_empty(), ctx, "f must be empty for kind C")
			var f_cap: int = rd.integer(ctx + " f_cap", table.get_value(r, "f_cap"))
			var fc0: float = rd.number(ctx + " fc0", table.get_value(r, "fc0"))
			var fg: float = rd.number(ctx + " fg", table.get_value(r, "fg"))
			rd.require(f_cap > 0, ctx, "f_cap must be > 0")
			rd.require(fc0 > 0.0, ctx, "fc0 must be > 0")
			rd.require(fg > 1.0, ctx, "fg must be > 1")
			var p: Dictionary = {"id": id, "kind": kind, "f": f, "f_cap": f_cap, "fc0": fc0, "fg": fg}
			p["tag"] = rd.text(ctx + " tag", table.get_value(r, "tag"))
			pending[id] = p
			ids.append(id)
	_collect(out, rd)
	if _ok(out):
		_emit(out, "foundry", "FoundryDef", FOUNDRY_SCRIPT, "FoundryTable", FOUNDRY_TABLE_SCRIPT, ids, pending)
	return out


## frames.csv to FrameDef files plus FrameTable.
static func frames(path: String) -> Dictionary:
	var out: Dictionary = {"files": {}, "errors": PackedStringArray()}
	var table: CsvTable = _load(path, out)
	if table == null:
		return out
	var rd: DataRowReader = DataRowReader.new("frames.csv")
	var seen: Dictionary = {}
	var ids: PackedStringArray = PackedStringArray()
	var pending: Dictionary = {}
	if rd.check_columns(table, FRAME_COLUMNS):
		for r: int in table.rows.size():
			var id: String = table.get_value(r, "id")
			var ctx: String = "row %d (%s)" % [r + 1, id]
			rd.snake_id(ctx + " id", id)
			if seen.has(id):
				rd.fail("%s: duplicate id" % ctx)
			seen[id] = true
			var p: Dictionary = _frame_row(rd, table, r, ctx)
			pending[id] = p
			ids.append(id)
	_collect(out, rd)
	if _ok(out):
		_emit(out, "frame", "FrameDef", FRAME_SCRIPT, "FrameTable", FRAME_TABLE_SCRIPT, ids, pending)
	return out


static func _frame_row(rd: DataRowReader, table: CsvTable, r: int, ctx: String) -> Dictionary:
	var p: Dictionary = {"id": table.get_value(r, "id")}
	for col: String in ["name_key", "role_key", "passive_key"]:
		p[col] = rd.text("%s %s" % [ctx, col], table.get_value(r, col))
	var unlock: int = rd.integer(ctx + " unlock_best_wave", table.get_value(r, "unlock_best_wave"))
	rd.require(unlock >= 0, ctx, "unlock_best_wave must be >= 0")
	p["unlock_best_wave"] = unlock
	var impl_text: String = table.get_value(r, "implemented")
	rd.require(impl_text == "true" or impl_text == "false", ctx, "implemented must be true or false")
	var implemented: bool = impl_text == "true"
	p["implemented"] = implemented
	var neutral: bool = true
	for col: String in FRAME_NUMBERS:
		var v: float = rd.number("%s %s" % [ctx, col], table.get_value(r, col))
		if col.ends_with("_mult"):
			rd.require(v > 0.0, ctx, "%s must be > 0" % col)
		p[col] = v
		var neutral_value: float = FRAME_NUMBERS[col]
		neutral = neutral and is_equal_approx(v, neutral_value)
	var passive: String = rd.text(ctx + " passive", table.get_value(r, "passive"))
	rd.require(PASSIVES.has(passive), ctx, "unknown passive '%s'" % passive)
	if implemented:
		rd.require(SIM_PASSIVES.has(passive), ctx, "implemented row uses passive '%s' the sim does not know" % passive)
	p["passive"] = passive
	var bastion: float = rd.number(ctx + " bastion_cap_frac", table.get_value(r, "bastion_cap_frac"))
	var per_kill: float = rd.number(ctx + " overclock_per_kill", table.get_value(r, "overclock_per_kill"))
	var oc_cap: float = rd.number(ctx + " overclock_cap", table.get_value(r, "overclock_cap"))
	rd.require(bastion > 0.0 and bastion <= 1.0, ctx, "bastion_cap_frac must be in (0, 1]")
	rd.require(per_kill > 0.0 and per_kill <= 1.0, ctx, "overclock_per_kill must be in (0, 1]")
	rd.require(oc_cap > 0.0 and oc_cap <= 10.0, ctx, "overclock_cap must be in (0, 10]")
	p["bastion_cap_frac"] = bastion
	p["overclock_per_kill"] = per_kill
	p["overclock_cap"] = oc_cap
	if p["id"] == "vanguard":
		var ok: bool = neutral and passive == "none" and unlock == 0 and implemented
		rd.require(ok, ctx, "vanguard must be neutral (all x1.0 / +0, passive none, unlock 0, implemented)")
	p["tag"] = rd.text(ctx + " tag", table.get_value(r, "tag"))
	return p


## wave_modes.csv to WaveModeDef files plus WaveModeTable (M4-01).
static func wave_modes(path: String) -> Dictionary:
	var out: Dictionary = {"files": {}, "errors": PackedStringArray()}
	var table: CsvTable = _load(path, out)
	if table == null:
		return out
	var rd: DataRowReader = DataRowReader.new("wave_modes.csv")
	var seen: Dictionary = {}
	var sorts: Dictionary = {}
	var ids: PackedStringArray = PackedStringArray()
	var pending: Dictionary = {}
	if rd.check_columns(table, WAVE_MODE_COLUMNS):
		for r: int in table.rows.size():
			var id: String = table.get_value(r, "id")
			var ctx: String = "row %d (%s)" % [r + 1, id]
			rd.snake_id(ctx + " id", id)
			if seen.has(id):
				rd.fail("%s: duplicate id" % ctx)
			seen[id] = true
			var p: Dictionary = _wave_mode_row(rd, table, r, ctx)
			var sort: int = p["sort"]
			if sorts.has(sort):
				rd.fail("%s: duplicate sort %d" % [ctx, sort])
			sorts[sort] = true
			pending[id] = p
			ids.append(id)
		rd.require(seen.has("timed"), "timed", "row 'timed' is missing")
	_collect(out, rd)
	if _ok(out):
		_emit(out, "wave_mode", "WaveModeDef", WAVE_MODE_SCRIPT, "WaveModeTable", WAVE_MODE_TABLE_SCRIPT, ids, pending)
	return out


static func _wave_mode_row(rd: DataRowReader, table: CsvTable, r: int, ctx: String) -> Dictionary:
	var id: String = table.get_value(r, "id")
	var p: Dictionary = {"id": id}
	var impl_text: String = table.get_value(r, "implemented")
	rd.require(impl_text == "1" or impl_text == "0", ctx, "implemented must be 1 or 0")
	var implemented: bool = impl_text == "1"
	p["implemented"] = implemented
	var unlock: int = rd.integer(ctx + " unlock_best_timed_wave", table.get_value(r, "unlock_best_timed_wave"))
	rd.require(unlock >= 0, ctx, "unlock_best_timed_wave must be >= 0")
	p["unlock_best_timed_wave"] = unlock
	var backstop: float = rd.number(ctx + " backstop_s", table.get_value(r, "backstop_s"))
	rd.require(backstop >= 0.0, ctx, "backstop_s must be >= 0")
	if id != "timed" and implemented:
		rd.require(backstop > 0.0, ctx, "backstop_s must be > 0 for a non-timed implemented mode")
	p["backstop_s"] = backstop
	var mult: float = rd.number(ctx + " reward_mult", table.get_value(r, "reward_mult"))
	rd.require(mult > 0.0, ctx, "reward_mult must be > 0")
	p["reward_mult"] = mult
	p["sort"] = rd.integer(ctx + " sort", table.get_value(r, "sort"))
	if id == "timed":
		rd.require(unlock == 0 and implemented, ctx, "timed must be implemented and unlocked at 0")
	return p


## Writes one `<prefix>_<id>.tres` per row plus `<prefix>_table.tres` into out["files"].
static func _emit(
	out: Dictionary,
	prefix: String,
	item_class: String,
	item_script: String,
	table_class: String,
	table_script: String,
	ids: PackedStringArray,
	pending: Dictionary
) -> void:
	var files: Dictionary = out["files"]
	var res_paths: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var file_name: String = "%s_%s.tres" % [prefix, id]
		var props: Dictionary = pending[id]
		files[file_name] = TresWriter.resource_text(item_class, item_script, props)
		res_paths.append(GEN_RES_DIR + file_name)
	files["%s_table.tres" % prefix] = TresWriter.table_text(table_class, table_script, "defs", item_script, res_paths)
	out["files"] = files


static func _load(path: String, out: Dictionary) -> CsvTable:
	if not FileAccess.file_exists(path):
		return null
	var table: CsvTable = CsvTable.load_file(path)
	if not table.error.is_empty():
		_fail(out, table.error)
		return null
	return table


static func _collect(out: Dictionary, rd: DataRowReader) -> void:
	var errs: PackedStringArray = out["errors"]
	errs.append_array(rd.errors)
	out["errors"] = errs


static func _ok(out: Dictionary) -> bool:
	var errs: PackedStringArray = out["errors"]
	return errs.is_empty()


static func _fail(out: Dictionary, message: String) -> void:
	var errs: PackedStringArray = out["errors"]
	errs.append(message)
	out["errors"] = errs
