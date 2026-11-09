class_name TestTitleFlow
extends GdUnitTestSuite
## The title flow in the real main scene (M3-30): boot -> TITLE, CONTINUE, NEW GAME confirm and reset, frame bay,
## quit confirm, and the Settings > Data double confirm. `Game` is the autoload; the test swaps in an in-memory
## SaveService and a fresh controller (and restores them).

var _fs: MemorySaveFs
var _old_saves: SaveService
var _old_controller: RunController
var _old_problem: SaveService.Problem
var _old_pending: Variant


func before_test() -> void:
	SaveKey.reset()
	_old_saves = Game.saves
	_old_controller = Game.controller
	_old_problem = Game.save_problem
	_old_pending = Game.get("_pending_resume")
	_fs = MemorySaveFs.new()
	Game.controller = RunController.new()
	Game.controller.last_run_path = "user://runs/test_title_flow.json"
	Game.set("_pending_resume", null)
	Game.notice = ""
	_use_service(SaveService.new(_fs, FakeClock.new(1000), "dev"))


func after_test() -> void:
	Game.saves = _old_saves
	Game.controller = _old_controller
	Game.save_problem = _old_problem
	Game.set("_pending_resume", _old_pending)
	Game.notice = ""


func _use_service(s: SaveService) -> void:
	@warning_ignore("return_value_discarded")
	s.load_profile()
	s.attach(Game.controller)
	Game.saves = s
	Game.save_problem = s.problem


## A profile that played: 250 data, best wave 9 (BULWARK unlocked and selected), custom settings, files on disk.
func _play() -> void:
	var p: PlayerProfile = Game.profile()
	p.settings = {"sfx": 0.25, "muted": true}
	@warning_ignore("return_value_discarded")
	Game.saves.bank_run(RunSummary.make(1, 9, BigNum.parse("250"), 1800))
	assert_bool(FrameRules.select(p, "bulwark")).is_true()
	assert_bool(Game.saves.save_now()).is_true()


func _booted() -> ScreenRouter:
	var main: Control = (load("res://src/ui/main.tscn") as PackedScene).instantiate()
	main.size = Vector2(1080.0, 2400.0)
	add_child(main)
	auto_free(main)
	for c: Node in main.get_children():
		if c is ScreenRouter:
			var r: ScreenRouter = c
			r.quits_tree = false
			return r
	fail("no router in main")
	return null


func _title(r: ScreenRouter) -> TitleScreen:
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.TITLE)
	return r.active_screen() as TitleScreen


func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in _fs.files:
		var b: PackedByteArray = _fs.files[k]
		out[k] = Marshalls.raw_to_base64(b)
	return out


func test_fresh_boot_shows_the_title_without_continue() -> void:
	var r: ScreenRouter = _booted()
	var t: TitleScreen = _title(r)
	assert_array(t.buttons().rows()).is_equal([TitleModel.ROW_NEW_GAME, TitleModel.ROW_SETTINGS])


func test_played_profile_shows_continue_and_continue_goes_home() -> void:
	_play()
	var r: ScreenRouter = _booted()
	var t: TitleScreen = _title(r)
	assert_array(t.buttons().rows()).is_equal(
		[TitleModel.ROW_CONTINUE, TitleModel.ROW_NEW_GAME, TitleModel.ROW_SETTINGS]
	)
	t.continue_pressed.emit()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.HOME)


func test_new_game_without_progress_goes_to_the_bay_then_home_then_deploys_vanguard() -> void:
	var r: ScreenRouter = _booted()
	_title(r).new_game_pressed.emit()
	assert_bool(r.dialog().is_open()).is_false()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.FRAME_BAY)
	(r.active_screen() as FrameBay).confirmed.emit()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.HOME)
	(r.active_screen() as HomeScreen).deploy_pressed.emit()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.BATTLE)
	assert_str(Game.controller.world.config.frame_id).is_equal("vanguard")


func test_new_game_confirm_no_leaves_everything_byte_identical() -> void:
	_play()
	var before: Dictionary = _snapshot()
	var r: ScreenRouter = _booted()
	_title(r).new_game_pressed.emit()
	assert_bool(r.dialog().is_open()).is_true()
	assert_str(r.dialog().body_text()).is_equal(Strings.get_text("title.newgame_confirm_body"))
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.TITLE)
	r.dialog().no_button().pressed.emit()
	assert_bool(r.dialog().is_open()).is_false()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.TITLE)
	assert_dict(_snapshot()).is_equal(before)
	assert_str(Game.profile().data.to_text()).is_equal(BigNum.parse("250").to_text())


func test_new_game_confirm_yes_resets_keeps_settings_and_opens_the_bay() -> void:
	_play()
	var live: PackedByteArray = _fs.files["profile.sav"]
	var r: ScreenRouter = _booted()
	_title(r).new_game_pressed.emit()
	r.dialog().yes_button().pressed.emit()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.FRAME_BAY)
	assert_array(_fs.files["profile.sav.reset"]).is_equal(live)
	var p: PlayerProfile = Game.profile()
	assert_bool(p.data.is_zero()).is_true()
	assert_bool(p.has_progress()).is_false()
	assert_str(p.frame_selected).is_equal("vanguard")
	assert_bool(p.settings["muted"]).is_true()
	assert_bool(_fs.exists("profile.sav")).is_true()  # the fresh profile (with the settings) is saved at once
	(r.active_screen() as FrameBay).confirmed.emit()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.HOME)


func test_back_on_the_title_asks_quit_and_a_second_back_closes_it() -> void:
	var r: ScreenRouter = _booted()
	var t: TitleScreen = _title(r)
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.CONFIRM_QUIT)
	assert_bool(t.quit_box_visible()).is_true()
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.CONFIRM_QUIT)
	assert_bool(t.quit_box_visible()).is_false()
	assert_int(r.quit_requested_count).is_equal(0)
	@warning_ignore("return_value_discarded")
	r.handle_back(false)
	t.quit_confirmed.emit()
	assert_int(r.quit_requested_count).is_equal(1)


func test_back_closes_the_new_game_dialog_before_anything_else() -> void:
	_play()
	var r: ScreenRouter = _booted()
	_title(r).new_game_pressed.emit()
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.CLOSE_DIALOG)
	assert_bool(r.dialog().is_open()).is_false()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.TITLE)


func test_settings_from_the_title_returns_to_the_title() -> void:
	var r: ScreenRouter = _booted()
	_title(r).settings_pressed.emit()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.SETTINGS)
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.GO_BACK)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.TITLE)


func test_settings_reset_needs_two_yes_taps_and_returns_to_the_title() -> void:
	_play()
	var live: PackedByteArray = _fs.files["profile.sav"]
	var r: ScreenRouter = _booted()
	_title(r).settings_pressed.emit()
	var s: SettingsScreen = r.active_screen() as SettingsScreen
	var taps: int = 0
	s.reset_button.pressed.emit()
	assert_str(s.dialog().body_text()).is_equal(Strings.get_text("settings.reset_confirm1"))
	taps += 1
	s.dialog().yes_button().pressed.emit()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.SETTINGS)  # one YES is not enough
	assert_bool(s.dialog().is_open()).is_true()
	assert_str(s.dialog().body_text()).contains("250").contains("9")
	assert_array(_fs.files["profile.sav"]).is_equal(live)
	taps += 1
	s.dialog().yes_button().pressed.emit()
	assert_int(taps).is_equal(2)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.TITLE)
	assert_array(_fs.files["profile.sav.reset"]).is_equal(live)
	assert_bool(Game.profile().has_progress()).is_false()
	assert_bool(Game.profile().settings["muted"]).is_true()
	assert_array(_title(r).buttons().rows()).is_equal([TitleModel.ROW_NEW_GAME, TitleModel.ROW_SETTINGS])


func test_settings_reset_cancel_and_back_change_nothing() -> void:
	_play()
	var before: Dictionary = _snapshot()
	var r: ScreenRouter = _booted()
	_title(r).settings_pressed.emit()
	var s: SettingsScreen = r.active_screen() as SettingsScreen
	s.reset_button.pressed.emit()
	s.dialog().no_button().pressed.emit()
	assert_int(s.reset_step()).is_equal(0)
	s.reset_button.pressed.emit()
	s.dialog().yes_button().pressed.emit()
	assert_int(s.reset_step()).is_equal(2)
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.GO_BACK)  # the screen consumes it: dialog closes
	assert_bool(s.dialog().is_open()).is_false()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.SETTINGS)
	assert_int(s.reset_step()).is_equal(0)
	assert_str(Game.profile().data.to_text()).is_equal(BigNum.parse("250").to_text())
	assert_bool(_fs.exists("profile.sav.reset")).is_false()
	var now: Dictionary = _snapshot()
	assert_str(str(now["profile.sav"])).is_equal(str(before["profile.sav"]))
