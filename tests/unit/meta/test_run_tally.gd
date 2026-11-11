class_name TestRunTally
extends GdUnitTestSuite
## Service Record counting (lifetime stats): the run tally against an independent count of the sim's event stream, the
## per-type kills and totals of a banked run, a checkpoint resume that neither loses nor double counts, and the
## idempotent bank. (There is no offline or idle catch-up simulation in the game: a run only advances while it is
## played, so nothing else feeds the record.)

const RUN_PATH: String = "user://runs/test_run_tally.json"
const MAX_TICKS: int = 60000
const SEED: int = 7


## One tick; an open patch draft (the sim waits for a pick) takes its first offer, as the controller does.
func _step(w: SimWorld) -> void:
	if w.is_draft_open():
		@warning_ignore("return_value_discarded")
		w.command_pick(0)
	w.step()


func _world(scrap: float = 5.0e6) -> SimWorld:
	var w := SimWorld.new(SimConfigLoader.load_default(SEED))
	w.economy.scrap = BigNum.from_float(scrap)
	return w


## Counts SHOT_FIRED / crits / highest hit / hull damage straight from the ring slots `[from, to)` (no EventCursor).
## `acc` = [shots, crits, hit_max, hull].
func _oracle(w: SimWorld, from: int, to: int, acc: Array[int]) -> void:
	for n: int in range(from, to):
		var i: int = n & (SimEvents.CAPACITY - 1)
		var kind: int = w.events.kind[i]
		if kind == SimEventKind.SHOT_FIRED:
			acc[0] += 1
			acc[1] += w.events.b[i]
		elif kind == SimEventKind.ENEMY_HIT:
			acc[2] = maxi(acc[2], w.events.b[i])
		elif kind == SimEventKind.CINDER_HIT:
			acc[3] += w.events.a[i]


func test_event_totals_match_an_independent_count_and_the_scrap_balance() -> void:
	var w: SimWorld = _world()
	var tally := RunTally.new()
	tally.bind(w)
	var acc: Array[int] = [0, 0, 0, 0]
	var spent_oracle: BigNum = BigNum.zero()
	var rows: int = w.config.upgrades.size()
	for t: int in 2400:
		var from: int = w.events.total_pushed
		if t % 60 == 0:
			var before: BigNum = w.economy.scrap
			@warning_ignore("return_value_discarded")
			w.command_buy(floori(float(t) / 60.0) % rows, 1 if t % 120 == 0 else 10)
			spent_oracle = spent_oracle.add(before.sub_floor0(w.economy.scrap))
		_step(w)
		_oracle(w, from, w.events.total_pushed, acc)
		tally.poll(w)
	assert_int(tally.shots).is_equal(acc[0])
	assert_int(tally.shots).is_greater(10)
	assert_int(tally.crits).is_equal(acc[1])
	assert_int(tally.hit_max).is_equal(acc[2])
	assert_int(tally.hull).is_equal(acc[3])
	assert_int(tally.lost).is_equal(0)
	assert_bool(tally.exact()).is_true()
	# scrap spent equals the balance the buys really removed (the interest and kills only add)
	assert_float(tally.spent.to_float()).is_equal_approx(spent_oracle.to_float(), 0.5)
	assert_float(tally.spent.to_float()).is_greater(0.0)
	var bought: int = 0
	for lv: int in w.run_levels:
		bought += lv
	assert_int(tally.levels).is_equal(bought)


func test_totals_of_a_finished_world_hold_kills_per_type_and_derive_the_scrap_gain() -> void:
	var w: SimWorld = _world(2000.0)
	var tally := RunTally.new()
	tally.bind(w)
	var t: int = 0
	while not w.is_over() and t < MAX_TICKS:
		if t % 90 == 0 and t < 900:
			@warning_ignore("return_value_discarded")
			w.command_buy(floori(float(t) / 90.0) % w.config.upgrades.size(), 1)
		_step(w)
		tally.poll(w)
		t += 1
	assert_bool(w.is_over()).is_true()
	var s: RunSummary = SaveService.summary_from(w, 3, true)
	var totals: RunTotals = RunTotals.from_world(w, tally, s)
	assert_int(totals.detail).is_equal(RunTotals.Detail.FULL)
	var total_kills: int = 0
	for id: Variant in totals.kills.keys():
		var n: int = totals.kills[id]
		total_kills += n
	assert_int(total_kills).is_equal(w.run.kills)
	assert_int(total_kills).is_greater(0)
	assert_int(totals.waves_cleared).is_equal(maxi(w.run.death_wave - 1, 0))
	assert_float(totals.damage.to_float()).is_equal_approx(w.run.damage_dealt, 0.5)
	assert_int(totals.frame_id.length()).is_greater(0)
	# gain = end balance + spent - start: never below the kill scrap the sim counted (interest only adds)
	var kill_scrap: float = floorf(w.run.scrap_earned - w.economy.scrap_frac)
	assert_float(totals.scrap_in.to_float()).is_greater_equal(kill_scrap - 1.0)
	# waves cleared equals the WAVE_ENDED events of the run (counted by the tally-free oracle below)
	var w2: SimWorld = _world(2000.0)
	var ended: int = 0
	var hull_oracle: int = 0
	var tt: int = 0
	while not w2.is_over() and tt < MAX_TICKS:
		var from: int = w2.events.total_pushed
		if tt % 90 == 0 and tt < 900:
			@warning_ignore("return_value_discarded")
			w2.command_buy(floori(float(tt) / 90.0) % w2.config.upgrades.size(), 1)
		_step(w2)
		for n: int in range(from, w2.events.total_pushed):
			var slot: int = n & (SimEvents.CAPACITY - 1)
			if w2.events.kind[slot] == SimEventKind.WAVE_ENDED:
				ended += 1
			elif w2.events.kind[slot] == SimEventKind.CINDER_HIT:
				hull_oracle += w2.events.a[slot]
		tt += 1
	assert_int(totals.waves_cleared).is_equal(ended)
	assert_int(totals.hull).is_equal(hull_oracle)
	assert_int(totals.hull).is_greater(0)  # Cinder fell, so the hits that killed her were counted


func test_a_gap_in_the_stream_marks_the_tally_inexact() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(SEED)
	cfg.debug_invulnerable = true  # the run keeps going while nobody reads the stream
	var w := SimWorld.new(cfg)
	var tally := RunTally.new()
	tally.bind(w)
	var guard: int = 0
	while w.events.total_pushed < 1600 and guard < 40000:  # no polling: the 1024-event ring wraps
		_step(w)
		guard += 1
	tally.poll(w)
	assert_int(tally.lost).is_greater(0)
	assert_bool(tally.exact()).is_false()
	var totals: RunTotals = RunTotals.from_world(w, tally, SaveService.summary_from(w, 1, true))
	assert_int(totals.detail).is_equal(RunTotals.Detail.WORLD)  # event totals are not committed


func test_tally_round_trips_through_its_dictionary_and_tolerates_bad_input() -> void:
	var w: SimWorld = _world()
	var tally := RunTally.new()
	tally.bind(w)
	for t: int in 900:
		if t % 100 == 0:
			@warning_ignore("return_value_discarded")
			w.command_buy(floori(float(t) / 100.0) % 4, 1)
		_step(w)
		tally.poll(w)
	var d: Dictionary = tally.to_dict()
	var json: Dictionary = {}
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))  # ints come back as floats
	if parsed is Dictionary:
		json = parsed
	var back: RunTally = RunTally.from_dict(json, w)
	assert_bool(back.partial).is_false()
	assert_int(back.shots).is_equal(tally.shots)
	assert_int(back.hit_max).is_equal(tally.hit_max)
	assert_str(back.spent.to_text()).is_equal(tally.spent.to_text())
	assert_bool(RunTally.from_dict({}, w).partial).is_true()
	var bad: Dictionary = d.duplicate()
	bad["spent"] = "not a number"
	assert_bool(RunTally.from_dict(bad, w).partial).is_true()
	bad["spent"] = 5
	assert_bool(RunTally.from_dict(bad, w).partial).is_true()
	var junk: Dictionary = d.duplicate()
	junk["shots"] = "many"
	assert_int(RunTally.from_dict(junk, w).shots).is_equal(0)


# ---- bank, resume, double counting -------------------------------------------------------------------------------


func _service(fs: MemorySaveFs, controller: RunController) -> SaveService:
	var s := SaveService.new(fs, FakeClock.new(1000), "dev")
	@warning_ignore("return_value_discarded")
	s.load_profile()
	s.attach(controller)
	return s


func _controller() -> RunController:
	var c := RunController.new()
	c.last_run_path = RUN_PATH
	return c


## Buys on the first tick of every 200-tick slice, then advances; the same script for the straight and the resumed run.
func _play(c: RunController, from_slice: int, to_slice: int) -> void:
	for slice: int in range(from_slice, to_slice):
		for row: int in 4:
			@warning_ignore("return_value_discarded")
			c.request_buy((slice + row) % 4, 1)
		@warning_ignore("return_value_discarded")
		c.fast_forward(200)


func _resume_config(info: SnapshotInfo) -> SimConfig:
	var cfg: SimConfig = SimConfigLoader.load_default(info.seed_value)
	cfg.best_wave_s1 = info.best_wave_s1
	return cfg


func test_a_run_resumed_from_a_checkpoint_counts_exactly_like_the_uninterrupted_run() -> void:
	SaveKey.reset()
	# A: play 6 slices, checkpoint, play to the end
	var fs_a := MemorySaveFs.new()
	var ca: RunController = _controller()
	var sa: SaveService = _service(fs_a, ca)
	ca.paused = false
	@warning_ignore("return_value_discarded")
	sa.start_run()
	_play(ca, 0, 6)
	assert_bool(sa.checkpoint_now()).is_true()
	var snap: Dictionary = fs_a.files.duplicate(true)  # what a kill right now would leave on disk
	var tally_at_checkpoint: Dictionary = ca.tally.to_dict()
	_play(ca, 6, 400)
	assert_bool(ca.world.is_over()).is_true()
	var rec_a: Dictionary = RecordReader.record(sa.profile).duplicate(true)
	assert_int(RecordReader.runs_all(sa.profile)).is_equal(1)
	# B: the app was killed at the checkpoint; boot, resume, play the same remainder
	var fs_b := MemorySaveFs.new()
	fs_b.files = snap
	var cb: RunController = _controller()
	var sb: SaveService = _service(fs_b, cb)
	sb.profile = PlayerProfile.fresh(1000, "dev")  # the profile file of a mid-run kill has no run banked yet
	ServiceRecord.ensure(sb.profile, sb.clock)
	sb.profile.run_counter = 1
	var res: ResumeResult = sb.try_resume(_resume_config)
	assert_int(res.status).is_equal(ResumeResult.Status.RESUMED)
	assert_dict(res.extras).is_equal(tally_at_checkpoint)
	@warning_ignore("return_value_discarded")
	cb.resume_run(res.world, res.info.run_id, res.extras)
	cb.paused = false
	assert_bool(cb.tally.partial).is_false()
	_play(cb, 6, 400)
	assert_bool(cb.world.is_over()).is_true()
	assert_str(cb.world.state_hash()).is_equal(ca.world.state_hash())
	var rec_b: Dictionary = RecordReader.record(sb.profile)
	# identical record apart from the dates (A started at clock 1000 too, so even those match)
	assert_dict(rec_b).is_equal(rec_a)
	assert_int(RecordReader.total(sb.profile, "shots")).is_greater(0)
	assert_int(RecordReader.total(sb.profile, "gaps")).is_equal(0)


func test_a_snapshot_without_a_tally_commits_the_world_totals_but_no_event_totals() -> void:
	SaveKey.reset()
	var fs := MemorySaveFs.new()
	var c: RunController = _controller()
	var s: SaveService = _service(fs, c)
	@warning_ignore("return_value_discarded")
	s.start_run()
	_play(c, 0, 4)
	# an old build wrote the snapshot without extras
	assert_bool(s.checkpointer.checkpoint(c.world, c.run_id)).is_true()
	var snap: Dictionary = fs.files.duplicate(true)
	var fs2 := MemorySaveFs.new()
	fs2.files = snap
	var c2: RunController = _controller()
	var s2: SaveService = _service(fs2, c2)
	s2.profile.run_counter = 1
	var res: ResumeResult = s2.try_resume(_resume_config)
	@warning_ignore("return_value_discarded")
	c2.resume_run(res.world, res.info.run_id, res.extras)
	c2.paused = false
	assert_bool(c2.tally.partial).is_true()
	_play(c2, 4, 400)
	assert_bool(c2.world.is_over()).is_true()
	assert_int(RecordReader.total(s2.profile, "gaps")).is_equal(1)
	assert_int(RecordReader.total(s2.profile, "shots")).is_equal(0)
	assert_int(RecordReader.kills_all(s2.profile)).is_equal(c2.world.run.kills)  # kills come from the world
	assert_int(RecordReader.runs_all(s2.profile)).is_equal(1)


func test_banking_the_same_run_again_adds_nothing() -> void:
	SaveKey.reset()
	var c: RunController = _controller()
	var s: SaveService = _service(MemorySaveFs.new(), c)
	@warning_ignore("return_value_discarded")
	s.start_run()
	_play(c, 0, 400)
	assert_bool(c.world.is_over()).is_true()
	var once: Dictionary = RecordReader.record(s.profile).duplicate(true)
	var summary: RunSummary = SaveService.summary_from(c.world, c.run_id, true)
	assert_bool(s.bank_run(summary, RunTotals.from_world(c.world, c.tally, summary))).is_false()
	assert_bool(s.bank_run(summary)).is_false()
	assert_dict(RecordReader.record(s.profile)).is_equal(once)
	assert_int(RecordReader.runs_of_mode(s.profile, "timed")).is_equal(1)
	assert_int(RecordReader.frame_runs(s.profile, "vanguard")).is_equal(1)


func test_debug_runs_and_aborted_runs() -> void:
	SaveKey.reset()
	var c: RunController = _controller()
	var s: SaveService = _service(MemorySaveFs.new(), c)
	@warning_ignore("return_value_discarded")
	c.start_run(1, true, 3)  # a debug load: never banked, never recorded
	@warning_ignore("return_value_discarded")
	c.fast_forward(300)
	assert_int(RecordReader.runs_all(s.profile)).is_equal(0)
	@warning_ignore("return_value_discarded")
	s.start_run()
	_play(c, 0, 3)
	assert_bool(c.abort_run()).is_true()  # banks like a death, the wave being played is not "cleared"
	assert_int(RecordReader.runs_of_mode(s.profile, "timed")).is_equal(1)
	assert_int(RecordReader.total(s.profile, "waves")).is_equal(maxi(c.world.wave - 1, 0))
	assert_int(RecordReader.total(s.profile, "deploy_ticks")).is_equal(c.world.tick)
	assert_int(RecordReader.total(s.profile, "shots")).is_greater(0)


func test_a_run_ended_by_an_update_commits_the_summary_basics() -> void:
	SaveKey.reset()
	var fs := MemorySaveFs.new()
	var c: RunController = _controller()
	var s: SaveService = _service(fs, c)
	@warning_ignore("return_value_discarded")
	s.start_run()
	_play(c, 0, 3)
	assert_bool(s.checkpoint_now()).is_true()
	# the next build has other rules: the snapshot's sim_version no longer matches
	var dec: DecodeResult = SaveCodec.decode(SaveCodec.MAGIC_SNAPSHOT, fs.read("run_snapshot.sav"), 0xFFFF)
	var d: Dictionary = bytes_to_var(dec.raw)
	d["sim_version"] = SimVersion.CURRENT + 1
	fs.files["run_snapshot.sav"] = SaveCodec.encode(SaveCodec.MAGIC_SNAPSHOT, 1, var_to_bytes(d))
	var s2: SaveService = _service(fs, _controller())
	s2.profile.run_counter = 1
	var res: ResumeResult = s2.try_resume(_resume_config)
	assert_int(res.status).is_equal(ResumeResult.Status.ENDED_BY_UPDATE)
	assert_int(RecordReader.runs_of_mode(s2.profile, "timed")).is_equal(1)
	assert_int(RecordReader.total(s2.profile, "gaps")).is_equal(1)
	assert_int(RecordReader.total(s2.profile, "deploy_ticks")).is_equal(c.world.tick)
	assert_int(RecordReader.kills_all(s2.profile)).is_equal(0)
