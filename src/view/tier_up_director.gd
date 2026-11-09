class_name TierUpDirector
extends RefCounted
## Turns upgrade level changes into tier-up moments (VT-5, docs/design/12 s5). View side only: it reads
## `world.run_levels` once per rendered frame, never writes the sim and adds no sim event.
## Rules: a row announces only when its displayed tier rises to a tier that has a banner (MK II to IV; plating from
## PLATED II); a multi-buy that crosses several tiers announces only the final one, and when several rows rise in
## one frame only the highest tier is shown. `bind` and `sync` adopt the current levels silently (run start, resume
## from a snapshot, replay or debug fast-forward), so owned levels never replay. The flash plays at once for every
## moment; the banner is one at a time: a moment arriving while a banner is up waits in a single slot, a newer one
## replaces the waiting one, and a waiting moment older than COALESCE_S is dropped.
## Usage: `update(world, now_s, flat)` every frame, then `take_flash()` and `take_banner()`.

const SLIDE_S: float = 0.15
const HOLD_S: float = 1.3
const HOLD_MK2_S: float = 1.0
const FADE_S: float = 0.3
const COALESCE_S: float = 2.0

var _tracker: TierRowTracker = TierRowTracker.new()
var _flash: TierUpMoment = null
var _banner: TierUpMoment = null
var _waiting: TierUpMoment = null
var _waiting_since_s: float = 0.0
var _busy_until_s: float = -1.0


## Hold time of the banner of `tier` (MK II is shorter).
static func hold_s(tier: int) -> float:
	return HOLD_MK2_S if tier <= 2 else HOLD_S


## On-screen time of one banner: slide (not when `flat`), hold, fade.
static func banner_total_s(tier: int, flat: bool) -> float:
	return (0.0 if flat else SLIDE_S) + hold_s(tier) + FADE_S


func bind(world: SimWorld) -> void:
	_tracker.bind(world)
	_clear()


## Adopts the current levels without announcing and drops anything waiting.
func sync(world: SimWorld) -> void:
	_tracker.sync(world)
	_clear()


func update(world: SimWorld, now_s: float, flat: bool) -> void:
	var best: TierUpMoment = null
	for row: int in mini(world.run_levels.size(), _tracker.row_count()):
		var level: int = world.run_levels[row]
		var tier: int = _tracker.observe(row, level)
		if tier > 0 and (best == null or tier > best.tier):
			best = _moment(row, tier, level)
	if best != null:
		_flash = best
		_waiting = best  # replaces whatever was waiting
		_waiting_since_s = now_s
	if _waiting != null and now_s >= _busy_until_s:
		if now_s - _waiting_since_s <= COALESCE_S:
			_waiting.flat = flat
			_banner = _waiting
			_busy_until_s = now_s + banner_total_s(_waiting.tier, flat)
		_waiting = null


## The moment whose flash starts now (once), or null.
func take_flash() -> TierUpMoment:
	var m: TierUpMoment = _flash
	_flash = null
	return m


## The moment whose banner starts now (once), or null.
func take_banner() -> TierUpMoment:
	var m: TierUpMoment = _banner
	_banner = null
	return m


## True while a banner is up or a moment waits for one.
func is_busy(now_s: float) -> bool:
	return _waiting != null or now_s < _busy_until_s


func _clear() -> void:
	_flash = null
	_banner = null
	_waiting = null
	_busy_until_s = -1.0


func _moment(row: int, tier: int, level: int) -> TierUpMoment:
	var m: TierUpMoment = TierUpMoment.new()
	m.row = row
	m.stat = _tracker.stat_at(row)
	m.tier = tier
	m.level = level
	m.banner_key = _tracker.tier_model().banner_key(m.stat, tier)
	return m
