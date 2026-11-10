class_name JourneySelfCheck
extends RefCounted
## `journey_run --self-check` (FO-2): proves the tool's own plumbing, like balance_run's canary. Prints
## "JOURNEY selfcheck <name> PASS|FAIL" per check and "JOURNEY SELFCHECK PASS|FAIL". Returns the exit code (0/2).
## Uses short journeys (wave cap 8) so it takes a few seconds.

static var _failed: int = 0


static func run() -> int:
	_failed = 0
	_check_args()
	_check_overrides()
	_check_spend_accounting()
	_check_cap()
	_check_recommended_mirror()
	_check_journey()
	_check_probe()
	print("JOURNEY SELFCHECK %s" % ("PASS" if _failed == 0 else "FAIL"))
	return 0 if _failed == 0 else 2


static func _report(check_name: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failed += 1
	print("JOURNEY selfcheck %s %s%s" % [check_name, "PASS" if ok else "FAIL", "" if ok else " (" + detail + ")"])


static func _check_args() -> void:
	var good: JourneyArgs = JourneyArgs.parse(
		PackedStringArray(
			["--spend", "laser", "--deployments", "4", "--set", "sim.data_level_coef=0.03", "--cap-k", "1.5"]
		)
	)
	_report(
		"args_parse", good.error.is_empty() and good.spend == "laser" and good.deployments == 4 and good.cap_k == 1.5
	)
	var bad_spend: JourneyArgs = JourneyArgs.parse(PackedStringArray(["--spend", "bogus"]))
	var bad_set: JourneyArgs = JourneyArgs.parse(PackedStringArray(["--set", "sim.x"]))
	var bad_flag: JourneyArgs = JourneyArgs.parse(PackedStringArray(["--nope", "1"]))
	_report(
		"args_reject", not bad_spend.error.is_empty() and not bad_set.error.is_empty() and not bad_flag.error.is_empty()
	)


static func _check_overrides() -> void:
	var ok: JourneyOverrides = JourneyOverrides.parse(
		PackedStringArray(["sim.data_level_coef=0.5", "enemies.data_scale=0.5", "foundry.laser_output.fc0=40"])
	)
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	var base_data: float = cfg.enemies[0].data_base
	ok.apply_to_config(cfg)
	var defs: Array[FoundryDef] = ok.foundry_defs()
	var plain: Array[FoundryDef] = SimConfigLoader.load_foundry_defs()
	_report(
		"override_applies",
		(
			ok.error.is_empty()
			and is_equal_approx(cfg.tuning.data_level_coef, 0.5)
			and is_equal_approx(cfg.enemies[0].data_base, base_data * 0.5)
			and is_equal_approx(defs[0].fc0, 40.0)
			and is_equal_approx(plain[0].fc0, 20.0)
		),
		"coef=%s data_base=%s fc0=%s" % [cfg.tuning.data_level_coef, cfg.enemies[0].data_base, defs[0].fc0]
	)
	var shared: SimTuning = load(SimConfigLoader.TUNING_PATH)
	_report("override_isolated", not is_equal_approx(shared.data_level_coef, 0.5))
	var bad_sim: JourneyOverrides = JourneyOverrides.parse(PackedStringArray(["sim.no_such_key=1"]))
	var bad_row: JourneyOverrides = JourneyOverrides.parse(PackedStringArray(["foundry.nope.fc0=1"]))
	var bad_shape: JourneyOverrides = JourneyOverrides.parse(PackedStringArray(["upgrade.laser_output.c0=1"]))
	_report(
		"override_rejects_unknown",
		not bad_sim.error.is_empty() and not bad_row.error.is_empty() and not bad_shape.error.is_empty()
	)


static func _service(cap: int) -> FoundryService:
	var args: JourneyArgs = JourneyArgs.new()
	args.cap_k = 1.0 if cap > 0 else 0.0
	var sim: JourneySim = JourneySim.new(args, JourneyOverrides.new())
	return sim.make_service(cap)


## Every policy: spent Data equals the exact sum of the level costs, nothing is bought above the balance, and the
## policy-specific shape holds (laser only buys laser; round-robin stays within one level across rows).
static func _check_spend_accounting() -> void:
	var defs: Array[FoundryDef] = SimConfigLoader.load_foundry_defs()
	for policy: String in ["cheapest", "laser", "recommended", "roundrobin"]:
		var profile: PlayerProfile = PlayerProfile.fresh(0, "check")
		profile.data = BigNum.from_float(1000.0)
		var spender: JourneySpend = JourneySpend.new(policy)
		var bought: int = spender.spend(profile, _service(0))
		var cost: float = BalanceSetup.foundry_cost(profile.foundry)
		var left: float = profile.data.to_float()
		var ok: bool = bought > 0 and absf((1000.0 - left) - cost) < 0.5 and left >= 0.0
		if policy == "laser":
			ok = ok and profile.foundry.size() == 1 and profile.foundry.has("laser_output")
		if policy == "roundrobin":
			var lo: int = 1000
			var hi: int = 0
			for def: FoundryDef in defs:
				lo = mini(lo, profile.foundry_level(def.id))
				hi = maxi(hi, profile.foundry_level(def.id))
			ok = ok and hi - lo <= 1
		_report("spend_%s" % policy, ok, "bought=%d left=%.1f cost=%.1f" % [bought, left, cost])


static func _check_cap() -> void:
	var profile: PlayerProfile = PlayerProfile.fresh(0, "check")
	profile.data = BigNum.from_float(1.0e9)
	var spender: JourneySpend = JourneySpend.new("roundrobin")
	@warning_ignore("return_value_discarded")
	spender.spend(profile, _service(4))
	var worst: int = 0
	for id: String in profile.foundry.keys():
		worst = maxi(worst, profile.foundry_level(id))
	_report("cap_limits_every_row", worst == 4 and profile.foundry.size() == 4, "max level %d" % worst)


## The recommended policy's first purchase is the row `FoundryRules.recommended` flags (with the cheapest-affordable
## fallback on a fresh profile) and the glow moves to a milestone-near row once one is within 3 levels.
static func _check_recommended_mirror() -> void:
	var service: FoundryService = _service(0)
	var profile: PlayerProfile = PlayerProfile.fresh(0, "check")
	profile.data = BigNum.from_float(25.0)
	var rows: Array[FoundryRowView] = service.rows(profile)
	var rec: int = FoundryRules.recommended(rows)
	var spender: JourneySpend = JourneySpend.new("recommended")
	@warning_ignore("return_value_discarded")
	spender.spend(profile, service)
	_report("recommended_matches_glow", rec >= 0 and profile.foundry_level(rows[rec].id) >= 1, "rec=%d" % rec)
	profile.set_foundry_level("hull_integrity", 8)
	rows = service.rows(profile)
	rec = FoundryRules.recommended(rows)
	_report("recommended_near_milestone", rec >= 0 and rows[rec].levels_to_milestone <= FoundryRules.NEAR_MILESTONE)


## Two identical short journeys give identical hashes; deployment 1 equals balance_run's setup for the same seed;
## banked Data adds up; Foundry levels reach the next deployment's config.
static func _check_journey() -> void:
	var args: JourneyArgs = JourneyArgs.parse(
		PackedStringArray(["--deployments", "3", "--waves", "8", "--spend", "cheapest", "--seed", "7"])
	)
	var a: Array[Dictionary] = JourneySim.new(args, JourneyOverrides.new()).run()
	var sim_b: JourneySim = JourneySim.new(args, JourneyOverrides.new())
	var b: Array[Dictionary] = sim_b.run()
	var same: bool = a.size() == 3 and b.size() == 3
	for i: int in range(mini(a.size(), b.size())):
		var ha: Variant = a[i]["hash"]
		var hb: Variant = b[i]["hash"]
		var la: Variant = a[i]["levels"]
		var lb: Variant = b[i]["levels"]
		same = same and ha == hb and la == lb
	_report("journey_deterministic", same)
	var direct: Dictionary = JourneySim.play(BalanceSetup.make_config(7, 1, 0, {}, "vanguard", "timed"), "greedy4", 8)
	var hash_a: Variant = a[0]["hash"]
	var hash_d: Variant = direct["hash"]
	var same_hash: bool = hash_a == hash_d
	_report("deployment_1_matches_balance_setup", same_hash)
	var total: float = 0.0
	for r: Dictionary in a:
		var earned: float = r["data"]
		total += earned
	var banked: float = sim_b.profile.lifetime_data.to_float()
	_report("data_banked_in_full", absf(total - banked) < 0.5, "sum=%.1f banked=%.1f" % [total, banked])
	var spent_total: float = 0.0
	for r: Dictionary in a:
		var spent: float = r["spent"]
		spent_total += spent
	var cost_total: float = BalanceSetup.foundry_cost(sim_b.profile.foundry)
	_report(
		"spent_equals_level_costs",
		absf(spent_total - cost_total) < 0.5,
		"spent=%.1f costs=%.1f" % [spent_total, cost_total]
	)
	var cfg: SimConfig = sim_b.make_config(7, 0, {"laser_output": 5}, "vanguard")
	_report("levels_reach_config", cfg.foundry_levels.size() > 0 and cfg.foundry_levels[0] == 5)


## Probe mode on the checked-in foundry_300 profile: runs, prints, and the profile's cost matches the file's total.
static func _check_probe() -> void:
	var args: JourneyArgs = JourneyArgs.parse(
		PackedStringArray(["--profile", "res://tests/profiles/foundry_300.json", "--runs", "2", "--waves", "6"])
	)
	var err: String = JourneyProbe.run(args, JourneyOverrides.new())
	_report("probe_profile", err.is_empty(), err)
