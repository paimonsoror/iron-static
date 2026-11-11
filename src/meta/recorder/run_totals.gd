class_name RunTotals
extends RefCounted
## What one finished run adds to the Service Record, built once when the run is banked. `detail` says how much of it
## is known: SUMMARY (a run ended by an app update: only what the run summary holds), WORLD (the finished world:
## kills per type, damage, scrap, levels, patches) or FULL (also the event totals of a `RunTally` that saw every event).
## Sources: kills per type, damage, patches and upgrade levels come from the world's own state; shots, crits, highest
## hit, hull damage and scrap spent from the tally; scrap gained = balance at the end + scrap spent - starting scrap.

enum Detail { SUMMARY, WORLD, FULL }

var detail: Detail = Detail.SUMMARY
var mode: String = SimConfig.MODE_TIMED
var frame_id: String = ""
var ticks: int = 0
## Wave reached (the death wave, or the wave being played when the mission was aborted).
var wave: int = 0
var waves_cleared: int = 0
## Enemy id -> kills; only types with kills.
var kills: Dictionary = {}
var bosses: int = 0
var damage: BigNum = BigNum.zero()
var upgrades: int = 0
var patches: int = 0
var shots: int = 0
var crits: int = 0
var hit_max: int = 0
var hull: int = 0
var scrap_in: BigNum = BigNum.zero()
var scrap_out: BigNum = BigNum.zero()


## Basics from the run summary alone.
static func from_summary(s: RunSummary) -> RunTotals:
	var t: RunTotals = RunTotals.new()
	t.mode = s.mode if not s.mode.is_empty() else SimConfig.MODE_TIMED
	t.frame_id = s.frame_id
	t.ticks = s.ticks
	t.wave = s.death_wave
	t.waves_cleared = maxi(s.death_wave - 1, 0)
	return t


## Everything the finished (or aborted) `world` and its `tally` know.
static func from_world(world: SimWorld, tally: RunTally, s: RunSummary) -> RunTotals:
	var t: RunTotals = RunTotals.from_summary(s)
	t.detail = Detail.WORLD
	var defs: Array[EnemyDef] = world.config.enemies
	for i: int in mini(defs.size(), world.run.kills_by_type.size()):
		var n: int = world.run.kills_by_type[i]
		if n <= 0:
			continue
		t.kills[defs[i].id] = n
		if world.type_is_boss[i] != 0:
			t.bosses += n
	t.damage = BigNum.from_float(world.run.damage_dealt)
	t.patches = world.patches.total_picks
	for lv: int in world.run_levels:
		t.upgrades += lv
	if tally != null and tally.exact():
		t.detail = Detail.FULL
		t.shots = tally.shots
		t.crits = tally.crits
		t.hit_max = tally.hit_max
		t.hull = tally.hull
		t.scrap_out = tally.spent
		var start: BigNum = BigNum.from_float(world.config.tuning.start_scrap)
		t.scrap_in = world.economy.scrap.add(tally.spent).sub_floor0(start)
	return t
