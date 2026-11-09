class_name FoundryScreen
extends MenuScreen
## Foundry screen (M3-16; GDD 05 1.4, 07 2.4, Q64 no tabs): spend `data`, see the permanent effect, redeploy in one
## tap. Layout: title, a top bar (BACK left, DATA balance right, number roll unless reduce motion), the Power Rating
## preview strip, one scrolling list of `FoundryRow`s and a persistent DEPLOY button. Buying (tap, hold) is the run
## panel's `UpgradeRow` logic; each accepted step calls `FoundryService.buy` and `request_save`, the release (and
## leaving the screen) calls `save_now`. The profile is the single source: rows refresh from `FoundryService.rows`.
## Signals are final: deploy_pressed, back_pressed (the router turns them into flow events).
## Test seams: `use_profile`, `use_save_hooks`, `use_service`.

signal deploy_pressed
signal back_pressed

const ROW_GAP: int = 14
const DATA_SIZE: int = 64
const PREVIEW_SIZE: int = 38
const BACK_W: float = 300.0
const BODY_SEPARATION: int = 10
const HEADING_SIZE: int = 64
const DATA_PAD: float = 16.0

var service: FoundryService = null
var back_button: Button = null
var deploy_button: Button = null
var data_label: Label = null
var preview_label: Label = null
var locked_label: Label = null
var scroll: ScrollContainer = null
var list: VBoxContainer = null

var _profile: PlayerProfile = null
var _request_save: Callable = Callable()
var _save_now: Callable = Callable()
var _rows: Array[FoundryRow] = []
var _views: Array[FoundryRowView] = []
var _roll: NumberRoll = NumberRoll.new()
var _locked: bool = false


func title_key() -> String:
	return "foundry.title"


func _build() -> void:
	content.add_theme_constant_override("separation", BODY_SEPARATION)
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	heading.add_theme_font_size_override("font_size", HEADING_SIZE)
	content.add_child(_build_top_bar())
	preview_label = label("", &"LabelNumber", Palette.AMBER_GLOW, PREVIEW_SIZE)
	preview_label.hide()
	content.add_child(preview_label)
	locked_label = label("foundry.locked", &"LabelHeading", Palette.TEXT_DIM, 48)
	locked_label.hide()
	content.add_child(locked_label)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", ROW_GAP)
	scroll.add_child(list)
	content.add_child(scroll)
	deploy_button = make_button("foundry.deploy", _on_deploy)
	content.add_child(deploy_button)
	set_process(false)
	enter()


func _build_top_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 20)
	back_button = make_button("foundry.back", _on_back)
	back_button.custom_minimum_size.x = BACK_W
	bar.add_child(back_button)
	data_label = label("", &"LabelNumber", Palette.AMBER, DATA_SIZE)
	data_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	data_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	data_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	bar.add_child(data_label)
	var pad := Control.new()
	pad.custom_minimum_size.x = DATA_PAD
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(pad)
	return bar


## Test seam: show this profile instead of `Game.profile()`.
func use_profile(profile: PlayerProfile) -> void:
	_profile = profile


## Test seam: replaces the `Game.saves` calls (`request_save`, `save_now`).
func use_save_hooks(request_save: Callable, save_now: Callable) -> void:
	_request_save = request_save
	_save_now = save_now


## Test seam: a service with other defs.
func use_service(s: FoundryService) -> void:
	service = s


func enter() -> void:
	if list == null:
		return
	_close_tips()
	refresh(true)
	scroll.scroll_vertical = 0


func leave() -> void:
	if list == null:
		return
	_close_tips()
	_save()


## Re-reads the profile and rewrites every row, the balance and the preview. `instant` skips the number roll.
func refresh(instant: bool = false) -> void:
	var profile: PlayerProfile = _the_profile()
	if profile == null:
		return
	_ensure_service()
	_locked = not MetaUnlocks.foundry_screen_unlocked(profile)
	locked_label.visible = _locked
	scroll.visible = not _locked
	_views = service.rows(profile)
	_ensure_rows(_views.size())
	for i: int in _views.size():
		_rows[i].apply_foundry(FoundryRowModel.from_view(_views[i], i))
	_set_data(profile.data, instant)
	_set_preview(profile)


func is_locked() -> bool:
	return _locked


func row_count() -> int:
	return _rows.size()


func row_at(i: int) -> FoundryRow:
	return _rows[i]


## Index of the row that shows RECOMMENDED, or -1.
func recommended_index() -> int:
	for i: int in _rows.size():
		if _rows[i].is_recommended():
			return i
	return -1


## Advances the data number roll (called per frame while rolling; tests call it directly).
func advance_roll(now_s: float) -> void:
	var shown: float = _roll.value_at(now_s)
	data_label.text = Strings.fill1("foundry.data", "v", NumberFormat.format(BigNum.from_float(shown)))
	if _roll.is_done(now_s):
		_finish_roll()


func _process(delta: float) -> void:
	assert(delta >= 0.0)
	advance_roll(Time.get_ticks_msec() / 1000.0)


func _finish_roll() -> void:
	set_process(false)
	var text: String = NumberFormat.format(BigNum.from_float(_roll.target_value()))
	data_label.text = Strings.fill1("foundry.data", "v", text)


func _set_data(data: BigNum, instant: bool) -> void:
	var now_s: float = Time.get_ticks_msec() / 1000.0
	var snap: bool = instant or Game.visual.reduce_motion
	_roll.set_target(data.to_float(), now_s, snap)
	if snap or _roll.is_done(now_s):
		data_label.text = Strings.fill1("foundry.data", "v", NumberFormat.format(data))
		set_process(false)
	else:
		set_process(true)


func _set_preview(profile: PlayerProfile) -> void:
	var rec: int = -1
	for i: int in _views.size():
		if _views[i].recommended and _views[i].affordable:
			rec = i
	preview_label.visible = rec >= 0 and not _locked
	if rec < 0:
		return
	var pr: Vector2 = service.power_rating_preview(profile, _views[rec].id)
	var fine: bool = floorf(pr.x) == floorf(pr.y)
	preview_label.text = Strings.fill("foundry.preview", {"a": _pr_text(pr.x, fine), "b": _pr_text(pr.y, fine)})


## Power Rating text: whole numbers, one decimal when both values would otherwise read the same.
static func _pr_text(v: float, fine: bool) -> String:
	if fine:
		return "%.1f" % v
	return NumberFormat.format(BigNum.from_float(floorf(v)))


func _ensure_service() -> void:
	if service == null:
		var cfg: SimConfig = SimConfigLoader.load_default(1)
		service = FoundryService.new(SimConfigLoader.load_foundry_defs(), cfg.upgrades)


func _ensure_rows(n: int) -> void:
	var scene: PackedScene = load("res://src/ui/foundry/foundry_row.tscn")
	while _rows.size() < n:
		var row: FoundryRow = scene.instantiate()
		list.add_child(row)
		row.buy_pressed.connect(_on_buy)
		row.released.connect(_save)
		_rows.append(row)


func _on_buy(index: int, count: int) -> void:
	if index < 0 or index >= _views.size() or count <= 0:
		return
	var bought: int = service.buy(_the_profile(), _views[index].id, count)
	if bought <= 0:
		return
	if _request_save.is_valid():
		_request_save.call()
	elif Game.saves != null:
		Game.saves.request_save()
	refresh()


func _save() -> void:
	if _save_now.is_valid():
		@warning_ignore("return_value_discarded")
		_save_now.call()
	elif Game.saves != null:
		@warning_ignore("return_value_discarded")
		Game.saves.save_now()


func _close_tips() -> void:
	for r: FoundryRow in _rows:
		if r.is_tooltip_visible():
			r.toggle_tooltip()


func _the_profile() -> PlayerProfile:
	if _profile != null:
		return _profile
	if Game.saves == null:
		return null
	return Game.profile()


func _on_deploy() -> void:
	AudioHooks.tap()
	deploy_pressed.emit()


func _on_back() -> void:
	AudioHooks.tap()
	back_pressed.emit()
