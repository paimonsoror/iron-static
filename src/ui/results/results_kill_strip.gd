class_name ResultsKillStrip
extends HBoxContainer
## The kill strip (M4): one chip per enemy type killed, the enemy's battle sprite with "x{count}" under it, most
## kills first; the boss chip uses the highlighted plate and amber count. Hidden when nothing was killed.

const THUMB_PX: float = 76.0
const COUNT_SIZE: int = 40
const MAX_CHIPS: int = 6

var _chips: Array[Control] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 12)
	alignment = BoxContainer.ALIGNMENT_CENTER


## Rebuilds the chips from `entries` (already sorted). At most MAX_CHIPS are shown.
func show_entries(entries: Array[KillEntry]) -> void:
	for c: Control in _chips:
		remove_child(c)
		c.queue_free()
	_chips.clear()
	visible = not entries.is_empty()
	for k: int in mini(entries.size(), MAX_CHIPS):
		var chip: Control = _chip(entries[k])
		add_child(chip)
		_chips.append(chip)


func chips() -> Array[Control]:
	return _chips


func _chip(e: KillEntry) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.plate_active(8, 8) if e.boss else UiKit.inset(8, 8))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.name = "Kill_" + e.id
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	var thumb := TextureRect.new()
	thumb.texture = ArtSlots.atlas(e.id, 0) if ArtSlots.has(e.id) else null
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.custom_minimum_size = Vector2(0.0, THUMB_PX)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(thumb)
	var count := Label.new()
	count.theme_type_variation = ThemeBuilder.VAR_LABEL_NUMBER
	count.add_theme_font_size_override("font_size", COUNT_SIZE)
	count.add_theme_color_override("font_color", Palette.AMBER_GLOW if e.boss else Palette.TEXT)
	count.text = Strings.fill1("results.kill_count", "n", NumberFormat.format(BigNum.from_int(e.count)))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.clip_text = true
	col.add_child(count)
	return panel
