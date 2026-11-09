class_name TestFtuePlacement
extends GdUnitTestSuite
## FtuePlacement (M4-27 F1-F3): the label plate never covers the target's content, the arrow aims at a blank spot.

const VIEW: Vector2 = Vector2(1080.0, 2400.0)
const PLATE: Vector2 = Vector2(780.0, 150.0)
const MARGIN: float = 48.0


func _plate_rect(kind: FtuePlacement.Kind, target: Rect2, anchor: Rect2, view: Vector2 = VIEW) -> Rect2:
	return Rect2(FtuePlacement.plate_pos(kind, target, anchor, PLATE, view, MARGIN), PLATE)


func test_kinds_of_targets() -> void:
	assert_int(FtuePlacement.kind_of(FtueScript.TARGET_RESULTS_FOUNDRY)).is_equal(FtuePlacement.Kind.RESULTS)
	assert_int(FtuePlacement.kind_of(FtueScript.FOUNDRY_PREFIX + "laser_output")).is_equal(FtuePlacement.Kind.FOUNDRY)
	assert_int(FtuePlacement.kind_of(FtueScript.ROW_PREFIX + "laser_output")).is_equal(FtuePlacement.Kind.ROW)
	assert_int(FtuePlacement.kind_of(FtueScript.TARGET_FIELD)).is_equal(FtuePlacement.Kind.FIELD)


func test_row_plate_sits_above_the_upgrade_panel() -> void:
	var panel := Rect2(0.0, 1780.0, 1080.0, 620.0)
	var row := Rect2(20.0, 2000.0, 1040.0, 200.0)
	var plate: Rect2 = _plate_rect(FtuePlacement.Kind.ROW, row, panel)
	assert_bool(plate.intersects(panel)).is_false()
	assert_float(plate.end.y).is_less_equal(panel.position.y)


func test_results_plate_sits_below_the_card_and_clear_of_its_buttons() -> void:
	var card := Rect2(70.0, 390.0, 940.0, 1620.0)
	var foundry := Rect2(90.0, 1655.0, 900.0, 160.0)
	var plate: Rect2 = _plate_rect(FtuePlacement.Kind.RESULTS, foundry, card)
	assert_bool(plate.intersects(card)).is_false()
	assert_float(plate.end.y).is_less_equal(VIEW.y)


func test_results_plate_moves_above_the_card_when_there_is_no_room_below() -> void:
	var view := Vector2(1990.0, 1920.0)
	var card := Rect2(400.0, 300.0, 1190.0, 1600.0)
	var plate: Rect2 = _plate_rect(FtuePlacement.Kind.RESULTS, Rect2(420.0, 1500.0, 1150.0, 160.0), card, view)
	assert_bool(plate.intersects(card)).is_false()


func test_foundry_plate_sits_in_the_free_band_not_on_the_rows_or_deploy() -> void:
	var band := Rect2(100.0, 1400.0, 880.0, 800.0)
	var row0 := Rect2(100.0, 410.0, 880.0, 252.0)
	var plate: Rect2 = _plate_rect(FtuePlacement.Kind.FOUNDRY, row0, band)
	assert_bool(plate.intersects(row0)).is_false()
	assert_bool(band.encloses(plate)).is_true()
	var tight := Rect2(100.0, 1900.0, 880.0, 120.0)  # band smaller than the plate: it rises, never covers DEPLOY
	assert_float(_plate_rect(FtuePlacement.Kind.FOUNDRY, row0, tight).end.y).is_less_equal(tight.end.y)


func test_arrows_aim_inside_the_target_at_a_blank_spot() -> void:
	var row := Rect2(20.0, 2000.0, 1040.0, 200.0)
	var tip: float = FtuePlacement.arrow_x(FtuePlacement.Kind.ROW, row)
	assert_bool(row.has_point(Vector2(tip, row.position.y + 1.0))).is_true()
	assert_float(tip).is_between(row.position.x + row.size.x * 0.45, row.position.x + row.size.x * 0.55)
	assert_bool(FtuePlacement.arrow_from_above(FtuePlacement.Kind.RESULTS)).is_false()
	assert_bool(FtuePlacement.arrow_from_above(FtuePlacement.Kind.ROW)).is_true()
	assert_bool(is_nan(FtuePlacement.arrow_x(FtuePlacement.Kind.FOUNDRY, row))).is_true()
