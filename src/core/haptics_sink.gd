class_name HapticsSink
extends RefCounted
## Where a haptic pulse ends up (M4-22). The base class is the desktop no-op sink; `RecordingHapticsSink` is for
## tests and `DeviceHapticsSink` calls the handheld motor on Android.

## Plays one pulse. `amplitude` is 0..1 (Godot: -1 would mean the device default).
@warning_ignore("unused_parameter")
func pulse(duration_ms: int, amplitude: float) -> void:  # gdlint: ignore=unused-argument
	pass
