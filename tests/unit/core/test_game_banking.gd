class_name TestGameBanking
extends GdUnitTestSuite
## Game wiring (M3-12/13): lifecycle notifications, banking order at death, boot resume. `Game` is an autoload
## (no class name), so the tests build a second node from the script and drive `setup_persistence`.

const GAME_SCRIPT: String = "res://src/core/game.gd"
const TEST_RUN_PATH: String = "user://runs/test_game_banking_run.json"
const MAX_TICKS: int = 60000


class SpyService:
	extends SaveService
	var saves_called: int = 0
	var checkpoints: int = 0

	func save_now() -> bool:
		saves_called += 1
		return super.save_now()

	func checkpoint_now() -> bool:
		checkpoints += 1
		return super.checkpoint_now()


var fs: MemorySaveFs


func before_test() -> void:
	SaveKey.reset()
	fs = MemorySaveFs.new()


func _game() -> Node:
	var script: GDScript = load(GAME_SCRIPT)
	var g: Node = script.new()
	g.call("setup_persistence", fs, PackedStringArray())
	var c: RunController = g.get("controller")
	c.last_run_path = TEST_RUN_PATH
	return g


func _free(g: Node) -> void:
	var a: Node = g.get("audio")
	a.free()
	g.free()


func _spy(g: Node) -> SpyService:
	var old: SaveService = g.get("saves")
	var spy: SpyService = SpyService.new(fs, old.clock, "dev")
	@warning_ignore("return_value_discarded")
	spy.load_profile()
	g.set("saves", spy)
	var ctrl: RunController = g.get("controller")
	spy.attach(ctrl)
	return spy


func test_pause_and_back_request_save_now_and_focus_out_does_not_on_desktop() -> void:
	var g: Node = _game()
	var spy: SpyService = _spy(g)
	g.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_int(spy.saves_called).is_equal(1)
	g.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_int(spy.saves_called).is_equal(2)
	g.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_int(spy.saves_called).is_equal(3)
	g.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_int(spy.saves_called).is_equal(3)  # desktop build: focus changes do not save
	_free(g)


func test_normal_run_death_banks_and_the_file_has_it() -> void:
	var g: Node = _game()
	g.call("start_run")
	var c: RunController = g.get("controller")
	assert_int(c.run_id).is_equal(1)
	@warning_ignore("return_value_discarded")
	c.fast_forward(MAX_TICKS)
	var s: SaveService = g.get("saves")
	assert_bool(s.last_bank_saved).is_true()
	var reloaded: SaveService = SaveService.new(fs, FakeClock.new(5), "x")
	@warning_ignore("return_value_discarded")
	reloaded.load_profile()
	assert_int(reloaded.profile.best_wave_s1()).is_equal(c.world.run.death_wave)
	assert_str(reloaded.profile.data.to_text()).is_equal(c.world.economy.data_run.to_text())
	_free(g)


func test_debug_load_run_never_banks_or_checkpoints() -> void:
	var g: Node = _game()
	var c: RunController = g.get("controller")
	@warning_ignore("return_value_discarded")
	c.start_run(1, true, 5)
	var s: SaveService = g.get("saves")
	assert_bool(s.checkpoint_now()).is_false()
	assert_bool(c.banks_rewards()).is_false()
	assert_bool(fs.exists("run_snapshot.sav")).is_false()
	_free(g)


func test_boot_resume_lands_paused_and_pause_checkpoints() -> void:
	var g: Node = _game()
	g.call("start_run")
	var c: RunController = g.get("controller")
	@warning_ignore("return_value_discarded")
	c.fast_forward(600)
	var s: SaveService = g.get("saves")
	assert_bool(s.checkpoint_now()).is_true()
	var hash_at: String = c.world.state_hash()
	_free(g)
	var g2: Node = _game()  # boot after the kill
	var c2: RunController = g2.get("controller")
	g2.call("start_run")  # main.gd's boot call resumes instead of starting
	assert_int(c2.state).is_equal(RunController.State.IN_RUN)
	assert_bool(c2.paused).is_true()
	assert_str(c2.world.state_hash()).is_equal(hash_at)
	assert_int(c2.run_id).is_equal(1)
	assert_str(g2.get("notice")).is_equal("save.resumed")
	_free(g2)


func test_snapshot_cleared_only_after_profile_save_ordering() -> void:
	var g: Node = _game()
	g.call("start_run")
	var c: RunController = g.get("controller")
	@warning_ignore("return_value_discarded")
	c.fast_forward(300)
	var s: SaveService = g.get("saves")
	assert_bool(s.checkpoint_now()).is_true()
	# the profile write fails (fault injected on the first mutating op): the snapshot must survive
	fs.fail_at(1)
	@warning_ignore("return_value_discarded")
	c.fast_forward(MAX_TICKS)
	assert_bool(s.last_bank_saved).is_false()
	assert_bool(fs.exists("run_snapshot.sav")).is_true()
	fs.clear_faults()
	assert_bool(s.save_now()).is_true()
	_free(g)
