class_name TestAudioEventRouter
extends GdUnitTestSuite
## AudioEventRouter (A1-05, A1-07): event kind -> sound id mapping on a synthetic ring, crit pairing, heavy vs small
## deaths, ring overrun, per-frame caps, and the music state derived from a world.

var _world: SimWorld
var _spy: SpyAudioDirector
var _router: AudioEventRouter


func before_test() -> void:
	_world = SimWorld.new(SimConfigLoader.load_default(1))
	_spy = auto_free(SpyAudioDirector.new())
	_router = AudioEventRouter.new(_spy)
	_router.bind(_world)


func _push(kind: int, a: int = 0, b: int = 0) -> void:
	_world.events.push(kind, a, b)


func test_bind_starts_music_with_in_run_state() -> void:
	assert_int(_spy.music_starts).is_equal(1)
	assert_int(_spy.states.size()).is_equal(1)
	assert_bool(_spy.states[0].in_menu).is_false()
	assert_int(_spy.states[0].wave).is_equal(_world.wave)


func test_simple_mapping() -> void:
	_push(SimEventKind.CINDER_HIT, 5, 0)
	_push(SimEventKind.WAVE_STARTED, 2)
	_push(SimEventKind.BOSS_WARNING, 3, 45)
	_push(SimEventKind.BOSS_SPAWNED, 3)  # silent: the drone already played at the warning
	_push(SimEventKind.RUN_ENDED, 4, -1)
	_push(SimEventKind.SHOT_FIRED, 1, 0)
	_router.update()
	assert_array(_spy.sfx).contains_exactly(
		["sfx_player_hit", "sfx_wave_start", "sfx_boss_warn", "sfx_death", "sfx_laser_shot"]
	)


func test_shot_uses_small_jitter() -> void:
	_push(SimEventKind.SHOT_FIRED, 1, 0)
	_router.update()
	assert_float(_spy.jitters[0]).is_equal(AudioEventRouter.SHOT_JITTER)


func test_normal_hit_and_crit_hit() -> void:
	# The sim pushes SHOT_FIRED(enemy, crit) right before ENEMY_HIT(enemy, damage).
	_push(SimEventKind.SHOT_FIRED, 7, 0)
	_push(SimEventKind.ENEMY_HIT, 7, 10)
	_push(SimEventKind.SHOT_FIRED, 8, 1)
	_push(SimEventKind.ENEMY_HIT, 8, 30)
	_push(SimEventKind.SHOT_FIRED, 9, 0)
	_push(SimEventKind.ENEMY_HIT, 9, 10)
	_router.update()
	assert_int(_spy.count("sfx_crit")).is_equal(1)
	assert_int(_spy.count("sfx_hit_metal")).is_equal(2)
	assert_int(_spy.count("sfx_laser_shot")).is_equal(3)


func test_laser_sound_off_silences_the_shot_and_its_impact() -> void:
	_spy.settings.laser_sound = false
	_push(SimEventKind.SHOT_FIRED, 7, 0)
	_push(SimEventKind.ENEMY_HIT, 7, 10)
	_push(SimEventKind.SHOT_FIRED, 8, 1)
	_push(SimEventKind.ENEMY_HIT, 8, 30)
	_push(SimEventKind.SHOT_FIRED, 9, 0)
	_push(SimEventKind.ENEMY_KILLED, 9, 0)
	_router.update()
	assert_int(_spy.count("sfx_laser_shot")).is_equal(0)
	assert_int(_spy.count("sfx_crit")).is_equal(0)
	assert_int(_spy.count("sfx_hit_metal")).is_equal(0)
	# Kills are not part of the per-shot chain and still play.
	assert_int(_spy.count("sfx_enemy_death_small")).is_equal(1)
	# Switching it back on takes effect at once, and crit pairing still works after the silent stretch.
	_spy.settings.laser_sound = true
	_push(SimEventKind.SHOT_FIRED, 1, 1)
	_push(SimEventKind.ENEMY_HIT, 1, 30)
	_push(SimEventKind.SHOT_FIRED, 2, 0)
	_push(SimEventKind.ENEMY_HIT, 2, 10)
	_router.update()
	assert_int(_spy.count("sfx_laser_shot")).is_equal(2)
	assert_int(_spy.count("sfx_crit")).is_equal(1)
	assert_int(_spy.count("sfx_hit_metal")).is_equal(1)


func test_crit_pairing_survives_a_frame_boundary() -> void:
	_push(SimEventKind.SHOT_FIRED, 4, 1)
	_router.update()
	_push(SimEventKind.ENEMY_HIT, 4, 30)
	_router.update()
	assert_int(_spy.count("sfx_crit")).is_equal(1)


func test_heavy_vs_small_deaths_follow_the_enemy_ids() -> void:
	var small: int = 0
	var heavy: int = 0
	for i: int in _world.config.enemies.size():
		var id: String = _world.config.enemies[i].id
		if id == "skitter":
			small = i
		if id == "walker":
			heavy = i
	_push(SimEventKind.ENEMY_KILLED, 1, small)
	_push(SimEventKind.ENEMY_KILLED, 2, heavy)
	_router.update()
	assert_array(_spy.sfx).contains_exactly(["sfx_enemy_death_small", "sfx_enemy_death_heavy"])


func test_every_enemy_type_is_classified() -> void:
	var table: PackedByteArray = AudioEventRouter.heavy_table(_world.config.enemies)
	for i: int in _world.config.enemies.size():
		var id: String = _world.config.enemies[i].id
		var want: bool = ["walker", "lancer", "boss_hulk"].has(id)
		assert_bool(table[i] != 0).override_failure_message(id).is_equal(want)
	assert_bool(AudioEventRouter.is_heavy("dart")).is_false()
	assert_bool(AudioEventRouter.is_heavy("boss_anything")).is_true()


func test_per_frame_cap_per_id() -> void:
	for i: int in 30:
		_push(SimEventKind.SHOT_FIRED, i, 0)
	_router.update()
	assert_int(_spy.count("sfx_laser_shot")).is_equal(AudioEventRouter.CAP_PER_FRAME)
	_router.update()  # next frame has a fresh budget but nothing new to read
	assert_int(_spy.count("sfx_laser_shot")).is_equal(AudioEventRouter.CAP_PER_FRAME)


func test_ring_overrun_does_not_crash_and_keeps_newest() -> void:
	for i: int in SimEvents.CAPACITY * 3:
		_push(SimEventKind.CINDER_HIT, i, 0)
	_push(SimEventKind.WAVE_STARTED, 9)
	_router.update()
	assert_int(_spy.count("sfx_player_hit")).is_equal(AudioEventRouter.CAP_PER_FRAME)
	assert_int(_spy.count("sfx_wave_start")).is_equal(1)  # the newest events are kept
	var before: int = _spy.sfx.size()
	_router.update()
	assert_int(_spy.sfx.size()).is_equal(before)  # nothing replays on the next frame


func test_deep_backlog_is_dropped_not_queued() -> void:
	var n: int = AudioEventRouter.MAX_BATCHES * EventCursor.BATCH + 100
	for i: int in n:
		_push(SimEventKind.WAVE_STARTED, i)  # fits the ring (n < 1024); the oldest 100 are skipped
	_push(SimEventKind.RUN_ENDED, 1, -1)
	_router.update()
	assert_int(_spy.count("sfx_death")).is_equal(1)
	assert_int(_spy.count("sfx_wave_start")).is_equal(AudioEventRouter.CAP_PER_FRAME)
	var before: int = _spy.sfx.size()
	_router.update()
	assert_int(_spy.sfx.size()).is_equal(before)


func test_skip_drops_pending_events_silently() -> void:
	_push(SimEventKind.WAVE_STARTED, 2)
	_router.skip()
	_router.update()
	assert_int(_spy.sfx.size()).is_equal(0)


func test_music_state_from_world() -> void:
	_world.wave = 12
	_world.cinder.band = 2
	var s: MusicState = AudioEventRouter.music_state(_world, false)
	assert_int(s.wave).is_equal(12)
	assert_int(s.integrity_band).is_equal(2)
	assert_bool(s.boss_active).is_false()
	assert_bool(s.in_menu).is_false()
	var boss: int = 0
	for i: int in _world.config.enemies.size():
		if _world.type_is_boss[i] != 0:
			boss = i
	@warning_ignore("return_value_discarded")
	_world.enemies.alloc(boss)
	assert_bool(AudioEventRouter.music_state(_world, false).boss_active).is_true()
	assert_bool(AudioEventRouter.music_state(_world, true).in_menu).is_true()


func test_update_pushes_music_state_only_on_change() -> void:
	var base: int = _spy.states.size()
	_router.update()
	_router.update()
	assert_int(_spy.states.size()).is_equal(base)
	_world.wave = 10
	_router.update()
	assert_int(_spy.states.size()).is_equal(base + 1)
	assert_int(_spy.states[base].wave).is_equal(10)
	_world.cinder.band = 3
	_router.update()
	assert_int(_spy.states[base + 1].integrity_band).is_equal(3)


func test_menu_flag_and_redeploy_reset() -> void:
	_router.in_menu = true
	_router.update()
	assert_bool(_spy.states[_spy.states.size() - 1].in_menu).is_true()
	var other: SimWorld = SimWorld.new(SimConfigLoader.load_default(2))
	_router.bind(other)  # redeploy
	assert_bool(_spy.states[_spy.states.size() - 1].in_menu).is_false()
	assert_int(_spy.music_starts).is_equal(2)  # start_music is idempotent in the real director
