class_name TestPurgeClock
extends GdUnitTestSuite
## PURGE wave-end rule (M4-03, Q72/Q73): quota cleared or backstop; the TIMED path is untouched.

const TIMED_TICKS: int = 2200
## State hash of the TIMED scenario below, recorded on main (83139a6) before M4-03 touched sim_world.gd.
const TIMED_HASH_BEFORE: String = "9ca563d42d03637e84b1c135c74d6d6f0d7a01105dbd3fefa0bba3a8773f3eb7"
const BACKSTOP: int = 900
const HUGE_HP: float = 1.0e30

var _cursor: int = 0
var _purged: Array[int] = []  ## b of each WAVE_PURGED seen, in order
var _order_ok: bool = true  ## every WAVE_PURGED was directly followed by WAVE_ENDED of the same wave


func before_test() -> void:
	_cursor = 0
	_purged.clear()
	_order_ok = true


func _cfg(mode: String, seed_value: int = 1) -> SimConfig:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	cfg.debug_invulnerable = true
	cfg.wave_mode = mode
	cfg.purge_backstop_ticks = BACKSTOP if mode == "purge" else 0
	return cfg


func _step(w: SimWorld) -> void:
	w.step()
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(SimEvents.CAPACITY * SimEvents.FIELDS)).is_equal(OK)
	var new_cursor: int = w.events.drain(_cursor, out)
	var n: int = new_cursor - _cursor
	_cursor = new_cursor
	for k: int in n:
		if out[k * SimEvents.FIELDS + 1] == SimEventKind.WAVE_PURGED:
			_purged.append(out[k * SimEvents.FIELDS + 3])
			var nxt: int = (k + 1) * SimEvents.FIELDS
			if k + 1 >= n or out[nxt + 1] != SimEventKind.WAVE_ENDED or out[nxt + 2] != out[k * SimEvents.FIELDS + 2]:
				_order_ok = false


## Marks the whole current plan spawned and removes every living enemy except `keep`.
func _clear_wave(w: SimWorld, keep: int = -1) -> void:
	for i: int in w.plan.count:
		w.plan.spawned[i] = 1
	w.plan.cursor = w.plan.count
	for i: int in w.enemies.high_water:
		if w.enemies.alive[i] != 0 and i != keep:
			w.enemies.release(i)


func _timed_hash() -> String:
	var w: SimWorld = SimWorld.new(_cfg("timed"))
	for i: int in TIMED_TICKS:
		w.step()
	return w.state_hash()


func test_timed_scenario_hash_is_unchanged() -> void:
	assert_str(_timed_hash()).is_equal(TIMED_HASH_BEFORE)


func test_timed_ignores_purge_fields_and_still_ends_at_720() -> void:
	var cfg: SimConfig = _cfg("timed")
	cfg.purge_backstop_ticks = 100  # never read in TIMED
	var w: SimWorld = SimWorld.new(cfg)
	for i: int in 400:
		_step(w)
	_clear_wave(w)
	for i: int in 319:
		_step(w)
	assert_int(w.wave).is_equal(1)
	_step(w)
	assert_int(w.wave).is_equal(2)
	assert_int(w.tick).is_equal(720)
	assert_int(_purged.size()).is_equal(0)


func test_cleared_wave_ends_at_once_and_next_wave_starts_next_tick() -> void:
	var w: SimWorld = SimWorld.new(_cfg("purge"))
	for i: int in 399:
		_step(w)
	assert_int(w.wave).is_equal(1)
	assert_bool(w.plan.remaining_unspawned() > 0).is_true()
	assert_int(PurgeClock.remaining_quota(w)).is_greater(0)
	_clear_wave(w)
	assert_int(PurgeClock.remaining_quota(w)).is_equal(0)
	_step(w)  # tick 400
	assert_int(w.wave).is_equal(2)
	assert_int(w.wave_tick).is_equal(0)
	assert_int(w.tick).is_equal(400)
	assert_array(_purged).is_equal([400])
	assert_bool(_order_ok).is_true()
	_step(w)  # no lull: wave 2 is already running
	assert_int(w.wave).is_equal(2)
	assert_int(w.wave_tick).is_equal(1)
	assert_bool(w.plan.built).is_true()
	assert_int(w.level_hp).is_equal(2)


func test_surviving_enemy_ends_wave_at_backstop_and_carries_over() -> void:
	var w: SimWorld = SimWorld.new(_cfg("purge"))
	var stub: int = w.debug_spawn_enemy(0, 30.0, 0.0)
	w.enemies.hp[stub] = HUGE_HP
	w.enemies.max_hp[stub] = HUGE_HP
	for i: int in 100:
		_step(w)
	_clear_wave(w, stub)
	assert_int(PurgeClock.remaining_quota(w)).is_equal(1)
	for i: int in BACKSTOP - 101:
		_step(w)
	assert_int(w.wave).is_equal(1)
	assert_int(w.wave_tick).is_equal(BACKSTOP - 1)
	_step(w)
	assert_int(w.wave).is_equal(2)
	assert_int(w.tick).is_equal(BACKSTOP)
	assert_int(_purged.size()).is_equal(0)
	assert_bool(w.enemies.is_alive(stub)).is_true()
	assert_int(w.enemies.born_wave[stub]).is_equal(1)
	assert_int(w.enemies.stale[stub]).is_equal(0)
	# Older enemies do not block wave 2: with its own quota gone it ends by clearing.
	_step(w)
	_clear_wave(w, stub)
	_step(w)
	assert_int(w.wave).is_equal(3)
	assert_array(_purged).is_equal([2])


func test_unspawned_entries_carry_over_on_backstop() -> void:
	var cfg: SimConfig = _cfg("purge")
	cfg.tuning.alive_cap_normal = 1  # one enemy at a time: the plan cannot spawn within the backstop
	var w: SimWorld = SimWorld.new(cfg)
	var stub: int = w.debug_spawn_enemy(0, 30.0, 0.0)
	w.enemies.hp[stub] = HUGE_HP  # holds the only normal slot for the whole wave
	w.enemies.max_hp[stub] = HUGE_HP
	for i: int in BACKSTOP:
		_step(w)
	assert_int(w.wave).is_equal(2)
	var left: int = w.plan.remaining_unspawned()
	assert_int(left).is_greater(0)
	assert_int(_purged.size()).is_equal(0)
	_step(w)  # the next wave's first tick carries them over
	assert_int(w.plan.carried).is_equal(left)


func test_entries_blocked_by_the_alive_caps_keep_the_wave_open() -> void:
	var cfg: SimConfig = _cfg("purge", 2)
	cfg.purge_backstop_ticks = 100000
	cfg.tuning.alive_cap_normal = 2
	var w: SimWorld = SimWorld.new(cfg)
	var held_open: bool = false
	for i: int in 20000:
		if w.wave != 1:
			break
		if w.wave_tick > 560 and w.plan.remaining_unspawned() > 0:
			held_open = true  # every entry is due by 540, yet the wave stays open
		_step(w)
	assert_int(w.wave).is_equal(2)
	assert_bool(held_open).is_true()
	assert_int(_purged.size()).is_equal(1)
	assert_int(_purged[0]).is_greater(560)


func test_boss_wave_ends_only_after_the_boss_is_dead() -> void:
	var cfg: SimConfig = _cfg("purge")
	cfg.tuning.boss_interval = 1  # every wave is a boss wave
	var w: SimWorld = SimWorld.new(cfg)
	var boss: int = -1
	for i: int in 70:
		_step(w)
	for e: int in w.enemies.high_water:
		if w.enemies.alive[e] != 0 and w.type_is_boss[w.enemies.type_id[e]] != 0:
			boss = e
	assert_int(boss).is_greater(-1)
	w.enemies.hp[boss] = HUGE_HP
	w.enemies.max_hp[boss] = HUGE_HP
	for i: int in 600:  # past the 540-tick spawn window, every normal enemy removed each tick
		_step(w)
		_clear_wave(w, boss)
	assert_int(w.wave).is_equal(1)
	assert_bool(w.enemies.is_alive(boss)).is_true()
	w.enemies.release(boss)
	_step(w)
	assert_int(w.wave).is_equal(2)
	assert_int(_purged.size()).is_equal(1)


func test_purge_run_to_wave_15_is_identical_at_1_and_4_ticks_per_frame() -> void:
	var plain: SimWorld = SimWorld.new(_cfg("purge", 5))
	while plain.wave < 15 and not plain.is_over() and plain.tick < 60000:
		@warning_ignore("return_value_discarded")  # a draft takes the first offer (M4-15)
		PolicyBot.settle_draft(plain)
		plain.step()
	assert_int(plain.wave).is_equal(15)
	var one: String = _driven_hash(1, plain.tick)
	assert_str(one).is_equal(plain.state_hash())
	assert_str(_driven_hash(4, plain.tick)).is_equal(one)


func _driven_hash(speed: int, limit: int) -> String:
	var w: SimWorld = SimWorld.new(_cfg("purge", 5))
	var driver: TickDriver = TickDriver.new()
	driver.budget_usec = 1_000_000_000
	driver.tick_limit = limit
	var guard: int = 0
	while w.tick < limit and guard < 1_000_000:
		@warning_ignore("return_value_discarded")
		PolicyBot.settle_draft(w)
		@warning_ignore("return_value_discarded")
		driver.advance(w, SimWorld.DT + 0.0001, speed)
		guard += 1
	assert_int(w.tick).is_equal(limit)
	return w.state_hash()
