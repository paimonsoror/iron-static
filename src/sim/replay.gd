class_name Replay
extends RefCounted
## Re-runs a RunRecord in a fresh world. Rule (same as live play): commands logged at tick T are applied
## before `step()` of tick T. Stops at `RUN_ENDED` or when `world.tick` reaches `max_ticks`. An aborted record (the
## player left the mission alive) also stops at its `final_tick`, after applying the commands due on that tick.


## Final `state_hash()` of the replayed run. Mutates `cfg` via `rec.apply_to` (seed, sector, best wave...).
static func run(cfg: SimConfig, rec: RunRecord, max_ticks: int) -> String:
	return run_world(cfg, rec, max_ticks).state_hash()


## Same as `run` but returns the finished world (its `input_log` equals the record's commands).
static func run_world(cfg: SimConfig, rec: RunRecord, max_ticks: int) -> SimWorld:
	rec.apply_to(cfg)
	var w: SimWorld = SimWorld.new(cfg)
	var cursor: int = 0
	var limit: int = mini(max_ticks, rec.final_tick) if rec.aborted else max_ticks
	while not w.is_over() and w.tick < limit:
		cursor = _apply_due(w, rec.commands, cursor)
		if w.is_draft_open():
			break  # a record cut inside a draft has no pick to apply: stop instead of waiting forever
		w.step()
	if rec.aborted and w.tick == rec.final_tick:
		cursor = _apply_due(w, rec.commands, cursor)  # buys logged while paused on the abort tick
	return w


## State hashes at each of `targets` (ascending ticks) while replaying; "" for a tick never reached.
static func checkpoints(cfg: SimConfig, rec: RunRecord, targets: PackedInt32Array) -> PackedStringArray:
	rec.apply_to(cfg)
	var out: PackedStringArray = PackedStringArray()
	var w: SimWorld = SimWorld.new(cfg)
	var cursor: int = 0
	for target: int in targets:
		var stop: int = mini(target, rec.final_tick) if rec.aborted else target
		while not w.is_over() and w.tick < stop:
			cursor = _apply_due(w, rec.commands, cursor)
			if w.is_draft_open():
				break  # see run_world
			w.step()
		if out.append(w.state_hash() if w.tick == target else ""):
			push_error("Replay: append failed")
	return out


## Applies the commands logged at `w.tick` (skipping stale ones) and returns the new cursor.
static func _apply_due(w: SimWorld, cmds: InputLog, start: int) -> int:
	var i: int = start
	while i < cmds.size() and cmds.ticks[i] <= w.tick:
		if cmds.ticks[i] == w.tick and cmds.kinds[i] == InputLog.CMD_BUY:
			@warning_ignore("return_value_discarded")  # replay re-derives the result
			w.command_buy(cmds.arg_a[i], cmds.arg_b[i])
		elif cmds.ticks[i] == w.tick and cmds.kinds[i] == InputLog.CMD_PICK:
			@warning_ignore("return_value_discarded")
			w.command_pick(cmds.arg_a[i])
		i += 1
	return i
