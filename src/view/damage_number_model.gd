class_name DamageNumberModel
extends RefCounted
## Damage and info numbers, pure logic (GDD 07 section 5.5, M4-20). No nodes, no engine time: every call takes
## `now` (seconds, any monotonic clock), so tests drive it directly. Fed read-only from sim events by
## DamageNumberLayer (SHOT_FIRED crit flag + ENEMY_HIT damage + the enemy store; CINDER_HIT).
##
## Show rules: a hit on an enemy shows when it is a crit or overcrit, or when it is >= 1% of the target's max HP.
## Hits on the same target within 0.2 s of its last hit are summed into one live number (a sub-threshold hit may
## join an existing number, but never makes one). At most 6 new enemy-hit numbers per 0.5 s window (the 6 best:
## crits above normals, then by amount; a better hit replaces the weakest of the window when it is full). At most
## `live_cap` (24, LOW tier 12) numbers live at once (the oldest is evicted). Lifetime 0.6 s, rise 30 px, fade,
## 2-frame punch scale-in (the layer renders those). Cinder damage and heals are not enemy hits: they skip the
## per-window budget and the merge, but count toward the live cap.
## Positions are view px (the layer takes them from the enemy renderer). The pool is preallocated; nothing grows.

enum Kind { NORMAL, CRIT, OVERCRIT, CINDER, HEAL }

const POOL: int = 24
const LIFETIME_S: float = 0.6
const RISE_PX: float = 30.0
const MERGE_S: float = 0.2
const WINDOW_S: float = 0.5
const WINDOW_MAX: int = 6
const MIN_FRACTION: float = 0.01
## Font size per kind in px at the 1080 px wide base viewport (GDD 07 5.5).
const SIZES: Array[int] = [18, 26, 34, 22, 20]

## Maximum live numbers (the layer lowers it on the LOW quality tier).
var live_cap: int = POOL
## Hits shown / dropped by the rules since creation (tests and the debug overlay).
var shown_total: int = 0
var dropped_total: int = 0

var _live := PackedByteArray()
var _kind := PackedByteArray()
var _target := PackedInt32Array()
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _amount := PackedFloat64Array()
var _born := PackedFloat64Array()
var _last_hit := PackedFloat64Array()
var _texts: Array[String] = []
var _live_count: int = 0
var _now: float = 0.0
var _window_start: float = -1.0e9
var _window_count: int = 0


func _init() -> void:
	var ok: bool = _live.resize(POOL) == OK
	ok = ok and _kind.resize(POOL) == OK
	ok = ok and _target.resize(POOL) == OK
	ok = ok and _x.resize(POOL) == OK
	ok = ok and _y.resize(POOL) == OK
	ok = ok and _amount.resize(POOL) == OK
	ok = ok and _born.resize(POOL) == OK
	ok = ok and _last_hit.resize(POOL) == OK
	if not ok:
		push_error("DamageNumberModel: resize failed")
	_texts.resize(POOL)
	for i: int in POOL:
		_texts[i] = ""


## Color of a kind (Palette: TEXT, AMBER_GLOW, EMITTER white, CRITICAL, TEAL).
static func color_of(kind: int) -> Color:
	match kind:
		Kind.CRIT:
			return Palette.AMBER_GLOW
		Kind.OVERCRIT:
			return Palette.EMITTER
		Kind.CINDER:
			return Palette.CRITICAL
		Kind.HEAL:
			return Palette.TEAL
	return Palette.TEXT


static func size_of(kind: int) -> int:
	return SIZES[clampi(kind, 0, SIZES.size() - 1)]


## Display text: NumberFormat short form; crit in [ ], heal with a leading +.
static func format_text(kind: int, amount: float) -> String:
	var s: String = NumberFormat.format(BigNum.from_float(amount))
	match kind:
		Kind.CRIT:
			return "[" + s + "]"
		Kind.HEAL:
			return "+" + s
	return s


## Live cap for a quality tier (LOW halves it).
static func cap_for_tier(tier: int) -> int:
	return POOL >> 1 if tier == VisualQuality.Tier.LOW else POOL


## Advances the clock, expires numbers older than the lifetime and trims to `live_cap` (oldest first).
func advance(now: float) -> void:
	_now = now
	for i: int in POOL:
		if _live[i] != 0 and now - _born[i] >= LIFETIME_S:
			_live[i] = 0
			_live_count -= 1
	while _live_count > live_cap:
		if _evict_oldest() < 0:
			break


## An enemy hit. `target` identifies the enemy (use its spawn_id: slots are reused); `max_hp` is its max HP
## (<= 0 = unknown, the percent rule then never passes).
## Returns true when the hit is now part of a live number.
func hit(target: int, x: float, y: float, amount: float, max_hp: float, crit: bool, overcrit: bool = false) -> bool:
	var kind: int = _hit_kind(crit, overcrit)
	var m: int = _find_merge(target)
	if m >= 0:
		_amount[m] += amount
		if kind > _kind[m]:
			_kind[m] = kind
		_last_hit[m] = _now
		_texts[m] = format_text(_kind[m], _amount[m])
		return true
	var qualifies: bool = crit or overcrit or (max_hp > 0.0 and amount >= max_hp * MIN_FRACTION)
	if not qualifies:
		dropped_total += 1
		return false
	if _now - _window_start >= WINDOW_S:
		_window_start = _now
		_window_count = 0
	var slot: int = -1
	if _window_count < WINDOW_MAX:
		slot = _free_slot()
		_window_count += 1
	else:
		slot = _weakest_in_window()
		if slot < 0 or not _beats(kind, amount, _kind[slot], _amount[slot]):
			dropped_total += 1
			return false
	_put(slot, kind, target, x, y, amount)
	return true


## Damage Cinder took (shown at Cinder's position: x, y meters, normally 0, 0).
func cinder_hit(amount: float, x: float = 0.0, y: float = 0.0) -> void:
	_put(_free_slot(), Kind.CINDER, -1, x, y, amount)


## A heal at x, y meters.
func heal(amount: float, x: float = 0.0, y: float = 0.0) -> void:
	_put(_free_slot(), Kind.HEAL, -1, x, y, amount)


func live_count() -> int:
	return _live_count


func is_live(slot: int) -> bool:
	return _live[slot] != 0


func kind_at(slot: int) -> int:
	return _kind[slot]


func text_at(slot: int) -> String:
	return _texts[slot]


func amount_at(slot: int) -> float:
	return _amount[slot]


func pos_at(slot: int) -> Vector2:
	return Vector2(_x[slot], _y[slot])


func age_at(slot: int) -> float:
	return _now - _born[slot]


func target_at(slot: int) -> int:
	return _target[slot]


## Removes everything (new run).
func clear() -> void:
	for i: int in POOL:
		_live[i] = 0
	_live_count = 0
	_window_start = -1.0e9
	_window_count = 0


static func _hit_kind(crit: bool, overcrit: bool) -> int:
	if overcrit:
		return Kind.OVERCRIT
	return Kind.CRIT if crit else Kind.NORMAL


func _find_merge(target: int) -> int:
	for i: int in POOL:
		if _live[i] != 0 and _target[i] == target and _now - _last_hit[i] <= MERGE_S:
			return i
	return -1


## A free slot, evicting the oldest live number when the live cap is reached.
func _free_slot() -> int:
	if _live_count >= live_cap:
		var evicted: int = _evict_oldest()
		if evicted >= 0:
			return evicted
	for i: int in POOL:
		if _live[i] == 0:
			return i
	return -1


## Frees the oldest live slot and returns it; -1 when none is live.
func _evict_oldest() -> int:
	var oldest: int = -1
	for i: int in POOL:
		if _live[i] != 0 and (oldest < 0 or _born[i] < _born[oldest]):
			oldest = i
	if oldest >= 0:
		_live[oldest] = 0
		_live_count -= 1
	return oldest


## The lowest-ranked live enemy-hit number born in the current window; -1 when none.
func _weakest_in_window() -> int:
	var best: int = -1
	for i: int in POOL:
		if _live[i] == 0 or _born[i] < _window_start or _target[i] < 0:
			continue
		if best < 0 or _beats(_kind[best], _amount[best], _kind[i], _amount[i]):
			best = i
	return best


## True when (kind_a, amount_a) outranks (kind_b, amount_b): crits above normals, then by amount.
static func _beats(kind_a: int, amount_a: float, kind_b: int, amount_b: float) -> bool:
	if kind_a != kind_b:
		return kind_a > kind_b
	return amount_a > amount_b


func _put(slot: int, kind: int, target: int, x: float, y: float, amount: float) -> void:
	if slot < 0:
		return
	if _live[slot] == 0:
		_live_count += 1
	_live[slot] = 1
	_kind[slot] = kind
	_target[slot] = target
	_x[slot] = x
	_y[slot] = y
	_amount[slot] = amount
	_born[slot] = _now
	_last_hit[slot] = _now
	_texts[slot] = format_text(kind, amount)
	shown_total += 1
