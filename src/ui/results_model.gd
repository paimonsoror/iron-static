class_name ResultsModel
extends RefCounted
## Pure text model of the results screen (M2-11, M3-17; GDD 07 section 2.10): wave reached, time, kills, cause, data
## banked, scrap, best-wave delta and badge, Foundry call to action, frame-unlocked chip and save warning, all
## through `NumberFormat` and `data/strings_en.csv`. Without a `BankedInfo` (debug runs) best stays `--`.

var title_text: String = ""
var wave_text: String = ""
var time_text: String = ""
var kills_text: String = ""
var cause_text: String = ""
var data_text: String = ""
var scrap_text: String = ""
var best_text: String = ""
var new_best: bool = false
var new_best_text: String = ""
var foundry_visible: bool = false
var foundry_text: String = ""
## FOUNDRY button pulses (at least one row is affordable).
var foundry_pulse: bool = false
var home_text: String = ""
var redeploy_text: String = ""
var chip_text: String = ""
## "TIMED MODE" / "PURGE MODE" (empty without a bank) and the one-time "PURGE MODE UNLOCKED" line (M4-09).
var mode_text: String = ""
var mode_unlock_text: String = ""
var save_warning_text: String = ""

var _banked: BankedInfo = null
var _total_text: String = ""


## `cause` is the already localized killer name ("" or unknown id gives UNKNOWN). `banked` null: no bank line.
static func from_run(
	run: RunStats, economy: EconomyState, ticks: int, cause: String, banked: BankedInfo = null
) -> ResultsModel:
	var m: ResultsModel = ResultsModel.new()
	m._banked = banked
	m.title_text = Strings.get_text("results.title")
	m.wave_text = Strings.fill1("results.wave", "n", str(run.death_wave))
	var seconds: int = floori(float(maxi(ticks, 0)) / float(Ticks.TICK_RATE))
	m.time_text = Strings.fill1("results.time", "v", NumberFormat.format_time(seconds))
	m.kills_text = Strings.fill1("results.kills", "v", NumberFormat.format(BigNum.from_int(run.kills)))
	var who: String = cause if not cause.is_empty() else Strings.get_text("results.cause_unknown")
	m.cause_text = Strings.fill1("results.cause", "v", who)
	m.scrap_text = Strings.fill1("results.scrap", "v", NumberFormat.format(BigNum.from_float(run.scrap_earned)))
	m.home_text = Strings.get_text("results.home")
	m.redeploy_text = Strings.get_text("results.redeploy")
	m.new_best_text = Strings.get_text("results.new_best")
	var banked_now: String = NumberFormat.format(economy.data_run)
	m.data_text = Strings.fill1("results.data", "v", banked_now)
	m.best_text = Strings.get_text("results.best")
	if banked != null and banked.has_bank:
		m._total_text = NumberFormat.format(banked.data_total)
		m.data_text = m.data_line(banked_now)
		m._fill_banked(run.death_wave, banked)
	return m


## The data row for a (possibly still counting up) banked value text.
func data_line(value_text: String) -> String:
	if _banked == null or not _banked.has_bank:
		return Strings.fill1("results.data", "v", value_text)
	return Strings.fill("results.data_banked", {"v": value_text, "t": _total_text})


func _fill_banked(death_wave: int, banked: BankedInfo) -> void:
	new_best = death_wave > banked.previous_best
	var name_key: String = "mode." + banked.mode
	var mode_name: String = Strings.get_text(name_key)
	mode_text = Strings.fill1("results.mode", "name", mode_name)
	best_text = Strings.fill("results.best_mode", {"name": mode_name, "n": str(banked.new_best)})
	if not banked.unlocked_modes.is_empty():
		mode_unlock_text = Strings.get_text("mode.unlocked_toast")
	foundry_visible = banked.foundry_unlocked
	foundry_pulse = foundry_visible and banked.affordable_count > 0
	if banked.affordable_count > 0:
		foundry_text = Strings.fill1("results.foundry_n", "n", str(banked.affordable_count))
	else:
		foundry_text = Strings.get_text("results.foundry")
	var names: PackedStringArray = PackedStringArray()
	for id: String in banked.unlocked_frames:
		names.append(Strings.get_text("frame.name." + id))
	if not names.is_empty():
		chip_text = Strings.fill1(FrameRules.KEY_CHIP, "name", ", ".join(names))
	if banked.save_failed:
		save_warning_text = Strings.get_text("results.save_failed")
