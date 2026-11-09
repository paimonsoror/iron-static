class_name PatchEffects
extends RefCounted
## Patch effects in the stat pipeline (GDD 02 sections 5 and 10; M4-14). Patches are external multipliers `M`
## of section 5: they enter `StatResolver` through `ExternalMults`, together with the frame modifiers, so a
## patch multiplies after the Type D product (run levels x Foundry) and after the Type C hard-cap clamp, and an
## additive patch (`patch_ceramic`) adds before the Type C clamp. Per patch of `qty` picks:
##   bonus: stat x (1 + per_pick x qty)    mult: stat x per_pick ^ qty    add: stat + per_pick x qty
## A gamble applies its cost (`cost_stat` x `cost_value ^ qty`) with the benefit. `data_yield` and
## `enemy_damage` are not upgrade rows: they ride on `StatBlock` (neutral 1.0).


## `base` (the frame modifiers, may be null) combined with the picked patches. No picks: `base` itself.
static func compose(base: ExternalMults, state: PatchState, defs: Array[PatchDef]) -> ExternalMults:
	if state == null or state.total_picks == 0:
		return base
	var m: ExternalMults = base.copy() if base != null else ExternalMults.new()
	for i: int in mini(defs.size(), state.picks.size()):
		var q: int = state.picks[i]
		if q == 0:
			continue
		var d: PatchDef = defs[i]
		for s: String in d.stat_ids():
			match d.op:
				"add":
					m.add_stat(s, d.per_pick * float(q))
				"mult":
					m.scale_stat(s, pow(d.per_pick, float(q)))
				_:
					m.scale_stat(s, 1.0 + d.per_pick * float(q))
		if d.is_gamble():
			m.scale_stat(d.cost_stat, pow(d.cost_value, float(q)))
	return m


## Picks patch `index` for `world` if it exists and is below `max_picks`: counts it, re-resolves `stats` and moves
## Cinder's hull with `hull_integrity` (a gain adds the delta like a run buy; a loss scales hp by new/old max so a
## gamble never kills Cinder by itself, impl). Returns false (no change) otherwise.
static func pick(world: SimWorld, index: int) -> bool:
	var defs: Array[PatchDef] = world.config.patches
	if index < 0 or index >= defs.size() or world.patches.qty(index) >= defs[index].max_picks:
		return false
	if not world.patches.add(index):
		return false
	var old_hull: float = world.stats.hull_integrity
	world.stats = world.resolve_stats()
	var c: CinderState = world.cinder
	var new_hull: float = world.stats.hull_integrity
	if new_hull >= old_hull:
		c.max_hp += new_hull - old_hull
		c.hp = clampf(c.hp + new_hull - old_hull, 0.0, c.max_hp)
	elif old_hull > 0.0:
		c.max_hp += new_hull - old_hull
		c.hp = clampf(c.hp * new_hull / old_hull, 0.0, c.max_hp)
	return true
