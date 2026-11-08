class_name DataRowReader
extends RefCounted
## Validation helpers for one CSV table: collects human-readable errors (never throws) and converts
## cell text to typed values. Used by DataImporter.

var table_name: String = ""
var errors: PackedStringArray = PackedStringArray()


func _init(name_text: String) -> void:
	table_name = name_text


func fail(message: String) -> void:
	errors.append_array(PackedStringArray(["%s: %s" % [table_name, message]]))


## Checks the header: every expected column present, no unknown column. Returns true when it matches.
func check_columns(table: CsvTable, expected: PackedStringArray) -> bool:
	var ok: bool = true
	for h: String in table.headers:
		if not expected.has(h):
			fail("unknown column '%s'" % h)
			ok = false
	for c: String in expected:
		if not table.has_column(c):
			fail("missing column '%s'" % c)
			ok = false
	return ok


## Required text cell (must be non-empty).
func text(ctx: String, value: String) -> String:
	if value.is_empty():
		fail("%s: missing required value" % ctx)
	return value


func snake_id(ctx: String, value: String) -> String:
	if value.is_empty():
		fail("%s: missing required value" % ctx)
	elif not _is_snake(value):
		fail("%s: id '%s' is not snake_case" % [ctx, value])
	return value


func number(ctx: String, value: String) -> float:
	if value.is_empty():
		fail("%s: missing required value" % ctx)
		return 0.0
	if not value.is_valid_float():
		fail("%s: '%s' is not a number" % [ctx, value])
		return 0.0
	var v: float = value.to_float()
	if is_nan(v) or is_inf(v):
		fail("%s: '%s' is not a finite number" % [ctx, value])
		return 0.0
	return v


func integer(ctx: String, value: String) -> int:
	if value.is_empty():
		fail("%s: missing required value" % ctx)
		return 0
	if not value.is_valid_int():
		fail("%s: '%s' is not an integer" % [ctx, value])
		return 0
	return value.to_int()


## Records an error when `condition` is false.
func require(condition: bool, ctx: String, message: String) -> void:
	if not condition:
		fail("%s: %s" % [ctx, message])


static func _is_snake(value: String) -> bool:
	var first: int = value.unicode_at(0)
	if first < 97 or first > 122:
		return false
	for i: int in value.length():
		var c: int = value.unicode_at(i)
		var ok: bool = (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95
		if not ok:
			return false
	return true
