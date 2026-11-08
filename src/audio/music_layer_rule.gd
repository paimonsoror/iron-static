class_name MusicLayerRule
extends RefCounted
## One row of `assets/audio/music_layers.csv`: when a music layer is audible. Thresholds are data, not code.

var layer: String = ""
## Layer is on from this wave on (0 = never by wave).
var min_wave: int = 0
var on_boss: bool = false
## Layer is on when the integrity band is >= `low_hp_band` (0 = never by integrity).
var low_hp_band: int = 0
## Linear volume (0..1) while in the menu / home screen (0 = silent there).
var menu_level: float = 0.0
## Linear volume (0..1) while the layer is switched on during a run.
var active_level: float = 1.0
var fade_in_s: float = 4.0
var fade_out_s: float = 6.0
