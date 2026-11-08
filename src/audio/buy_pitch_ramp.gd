class_name BuyPitchRamp
extends RefCounted
## Pitch steps for `sfx_upgrade_buy` during a press-and-hold repeat buy: each consecutive buy raises the pitch by
## `STEP_SEMITONES`, capped at `MAX_SEMITONES`; a gap longer than `RESET_GAP_MS` (or `reset()` on release) starts over.

const STEP_SEMITONES: float = 0.5
const MAX_SEMITONES: float = 5.0
const RESET_GAP_MS: int = 450

var _count: int = 0
var _last_ms: int = -1000000000


## Semitone offset for a buy at `now_ms` (0 for the first buy of a streak).
func next_semitones(now_ms: int) -> float:
	if now_ms - _last_ms > RESET_GAP_MS:
		_count = 0
	_last_ms = now_ms
	var st: float = minf(float(_count) * STEP_SEMITONES, MAX_SEMITONES)
	_count += 1
	return st


func reset() -> void:
	_count = 0
	_last_ms = -1000000000


## Pitch scale for a semitone offset.
static func pitch_scale(semitones: float) -> float:
	return pow(2.0, semitones / 12.0)
