class_name MusicState
extends RefCounted
## Inputs of the MusicIntensity model (view-side snapshot; never fed back into the sim).

var wave: int = 0
var boss_active: bool = false
## Skin-burn integrity band 0..3 (3 = lowest integrity).
var integrity_band: int = 0
var in_menu: bool = true


static func make(wave_no: int, boss: bool, band: int, menu: bool) -> MusicState:
	var s: MusicState = MusicState.new()
	s.wave = wave_no
	s.boss_active = boss
	s.integrity_band = band
	s.in_menu = menu
	return s
