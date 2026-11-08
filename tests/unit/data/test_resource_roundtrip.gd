class_name TestResourceRoundtrip
extends GdUnitTestSuite
## Regression guard (M1-26): the Android export converted text .tres to binary and silently dropped every
## script var that was not `@export`, so all sim data loaded as 0. This saves each generated resource as
## binary .res (what the exporter stores), reloads it and requires every script variable to survive.

const GEN_DIR: String = "res://src/data_gen"
const SCRATCH: String = "user://roundtrip_test"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))


func after_test() -> void:
	var dir: DirAccess = DirAccess.open(SCRATCH)
	if dir == null:
		return
	for f: String in dir.get_files():
		if dir.remove(f) != OK:
			push_warning("roundtrip scratch cleanup failed: " + f)


func _generated_files() -> PackedStringArray:
	var out := PackedStringArray()
	for f: String in DirAccess.get_files_at(GEN_DIR):
		if f.ends_with(".tres"):
			if out.append(f):  # PackedStringArray.append returns true on failure
				push_error("append failed")
	return out


## Script variables of `res` as name -> value (stored or not).
func _script_vars(res: Resource) -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in res.get_property_list():
		var usage: int = p["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var prop_name: String = p["name"]
			out[prop_name] = res.get(prop_name)
	return out


## Returns "" when equal, else a description of the first mismatch.
func _diff(a: Resource, b: Resource, path: String) -> String:
	var va: Dictionary = _script_vars(a)
	var vb: Dictionary = _script_vars(b)
	for key: String in va:
		var x: Variant = va[key]
		var y: Variant = vb.get(key)
		if x is Array:
			var xa: Array = x
			var ya: Array = y
			if xa.size() != ya.size():
				return "%s.%s size %d != %d" % [path, key, xa.size(), ya.size()]
			for i: int in xa.size():
				var xr: Variant = xa[i]
				if xr is Resource:
					var xres: Resource = xr
					var yr: Resource = ya[i]
					var d: String = _diff(xres, yr, "%s.%s[%d]" % [path, key, i])
					if not d.is_empty():
						return d
				elif xa[i] != ya[i]:
					return "%s.%s[%d] %s != %s" % [path, key, i, str(xa[i]), str(ya[i])]
		elif x != y:
			return "%s.%s: %s != %s" % [path, key, str(x), str(y)]
	return ""


func test_every_generated_resource_survives_binary_roundtrip() -> void:
	var files: PackedStringArray = _generated_files()
	assert_int(files.size()).is_greater(15)
	var compared: int = 0
	for f: String in files:
		var original: Resource = load(GEN_DIR.path_join(f))
		var out_path: String = SCRATCH.path_join(f.get_basename() + ".res")
		assert_int(ResourceSaver.save(original, out_path)).is_equal(OK)
		var reloaded: Resource = ResourceLoader.load(out_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		assert_object(reloaded).is_not_null()
		var mismatch: String = _diff(original, reloaded, f)
		assert_str(mismatch).is_empty()
		compared += _script_vars(original).size()
	assert_int(compared).is_greater(150)


func test_sim_tuning_has_real_values_after_roundtrip() -> void:
	# Guards against the comparison passing trivially (both sides zero).
	var original: SimTuning = load(GEN_DIR.path_join("sim_tuning.tres"))
	var out_path: String = SCRATCH.path_join("tuning.res")
	assert_int(ResourceSaver.save(original, out_path)).is_equal(OK)
	var reloaded: SimTuning = ResourceLoader.load(out_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_int(reloaded.tick_rate).is_equal(30)
	assert_float(reloaded.hp0).is_greater(0.0)
	assert_float(reloaded.arena_radius).is_greater(0.0)
