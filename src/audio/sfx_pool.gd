class_name SfxPool
extends RefCounted
## Players of one sound id: `gate` decides which voice may start, `players[i]` realizes voice i (own pitch).

var gate: VoiceGate = VoiceGate.new()
var players: Array[AudioStreamPlayer] = []


func set_paused(paused: bool) -> void:
	for p: AudioStreamPlayer in players:
		p.stream_paused = paused
