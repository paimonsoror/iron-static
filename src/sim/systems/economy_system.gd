class_name EconomySystem
extends RefCounted
## Scrap and run-data bookkeeping (GDD 02 sections 7.3 and 9, 04 section 2). Kills add floats to
## `world.tick_scrap` / `world.tick_data`; `apply_tick` (stage 5b) converts them to BigNum once per tick.
## **(impl)** scrap is floored when added: the whole part goes to `scrap`, the remainder is carried in
## `scrap_frac`, so the balance plus the carry always equals the float shadow total (no rounding loss).

const REINVEST_CAP_FRAC: float = 0.5  ## payout cap per wave = 0.5 x that wave's kill scrap (GDD 02 section 7.3)


## Stage 5b: converts the tick accumulators into the BigNum balances. No-op when both are zero.
static func apply_tick(world: SimWorld) -> void:
	var ts: float = world.tick_scrap
	var td: float = world.tick_data
	if ts <= 0.0 and td <= 0.0:
		return
	var eco: EconomyState = world.economy
	eco.conversions += 1
	if ts > 0.0:
		eco.wave_kill_scrap += ts
		eco.scrap_frac += ts
		var whole: float = floorf(eco.scrap_frac)
		if whole > 0.0:
			eco.scrap = eco.scrap.add(BigNum.from_float(whole))
			eco.scrap_frac -= whole
	if td > 0.0:
		eco.data_run = eco.data_run.add(BigNum.from_float(td))
	world.tick_scrap = 0.0
	world.tick_data = 0.0


## Wave-end steps 1-2. Step 1 (`scrap_per_wave`, `data_per_wave`) is a hook, not in the MVP.
## Step 2: interest = min(floor(scrap * reinvest), floor(0.5 * wave_kill_scrap)) **(impl: cap floored)**.
static func wave_end(world: SimWorld) -> void:
	var eco: EconomyState = world.economy
	var rate: float = world.stats.reinvest
	if rate > 0.0 and not eco.scrap.is_zero():
		var raw: BigNum = eco.scrap.mul_float(rate).floor_value()
		var cap: BigNum = BigNum.from_float(floorf(REINVEST_CAP_FRAC * eco.wave_kill_scrap))
		var interest: BigNum = raw.min(cap)
		if not interest.is_zero():
			eco.scrap = eco.scrap.add(interest)
	eco.wave_kill_scrap = 0.0
