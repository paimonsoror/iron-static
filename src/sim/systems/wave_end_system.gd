class_name WaveEndSystem
extends RefCounted
## End-of-wave resolution, MVP subset (GDD 02 section 9, 03 section 4.1). Runs with `world.wave` still the
## ending wave; the world increments the wave afterwards.
## Hooks not implemented in M1 (GDD 02 section 9 step numbers):
##   TODO step 1 (wave bonuses, hook in EconomySystem), 3-4 (free rolls, pods, conditions) and 8 (adaptation,
##   Intel refresh). Step 5 (draft check, M4-15) runs last, after steps 6-9: `DraftSystem.check`.
##   TODO M6 signal_lag: the level accumulator below adds a lag-skipped amount; M1 lag is 0.


static func step(world: SimWorld) -> void:
	var ending: int = world.wave
	world.events.push(SimEventKind.WAVE_ENDED, ending, 0)
	# Steps 1-2: wave bonuses (hook) and interest.
	EconomySystem.wave_end(world)
	# Step 6: enemy level increment, no skips (hook: lag 0).
	var lag_skip: int = 0
	world.level_hp += 1 - lag_skip
	world.level_atk += 1 - lag_skip
	# Step 7: boss check for the wave after the next one starts (current becomes ending + 1).
	world.next_wave_is_boss = world.is_boss_wave(ending + 2)
	world.overclock_kills = 0  # Overclock resets at the wave boundary (M3-22)
	# Step 9: stale cleanup, the third wave end after spawning marks the enemy.
	var limit: int = world.config.tuning.stale_wave_ends
	var store: EnemyStore = world.enemies
	for i: int in store.high_water:
		if store.alive[i] != 0 and ending - store.born_wave[i] + 1 >= limit:
			store.stale[i] = 1
	# Step 5: draft check, after steps 6-9 (M4-15). Opens the draft; the world then refuses to step until a pick.
	DraftSystem.check(world, ending)
