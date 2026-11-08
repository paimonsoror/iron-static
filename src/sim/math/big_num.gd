class_name BigNum
extends RefCounted
## Immutable big number for currencies and costs: `m` (0, or in [1,10)) times 10^`e`.
## Zero is m = 0, e = 0. Never mutate `m`/`e` after construction; every operation returns a new value.
## Negative, NaN, INF and unparsable inputs are invalid: the operation records the problem in
## `last_error` / `error_count`, emits a push_warning (not push_error, so headless test runs
## stay clean and tests can assert on the counters) and returns zero. BigNum never yields NaN.

const MAX_FLOAT: float = 1.7976931348623157e308
const ADD_CUTOFF: int = 17  # exponent difference above which the smaller operand is ignored
const NEG_POW10: PackedFloat64Array = [
	1.0,
	1.0e-1,
	1.0e-2,
	1.0e-3,
	1.0e-4,
	1.0e-5,
	1.0e-6,
	1.0e-7,
	1.0e-8,
	1.0e-9,
	1.0e-10,
	1.0e-11,
	1.0e-12,
	1.0e-13,
	1.0e-14,
	1.0e-15,
	1.0e-16,
	1.0e-17
]
const TEXT_DECIMALS: int = 12
const MAX_MANTISSA_DIGITS: int = 17

static var last_error: String = ""
static var error_count: int = 0

static var _parse_regex: RegEx = null

var m: float = 0.0
var e: int = 0


func _init(mantissa: float = 0.0, exponent: int = 0) -> void:
	m = mantissa
	e = exponent


static func reset_errors() -> void:
	last_error = ""
	error_count = 0


static func zero() -> BigNum:
	return BigNum.new(0.0, 0)


static func one() -> BigNum:
	return BigNum.new(1.0, 0)


static func from_float(x: float) -> BigNum:
	if is_nan(x) or is_inf(x) or x < 0.0:
		return _fail("from_float: invalid value %s" % str(x))
	if x == 0.0:
		return zero()
	return _normalized(x, 0)


static func from_int(x: int) -> BigNum:
	if x < 0:
		return _fail("from_int: negative value %d" % x)
	if x == 0:
		return zero()
	return _normalized(float(x), 0)


## Accepts "123", "1.2345e456", "1e318", "0", "12.5E-3". Anything else records an error and gives zero.
static func parse(s: String) -> BigNum:
	if _parse_regex == null:
		_parse_regex = RegEx.create_from_string("^(\\d+)(?:\\.(\\d+))?(?:[eE]([+-]?\\d+))?$")
	var t: String = s.strip_edges()
	var found: RegExMatch = _parse_regex.search(t)
	if found == null:
		return _fail("parse: invalid number text '%s'" % s)
	var int_part: String = found.get_string(1)
	var frac_part: String = found.get_string(2)
	var exp_text: String = found.get_string(3)
	var exp10: int = 0
	if not exp_text.is_empty():
		if exp_text.lstrip("+-").length() > 15:
			return _fail("parse: exponent too large in '%s'" % s)
		exp10 = int(exp_text)
	var digits: String = int_part + frac_part
	var stripped: String = digits.lstrip("0")
	if stripped.is_empty():
		return zero()
	var lead_zeros: int = digits.length() - stripped.length()
	var point_exp: int = int_part.length() - 1 - lead_zeros
	var sig: String = stripped.substr(0, MAX_MANTISSA_DIGITS)
	var mant_text: String = sig.substr(0, 1) + "." + sig.substr(1) + "0"
	return _normalized(mant_text.to_float(), exp10 + point_exp)


func is_zero() -> bool:
	return m == 0.0


func add(other: BigNum) -> BigNum:
	if m == 0.0:
		return other
	if other.m == 0.0:
		return self
	var d: int = e - other.e
	if d > ADD_CUTOFF:
		return self
	if d < -ADD_CUTOFF:
		return other
	if d >= 0:
		return _normalized(m + other.m * NEG_POW10[d], e)
	return _normalized(other.m + m * NEG_POW10[-d], other.e)


func sub_floor0(other: BigNum) -> BigNum:
	if other.m == 0.0:
		return self
	if cmp(other) <= 0:
		return zero()
	var d: int = e - other.e
	if d > ADD_CUTOFF:
		return self
	var diff: float = m - other.m * NEG_POW10[d]
	if diff <= 0.0:
		return zero()
	return _normalized(diff, e)


func mul(other: BigNum) -> BigNum:
	if m == 0.0 or other.m == 0.0:
		return zero()
	return _normalized(m * other.m, e + other.e)


func mul_float(k: float) -> BigNum:
	if is_nan(k) or is_inf(k) or k < 0.0:
		return _fail("mul_float: invalid factor %s" % str(k))
	if k == 0.0 or m == 0.0:
		return zero()
	var f: BigNum = _normalized(k, 0)
	return _normalized(m * f.m, e + f.e)


func div(other: BigNum) -> BigNum:
	if other.m == 0.0:
		return _fail("div: division by zero")
	if m == 0.0:
		return zero()
	return _normalized(m / other.m, e - other.e)


## self ^ p. 0^p is 0 for p > 0, 1 for p == 0; 0 with p < 0 is an error.
func pow_float(p: float) -> BigNum:
	if is_nan(p) or is_inf(p):
		return _fail("pow_float: invalid exponent %s" % str(p))
	if p == 0.0:
		return one()
	if m == 0.0:
		if p > 0.0:
			return zero()
		return _fail("pow_float: zero to a negative power")
	var total: float = (float(e) + log(m) / log(10.0)) * p
	if absf(total) > 1.0e15:
		return _fail("pow_float: result exponent out of range")
	var whole: float = floor(total)
	return _normalized(pow(10.0, total - whole), int(whole))


func floor_value() -> BigNum:
	if m == 0.0 or e >= 15:
		return self
	if e < 0:
		return zero()
	var v: float = floor(m * pow(10.0, float(e)))
	if v <= 0.0:
		return zero()
	return _normalized(v, 0)


@warning_ignore("shadowed_global_identifier")  # spec-mandated name
func min(other: BigNum) -> BigNum:
	return self if cmp(other) <= 0 else other


@warning_ignore("shadowed_global_identifier")  # spec-mandated name
func max(other: BigNum) -> BigNum:
	return self if cmp(other) >= 0 else other


func cmp(other: BigNum) -> int:
	if m == 0.0:
		return 0 if other.m == 0.0 else -1
	if other.m == 0.0:
		return 1
	if e != other.e:
		return -1 if e < other.e else 1
	if m == other.m:
		return 0
	return -1 if m < other.m else 1


func lt(other: BigNum) -> bool:
	return cmp(other) < 0


func le(other: BigNum) -> bool:
	return cmp(other) <= 0


func gt(other: BigNum) -> bool:
	return cmp(other) > 0


func ge(other: BigNum) -> bool:
	return cmp(other) >= 0


func eq(other: BigNum) -> bool:
	return cmp(other) == 0


## log10 of the value. Zero records an error and returns -INF (never NaN).
func log10() -> float:
	if m == 0.0:
		_fail("log10: zero")
		return -INF
	return float(e) + log(m) / log(10.0)


func to_float() -> float:
	if m == 0.0:
		return 0.0
	if e > 308:
		return MAX_FLOAT
	if e < -300:
		if e < -330:
			return 0.0
		return m * pow(10.0, float(e + 300)) * 1.0e-300
	var v: float = m * pow(10.0, float(e))
	if is_inf(v) or is_nan(v):
		return MAX_FLOAT
	return v


## Canonical text: "0", or mantissa (at most 12 decimals, trailing zeros trimmed) + "e" + exponent.
func to_text() -> String:
	if m == 0.0:
		return "0"
	var exp10: int = e
	var txt: String = ("%." + str(TEXT_DECIMALS) + "f") % m
	if txt.begins_with("10"):  # rounding carried into the next power of ten
		txt = "1"
		exp10 += 1
	elif txt.contains("."):
		txt = txt.rstrip("0").rstrip(".")
	return "%se%d" % [txt, exp10]


## Normalizes any positive finite x * 10^exp10 into m in [1,10).
static func _normalized(x: float, exp10: int) -> BigNum:
	if x <= 0.0 or is_nan(x) or is_inf(x):
		if x == 0.0:
			return zero()
		return _fail("normalize: invalid mantissa %s" % str(x))
	if x >= 1.0 and x < 10.0:
		return BigNum.new(x, exp10)
	var ex: int = exp10
	var v: float = x
	if v < 1.0e-300:
		v *= 1.0e300
		ex -= 300
	var k: int = floori(log(v) / log(10.0))
	if k != 0:
		if k > 0:
			v /= pow(10.0, float(k))
		else:
			v *= pow(10.0, float(-k))
		ex += k
	while v >= 10.0:
		v /= 10.0
		ex += 1
	while v < 1.0:
		v *= 10.0
		ex -= 1
	return BigNum.new(v, ex)


static func _fail(message: String) -> BigNum:
	last_error = message
	error_count += 1
	push_warning("BigNum: " + message)
	return zero()
