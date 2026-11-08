class_name HudModel
extends RefCounted
## Pure text model of the HUD counters (M2-11; GDD 07 section 2.1, 04 section 5): wave, integrity, scrap and run
## data through `NumberFormat`. `update` is throttled to 10 Hz of the caller's clock and otherwise keeps the cached
## strings, so the HUD can call it every frame without string churn.

const REFRESH_S: float = 0.1

var wave_text: String = ""
var hp_text: String = ""
var scrap_text: String = ""
var data_text: String = ""
## Whole seconds left in the wave ("14s"); empty until a wave_tick is given.
var timer_text: String = ""

var _last_s: float = -1.0
var _wave: int = -1
var _hp: int = -1
var _max_hp: int = -1
var _scrap_key: String = ""
var _data_key: String = ""
var _secs_left: int = -1


## True when `now_s` is at least REFRESH_S after the last accepted refresh (the first call is always due).
func due(now_s: float) -> bool:
	if _last_s >= 0.0 and now_s - _last_s < REFRESH_S:
		return false
	_last_s = now_s
	return true


## Throttled: recomputes the texts only when `due(now_s)`. Returns true when it recomputed.
func update(
	now_s: float, wave: int, hp: float, max_hp: float, scrap: BigNum, data: BigNum, wave_tick: int = -1
) -> bool:
	if not due(now_s):
		return false
	set_values(wave, hp, max_hp, scrap, data, wave_tick)
	return true


## Unthrottled recompute; a string is rebuilt only when its source value changed.
func set_values(wave: int, hp: float, max_hp: float, scrap: BigNum, data: BigNum, wave_tick: int = -1) -> void:
	if wave_tick >= 0:
		var secs: int = ceili(float(maxi(Ticks.WAVE_TICKS - wave_tick, 0)) / float(Ticks.TICK_RATE))
		if secs != _secs_left:
			_secs_left = secs
			timer_text = Strings.fill1("hud.timer", "n", str(secs))
	if wave != _wave:
		_wave = wave
		wave_text = Strings.fill1("hud.wave", "n", str(wave))
	var hp_i: int = ceili(maxf(hp, 0.0))
	var max_i: int = ceili(maxf(max_hp, 0.0))
	if hp_i != _hp or max_i != _max_hp:
		_hp = hp_i
		_max_hp = max_i
		hp_text = (
			Strings
			. fill(
				"hud.hp",
				{
					"a": NumberFormat.format(BigNum.from_int(hp_i)),
					"b": NumberFormat.format(BigNum.from_int(max_i)),
				}
			)
		)
	var sk: String = scrap.to_text()
	if sk != _scrap_key:
		_scrap_key = sk
		scrap_text = Strings.fill1("hud.scrap", "v", NumberFormat.format(scrap))
	var dk: String = data.to_text()
	if dk != _data_key:
		_data_key = dk
		data_text = Strings.fill1("hud.data", "v", NumberFormat.format(data))
