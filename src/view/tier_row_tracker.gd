class_name TierRowTracker
extends RefCounted
## Last seen run level of every upgrade row plus the stat id of each row (VT-5): turns "row r is now at level n" into
## the tier-up it announces. Shared by the director (polls the world), the audio router and the haptic hooks (feed
## UPGRADE_BOUGHT events), so all three agree. Presentation only; reads the world, never writes it. `bind` and `sync`
## adopt the current levels without announcing anything (resume, rebind, fast-forward).

var _model: VisualTierModel = null
var _stats: PackedStringArray = PackedStringArray()
var _levels: PackedInt32Array = PackedInt32Array()


func _init(model: VisualTierModel = null) -> void:
	_model = model if model != null else VisualTierModel.shared()


## Adopts the rows and levels of `world` (nothing is announced).
func bind(world: SimWorld) -> void:
	_stats = PackedStringArray()
	for def: RunUpgradeDef in world.config.upgrades:
		@warning_ignore("return_value_discarded")
		_stats.append(def.id)
	_levels = PackedInt32Array()
	@warning_ignore("return_value_discarded")
	_levels.resize(_stats.size())
	sync(world)


## Re-adopts the current levels without announcing.
func sync(world: SimWorld) -> void:
	for i: int in mini(_levels.size(), world.run_levels.size()):
		_levels[i] = world.run_levels[i]


func row_count() -> int:
	return _stats.size()


func stat_at(row: int) -> String:
	return _stats[row] if row >= 0 and row < _stats.size() else ""


func tier_model() -> VisualTierModel:
	return _model


## Records `level` for `row` and returns the tier it announces (0 = none).
func observe(row: int, level: int) -> int:
	if row < 0 or row >= _levels.size():
		return 0
	var old: int = _levels[row]
	_levels[row] = level
	return _model.tier_up(_stats[row], old, level)


## True when `tier` is the top mark of the row's stat.
func is_top(row: int, tier: int) -> bool:
	return tier >= _model.max_tier(stat_at(row))
