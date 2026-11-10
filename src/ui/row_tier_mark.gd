class_name RowTierMark
extends RefCounted
## Visual-tier readout of one `UpgradeRow` (VT-6, docs/design/12 s6.1): the mark chip (`MK II`), the `NEXT LOOK AT
## L12` line and a thin progress bar toward the next mark. Only rows with tiers show it; the nodes are rewritten
## only when a value changed (rows are re-applied by a timer, so unchanged frames cost nothing and allocate nothing).
## The chip is flat and never animates: the gold ring and its 0.4 s expansion (`RowFx`) stay the only motion, so at
## MK IV (which lands on the x25 ring) the two do not compete. Newest mark = amber on the active plate; MK I and
## the first PLATED mark = dim on the normal plate; the top mark hides the bar and the line reads TOP MARK.

const CHIP_SIZE: int = 34
const NEXT_SIZE: int = 38
## The next-look line is teal for this long after the displayed tier rises (VT-5, spec 12 s6.1).
const TEAL_MS: int = 3000

## Monotonic time in ms; tests replace it.
var clock: Callable = Time.get_ticks_msec

var _line: Control = null
var _chip: Label = null
var _next: Label = null
var _bar: ProgressBar = null
var _shown: bool = false
var _mark: String = "\n"  # never a real mark: the first apply always sets the chip
var _next_text: String = ""
var _progress: float = -1.0
var _top: bool = false
var _tier: int = -1
var _teal_until_ms: int = -1
var _next_color: Color = Palette.TEXT_DIM
var _dim_plate: StyleBox = UiKit.tab(12, 5)
var _lit_plate: StyleBox = UiKit.tab_active(12, 5)


func setup(line: Control, chip: Label, next: Label, bar: ProgressBar) -> void:
	_line = line
	_chip = chip
	_next = next
	_bar = bar
	_chip.add_theme_font_size_override("font_size", CHIP_SIZE)
	_next.add_theme_font_size_override("font_size", NEXT_SIZE)
	_next.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Palette.AMBER_DIM
	_bar.add_theme_stylebox_override("fill", fill)


func apply(model: UpgradeRowModel) -> void:
	if model.tier_has != _shown:
		_shown = model.tier_has
		_line.visible = _shown
		_bar.visible = _shown and not model.tier_top
	if not _shown:
		return
	if model.mark_text != _mark:
		_mark = model.mark_text
		_chip.text = _mark
		_chip.visible = not _mark.is_empty()
	if model.tier != _tier:
		if _tier >= 0 and model.tier > _tier:  # a rise, not the first apply (resume, new run)
			_teal_until_ms = _now() + TEAL_MS
		_tier = model.tier
		var lit: bool = _tier >= 2
		_chip.add_theme_stylebox_override("normal", _lit_plate if lit else _dim_plate)
		_chip.add_theme_color_override("font_color", Palette.AMBER if lit else Palette.TEXT_DIM)
	if model.next_text != _next_text:
		_next_text = model.next_text
		_next.text = _next_text
	if model.tier_top != _top:
		_top = model.tier_top
		_bar.visible = not _top
	if not is_equal_approx(model.tier_progress, _progress):
		_progress = model.tier_progress
		_bar.value = _progress
	_paint_next()


## True while the next-look line is in its 3 s teal phase.
func is_teal() -> bool:
	return _teal_until_ms >= 0 and _now() < _teal_until_ms


func _paint_next() -> void:
	var color: Color = Palette.TEAL if is_teal() else (Palette.AMBER_TEXT if _top else Palette.TEXT_DIM)
	if color != _next_color:
		_next_color = color
		_next.add_theme_color_override("font_color", color)


func _now() -> int:
	var t: int = clock.call()
	return t


func is_chip_visible() -> bool:
	return _shown and _chip.visible


func is_bar_visible() -> bool:
	return _shown and _bar.visible
