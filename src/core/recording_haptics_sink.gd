class_name RecordingHapticsSink
extends HapticsSink
## Test sink: remembers every pulse as `Vector2(duration_ms, amplitude)`.

var pulses: Array[Vector2] = []


func pulse(duration_ms: int, amplitude: float) -> void:
	pulses.append(Vector2(float(duration_ms), amplitude))


func durations() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for p: Vector2 in pulses:
		@warning_ignore("return_value_discarded")
		out.append(int(p.x))
	return out
