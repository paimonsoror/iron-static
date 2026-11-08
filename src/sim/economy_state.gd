class_name EconomyState
extends RefCounted
## Currency balances of one run (M2-05). `scrap` and `data_run` are BigNum and change only at economy events
## (once per tick at most). `wave_kill_scrap` and `scrap_frac` are float shadows that never hit BigNum.

var scrap: BigNum = BigNum.zero()
var data_run: BigNum = BigNum.zero()
## Kill scrap earned in the current wave (float, unfloored); caps the wave-end `reinvest` payout.
var wave_kill_scrap: float = 0.0
## Fractional kill scrap not yet added to `scrap` (the floor rule carries the remainder, nothing is lost).
var scrap_frac: float = 0.0
## Ticks in which the accumulators were converted to BigNum (at most once per tick). Not hashed; for tests.
var conversions: int = 0
