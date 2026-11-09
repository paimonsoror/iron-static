class_name UiKit
extends RefCounted
## Style API for the V1 HUD skin (art bible 7.1): builds `StyleBoxTexture` 9-slices from the `ui_*` rows of
## `assets/art/slots.csv` (cell rect and 9-slice margins come from the table, never from code) and icon faces.
## Everything returns a NEW stylebox (callers may tweak it); textures are cached by `ArtSlots`.
##
## Recipes for panels and results:
##   panel.add_theme_stylebox_override("panel", UiKit.plate())          # PanelContainer / Panel
##   button.add_theme_stylebox_override("normal", UiKit.button())       # + button_pressed / button_disabled ...
##   UiKit.style_icon_button(button, "icon_ic_pause")                    # icon IS the face, no extra plate
##   bar: draw_style_box(UiKit.bar_frame(), rect) + UiKit.segment_region(true)

## Menu side margin in base px (1080 reference): nothing in a menu screen or dialog is drawn closer than this to the
## left/right edge of the safe area. Matches the pause card (880 px wide on 1080 = 100 px each side). Applied by
## `MenuColumn.rect` (every `MenuScreen`: Home, Frame Bay, Foundry, Settings, Title, save problem) and `ConfirmDialog`.
const MENU_SIDE_MARGIN: float = 100.0

const SLOT_PLATE: String = "ui_panel_plate"
const SLOT_PLATE_ACTIVE: String = "ui_panel_plate_active"
const SLOT_INSET: String = "ui_panel_inset"
const SLOT_TOOLTIP: String = "ui_tooltip_plate"
const SLOT_BUTTON: String = "ui_button_plate"
const SLOT_BUTTON_PRESSED: String = "ui_button_plate_pressed"
const SLOT_BUTTON_DISABLED: String = "ui_button_plate_disabled"
const SLOT_BUTTON_AFFORDABLE: String = "ui_button_plate_affordable"
const SLOT_BUTTON_ACTIVE: String = "ui_button_plate_active"
const SLOT_TAB: String = "ui_tab_plate"
const SLOT_TAB_ACTIVE: String = "ui_tab_plate_active"
const SLOT_BAR_FRAME: String = "ui_bar_frame"
const SLOT_BAR_SEGMENT: String = "ui_bar_segment"
const SLOT_BAR_SEGMENT_OFF: String = "ui_bar_segment_off"
const SLOT_TICK_MINOR: String = "ui_bar_tick_minor"
const SLOT_TICK_MAJOR: String = "ui_bar_tick_major"
const SLOT_BRACKET: String = "ui_bracket_corner"
const SLOT_HAZARD: String = "ui_hazard_stripe"
const SLOT_LOCK: String = "ui_lock_mark"

## Icon slots carry their own chamfered plate: the icon is the button face.
const ICON_PRESSED_TINT: Color = Color(0.72, 0.72, 0.72, 1.0)

static var _lock_icon: AtlasTexture = null


## Generic 9-slice box for any `ui_*` slot. `content_h`/`content_v` < 0 keep the texture margins as content margins.
static func box(slot_id: String, content_h: float = -1.0, content_v: float = -1.0) -> StyleBoxTexture:
	var art: ArtSlot = ArtSlots.slot(slot_id)
	var sb := StyleBoxTexture.new()
	sb.texture = ArtSlots.texture(slot_id)
	if art.valid:
		sb.region_rect = art.frame_rect(0)
		sb.texture_margin_left = art.pivot.x
		sb.texture_margin_right = art.pivot.x
		sb.texture_margin_top = art.pivot.y
		sb.texture_margin_bottom = art.pivot.y
	sb.content_margin_left = content_h
	sb.content_margin_right = content_h
	sb.content_margin_top = content_v
	sb.content_margin_bottom = content_v
	return sb


static func plate(content_h: float = -1.0, content_v: float = -1.0) -> StyleBoxTexture:
	return box(SLOT_PLATE, content_h, content_v)


static func plate_active(content_h: float = -1.0, content_v: float = -1.0) -> StyleBoxTexture:
	return box(SLOT_PLATE_ACTIVE, content_h, content_v)


static func inset(content_h: float = -1.0, content_v: float = -1.0) -> StyleBoxTexture:
	return box(SLOT_INSET, content_h, content_v)


static func tooltip(content_h: float = -1.0, content_v: float = -1.0) -> StyleBoxTexture:
	return box(SLOT_TOOLTIP, content_h, content_v)


static func button(content_h: float = -1.0, content_v: float = -1.0) -> StyleBoxTexture:
	return box(SLOT_BUTTON, content_h, content_v)


static func button_pressed(content_h: float = -1.0, content_v: float = -1.0) -> StyleBoxTexture:
	return box(SLOT_BUTTON_PRESSED, content_h, content_v)


static func button_disabled(content_h: float = -1.0, content_v: float = -1.0) -> StyleBoxTexture:
	return box(SLOT_BUTTON_DISABLED, content_h, content_v)


static func button_affordable(content_h: float = -1.0, content_v: float = -1.0) -> StyleBoxTexture:
	return box(SLOT_BUTTON_AFFORDABLE, content_h, content_v)


static func button_active(content_h: float = -1.0, content_v: float = -1.0) -> StyleBoxTexture:
	return box(SLOT_BUTTON_ACTIVE, content_h, content_v)


static func tab(content_h: float = -1.0, content_v: float = -1.0) -> StyleBoxTexture:
	return box(SLOT_TAB, content_h, content_v)


static func tab_active(content_h: float = -1.0, content_v: float = -1.0) -> StyleBoxTexture:
	return box(SLOT_TAB_ACTIVE, content_h, content_v)


static func bar_frame() -> StyleBoxTexture:
	return box(SLOT_BAR_FRAME, 0.0, 0.0)


## Horizontally tiled hazard stripe (period 16 px, 16 px tall); stretch the box to the strip size.
static func hazard_stripe() -> StyleBoxTexture:
	var sb: StyleBoxTexture = box(SLOT_HAZARD, 0.0, 0.0)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb


## Sheet texture of the ui_kit; pair with `region(slot)` for `draw_texture_rect_region` (segments, ticks, brackets).
static func sheet() -> Texture2D:
	return ArtSlots.texture(SLOT_PLATE)


static func region(slot_id: String) -> Rect2:
	var art: ArtSlot = ArtSlots.slot(slot_id)
	return art.frame_rect(0) if art.valid else Rect2(0, 0, 1, 1)


static func segment_region(lit: bool) -> Rect2:
	return region(SLOT_BAR_SEGMENT if lit else SLOT_BAR_SEGMENT_OFF)


## Makes `b` an icon button: invisible styleboxes, the icon slot (e.g. "icon_ic_pause") scaled to the button rect.
## Keep `custom_minimum_size` >= 148 px on the button; the icon never shrinks the touch rect.
static func style_icon_button(b: Button, icon_slot: String) -> void:
	set_icon(b, icon_slot)
	b.flat = true
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	var none := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, none)
	b.add_theme_color_override("icon_pressed_color", ICON_PRESSED_TINT)
	b.add_theme_color_override("icon_hover_pressed_color", ICON_PRESSED_TINT)


static func set_icon(b: Button, icon_slot: String) -> void:
	var tex: Texture2D = ArtSlots.texture(icon_slot)
	if b.icon != tex:
		b.icon = tex


## A `TextureRect` showing an icon slot at `px` x `px` (no input).
static func icon_rect(icon_slot: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = ArtSlots.texture(icon_slot)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Adds the four amber corner brackets (art bible 7.1) as children of `host`, anchored to its corners.
static func add_brackets(host: Control, pad: float = 2.0) -> void:
	var at := AtlasTexture.new()
	at.atlas = sheet()
	at.region = region(SLOT_BRACKET)
	var leg: float = at.region.size.x
	for k: int in 4:
		var t := TextureRect.new()
		t.texture = at
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.flip_h = k % 2 == 1
		t.flip_v = k >= 2
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ax: float = float(k % 2)
		var ay: float = 0.0 if k < 2 else 1.0
		t.anchor_left = ax
		t.anchor_right = ax
		t.anchor_top = ay
		t.anchor_bottom = ay
		t.offset_left = -pad if ax == 0.0 else pad - leg
		t.offset_right = leg - pad if ax == 0.0 else pad
		t.offset_top = -pad if ay == 0.0 else pad - leg
		t.offset_bottom = leg - pad if ay == 0.0 else pad
		host.add_child(t)


## The plateless padlock of `ui_lock_mark` (cached): the face mark of an unaffordable cost button.
static func lock_icon() -> Texture2D:
	if _lock_icon == null:
		_lock_icon = AtlasTexture.new()
		_lock_icon.atlas = sheet()
		_lock_icon.region = region(SLOT_LOCK)
	return _lock_icon


## Adds a hazard-stripe strip (16 px tall) along the bottom of `host` (a non-container Control, e.g. the MAX chip).
## Returns it so the caller can show/hide it.
static func add_hazard(host: Control, pad_h: float = 24.0, pad_bottom: float = 14.0) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", hazard_stripe())
	p.anchor_left = 0.0
	p.anchor_right = 1.0
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = pad_h
	p.offset_right = -pad_h
	p.offset_bottom = -pad_bottom
	p.offset_top = -pad_bottom - region(SLOT_HAZARD).size.y
	host.add_child(p)
	return p
