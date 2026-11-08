class_name TestEventCursor
extends GdUnitTestSuite


func _drain_all(cur: EventCursor, ev: SimEvents, seen: PackedInt32Array) -> void:
	while cur.poll(ev) > 0:
		for i: int in cur.count:
			assert_bool(seen.append(cur.a_at(i))).is_false()


func test_drains_only_unseen_events_in_order() -> void:
	var ev := SimEvents.new()
	var cur := EventCursor.new()
	for i: int in 5:
		ev.push(SimEventKind.SHOT_FIRED, i, 0)
	var seen := PackedInt32Array()
	_drain_all(cur, ev, seen)
	assert_array(seen).is_equal(PackedInt32Array([0, 1, 2, 3, 4]))
	seen.clear()
	_drain_all(cur, ev, seen)
	assert_int(seen.size()).is_equal(0)
	ev.push(SimEventKind.ENEMY_HIT, 9, 7)
	_drain_all(cur, ev, seen)
	assert_array(seen).is_equal(PackedInt32Array([9]))


func test_batches_larger_than_buffer_are_all_delivered() -> void:
	var ev := SimEvents.new()
	var cur := EventCursor.new()
	for i: int in 200:
		ev.push(SimEventKind.SHOT_FIRED, i, 1)
	var seen := PackedInt32Array()
	_drain_all(cur, ev, seen)
	assert_int(seen.size()).is_equal(200)
	assert_int(seen[199]).is_equal(199)
	assert_int(cur.lost_total).is_equal(0)


func test_fields_are_decoded() -> void:
	var ev := SimEvents.new()
	ev.tick = 42
	ev.push(SimEventKind.SHOT_FIRED, 3, 1)
	var cur := EventCursor.new()
	assert_int(cur.poll(ev)).is_equal(1)
	assert_int(cur.tick_at(0)).is_equal(42)
	assert_int(cur.kind_at(0)).is_equal(SimEventKind.SHOT_FIRED)
	assert_int(cur.a_at(0)).is_equal(3)
	assert_int(cur.b_at(0)).is_equal(1)


func test_survives_ring_wrap_and_counts_loss() -> void:
	var ev := SimEvents.new()
	var cur := EventCursor.new()
	for i: int in 3000:
		ev.push(SimEventKind.SHOT_FIRED, i, 0)
	var seen := PackedInt32Array()
	_drain_all(cur, ev, seen)
	assert_int(cur.lost_total).is_equal(3000 - SimEvents.CAPACITY)
	assert_int(cur.lost_warnings).is_equal(1)
	assert_int(seen.size()).is_equal(SimEvents.CAPACITY)
	assert_int(seen[0]).is_equal(3000 - SimEvents.CAPACITY)
	assert_int(seen[seen.size() - 1]).is_equal(2999)


func test_sync_to_skips_history() -> void:
	var ev := SimEvents.new()
	for i: int in 10:
		ev.push(SimEventKind.SHOT_FIRED, i, 0)
	var cur := EventCursor.new()
	cur.sync_to(ev)
	assert_int(cur.poll(ev)).is_equal(0)
