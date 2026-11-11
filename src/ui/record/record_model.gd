class_name RecordModel
extends RefCounted
## Text model of the Service Record screen (pure: profile and data tables in, display strings out). Lifetime totals
## come from `RecordReader`; best waves, data earned and spent and the Foundry levels are read live from the profile.
## Numbers go through `NumberFormat` (the player's number-format setting), times through `duration_text`.

var sections: Array[RecordSection] = []
## "TRACKED SINCE 2026-11-10".
var since_text: String = ""
## Plain notes under the heading, "" when they do not apply: the record was started from an older save, and
## deployments that are missing some totals.
var seeded_note: String = ""
var gaps_note: String = ""


## `enemy_ids`: every enemy id of data/enemies.csv in row order; `modes` / `frames`: the data tables.
static func build(
	profile: PlayerProfile, enemy_ids: PackedStringArray, modes: Array[WaveModeDef], frames: Array[FrameDef]
) -> RecordModel:
	var m: RecordModel = RecordModel.new()
	var since: int = RecordReader.since(profile)
	if since > 0:
		m.since_text = Strings.fill1("record.since", "date", FlightRecorder.day_key(since))
	if RecordReader.seeded(profile):
		m.seeded_note = Strings.get_text("record.seeded_note")
	var gaps: int = RecordReader.total(profile, "gaps")
	if gaps > 0:
		m.gaps_note = Strings.fill1("record.gaps_note", "n", str(gaps))
	m.sections.append(_general(profile, modes))
	m.sections.append(_combat(profile))
	m.sections.append(_kills(profile, enemy_ids))
	m.sections.append(_economy(profile))
	var fs: RecordSection = _frames(profile, frames)
	if fs.size() > 0:
		m.sections.append(fs)
	return m


## `12h 05m` from an hour up, `5m 30s` from a minute, `45s` below.
static func duration_text(seconds: int) -> String:
	var s: int = maxi(seconds, 0)
	var h: int = floori(float(s) / 3600.0)
	var m: int = floori(float(s % 3600) / 60.0)
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%dm %02ds" % [m, s % 60]
	return "%ds" % s


## A whole number as the player wants numbers shown ("12.3K" in the short style).
static func count_text(n: int) -> String:
	return NumberFormat.format(BigNum.from_int(maxi(n, 0)))


## Percent with one decimal ("23.4%"), rounded down; the dash text when `whole` is 0.
static func rate_text(part: int, whole: int) -> String:
	if whole <= 0:
		return Strings.get_text("record.none")
	var tenths: int = floori(float(part) * 1000.0 / float(whole))
	return "%d.%d%%" % [floori(float(tenths) / 10.0), tenths % 10]


static func _general(profile: PlayerProfile, modes: Array[WaveModeDef]) -> RecordSection:
	var s: RecordSection = RecordSection.new(Strings.get_text("record.sec_general"))
	s.add(Strings.get_text("record.time_played"), duration_text(RecordReader.total(profile, "play_s")))
	var ticks: int = RecordReader.total(profile, "deploy_ticks")
	s.add(Strings.get_text("record.time_deployed"), duration_text(floori(float(ticks) / float(Ticks.TICK_RATE))))
	s.add(Strings.get_text("record.deployments"), count_text(RecordReader.runs_all(profile)))
	for def: WaveModeDef in modes:
		if not def.implemented:
			continue
		var name: String = Strings.get_text("mode." + def.id)
		s.add(Strings.fill1("record.mode_runs", "name", name), count_text(RecordReader.runs_of_mode(profile, def.id)))
	if RecordReader.runs_before(profile) > 0:
		s.add(Strings.get_text("record.earlier_runs"), count_text(RecordReader.runs_before(profile)))
	for def: WaveModeDef in modes:
		if not def.implemented:
			continue
		var best: int = profile.best_wave_of_mode(def.id, 1)
		var name: String = Strings.get_text("mode." + def.id)
		s.add(
			Strings.fill1("record.mode_best", "name", name),
			"W%d" % best if best > 0 else Strings.get_text("record.none")
		)
	s.add(Strings.get_text("record.waves_cleared"), count_text(RecordReader.total(profile, "waves")))
	var longest: int = RecordReader.total(profile, "longest_ticks")
	s.add(Strings.get_text("record.longest"), duration_text(floori(float(longest) / float(Ticks.TICK_RATE))))
	return s


static func _combat(profile: PlayerProfile) -> RecordSection:
	var s: RecordSection = RecordSection.new(Strings.get_text("record.sec_combat"))
	s.add(Strings.get_text("record.destroyed"), count_text(RecordReader.kills_all(profile)))
	s.add(Strings.get_text("record.bosses"), count_text(RecordReader.total(profile, "bosses")))
	var shots: int = RecordReader.total(profile, "shots")
	var crits: int = RecordReader.total(profile, "crits")
	s.add(Strings.get_text("record.shots"), count_text(shots))
	s.add(Strings.get_text("record.crits"), count_text(crits))
	s.add(Strings.get_text("record.crit_rate"), rate_text(crits, shots))
	s.add(Strings.get_text("record.damage"), NumberFormat.format(RecordReader.total_big(profile, "damage")))
	s.add(Strings.get_text("record.hit_max"), count_text(RecordReader.total(profile, "hit_max")))
	s.add(Strings.get_text("record.hull"), count_text(RecordReader.total(profile, "hull")))
	return s


## One row per enemy type of the data table (bosses included), with the names Intel and Results use.
static func _kills(profile: PlayerProfile, enemy_ids: PackedStringArray) -> RecordSection:
	var s: RecordSection = RecordSection.new(Strings.get_text("record.sec_kills"))
	for id: String in enemy_ids:
		s.add(KillEntry.display_name(id), count_text(RecordReader.kills_of(profile, id)))
	return s


static func _economy(profile: PlayerProfile) -> RecordSection:
	var s: RecordSection = RecordSection.new(Strings.get_text("record.sec_economy"))
	s.add(Strings.get_text("record.scrap_in"), NumberFormat.format(RecordReader.total_big(profile, "scrap_in")))
	s.add(Strings.get_text("record.scrap_out"), NumberFormat.format(RecordReader.total_big(profile, "scrap_out")))
	s.add(Strings.get_text("record.upgrades"), count_text(RecordReader.total(profile, "upgrades")))
	s.add(Strings.get_text("record.data_in"), NumberFormat.format(profile.lifetime_data))
	s.add(Strings.get_text("record.data_out"), NumberFormat.format(data_spent(profile)))
	var levels: int = 0
	for id: Variant in profile.foundry.keys():
		levels += profile.foundry_level(str(id))
	s.add(Strings.get_text("record.foundry_levels"), count_text(levels))
	s.add(Strings.get_text("record.patches"), count_text(RecordReader.total(profile, "patches")))
	return s


static func _frames(profile: PlayerProfile, frames: Array[FrameDef]) -> RecordSection:
	var s: RecordSection = RecordSection.new(Strings.get_text("record.sec_frames"))
	for def: FrameDef in frames:
		if not def.implemented:
			continue
		var runs: int = RecordReader.frame_runs(profile, def.id)
		var values: Dictionary[String, String] = {
			"n": count_text(runs),
			"b": str(RecordReader.frame_best(profile, def.id)),
		}
		var shown: String = Strings.fill("record.frame_value", values) if runs > 0 else Strings.get_text("record.none")
		s.add(Strings.get_text(def.name_key), shown)
	return s


## Data spent in the Foundry: the data ever banked minus the balance (the Foundry is the only place data is spent).
static func data_spent(profile: PlayerProfile) -> BigNum:
	return profile.lifetime_data.sub_floor0(profile.data)
