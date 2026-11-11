class_name TestSettingsScroll
extends GdUnitTestSuite
## Settings list vs touch scrolling (same bug as the INTEL cards): a read-only PanelContainer plate defaults to
## mouse_filter STOP and would swallow a touch drag before the screen's ScrollContainer sees it.

var _fs: MemorySaveFs
var _old_saves: SaveService


func before_test() -> void:
	SaveKey.reset()
	_old_saves = Game.saves
	_fs = MemorySaveFs.new()
	var s := SaveService.new(_fs, FakeClock.new(1000), "dev")
	@warning_ignore("return_value_discarded")
	s.load_profile()
	Game.saves = s


func after_test() -> void:
	Game.saves = _old_saves


func test_read_only_plates_do_not_stop_touch_drags_meant_for_the_scroll_list() -> void:
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, 2400.0)
	add_child(root)
	var s: SettingsScreen = (load("res://src/ui/settings/settings_screen.tscn") as PackedScene).instantiate()
	root.add_child(s)
	var plates: Array[Node] = s.scroll.find_children("*", "PanelContainer", true, false)
	assert_int(plates.size()).is_greater(0)
	for n: Node in plates:
		assert_int((n as PanelContainer).mouse_filter).is_not_equal(Control.MOUSE_FILTER_STOP)
