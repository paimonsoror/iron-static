class_name TestGamePlayTime
extends GdUnitTestSuite
## Foreground play time in `Game`: sampled each frame through the injected clock, written to the flight recorder and the
## Service Record in whole seconds (every 30 s and when the app goes to the background), never while play is not
## recorded. `Game` is an autoload, so the test builds a second node from the script.

const GAME_SCRIPT: String = "res://src/core/game.gd"


func _game(clock: FakeClock) -> Node:
	var g: Node = (load(GAME_SCRIPT) as GDScript).new()
	g.set("clock", clock)
	g.call("setup_persistence", MemorySaveFs.new(), PackedStringArray())
	return g


func _free(g: Node) -> void:
	var a: Node = g.get("audio")
	a.free()
	g.free()


## `frames` frames of `step_ms` each.
func _frames(g: Node, clock: FakeClock, frames: int, step_ms: int) -> void:
	for i: int in frames:
		clock.mono_ms += step_ms
		g.call("_count_play_time")


func _record_seconds(g: Node) -> int:
	var s: SaveService = g.get("saves")
	return RecordReader.total(s.profile, "play_s")


func _flight_seconds(g: Node) -> int:
	var s: SaveService = g.get("saves")
	var total: int = 0
	var days: Dictionary = FlightRecorder.days(s.profile)
	for key: Variant in days.keys():
		var d: Dictionary = days[key]
		total += FlightRecorder.int_of(d, "sec")
	return total


func test_seconds_reach_both_records_every_30_seconds_and_on_pause() -> void:
	SaveKey.reset()
	var clock := FakeClock.new(1794268800)
	var g: Node = _game(clock)
	_frames(g, clock, 2, 500)  # the first call only anchors the timer
	assert_int(_record_seconds(g)).is_equal(0)
	_frames(g, clock, 70, 500)  # 35 s of frames: the 30 s flush has run
	assert_int(_record_seconds(g)).is_between(29, 30)
	assert_int(_flight_seconds(g)).is_equal(_record_seconds(g))
	g.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var after_pause: int = _record_seconds(g)
	assert_int(after_pause).is_between(35, 36)
	assert_int(_flight_seconds(g)).is_equal(after_pause)
	# the app sleeps for an hour: nothing is added for the gap, play carries on afterwards
	clock.mono_ms += 3600 * 1000
	_frames(g, clock, 1, 16)
	g.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_int(_record_seconds(g)).is_equal(after_pause)
	_frames(g, clock, 10, 500)
	g.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_int(_record_seconds(g)).is_between(after_pause + 4, after_pause + 5)
	_free(g)


func test_a_debug_load_records_no_play_time() -> void:
	SaveKey.reset()
	var clock := FakeClock.new(1794268800)
	var g: Node = _game(clock)
	g.set("debug_load", true)
	_frames(g, clock, 80, 500)
	g.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_int(_record_seconds(g)).is_equal(0)
	_free(g)
