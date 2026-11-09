class_name UtUi
extends RefCounted
## Mockup UI of the style frame (debug only): the tier-up banner, the bottom panel with three upgrade rows (mark chip,
## `next look at L..`, progress bar) and the small text helpers the sheet captions use. Plain Controls, no theme.

const PANEL_SIZE: Vector2i = Vector2i(1080, 1440)
const OXANIUM: String = "res://assets/fonts/Oxanium-Variable.ttf"
const MONO: String = "res://assets/fonts/ShareTechMono-Regular.ttf"


func make_font(path: String, spacing: int = 0) -> Font:
	var base: Font = load(path) as Font
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = spacing
	return fv


func label(text: String, size: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func rect(pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = col
	return r


func overlay(vp: SubViewport, view: BattleView) -> void:
	var ox: Font = make_font(OXANIUM, 5)
	var mono: Font = make_font(MONO, 1)
	var root := Control.new()
	root.size = Vector2(PANEL_SIZE)
	vp.add_child(root)
	# tier-up banner
	var bw: float = 560.0
	var bx: float = (1080.0 - bw) * 0.5
	var by: float = 70.0
	root.add_child(rect(Vector2(bx, by), Vector2(bw, 96), Color(0.05, 0.065, 0.09, 0.9)))
	root.add_child(rect(Vector2(bx, by), Vector2(bw, 3), Palette.AMBER))
	root.add_child(rect(Vector2(bx, by + 93), Vector2(bw, 3), Palette.AMBER_DIM))
	root.add_child(rect(Vector2(bx - 10, by - 6), Vector2(8, 108), Palette.AMBER))
	root.add_child(rect(Vector2(bx + bw + 2, by - 6), Vector2(8, 108), Palette.AMBER))
	var t1: Label = label("LASER MK II", 54, Palette.AMBER_GLOW, ox)
	t1.position = Vector2(bx, by + 8)
	t1.size = Vector2(bw, 60)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(t1)
	var t2: Label = label("BEAM OUTPUT TIER UP", 20, Palette.TEAL, mono)
	t2.position = Vector2(bx, by + 64)
	t2.size = Vector2(bw, 26)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(t2)
	# bottom panel with three upgrade rows
	var py: float = view.field_rect().end.y
	root.add_child(rect(Vector2(0, py), Vector2(1080, 1440.0 - py), Palette.PANEL))
	root.add_child(rect(Vector2(0, py), Vector2(1080, 3), Palette.AMBER_DIM))
	var rows: Array[Dictionary] = [
		{
			"n": "LASER OUTPUT",
			"lv": 5,
			"mk": "MK II",
			"next": "next look at L12",
			"p": 5.0 / 12.0,
			"hot": true,
			"cost": "58"
		},
		{
			"n": "HULL INTEGRITY",
			"lv": 3,
			"mk": "MK I",
			"next": "next look at L5",
			"p": 3.0 / 5.0,
			"hot": false,
			"cost": "41"
		},
		{
			"n": "NANO REPAIR",
			"lv": 7,
			"mk": "MK II",
			"next": "next look at L12",
			"p": 7.0 / 12.0,
			"hot": false,
			"cost": "77"
		},
	]
	for i: int in rows.size():
		_row(root, rows[i], Vector2(24, py + 24 + 190.0 * i), ox, mono)


func _row(root: Control, d: Dictionary, at: Vector2, ox: Font, mono: Font) -> void:
	var hot: bool = d["hot"]
	var lv_value: int = d["lv"]
	var prog_value: float = d["p"]
	var edge: Color = Palette.AMBER_GLOW if hot else Palette.AMBER_DIM
	root.add_child(rect(at, Vector2(1032, 170), Color(0.075, 0.095, 0.13, 1.0)))
	root.add_child(rect(at, Vector2(1032, 2), edge))
	root.add_child(rect(at + Vector2(0, 168), Vector2(1032, 2), edge))
	root.add_child(rect(at, Vector2(2, 170), edge))
	root.add_child(rect(at + Vector2(1030, 0), Vector2(2, 170), edge))
	if hot:
		root.add_child(rect(at - Vector2(4, 4), Vector2(1040, 3), Color(Palette.AMBER, 0.55)))
		root.add_child(rect(at + Vector2(-4, 171), Vector2(1040, 3), Color(Palette.AMBER, 0.55)))
	root.add_child(rect(at + Vector2(18, 24), Vector2(120, 120), Palette.PLATE_SHADOW))
	root.add_child(rect(at + Vector2(18, 24), Vector2(120, 3), edge))
	_icon(root, at + Vector2(78, 84), str(d["n"]))
	var nm: Label = label(str(d["n"]), 38, Palette.TEXT, ox)
	nm.position = at + Vector2(160, 14)
	root.add_child(nm)
	var chip: Color = Palette.AMBER if hot else Palette.AMBER_DIM
	root.add_child(rect(at + Vector2(160, 64), Vector2(112, 40), chip))
	var mk: Label = label(str(d["mk"]), 28, Palette.VOID, ox)
	mk.position = at + Vector2(176, 66)
	root.add_child(mk)
	var lv: Label = label("L%d" % lv_value, 30, Palette.TEXT_DIM, mono)
	lv.position = at + Vector2(300, 68)
	root.add_child(lv)
	var nx: Label = label(str(d["next"]), 24, Palette.TEAL if hot else Palette.TEXT_DIM, mono)
	nx.position = at + Vector2(160, 112)
	root.add_child(nx)
	var bar_w: float = 330.0
	root.add_child(rect(at + Vector2(430, 120), Vector2(bar_w, 10), Palette.GRID))
	root.add_child(rect(at + Vector2(430, 120), Vector2(bar_w * prog_value, 10), Palette.AMBER))
	root.add_child(rect(at + Vector2(800, 30), Vector2(212, 110), Palette.PLATE_SHADOW))
	root.add_child(rect(at + Vector2(800, 30), Vector2(212, 3), Palette.AMBER))
	var buy: Label = label("BUY  %s" % str(d["cost"]), 32, Palette.AMBER_GLOW, ox)
	buy.position = at + Vector2(824, 64)
	root.add_child(buy)


## Simple glyph per row (laser = beam and lens, hull = hex plate, nano = cross), amber on the icon plate.
func _icon(root: Control, c: Vector2, row_name: String) -> void:
	var col: Color = Palette.AMBER
	if row_name.begins_with("LASER"):
		var ln := Line2D.new()
		ln.points = PackedVector2Array([c + Vector2(-38, 30), c + Vector2(30, -30)])
		ln.width = 9.0
		ln.default_color = col
		root.add_child(ln)
		var dot := Polygon2D.new()
		dot.polygon = _ngon(c + Vector2(-38, 30), 14.0, 8)
		dot.color = Palette.AMBER_GLOW
		root.add_child(dot)
	elif row_name.begins_with("HULL"):
		var hx := Polygon2D.new()
		hx.polygon = _ngon(c, 42.0, 6)
		hx.color = Palette.FRAME_BASE
		root.add_child(hx)
		var hi := Polygon2D.new()
		hi.polygon = _ngon(c, 26.0, 6)
		hi.color = col
		root.add_child(hi)
	else:
		for k: int in 2:
			var ln2 := Line2D.new()
			var a: Vector2 = Vector2(0, 40) if k == 0 else Vector2(40, 0)
			ln2.points = PackedVector2Array([c - a, c + a])
			ln2.width = 14.0
			ln2.default_color = Palette.TEAL
			root.add_child(ln2)


func _ngon(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in n:
		pts.append(c + Vector2.from_angle(TAU * float(i) / float(n) + PI / float(n)) * r)
	return pts
