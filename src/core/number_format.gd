class_name NumberFormat
extends RefCounted
## GDD 04_economy section 5 number display. Static only. Display always floors (never rounds up)
## BigNum values to 3 significant digits; stat values (format_float, format_percent) round.
## Suffix ladder: the generated res://src/data_gen/number_suffixes.tres (ships in the APK), else
## res://data/number_suffixes.csv (tools and tests), else the const fallback.

enum { SHORT, SCIENTIFIC, ENGINEERING }

const SUFFIX_CSV: String = "res://data/number_suffixes.csv"
const SUFFIX_GEN: String = "res://src/data_gen/number_suffixes.tres"
const DEFAULT_SUFFIXES: Array[String] = ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
const SHORT_MAX_EXP: int = 35  # 1e36 and above print in scientific form
const CACHE_LIMIT: int = 512
const EPS: float = 1.0e-12  # relative nudge so 12.4 stored as 12.399999999999999 still floors to 12.4

static var _suffixes: Array[String] = []
static var _cache: Dictionary = {}


## Suffix for 10^(3*group), group 1..11 (empty when out of range).
static func suffix_for_group(group: int) -> String:
	_ensure_suffixes()
	if group < 1 or group > _suffixes.size():
		return ""
	return _suffixes[group - 1]


static func suffix_count() -> int:
	_ensure_suffixes()
	return _suffixes.size()


static func format(value: BigNum, style: int = SHORT) -> String:
	if value.is_zero():
		return "0"
	var key: String = "%d|%s" % [style, value.to_text()]
	if _cache.has(key):
		var hit: String = _cache[key]
		return hit
	var out: String = _format_uncached(value, style, false)
	_cache_put(key, out)
	return out


## Stat values: rounded to at most `max_decimals`, trailing zeros trimmed (1.44, 12).
static func format_float(v: float, max_decimals: int) -> String:
	if is_nan(v) or is_inf(v):
		return "0"
	var txt: String = _fixed(v, max_decimals)
	if txt.contains("."):
		txt = txt.rstrip("0").rstrip(".")
	if txt == "-0":
		return "0"
	return txt


## Fraction (0.0734) to percent text: 1 decimal below 10%, integer at or above.
static func format_percent(fraction: float) -> String:
	if is_nan(fraction) or is_inf(fraction):
		return "0%"
	var p: float = fraction * 100.0
	if absf(p) < 9.95:
		return _fixed(p, 1) + "%"
	return "%d%%" % roundi(p)


## Fixed-point text with exactly `decimals` digits, rounding halves away from zero.
## Done with integer math because printf-style "%.2f" rounds ties differently per platform
## (0.125 -> "0.13" on Windows, different on Linux CI). The 1e-12 nudge makes values stored
## just below a written tie (1.005 as 1.00499999...) round as written.
static func _fixed(v: float, decimals: int) -> String:
	var d: int = clampi(decimals, 0, 9)
	var p10: int = 1
	for _step: int in d:
		p10 *= 10
	var magnitude: float = absf(v) * float(p10) * (1.0 + 1e-12)
	if magnitude >= 9.0e15:
		return str(roundi(v))
	var scaled: int = roundi(magnitude)
	var whole: int = floori(float(scaled) / float(p10))
	var txt: String = str(whole)
	if d > 0:
		txt += "." + str(scaled - whole * p10).lpad(d, "0")
	if v < 0.0 and scaled != 0:
		txt = "-" + txt
	return txt


## Multiplier text: x1.25, x12.4, x1.24K. Accepts float or BigNum.
static func format_mult(v: Variant, style: int = SHORT) -> String:
	var big: BigNum = null
	if v is BigNum:
		big = v
	elif v is float or v is int:
		var f: float = v
		big = BigNum.from_float(maxf(f, 0.0)) if not is_nan(f) else BigNum.zero()
	else:
		return "x0"
	if big.is_zero():
		return "x0"
	return "x" + _format_uncached(big, style, true)


## Seconds to 45s / 12m 30s / 3h 05m / 1d 4h.
static func format_time(seconds: int) -> String:
	var s: int = maxi(seconds, 0)
	if s < 60:
		return "%ds" % s
	if s < 3600:
		return "%dm %02ds" % [floori(float(s) / 60.0), s % 60]
	if s < 86400:
		return "%dh %02dm" % [floori(float(s) / 3600.0), floori(float(s % 3600) / 60.0)]
	return "%dd %dh" % [floori(float(s) / 86400.0), floori(float(s % 86400) / 3600.0)]


## `small_decimals`: below 1000 keep 3 significant digits (multipliers) instead of an integer.
static func _format_uncached(value: BigNum, style: int, small_decimals: bool) -> String:
	if value.e < 3:
		if small_decimals:
			return _sig3(value.to_float())
		return str(floori(value.to_float()))
	if style == SCIENTIFIC:
		return _sig3(value.m) + "e" + str(value.e)
	if style == ENGINEERING:
		var rem: int = value.e % 3
		return _sig3(value.m * pow(10.0, float(rem))) + "e" + str(value.e - rem)
	if value.e > SHORT_MAX_EXP:
		return _sig3(value.m) + "e" + str(value.e)
	var group: int = floori(float(value.e) / 3.0)
	var scaled: float = value.m * pow(10.0, float(value.e - 3 * group))
	return _sig3(scaled) + suffix_for_group(group)


## Floors x to 3 significant digits and trims trailing zeros. x < 1000 (0 < x < 1 keeps 3 decimals).
static func _sig3(x: float) -> String:
	var v: float = x * (1.0 + EPS)
	if v >= 100.0:
		return str(floori(v))
	var decimals: int = 2 if v >= 1.0 else 3
	if v >= 10.0:
		decimals = 1
	var scale: int = 10 if decimals == 1 else (100 if decimals == 2 else 1000)
	var n: int = floori(v * float(scale))
	var whole: int = floori(float(n) / float(scale))
	var frac: int = n - whole * scale
	if frac == 0:
		return str(whole)
	var frac_text: String = ("%0" + str(decimals) + "d") % frac
	return "%d.%s" % [whole, frac_text.rstrip("0")]


static func _cache_put(key: String, text: String) -> void:
	if _cache.size() >= CACHE_LIMIT:
		_cache.clear()
	_cache[key] = text


static func _ensure_suffixes() -> void:
	if not _suffixes.is_empty():
		return
	if ResourceLoader.exists(SUFFIX_GEN):
		var res: Resource = load(SUFFIX_GEN)
		if res is NumberSuffixTable:
			var gen: NumberSuffixTable = res
			_suffixes.append_array(gen.suffixes)
	if _suffixes.is_empty():
		var table: CsvTable = CsvTable.load_file(SUFFIX_CSV)
		if table.error.is_empty():
			for i: int in table.rows.size():
				_suffixes.append(table.get_value(i, "suffix"))
	if _suffixes.size() != DEFAULT_SUFFIXES.size():
		_suffixes.clear()
		_suffixes.append_array(DEFAULT_SUFFIXES)
