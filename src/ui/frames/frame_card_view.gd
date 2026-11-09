class_name FrameCardView
extends PanelContainer
## One frame card of the bay (M3-29): portrait (hero silhouette, or the locked outline), name, role, SELECTED tag or
## lock text with progress, passive, six comparison bars and the Power Rating. `bind` rebinds it to any card, so the
## carousel owns a single instance. Touch passes through (the bay handles the swipe).

const SIL_DIR: String = "res://assets/art/title/src/"
const PORTRAIT_SIZE := Vector2(260.0, 366.0)
const LABEL_PX: int = 40
const ROW_LABEL_W: float = 250.0
const ROW_VALUE_W: float = 150.0

static var _tex: Dictionary = {}

var _sil: TextureRect
var _glow: TextureRect
var _name: Label
var _role: Label
var _tag: Label
var _lock: Label
var _progress: Label
var _passive: Label
var _passive_desc: Label
var _pr: Label
var _bars: Dictionary = {}
var _values: Dictionary = {}
var _shown_id: String = ""


func _init() -> void:
	theme_type_variation = ThemeBuilder.VAR_PANEL_PLATE
	mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.add_child(_build_top())
	_passive = MenuScreen.label("", &"LabelHeading", Palette.AMBER_GLOW, 46)
	box.add_child(_passive)
	_passive_desc = MenuScreen.label("", &"LabelDim", Palette.TEXT_DIM, LABEL_PX)
	box.add_child(_passive_desc)
	for key: String in FrameCard.STAT_KEYS:
		box.add_child(_build_row(key))
	_pr = _short(MenuScreen.label("", &"LabelNumber", Palette.TEXT, 48))
	box.add_child(_pr)


func _build_top() -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 28)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := Control.new()
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sil = _portrait_rect()
	_glow = _portrait_rect()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	portrait.add_child(_sil)
	portrait.add_child(_glow)
	top.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 10)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = _short(MenuScreen.label("", &"LabelHeading", Palette.AMBER, 72))
	_role = _short(MenuScreen.label("", &"LabelDim", Palette.TEXT_DIM, 44))
	_tag = _short(MenuScreen.label("frame.selected", &"LabelHeading", Palette.TEAL, 44))
	_lock = _short(MenuScreen.label("", &"LabelHeading", Palette.AMBER_DIM, 50))
	_progress = _short(MenuScreen.label("", &"LabelNumber", Palette.TEXT_DIM, 44))
	for l: Label in [_name, _role, _tag, _lock, _progress]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.add_child(l)
	top.add_child(info)
	return top


func _portrait_rect() -> TextureRect:
	var t := TextureRect.new()
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _build_row(key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := _short(MenuScreen.label("", &"LabelDim", Palette.TEXT, LABEL_PX))
	n.text = FrameBayModel.stat_label(key)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.custom_minimum_size = Vector2(ROW_LABEL_W, 0.0)
	row.add_child(n)
	var bar := FrameDeltaBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var v := _short(MenuScreen.label("", &"LabelNumber", Palette.TEXT, LABEL_PX + 2))
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.custom_minimum_size = Vector2(ROW_VALUE_W, 0.0)
	row.add_child(v)
	_bars[key] = bar
	_values[key] = v
	return row


## Shows `card`. Text comes from `FrameBayModel` and `Strings`; the stat rows read the card's deltas.
func bind(card: FrameCard) -> void:
	_name.text = Strings.get_text(card.name_key)
	_role.text = Strings.get_text(card.role_key)
	_tag.visible = card.selected
	var lock: String = FrameBayModel.lock_text(card)
	_lock.text = lock
	_lock.visible = card.locked
	_progress.text = FrameBayModel.progress_text(card)
	_progress.visible = card.locked
	_passive.text = Strings.get_text(card.passive_key)
	_passive_desc.text = Strings.get_text(card.passive_desc_key)
	for key: String in FrameCard.STAT_KEYS:
		var pct: float = card.delta(key)
		var bar: FrameDeltaBar = _bars[key]
		bar.pct = pct
		var v: Label = _values[key]
		v.text = FrameBayModel.delta_text(pct)
		var s: int = FrameBayModel.sign_of(pct)
		v.add_theme_color_override("font_color", _delta_color(s))
	var pr: String = FrameBayModel.pr_text(card)
	var d: String = FrameBayModel.pr_delta_text(card)
	_pr.text = pr if d.is_empty() else "%s  (%s)" % [pr, d]
	_show_portrait(card)


static func _delta_color(s: int) -> Color:
	if s > 0:
		return Palette.AMBER
	return Palette.TEXT_DIM if s < 0 else Palette.TEXT


func _show_portrait(card: FrameCard) -> void:
	_shown_id = card.id
	if card.locked:
		_sil.texture = ArtSlots.atlas("title_sil_locked_" + card.id)
		_sil.modulate = Palette.TEXT_DIM
		_glow.texture = null
		return
	_sil.modulate = Color.WHITE
	_sil.texture = _load("sil_" + card.id)
	_glow.texture = _load("sil_" + card.id + "_glow")


func shown_id() -> String:
	return _shown_id


## The portrait's current texture (a test reads it).
func portrait_texture() -> Texture2D:
	return _sil.texture


func bar_pct(key: String) -> float:
	var bar: FrameDeltaBar = _bars[key]
	return bar.pct


func value_text(key: String) -> String:
	var v: Label = _values[key]
	return v.text


func value_color(key: String) -> Color:
	var v: Label = _values[key]
	return v.get_theme_color("font_color")


func lock_label() -> Label:
	return _lock


func tag_label() -> Label:
	return _tag


func pr_label() -> Label:
	return _pr


func _load(sheet: String) -> Texture2D:
	if not _tex.has(sheet):
		var loaded: Texture2D = load(SIL_DIR + sheet + ".svg") as Texture2D
		if loaded == null:
			push_error("frame bay: missing texture " + sheet)
		_tex[sheet] = loaded
	var v: Variant = _tex[sheet]
	var t: Texture2D = v
	return t


static func _short(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l
