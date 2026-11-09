class_name TestVersion
extends GdUnitTestSuite
## B1-02: release/version.json is the single source; presets, project setting and Game.VERSION agree.

const VERSION_PATH: String = "res://release/version.json"
const PRESETS_PATH: String = "res://export_presets.cfg"


func _read_json() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VERSION_PATH))
	assert_bool(parsed is Dictionary).is_true()
	var result: Dictionary = parsed
	return result


func _name_of(v: Dictionary) -> String:
	var major: int = v["major"]
	var minor: int = v["minor"]
	var patch: int = v["patch"]
	var build: int = v["build"]
	var stage: String = v["stage"]
	var n: String = "%d.%d.%d" % [major, minor, patch]
	if stage == "beta":
		n += "-beta.%d" % build
	return n


func _code_of(v: Dictionary) -> int:
	var major: int = v["major"]
	var minor: int = v["minor"]
	var patch: int = v["patch"]
	var build: int = v["build"]
	return major * 1000000 + minor * 10000 + patch * 100 + build


func test_formula_gives_name_and_code() -> void:
	var v: Dictionary = {"major": 0, "minor": 5, "patch": 0, "stage": "beta", "build": 1}
	assert_str(_name_of(v)).is_equal("0.5.0-beta.1")
	assert_int(_code_of(v)).is_equal(50001)
	v["build"] = 2
	assert_int(_code_of(v)).is_equal(50002)
	v["stage"] = ""
	assert_str(_name_of(v)).is_equal("0.5.0")


func test_codes_only_increase_across_bumps() -> void:
	var prev: int = 0
	var v: Dictionary = {"major": 0, "minor": 5, "patch": 0, "stage": "beta", "build": 1}
	for build: int in range(2, 100):
		v["build"] = build
		assert_int(_code_of(v)).is_greater(prev)
		prev = _code_of(v)
	# a patch bump resets build to 1 and still exceeds build 99 of the previous patch
	v["patch"] = 1
	v["build"] = 1
	assert_int(_code_of(v)).is_greater(prev)
	assert_int(_code_of(v)).is_less(2100000000)


func test_version_json_matches_game_project_and_presets() -> void:
	var v: Dictionary = _read_json()
	var build: int = v["build"]
	assert_int(build).is_between(1, 99)
	assert_str(Game.VERSION).is_equal(_name_of(v))
	var project_version: String = ProjectSettings.get_setting("application/config/version")
	assert_str(project_version).is_equal(_name_of(v))
	var cfg: ConfigFile = ConfigFile.new()
	assert_int(cfg.parse(FileAccess.get_file_as_string(PRESETS_PATH))).is_equal(OK)
	var seen: int = 0
	for section: String in cfg.get_sections():
		if section.ends_with(".options"):
			var preset_name: String = cfg.get_value(section, "version/name")
			var preset_code: int = cfg.get_value(section, "version/code")
			assert_str(preset_name).is_equal(_name_of(v))
			assert_int(preset_code).is_equal(_code_of(v))
			seen += 1
	assert_int(seen).is_greater_equal(1)
