class_name TestNumberFormat
extends GdUnitTestSuite
## NumberFormat: GDD 04_economy section 5 table, styles, percent, mult, time, suffix table.


func _fmt(text: String, style: int = NumberFormat.SHORT) -> String:
	return NumberFormat.format(BigNum.parse(text), style)


func test_short_table() -> void:
	var rows: Array = [
		["847", "847"],
		["999", "999"],
		["1000", "1K"],
		["1234", "1.23K"],
		["12400", "12.4K"],
		["15000", "15K"],
		["847000", "847K"],
		["999999", "999K"],
		["1e6", "1M"],
		["1e12", "1T"],
		["1e33", "1Dc"],
		["1.5e35", "150Dc"],
		["1e36", "1e36"],
		["1.23456e45", "1.23e45"],
		["0", "0"],
		["999.9", "999"],
		["1.5", "1"],
		["0.4", "0"],
		["1999", "1.99K"],
		["1.0e9", "1B"],
		["9.99999e32", "999No"],
		["1.5e3", "1.5K"],
		["10000", "10K"],
		["1100", "1.1K"],
		["1e15", "1Qa"],
	]
	for row: Array in rows:
		var input: String = row[0]
		var expected: String = row[1]
		assert_str(_fmt(input)).override_failure_message("input %s" % input).is_equal(expected)


func test_short_floor_not_round_over_many_values() -> void:
	# floor(n) for integers 1000..99999 must equal the first 3 significant digits truncated.
	var bad: int = 0
	for n: int in range(1000, 100000, 7):
		var text: String = NumberFormat.format(BigNum.from_int(n))
		var digits: String = str(n)
		var lead: int = digits.length() % 3
		if lead == 0:
			lead = 3
		var head: String = digits.substr(0, lead)
		var tail: String = digits.substr(lead, 3 - lead)
		var expected: String = head
		if not tail.is_empty() and tail.rstrip("0") != "":
			expected = head + "." + tail.rstrip("0")
		expected += "K"
		if text != expected:
			bad += 1
	assert_int(bad).is_equal(0)


func test_scientific_style() -> void:
	assert_str(_fmt("1000", NumberFormat.SCIENTIFIC)).is_equal("1e3")
	assert_str(_fmt("12345", NumberFormat.SCIENTIFIC)).is_equal("1.23e4")
	assert_str(_fmt("847", NumberFormat.SCIENTIFIC)).is_equal("847")
	assert_str(_fmt("1.999e50", NumberFormat.SCIENTIFIC)).is_equal("1.99e50")


func test_engineering_style() -> void:
	assert_str(_fmt("12345", NumberFormat.ENGINEERING)).is_equal("12.3e3")
	assert_str(_fmt("1000", NumberFormat.ENGINEERING)).is_equal("1e3")
	assert_str(_fmt("123456", NumberFormat.ENGINEERING)).is_equal("123e3")
	assert_str(_fmt("1.5e7", NumberFormat.ENGINEERING)).is_equal("15e6")
	assert_str(_fmt("999", NumberFormat.ENGINEERING)).is_equal("999")


func test_cache_returns_same_and_stays_bounded() -> void:
	var a: String = NumberFormat.format(BigNum.from_int(12400))
	var b: String = NumberFormat.format(BigNum.from_int(12400))
	assert_str(a).is_equal("12.4K")
	assert_str(b).is_equal(a)
	for i: int in 2000:
		NumberFormat.format(BigNum.from_int(1000 + i))
	assert_str(NumberFormat.format(BigNum.from_int(12400))).is_equal("12.4K")
	assert_int(NumberFormat._cache.size()).is_less_equal(NumberFormat.CACHE_LIMIT)


func test_format_float() -> void:
	assert_str(NumberFormat.format_float(1.44, 2)).is_equal("1.44")
	assert_str(NumberFormat.format_float(12.0, 2)).is_equal("12")
	assert_str(NumberFormat.format_float(1.5, 0)).is_equal("2")
	assert_str(NumberFormat.format_float(0.125, 2)).is_equal("0.13")
	assert_str(NumberFormat.format_float(10.0, 1)).is_equal("10")
	assert_str(NumberFormat.format_float(-0.0001, 2)).is_equal("0")
	assert_str(NumberFormat.format_float(NAN, 2)).is_equal("0")


func test_percent() -> void:
	assert_str(NumberFormat.format_percent(0.0734)).is_equal("7.3%")
	assert_str(NumberFormat.format_percent(0.25)).is_equal("25%")
	assert_str(NumberFormat.format_percent(0.0)).is_equal("0.0%")
	assert_str(NumberFormat.format_percent(0.1)).is_equal("10%")
	assert_str(NumberFormat.format_percent(0.0999)).is_equal("10%")
	assert_str(NumberFormat.format_percent(1.0)).is_equal("100%")


func test_mult() -> void:
	assert_str(NumberFormat.format_mult(1.25)).is_equal("x1.25")
	assert_str(NumberFormat.format_mult(12.4)).is_equal("x12.4")
	assert_str(NumberFormat.format_mult(1.0)).is_equal("x1")
	assert_str(NumberFormat.format_mult(0.5)).is_equal("x0.5")
	assert_str(NumberFormat.format_mult(1240.0)).is_equal("x1.24K")
	assert_str(NumberFormat.format_mult(BigNum.parse("1.24e3"))).is_equal("x1.24K")
	assert_str(NumberFormat.format_mult(BigNum.parse("3.5e40"))).is_equal("x3.5e40")
	assert_str(NumberFormat.format_mult(0.0)).is_equal("x0")


func test_time() -> void:
	assert_str(NumberFormat.format_time(45)).is_equal("45s")
	assert_str(NumberFormat.format_time(0)).is_equal("0s")
	assert_str(NumberFormat.format_time(60)).is_equal("1m 00s")
	assert_str(NumberFormat.format_time(750)).is_equal("12m 30s")
	assert_str(NumberFormat.format_time(11100)).is_equal("3h 05m")
	assert_str(NumberFormat.format_time(100800)).is_equal("1d 4h")
	assert_str(NumberFormat.format_time(-5)).is_equal("0s")


func test_suffix_table_file_matches_code() -> void:
	var table: CsvTable = CsvTable.load_file("res://data/number_suffixes.csv")
	assert_str(table.error).is_equal("")
	assert_int(table.rows.size()).is_equal(11)
	assert_int(NumberFormat.DEFAULT_SUFFIXES.size()).is_equal(11)
	for i: int in 11:
		assert_str(table.get_value(i, "exp")).is_equal(str(3 * (i + 1)))
		assert_str(table.get_value(i, "suffix")).is_equal(NumberFormat.DEFAULT_SUFFIXES[i])
		assert_str(NumberFormat.suffix_for_group(i + 1)).is_equal(NumberFormat.DEFAULT_SUFFIXES[i])
	assert_int(NumberFormat.suffix_count()).is_equal(11)
