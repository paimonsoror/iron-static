class_name ImgTool
extends SceneTree
## Image tool for the README and codex pictures: crops, downscales and tiles PNG captures into small JPEGs
## (no PIL on the dev machine; this is the same Godot `Image` code the capture harnesses use). Run with a script
## (the console exe; it needs no window):
##   godot --headless --path . --script res://src/debug/img_tool.gd -- --out=<file.jpg> --width=<px> [--quality=0.82]
##     [--crop=x,y,w,h] [--cols=<n>] [--gap=<px>] <in1.png> [<in2.png> ...]
## Every input is cropped by --crop (source pixels; default: the whole image), scaled to the cell width with
## Lanczos (never stretched: the height follows the crop's aspect ratio) and the cells are tiled `--cols` wide
## (default: all in one row) with `--gap` px of the page color between them. --width is the width of the whole output.

const PAGE: Color = Color(0.027, 0.035, 0.047)  # Palette.VOID


func _init() -> void:
	var out: String = ""
	var width: int = 540
	var quality: float = 0.82
	var crop: Array[int] = []
	var cols: int = 0
	var gap: int = 0
	var inputs: PackedStringArray = PackedStringArray()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--width="):
			width = a.get_slice("=", 1).to_int()
		elif a.begins_with("--quality="):
			quality = a.get_slice("=", 1).to_float()
		elif a.begins_with("--crop="):
			for part: String in a.get_slice("=", 1).split(","):
				crop.append(part.to_int())
		elif a.begins_with("--cols="):
			cols = a.get_slice("=", 1).to_int()
		elif a.begins_with("--gap="):
			gap = a.get_slice("=", 1).to_int()
		elif not a.begins_with("--"):
			inputs.append(a)
	if out.is_empty() or inputs.is_empty() or width <= 0:
		push_error("img_tool: need --out, --width and at least one input")
		quit(2)
		return
	quit(_run(out, width, quality, crop, maxi(cols, 0), gap, inputs))


func _run(
	out: String, width: int, quality: float, crop: Array[int], cols: int, gap: int, inputs: PackedStringArray
) -> int:
	var count: int = inputs.size()
	var per_row: int = count if cols <= 0 else mini(cols, count)
	var rows: int = ceili(float(count) / float(per_row))
	var cell_w: int = floori(float(width - gap * (per_row - 1)) / float(per_row))
	var cells: Array[Image] = []
	for path: String in inputs:
		var img: Image = Image.load_from_file(path)
		if img == null or img.is_empty():
			push_error("img_tool: cannot read " + path)
			return 1
		if crop.size() == 4:
			img = img.get_region(Rect2i(crop[0], crop[1], crop[2], crop[3]))
		var h: int = roundi(float(img.get_height()) * float(cell_w) / float(img.get_width()))
		img.resize(cell_w, h, Image.INTERPOLATE_LANCZOS)
		cells.append(img)
	var cell_h: int = cells[0].get_height()
	var total_h: int = cell_h * rows + gap * (rows - 1)
	var sheet: Image = Image.create(width, total_h, false, Image.FORMAT_RGBA8)
	sheet.fill(PAGE)
	for i: int in count:
		var x: int = (i % per_row) * (cell_w + gap)
		var y: int = floori(float(i) / float(per_row)) * (cell_h + gap)
		sheet.blit_rect(cells[i], Rect2i(0, 0, cell_w, cells[i].get_height()), Vector2i(x, y))
	sheet.convert(Image.FORMAT_RGB8)
	if sheet.save_jpg(out, quality) != OK:
		push_error("img_tool: cannot write " + out)
		return 1
	print("[IMG] %s %dx%d" % [out, sheet.get_width(), sheet.get_height()])
	return 0
