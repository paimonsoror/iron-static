class_name PolicyBot
extends RefCounted
## Deterministic greedy buyer for headless balance runs (M2-13). No randomness; buys only through
## `world.command_buy` (so runs are recorded and replayable) and reads costs through `UpgradeSystem.preview`.
## The runner calls `think(world)` every THINK_INTERVAL ticks (before that tick's `step()`).
## Policies: "greedy4" = the four starting rows (ids in GREEDY4_IDS), "all" = every visible row,
## "only:<row id>" = that single row (M3 balance check). R1-01 honesty-check policies over every visible row:
## "cheapest" = always the row with the cheapest next level, "random" = a random affordable row (own `Rng` stream
## derived from the config seed, so a run stays a pure function of (seed, config)).
## Rule: for each candidate row, gain = score(after one more level) / score(now) - 1 with
## score = ref_dmg * ref_ehp; ratio = gain / cost; the best ratio wins (lowest row index on ties).
## **(impl)** If the winner is unaffordable the bot waits (saves). After a purchase it re-evaluates in the
## same call, up to MAX_BUYS_PER_THINK, so late runs are not limited to one level per interval. Rows that
## do not change the score (scrap_yield, reinvest, optic_range, ...) have ratio 0 and are never bought.

const THINK_INTERVAL: int = 15
const MAX_BUYS_PER_THINK: int = 64
const GREEDY4_IDS: PackedStringArray = ["laser_output", "cycle_rate", "hull_integrity", "nano_repair"]
## `only:<row id>` policy: buys just that row (balance check of single purchases).
const ONLY_PREFIX: String = "only:"
const POLICY_CHEAPEST: String = "cheapest"
const POLICY_RANDOM: String = "random"
const DRAFT_FIRST: String = "first"
const DRAFT_RANDOM: String = "random"
## Headless draft pick policy (`--draft first|random` of balance_run and journey_run): `first` takes slot 0 (ARMS).
static var draft_mode: String = DRAFT_FIRST

var policy: String = "greedy4"
var _rng: Rng = null


func _init(policy_name: String = "greedy4") -> void:
	policy = policy_name


## Draft policy hook (M4-15): the offer slot every headless policy takes (the first offer). Deterministic, so a bot run
## that picks stays a pure function of (seed, config). Runners call `settle_draft` every iteration, not only on
## think ticks, because a draft freezes the tick counter.
static func pick_offer(world: SimWorld) -> int:
	if draft_mode == DRAFT_RANDOM and not world.draft.offers.is_empty():
		# Deterministic pseudo-random slot from the seed and the tick (no RNG stream touched): the lower bound of
		# what drafts are worth (R1-02 tune); `first` (always the ARMS card) is the upper bound.
		return posmod(world.config.seed_value * 31 + world.tick, world.draft.offers.size())
	return 0


## Picks for an open draft (through `command_pick`, so the pick is logged and replayable). True when it picked.
static func settle_draft(world: SimWorld) -> bool:
	return world.is_draft_open() and world.command_pick(pick_offer(world))


func think(world: SimWorld) -> void:
	var allowed: PackedInt32Array = _candidates(world)
	if policy == POLICY_CHEAPEST:
		_buy_cheapest(world, allowed)
		return
	if policy == POLICY_RANDOM:
		_buy_random(world, allowed)
		return
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


## Always the visible row with the cheapest next level (first row on ties); waits and saves when it is not affordable.
func _buy_cheapest(world: SimWorld, allowed: PackedInt32Array) -> void:
	for buy_round: int in MAX_BUYS_PER_THINK:
		var best: int = -1
		var best_cost: float = INF
		for i: int in allowed:
			var p: UpgradePreview = UpgradeSystem.preview(world, i, 1)
			if p.maxed or not p.visible:
				continue
			var cost: float = p.cost.to_float()
			if cost < best_cost:
				best_cost = cost
				best = i
		if best < 0 or world.command_buy(best, 1) == 0:
			return


## A uniformly random affordable visible row, until nothing is affordable.
func _buy_random(world: SimWorld, allowed: PackedInt32Array) -> void:
	if _rng == null:
		_rng = Rng.derive(world.config.seed_value, "policy_random")
	for buy_round: int in MAX_BUYS_PER_THINK:
		var ok: PackedInt32Array = PackedInt32Array()
		for i: int in allowed:
			var p: UpgradePreview = UpgradeSystem.preview(world, i, 1)
			if not p.maxed and p.visible and p.affordable:
				if ok.append(i):
					push_error("PolicyBot: append failed")
		if ok.is_empty():
			return
		if world.command_buy(ok[_rng.range_int(0, ok.size() - 1)], 1) == 0:
			return


func _candidates(world: SimWorld) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var defs: Array[RunUpgradeDef] = world.config.upgrades
	for i: int in defs.size():
		if world.visible[i] == 0:
			continue
		if policy == "greedy4" and not GREEDY4_IDS.has(defs[i].id):
			continue
		if policy.begins_with(ONLY_PREFIX) and defs[i].id != policy.trim_prefix(ONLY_PREFIX):
			continue
		if out.append(i):
			push_error("PolicyBot: append failed")
	return out
