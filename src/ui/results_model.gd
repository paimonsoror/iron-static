class_name ResultsModel
extends RefCounted
## Pure text model of the results screen (M2-11; GDD 07 section 2.10): wave reached, time, kills, cause, data
## and scrap through `NumberFormat`. Best-wave delta stays `--` until M3.

var title_text: String = ""
var wave_text: String = ""
var time_text: String = ""
var kills_text: String = ""
var cause_text: String = ""
var data_text: String = ""
var scrap_text: String = ""
var best_text: String = ""


## `cause` is the already localized killer name ("" or unknown id gives UNKNOWN).
static func from_run(run: RunStats, economy: EconomyState, ticks: int, cause: String) -> ResultsModel:
	var m: ResultsModel = ResultsModel.new()
	m.title_text = Strings.get_text("results.title")
	m.wave_text = Strings.fill1("results.wave", "n", str(run.death_wave))
	var seconds: int = floori(float(maxi(ticks, 0)) / float(Ticks.TICK_RATE))
	m.time_text = Strings.fill1("results.time", "v", NumberFormat.format_time(seconds))
	m.kills_text = Strings.fill1("results.kills", "v", NumberFormat.format(BigNum.from_int(run.kills)))
	var who: String = cause if not cause.is_empty() else Strings.get_text("results.cause_unknown")
	m.cause_text = Strings.fill1("results.cause", "v", who)
	m.data_text = Strings.fill1("results.data", "v", NumberFormat.format(economy.data_run))
	m.scrap_text = Strings.fill1("results.scrap", "v", NumberFormat.format(BigNum.from_float(run.scrap_earned)))
	m.best_text = Strings.get_text("results.best")
	return m
