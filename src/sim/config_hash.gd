class_name ConfigHash
extends RefCounted
## SHA-256 over the field values of tuning, enemies and upgrades (M2-07). Fields come from each def's
## script variables (every `@export`), sorted by name, so new fields are included automatically. Floats
## are hashed as raw 64-bit values; order of the enemy and upgrade rows matters.


static func compute(cfg: SimConfig) -> String:
	var ctx: HashingContext = HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		push_error("ConfigHash: start failed")
		return ""
	_put_resource(ctx, cfg.tuning)
	_put_text(ctx, "enemies:%d" % cfg.enemies.size())
	for e: EnemyDef in cfg.enemies:
		_put_resource(ctx, e)
	_put_text(ctx, "upgrades:%d" % cfg.upgrades.size())
	for u: RunUpgradeDef in cfg.upgrades:
		_put_resource(ctx, u)
	return ctx.finish().hex_encode()


static func _put_text(ctx: HashingContext, text: String) -> void:
	var bytes: PackedByteArray = text.to_utf8_buffer()
	if bytes.is_empty():
		return
	if ctx.update(bytes) != OK:
		push_error("ConfigHash: update failed")


static func _put_resource(ctx: HashingContext, res: Resource) -> void:
	var names: PackedStringArray = PackedStringArray()
	for p: Dictionary in res.get_property_list():
		var usage: int = p["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			var prop_name: String = p["name"]
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
