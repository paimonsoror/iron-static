class_name PolicyBot
extends RefCounted
## Deterministic greedy buyer for headless balance runs (M2-13). No randomness; buys only through
## `world.command_buy` (so runs are recorded and replayable) and reads costs through `UpgradeSystem.preview`.
## The runner calls `think(world)` every THINK_INTERVAL ticks (before that tick's `step()`).
## Policies: "greedy4" = the four starting rows (ids in GREEDY4_IDS), "all" = every visible row.
## Rule: for each candidate row, gain = score(after one more level) / score(now) - 1 with
## score = ref_dmg * ref_ehp; ratio = gain / cost; the best ratio wins (lowest row index on ties).
## **(impl)** If the winner is unaffordable the bot waits (saves). After a purchase it re-evaluates in the
## same call, up to MAX_BUYS_PER_THINK, so late runs are not limited to one level per interval. Rows that
## do not change the score (scrap_yield, reinvest, optic_range, ...) have ratio 0 and are never bought.

const THINK_INTERVAL: int = 15
const MAX_BUYS_PER_THINK: int = 64
const GREEDY4_IDS: PackedStringArray = ["laser_output", "cycle_rate", "hull_integrity", "nano_repair"]

var policy: String = "greedy4"


func _init(policy_name: String = "greedy4") -> void:
	policy = policy_name


func think(world: SimWorld) -> void:
	var allowed: PackedInt32Array = _candidates(world)
	for buy_round: int in MAX_BUYS_PER_THINK:
		var base_score: float = PowerRating.score(world.stats)
		if base_score <= 0.0:
			return
		var best: int = -1
		var best_ratio: float = 0.0
		var levels: PackedInt32Array = world.run_levels.duplicate()
		for i: int in allowed:
			var p: UpgradePreview = UpgradeSystem.preview(world, i, 1)
			if p.maxed or not p.visible:
				continue
			levels[i] += 1
			var after: StatBlock = world.resolve_stats_for(levels)
			levels[i] -= 1
			var gain: float = PowerRating.score(after) / base_score - 1.0
			var cost: float = p.cost.to_float()
			if gain <= 0.0 or cost <= 0.0:
				continue
			var ratio: float = gain / cost
			if ratio > best_ratio:
				best_ratio = ratio
				best = i
		if best < 0:
			return
		if world.command_buy(best, 1) == 0:
			return  # best row not affordable yet: wait and save


func _candidates(world: SimWorld) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var defs: Array[RunUpgradeDef] = world.config.upgrades
	for i: int in defs.size():
		if world.visible[i] == 0:
			continue
		if policy == "greedy4" and not GREEDY4_IDS.has(defs[i].id):
			continue
		if out.append(i):
			push_error("PolicyBot: append failed")
	return out
