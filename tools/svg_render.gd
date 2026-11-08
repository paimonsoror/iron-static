extends SceneTree
## Rasterize SVG files with Godot's built-in ThorVG (the same rasterizer the SVG importer uses)
## and save PNGs, optionally composited on a background color, so agents can look at their art.
##
## Usage (via tools/svg_render.ps1):
##   godot --headless --path . -s res://tools/svg_render.gd -- --out build/svg --scale 1.0 \
##       [--bg #07090C] file1.svg [file2.svg ...]
## Prints "SVG OK <in> -> <out> <w>x<h>" per file, "SVG FAIL <in>: <reason>" on errors and
## "SVG RENDER DONE ok=<n> fail=<n>" last.


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = "res://build/svg"
	var scale_value: float = 1.0
	var bg_text: String = ""
	var inputs: PackedStringArray = PackedStringArray()
	var i: int = 0
	while i < args.size():
		var a: String = args[i]
		if a == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
			i += 2
		elif a == "--scale" and i + 1 < args.size():
			scale_value = args[i + 1].to_float()
			i += 2
		elif a == "--bg" and i + 1 < args.size():
			bg_text = args[i + 1]
			i += 2
		else:
			inputs.append_array(PackedStringArray([a]))
			i += 1
	var ok_count: int = 0
	var fail_count: int = 0
	var abs_out: String = ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(abs_out)
	for path: String in inputs:
		if _render_one(path, abs_out, scale_value, bg_text):
			ok_count += 1
		else:
			fail_count += 1
	print("SVG RENDER DONE ok=%d fail=%d" % [ok_count, fail_count])
	quit(1 if fail_count > 0 else 0)


func _render_one(path: String, abs_out: String, scale_value: float, bg_text: String) -> bool:
	var abs_in: String = ProjectSettings.globalize_path(path)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(abs_in)
	if bytes.is_empty():
		print("SVG FAIL %s: cannot read file" % path)
		return false
	var img: Image = Image.new()
	var err: Error = img.load_svg_from_buffer(bytes, scale_value)
	if err != OK:
		print("SVG FAIL %s: load_svg_from_buffer error %d" % [path, err])
		return false
	if bg_text != "":
		var bg: Image = Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		bg.fill(Color(bg_text))
		img.convert(Image.FORMAT_RGBA8)
		bg.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
		img = bg
	var out_path: String = abs_out.path_join(abs_in.get_file().get_basename() + ".png")
	var save_err: Error = img.save_png(out_path)
	if save_err != OK:
		print("SVG FAIL %s: save_png error %d" % [path, save_err])
		return false
	print("SVG OK %s -> %s %dx%d" % [path, out_path, img.get_width(), img.get_height()])
	return true
