class_name ResultsAnim
extends RefCounted
## Pure timing of the results screen entry (V1-18, art bible 7.6): the header glitches in for HEADER_S, stat line k
## reveals at `0.3 + 0.12 k`, number tallies run TALLY_S and end on the exact final value. Reduce motion: everything
## is final at t = 0. The buttons are tappable from BUTTONS_ENABLED_S (the M2 overlay had no delay: 0 s).

const HEADER_S: float = 0.3
const STEP_S: float = 0.12
const TALLY_S: float = 0.6
const FADE_S: float = 0.12
const SLIDE_PX: float = 36.0
const BUTTONS_ENABLED_S: float = 0.0
const PULSE_PERIOD_S: float = 1.6
const PULSE_AMOUNT: float = 0.18


## Time at which stat line `k` (0-based) starts to appear.
static func reveal_time(k: int) -> float:
	return HEADER_S + STEP_S * float(k)


## 0..1 opacity of line `k` at `t` (instant when `reduced`).
static func line_alpha(k: int, t: float, reduced: bool) -> float:
	if reduced:
		return 1.0
	return clampf((t - reveal_time(k)) / FADE_S, 0.0, 1.0)


## Displayed tally of `final_value` for the line starting at `start_s`; exactly `final_value` once TALLY_S has passed.
static func tally(final_value: float, t: float, start_s: float, reduced: bool) -> float:
	if reduced or t >= start_s + TALLY_S:
		return final_value
	var u: float = clampf((t - start_s) / TALLY_S, 0.0, 1.0)
	return final_value * NumberRoll.ease_out(u)


## Time after which nothing moves any more (last of `lines` lines done, tally included).
static func total_s(lines: int, reduced: bool) -> float:
	if reduced:
		return 0.0
	return reveal_time(maxi(lines - 1, 0)) + TALLY_S


## Horizontal jitter (px) of the header during the glitch-in, 0 once done.
static func header_jitter(t: float, reduced: bool) -> float:
	if reduced or t >= HEADER_S:
		return 0.0
	var step: int = floori(t / 0.05)
	return (14.0 if step % 2 == 0 else -9.0) * (1.0 - t / HEADER_S)


## Header and card opacity during the glitch-in.
static func header_alpha(t: float, reduced: bool) -> float:
	if reduced:
		return 1.0
	return clampf(t / (HEADER_S * 0.5), 0.0, 1.0)


## Card slide offset (px, positive = lower) at `t`.
static func slide_offset(t: float, reduced: bool) -> float:
	if reduced:
		return 0.0
	return SLIDE_PX * (1.0 - NumberRoll.ease_out(t / HEADER_S))


## Brightness boost 0..PULSE_AMOUNT of the REDEPLOY plate (0 under reduce motion).
static func pulse(t: float, reduced: bool) -> float:
	if reduced:
		return 0.0
	return PULSE_AMOUNT * 0.5 * (1.0 - cos(TAU * t / PULSE_PERIOD_S))


## Accent color of a killer enemy id (art bible enemy accents); unknown ids fall back to skitter red.
static func accent_for(enemy_id: String) -> Color:
	if enemy_id.begins_with("boss"):
		return Palette.ACCENT_BOSS
	match enemy_id:
		"dart":
			return Palette.ACCENT_DART
		"walker":
			return Palette.ACCENT_WALKER
		"lancer":
			return Palette.ACCENT_LANCER
		_:
			return Palette.ACCENT_SKITTER
