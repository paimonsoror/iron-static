class_name ResultsBody
extends VBoxContainer
## The image-first body of the results screen (M4; GDD 07 section 2.10), built in code: header (mode chip, best,
## NEW BEST badge, the wave as the biggest text), the "destroyed by" card with the killer's battle sprite, four stat
## tiles (icon + number + one word), the kill strip (one sprite per enemy type killed with x{count}) and compact
## unlock badges. `ResultsOverlay` owns the animation: it reads `sections()` and calls the `set_*` methods.

const SECTION_COUNT: int = 5
const WAVE_SIZE: int = 132
const SPRITE_PX: float = 176.0
const NAME_SIZE: int = 40
const BADGE_ICON_PX: float = 56.0
const BADGE_SIZE: int = 40
const GAP: int = 14

var _header: VBoxContainer = null
var _mode_chip: PanelContainer = null
var _mode_label: Label = null
var _best: Label = null
var _new_best: PanelContainer = null
var _new_best_label: Label = null
var _wave: Label = null
var _killer_card: PanelContainer = null
var _killer_caption: Label = null
var _killer_sprite: TextureRect = null
var _killer_name: Label = null
var _tiles: GridContainer = null
var _time: ResultsTile = null
var _kills: ResultsTile = null
var _data: ResultsTile = null
var _scrap: ResultsTile = null
var _strip: ResultsKillStrip = null
var _badges: VBoxContainer = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", GAP)
	_build_header()
	_build_killer()
	_build_tiles()
	_strip = ResultsKillStrip.new()
	add_child(_strip)
	_badges = VBoxContainer.new()
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badges.add_theme_constant_override("separation", 10)
	add_child(_badges)


## The five animated sections in reveal order: header, killer card, tiles, kill strip, badges.
func sections() -> Array[Control]:
	return [_header, _killer_card, _tiles, _strip, _badges]


## Fills everything except the counting numbers (`set_wave`, `set_kills`, `set_data`, `set_scrap` do those).
func show_model(m: ResultsModel) -> void:
	_mode_chip.visible = not m.mode_chip_text.is_empty()
	_mode_label.text = m.mode_chip_text
	_best.text = m.best_short_text
	_new_best.visible = m.new_best
	_new_best_label.text = m.new_best_text
	_time.set_value(m.time_value_text)
	_data.set_extra(m.data_total_text)
	_killer_sprite.texture = ArtSlots.atlas(m.killer_id, 0) if ArtSlots.has(m.killer_id) else null
	_killer_sprite.visible = _killer_sprite.texture != null
	_killer_name.text = m.killer_name_text
	_killer_name.add_theme_color_override("font_color", ResultsAnim.accent_for(m.killer_id))
	_strip.show_entries(m.kill_entries)
	_fill_badges(m)


func set_wave(text: String) -> void:
	_wave.text = text


func set_kills(text: String) -> void:
	_kills.set_value(text)


func set_data(text: String) -> void:
	_data.set_value(text)


func set_scrap(text: String) -> void:
	_scrap.set_value(text)


func wave_label() -> Label:
	return _wave


func best_label() -> Label:
	return _best


func new_best_badge() -> Control:
	return _new_best


func mode_chip() -> Control:
	return _mode_chip


func killer_card() -> Control:
	return _killer_card


func killer_sprite() -> TextureRect:
	return _killer_sprite


func killer_name_label() -> Label:
	return _killer_name


func tiles() -> Array[ResultsTile]:
	return [_time, _kills, _data, _scrap]


func strip() -> ResultsKillStrip:
	return _strip


func badges() -> Control:
	return _badges


func _build_header() -> void:
	_header = VBoxContainer.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_theme_constant_override("separation", 0)
	add_child(_header)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	_header.add_child(top)
	_mode_chip = PanelContainer.new()
	_mode_chip.add_theme_stylebox_override("panel", UiKit.inset(22, 6))
	_mode_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_label = _label(Palette.TEAL, ThemeBuilder.FONT_SIZE_BODY + 4)
	_mode_chip.add_child(_mode_label)
	top.add_child(_mode_chip)
	_best = _label(Palette.TEXT_DIM, ThemeBuilder.FONT_SIZE_BODY)
	_best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_best)
	_new_best = PanelContainer.new()
	_new_best.add_theme_stylebox_override("panel", UiKit.plate_active(22, 6))
	_new_best.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_new_best_label = _label(Palette.AMBER_GLOW, ThemeBuilder.FONT_SIZE_BODY + 4)
	_new_best.add_child(_new_best_label)
	top.add_child(_new_best)
	_wave = Label.new()
	_wave.theme_type_variation = ThemeBuilder.VAR_LABEL_HEADING
	_wave.add_theme_font_size_override("font_size", WAVE_SIZE)
	_wave.add_theme_color_override("font_color", Palette.AMBER)
	_wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_child(_wave)
	var stripe := Panel.new()
	stripe.custom_minimum_size = Vector2(0.0, 12.0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.add_theme_stylebox_override("panel", UiKit.hazard_stripe())
	_header.add_child(stripe)


func _build_killer() -> void:
	_killer_card = PanelContainer.new()
	_killer_card.add_theme_stylebox_override("panel", UiKit.inset(24, 12))
	_killer_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_killer_card)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	_killer_card.add_child(col)
	_killer_caption = _label(Palette.TEXT_DIM, ThemeBuilder.FONT_SIZE_BODY)
	_killer_caption.text = Strings.get_text("results.killed_by")
	col.add_child(_killer_caption)
	_killer_sprite = TextureRect.new()
	_killer_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_killer_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_killer_sprite.custom_minimum_size = Vector2(0.0, SPRITE_PX)
	_killer_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_killer_sprite)
	_killer_name = _label(Palette.ACCENT_SKITTER, NAME_SIZE)
	col.add_child(_killer_name)


func _build_tiles() -> void:
	_tiles = GridContainer.new()
	_tiles.columns = 2
	_tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tiles.add_theme_constant_override("h_separation", GAP)
	_tiles.add_theme_constant_override("v_separation", GAP)
	add_child(_tiles)
	_time = _tile("icon_ic_clock", "results.stat_time", Palette.TEXT, false)
	_kills = _tile("icon_ic_kills", "results.stat_kills", Palette.TEXT, false)
	_data = _tile("icon_cur_data", "results.stat_data", Palette.DATA, true)
	_scrap = _tile("icon_cur_scrap", "results.stat_scrap", Palette.SCRAP, false)


func _tile(icon: String, key: String, color: Color, extra: bool) -> ResultsTile:
	var t := ResultsTile.new()
	_tiles.add_child(t)
	t.setup(icon, Strings.get_text(key), color, extra)
	return t


func _fill_badges(m: ResultsModel) -> void:
	for c: Node in _badges.get_children():
		_badges.remove_child(c)
		c.queue_free()
	if not m.chip_text.is_empty():
		_badges.add_child(_badge(m.chip_text, _frame_icon(m.chip_frame_id)))
	if not m.mode_unlock_text.is_empty():
		_badges.add_child(_badge(m.mode_unlock_text, ArtSlots.texture("icon_ic_check")))
	_badges.visible = _badges.get_child_count() > 0


func _frame_icon(frame_id: String) -> Texture2D:
	var slot: String = "cinder_frame" if frame_id == "vanguard" else "cinder_%s_frame" % frame_id
	if not frame_id.is_empty() and ArtSlots.has(slot):
		return ArtSlots.atlas(slot, 0)
	return ArtSlots.texture("icon_ic_check")


func _badge(text: String, icon: Texture2D) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.inset(20, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var pic := TextureRect.new()
	pic.texture = icon
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(BADGE_ICON_PX, BADGE_ICON_PX)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var label: Label = _label(Palette.TEAL, BADGE_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.text = text
	row.add_child(label)
	return panel


func _label(color: Color, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
