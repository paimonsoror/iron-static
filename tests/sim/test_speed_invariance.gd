class_name TestSpeedInvariance
extends GdUnitTestSuite
## Game speed only changes ticks per frame, never outcomes (M1-15 item 2) and TickDriver limits (item 4).

const TICKS: int = 3000
const DRAFT_TICKS: int = 8000  ## past the wave 10 draft (tick 7200)
const FRAME_MIN_S: float = 0.005
const FRAME_MAX_S: float = 0.040
const NO_BUDGET_LIMIT: int = 1_000_000_000


func _world() -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(5)
	cfg.debug_invulnerable = true
	return SimWorld.new(cfg)


func _driven_hash(speed: int, frame_seed: int) -> String:
	var w: SimWorld = _world()
	var driver: TickDriver = TickDriver.new()
	driver.budget_usec = NO_BUDGET_LIMIT  # this test is about ordering, not timing
	driver.tick_limit = TICKS
	var frames: Rng = Rng.new(frame_seed, 99)
	var guard: int = 0
	while w.tick < TICKS and guard < 1_000_000:
		var delta: float = FRAME_MIN_S + frames.next_float() * (FRAME_MAX_S - FRAME_MIN_S)
		@warning_ignore("return_value_discarded")  # tick count not needed here
		driver.advance(w, delta, speed)
		guard += 1
	assert_int(w.tick).is_equal(TICKS)
	return w.state_hash()


func test_speeds_1_to_4_give_the_same_hash() -> void:
	var base: String = _driven_hash(1, 11)
	assert_str(_driven_hash(2, 12)).is_equal(base)
	assert_str(_driven_hash(3, 13)).is_equal(base)
	assert_str(_driven_hash(4, 14)).is_equal(base)


func test_matches_plain_stepping() -> void:
	var w: SimWorld = _world()
	for i: int in TICKS:
		w.step()
	assert_str(_driven_hash(4, 21)).is_equal(w.state_hash())


func test_zero_budget_drops_ticks_and_never_exceeds_cap() -> void:
	var w: SimWorld = _world()
	var driver: TickDriver = TickDriver.new()
	driver.budget_usec = 0
	var ran: int = driver.advance(w, 0.2, 4)  # 24 ticks due
	assert_int(ran).is_between(1, TickDriver.MAX_TICKS_PER_FRAME)
	assert_bool(driver.throttled).is_true()
	assert_int(w.tick).is_equal(ran)
	assert_float(driver.acc).is_less(TickDriver.DT)


func test_cap_of_8_ticks_per_call_sets_throttled() -> void:
	var w: SimWorld = _world()
	var driver: TickDriver = TickDriver.new()
	driver.budget_usec = NO_BUDGET_LIMIT
	var ran: int = driver.advance(w, 1.0, 4)
	assert_int(ran).is_equal(TickDriver.MAX_TICKS_PER_FRAME)
	assert_bool(driver.throttled).is_true()
	ran = driver.advance(w, 1.0 / 30.0 + 0.0001, 1)
	assert_int(ran).is_equal(1)
	assert_bool(driver.throttled).is_false()


func test_fractional_time_accumulates() -> void:
	var w: SimWorld = _world()
	var driver: TickDriver = TickDriver.new()
	driver.budget_usec = NO_BUDGET_LIMIT
	var total: int = 0
	for i: int in 30:
		total += driver.advance(w, 0.01, 1)  # 0.3 s of frame time
	assert_int(total).is_between(8, 9)
	assert_int(w.tick).is_equal(total)


func _purge_driven_hash(speed: int, frame_seed: int) -> String:
	var cfg: SimConfig = SimConfigLoader.load_default(5)
	assert_int(SimConfigLoader.apply_mode(cfg, "purge").size()).is_equal(0)
	cfg.debug_invulnerable = true
	var w: SimWorld = SimWorld.new(cfg)
	var driver: TickDriver = TickDriver.new()
	driver.budget_usec = NO_BUDGET_LIMIT
	driver.tick_limit = TICKS
	var frames: Rng = Rng.new(frame_seed, 99)
	var guard: int = 0
	while w.tick < TICKS and guard < 1_000_000:
		var delta: float = FRAME_MIN_S + frames.next_float() * (FRAME_MAX_S - FRAME_MIN_S)
		@warning_ignore("return_value_discarded")
		driver.advance(w, delta, speed)
		guard += 1
	assert_int(w.tick).is_equal(TICKS)
	return w.state_hash()


func test_purge_speeds_1_2_4_give_the_same_hash() -> void:
	var base: String = _purge_driven_hash(1, 11)
	assert_str(_purge_driven_hash(2, 12)).is_equal(base)
	assert_str(_purge_driven_hash(4, 14)).is_equal(base)
	assert_str(base).is_not_equal(_driven_hash(1, 11))  # PURGE really is a different run than TIMED


## Driven past the wave 10 draft; the pick (slot 1) is made between frames, never inside `advance` (M4-15).
func _draft_driven_hash(speed: int, frame_seed: int) -> String:
	var w: SimWorld = _world()
	var driver: TickDriver = TickDriver.new()
	driver.budget_usec = NO_BUDGET_LIMIT
	driver.tick_limit = DRAFT_TICKS
	var frames: Rng = Rng.new(frame_seed, 99)
	var guard: int = 0
	var picks: int = 0
	while w.tick < DRAFT_TICKS and guard < 1_000_000:
		if w.is_draft_open():
			assert_bool(w.command_pick(1)).is_true()
			picks += 1
		var delta: float = FRAME_MIN_S + frames.next_float() * (FRAME_MAX_S - FRAME_MIN_S)
		@warning_ignore("return_value_discarded")
		driver.advance(w, delta, speed)
		guard += 1
	assert_int(picks).is_equal(1)
	assert_int(w.tick).is_equal(DRAFT_TICKS)
	return w.state_hash()


func test_speeds_give_the_same_hash_across_a_draft_pick() -> void:
	var base: String = _draft_driven_hash(1, 11)
	assert_str(_draft_driven_hash(2, 12)).is_equal(base)
	assert_str(_draft_driven_hash(4, 14)).is_equal(base)
