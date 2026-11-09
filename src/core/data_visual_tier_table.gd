class_name DataVisualTierTable
extends RefCounted
## Importer helper for data/visual_tiers.csv (VT-1), split out of DataImporter for the file-size cap.
## Returns `{"files": Dictionary, "errors": PackedStringArray}`; a missing CSV gives no files and no errors.
## Every message names the row, e.g. `visual_tiers.csv: row 3 (laser_2): thresholds must increase`.

const DEF_SCRIPT: String = "res://src/data_defs/visual_tier_def.gd"
const TABLE_SCRIPT: String = "res://src/data_defs/visual_tier_table.gd"
const COLUMNS: PackedStringArray = [
	"id",
	"upgrade",
	"tier",
	"mark",
	"threshold_kind",
	"threshold",
	"label_key",
	"banner_key",
	"art_slot",
	"params",
]
const TIERS_PER_UPGRADE: int = 4


## `upgrades` = Dictionary keyed by the ids of run_upgrades.csv; string keys are read from `data_dir`/strings_en.csv.
static func visual_tiers(path: String, upgrades: Dictionary, data_dir: String) -> Dictionary:
	var out: Dictionary = {"files": {}, "errors": PackedStringArray()}
	if not FileAccess.file_exists(path):
		return out
	var table: CsvTable = CsvTable.load_file(path)
	var errs: PackedStringArray = PackedStringArray()
	if not table.error.is_empty():
		errs.append(table.error)
		out["errors"] = errs
		return out
	var rd: DataRowReader = DataRowReader.new("visual_tiers.csv")
	var seen: Dictionary = {}
	var ids: PackedStringArray = PackedStringArray()
	var pending: Dictionary = {}
	var last: Dictionary = {}  # upgrade -> {tier, threshold} of the previous row
	var string_keys: Dictionary = _string_keys(data_dir)
	if rd.check_columns(table, COLUMNS):
		for r: int in table.rows.size():
			var id: String = table.get_value(r, "id")
			var ctx: String = "row %d (%s)" % [r + 1, id]
			rd.snake_id(ctx + " id", id)
			if seen.has(id):
				rd.fail("%s: duplicate id" % ctx)
			seen[id] = true
			var p: Dictionary = _row(rd, table, r, ctx, upgrades, string_keys)
			_order(rd, ctx, p, last)
			pending[id] = p
			ids.append(id)
		_counts(rd, last)
	errs.append_array(rd.errors)
	out["errors"] = errs
	if errs.is_empty():
		_emit(out, ids, pending)
	return out


static func _row(
	rd: DataRowReader, table: CsvTable, r: int, ctx: String, upgrades: Dictionary, string_keys: Dictionary
) -> Dictionary:
	var p: Dictionary = {"id": table.get_value(r, "id")}
	var upgrade: String = rd.text(ctx + " upgrade", table.get_value(r, "upgrade"))
	rd.require(upgrades.has(upgrade), ctx, "unknown upgrade '%s' (no row in run_upgrades.csv)" % upgrade)
	p["upgrade"] = upgrade
	var tier: int = rd.integer(ctx + " tier", table.get_value(r, "tier"))
	rd.require(tier >= 1 and tier <= TIERS_PER_UPGRADE, ctx, "tier must be 1 to %d" % TIERS_PER_UPGRADE)
	p["tier"] = tier
	p["mark"] = rd.text(ctx + " mark", table.get_value(r, "mark"))
	var kind: String = table.get_value(r, "threshold_kind")
	rd.require(kind == "level", ctx, "threshold_kind must be level (cap_frac is not supported yet)")
	p["threshold_kind"] = kind
	var threshold: int = rd.integer(ctx + " threshold", table.get_value(r, "threshold"))
	rd.require(threshold >= 0, ctx, "threshold must be >= 0")
	p["threshold"] = threshold
	var label_key: String = rd.text(ctx + " label_key", table.get_value(r, "label_key"))
	rd.require(label_key.is_empty() or string_keys.has(label_key), ctx, "unknown label_key '%s'" % label_key)
	p["label_key"] = label_key
	var banner_key: String = table.get_value(r, "banner_key")
	rd.require(banner_key.is_empty() or string_keys.has(banner_key), ctx, "unknown banner_key '%s'" % banner_key)
	p["banner_key"] = banner_key
	p["art_slot"] = rd.text(ctx + " art_slot", table.get_value(r, "art_slot"))
	var params: String = table.get_value(r, "params")
	_check_params(rd, ctx, params)
	p["params"] = params
	return p


static func _check_params(rd: DataRowReader, ctx: String, params: String) -> void:
	for kv: String in params.split(";", false):
		var pair: PackedStringArray = kv.split("=")
		var ok: bool = pair.size() == 2 and not pair[0].is_empty() and pair[1].is_valid_float()
		rd.require(ok, ctx, "params entry '%s' is not key=number" % kv)


## Tiers of one upgrade must run 1, 2, 3, 4 in row order with strictly increasing thresholds.
static func _order(rd: DataRowReader, ctx: String, p: Dictionary, last: Dictionary) -> void:
	var upgrade: String = p["upgrade"]
	var tier: int = p["tier"]
	var threshold: int = p["threshold"]
	var prev_tier: int = 0
	var prev_threshold: int = -1
	if last.has(upgrade):
		var prev: Dictionary = last[upgrade]
		prev_tier = prev["tier"]
		prev_threshold = prev["threshold"]
	rd.require(tier == prev_tier + 1, ctx, "tier %d does not follow tier %d of %s" % [tier, prev_tier, upgrade])
	rd.require(threshold > prev_threshold, ctx, "thresholds must increase (%d after %d)" % [threshold, prev_threshold])
	last[upgrade] = {"tier": tier, "threshold": threshold}


static func _counts(rd: DataRowReader, last: Dictionary) -> void:
	for upgrade: String in last:
		var prev: Dictionary = last[upgrade]
		var tier: int = prev["tier"]
		rd.require(tier == TIERS_PER_UPGRADE, upgrade, "needs %d tiers, has %d" % [TIERS_PER_UPGRADE, tier])


static func _emit(out: Dictionary, ids: PackedStringArray, pending: Dictionary) -> void:
	var files: Dictionary = {}
	var res_paths: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var file_name: String = "visual_tier_%s.tres" % id
		var props: Dictionary = pending[id]
		files[file_name] = TresWriter.resource_text("VisualTierDef", DEF_SCRIPT, props)
		res_paths.append(DataMetaTables.GEN_RES_DIR + file_name)
	files["visual_tier_table.tres"] = TresWriter.table_text(
		"VisualTierTable", TABLE_SCRIPT, "defs", DEF_SCRIPT, res_paths
	)
	out["files"] = files


static func _string_keys(data_dir: String) -> Dictionary:
	var keys: Dictionary = {}
	var strings: CsvTable = CsvTable.load_file(data_dir.path_join("strings_en.csv"))
	for r: int in strings.rows.size():
		keys[strings.get_value(r, "key")] = true
	return keys
