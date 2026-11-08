class_name TestBigNum
extends GdUnitTestSuite
## BigNum: construction, text round-trip, arithmetic vs float64, ordering, saturation, errors.


func _random_big(rng: Rng, exp_lo: int, exp_hi: int) -> BigNum:
	var lead: int = rng.range_int(1, 9)
	var frac: int = rng.range_int(0, 999999) * 1000000 + rng.range_int(0, 999999)
	var ex: int = rng.range_int(exp_lo, exp_hi)
	return BigNum.parse("%d.%012de%d" % [lead, frac, ex])


func _rel_err(a: float, b: float) -> float:
	if b == 0.0:
		return absf(a)
	return absf(a - b) / absf(b)


func test_zero_and_constructors() -> void:
	assert_bool(BigNum.zero().is_zero()).is_true()
	assert_str(BigNum.zero().to_text()).is_equal("0")
	assert_str(BigNum.from_int(0).to_text()).is_equal("0")
	assert_str(BigNum.from_int(1234).to_text()).is_equal("1.234e3")
	assert_str(BigNum.from_float(0.5).to_text()).is_equal("5e-1")
	assert_str(BigNum.from_float(1000.0).to_text()).is_equal("1e3")
	assert_str(BigNum.one().to_text()).is_equal("1e0")
	var b: BigNum = BigNum.from_float(123456.0)
	assert_float(b.m).is_between(1.0, 10.0)
	assert_int(b.e).is_equal(5)


func test_parse_forms() -> void:
	assert_bool(BigNum.parse("0").is_zero()).is_true()
	assert_bool(BigNum.parse("000").is_zero()).is_true()
	assert_bool(BigNum.parse("123").eq(BigNum.from_int(123))).is_true()
	assert_str(BigNum.parse("1.2345e456").to_text()).is_equal("1.2345e456")
	assert_str(BigNum.parse("12345e3").to_text()).is_equal("1.2345e7")
	assert_str(BigNum.parse("0.005").to_text()).is_equal("5e-3")
	assert_str(BigNum.parse("12.5E-3").to_text()).is_equal("1.25e-2")
	assert_str(BigNum.parse("123456789012345678901234567890").to_text()).is_equal("1.234567890123e29")


func test_parse_garbage_records_error() -> void:
	BigNum.reset_errors()
	assert_bool(BigNum.parse("garbage").is_zero()).is_true()
	assert_int(BigNum.error_count).is_equal(1)
	assert_str(BigNum.last_error).contains("garbage")
	assert_bool(BigNum.parse("-5").is_zero()).is_true()
	assert_bool(BigNum.parse("").is_zero()).is_true()
	assert_bool(BigNum.parse("1e").is_zero()).is_true()
	assert_bool(BigNum.parse("1e99999999999999999999").is_zero()).is_true()
	assert_int(BigNum.error_count).is_equal(5)
	BigNum.reset_errors()
	assert_int(BigNum.error_count).is_equal(0)
	assert_str(BigNum.last_error).is_equal("")


func test_invalid_inputs_return_zero_never_nan() -> void:
	BigNum.reset_errors()
	assert_bool(BigNum.from_float(-1.0).is_zero()).is_true()
	assert_bool(BigNum.from_float(NAN).is_zero()).is_true()
	assert_bool(BigNum.from_float(INF).is_zero()).is_true()
	assert_bool(BigNum.from_int(-3).is_zero()).is_true()
	assert_bool(BigNum.from_int(5).div(BigNum.zero()).is_zero()).is_true()
	assert_bool(BigNum.from_int(5).mul_float(-2.0).is_zero()).is_true()
	assert_bool(BigNum.from_int(5).mul_float(NAN).is_zero()).is_true()
	assert_bool(BigNum.zero().pow_float(-1.0).is_zero()).is_true()
	assert_bool(BigNum.from_int(5).pow_float(NAN).is_zero()).is_true()
	assert_int(BigNum.error_count).is_equal(9)
	BigNum.reset_errors()
	var lg: float = BigNum.zero().log10()
	assert_bool(is_nan(lg)).is_false()
	assert_int(BigNum.error_count).is_equal(1)
	BigNum.reset_errors()


func test_round_trip_1000_random_values() -> void:
	var rng: Rng = Rng.new(2026, 1)
	BigNum.reset_errors()
	var bad: int = 0
	for i: int in 1000:
		var x: BigNum = _random_big(rng, -300, 3000)
		var back: BigNum = BigNum.parse(x.to_text())
		if not back.eq(x):
			bad += 1
	assert_int(bad).is_equal(0)
	assert_int(BigNum.error_count).is_equal(0)


func test_to_text_rounding_carry() -> void:
	var x: BigNum = BigNum.new(9.9999999999999, 5)
	assert_str(x.to_text()).is_equal("1e6")


func test_arithmetic_matches_float64() -> void:
	var rng: Rng = Rng.new(7, 2)
	var worst: float = 0.0
	for i: int in 2000:
		var a: BigNum = _random_big(rng, -100, 100)
		var b: BigNum = _random_big(rng, -100, 100)
		var fa: float = a.to_float()
		var fb: float = b.to_float()
		worst = maxf(worst, _rel_err(a.add(b).to_float(), fa + fb))
		worst = maxf(worst, _rel_err(a.mul(b).to_float(), fa * fb))
		worst = maxf(worst, _rel_err(a.div(b).to_float(), fa / fb))
		if fa > fb:
			var d: float = fa - fb
			# cancellation amplifies input error; only check well-separated operands
			if d > fa * 1.0e-3:
				worst = maxf(worst, _rel_err(a.sub_floor0(b).to_float(), d))
	assert_float(worst).is_less(1.0e-12)


func test_add_sub_small_exact() -> void:
	assert_str(BigNum.from_int(5).add(BigNum.from_int(7)).to_text()).is_equal("1.2e1")
	assert_str(BigNum.from_int(10).sub_floor0(BigNum.from_int(4)).to_text()).is_equal("6e0")
	assert_str(BigNum.from_int(999).add(BigNum.from_int(1)).to_text()).is_equal("1e3")
	assert_bool(BigNum.from_int(7).sub_floor0(BigNum.from_int(7)).is_zero()).is_true()


func test_sub_floor0_clamps_at_zero() -> void:
	assert_bool(BigNum.from_int(5).sub_floor0(BigNum.from_int(10)).is_zero()).is_true()
	assert_bool(BigNum.zero().sub_floor0(BigNum.from_int(1)).is_zero()).is_true()
	assert_bool(BigNum.from_int(5).sub_floor0(BigNum.zero()).eq(BigNum.from_int(5))).is_true()


func test_add_far_apart_returns_larger() -> void:
	var big: BigNum = BigNum.parse("1e100")
	var tiny: BigNum = BigNum.parse("1e50")
	assert_bool(big.add(tiny).eq(big)).is_true()
	assert_bool(tiny.add(big).eq(big)).is_true()
	assert_bool(big.sub_floor0(tiny).eq(big)).is_true()
	# difference of 15 still contributes
	var near: BigNum = BigNum.parse("1e15").add(BigNum.one())
	assert_bool(near.gt(BigNum.parse("1e15"))).is_true()


func test_mul_and_div_identities() -> void:
	var a: BigNum = BigNum.parse("3.5e40")
	assert_bool(a.mul(BigNum.one()).eq(a)).is_true()
	assert_bool(a.mul(BigNum.zero()).is_zero()).is_true()
	assert_bool(BigNum.zero().div(a).is_zero()).is_true()
	assert_str(a.div(a).to_text()).is_equal("1e0")
	assert_str(BigNum.from_int(6).mul_float(2.5).to_text()).is_equal("1.5e1")
	assert_str(BigNum.from_float(1.0e308).mul(BigNum.from_float(1.0e10)).to_text()).is_equal("1e318")


func test_pow_float() -> void:
	assert_str(BigNum.from_int(2).pow_float(10.0).to_text()).is_equal("1.024e3")
	assert_bool(BigNum.from_int(9).pow_float(0.5).to_float() > 2.9999999999).is_true()
	assert_bool(BigNum.from_int(9).pow_float(0.5).to_float() < 3.0000000001).is_true()
	assert_bool(BigNum.zero().pow_float(2.0).is_zero()).is_true()
	assert_str(BigNum.zero().pow_float(0.0).to_text()).is_equal("1e0")
	var huge: BigNum = BigNum.parse("1e100").pow_float(3.0)
	assert_int(huge.e).is_between(299, 300)
	assert_float(huge.log10()).is_equal_approx(300.0, 1.0e-9)
	var growth: BigNum = BigNum.from_float(1.15).pow_float(1000.0)
	assert_float(growth.log10()).is_equal_approx(1000.0 * log(1.15) / log(10.0), 1.0e-9)


func test_floor_value() -> void:
	assert_str(BigNum.from_float(999999.9).floor_value().to_text()).is_equal("9.99999e5")
	assert_bool(BigNum.from_float(0.99).floor_value().is_zero()).is_true()
	assert_str(BigNum.from_float(12.7).floor_value().to_text()).is_equal("1.2e1")
	var huge: BigNum = BigNum.parse("1.5e20")
	assert_bool(huge.floor_value().eq(huge)).is_true()


func test_min_max_log10_immutability() -> void:
	var a: BigNum = BigNum.from_int(5)
	var b: BigNum = BigNum.parse("1e30")
	assert_bool(a.min(b).eq(a)).is_true()
	assert_bool(a.max(b).eq(b)).is_true()
	assert_bool(b.min(a).eq(a)).is_true()
	assert_bool(BigNum.zero().max(a).eq(a)).is_true()
	assert_float(BigNum.parse("1e50").log10()).is_equal_approx(50.0, 1.0e-12)
	assert_float(BigNum.from_int(1000).log10()).is_equal_approx(3.0, 1.0e-12)
	assert_float(BigNum.parse("2e-5").log10()).is_equal_approx(log(2.0e-5) / log(10.0), 1.0e-12)
	var ia: BigNum = BigNum.from_int(10)
	var ib: BigNum = BigNum.from_int(5)
	var sm: BigNum = ia.add(ib)
	assert_str(ia.to_text()).is_equal("1e1")
	assert_str(ib.to_text()).is_equal("5e0")
	assert_str(sm.to_text()).is_equal("1.5e1")


func test_to_float_saturates() -> void:
	assert_float(BigNum.parse("1e400").to_float()).is_equal(1.7976931348623157e308)
	assert_float(BigNum.parse("1e309").to_float()).is_equal(1.7976931348623157e308)
	assert_float(BigNum.parse("2e-400").to_float()).is_equal(0.0)
	assert_float(BigNum.parse("1.5e-310").to_float()).is_greater(0.0)
	assert_float(BigNum.from_float(1234.5).to_float()).is_equal_approx(1234.5, 1.0e-9)
	assert_float(BigNum.zero().to_float()).is_equal(0.0)
	assert_bool(is_inf(BigNum.parse("9e308").to_float())).is_false()


func test_extreme_from_float() -> void:
	var tiny: BigNum = BigNum.from_float(pow(10.0, -320.0))
	assert_int(tiny.e).is_between(-321, -320)
	assert_bool(tiny.m >= 1.0 and tiny.m < 10.0).is_true()
	var top: BigNum = BigNum.from_float(1.7976931348623157e308)
	assert_int(top.e).is_equal(308)
	assert_float(top.to_float()).is_equal(1.7976931348623157e308)


func test_mantissa_always_normalized() -> void:
	var rng: Rng = Rng.new(11, 3)
	var bad: int = 0
	for i: int in 1000:
		var a: BigNum = _random_big(rng, -50, 50)
		var b: BigNum = _random_big(rng, -50, 50)
		for r: BigNum in [a.add(b), a.mul(b), a.div(b), a.sub_floor0(b), a.pow_float(1.7)]:
			if not r.is_zero() and (r.m < 1.0 or r.m >= 10.0):
				bad += 1
	assert_int(bad).is_equal(0)


func test_comparisons_total_order_on_sorted_200() -> void:
	var rng: Rng = Rng.new(5, 4)
	var values: Array[BigNum] = [BigNum.zero()]
	for i: int in 199:
		values.append(_random_big(rng, -20, 40))
	values.sort_custom(func(x: BigNum, y: BigNum) -> bool: return x.cmp(y) < 0)
	var violations: int = 0
	for i: int in values.size():
		if values[i].cmp(values[i]) != 0 or not values[i].eq(values[i]):
			violations += 1
		for j: int in range(i + 1, values.size()):
			var c: int = values[i].cmp(values[j])
			var back: int = values[j].cmp(values[i])
			if c > 0 or back < 0 or c != -back:
				violations += 1
			if (
				c < 0
				and not (
					values[i].lt(values[j])
					and values[i].le(values[j])
					and values[j].gt(values[i])
					and values[j].ge(values[i])
				)
			):
				violations += 1
			if c == 0 and not (values[i].le(values[j]) and values[i].ge(values[j])):
				violations += 1
	assert_int(violations).is_equal(0)


func test_100k_additions_timing() -> void:
	var acc: BigNum = BigNum.zero()
	var step: BigNum = BigNum.from_float(1234.5678)
	var t0: int = Time.get_ticks_usec()
	for i: int in 100000:
		acc = acc.add(step)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("BigNum 100k additions: %.1f ms" % ms)
	assert_float(acc.to_float()).is_equal_approx(123456780.0, 1.0)
	assert_float(ms).is_less(5000.0)  # informational target is 1000 ms; loose bound avoids flaky CI
