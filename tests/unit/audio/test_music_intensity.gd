class_name TestMusicIntensity
extends GdUnitTestSuite

## MusicIntensity (A1-03): rule parsing, targets by wave/boss/integrity/menu, fade step, shipped thresholds.

const CSV: String = (
	"layer,min_wave,on_boss,low_hp_band,menu_level,active_level,fade_in_s,fade_out_s\n"
	+ "pad,1,0,0,0.8,1.0,3,5\n"
	+ "pulse,10,1,0,0,0.9,4,6\n"
	+ "perc,30,1,0,0,0.9,4,6\n"
	+ "lead,0,1,3,0,0.8,2,5\n"
)


func _targets(wave: int, boss: bool, band: int, menu: bool) -> PackedFloat32Array:
	var m: MusicIntensity = MusicIntensity.from_text(CSV)
	return m.targets(MusicState.make(wave, boss, band, menu))


func test_parses_four_rules() -> void:
	var m: MusicIntensity = MusicIntensity.from_text(CSV)
	assert_str(m.error).is_empty()
	assert_int(m.rules.size()).is_equal(4)
	assert_int(m.rules[1].min_wave).is_equal(10)
	assert_bool(m.rules[1].on_boss).is_true()
	assert_float(m.rules[3].active_level).is_equal(0.8)


func test_menu_is_stripped_ambient() -> void:
	var t: PackedFloat32Array = _targets(50, true, 3, true)
	assert_float(t[0]).is_equal_approx(0.8, 0.0001)
	assert_float(t[1]).is_equal(0.0)
	assert_float(t[2]).is_equal(0.0)
	assert_float(t[3]).is_equal(0.0)


func test_layers_stack_with_wave() -> void:
	var early: PackedFloat32Array = _targets(3, false, 0, false)
	assert_float(early[0]).is_equal(1.0)
	assert_float(early[1]).is_equal(0.0)
	var w10: PackedFloat32Array = _targets(10, false, 0, false)
	assert_float(w10[1]).is_equal_approx(0.9, 0.0001)
	assert_float(w10[2]).is_equal(0.0)
	var w30: PackedFloat32Array = _targets(30, false, 0, false)
	assert_float(w30[2]).is_equal_approx(0.9, 0.0001)
	assert_float(w30[3]).is_equal(0.0)


func test_boss_switches_everything_on() -> void:
	var t: PackedFloat32Array = _targets(10, true, 0, false)
	for i: int in range(4):
		assert_float(t[i]).is_greater(0.0)


func test_low_integrity_brings_the_lead() -> void:
	assert_float(_targets(5, false, 2, false)[3]).is_equal(0.0)
	assert_float(_targets(5, false, 3, false)[3]).is_equal_approx(0.8, 0.0001)


func test_fade_step_moves_linearly_and_never_overshoots() -> void:
	assert_float(MusicIntensity.step(0.0, 1.0, 0.5, 4.0, 6.0)).is_equal_approx(0.125, 0.0001)
	assert_float(MusicIntensity.step(0.95, 1.0, 1.0, 4.0, 6.0)).is_equal(1.0)
	assert_float(MusicIntensity.step(1.0, 0.0, 0.6, 4.0, 6.0)).is_equal_approx(0.9, 0.0001)
	assert_float(MusicIntensity.step(0.05, 0.0, 10.0, 4.0, 6.0)).is_equal(0.0)
	assert_float(MusicIntensity.step(0.5, 0.5, 1.0, 4.0, 6.0)).is_equal(0.5)
	assert_float(MusicIntensity.step(0.0, 1.0, 1.0, 0.0, 6.0)).is_equal(1.0)


func test_bad_csv_sets_error() -> void:
	assert_str(MusicIntensity.from_text("layer,min_wave\n,1\n").error).is_not_empty()
	assert_str(MusicIntensity.from_text("").error).is_not_empty()


func test_shipped_rules_match_the_audio_direction() -> void:
	var m: MusicIntensity = MusicIntensity.load_default()
	assert_str(m.error).is_empty()
	assert_int(m.rules.size()).is_equal(4)
	assert_int(m.rules[1].min_wave).is_equal(10)
	assert_int(m.rules[2].min_wave).is_equal(30)
	for r: MusicLayerRule in m.rules:
		assert_bool(AudioSlots.has(r.layer)).is_true()
