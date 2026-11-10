class_name JourneySim
extends RefCounted
## Journey simulation core (FO-2): consecutive deployments from a fresh profile, run upgrades bought by PolicyBot
## inside a deployment, Foundry rows bought by JourneySpend between deployments. Banking goes through the real
## `PlayerProfile.bank_run` (Data banked in full at death, best wave, runs_total), Foundry buying through the real
## `FoundryService`, run setup through `BalanceSetup.make_config` (the same path as tools/balance_run.gd).
## Frames: a non-VANGUARD scenario frame is played from the first deployment after its `unlock_best_wave`
## (frames.csv) is reached by the profile's best wave; earlier deployments use VANGUARD.

var args: JourneyArgs
var overrides: JourneyOverrides
var profile: PlayerProfile = PlayerProfile.fresh(0, "journey")
var spender: JourneySpend
var ticks_total: int = 0
var _frame_gates: Dictionary = {}  # frame id -> unlock best wave


func _init(journey_args: JourneyArgs, journey_overrides: JourneyOverrides) -> void:
	args = journey_args
	overrides = journey_overrides
	spender = JourneySpend.new(args.spend)
	var table: FrameTable = load(SimConfigLoader.FRAME_TABLE_PATH)
	for def: FrameDef in table.defs:
		_frame_gates[def.id] = def.unlock_best_wave


## Plays `args.deployments` deployments; returns one record Dictionary per deployment.
func run() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cum_data: float = 0.0
	var cum_ticks: int = 0
	var streak: int = 0
	for dep: int in range(args.deployments):
		var best: int = profile.best_wave_of_mode(args.mode, 1)
		var frame_id: String = frame_for(best)
		var levels_in: Dictionary = profile.foundry.duplicate()
		var seed_used: int = args.seed_value + dep
		var cfg: SimConfig = make_config(seed_used, best, levels_in, frame_id)
		var res: Dictionary = play(cfg, args.run_policy, args.waves)
		var death_wave: int = res["death_wave"]
		var data_run: BigNum = res["data"]
		var run_ticks: int = res["ticks"]
		var summary: RunSummary = RunSummary.make(profile.begin_run(), death_wave, data_run, run_ticks)
		summary.mode = args.mode
		summary.kills = res["kills"]
		if not profile.bank_run(summary):
			push_error("JourneySim: bank_run refused run %d" % dep)
		var data_in: BigNum = profile.data
		var bought: int = spender.spend(profile, make_service())
		var earned: float = data_run.to_float()
		var best_after: int = profile.best_wave_of_mode(args.mode, 1)
		streak = JourneyPacing.next_streak(streak, best_after > best)
		cum_data += earned
		cum_ticks += run_ticks
		ticks_total += run_ticks
		(
			out
			. append(
				{
					"dep": dep + 1,
					"seed": seed_used,
					"frame": frame_id,
					"best_before": best,
					"death_wave": death_wave,
					"capped": res["capped"],
					"best_after": best_after,
					"no_best_streak": streak,
					"data_unspent": profile.data.to_float(),
					"data": earned,
					"cum_data": cum_data,
					"spent": data_in.to_float() - profile.data.to_float(),
					"left": profile.data.to_float(),
					"bought": bought,
					"cap": FoundryRules.wave_cap(profile.best_wave_s1()),
					"levels": profile.foundry.duplicate(),
					"minutes_1x": float(run_ticks) / float(Ticks.TICK_RATE) / 60.0,
					"cum_min_1x": float(cum_ticks) / float(Ticks.TICK_RATE) / 60.0,
					"hash": res["hash"],
				}
			)
		)
	return out


## The frame played at `best` wave: the scenario frame once unlocked, else VANGUARD.
func frame_for(best: int) -> String:
	if args.frame == "vanguard":
		return "vanguard"
	var gate: int = _frame_gates.get(args.frame, 0)
	return args.frame if best >= gate else "vanguard"


## The service for one spending phase. The real best-wave level cap (FO-3, `FoundryRules.wave_cap`) applies unless
## `wave_cap` is false (the probe spends on a fresh profile with no best wave).
func make_service(wave_cap: bool = true) -> FoundryService:
	var service: FoundryService = FoundryService.new(overrides.foundry_defs(), SimConfigLoader.load_default(0).upgrades)
	service.wave_cap_enabled = wave_cap
	return service


## SimConfig of one deployment with overrides and the profile's Foundry levels applied.
func make_config(seed_value: int, best: int, levels: Dictionary, frame_id: String) -> SimConfig:
	var cfg: SimConfig = BalanceSetup.make_config(seed_value, 1, best, {}, frame_id, args.mode)
	overrides.apply_to_config(cfg)
	if not levels.is_empty():
		var defs: Array[FoundryDef] = overrides.foundry_defs()
		cfg.foundry_levels = FoundryRules.aligned_levels(cfg.upgrades, defs, levels)
		cfg.foundry_f = FoundryRules.aligned_f(cfg.upgrades, defs)
	return cfg


## Plays one deployment (balance_run's loop: draft pick, bot think every THINK_INTERVAL ticks, step).
## Returns {death_wave, capped, data (BigNum), ticks, kills, hash}.
static func play(cfg: SimConfig, run_policy: String, max_waves: int) -> Dictionary:
	var world: SimWorld = SimWorld.new(cfg)
	var bot: PolicyBot = PolicyBot.new(run_policy)
	var buys: bool = BalanceRunArgs.buys(run_policy)
	while not world.is_over() and world.wave <= max_waves:
		@warning_ignore("return_value_discarded")  # every policy takes the first draft offer (as in balance_run)
		PolicyBot.settle_draft(world)
		if buys and world.tick % PolicyBot.THINK_INTERVAL == 0:
			bot.think(world)
		world.step()
	var survived: bool = not world.is_over()
	return {
		"death_wave": max_waves if survived else world.run.death_wave,
		"capped": survived,
		"data": world.economy.data_run,
		"ticks": world.tick,
		"kills": world.run.kills,
		"hash": world.state_hash(),
	}
