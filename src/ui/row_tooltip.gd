class_name RowTooltip
extends PanelContainer
## Tooltip of an `UpgradeRow` (V1-27; upgrade-info: description, now and next, then the formula). It is a sibling of the
## row inside the panel's scroll content, placed directly below the row, so it never covers the row's own header.
## Showing it scrolls the nearest ScrollContainer so the row and the tooltip are both visible (row top wins when they do
## not fit together). It hides after `hold_seconds` (`TOOLTIP_S` plus reading time for the text, at most
## `TOOLTIP_MAX_S`), when the list is dragged, or when the row hides or leaves the tree; tapping the row again hides it.

const TOOLTIP_S: float = 4.0
const TOOLTIP_MAX_S: float = 12.0
## Extra seconds per character of text (about 20 characters a second).
const READ_S_PER_CHAR: float = 0.05

var _row: Control = null
var _label: Label = Label.new()
var _timer: Timer = Timer.new()
var _scroll: ScrollContainer = null


func setup(row: Control) -> void:
	_row = row
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiKit.tooltip(20, 12))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_timer.one_shot = true
	_timer.wait_time = TOOLTIP_S
	_timer.timeout.connect(close)
	add_child(_timer)
	hide()


func set_text(text: String) -> void:
	_label.text = text


## How long the tooltip stays up for `text`: a base time plus reading time, capped.
static func hold_seconds(text: String) -> float:
	return minf(TOOLTIP_S + READ_S_PER_CHAR * float(text.length()), TOOLTIP_MAX_S)


## Shows the tooltip under the row (inserted after it in the row's parent) and scrolls it into view.
func open() -> void:
	var host: Node = _row.get_parent()
	if host == null:
		return
	if get_parent() != host:
		if get_parent() != null:
			get_parent().remove_child(self)
		host.add_child(self)
	host.move_child(self, _row.get_index() + 1)
	show()
	_timer.start(hold_seconds(_label.text))
	_connect_scroll()
	_reveal.call_deferred()


func close() -> void:
	_timer.stop()
	hide()


func _connect_scroll() -> void:
	var n: Node = _row.get_parent()
	while n != null and not n is ScrollContainer:
		n = n.get_parent()
	var sc: ScrollContainer = n as ScrollContainer
	if sc == _scroll:
		return
	if _scroll != null and _scroll.scroll_started.is_connected(close):
		_scroll.scroll_started.disconnect(close)
	_scroll = sc
	if _scroll != null:
		_scroll.scroll_started.connect(close)


## Waits two frames (the tooltip's size is only known after layout), then scrolls so row and tooltip are visible.
func _reveal() -> void:
	if _scroll == null or not visible or not is_inside_tree():
		return
	# Two frames: the wrapped label only reaches its final height one layout pass after the tooltip is shown.
	await get_tree().process_frame
	await get_tree().process_frame
	if _scroll == null or not visible or not _row.is_inside_tree():
		return
	var top: float = _row.global_position.y - _scroll.global_position.y
	var bottom: float = global_position.y + size.y - _scroll.global_position.y  # the tooltip's real bottom edge
	var view: float = _scroll.size.y
	var shift: float = minf(maxf(bottom - view, 0.0), top)
	_scroll.scroll_vertical = maxi(_scroll.scroll_vertical + roundi(shift), 0)
