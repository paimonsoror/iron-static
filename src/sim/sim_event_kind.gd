class_name SimEventKind
extends RefCounted
## Event kinds pushed into SimEvents (M1 shared contract). `a` and `b` meanings per kind:

const WAVE_STARTED: int = 0  ## a = wave number
const WAVE_ENDED: int = 1  ## a = wave number
const ENEMY_SPAWNED: int = 2  ## a = enemy index, b = type index
const SHOT_FIRED: int = 3  ## a = target enemy index, b = crit 0/1
const ENEMY_HIT: int = 4  ## a = enemy index, b = damage (int)
const ENEMY_KILLED: int = 5  ## a = enemy index, b = type index
const CINDER_HIT: int = 6  ## a = damage (int), b = attacker type index
const BAND_CHANGED: int = 7  ## a = old band, b = new band
const BOSS_SPAWNED: int = 8  ## a = enemy index
const RUN_ENDED: int = 9  ## a = wave, b = death cause (enemy type index, -1 none)
const COUNT: int = 10
