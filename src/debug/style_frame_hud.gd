class_name StyleFrameHud
extends Control
## Styled HUD / panel mock for the style frame (not wired to the game): top plate, integrity bar, counter plates,
## bottom panel with tabs, buy row and two upgrade rows. 1080 x 2400 layout, built from ui_kit 9-slices.
## Cells (x, y, w, h) and margins come from the ui_kit.svg header comment.

const PANEL: Rect2 = Rect2(0, 0, 96, 96)
const PANEL_ACTIVE: Rect2 = Rect2(104, 0, 96, 96)
const INSET: Rect2 = Rect2(208, 0, 96, 96)
const BUTTON: Rect2 = Rect2(0, 104, 96, 96)
const BUTTON_AFFORD: Rect2 = Rect2(312, 104, 96, 96)
const BUTTON_OFF: Rect2 = Rect2(208, 104, 96, 96)
const TAB: Rect2 = Rect2(0, 208, 96, 96)
const TAB_ACTIVE: Rect2 = Rect2(104, 208, 96, 96)
const BAR_FRAME: Rect2 = Rect2(208, 208, 96, 40)
const BRACKET: Rect2 = Rect2(0, 312, 48, 48)

var _kit: Texture2D = null


func _ready() -> void:
	_kit = StyleFrameArt.tex("ui_kit")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_bottom()


func _plate(rect: Rect2, cell: Rect2, margin: int) -> void:
	var n := NinePatchRect.new()
	n.texture = _kit
	n.region_rect = cell
	n.patch_margin_left = margin
	n.patch_margin_right = margin
	n.patch_margin_top = margin
	n.patch_margin_bottom = margin
	n.position = rect.position
	n.size = rect.size
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(n)


func _label(
	text: String, pos: Vector2, font: Font, fsize: int, color: Color, width: float = 0.0, align: int = 0
) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.position = pos
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
		l.size = Vector2(width, fsize + 12)
		l.horizontal_alignment = align as HorizontalAlignment
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)


func _icon(slot: String, pos: Vector2, px: float, tint: Color = Color.WHITE) -> void:
	var t := TextureRect.new()
	t.texture = load("res://assets/art/src/icons/" + slot + ".svg") as Texture2D
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = pos
	t.size = Vector2(px, px)
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)


func _brackets(r: Rect2) -> void:
	for k: int in 4:
		var t := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = _kit
		at.region = BRACKET
		t.texture = at
		t.size = Vector2(48, 48)
		t.flip_h = k % 2 == 1
		t.flip_v = k >= 2
		var x: float = r.position.x - 2.0 if k % 2 == 0 else r.end.x - 46.0
		var y: float = r.position.y - 2.0 if k < 2 else r.end.y - 46.0
		t.position = Vector2(x, y)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(t)


func _bar(rect: Rect2, segs: int, lit: int, colors: PackedColorArray, ticks: bool) -> void:
	_plate(rect, BAR_FRAME, 16)
	var b := StyleFrameBar.new()
	b.position = rect.position
	b.size = rect.size
	b.segments = segs
	b.lit = lit
	b.colors = colors
	b.ticks = ticks
	b.head_bright = ticks
	add_child(b)


func _build_top() -> void:
	var body: Font = StyleFrameArt.font_body()
	var head: Font = StyleFrameArt.font_heading()
	var num: Font = StyleFrameArt.font_number()
	_plate(Rect2(14, 10, 1052, 180), PANEL, 28)
	_brackets(Rect2(14, 10, 1052, 180))
	_label("WAVE", Vector2(46, 26), body, 36, Palette.TEXT_DIM)
	_label("37", Vector2(46, 56), head, 92, Palette.AMBER)
	_bar(Rect2(270, 56, 450, 44), 24, 15, PackedColorArray([Palette.AMBER]), true)
	_label("14s", Vector2(272, 112), num, 40, Palette.TEXT)
	_label("BOSS 3w", Vector2(480, 112), body, 36, Palette.TEXT_DIM, 240.0, 2)
	_plate(Rect2(748, 26, 146, 148), BUTTON, 28)
	_label("2x", Vector2(748, 66), head, 64, Palette.AMBER_GLOW, 146.0, 1)
	_plate(Rect2(902, 26, 148, 148), BUTTON, 28)
	for k: int in 2:
		var bar := ColorRect.new()
		bar.color = Palette.AMBER
		bar.position = Vector2(950 + 28 * k, 78)
		bar.size = Vector2(16, 48)
		add_child(bar)
	var teal: PackedColorArray = PackedColorArray([Palette.TEAL])
	_bar(Rect2(16, 200, 1048, 56), 20, 14, teal, false)
	_label("70/100", Vector2(740, 204), num, 44, Palette.TEXT, 280.0, 2)
	_counter(Rect2(16, 268, 504, 92), "cur_scrap", "SCRAP", "12.4K", Palette.SCRAP)
	_counter(Rect2(560, 268, 504, 92), "cur_data", "DATA", "3.2K", Palette.DATA)


func _counter(r: Rect2, icon: String, name_text: String, value: String, color: Color) -> void:
	_plate(r, PANEL, 28)
	_icon(icon, r.position + Vector2(18, 14), 64.0)
	_label(name_text, r.position + Vector2(100, 22), StyleFrameArt.font_body(), 38, color)
	_label(value, r.position + Vector2(190, 18), StyleFrameArt.font_number(), 52, Palette.TEXT, 300.0, 2)


func _build_bottom() -> void:
	var body: Font = StyleFrameArt.font_body()
	var head: Font = StyleFrameArt.font_heading()
	var num: Font = StyleFrameArt.font_number()
	_plate(Rect2(4, 1334, 1072, 1062), PANEL, 28)
	_brackets(Rect2(4, 1334, 1072, 1062))
	var tabs: PackedStringArray = PackedStringArray(["ARMS", "CHASSIS", "SYSTEMS", "INTEL"])
	for k: int in 4:
		var r := Rect2(24 + 258 * k, 1356, 250, 148)
		_plate(r, TAB_ACTIVE if k == 0 else TAB, 28)
		_label(
			tabs[k], Vector2(r.position.x, 1402), head, 46, Palette.AMBER_GLOW if k == 0 else Palette.AMBER, 250.0, 1
		)
	_label("BUY", Vector2(28, 1562), body, 38, Palette.TEXT_DIM)
	var chips: PackedStringArray = PackedStringArray(["x1", "x10", "x100", "MAX"])
	for k: int in 4:
		var r2 := Rect2(120 + 238 * k, 1516, 230, 148)
		_plate(r2, BUTTON_AFFORD if k == 0 else BUTTON, 28)
		_label(chips[k], Vector2(r2.position.x, 1556), num, 56, Palette.AMBER, 230.0, 1)
	_row(Rect2(24, 1676, 1032, 230), "laser_output", "LASER OUTPUT", "L24", "11 > 12", "1.2K", true)
	_row(Rect2(24, 1918, 1032, 230), "cycle_rate", "CYCLE RATE", "L11", "1.44 > 1.48", "9.8K", false)
	_label("NEXT UNLOCK AT WAVE 3", Vector2(4, 2166), body, 40, Palette.TEXT_DIM, 1072.0, 1)


func _row(r: Rect2, icon: String, title: String, level: String, value: String, cost: String, afford: bool) -> void:
	_plate(r, INSET, 24)
	_plate(Rect2(r.position.x + 20, r.position.y + 62, 108, 108), PANEL, 28)
	_icon(icon, r.position + Vector2(24, 66), 100.0)
	_label(title, r.position + Vector2(152, 28), StyleFrameArt.font_heading(), 42, Palette.TEXT)
	_plate(Rect2(r.position.x + 536, r.position.y + 20, 100, 52), PANEL, 20)
	_label(level, r.position + Vector2(536, 26), StyleFrameArt.font_number(), 38, Palette.TEXT_DIM, 100.0, 1)
	_label(value, r.position + Vector2(152, 92), StyleFrameArt.font_number(), 56, Palette.TEXT)
	var br := Rect2(r.position.x + 666, r.position.y + 42, 340, 148)
	_plate(br, BUTTON_AFFORD if afford else BUTTON_OFF, 28)
	_icon("cur_scrap", br.position + Vector2(30, 40), 64.0, Color.WHITE if afford else Color(1, 1, 1, 0.45))
	var col: Color = Palette.TEXT if afford else Palette.UNAFFORDABLE
	_label(cost, br.position + Vector2(100, 36), StyleFrameArt.font_number(), 56, col, 210.0, 2)
