class_name BankedInfo
extends RefCounted
## What banking did for the run that just ended (M3-17), read by `ResultsModel`. Plain data plus one builder that
## reads (never writes) the profile: the overlay shows the numbers, `SaveService.bank_run` already ran.

## False for debug-load and other runs that do not count for progress: best shows `--`, no data line.
var has_bank: bool = false
var previous_best: int = 0
var new_best: int = 0
var data_total: BigNum = BigNum.zero()
var affordable_count: int = 0
var foundry_unlocked: bool = false
## Frame ids unlocked by this very run (CSV order).
var unlocked_frames: Array[String] = []
## True when the profile save after banking failed (progress is only in memory).
var save_failed: bool = false


## Reads `Game` (profile, last bank outcome). `world.config.best_wave_s1` is the best wave at the start of this run.
static func from_game(world: SimWorld) -> BankedInfo:
	var info: BankedInfo = BankedInfo.new()
	if Game.saves == null or Game.controller == null or not Game.controller.banks_rewards():
		return info
	var saves: SaveService = Game.saves
	var profile: PlayerProfile = saves.profile
	info.has_bank = true
	info.previous_best = world.config.best_wave_s1
	info.new_best = maxi(info.previous_best, world.run.death_wave)
	info.data_total = profile.data
	info.foundry_unlocked = MetaUnlocks.foundry_screen_unlocked(profile)
	info.unlocked_frames = saves.last_unlocked_frames.duplicate()
	info.save_failed = not saves.last_bank_saved
	info.affordable_count = affordable_foundry(profile, world.config.upgrades)
	return info


## Foundry rows whose next level the profile can pay now (the FOUNDRY button badge).
static func affordable_foundry(profile: PlayerProfile, upgrades: Array[RunUpgradeDef]) -> int:
	var svc := FoundryService.new(SimConfigLoader.load_foundry_defs(), upgrades)
	return svc.affordable_count(profile)
