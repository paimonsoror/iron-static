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
## `home.next_unlock` for the next locked run row, or `home.all_unlocked`.
var hint_text: String = ""
var all_unlocked: bool = false
## Id of the next locked run row ("" when all are unlocked) and its gate wave.
var next_unlock_id: String = ""
var next_unlock_wave: int = 0
var foundry_visible: bool = false
## Number of Foundry rows whose next level is affordable; the hint chip shows only when above 0.
var affordable: int = 0
var foundry_hint_text: String = ""
var nav: Array[StringName] = []


func hint_chip_visible() -> bool:
	return foundry_visible and affordable > 0


## The bottom nav is shown only when there is something besides HOME to go to (locked items are hidden).
func nav_visible() -> bool:
	return nav.size() > 1


static func build(
	profile: PlayerProfile, upgrades: Array[RunUpgradeDef], foundry: FoundryService, frame_defs: Array[FrameDef]
) -> HomeModel:
	var m := HomeModel.new()
	var best: int = profile.best_wave_s1()
	m.data_text = Strings.fill1("home.data", "v", NumberFormat.format(profile.data))
	m.sector_text = Strings.fill1("home.sector", "n", "1")
	m.best_known = best > 0
	m.best_text = Strings.fill1("home.best", "n", str(best)) if best > 0 else Strings.get_text("home.best_none")
	m.nav = MetaUnlocks.visible_nav(profile)
	m.foundry_visible = MetaUnlocks.foundry_screen_unlocked(profile)
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
		m.hint_text = Strings.get_text("home.all_unlocked")
	m.affordable = foundry.affordable_count(profile)
	m.foundry_hint_text = Strings.fill1("home.foundry_hint", "n", str(m.affordable))
	m.frame_id = FrameRules.selected_id(profile, frame_defs)
	var def: FrameDef = FrameRules.find_def(frame_defs, m.frame_id)
	if def != null:
		m.frame_text = Strings.fill1("frame.chip", "name", Strings.get_text(def.name_key))
	var cards: Array[FrameCard] = FrameRules.cards(profile, frame_defs, foundry)
	var pr: float = 0.0
	for c: FrameCard in cards:
		if c.id == m.frame_id:
			pr = c.power_rating
	m.pr_text = Strings.fill1("home.pr", "v", str(roundi(pr)))
	return m
