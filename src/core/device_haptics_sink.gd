class_name DeviceHapticsSink
extends HapticsSink
## Android sink: `Input.vibrate_handheld` (needs the VIBRATE permission in the export preset).


func pulse(duration_ms: int, amplitude: float) -> void:
	Input.vibrate_handheld(duration_ms, amplitude)
