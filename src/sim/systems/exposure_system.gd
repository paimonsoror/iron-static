class_name ExposureSystem
extends RefCounted
## Regeneration, integrity bands with hysteresis, and run end (GDD 02 section 12.1, 7.2, 1 step 7).
## Bands (visual only in M1, no modifiers): f = hp / max_hp; f <= t1 band 1, <= t2 band 2, <= t3 band 3.
## Falling enters a worse band as soon as f is at or below its threshold; rising leaves a band only
## when f > its threshold + exposure_hysteresis.


static func step(world: SimWorld) -> void:
	var c: CinderState = world.cinder
	var t: SimTuning = world.config.tuning
	if c.alive:
		c.hp = minf(c.max_hp, c.hp + world.stats.nano_repair * SimWorld.DT)
	var f: float = c.hp / c.max_hp if c.max_hp > 0.0 else 0.0
	var old_band: int = c.band
	var band: int = old_band
	var raw: int = _raw_band(f, t)
	if raw > band:
		band = raw
	else:
		while band > 0 and f > _threshold(band, t) + t.exposure_hysteresis:
			band -= 1
	if band != old_band:
		c.band = band
		world.events.push(SimEventKind.BAND_CHANGED, old_band, band)
	if not c.alive:
		world.end_run()


static func _raw_band(f: float, t: SimTuning) -> int:
	if f <= t.exposure_t3:
		return 3
	if f <= t.exposure_t2:
		return 2
	if f <= t.exposure_t1:
		return 1
	return 0


## Threshold of band `b` (1-3): the f value at or below which the band is entered.
static func _threshold(b: int, t: SimTuning) -> float:
	match b:
		1:
			return t.exposure_t1
		2:
			return t.exposure_t2
		_:
			return t.exposure_t3
