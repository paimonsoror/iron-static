class_name RowTooltip
extends PanelContainer
## Formula tooltip of an `UpgradeRow` (V1-27). It is a sibling of the row inside the panel's scroll content, placed
## directly below the row, so it never covers the row's own header. Showing it scrolls the nearest ScrollContainer so
## the row and the tooltip are both visible (row top wins when they do not fit together). It hides after `TOOLTIP_S`,
## when the list is dragged, or when the row hides or leaves the tree.

const TOOLTIP_S: float = 3.0

var _row: Control = null
var _label: Label = Label.new()
var _timer: Timer = Timer.new()
var _scroll: ScrollContainer = null


func setup(row: Control) -> void:
	_row = row
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiKit.tooltip(20, 6))
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
	_timer.start()
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


## Waits one frame (the tooltip's size is only known after layout), then scrolls so row and tooltip are visible.
func _reveal() -> void:
	if _scroll == null or not visible or not is_inside_tree():
		return
	await get_tree().process_frame
	if _scroll == null or not visible or not _row.is_inside_tree():
		return
	var top: float = _row.global_position.y - _scroll.global_position.y
	var bottom: float = top + _row.size.y + size.y
	var view: float = _scroll.size.y
	var shift: float = minf(maxf(bottom - view, 0.0), top)
	_scroll.scroll_vertical = maxi(_scroll.scroll_vertical + roundi(shift), 0)
