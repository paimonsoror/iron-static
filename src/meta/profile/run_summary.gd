class_name RunSummary
extends RefCounted
## Plain data of a finished run, handed to `PlayerProfile.bank_run`. Built by the run flow (M3-12).

var run_id: int = 0
var sector: int = 1
var death_wave: int = 0
var data_run: BigNum = BigNum.zero()
var kills: int = 0
var ticks: int = 0
## False for debug-load runs: they bank nothing and never touch best wave.
var counts_for_progress: bool = true


static func make(
	id: int, wave: int, data_amount: BigNum, run_ticks: int = 0, run_kills: int = 0, sector_id: int = 1
) -> RunSummary:
	var s: RunSummary = RunSummary.new()
	s.run_id = id
	s.death_wave = wave
	s.data_run = data_amount
	s.ticks = run_ticks
	s.kills = run_kills
	s.sector = sector_id
	return s
