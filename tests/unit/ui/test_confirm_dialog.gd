class_name TestConfirmDialog
extends GdUnitTestSuite
## ConfirmDialog (M3-30): hidden until opened, two buttons, closes itself, back cancels.

var _yes: int = 0
var _no: int = 0


func _make() -> ConfirmDialog:
	var d := ConfirmDialog.new()
	d.confirmed.connect(func() -> void: _yes += 1)
	d.cancelled.connect(func() -> void: _no += 1)
	add_child(d)
	auto_free(d)
	_yes = 0
	_no = 0
	return d


func test_starts_hidden_and_open_shows_the_texts() -> void:
	var d: ConfirmDialog = _make()
	assert_bool(d.is_open()).is_false()
	d.open("TITLE", "BODY")
	assert_bool(d.is_open()).is_true()
	assert_str(d.title_text()).is_equal("TITLE")
	assert_str(d.body_text()).is_equal("BODY")
	assert_bool(d.yes_button().custom_minimum_size.y >= 148.0).is_true()


func test_yes_and_no_close_the_dialog_and_signal_once() -> void:
	var d: ConfirmDialog = _make()
	d.open("T", "B")
	d.yes_button().pressed.emit()
	assert_bool(d.is_open()).is_false()
	assert_int(_yes).is_equal(1)
	assert_int(_no).is_equal(0)
	d.open("T", "B")
	d.no_button().pressed.emit()
	assert_bool(d.is_open()).is_false()
	assert_int(_no).is_equal(1)


func test_cancel_is_the_back_gesture_and_a_closed_dialog_ignores_it() -> void:
	var d: ConfirmDialog = _make()
	assert_bool(d.cancel()).is_false()
	assert_int(_no).is_equal(0)
	d.open("T", "B")
	assert_bool(d.cancel()).is_true()
	assert_bool(d.is_open()).is_false()
	assert_int(_no).is_equal(1)


func test_open_with_custom_button_texts_and_default_after() -> void:
	var d := ConfirmDialog.new()
	add_child(d)
	auto_free(d)
	d.open("T", "B", "ABORT", "CANCEL")
	assert_str(d.yes_button().text).is_equal("ABORT")
	assert_str(d.no_button().text).is_equal("CANCEL")
	d.open("T", "B")
	assert_str(d.yes_button().text).is_equal(Strings.get_text("title.quit_yes"))
	assert_str(d.no_button().text).is_equal(Strings.get_text("title.quit_no"))
