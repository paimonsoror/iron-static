class_name ConfigHash
extends RefCounted
## SHA-256 over the field values of tuning, enemies and upgrades (M2-07). Fields come from each def's
## script variables (every `@export`), sorted by name, so new fields are included automatically. Floats
## are hashed as raw 64-bit values; order of the enemy and upgrade rows matters.
## R1-02: `META_ONLY_KEYS` (the Foundry soft cap rows) steer only the meta layer and are not hashed, so tuning them does
## not end a run in progress (review C-07).
## SimVersion 4 (M4-15): the `draft_*` tuning vars and the patch defs (`cfg.patches`, row order) are hashed.

const META_ONLY_KEYS: PackedStringArray = [
	"foundry_cap_k", "foundry_cap_min", "foundry_over_cap_mult", "foundry_over_cap_growth"
]


static func compute(cfg: SimConfig) -> String:
	var ctx: HashingContext = HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		push_error("ConfigHash: start failed")
		return ""
	_put_resource(ctx, cfg.tuning, META_ONLY_KEYS)
	_put_text(ctx, "enemies:%d" % cfg.enemies.size())
	for e: EnemyDef in cfg.enemies:
		_put_resource(ctx, e)
	_put_text(ctx, "upgrades:%d" % cfg.upgrades.size())
	for u: RunUpgradeDef in cfg.upgrades:
		_put_resource(ctx, u)
	_put_text(ctx, "patches:%d" % cfg.patches.size())
	for p: PatchDef in cfg.patches:
		_put_resource(ctx, p)
	_put_foundry(ctx, cfg)
	_put_text(
		ctx,
		(
			"mode:%s;backstop:%d;reward:%s;"
			% [
				cfg.wave_mode,
				cfg.purge_backstop_ticks,
				PackedFloat64Array([cfg.reward_mult]).to_byte_array().hex_encode()
			]
		)
	)
	var fm: FrameMods = cfg.frame
	if fm != null and not fm.is_neutral():
		_put_text(ctx, fm.hash_text(cfg.frame_id))
	return ctx.finish().hex_encode()


static func _put_text(ctx: HashingContext, text: String) -> void:
	var bytes: PackedByteArray = text.to_utf8_buffer()
	if bytes.is_empty():
		return
	if ctx.update(bytes) != OK:
		push_error("ConfigHash: update failed")


static func _put_resource(ctx: HashingContext, res: Resource, skip: PackedStringArray = PackedStringArray()) -> void:
	var names: PackedStringArray = PackedStringArray()
	for p: Dictionary in res.get_property_list():
		var usage: int = p["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			var prop_name: String = p["name"]
			if skip.has(prop_name):
				continue
			if names.append(prop_name):
				push_error("ConfigHash: append failed")
	names.sort()
	for n: String in names:
		var value: Variant = res.get(n)
		var text: String
		match typeof(value):
			TYPE_FLOAT:
				var v: float = value
				text = "%s=f%s;" % [n, PackedFloat64Array([v]).to_byte_array().hex_encode()]
			TYPE_INT:
				text = "%s=i%d;" % [n, value]
			TYPE_BOOL:
				text = "%s=b%d;" % [n, 1 if value else 0]
			_:
				text = "%s=s%s;" % [n, str(value)]
		_put_text(ctx, text)


## `foundry:` section (M3-07): appended only when some level is non-zero, so all-zero configs keep their
## pre-M3 hash. Triples of (row index, level, raw bits of f) in row order.
static func _put_foundry(ctx: HashingContext, cfg: SimConfig) -> void:
	var text: String = ""
	for i: int in cfg.foundry_levels.size():
		var level: int = cfg.foundry_levels[i]
		if level == 0:
			continue
		var f: float = cfg.foundry_f[i] if i < cfg.foundry_f.size() else 0.0
		text += "%d:%d:%s;" % [i, level, PackedFloat64Array([f]).to_byte_array().hex_encode()]
	if text != "":
		_put_text(ctx, "foundry:" + text)
