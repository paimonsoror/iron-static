class_name CsvTable
extends RefCounted
## Small CSV reader for data/*.csv: header row, comma separated, `"` quoting (with `""` escape,
## embedded commas and newlines), `#` comment lines, blank lines skipped, UTF-8 (a BOM is tolerated).
## Unquoted fields are trimmed; quoted fields are kept verbatim.
## Parse problems never throw: check `error` (empty when the table is valid).

var path: String = ""
var headers: PackedStringArray = PackedStringArray()
var rows: Array[PackedStringArray] = []
var error: String = ""


## Reads and parses a file (res://, user:// or absolute). A missing file sets `error`.
static func load_file(file_path: String) -> CsvTable:
	if not FileAccess.file_exists(file_path):
		var missing: CsvTable = CsvTable.new()
		missing.path = file_path
		missing.error = "%s: file not found" % file_path
		return missing
	return parse(FileAccess.get_file_as_string(file_path), file_path)


## Parses CSV text. `source_name` is only used in error messages.
static func parse(text: String, source_name: String = "<text>") -> CsvTable:
	var table: CsvTable = CsvTable.new()
	table.path = source_name
	var records: Array[PackedStringArray] = []
	var line_numbers: PackedInt32Array = PackedInt32Array()
	var problem: String = _tokenize(text, records, line_numbers)
	if not problem.is_empty():
		table.error = "%s: %s" % [source_name, problem]
		return table
	if records.is_empty():
		table.error = "%s: no header row" % source_name
		return table
	table.headers = records[0]
	for h: String in table.headers:
		if h.is_empty():
			table.error = "%s: empty column name in header (line %d)" % [source_name, line_numbers[0]]
			return table
	for i: int in range(1, records.size()):
		var rec: PackedStringArray = records[i]
		if rec.size() != table.headers.size():
			table.error = (
				"%s: line %d has %d fields, header has %d"
				% [source_name, line_numbers[i], rec.size(), table.headers.size()]
			)
			return table
		table.rows.append(rec)
	return table


func column_index(column_name: String) -> int:
	return headers.find(column_name)


func has_column(column_name: String) -> bool:
	return headers.find(column_name) >= 0


## Value of a column in a row, or "" when the column or row does not exist.
func get_value(row_index: int, column_name: String) -> String:
	var c: int = headers.find(column_name)
	if c < 0 or row_index < 0 or row_index >= rows.size():
		return ""
	return rows[row_index][c]


## Splits text into records. Returns an error message or "". Fills `out` and 1-based start lines.
static func _tokenize(text: String, out: Array[PackedStringArray], lines: PackedInt32Array) -> String:
	# Compare the code point: a literal U+FEFF in a string is dropped by Godot's binary script
	# tokenization on export, which made this test always true on Android (first char eaten).
	if not text.is_empty() and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var fields: PackedStringArray = PackedStringArray()
	var field: String = ""
	var quoted: bool = false  # current field was quoted
	var in_quotes: bool = false
	var started: bool = false  # current record has content
	var line: int = 1
	var record_line: int = 1
	var i: int = 0
	var n: int = text.length()
	while i < n:
		var ch: String = text[i]
		i += 1
		if in_quotes:
			if ch == '"':
				if i < n and text[i] == '"':
					field += '"'
					i += 1
				else:
					in_quotes = false
			else:
				if ch == "\n":
					line += 1
				field += ch
			continue
		if ch == "\r":
			continue
		if ch == "\n" or ch == ",":
			if ch == "," or started:
				if not started:
					record_line = line
				fields.append_array(PackedStringArray([field if quoted else field.strip_edges()]))
				started = true
			if ch == "\n":
				if started:
					out.append(fields)
					lines.append_array(PackedInt32Array([record_line]))
				fields = PackedStringArray()
				started = false
				line += 1
			field = ""
			quoted = false
			continue
		if ch == " " or ch == "\t":
			if quoted:
				continue  # padding after a closing quote
			if not started and field.is_empty():
				continue  # leading blanks (or a blank line)
		elif ch == "#" and not started and field.is_empty():
			while i < n and text[i] != "\n":
				i += 1
			continue  # comment line; the newline is handled by the next iteration
		if not started:
			started = true
			record_line = line
		if ch == '"' and field.is_empty() and not quoted:
			in_quotes = true
			quoted = true
			continue
		if quoted:
			return "line %d: text after closing quote" % line
		field += ch
	if in_quotes:
		return "line %d: unterminated quoted field" % record_line
	if started:
		fields.append_array(PackedStringArray([field if quoted else field.strip_edges()]))
		out.append(fields)
		lines.append_array(PackedInt32Array([record_line]))
	return ""
