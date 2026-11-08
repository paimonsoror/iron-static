class_name TestUiStringKeys
extends GdUnitTestSuite
## Guards against a missing UI string key (M2-16): building the HUD with the upgrade panel and the results
## overlay against a world with all 10 rows visible must not bump `Strings.missing_count`.

const BANNED: PackedStringArray = ["Cash", "Coins", "Gems", "Power Stones", "Workshop", "Ultimate", "Cards"]
const UI_FOLDERS: PackedStringArray = [
	"res://src/ui/home",
	"res://src/ui/foundry",
	"res://src/ui/settings",
	"res://src/ui/flow",
	"res://src/ui/title",
	"res://src/ui/frames",
]
const M3_KEYS: PackedStringArray = [
	"home.header",
	"home.pr",
	"home.data",
	"home.sector",
	"home.best",
	"home.best_none",
	"home.deploy",
	"home.next_unlock",
	"home.all_unlocked",
	"home.foundry_hint",
	"nav.home",
	"nav.foundry",
	"nav.settings",
	"foundry.title",
	"foundry.data",
	"foundry.level",
	"foundry.value",
	"foundry.value_start",
	"foundry.milestone",
	"foundry.max",
	"foundry.recommended",
	"foundry.afford_now",
	"foundry.afford_in",
	"foundry.preview",
	"foundry.deploy",
	"foundry.back",
	"foundry.tooltip_d",
	"foundry.tooltip_c",
	"foundry.locked",
	"results.best_delta",
	"results.best_same",
	"results.new_best",
	"results.data_banked",
	"results.foundry",
	"results.foundry_n",
	"results.home",
	"settings.title",
	"settings.sound",
	"settings.music",
	"settings.mute",
	"settings.reduce_motion",
	"settings.shake",
	"settings.scanlines",
	"settings.number_format",
	"settings.fps_cap",
	"settings.back",
	"settings.opt.off",
	"settings.opt.low",
	"settings.opt.normal",
	"settings.opt.short",
	"settings.opt.scientific",
	"settings.opt.engineering",
	"settings.opt.fps30",
	"settings.opt.fps60",
	"settings.version",
	"settings.note_session",
	"save.problem_title",
	"save.corrupt_body",
	"save.start_new",
	"save.too_new_body",
	"save.recovered",
	"save.resumed",
	"save.run_ended_by_update",
	"exit.back_again",
	"title.continue",
	"title.new_game",
	"title.settings",
	"title.quit_title",
	"title.quit_yes",
	"title.quit_no",
	"title.newgame_confirm_title",
	"title.newgame_confirm_body",
	"title.version",
	"frame.name.vanguard",
	"frame.name.bulwark",
	"frame.name.striker",
	"frame.name.salvager",
	"frame.name.longshot",
	"frame.role.vanguard",
	"frame.role.bulwark",
	"frame.role.striker",
	"frame.role.salvager",
	"frame.role.longshot",
	"frame.passive.vanguard",
	"frame.passive.bulwark",
	"frame.passive.striker",
	"frame.passive.salvager",
	"frame.passive.longshot",
	"frame.passive_desc.vanguard",
	"frame.passive_desc.bulwark",
	"frame.passive_desc.striker",
	"frame.passive_desc.salvager",
	"frame.passive_desc.longshot",
	"frame.bay_title",
	"frame.select",
	"frame.selected",
	"frame.locked_wave",
	"frame.progress",
	"frame.unlocked_chip",
	"frame.pr",
	"frame.stat.hull",
	"frame.stat.rate",
	"frame.stat.damage",
	"frame.stat.range",
	"frame.stat.crit",
	"frame.stat.repair",
	"frame.chip",
	"settings.data",
	"settings.reset",
	"settings.reset_confirm1",
	"settings.reset_confirm2",
	"settings.reset_done",
]


func test_hud_and_results_overlay_use_only_known_keys() -> void:
	var before: int = Strings.missing_count
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.best_wave_s1 = 12
	var w := SimWorld.new(cfg)
	var hud: Hud = auto_free((load("res://src/ui/hud.tscn") as PackedScene).instantiate())
	add_child(hud)
	hud.refresh(w, 0.0)
	var panel: UpgradePanel = hud.upgrade_panel()
	for tab: String in UpgradePanelModel.TAB_IDS:
		panel.set_tab(tab)
		panel.refresh()
	hud.set_paused(true)
	hud.set_paused(false)
	var overlay: ResultsOverlay = auto_free((load("res://src/ui/results_overlay.tscn") as PackedScene).instantiate())
	add_child(overlay)
	var c := RunController.new()
	c.start_run(1)
	c.fast_forward(60000)
	overlay.show_results(c.world)
	assert_int(Strings.missing_count).is_equal(before)


func test_every_run_upgrade_has_a_name_key() -> void:
	var table: CsvTable = CsvTable.load_file("res://data/run_upgrades.csv")
	assert_int(table.rows.size()).is_greater(0)
	for r: int in table.rows.size():
		var key: String = "upgrade." + table.get_value(r, "id")
		assert_bool(Strings.has_key(key)).is_true()


func test_every_m3_key_resolves_and_is_clean() -> void:
	var before: int = Strings.missing_count
	assert_int(M3_KEYS.size()).is_greater(100)
	for key: String in M3_KEYS:
		assert_bool(Strings.has_key(key)).is_true()
		var text: String = Strings.get_text(key)
		assert_str(text).is_not_equal(key)
		for word: String in BANNED:
			assert_bool(text.to_lower().contains(word.to_lower())).is_false()
	assert_int(Strings.missing_count).is_equal(before)


func test_no_banned_vocabulary_in_any_string() -> void:
	var csv: CsvTable = CsvTable.load_file(Strings.PATH)
	for r: int in csv.rows.size():
		var text: String = csv.get_value(r, "text")
		for word: String in ["Cash", "Coins", "Gems", "Power Stones", "Workshop", "Ultimate"]:
			assert_bool(text.contains(word)).is_false()


func test_ui_folders_use_only_known_keys() -> void:
	var pattern: String = 'Strings[.](?:get_text|fill1|fill|has_key)[(]\\s*["]([^"]+)["]'
	var re: RegEx = RegEx.create_from_string(pattern)
	for folder: String in UI_FOLDERS:
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
			continue
		for file: String in DirAccess.get_files_at(folder):
			if not file.ends_with(".gd"):
				continue
			var text: String = FileAccess.get_file_as_string(folder.path_join(file))
			for m: RegExMatch in re.search_all(text):
				var key: String = m.get_string(1)
				(
					assert_bool(Strings.has_key(key))
					. override_failure_message("%s uses missing key %s" % [file, key])
					. is_true()
				)
