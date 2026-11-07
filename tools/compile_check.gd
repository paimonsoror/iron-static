extends SceneTree
## Compile gate used by tools/lint.ps1: loads every script passed after `--` so that parse errors
## and warnings-as-errors are reported (autoloads are registered in this mode, unlike --check-only).
## Usage: godot --headless --path . -s res://tools/compile_check.gd -- res://a.gd res://b.gd


func _initialize() -> void:
	# Autoloads are added to the tree after _init, so compile on the first frame.
	process_frame.connect(_compile_all, CONNECT_ONE_SHOT)


func _compile_all() -> void:
	var failed: int = 0
	var checked: int = 0
	for path: String in OS.get_cmdline_user_args():
		checked += 1
		var script: Resource = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
		if script == null:
			failed += 1
			print("COMPILE FAIL: ", path)
	print("COMPILE SUMMARY: checked=", checked, " failed=", failed)
	quit(1 if failed > 0 else 0)
