class_name Haptics
extends RefCounted
## Haptics service (M4-22, 07 s4/s7): short tick on purchase, medium on boss spawn, long on death; micro-events
## (hits, kills, shots) never buzz. Owned by `Game` (`Game.haptics`); node layer only, never called from src/sim or
## src/meta. Own on/off switch (`enabled`, M4-23 binds it to the haptics setting); not tied to audio mute.
## Rate limit: at most one pulse per MIN_GAP_MS, except the boss and death pulses, which always play.
## Hold-to-buy: the tick plays on the first buy of a streak and on every BUY_REPEAT_EVERY-th repeat after it; a
## streak ends after BUY_GAP_MS without a buy.

const BUY_MS: int = 15
const BOSS_MS: int = 80
const DEATH_MS: int = 250
const PICK_MS: int = 25
const TIER_MS: int = 35
const TIER_TOP_MS: int = 70
const BUY_AMP: float = 0.4
const BOSS_AMP: float = 0.7
const DEATH_AMP: float = 1.0
const PICK_AMP: float = 0.5
const TIER_AMP: float = 0.6
const TIER_TOP_AMP: float = 0.8
const MIN_GAP_MS: int = 60
const BUY_REPEAT_EVERY: int = 10
const BUY_GAP_MS: int = 400

## Master switch (default on).
var enabled: bool = true
var sink: HapticsSink = HapticsSink.new()
## Returns a monotonic time in ms; tests replace it.
var clock: Callable = Time.get_ticks_msec

var _last_pulse_ms: int = -1000000
var _last_buy_ms: int = -1000000
var _streak: int = 0


## The sink for this platform: the device motor on Android, a no-op elsewhere.
static func platform_sink() -> HapticsSink:
	if OS.has_feature("android"):
		return DeviceHapticsSink.new()
	return HapticsSink.new()


## A service with the platform sink.
static func create() -> Haptics:
	var h: Haptics = Haptics.new()
	h.sink = platform_sink()
	return h


## One purchase step (a tap or one repeat of a hold).
func buy() -> void:
	var now: int = _now()
	if now - _last_buy_ms > BUY_GAP_MS:
		_streak = 0
	_last_buy_ms = now
	var due: bool = _streak % BUY_REPEAT_EVERY == 0
	_streak += 1
	if due:
		_play(BUY_MS, BUY_AMP, false)


## The tier pulse of a purchase that reaches a new visual tier (VT-5): it REPLACES that purchase's buy tick, counts as
## a buy step of the hold streak and is not dropped by the rate limit (a tick just before it must not eat it).
## MK II and III: 35 ms at 0.6; the top mark (MK IV): 70 ms at 0.8.
func tier_up(top: bool) -> void:
	_last_buy_ms = _now()
	_streak += 1
	if top:
		_play(TIER_TOP_MS, TIER_TOP_AMP, true)
	else:
		_play(TIER_MS, TIER_AMP, true)


func boss_spawn() -> void:
	_play(BOSS_MS, BOSS_AMP, true)


func death() -> void:
	_play(DEATH_MS, DEATH_AMP, true)


func draft_pick() -> void:
	_play(PICK_MS, PICK_AMP, false)


func _play(duration_ms: int, amplitude: float, urgent: bool) -> void:
	if not enabled:
		return
	var now: int = _now()
	if not urgent and now - _last_pulse_ms < MIN_GAP_MS:
		return
	_last_pulse_ms = now
	sink.pulse(duration_ms, amplitude)


func _now() -> int:
	var t: int = clock.call()
	return t
