class_name PngRgb
extends SceneTree
## Rewrites PNG captures as 24-bit RGB PNGs (Play wants no alpha channel in screenshots; the viewport captures are
## RGBA). Run with a script (no window needed):
##   godot --headless --path . --script res://src/debug/png_rgb.gd -- --out=<dir> <in1.png> [<in2.png> ...]
## Each input is written to <dir>/<same name> at its own size (nothing is scaled).


func _init() -> void:
	var out: String = ""
	var inputs: PackedStringArray = PackedStringArray()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif not a.begins_with("--"):
			inputs.append(a)
	if out.is_empty() or inputs.is_empty():
		push_error("png_rgb: need --out=<dir> and at least one input")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var failed: int = 0
	for path: String in inputs:
		var img: Image = Image.load_from_file(path)
		if img == null or img.is_empty():
			push_error("png_rgb: cannot read " + path)
			failed += 1
			continue
		img.convert(Image.FORMAT_RGB8)
		var dest: String = out.path_join(path.get_file())
		if img.save_png(dest) != OK:
			push_error("png_rgb: cannot write " + dest)
			failed += 1
			continue
		print("[RGB] %s %dx%d" % [dest, img.get_width(), img.get_height()])
	quit(1 if failed > 0 else 0)
