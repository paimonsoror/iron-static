class_name MusicIntensity
extends RefCounted
## Pure adaptive-music model: rules (from `assets/audio/music_layers.csv`) + MusicState -> target linear
## volume per layer, plus the per-frame fade step. No engine calls, no randomness.

const CSV_PATH: String = "res://assets/audio/music_layers.csv"

var rules: Array[MusicLayerRule] = []
var error: String = ""


static func from_text(text: String, source: String = "<text>") -> MusicIntensity:
	var m: MusicIntensity = MusicIntensity.new()
	var table: CsvTable = CsvTable.parse(text, source)
	m._read(table)
	return m


static func load_default() -> MusicIntensity:
	var m: MusicIntensity = MusicIntensity.new()
	m._read(CsvTable.load_file(CSV_PATH))
	return m


## Target linear volume (0..1) of every rule, in rule order.
func targets(state: MusicState) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for r: MusicLayerRule in rules:
		@warning_ignore("return_value_discarded")
		out.append(_target(r, state))
	return out


## One frame of a linear fade toward `target` (full scale in `fade_in_s` going up, `fade_out_s` going down).
static func step(current: float, target: float, dt: float, fade_in_s: float, fade_out_s: float) -> float:
	if is_equal_approx(current, target):
		return target
	if target > current:
		return minf(target, current + dt / maxf(fade_in_s, 0.001))
	return maxf(target, current - dt / maxf(fade_out_s, 0.001))


func _target(r: MusicLayerRule, s: MusicState) -> float:
	if s.in_menu:
		return r.menu_level
	var on: bool = r.min_wave > 0 and s.wave >= r.min_wave
	on = on or (r.on_boss and s.boss_active)
	on = on or (r.low_hp_band > 0 and s.integrity_band >= r.low_hp_band)
	return r.active_level if on else 0.0


func _read(table: CsvTable) -> void:
	if not table.error.is_empty():
		error = table.error
		return
	for i: int in range(table.rows.size()):
		var r: MusicLayerRule = MusicLayerRule.new()
		r.layer = table.get_value(i, "layer")
		if r.layer.is_empty():
			error = "%s: row %d has no layer" % [table.path, i + 1]
			return
		r.min_wave = table.get_value(i, "min_wave").to_int()
		r.on_boss = table.get_value(i, "on_boss") == "1"
		r.low_hp_band = table.get_value(i, "low_hp_band").to_int()
		r.menu_level = clampf(table.get_value(i, "menu_level").to_float(), 0.0, 1.0)
		r.active_level = clampf(table.get_value(i, "active_level").to_float(), 0.0, 1.0)
		r.fade_in_s = table.get_value(i, "fade_in_s").to_float()
		r.fade_out_s = table.get_value(i, "fade_out_s").to_float()
		rules.append(r)
