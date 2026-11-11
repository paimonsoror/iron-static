class_name HomeModel
extends RefCounted
## Pure text and visibility model of the Home screen (M3-15, GDD 07 section 2.3 for the MVP). Built from the
## profile and the data tables (injected, no autoloads), so it is unit-testable headless. Every string comes
## from `data/strings_en.csv` keys; nothing here touches the scene tree.

var pr_text: String = ""
var data_text: String = ""
var sector_text: String = ""
var best_text: String = ""
var best_known: bool = false
var frame_id: String = FrameRules.DEFAULT_FRAME
var frame_text: String = ""
## The tappable frame chip ("FRAME: VANGUARD >"); shown once the profile has progress (opens the frame bay).
var frame_button_text: String = ""
var frame_button_visible: bool = false
## `home.next_unlock` for the next locked run row, or `home.all_unlocked`.
var hint_text: String = ""
var all_unlocked: bool = false
## Id of the next locked run row ("" when all are unlocked) and its gate wave.
var next_unlock_id: String = ""
var next_unlock_wave: int = 0
var foundry_visible: bool = false
## The RECORD tab (Service Record) is shown from the first banked deployment, like the Foundry.
var record_visible: bool = false
## Number of Foundry rows whose next level is affordable; the hint chip shows only when above 0.
var affordable: int = 0
var foundry_hint_text: String = ""
var nav: Array[StringName] = []
## Mode picker cards (`ModeRules.cards`, data-driven), the selected mode id (always an unlocked one) and the
## one-time unlock chip line ("" when none is pending).
var mode_cards: Array[ModeCard] = []
var selected_mode: String = SimConfig.MODE_TIMED
var unlock_chip_text: String = ""


func hint_chip_visible() -> bool:
	return foundry_visible and affordable > 0


## The bottom nav is shown only when there is something besides HOME to go to (locked items are hidden).
func nav_visible() -> bool:
	return nav.size() > 1


static func build(
	profile: PlayerProfile,
	upgrades: Array[RunUpgradeDef],
	foundry: FoundryService,
	frame_defs: Array[FrameDef],
	mode_defs: Array[WaveModeDef] = [],
) -> HomeModel:
	var m := HomeModel.new()
	var best: int = profile.best_wave_s1()
	m.data_text = Strings.fill1("home.data", "v", NumberFormat.format(profile.data))
	m.sector_text = Strings.fill1("home.sector", "n", "1")
	m.best_known = best > 0
	m.nav = MetaUnlocks.visible_nav(profile)
	m.foundry_visible = MetaUnlocks.foundry_screen_unlocked(profile)
	m.record_visible = m.foundry_visible
	var nu: Vector2i = MetaUnlocks.next_unlock_line(upgrades, best)
	if nu.x >= 0 and nu.x < upgrades.size():
		m.next_unlock_id = upgrades[nu.x].id
		m.next_unlock_wave = nu.y
		var values: Dictionary[String, String] = {
			"w": str(nu.y), "name": UpgradeRowModel.upgrade_name(m.next_unlock_id)
		}
		m.hint_text = Strings.fill("home.next_unlock", values)
	else:
		m.all_unlocked = true
		m.hint_text = _speed_hint(best)
	m.affordable = foundry.affordable_count(profile)
	m.foundry_hint_text = Strings.fill1("home.foundry_hint", "n", str(m.affordable))
	m.frame_id = FrameRules.selected_id(profile, frame_defs)
	var def: FrameDef = FrameRules.find_def(frame_defs, m.frame_id)
	if def != null:
		m.frame_text = Strings.fill1("frame.chip", "name", Strings.get_text(def.name_key))
		m.frame_button_text = Strings.fill1("home.frame_button", "name", Strings.get_text(def.name_key))
	m.frame_button_visible = profile.has_progress()
	var cards: Array[FrameCard] = FrameRules.cards(profile, frame_defs, foundry)
	var pr: float = 0.0
	for c: FrameCard in cards:
		if c.id == m.frame_id:
			pr = c.power_rating
	m.pr_text = Strings.fill1("home.pr", "v", str(roundi(pr)))
	m._fill_modes(profile, mode_defs)
	m.best_text = best_line(profile, m.selected_mode)
	m.best_known = profile.best_wave_of_mode(m.selected_mode, 1) > 0
	return m


## The Home best line of one mode (M4-09): every mode "BEST {name} {n}" ("BEST TIMED 14", "BEST PURGE 31"),
## "NO DEPLOYMENT YET" when that mode was never played.
static func best_line(profile: PlayerProfile, mode_id: String) -> String:
	var best: int = profile.best_wave_of_mode(mode_id, 1)
	if best <= 0:
		return Strings.get_text("home.best_none")
	var name_key: String = "mode." + mode_id
	return Strings.fill("home.best_mode", {"name": Strings.get_text(name_key), "n": str(best)})


## Cards of the wave mode picker. The selection is `last_mode` when unlocked, else the first unlocked card, so a
## locked mode can never be preselected (Q75). A pending unlock flag turns into the chip line.
func _fill_modes(profile: PlayerProfile, mode_defs: Array[WaveModeDef]) -> void:
	var defs: Array[WaveModeDef] = mode_defs if not mode_defs.is_empty() else ModeRules.load_defs()
	mode_cards = ModeRules.cards(profile, defs)
	selected_mode = ""
	for c: ModeCard in mode_cards:
		c.selected = c.unlocked and c.id == profile.last_mode
		if c.selected:
			selected_mode = c.id
	if selected_mode.is_empty():
		for c: ModeCard in mode_cards:
			if c.unlocked:
				c.selected = true
				selected_mode = c.id
				break
	if not ModeUnlockFlag.pending(profile).is_empty():
		unlock_chip_text = Strings.get_text("mode.unlocked_toast")


## Once every run row is open, the unlock chip names the next game speed (R1-03: 4x at best TIMED wave 30, 8x at 60);
## `home.all_unlocked` when nothing is left.
static func _speed_hint(best: int) -> String:
	var ns: Vector2i = SpeedRules.next_unlock(best)
	if ns.x <= 0:
		return Strings.get_text("home.all_unlocked")
	var values: Dictionary[String, String] = {"w": str(ns.y), "name": Strings.fill1("home.speed_name", "n", str(ns.x))}
	return Strings.fill("home.next_unlock", values)
