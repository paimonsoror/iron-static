class_name TestAudioEventRouterA108
extends GdUnitTestSuite
## A1-08 router additions: boss death, skin burn on band change, band-3 heartbeat cadence, x25 milestone, results
## tally, and the slot table covering every sound id of the 07 section 7 list.

const ALL_IDS: PackedStringArray = [
	"sfx_laser_shot",
	"sfx_hit_metal",
	"sfx_crit",
	"sfx_overcrit",
	"sfx_enemy_death_small",
	"sfx_enemy_death_heavy",
	"sfx_player_hit",
	"sfx_integrity_warn",
	"sfx_skin_burn",
	"sfx_wave_start",
	"sfx_boss_warn",
	"sfx_boss_death",
	"sfx_upgrade_buy",
	"sfx_milestone_x15",
	"sfx_draft_open",
	"sfx_draft_pick",
	"sfx_cache_open",
	"sfx_pod_heal",
	"sfx_razor_spin",
	"sfx_shock_ring",
	"sfx_mine_beep",
	"sfx_arc",
	"sfx_emp",
	"sfx_missile_launch",
	"sfx_singularity",
	"sfx_dilation",
	"sfx_nanite",
	"sfx_overdrive_on",
	"sfx_overdrive_off",
	"sfx_aegis_break",
	"sfx_reboot",
	"sfx_meltdown",
	"sfx_purge",
	"sfx_ui_tap",
	"sfx_ui_deny",
	"sfx_lab_complete",
	"sfx_firmware_pick",
	"sfx_gauntlet_rank_up",
	"sfx_death",
	"sfx_results_tally",
]

var _world: SimWorld
var _spy: SpyAudioDirector
var _router: AudioEventRouter


func before_test() -> void:
	_world = SimWorld.new(SimConfigLoader.load_default(1))
	_spy = auto_free(SpyAudioDirector.new())
	_router = AudioEventRouter.new(_spy)
	_router.bind(_world)


func _type_index(enemy_id: String) -> int:
	for i: int in _world.config.enemies.size():
		if _world.config.enemies[i].id == enemy_id:
			return i
	return -1


func _beats(seconds: float, step_ticks: int) -> int:
	var ticks: int = roundi(seconds / SimWorld.DT)
	var done: int = 0
	while done < ticks:
		_world.tick += step_ticks
		done += step_ticks
		_router.update()
	return _spy.count("sfx_integrity_warn")


func test_boss_kill_plays_boss_death_not_heavy() -> void:
	var boss: int = _type_index("boss_hulk")
	assert_int(boss).is_greater_equal(0)
	_world.events.push(SimEventKind.ENEMY_KILLED, 3, boss)
	_world.events.push(SimEventKind.ENEMY_KILLED, 4, _type_index("walker"))
	_router.update()
	assert_array(_spy.sfx).contains_exactly(["sfx_boss_death", "sfx_enemy_death_heavy"])


func test_skin_burn_only_on_a_worse_band() -> void:
	_world.events.push(SimEventKind.BAND_CHANGED, 0, 1)
	_world.events.push(SimEventKind.BAND_CHANGED, 1, 2)
	_world.events.push(SimEventKind.BAND_CHANGED, 2, 1)  # regeneration: silent
	_router.update()
	assert_int(_spy.count("sfx_skin_burn")).is_equal(2)


func test_milestone_on_multiples_of_25_only() -> void:
	for level: int in [1, 24, 25, 26, 49, 50]:
		_world.events.push(SimEventKind.UPGRADE_BOUGHT, 0, level)
	_router.update()
	assert_int(_spy.count("sfx_milestone_x15")).is_equal(2)


func test_no_heartbeat_below_band_3() -> void:
	_world.cinder.band = 2
	assert_int(_beats(6.0, 1)).is_equal(0)


func test_heartbeat_follows_the_visual_clock_at_band_3() -> void:
	_world.cinder.band = 3
	_router.update()  # arms the clock: the first sound is the next beat, not an immediate one
	assert_int(_spy.count("sfx_integrity_warn")).is_equal(0)
	var beats: int = _beats(10.0, 1)
	assert_int(beats).is_between(11, 13)  # 1.2 Hz over 10 s


func test_heartbeat_is_silent_while_the_sim_is_frozen() -> void:
	_world.cinder.band = 3
	_router.update()
	for i: int in 120:
		_router.update()  # tick does not advance (pause)
	assert_int(_spy.count("sfx_integrity_warn")).is_equal(0)


func test_heartbeat_does_not_double_at_high_frame_steps() -> void:
	_world.cinder.band = 3
	_router.update()
	var beats: int = _beats(10.0, 4)  # 4 ticks per frame (speed 4x)
	assert_int(beats).is_between(11, 13)


func test_leaving_band_3_stops_and_rearms() -> void:
	_world.cinder.band = 3
	_router.update()
	var first: int = _beats(3.0, 1)
	_world.cinder.band = 1
	assert_int(_beats(3.0, 1)).is_equal(first)
	_world.cinder.band = 3
	_router.update()
	assert_int(_spy.count("sfx_integrity_warn")).is_equal(first)  # the first beat after re-entry is not instant


func test_results_tally() -> void:
	_router.play_results_tally()
	_router.play_results_tally(false)
	assert_array(_spy.sfx).contains_exactly(["sfx_results_tally"])


func test_slot_table_has_every_07_sound_with_a_loadable_file() -> void:
	AudioSlots.error_count = 0
	for sid: String in ALL_IDS:
		assert_bool(AudioSlots.has(sid)).override_failure_message(sid).is_true()
		assert_object(AudioSlots.stream(sid)).override_failure_message(sid).is_not_null()
		assert_float(AudioSlots.slot(sid).volume_db).is_less_equal(6.0)
	assert_int(AudioSlots.error_count).is_equal(0)
