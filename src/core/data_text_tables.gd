class_name DataTextTables
extends RefCounted
## Importer helpers (split from DataImporter for the file-size cap): the text tables that must ship as
## generated resources because `data/` is `.gdignore`d and never exported. Each builder returns
## `{"text": String, "errors": PackedStringArray}`; a missing CSV gives empty text and no errors.

const STRING_TABLE_SCRIPT: String = "res://src/data_defs/string_table.gd"
const SUFFIX_TABLE_SCRIPT: String = "res://src/data_defs/number_suffix_table.gd"


## strings_en.csv (key,text) to the StringTable resource text.
static func strings(path: String) -> Dictionary:
	var out: Dictionary = {"text": "", "errors": PackedStringArray()}
	var table: CsvTable = _load(path, out)
	if table == null:
		return out
	if table.column_index("key") < 0 or table.column_index("text") < 0:
		_fail(out, "strings_en.csv: header must be key,text")
		return out
	var seen: Dictionary = {}
	var keys: PackedStringArray = PackedStringArray()
	var texts: PackedStringArray = PackedStringArray()
	for r: int in table.rows.size():
		var key: String = table.get_value(r, "key")
		if key.is_empty() or seen.has(key):
			_fail(out, "strings_en.csv row %d: empty or duplicate key '%s'" % [r + 1, key])
			continue
		seen[key] = true
		keys.append(key)
		texts.append(table.get_value(r, "text"))
	if _ok(out):
		var body: String = "keys = PackedStringArray(%s)\n" % _quoted_list(keys)
		body += "texts = PackedStringArray(%s)\n" % _quoted_list(texts)
		out["text"] = _resource("StringTable", STRING_TABLE_SCRIPT, body)
	return out


## number_suffixes.csv (exp,suffix) to the NumberSuffixTable resource text.
static func suffixes(path: String) -> Dictionary:
	var out: Dictionary = {"text": "", "errors": PackedStringArray()}
	var table: CsvTable = _load(path, out)
	if table == null:
		return out
	if table.column_index("exp") < 0 or table.column_index("suffix") < 0:
		_fail(out, "number_suffixes.csv: header must be exp,suffix")
		return out
	var exps: PackedStringArray = PackedStringArray()
	var names: PackedStringArray = PackedStringArray()
	var last: int = 0
	for r: int in table.rows.size():
		var exp_text: String = table.get_value(r, "exp")
		var suffix: String = table.get_value(r, "suffix")
		if not exp_text.is_valid_int() or suffix.is_empty() or exp_text.to_int() <= last:
			_fail(out, "number_suffixes.csv row %d: need an ascending integer exp and a non-empty suffix" % (r + 1))
			continue
		last = exp_text.to_int()
		exps.append(exp_text)
		names.append(suffix)
	if _ok(out):
		var body: String = "exps = PackedInt32Array(%s)\n" % ", ".join(exps)
		body += "suffixes = PackedStringArray(%s)\n" % _quoted_list(names)
		out["text"] = _resource("NumberSuffixTable", SUFFIX_TABLE_SCRIPT, body)
	return out


static func _load(path: String, out: Dictionary) -> CsvTable:
	if not FileAccess.file_exists(path):
		return null
	var table: CsvTable = CsvTable.load_file(path)
	if not table.error.is_empty():
		_fail(out, table.error)
		return null
	return table


static func _ok(out: Dictionary) -> bool:
	var errs: PackedStringArray = out["errors"]
	return errs.is_empty()


static func _fail(out: Dictionary, message: String) -> void:
	var errs: PackedStringArray = out["errors"]
	errs.append(message)
	out["errors"] = errs


static func _resource(script_class: String, script_path: String, body: String) -> String:
	var text: String = '[gd_resource type="Resource" script_class="%s" format=3]\n\n' % script_class
	text += '[ext_resource type="Script" path="%s" id="1_script"]\n\n' % script_path
	text += '[resource]\nscript = ExtResource("1_script")\n'
	return text + body


static func _quoted_list(values: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for v: String in values:
		parts.append(TresWriter.fmt_string(v))
	return ", ".join(parts)
