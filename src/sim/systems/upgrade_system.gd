class_name UpgradeSystem
extends RefCounted
## Buying run upgrades with scrap (GDD 02 sections 5 and 7). Cost of the next level is `ceil(c0 * g^L)`,
## sequential sums, no discount. Costs are summed as floats (exact below 2^53) and wrapped into BigNum at the
## boundary. **(impl)** counts other than 1, 10, 100, -1 (Max) are rejected; x10/x100 buy a partial amount.


## Buys up to `count` levels of row `index` (1, 10, 100, -1 = Max). Returns the levels bought (0 = rejected,
## no state change). Re-resolves `stats`; `hull_integrity` raises max hp and hp by the same delta (impl).
static func buy(world: SimWorld, index: int, count: int) -> int:
	var p: UpgradePreview = preview(world, index, count)
	if p.levels <= 0:
		return 0
	var eco: EconomyState = world.economy
	eco.scrap = eco.scrap.sub_floor0(p.cost)
	var new_level: int = p.level + p.levels
	world.run_levels[index] = new_level
	var old_hull: float = world.stats.hull_integrity
	world.stats = world.resolve_stats()
	var delta: float = world.stats.hull_integrity - old_hull
	if delta != 0.0:
		var c: CinderState = world.cinder
		c.max_hp += delta
		c.hp = clampf(c.hp + delta, 0.0, c.max_hp)
	world.events.push(SimEventKind.UPGRADE_BOUGHT, index, new_level)
	return p.levels


## What a buy of `count` would do right now. Pure: no state change. Invalid index or count gives an
## invisible, unaffordable preview with zero levels.
static func preview(world: SimWorld, index: int, count: int) -> UpgradePreview:
	var p: UpgradePreview = UpgradePreview.new()
	p.index = index
	p.requested = count
	p.cost = BigNum.zero()
	var defs: Array[RunUpgradeDef] = world.config.upgrades
	if index < 0 or index >= defs.size():
		return p
	var def: RunUpgradeDef = defs[index]
	var level: int = world.run_levels[index]
	p.level = level
	p.visible = world.visible[index] != 0
	p.maxed = level >= def.l_cap
	p.levels_to_milestone = StatResolver.levels_to_next_milestone(level)
	p.current_value = _value(world, index, level)
	if p.maxed:
		p.next_value = p.current_value
		return p
	var want: int = _want(count, def.l_cap - level)
	var total: float = 0.0
	var first: float = Curves.upgrade_cost(def.c0, def.g, level)
	if p.visible and want > 0:
		var budget: float = world.economy.scrap.to_float()
		var n: int = 0
		while n < want:
			var c: float = first if n == 0 else Curves.upgrade_cost(def.c0, def.g, level + n)
			if total + c > budget:
				break
			total += c
			n += 1
		p.levels = n
	p.affordable = p.levels > 0
	p.cost = BigNum.from_float(total if p.levels > 0 else first)
	p.next_value = _value(world, index, level + maxi(p.levels, 1))
	return p


## Levels a mode asks for, bounded by the room below `l_cap`; 0 for an unsupported count.
static func _want(count: int, room: int) -> int:
	if count == -1:
		return room
	if count == 1 or count == 10 or count == 100:
		return mini(count, room)
	return 0


## Stat value of row `index` at run `level` including this world's Foundry levels and frame modifiers, so
## previews show the real stat (M3-07/M3-22).
static func _value(world: SimWorld, index: int, level: int) -> float:
	var cfg: SimConfig = world.config
	var def: RunUpgradeDef = cfg.upgrades[index]
	var fl: int = cfg.foundry_levels[index] if index < cfg.foundry_levels.size() else 0
	var ff: float = cfg.foundry_f[index] if index < cfg.foundry_f.size() else 0.0
	var ext: ExternalMults = world.frame_ext
	if ext == null:
		return StatResolver.value_at(def, level, fl, ff)
	return StatResolver.value_at(def, level, fl, ff, ext.mult_for(def.id), ext.add_for(def.id))
