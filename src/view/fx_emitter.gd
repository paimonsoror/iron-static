class_name FxEmitter
extends RefCounted
## Spends the FxRecipes numbers into the particle pools (V1-13): the public effect API of the particle ring.
## Everything is view-only and allocation-free per call (Vector2/Color values, preallocated pools, own RNG).
## Positions are local px (origin Cinder); `now` is the sim time in seconds (set by FxSpawner every frame).
## V1-12 (beams) calls `impact()` and `muzzle()`; V1-14 (shake, slow-mo) reads FxSpawner's big-event counters.

const HULL_DARK := Color("#7A1E30")
const SMOKE_COLOR := Color(0.165, 0.039, 0.063, 0.4)
const HOT_WHITE := Color(1.0, 0.96, 0.9, 1.0)
const SPARK_AMBER := Color("#FFD27A")
const CORE_AMBER := Color("#FFE3A3")
const AMBER := Color("#FFB000")
const EMBER_LOW := Color("#FF8A1F")
const CHAR_FLAKE := Color("#7A5A48")
const WARNING := Color("#FFC21A")
const TEAL := Color("#2EE6D6")
## VT-4 sizes are authored in the style frame (docs/design/style/upgrade_tiers) at sprite factor 0.85; this brings them
## to the factor-1 px that `_add` then scales like every other recipe.
const VT_SIZE_K: float = 1.0 / 0.85

## Sim time in seconds.
var now: float = 0.0
## Cinder's armor ring radius in px (ember and band-change origin).
var cinder_radius_px: float = 100.0
## Particle size multiplier (V1-23: the sprite factor, 1.0 = pre-V1-23 pixels). Applied to every particle size.
var fx_scale: float = 1.0
var reduce_motion: bool = false
var rings_enabled: bool = true
var sparks_per_hit: int = 6
## VisualQuality tier index (0 HIGH, 1 MID, 2 LOW) for the VT-4 effects (deflection sparks, repair motes).
var quality_tier: int = 0
## Bearing (radians) of the latest `cinder_hit()` on the armor ring; `deflect()` fires at the same point.
var last_hit_angle: float = 0.0
var additive: ParticlePool
var smoke: ParticlePool
var _rng := RandomNumberGenerator.new()
var _fx_rng := RandomNumberGenerator.new()  # VT-4 effects: own stream, so tiers never shift the other recipes


func _init(add_pool: ParticlePool = null, smoke_pool: ParticlePool = null) -> void:
	additive = add_pool if add_pool != null else ParticlePool.new()
	smoke = smoke_pool if smoke_pool != null else ParticlePool.new()
	_rng.seed = 20260515
	_fx_rng.seed = 20261109


## Hit impact at `pos`; `toward` is the unit direction sparks mostly fly (back toward the shooter).
func impact(pos: Vector2, toward: Vector2, alive: int, crit: bool = false) -> void:
	var rings_ok: bool = FxRecipes.rings_allowed(alive, rings_enabled, reduce_motion)
	var sparks: int = FxRecipes.lod_sparks(FxRecipes.CRIT_SPARKS if crit else sparks_per_hit, alive)
	_add(pos, Vector2.ZERO, 0.0, 0.05, Vector2(26.0, 34.0), Color(CORE_AMBER, 0.95), ParticlePack.KIND_FLASH)
	_add(pos, Vector2.ZERO, 0.0, 0.10, Vector2(36.0, 54.0), Color(AMBER, 0.45), ParticlePack.KIND_HALO)
	if rings_ok:
		_add(pos, Vector2.ZERO, 0.0, 0.12, Vector2(40.0, 70.0), Color(SPARK_AMBER, 0.6), ParticlePack.KIND_RING_THIN)
	if crit:
		_add(pos, Vector2.ZERO, 0.0, 0.15, Vector2(60.0, 90.0), Color(HOT_WHITE, 0.9), ParticlePack.KIND_FLARE8)
		if rings_ok:
			_add(pos, Vector2.ZERO, 0.0, 0.2, Vector2(60.0, 110.0), Color(AMBER, 0.7), ParticlePack.KIND_RING_THIN)
	var base: float = toward.angle()
	for k: int in sparks:
		var a: float = base + _rng.randf_range(-1.1, 1.1)
		var v: Vector2 = Vector2.from_angle(a) * _rng.randf_range(260.0, 420.0)
		var len_px: float = _rng.randf_range(22.0, 40.0)
		var col: Color = SPARK_AMBER.lerp(HOT_WHITE, _rng.randf_range(0.0, 0.5))
		col.a = 0.95
		_add(pos, v, 0.0, 0.18, Vector2(len_px, len_px * 0.4), col, _spark_kind())


## Muzzle flare at the emitter (one particle; the cone and lens glow belong to the beam renderer).
func muzzle(pos: Vector2) -> void:
	_add(pos, Vector2.ZERO, 0.0, 0.06, Vector2(38.0, 83.0), Color(CORE_AMBER, 0.9), ParticlePack.KIND_FLARE4)


## Kill burst of enemy type `type_index` at `pos`; `radius_px` = its sprite radius, `alive` the density for LOD.
func kill(type_index: int, pos: Vector2, radius_px: float, alive: int) -> void:
	var size_r: float = radius_px / fx_scale  # radius_px already carries the sprite factor that _add applies
	var t: int = clampi(type_index, 0, FxRecipes.ACCENTS.size() - 1)
	if t == FxRecipes.BOSS_TYPE:
		boss_death(pos, radius_px)
		return
	var accent: Color = FxRecipes.accent(t)
	var rings_ok: bool = FxRecipes.rings_allowed(alive, rings_enabled, reduce_motion)
	var flash_col: Color = accent.lerp(HOT_WHITE, 0.6)
	flash_col.a = 1.0
	_add(pos, Vector2.ZERO, 0.0, 0.07, Vector2(size_r * 2.0, radius_px * 2.6), flash_col, ParticlePack.KIND_FLASH)
	if rings_ok:
		var thick: bool = t == FxRecipes.WALKER_TYPE
		var rk: int = ParticlePack.KIND_RING_THICK if thick else ParticlePack.KIND_RING_THIN
		var rcol: Color = Color(accent, 0.8 if thick else 0.6)
		var reach: float = 3.6 if thick else 2.6
		_add(pos, Vector2.ZERO, 0.0, 0.3 if thick else 0.22, Vector2(size_r * 1.2, radius_px * reach), rcol, rk)
	_shards(pos, FxRecipes.KILL_SHARDS[t], accent, 1.0, 0.0)
	_sparks(pos, FxRecipes.lod_sparks(FxRecipes.KILL_SPARKS[t], alive), accent, 1.0, 0.0)
	if FxRecipes.smoke_allowed(alive):
		for k: int in FxRecipes.KILL_SMOKE[t]:
			_smoke_puff(pos, 40.0, 70.0, 0.5, 0.0)


## Boss death (6.4): white-hot flash, three staggered thick rings, shards, sparks, smoke and three mini bursts.
func boss_death(pos: Vector2, radius_px: float) -> void:
	var size_r: float = radius_px / fx_scale
	var accent: Color = FxRecipes.accent(FxRecipes.BOSS_TYPE)
	_add(
		pos,
		Vector2.ZERO,
		0.0,
		0.25,
		Vector2(size_r * 4.0, radius_px * 5.0),
		Color(HOT_WHITE, 0.95),
		ParticlePack.KIND_FLASH
	)
	_add(
		pos,
		Vector2.ZERO,
		0.0,
		0.35,
		Vector2(size_r * 2.5, radius_px * 6.0),
		Color(HOT_WHITE, 0.8),
		ParticlePack.KIND_FLARE8
	)
	if not reduce_motion:
		for k: int in FxRecipes.BOSS_RINGS:
			var col: Color = AMBER.lerp(FxRecipes.accent(FxRecipes.BOSS_TYPE), float(k) / 2.0)
			col.a = 0.85
			_add(
				pos,
				Vector2.ZERO,
				0.09 * float(k),
				0.5,
				Vector2(size_r * 1.5, radius_px * 5.5),
				col,
				ParticlePack.KIND_RING_THICK
			)
	_shards(pos, FxRecipes.KILL_SHARDS[FxRecipes.BOSS_TYPE], accent, 2.0, 0.0)
	_sparks(pos, FxRecipes.KILL_SPARKS[FxRecipes.BOSS_TYPE], accent, 1.6, 0.0)
	for k: int in FxRecipes.KILL_SMOKE[FxRecipes.BOSS_TYPE]:
		_smoke_puff(pos + _disc(radius_px * 0.6), 70.0, 120.0, 0.7, _rng.randf_range(0.0, 0.2))
	for k: int in FxRecipes.BOSS_MINI_BURSTS:
		var delay: float = 0.15 * float(k + 1)
		var at: Vector2 = pos + _disc(radius_px * 0.7)
		_add(
			at,
			Vector2.ZERO,
			delay,
			0.12,
			Vector2(size_r * 0.9, radius_px * 1.3),
			Color(accent.lerp(HOT_WHITE, 0.5), 0.9),
			ParticlePack.KIND_FLASH
		)
		_shards(at, FxRecipes.MINI_SHARDS, accent, 1.0, delay)
		_sparks(at, FxRecipes.MINI_SPARKS, accent, 1.0, delay)


## Boss spawn warning ring (6.4): one amber thick ring at the boss.
func warning_ring(pos: Vector2) -> void:
	if reduce_motion:
		return
	_add(pos, Vector2.ZERO, 0.0, 0.8, Vector2(60.0, 260.0), Color(WARNING, 0.8), ParticlePack.KIND_RING_THICK)


## One ember rising outward from Cinder's armor ring (6.5), `angle` = bearing on the ring.
func ember(angle: float) -> void:
	var dir: Vector2 = Vector2.from_angle(angle + _rng.randf_range(-0.25, 0.25))
	var v: Vector2 = dir * _rng.randf_range(30.0, 70.0)
	var size: float = _rng.randf_range(22.0, 30.0)
	var col: Color = EMBER_LOW.lerp(SPARK_AMBER, _rng.randf())
	col.a = 1.0
	var k: int = ParticlePack.KIND_EMBER_A + _rng.randi_range(0, 1)
	_add(
		Vector2.from_angle(angle) * cinder_radius_px * 0.95,
		v,
		0.0,
		_rng.randf_range(0.8, 1.2),
		Vector2(size, size * 0.7),
		col,
		k
	)


## Band got worse (`new_band` 1..3): expanding ring, frame flash, charred flakes and 4 embers per affected wedge.
func band_worse(new_band: int) -> void:
	var b: int = clampi(new_band, 1, 3)
	var col: Color = FxRecipes.BAND_RING_COLORS[b]
	if not reduce_motion:
		_add(
			Vector2.ZERO, Vector2.ZERO, 0.0, 0.35, Vector2(90.0, 260.0), Color(col, 0.85), ParticlePack.KIND_RING_THICK
		)
	_add(
		Vector2.ZERO,
		Vector2.ZERO,
		0.0,
		0.3,
		Vector2(cinder_radius_px * 2.2, cinder_radius_px * 2.6) / fx_scale,
		Color(col, 0.4),
		ParticlePack.KIND_FLASH
	)
	var wedges: Array = FxRecipes.BAND_WEDGES[b]
	for wi: int in wedges.size():
		var w: int = wedges[wi]
		var a: float = (float(w) + 0.5) * TAU / 12.0 - PI * 0.5
		var origin: Vector2 = Vector2.from_angle(a) * cinder_radius_px * 0.8
		var v: Vector2 = Vector2.from_angle(a + _rng.randf_range(-0.2, 0.2)) * _rng.randf_range(200.0, 310.0)
		var fcol: Color = CHAR_FLAKE.lerp(EMBER_LOW, _rng.randf_range(0.1, 0.5))
		fcol.a = 0.95
		var sz: float = _rng.randf_range(16.0, 24.0)
		var k: int = ParticlePack.KIND_SHARD_1 + _rng.randi_range(0, 5)
		_add(origin, v, 0.0, 0.6, Vector2(sz, sz * 0.6), fcol, k)
		for e: int in FxRecipes.EMBERS_PER_WEDGE:
			var ev: Vector2 = v * _rng.randf_range(0.2, 0.5) + _disc(40.0)
			var ecol: Color = EMBER_LOW.lerp(SPARK_AMBER, _rng.randf())
			ecol.a = 1.0
			var esz: float = _rng.randf_range(22.0, 30.0)
			var ek: int = ParticlePack.KIND_EMBER_A + _rng.randi_range(0, 1)
			_add(origin, ev, 0.0, _rng.randf_range(0.8, 1.2), Vector2(esz, esz * 0.7), ecol, ek)


## Band improved: one quick teal ring.
func band_better() -> void:
	if reduce_motion:
		return
	_add(Vector2.ZERO, Vector2.ZERO, 0.0, 0.3, Vector2(100.0, 200.0), Color(TEAL, 0.6), ParticlePack.KIND_RING_THIN)


## Cinder was hit: 4 red-orange sparks at a random point of the armor ring.
func cinder_hit(accent: Color) -> void:
	var a: float = _rng.randf() * TAU
	last_hit_angle = a
	var pos: Vector2 = Vector2.from_angle(a) * cinder_radius_px
	for k: int in FxRecipes.CINDER_HIT_SPARKS:
		var v: Vector2 = Vector2.from_angle(a + _rng.randf_range(-0.9, 0.9)) * _rng.randf_range(180.0, 320.0)
		var col: Color = accent.lerp(EMBER_LOW, 0.5)
		col.a = 0.95
		var len_px: float = _rng.randf_range(16.0, 28.0)
		_add(pos, v, 0.0, 0.22, Vector2(len_px, len_px * 0.4), col, _spark_kind())


## VT-4: teal-white ricochet at the plate edge (bearing `angle` on the armor ring), `tier_scale` = the PLATED tier's
## spark_scale (1.0 to 1.4). HIGH: flash, ring, halo, flare + 5 to 6 sparks fanned to both sides of the normal;
## MID: 4 sparks and no ring; reduce motion: 3 sparks and no ring; LOW: nothing. Returns the particles written.
func deflect(angle: float, tier_scale: float) -> int:
	var n: int = FxRecipes.deflect_sparks(quality_tier, reduce_motion, tier_scale)
	if n <= 0:
		return 0
	var sc: float = tier_scale * VT_SIZE_K
	var pos: Vector2 = Vector2.from_angle(angle) * cinder_radius_px * FxRecipes.DEFLECT_EDGE
	var teal: Color = Palette.current().teal
	var white := Color(0.85, 1.0, 0.98, 1.0)
	var before: int = additive.total_written
	_add(pos, Vector2.ZERO, 0.0, 0.1, Vector2(20.0, 26.0) * sc, Color(white, 0.6), ParticlePack.KIND_FLASH)
	if rings_enabled and not reduce_motion and quality_tier == 0:
		_add(pos, Vector2.ZERO, 0.0, 0.2, Vector2(30.0, 64.0) * sc, Color(teal, 0.8), ParticlePack.KIND_RING_THIN)
	_add(pos, Vector2.ZERO, 0.0, 0.2, Vector2(46.0, 60.0) * sc, Color(teal, 0.3), ParticlePack.KIND_HALO)
	_add(pos, Vector2.ZERO, 0.0, 0.16, Vector2(34.0, 42.0) * sc, Color(white, 0.7), ParticlePack.KIND_FLARE4)
	for k: int in n:
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var a: float = angle + side * _fx_rng.randf_range(0.55, 1.0)
		var v: Vector2 = Vector2.from_angle(a) * _fx_rng.randf_range(300.0, 470.0)
		var len_px: float = _fx_rng.randf_range(44.0, 78.0) * sc
		var col: Color = teal.lerp(Color.WHITE, _fx_rng.randf_range(0.2, 0.7))
		col.a = 0.95
		var kind: int = ParticlePack.KIND_SPARK_A + _fx_rng.randi_range(0, 2)
		_add(pos, v, 0.0, 0.24, Vector2(len_px, len_px * 0.22), col, kind)
	return additive.total_written - before


## VT-4: one repair mote just outside the plates at bearing `angle`. `speed` px/s along the tangent (0 = it fades in
## place, reduce motion), `size` px; `halo` adds the soft glow particle. Lives MOTE_LIFE_S. Returns particles written.
func mote(angle: float, speed: float, size: float, halo: bool) -> int:
	var k: float = VT_SIZE_K
	var rr: float = cinder_radius_px * _fx_rng.randf_range(1.02, 1.32)
	var pos: Vector2 = Vector2.from_angle(angle) * rr
	var v := Vector2.ZERO
	if speed > 0.0:
		v = Vector2.from_angle(angle + PI * 0.5) * speed * _fx_rng.randf_range(0.75, 1.1)
		v += Vector2.from_angle(angle) * 14.0
	var teal: Color = Palette.current().teal
	var col: Color = teal.lerp(Color.WHITE, _fx_rng.randf_range(0.1, 0.45))
	col.a = 0.95
	var life: float = FxRecipes.MOTE_LIFE_S
	_add(pos, v, 0.0, life, Vector2(size, size * 0.6) * k, col, ParticlePack.KIND_EMBER_A)
	if not halo:
		return 1
	_add(pos, v, 0.0, life, Vector2(size * 3.2, size * 2.0) * k, Color(teal, 0.55), ParticlePack.KIND_HALO)
	return 2


## Cinder died: a big white flash (kept under reduce motion) and one ring.
func cinder_death() -> void:
	_add(Vector2.ZERO, Vector2.ZERO, 0.0, 0.4, Vector2(1600.0, 1800.0), Color(HOT_WHITE, 0.35), ParticlePack.KIND_FLASH)
	if not reduce_motion:
		_add(
			Vector2.ZERO,
			Vector2.ZERO,
			0.0,
			0.6,
			Vector2(120.0, 700.0),
			Color(FxRecipes.BAND_RING_COLORS[3], 0.8),
			ParticlePack.KIND_RING_THICK
		)


func _shards(pos: Vector2, count: int, accent: Color, scale: float, delay: float) -> void:
	for k: int in count:
		var v: Vector2 = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(120.0, 300.0) * scale
		var col: Color = HULL_DARK.lerp(accent, _rng.randf_range(0.3, 1.0))
		col.a = 0.95
		var sz: float = _rng.randf_range(10.0, 22.0) * scale
		var kind: int = ParticlePack.KIND_SHARD_1 + _rng.randi_range(0, 5)
		_add(pos, v, delay, 0.45, Vector2(sz, sz * 0.5), col, kind)


func _sparks(pos: Vector2, count: int, accent: Color, scale: float, delay: float) -> void:
	for k: int in count:
		var v: Vector2 = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(200.0, 420.0) * scale
		var col: Color = accent.lerp(SPARK_AMBER, 0.5)
		col.a = 0.95
		var len_px: float = _rng.randf_range(24.0, 44.0) * scale
		_add(pos, v, delay, _rng.randf_range(0.2, 0.3), Vector2(len_px, len_px * 0.4), col, _spark_kind())


func _smoke_puff(pos: Vector2, s0: float, s1: float, life: float, delay: float) -> void:
	var v: Vector2 = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(10.0, 30.0)
	var k: int = ParticlePack.KIND_SMOKE_A + _rng.randi_range(0, 1)
	smoke.emit(pos, v, now + delay, life, Vector2(s0, s1) * fx_scale, SMOKE_COLOR, k)


func _add(pos: Vector2, vel: Vector2, delay: float, life: float, size: Vector2, color: Color, kind: int) -> void:
	additive.emit(pos, vel, now + delay, life, size * fx_scale, color, kind)


func _spark_kind() -> int:
	return ParticlePack.KIND_SPARK_A + _rng.randi_range(0, 2)


func _disc(radius: float) -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU) * radius * sqrt(_rng.randf())
