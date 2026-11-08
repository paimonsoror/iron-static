class_name ShakeModel
extends RefCounted
## Screen shake trauma model (V1-14, art bible 6.6). Pure math, no nodes: `offset = max_px * trauma^2 * noise`,
## trauma decays 2.5/s, no rotation, hard clamp at `max_px`. Trauma sources are big events only (Cinder hit,
## exposure band getting worse, boss spawn, boss death, Cinder death). Enemy hits, kills and the player's own
## beam add 0 trauma (see `trauma_for_event`). `max_px` comes from `VisualSettings.effective_shake_px()`
## (0 when Off or reduce motion), scaled by viewport width / 1080 by the caller.

const DECAY_PER_S: float = 2.5
const MAX_TRAUMA: float = 1.0
const HIT_BASE: float = 0.08
const HIT_PER_FRACTION: float = 0.4
const HIT_CAP: float = 0.3
const BAND_WORSE: float = 0.5
const BAND_WORSE_LAST: float = 0.65
const BOSS_SPAWN: float = 0.35
const BOSS_DEATH: float = 0.7
const CINDER_DEATH: float = 0.9
const BOSS_TYPE: int = 4
const LAST_BAND: int = 3

var trauma: float = 0.0


## Trauma a Cinder hit adds: 0.08 + 0.4 * damage_fraction, capped at 0.3.
static func hit_trauma(damage_fraction: float) -> float:
	return minf(HIT_BASE + HIT_PER_FRACTION * clampf(damage_fraction, 0.0, 1.0), HIT_CAP)


## Trauma for one sim event (0 for every kind that must not shake). `max_hp` is Cinder's max hp (CINDER_HIT).
static func trauma_for_event(kind: int, a: int, b: int, max_hp: float) -> float:
	match kind:
		SimEventKind.CINDER_HIT:
			if max_hp <= 0.0:
				return HIT_BASE
			return hit_trauma(float(a) / max_hp)
		SimEventKind.BAND_CHANGED:
			if b <= a:
				return 0.0  # healing never shakes
			return BAND_WORSE_LAST if b >= LAST_BAND else BAND_WORSE
		SimEventKind.BOSS_SPAWNED:
			return BOSS_SPAWN
		SimEventKind.ENEMY_KILLED:
			return BOSS_DEATH if b == BOSS_TYPE else 0.0
		SimEventKind.RUN_ENDED:
			return CINDER_DEATH
	return 0.0


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + maxf(amount, 0.0), 0.0, MAX_TRAUMA)


func add_event(kind: int, a: int, b: int, max_hp: float) -> void:
	add_trauma(trauma_for_event(kind, a, b, max_hp))


func decay(dt: float) -> void:
	trauma = maxf(trauma - DECAY_PER_S * maxf(dt, 0.0), 0.0)


func reset() -> void:
	trauma = 0.0


## Offset in px at time `t_s` for the current trauma; exactly zero when trauma or `max_px` is 0.
func offset(t_s: float, max_px: float) -> Vector2:
	if trauma <= 0.0 or max_px <= 0.0:
		return Vector2.ZERO
	var amp: float = max_px * trauma * trauma
	var v := Vector2(
		sin(t_s * 37.0) * 0.6 + sin(t_s * 61.3 + 1.7) * 0.4, sin(t_s * 43.1 + 0.9) * 0.6 + sin(t_s * 71.7 + 2.3) * 0.4
	)
	return (v * amp).limit_length(max_px)
