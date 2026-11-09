class_name FxRecipes
extends RefCounted
## Pure numbers of the particle effects (art bible 6.1, 6.4, 6.5, V1-13): per-type kill recipes, ember rates, LOD
## thinning and the per-frame effect budgets. No Node, no randomness; FxEmitter spends these numbers.

## Per enemy type (sim row: skitter, dart, walker, lancer, boss_hulk).
const ACCENTS: Array[Color] = [Color("#FF2D4B"), Color("#FF4FD8"), Color("#FF7A1A"), Color("#A35CFF"), Color("#FF1F3D")]
const KILL_SHARDS: Array[int] = [5, 5, 12, 5, 24]
const KILL_SPARKS: Array[int] = [4, 4, 6, 4, 40]
const KILL_SMOKE: Array[int] = [1, 1, 1, 1, 6]
## Boss: three staggered thick rings and three secondary mini bursts (flash + MINI_SPARKS + MINI_SHARDS each).
const BOSS_RINGS: int = 3
const BOSS_MINI_BURSTS: int = 3
const MINI_SPARKS: int = 6
const MINI_SHARDS: int = 4
const BOSS_TYPE: int = 4
const WALKER_TYPE: int = 2
## Hit impact base counts (6.1): flash + ring + sparks + halo = 9 at 6 sparks.
const CRIT_SPARKS: int = 12
## LOD thresholds on alive enemies (6.3): above 100 sparks halve, above 150 they drop to 2 and rings/smoke go.
const LOD_HALVE_ABOVE: int = 100
const LOD_MIN_ABOVE: int = 150
const LOD_MIN_SPARKS: int = 2
## Embers per second by exposure band 0..3 (6.5).
const EMBER_RATES: Array[float] = [0.0, 3.0, 8.0, 14.0]
## Wedges affected by entering band 1, 2, 3 (index = new band): 4 embers each on a band change.
const BAND_WEDGES: Array = [[], [2, 7, 10], [0, 3, 5, 8, 11], [1, 4, 6, 9]]
const EMBERS_PER_WEDGE: int = 4
const BAND_RING_COLORS: Array[Color] = [Color("#FFB000"), Color("#FFB000"), Color("#FF8A1F"), Color("#FF3B30")]
## Per-frame budgets (extra work beyond them is skipped, not queued): [HIGH, MID, LOW].
const HIT_BUDGET: Array[int] = [6, 4, 3]
const KILL_BUDGET: Array[int] = [16, 10, 6]
const CINDER_HIT_BUDGET: int = 3
## Particles one frame may write for hits and kills together (the boss is exempt): [HIGH, MID, LOW].
const PARTICLE_BUDGET: Array[int] = [120, 80, 48]
const MAX_EMBERS_PER_FRAME: int = 4
## Sparks of a Cinder hit (6.5).
const CINDER_HIT_SPARKS: int = 4
## VT-4 deflection sparks: radius of the ricochet point as a fraction of the armor ring radius (plate edge) and the
## spark counts (cap per hit, MID, reduce motion).
const DEFLECT_EDGE: float = 1.22
const DEFLECT_SPARKS_MAX: int = 6
const DEFLECT_SPARKS_MID: int = 4
const DEFLECT_SPARKS_REDUCED: int = 3
## VT-4 repair motes: life in s, spawn rate share at full integrity (1.0 while hurt), count share of MID and of
## reduce motion, and the per-frame spawn cap.
const MOTE_LIFE_S: float = 1.3
const MOTE_IDLE_RATE: float = 0.4
const MOTE_MID_SHARE: float = 0.6
const MOTE_REDUCED_SHARE: float = 0.5
const MAX_MOTES_PER_FRAME: int = 3
## Hits on one enemy within this many sim seconds do not spawn a second impact (a beam burst on one target).
const HIT_COOLDOWN_S: float = 0.05


## Sparks after the density LOD: above 150 alive two, above 100 half (at least 1), else `base`.
static func lod_sparks(base: int, alive: int) -> int:
	if alive > LOD_MIN_ABOVE:
		return mini(base, LOD_MIN_SPARKS)
	if alive > LOD_HALVE_ABOVE:
		return maxi(floori(float(base) / 2.0), 1)
	return base


## Rings and impact flashes are allowed below 150 alive, with the tier switch on and without reduce motion.
static func rings_allowed(alive: int, tier_rings: bool, reduce_motion: bool) -> bool:
	return tier_rings and not reduce_motion and alive <= LOD_MIN_ABOVE


static func smoke_allowed(alive: int) -> bool:
	return alive <= LOD_HALVE_ABOVE


static func ember_rate(band: int) -> float:
	return EMBER_RATES[clampi(band, 0, EMBER_RATES.size() - 1)]


static func accent(type_index: int) -> Color:
	return ACCENTS[clampi(type_index, 0, ACCENTS.size() - 1)]


## Particles of one kill burst (flash, rings, shards, sparks, smoke; boss includes its mini bursts and flare).
static func kill_total(type_index: int, alive: int, rings_ok: bool) -> int:
	var t: int = clampi(type_index, 0, ACCENTS.size() - 1)
	if t == BOSS_TYPE:
		var rings: int = BOSS_RINGS if rings_ok else 0
		var mini_each: int = 1 + MINI_SPARKS + MINI_SHARDS
		return 1 + 1 + rings + KILL_SHARDS[t] + KILL_SPARKS[t] + KILL_SMOKE[t] + BOSS_MINI_BURSTS * mini_each
	var n: int = 1 + KILL_SHARDS[t] + lod_sparks(KILL_SPARKS[t], alive)
	if rings_ok:
		n += 1
	if smoke_allowed(alive):
		n += KILL_SMOKE[t]
	return n


## Particles of one hit impact: flash + halo + sparks, plus the ring when allowed; crit adds a star and a second ring.
static func impact_total(sparks_per_hit: int, alive: int, crit: bool, rings_ok: bool) -> int:
	var sparks: int = lod_sparks(CRIT_SPARKS if crit else sparks_per_hit, alive)
	var n: int = 2 + sparks
	if rings_ok:
		n += 1
	if crit:
		n += 1
		if rings_ok:
			n += 1
	return n


## Hit-effect budget per frame for a tier index (0 HIGH, 1 MID, 2 LOW).
static func hit_budget(tier: int) -> int:
	return HIT_BUDGET[clampi(tier, 0, 2)]


static func particle_budget(tier: int) -> int:
	return PARTICLE_BUDGET[clampi(tier, 0, 2)]


static func kill_budget(tier: int) -> int:
	return KILL_BUDGET[clampi(tier, 0, 2)]


## Sparks of one deflection (0 on LOW): 5 to 6 at HIGH by the PLATED tier scale, 4 on MID, 3 under reduce motion.
static func deflect_sparks(tier: int, reduce_motion: bool, tier_scale: float) -> int:
	if tier >= 2:
		return 0
	if reduce_motion:
		return DEFLECT_SPARKS_REDUCED
	if tier == 1:
		return DEFLECT_SPARKS_MID
	return clampi(roundi(5.0 * tier_scale), 1, DEFLECT_SPARKS_MAX)


## Live repair motes wanted at quality `tier`: 0 on LOW, 60% on MID, half under reduce motion (the smaller of the two).
static func mote_count(base: int, tier: int, reduce_motion: bool) -> int:
	if tier >= 2 or base <= 0:
		return 0
	var share: float = 1.0
	if tier == 1:
		share = MOTE_MID_SHARE
	if reduce_motion:
		share = minf(share, MOTE_REDUCED_SHARE)
	return maxi(roundi(float(base) * share), 1)


## Mote spawns per second: count / life, at 40% while Cinder is at full integrity and 100% while hurt.
static func mote_rate(count: int, hurt: bool) -> float:
	return float(count) / MOTE_LIFE_S * (1.0 if hurt else MOTE_IDLE_RATE)
