class_name TestCsvTable
extends GdUnitTestSuite
## CsvTable: header row, quoting, comments, blank lines, error reporting.


func test_basic_table() -> void:
	var t: CsvTable = CsvTable.parse("id,value\nalpha,1\nbeta,2\n")
	assert_str(t.error).is_empty()
	assert_int(t.rows.size()).is_equal(2)
	assert_str(t.headers[1]).is_equal("value")
	assert_str(t.get_value(1, "id")).is_equal("beta")
	assert_int(t.column_index("value")).is_equal(1)
	assert_bool(t.has_column("nope")).is_false()
	assert_str(t.get_value(0, "nope")).is_empty()


func test_comments_and_blank_lines_are_skipped() -> void:
	var t: CsvTable = CsvTable.parse("# leading comment\n\nid,value\n# mid comment\n   \na,1\n\n#tail\nb,2")
	assert_str(t.error).is_empty()
	assert_int(t.rows.size()).is_equal(2)
	assert_str(t.get_value(1, "value")).is_equal("2")


func test_quoted_fields() -> void:
	var text: String = 'id,note\nx,"has, comma"\ny,"say ""hi"""\nz,"two\nlines"\nw,"# not a comment"\n'
	var t: CsvTable = CsvTable.parse(text)
	assert_str(t.error).is_empty()
	assert_int(t.rows.size()).is_equal(4)
	assert_str(t.get_value(0, "note")).is_equal("has, comma")
	assert_str(t.get_value(1, "note")).is_equal('say "hi"')
	assert_str(t.get_value(2, "note")).is_equal("two\nlines")
	assert_str(t.get_value(3, "note")).is_equal("# not a comment")


func test_crlf_bom_and_trailing_blank_fields() -> void:
	var t: CsvTable = CsvTable.parse(String.chr(0xFEFF) + "a,b,c\r\n1,,3\r\n,,\r\n")
	assert_str(t.error).is_empty()
	assert_int(t.rows.size()).is_equal(2)
	assert_str(t.get_value(0, "b")).is_empty()
	assert_str(t.get_value(0, "c")).is_equal("3")
	assert_int(t.rows[1].size()).is_equal(3)


func test_unquoted_fields_are_trimmed_and_quoted_kept() -> void:
	var t: CsvTable = CsvTable.parse('a,b\n  x  ,"  y  "\n')
	assert_str(t.get_value(0, "a")).is_equal("x")
	assert_str(t.get_value(0, "b")).is_equal("  y  ")


func test_wrong_field_count_is_an_error_with_line_number() -> void:
	var t: CsvTable = CsvTable.parse("a,b\n1,2\n3\n", "t.csv")
	assert_str(t.error).contains("t.csv")
	assert_str(t.error).contains("line 3")


func test_unterminated_quote_and_text_after_quote() -> void:
	assert_str(CsvTable.parse('a\n"oops\n').error).contains("unterminated")
	assert_str(CsvTable.parse('a,b\n"x"y,2\n').error).contains("after closing quote")


func test_empty_text_has_no_header() -> void:
	assert_str(CsvTable.parse("# only a comment\n").error).contains("no header")
	assert_str(CsvTable.parse("").error).contains("no header")


func test_missing_file_reports_error() -> void:
	var t: CsvTable = CsvTable.load_file("res://data/does_not_exist.csv")
	assert_str(t.error).contains("not found")


func test_load_real_enemies_file() -> void:
	var t: CsvTable = CsvTable.load_file("res://data/enemies.csv")
	assert_str(t.error).is_empty()
	assert_int(t.rows.size()).is_equal(5)
