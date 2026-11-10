class_name SpeedBench
extends Node
## R1-03 desktop bench: ms per frame of the production BattleView on a late-run state (debug load, invulnerable,
## about 165 enemies at wave 60) at 1x, 2x, 4x and 8x, with the high-speed load shedding (`SpeedLoad`) on and, at 8x,
## off. Frames are fixed 1/60 s steps, so 8x runs 4 ticks per frame. Needs a window (vsync is switched off):
##   godot --path . --windowed --resolution 540x1200 res://src/debug/speed_bench.tscn -- --bench-wave=60
## Prints `SPEEDBENCH ...` lines (avg and p95 frame ms, avg sim ms per frame, ticks per frame).

const FRAME_DT: float = 1.0 / 60.0
const WARMUP_FRAMES: int = 60


func _ready() -> void:
	var wave: int = 60
	var frames: int = 400
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--bench-wave="):
			wave = int(a.get_slice("=", 1))
		elif a.begins_with("--bench-frames="):
			frames = int(a.get_slice("=", 1))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var c := RunController.new()
	c.start_run(RunController.DEFAULT_SEED, true, wave)
	var guard: int = 0
	while c.load_wave > 0 and guard < 100000:
		@warning_ignore("return_value_discarded")
		c.update(FRAME_DT)
		guard += 1
	var view: BattleView = (load("res://src/view/battle_view.tscn") as PackedScene).instantiate()
	add_child(view)
	view.bind(c.world)
	await get_tree().process_frame
	print("SPEEDBENCH state: wave=%d enemies=%d tick=%d" % [c.world.wave, c.world.enemies.alive_count, c.world.tick])
	for cfg: Array in [[1, 1, "1x"], [2, 2, "2x"], [4, 4, "4x shed"], [8, 8, "8x shed"], [8, 1, "8x unshed"]]:
		var speed: int = cfg[0]
		var hint: int = cfg[1]
		var label: String = cfg[2]
		c.speed = speed
		view.set_speed_hint(hint)
		var times: PackedFloat32Array = PackedFloat32Array()
		var sim_us: int = 0
		var ticks: int = 0
		var last: int = Time.get_ticks_usec()
		for f: int in frames + WARMUP_FRAMES:
			var ran: int = c.update(FRAME_DT)
			view.render(c.driver.acc / TickDriver.DT)
			await get_tree().process_frame
			var now: int = Time.get_ticks_usec()
			if f >= WARMUP_FRAMES:
				times.append(float(now - last) / 1000.0)
				sim_us += c.last_usec
				ticks += ran
			last = now
		times.sort()
		var sum: float = 0.0
		for t: float in times:
			sum += t
		print(
			(
				"SPEEDBENCH %-10s avg_frame_ms=%.2f p95_ms=%.2f sim_ms=%.2f ticks_per_frame=%.1f"
				% [
					label,
					sum / float(times.size()),
					times[floori(0.95 * float(times.size() - 1))],
					float(sim_us) / 1000.0 / float(frames),
					float(ticks) / float(frames)
				]
			)
		)
	get_tree().quit()
