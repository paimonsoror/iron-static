extends SceneTree
## Pixel check of the art sheets (V1-02). Rasterizes every sheet file of the slot table with
## `Image.load_svg_from_buffer` (the SVG importer's rasterizer, pixel-identical to the imported texture) and checks:
##   size      sheet size equals the table
##   outside   alpha outside every cell rectangle is 0 (tolerance 1/255)
##   margin    nothing but 1/255 alpha inside the `margin` texels of a cell border (rows with margin > 0)
##   coverage  every frame of a `ready` slot has >= 3% (table `min_coverage`) pixels with alpha >= 10/255 (not empty)
##   shape     enemy body cells: convex-hull solidity of the solid silhouette >= 0.55 and bbox aspect within
##             +-35% of the table `aspect`
## Usage (via tools/art_check.ps1): godot --headless -s res://tools/art_check.gd -- [--slots res://x.csv]
##   [--dir res://dir/] [--only substring] [--quiet]
## Output lines: `ART OK|WARN|FAIL <slot-or-file>: <detail>`, `ART STAT ...`, last `ART CHECK SUMMARY: ...`.

const MIN_COVERAGE: float = 0.03
const MIN_SOLIDITY: float = 0.55
const ASPECT_TOLERANCE: float = 0.35
const ALPHA_TOLERANCE: int = 1
const ALPHA_VISIBLE: int = 10
const ALPHA_SOLID: int = 128

var _fail: int = 0
var _warn: int = 0
var _frames: int = 0
var _quiet: bool = false


func _init() -> void:
	var slots_path: String = "res://assets/art/slots.csv"
	var dir: String = "res://assets/art/src/"
	var only: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		if args[i] == "--slots" and i + 1 < args.size():
			slots_path = args[i + 1]
			i += 2
		elif args[i] == "--dir" and i + 1 < args.size():
			dir = args[i + 1]
			i += 2
		elif args[i] == "--only" and i + 1 < args.size():
			only = args[i + 1]
			i += 2
		else:
			if args[i] == "--quiet":
				_quiet = true
			i += 1
	var table: CsvTable = CsvTable.load_file(slots_path)
	if not table.error.is_empty():
		print("ART CHECK ERROR: " + table.error)
		quit(2)
		return
	var by_file: Dictionary = {}
	for r: int in range(table.rows.size()):
		var file: String = table.get_value(r, "file")
		if file.is_empty() or (not only.is_empty() and not file.contains(only)):
			continue
		if not by_file.has(file):
			by_file[file] = []
		var list: Array = by_file[file]
		list.append(r)
	for file: String in by_file:
		var rows: Array = by_file[file]
		_check_sheet(table, dir, file, rows)
	print("ART CHECK SUMMARY: files=%d frames=%d fail=%d warn=%d" % [by_file.size(), _frames, _fail, _warn])
	quit(1 if _fail > 0 else 0)


func _check_sheet(table: CsvTable, dir: String, file: String, rows: Array) -> void:
	var ready_rows: int = 0
	for r: int in rows:
		if table.get_value(r, "status") == "ready":
			ready_rows += 1
	if ready_rows == 0:
		if not _quiet:
			print("ART SKIP %s: no ready slot rows (authored by a later art task)" % file)
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(dir.path_join(file))
	var img: Image = Image.new()
	if bytes.is_empty() or img.load_svg_from_buffer(bytes, 1.0) != OK:
		_report("FAIL", file, "cannot rasterize (missing or unreadable SVG)")
		return
	img.convert(Image.FORMAT_RGBA8)
	var first: int = rows[0]
	var want: Vector2i = Vector2i(
		table.get_value(first, "sheet_w").to_int(), table.get_value(first, "sheet_h").to_int()
	)
	if img.get_size() != want:
		_report("FAIL", file, "size %dx%d != table %dx%d" % [img.get_width(), img.get_height(), want.x, want.y])
		return
	_check_outside(table, img, file, rows)
	for r: int in rows:
		if table.get_value(r, "status") == "ready":
			_check_slot(table, img, r)
	if not _quiet:
		print("ART OK %s: size %dx%d, %d slot row(s)" % [file, want.x, want.y, rows.size()])


func _cell_rects(table: CsvTable, r: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var w: int = table.get_value(r, "cell_w").to_int()
	var h: int = table.get_value(r, "cell_h").to_int()
	var x0: int = table.get_value(r, "cell_x").to_int()
	var y0: int = table.get_value(r, "cell_y").to_int()
	for f: int in range(maxi(table.get_value(r, "frames").to_int(), 1)):
		out.append(Rect2i(x0 + f * w, y0, w, h))
	return out


func _check_outside(table: CsvTable, img: Image, file: String, rows: Array) -> void:
	var work: Image = img.duplicate()
	for r: int in rows:
		for rect: Rect2i in _cell_rects(table, r):
			work.fill_rect(rect, Color(0, 0, 0, 0))
	var used: Rect2i = work.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var data: PackedByteArray = work.get_data()
	var width: int = work.get_width()
	var bad: int = 0
	var first_at: Vector2i = Vector2i(-1, -1)
	for y: int in range(used.position.y, used.end.y):
		var base: int = y * width * 4
		for x: int in range(used.position.x, used.end.x):
			if data[base + x * 4 + 3] > ALPHA_TOLERANCE:
				bad += 1
				if bad == 1:
					first_at = Vector2i(x, y)
	if bad > 0:
		_report("FAIL", file, "alpha outside cells: %d px, first at %d,%d" % [bad, first_at.x, first_at.y])


func _check_slot(table: CsvTable, img: Image, r: int) -> void:
	var sid: String = table.get_value(r, "slot")
	var margin: int = table.get_value(r, "margin").to_int()
	var mc_text: String = table.get_value(r, "min_coverage")
	var min_cov: float = (mc_text.to_float() if not mc_text.is_empty() else MIN_COVERAGE * 100.0) / 100.0
	var aspect: float = table.get_value(r, "aspect").to_float()
	var solid_guard: bool = aspect > 0.0 and table.get_value(r, "blend") != "add"
	var fi: int = 0
	var worst_solidity: float = 9.0
	var worst_aspect_err: float = 0.0
	for rect: Rect2i in _cell_rects(table, r):
		_frames += 1
		var cell: Image = img.get_region(rect)
		var data: PackedByteArray = cell.get_data()
		var w: int = rect.size.x
		var h: int = rect.size.y
		var visible: int = 0
		var ring_bad: int = 0
		var ring_max: int = 0
		var ring_at: Vector2i = Vector2i.ZERO
		var solid: int = 0
		var minx: int = w
		var maxx: int = -1
		var miny: int = h
		var maxy: int = -1
		var col_min: PackedInt32Array = PackedInt32Array()
		var col_max: PackedInt32Array = PackedInt32Array()
		col_min.resize(w)
		col_max.resize(w)
		col_min.fill(h)
		col_max.fill(-1)
		for y: int in range(h):
			var base: int = y * w * 4
			var in_y: bool = y >= margin and y < h - margin
			for x: int in range(w):
				var a: int = data[base + x * 4 + 3]
				if a >= ALPHA_VISIBLE:
					visible += 1
				if margin > 0 and a > ALPHA_TOLERANCE and not (in_y and x >= margin and x < w - margin):
					ring_bad += 1
					if a > ring_max:
						ring_max = a
						ring_at = Vector2i(x, y)
				if solid_guard and a >= ALPHA_SOLID:
					solid += 1
					minx = mini(minx, x)
					maxx = maxi(maxx, x)
					miny = mini(miny, y)
					maxy = maxi(maxy, y)
					col_min[x] = mini(col_min[x], y)
					col_max[x] = maxi(col_max[x], y)
		var cov: float = float(visible) / float(w * h)
		if cov < min_cov:
			_report("FAIL", sid, "frame %d coverage %.1f%% < %.1f%% (empty cell?)" % [fi, cov * 100.0, min_cov * 100.0])
		if ring_bad > 0:
			_report(
				"FAIL",
				sid,
				(
					"frame %d: %d px of alpha inside the %d texel margin (max alpha %d/255 at cell px %d,%d)"
					% [fi, ring_bad, margin, ring_max, ring_at.x, ring_at.y]
				)
			)
		if solid_guard:
			if solid == 0:
				_report("FAIL", sid, "frame %d: no solid pixels for the silhouette guard" % fi)
			else:
				var hull: float = _hull_area(col_min, col_max)
				var solidity: float = float(solid) / maxf(hull, 1.0)
				var asp: float = float(maxx - minx + 1) / float(maxy - miny + 1)
				worst_solidity = minf(worst_solidity, solidity)
				worst_aspect_err = maxf(worst_aspect_err, absf(asp / aspect - 1.0))
				if solidity < MIN_SOLIDITY:
					_report("FAIL", sid, "frame %d solidity %.2f < %.2f" % [fi, solidity, MIN_SOLIDITY])
				if absf(asp / aspect - 1.0) > ASPECT_TOLERANCE:
					_report("FAIL", sid, "frame %d aspect %.2f vs table %.2f (> 35%%)" % [fi, asp, aspect])
		fi += 1
	if solid_guard and worst_solidity < 9.0 and not _quiet:
		print(
			(
				"ART STAT %s: worst solidity %.2f, worst aspect error %.0f%%"
				% [sid, worst_solidity, worst_aspect_err * 100.0]
			)
		)


## Area of the convex hull of the pixel columns (column extremes, pixel corners), monotone chain.
func _hull_area(col_min: PackedInt32Array, col_max: PackedInt32Array) -> float:
	var pts: Array[Vector2] = []
	for x: int in range(col_min.size()):
		if col_max[x] < 0:
			continue
		pts.append(Vector2(x, col_min[x]))
		pts.append(Vector2(x + 1, col_min[x]))
		pts.append(Vector2(x, col_max[x] + 1))
		pts.append(Vector2(x + 1, col_max[x] + 1))
	if pts.size() < 3:
		return 0.0
	var hull: PackedVector2Array = Geometry2D.convex_hull(PackedVector2Array(pts))
	var area: float = 0.0
	for k: int in range(hull.size()):
		var p: Vector2 = hull[k]
		var q: Vector2 = hull[(k + 1) % hull.size()]
		area += p.x * q.y - q.x * p.y
	return absf(area) * 0.5


func _report(kind: String, who: String, detail: String) -> void:
	if kind == "FAIL":
		_fail += 1
	elif kind == "WARN":
		_warn += 1
	print("ART %s %s: %s" % [kind, who, detail])
