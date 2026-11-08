class_name EnemyInstanceData
extends RefCounted
## Pure per-instance animation math for the textured enemy renderer (art bible 4.5, 6.2; V1-10). No state, no
## allocation. Feeds the MultiMesh custom data: x = flash, y = frame, z = spawn-in, w = phase seed.

## Hit flash length: 1.0 at the hit, linear to 0 (art bible 6.2).
const FLASH_S: float = 0.09
## Spawn-in length: scale 0.6 to 1.0 and alpha 0 to 1 (art bible 4.5).
const SPAWN_S: float = 0.2
## Lancer frames: 0 idle, 1 charge/recoil, 2 fire (slots.csv). After a shot: FIRE_S on frame 2, then frame 1
## until RECOIL_END_S, then idle.
const LANCER_FIRE_S: float = 0.12
const LANCER_RECOIL_END_S: float = 0.45
## Golden-ratio step: spreads per-instance phases evenly so crowds do not animate in lockstep.
const PHASE_STEP: float = 0.6180339
const PULSE_SEED_STEP: float = 0.137


## Flipbook frame `floor(t * fps + phase) mod frames`, always in 0..frames-1; 0 when fps is 0 or frames <= 1.
static func frame_for(time_s: float, fps: float, phase: float, frames: int) -> int:
	if frames <= 1 or fps <= 0.0:
		return 0
	return posmod(floori(time_s * fps + phase), frames)


## Per-instance phase in frames (0..frames) derived from the enemy slot index.
static func phase_for(index: int, frames: int) -> float:
	return fposmod(float(index) * PHASE_STEP, 1.0) * float(maxi(frames, 1))


## Phase seed for the shader's glow pulse (custom.w).
static func pulse_seed(index: int) -> float:
	return float(index) * PULSE_SEED_STEP


## Flash after `dt` seconds of decay: linear from 1.0 to 0 over FLASH_S, clamped to 0..1.
static func decay_flash(flash: float, dt: float) -> float:
	return clampf(flash - dt / FLASH_S, 0.0, 1.0)


## Spawn-in progress 0..1 for an enemy `age_s` seconds old (1 = fully spawned).
static func spawn_factor(age_s: float) -> float:
	return clampf(age_s / SPAWN_S, 0.0, 1.0)


## Lancer frame from the seconds since its last shot.
static func lancer_frame(since_shot_s: float) -> int:
	if since_shot_s < 0.0:
		return 0
	if since_shot_s < LANCER_FIRE_S:
		return 2
	if since_shot_s < LANCER_RECOIL_END_S:
		return 1
	return 0
