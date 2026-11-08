class_name VoiceGate
extends RefCounted
## Pure voice-cap and cooldown logic for one sound id (no engine calls; times are injected, in ms).
## `acquire` returns the voice index to use, or -1 when the sound must be skipped (cooldown not over, or all
## voices busy). The director maps voice indexes to the AudioStreamPlayers of a pool.

var voice_cap: int = 1
var cooldown_ms: int = 0
var _end_ms: PackedInt64Array = PackedInt64Array()
var _last_start_ms: int = -1000000000


func _init(cap: int = 1, cooldown: int = 0) -> void:
	voice_cap = maxi(cap, 1)
	cooldown_ms = maxi(cooldown, 0)
	@warning_ignore("return_value_discarded")
	_end_ms.resize(voice_cap)
	_end_ms.fill(-1)


## Number of voices still sounding at `now_ms`.
func active(now_ms: int) -> int:
	var n: int = 0
	for e: int in _end_ms:
		if e > now_ms:
			n += 1
	return n


## Claims a voice for a sound of `length_ms` starting at `now_ms`; -1 = skip it.
func acquire(now_ms: int, length_ms: int) -> int:
	if now_ms - _last_start_ms < cooldown_ms:
		return -1
	for i: int in range(voice_cap):
		if _end_ms[i] <= now_ms:
			_end_ms[i] = now_ms + maxi(length_ms, 1)
			_last_start_ms = now_ms
			return i
	return -1


## Frees every voice (pause, stop or reset).
func clear() -> void:
	_end_ms.fill(-1)
	_last_start_ms = -1000000000
