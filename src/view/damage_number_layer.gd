class_name DamageNumberLayer
extends Node2D
## Pooled renderer of the damage numbers (GDD 07 section 5.5, M4-21): ONE canvas item that draws the live slots of
## a DamageNumberModel with `draw_string` (V1 number font, Share Tech Mono) plus a 1 px dark shadow. No per-number
## nodes; the pool is the model's 24 preallocated slots, so nothing grows however many hits arrive.
## Feeds itself from its own EventCursor (read-only): SHOT_FIRED (a = enemy, b = crit) is followed by ENEMY_HIT
## (a = enemy, b = damage), CINDER_HIT (a = damage). Positions are local px (origin Cinder), taken from the
## EnemyRenderer at the moment the event is drained, so a number stays where the hit landed while the enemy moves on.
## Quality: the LOW tier caps live numbers at 12. Reduce motion: no rise and no punch scale-in, only the fade.

const FONT_PATH: String = "res://assets/fonts/ShareTechMono-Regular.ttf"
const SHADOW_PX: float = 1.5
const FADE_START: float = 0.4  ## fraction of the lifetime after which the alpha ramps to 0
const PUNCH_S: float = 2.0 / 60.0  ## the 2-frame punch scale-in
const PUNCH_FROM: float = 0.6
const PUNCH_OVER: float = 1.2
const KIND_COUNT: int = 5
const LIFT_FRACTION: float = 0.9  ## start height above an enemy, in sprite radii

## Optional view settings (quality tier, reduce motion).
var visual: VisualSettings
## Px scale of the text (viewport width / 1080).
var text_scale: float = 1.0
## Cinder's hit radius in px (where the Cinder-damage number appears).
var cinder_radius_px: float = 65.0

var model := DamageNumberModel.new()
var _events := EventCursor.new()
var _font: Font
var _world: SimWorld
var _crit_pending: bool = false
var _was_live: bool = false


func _ready() -> void:
	_font = load(FONT_PATH)


## Starts observing `world` (skips events already pushed, clears live numbers).
func bind(world: SimWorld) -> void:
	_world = world
	_events.sync_to(world.events)
	model.clear()
	_crit_pending = false
	queue_redraw()


## Consumes new events and redraws. `now_s` = monotonic wall seconds, `alpha` = sim interpolation.
func update(enemies: EnemyRenderer, now_s: float, alpha: float) -> void:
	if _world == null:
		return
	if visual != null and visual.quality != null:
		model.live_cap = DamageNumberModel.cap_for_tier(visual.quality.tier)
	model.advance(now_s)
	var store: EnemyStore = _world.enemies
	while _events.poll(_world.events) > 0:
		for i: int in _events.count:
			_on_event(_events.kind_at(i), _events.a_at(i), _events.b_at(i), store, enemies, alpha)
	var live: bool = model.live_count() > 0
	if live or _was_live:
		queue_redraw()
	_was_live = live


func events_lost_total() -> int:
	return _events.lost_total


func _on_event(kind: int, a: int, b: int, store: EnemyStore, enemies: EnemyRenderer, alpha: float) -> void:
	match kind:
		SimEventKind.SHOT_FIRED:
			_crit_pending = b != 0
		SimEventKind.ENEMY_HIT:
			var crit: bool = _crit_pending
			_crit_pending = false
			if a < 0 or a >= store.high_water:
				return
			var pos: Vector2 = enemies.draw_pos(store, a, alpha)
			pos.y -= enemies.sprite_radius_px(store.type_id[a]) * LIFT_FRACTION
			model.hit(store.spawn_id[a], pos.x, pos.y, float(b), store.max_hp[a], crit)
		SimEventKind.CINDER_HIT:
			model.cinder_hit(float(a), 0.0, -cinder_radius_px * 1.1)


func _draw() -> void:
	if _font == null:
		return
	var reduce: bool = visual != null and visual.reduce_motion
	# Grouped by kind, shadow then text: glyphs of one size share a texture, so a kind batches into one draw call
	# (per-number order would flip between size textures and cost about one draw call per number).
	for kind: int in KIND_COUNT:
		for shadow: bool in [true, false]:
			for slot: int in DamageNumberModel.POOL:
				if model.is_live(slot) and model.kind_at(slot) == kind:
					_draw_slot(slot, reduce, shadow)


func _draw_slot(slot: int, reduce: bool, shadow: bool) -> void:
	var kind: int = model.kind_at(slot)
	var age: float = model.age_at(slot)
	var life: float = clampf(age / DamageNumberModel.LIFETIME_S, 0.0, 1.0)
	var alpha: float = 1.0 - clampf((life - FADE_START) / (1.0 - FADE_START), 0.0, 1.0)
	var rise: float = rise_px(life, reduce, text_scale)
	var scale_f: float = 1.0 if reduce else punch_scale(age)
	var text: String = model.text_at(slot)
	var size: int = maxi(roundi(float(DamageNumberModel.size_of(kind)) * scale_f * text_scale), 8)
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var jitter: float = float((slot * 7) % 5 - 2) * 5.0 * text_scale
	# No draw_set_transform: a transform change per number splits the batch; the punch changes the font size.
	var base: Vector2 = model.pos_at(slot) + Vector2(jitter - width * 0.5, -rise)
	if shadow:
		var offset := Vector2(SHADOW_PX, SHADOW_PX) * text_scale
		var shade := Color(0.0, 0.0, 0.0, alpha * 0.8)
		draw_string(_font, base + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shade)
		return
	var col: Color = DamageNumberModel.color_of(kind)
	col.a = alpha
	draw_string(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Rise in px at lifetime fraction `life`; zero under reduce motion.
static func rise_px(life: float, reduce: bool, text_scale_f: float) -> float:
	return 0.0 if reduce else DamageNumberModel.RISE_PX * text_scale_f * ease_out(life)


## Rise easing: fast start, settles (1 - (1 - t)^2).
static func ease_out(t: float) -> float:
	var u: float = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - u * u


## 2-frame punch: starts small, overshoots on the second frame, then 1.0.
static func punch_scale(age: float) -> float:
	if age < PUNCH_S * 0.5:
		return PUNCH_FROM
	if age < PUNCH_S:
		return PUNCH_OVER
	return 1.0
