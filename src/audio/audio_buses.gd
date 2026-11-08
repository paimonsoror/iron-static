class_name AudioBuses
extends RefCounted
## Bus names of `res://default_bus_layout.tres`: Master (limiter) -> Music, SFX, UI. The Music bus has a
## compressor side-chained to SFX, so effects duck the music slightly.

const MASTER: StringName = &"Master"
const MUSIC: StringName = &"Music"
const SFX: StringName = &"SFX"
const UI: StringName = &"UI"

const ALL: Array[StringName] = [MASTER, MUSIC, SFX, UI]


## Bus index, or -1 when the layout has no such bus.
static func index_of(bus: StringName) -> int:
	return AudioServer.get_bus_index(bus)
