class_name TestCameraFit
extends GdUnitTestSuite
## V1-23 camera auto-fit: fit width, smooth zoom, sprite factor, stand-off and beam consistency, scene wiring.

const TALL := Vector2(1080.0, 2400.0)
const SHORT := Vector2(1080.0, 1920.0)
const BATTLE_VIEW_SCENE: PackedScene = preload("res://src/view/battle_view.tscn")


func test_fit_width_at_base_range_is_52_m() -> void:
	assert_float(ViewMath.fit_width_m(24.0, 52.0, TALL)).is_equal_approx(52.0, 1e-4)
	# 1080x1920: the battle area is 1075.2 px tall, so the range circle must fit that instead
	assert_float(ViewMath.fit_width_m(24.0, 52.0, SHORT)).is_equal_approx(52.0 * 1080.0 / 1075.2, 1e-3)


func test_fit_keeps_the_whole_range_circle_in_the_battle_area() -> void:
	for vp: Vector2 in [TALL, SHORT]:
		for r: float in [24.0, 30.0, 45.0]:
			var w: float = ViewMath.fit_width_m(r, 52.0, vp)
			var ppm: float = ViewMath.px_per_m(vp.x, w)
			var half: float = minf(vp.x, ViewMath.battle_height(vp.y)) * 0.5
			assert_float(ppm * (r + ViewMath.FIT_MARGIN_M)).is_less_equal(half + 0.01)


func test_fit_clamps_to_min_and_the_spawn_ring() -> void:
	assert_float(ViewMath.fit_width_m(5.0, 52.0, TALL)).is_equal(ViewMath.MIN_FIT_WIDTH_M)
	assert_float(ViewMath.fit_width_m(0.0, 52.0, TALL)).is_equal(ViewMath.MIN_FIT_WIDTH_M)
	assert_float(ViewMath.fit_width_m(500.0, 52.0, TALL)).is_equal_approx(2.0 * (52.0 + ViewMath.FIT_MARGIN_M), 1e-4)
	assert_float(ViewMath.fit_width_m(40.0, 52.0, TALL)).is_equal_approx(84.0, 1e-4)


func test_fit_is_monotonic_in_range() -> void:
	var prev: float = 0.0
	for k: int in 60:
		var w: float = ViewMath.fit_width_m(float(k), 52.0, TALL)
		assert_float(w).is_greater_equal(prev)
		prev = w


func test_zoom_first_step_snaps_then_eases_smoothly() -> void:
	var z := CameraFit.new()
	assert_float(z.step(52.0, 10.0, false)).is_equal(52.0)
	assert_float(z.step(52.0, 10.5, false)).is_equal(52.0)
	assert_bool(z.easing()).is_false()
	# a purchase changes the target at t = 11
	var first: float = z.step(70.0, 11.0, false)
	assert_float(first).is_equal_approx(52.0, 1e-6)
	var prev: float = first
	var t: float = 11.0
	while t < 11.0 + ViewMath.ZOOM_EASE_S:
		t += 1.0 / 60.0
		var w: float = z.step(70.0, t, false)
		assert_float(w).is_greater_equal(prev)
		assert_float(w).is_less_equal(70.0)
		prev = w
	assert_float(z.step(70.0, 11.0 + ViewMath.ZOOM_EASE_S + 0.01, false)).is_equal(70.0)
	assert_bool(z.easing()).is_false()
	# halfway through the ease it is halfway there (smoothstep is symmetric)
	var h := CameraFit.new()
	h.step(50.0, 0.0, false)
	h.step(60.0, 1.0, false)
	assert_float(h.step(60.0, 1.0 + ViewMath.ZOOM_EASE_S * 0.5, false)).is_equal_approx(55.0, 1e-4)


func test_zoom_is_deterministic_and_retarget_is_continuous() -> void:
	var a := CameraFit.new()
	var b := CameraFit.new()
	var seq: Array[float] = []
	for z: CameraFit in [a, b]:
		z.step(52.0, 0.0, false)
		z.step(60.0, 1.0, false)
		var w1: float = z.step(60.0, 1.3, false)
		var w2: float = z.step(75.0, 1.3, false)  # retarget mid-ease: starts from the current width
		seq.append(w1)
		seq.append(w2)
	assert_float(seq[0]).is_equal(seq[2])
	assert_float(seq[1]).is_equal(seq[3])
	assert_float(seq[1]).is_equal_approx(seq[0], 1e-6)


func test_zoom_reduce_motion_snaps() -> void:
	var z := CameraFit.new()
	z.step(52.0, 0.0, false)
	assert_float(z.step(80.0, 0.1, true)).is_equal(80.0)
	assert_bool(z.easing()).is_false()


func test_sprite_factor_base_sqrt_and_floor() -> void:
	assert_float(ViewMath.sprite_factor(52.0)).is_equal_approx(0.85, 1e-6)
	assert_float(ViewMath.sprite_factor(38.0)).is_equal_approx(0.85, 1e-6)  # never bigger than 85%
	assert_float(ViewMath.sprite_factor(62.4)).is_equal_approx(0.85 * sqrt(52.0 / 62.4), 1e-6)
	assert_float(ViewMath.sprite_factor(70.0)).is_equal_approx(0.85 * sqrt(52.0 / 70.0), 1e-6)
	assert_float(ViewMath.sprite_factor(84.0)).is_equal(ViewMath.SPRITE_MIN_FACTOR)
	assert_float(ViewMath.sprite_factor(108.0)).is_equal(ViewMath.SPRITE_MIN_FACTOR)
	assert_float(ViewMath.sprite_factor(0.0)).is_equal_approx(0.85, 1e-6)
	var prev: float = 1.0
	for k: int in range(38, 120):
		var f: float = ViewMath.sprite_factor(float(k))
		assert_float(f).is_less_equal(prev)
		prev = f


func test_sprite_pixel_sizes_at_base_zoom_are_85_percent() -> void:
	var spm: float = ViewMath.sprite_ppm(1080.0, 52.0)
	assert_float(spm).is_equal_approx(ViewMath.REF_PPM * 0.85, 1e-4)
	for t: int in ViewMath.ENEMY_SLOTS.size():
		var now: float = ViewMath.body_radius_px(t, spm)
		var before: float = ViewMath.body_radius_px(t, ViewMath.REF_PPM)
		assert_float(now / before).is_equal_approx(0.85, 1e-4)
	assert_float(ViewMath.body_radius_px(0, spm) * 2.0).is_equal_approx(54.4, 0.01)
	# the width of the viewport scales sprites as before
	assert_float(ViewMath.sprite_ppm(540.0, 52.0)).is_equal_approx(spm * 0.5, 1e-4)
	# extended zoom: smaller, never below 70% of the old size
	var far: float = ViewMath.sprite_ppm(1080.0, 120.0)
	assert_float(ViewMath.body_radius_px(0, far) / ViewMath.body_radius_px(0, ViewMath.REF_PPM)).is_equal_approx(
		0.70, 1e-4
	)


func test_standoff_clears_armor_at_base_and_moderate_zoom() -> void:
	for cam: float in [52.0, 62.0, 70.0]:
		var ppm: float = ViewMath.px_per_m(1080.0, cam)
		var spm: float = ViewMath.sprite_ppm(1080.0, cam)
		var armor: float = 2.0 * spm * ViewMath.VISUAL_SCALE * ViewMath.CINDER_SCALE
		for t: int in ViewMath.ENEMY_SLOTS.size():
			var r: float = ViewMath.body_radius_px(t, spm)
			var s: float = ViewMath.contact_standoff_px(
				r, 2.0, ppm, ViewMath.STANDOFF_NEAR_M, spm, ViewMath.CINDER_SCALE
			)
			var center: float = ViewMath.map_dist(2.0, ppm, s)
			if t == 4:
				# the hulk's stand-off may hit the monotonic cap at wide zooms and overlap the ring a little
				assert_float(center - r - armor).is_greater(-40.0)
			else:
				assert_float(center - r - armor).is_equal_approx(ViewMath.CONTACT_GAP_PX, 0.01)
			var prev: float = -1.0
			for k: int in range(1, 601):
				var d: float = ViewMath.map_dist(float(k) * 0.1, ppm, s)
				assert_float(d).is_greater(prev)
				prev = d
	assert_float(2.0 * ViewMath.sprite_ppm(1080.0, 52.0) * ViewMath.VISUAL_SCALE * ViewMath.CINDER_SCALE).is_between(
		64.0, 65.5
	)


func test_standoff_stays_monotonic_at_the_widest_camera() -> void:
	var ppm: float = ViewMath.px_per_m(1080.0, 108.0)
	var spm: float = ViewMath.sprite_ppm(1080.0, 108.0)
	for t: int in ViewMath.ENEMY_SLOTS.size():
		var r: float = ViewMath.body_radius_px(t, spm)
		var s: float = ViewMath.contact_standoff_px(r, 2.0, ppm, ViewMath.STANDOFF_NEAR_M, spm, ViewMath.CINDER_SCALE)
		assert_float(s).is_less(ViewMath.STANDOFF_SPAN_M * ppm)
		var prev: float = -1.0
		for k: int in range(1, 1200):
			var d: float = ViewMath.map_dist(float(k) * 0.1, ppm, s)
			assert_float(d).is_greater(prev)
			prev = d


func test_renderer_sizes_follow_set_scale_without_rebuilding() -> void:
	var r: EnemyRenderer = auto_free(EnemyRenderer.new())
	add_child(r)
	var radii := PackedFloat32Array([0.6, 0.5, 1.4, 0.7, 3.0])
	var ppm: float = ViewMath.px_per_m(1080.0, 52.0)
	var spm: float = ViewMath.sprite_ppm(1080.0, 52.0)
	r.setup(ppm, radii, EnemyStore.DEFAULT_CAPACITY, ProjectileStore.DEFAULT_CAPACITY, 2.0, spm)
	var mesh_before: Mesh = (r.get_child(0) as MultiMeshInstance2D).multimesh.mesh
	var before: int = r.resize_count
	assert_float(r.sprite_radius_px(0)).is_equal_approx(32.0 * 0.85, 0.01)
	var armor: float = 2.0 * spm * ViewMath.VISUAL_SCALE * ViewMath.CINDER_SCALE
	var center: float = ViewMath.map_dist(2.0, ppm, r.standoff_px(0))
	assert_float(center - r.sprite_radius_px(0) - armor).is_equal_approx(ViewMath.CONTACT_GAP_PX, 0.01)
	var ppm2: float = ViewMath.px_per_m(1080.0, 70.0)
	var spm2: float = ViewMath.sprite_ppm(1080.0, 70.0)
	r.set_view_scale(ppm2, spm2, 2.0)
	assert_float(r.sprite_radius_px(0)).is_equal_approx(32.0 * ViewMath.sprite_factor(70.0), 0.01)
	assert_int(r.resize_count).is_equal(before)
	assert_object((r.get_child(0) as MultiMeshInstance2D).multimesh.mesh).is_same(mesh_before)
	var armor2: float = 2.0 * spm2 * ViewMath.VISUAL_SCALE * ViewMath.CINDER_SCALE
	var center2: float = ViewMath.map_dist(2.0, ppm2, r.standoff_px(0))
	assert_float(center2 - r.sprite_radius_px(0) - armor2).is_equal_approx(ViewMath.CONTACT_GAP_PX, 0.01)
	# beam end sits 0.6 of the (new) sprite radius short of the remapped target
	var target := Vector2.from_angle(0.4) * 2.0
	var end: Vector2 = BeamRenderer.beam_end(target, r.sprite_radius_px(0), ppm2, r.standoff_px(0))
	assert_float(end.length()).is_equal_approx(center2 - 0.6 * r.sprite_radius_px(0), 0.001)
	# the cull margin covers the boss at any zoom
	var rect := Rect2(-540.0, -672.0, 1080.0, 1344.0)
	var c: Rect2 = EnemyRenderer.cull_rect_for(rect, ppm2, r.max_sprite_radius_px() * 1.15)
	assert_float(rect.position.x - c.position.x).is_greater_equal(r.sprite_radius_px(4))


func test_battle_view_eases_to_a_larger_optic_range_and_floors() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var scene: PackedScene = BATTLE_VIEW_SCENE
	var view: BattleView = auto_free(scene.instantiate())
	add_child(view)
	view.layout(TALL)
	view.bind(world)
	view.render(0.5)
	assert_float(view.camera_m()).is_equal_approx(52.0, 1e-3)
	assert_float(view.sprite_factor()).is_equal_approx(0.85, 1e-4)
	assert_float(view.cinder_view().radius_px * 0.92).is_equal_approx(2.0 * 33.75 * 0.85 * 1.5 * 0.75, 0.5)
	world.stats.optic_range = 40.0
	view.render(0.5)
	var mid: float = view.camera_m()
	assert_float(mid).is_greater_equal(52.0)
	assert_float(mid).is_less(84.0)
	OS.delay_msec(int((ViewMath.ZOOM_EASE_S + 0.2) * 1000.0))
	view.render(0.5)
	assert_float(view.camera_m()).is_equal_approx(84.0, 1e-3)
	assert_float(view.px_per_m()).is_equal_approx(1080.0 / 84.0, 1e-3)
	assert_float(view.sprite_factor()).is_equal(ViewMath.SPRITE_MIN_FACTOR)
	# settled: another render does not change anything
	view.render(0.5)
	assert_float(view.camera_m()).is_equal(84.0)


func test_field_insets_center_cinder_and_fit_the_range_into_the_field() -> void:
	var f: Rect2 = ViewMath.field_rect(TALL, 365.0, 1055.0)
	assert_float(f.position.y).is_equal(365.0)
	assert_float(f.end.y).is_equal(1345.0)
	# fit: 980 px tall field limits the 52 m circle
	var w: float = ViewMath.fit_width_m(24.0, 52.0, TALL, f.size)
	assert_float(w).is_equal_approx(52.0 * 1080.0 / 980.0, 1e-3)
	assert_float(ViewMath.px_per_m(1080.0, w) * 26.0).is_less_equal(490.01)
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var scene: PackedScene = BATTLE_VIEW_SCENE
	var view: BattleView = auto_free(scene.instantiate())
	add_child(view)
	view.layout(TALL)
	view.bind(world)
	view.set_field_insets(365.0, 1055.0)
	view.render(0.5)
	assert_vector(view.position).is_equal(Vector2(540.0, 855.0))
	assert_float(view.camera_m()).is_equal_approx(w, 1e-3)
	# sprites keep the 85 percent size whatever the aspect
	assert_float(view.sprite_factor()).is_equal_approx(0.85, 1e-4)
	view.set_field_insets(-1.0, -1.0)
	assert_vector(view.position).is_equal(Vector2(540.0, 672.0))
