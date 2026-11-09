class_name IntelWavePanel
extends IntelPanel
## The INTEL tab's Wave panel (M4-19): the same card list and 4 Hz refresh as the Stats panel, with rows from
## `IntelWaveModel` (wave and mode, time or quota left, boss and draft countdowns, slots, stale count, enemy mix).


func _title_key() -> String:
	return "intel.wave.title"


func _build_rows() -> Array[IntelRow]:
	return IntelWaveModel.build(_world)
