class_name TestBossWarning
extends GdUnitTestSuite
## BOSS_WARNING (M4-17): 45 ticks before the boss entry is due, a = spawn angle, presentation only.

const BOSS: int = 4


func _world(wave: int) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(7)
	cfg.debug_invulnerable = true
	var w := SimWorld.new(cfg)
	w.wave = wave
	return w


## (tick, a, b) triples of the events of kind `kind` pushed so far.
func _events_of(w: SimWorld, kind: int) -> Array[PackedInt32Array]:
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(SimEvents.CAPACITY * SimEvents.FIELDS)).is_equal(OK)
	var n: int = w.events.drain(0, out)
	var found: Array[PackedInt32Array] = []
	for k: int in n:
		if out[k * 4 + 1] == kind:
			found.append(PackedInt32Array([out[k * 4], out[k * 4 + 2], out[k * 4 + 3]]))
	return found


func test_kind_is_appended_after_the_draft_events() -> void:
	assert_int(SimEventKind.BOSS_WARNING).is_equal(14)
	assert_int(SimEventKind.COUNT).is_equal(15)


func test_waves_until_boss() -> void:
	var w: SimWorld = _world(1)
	var expect: Dictionary = {1: 9, 6: 4, 7: 3, 8: 2, 9: 1, 10: 10, 11: 9, 19: 1, 20: 10}
	for wave: int in expect:
		w.wave = wave
		assert_int(w.waves_until_boss()).is_equal(expect[wave])
	w.config.tuning.boss_interval = 0
	assert_int(w.waves_until_boss()).is_equal(-1)


func test_warning_fires_45_ticks_before_the_boss_spawns() -> void:
	var w: SimWorld = _world(10)
	for i: int in 140:
		w.step()
	var warns: Array[PackedInt32Array] = _events_of(w, SimEventKind.BOSS_WARNING)
	var spawns: Array[PackedInt32Array] = _events_of(w, SimEventKind.BOSS_SPAWNED)
	assert_int(warns.size()).is_equal(1)
	assert_int(spawns.size()).is_equal(1)
	assert_int(spawns[0][0] - warns[0][0]).is_equal(SpawnSystem.BOSS_WARN_TICKS)
	assert_int(warns[0][2]).is_equal(SpawnSystem.BOSS_WARN_TICKS)  # b = lead ticks
	var boss_angle: int = -1
	for i: int in w.plan.count:
		if w.plan.type_index[i] == BOSS:
			boss_angle = w.plan.angle_idx[i]
	assert_int(warns[0][1]).is_equal(boss_angle)


func test_no_warning_on_normal_waves() -> void:
	for wave: int in [1, 7, 9, 11]:
		var w: SimWorld = _world(wave)
		for i: int in 150:
			w.step()
		assert_int(_events_of(w, SimEventKind.BOSS_WARNING).size()).is_equal(0)


func test_early_boss_clamps_the_warning_to_wave_tick_zero() -> void:
	var w: SimWorld = _world(10)
	w.plan.begin(10)
	@warning_ignore("return_value_discarded")
	WavePlanner.build(w)
	for i: int in w.plan.count:
		if w.plan.type_index[i] == BOSS:
			w.plan.spawn_tick[i] = 20
	w.wave_tick = 0
	SpawnSystem.step(w)
	var warns: Array[PackedInt32Array] = _events_of(w, SimEventKind.BOSS_WARNING)
	assert_int(warns.size()).is_equal(1)
	assert_int(warns[0][2]).is_equal(20)


func test_view_listener_does_not_change_the_state_hash() -> void:
	var a: SimWorld = _world(10)
	var b: SimWorld = _world(10)
	var view: HudBossWarning = auto_free(HudBossWarning.new())
	for i: int in 150:
		a.step()
		b.step()
		view.update(b, Rect2(0.0, 200.0, 1080.0, 1200.0), Vector2.ZERO)
	assert_str(b.state_hash()).is_equal(a.state_hash())
