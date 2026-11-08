class_name EnemyDrawSpec
extends RefCounted
## Per-type drawing inputs for MultiMeshBuffer.fill / fill_bolts, reused every frame (no allocation).
## The renderer owns one per MultiMesh and updates `time_s` / `tick_f` before filling.

## Transform scale of every instance. The textured quads are baked at pixel size, so this is 1.0; 0 = legacy
## mode (scale = radius x visual scale, custom data left at its defaults).
var scale_px: float = 0.0
## Stand-off for ViewMath.map_dist (per type, see ViewMath.contact_standoff_px).
var standoff_px: float = ViewMath.STANDOFF_PX
## Flipbook frame count and rate (frames <= 1 or fps 0 = frame 0).
var frames: int = 1
var fps: float = 0.0
## Flipbook clock in seconds (sim time, so a paused game freezes the animation).
var time_s: float = 0.0
## Lancer mode when > 0: ticks between shots; frames come from `next_attack_tick` and `tick_f`.
var fire_gap_ticks: int = 0
## Current sim tick plus the interpolation alpha.
var tick_f: float = 0.0
var fx: EnemyFxState = null
