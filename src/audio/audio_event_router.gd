class_name AudioEventRouter
extends RefCounted
## Sim events -> sounds and adaptive music (A1-05, A1-07). Presentation only: reads `world.events` through its own
## EventCursor (like the view), never writes sim state and never uses the sim Rng.
## Mapping: SHOT_FIRED -> sfx_laser_shot; ENEMY_HIT -> sfx_hit_metal, or sfx_crit when the paired SHOT_FIRED (the
## sim pushes SHOT_FIRED(a = enemy, b = crit) immediately before ENEMY_HIT(a = enemy)) was a crit; ENEMY_KILLED ->
## sfx_enemy_death_small (skitter, dart) or sfx_enemy_death_heavy (walker, lancer, bosses); CINDER_HIT ->
## sfx_player_hit; WAVE_STARTED -> sfx_wave_start; BOSS_SPAWNED -> sfx_boss_warn; RUN_ENDED -> sfx_death.
## A1-08 additions: a boss ENEMY_KILLED -> sfx_boss_death (instead of the heavy death); BAND_CHANGED to a worse band ->
## sfx_skin_burn; while integrity band 3 lasts, one sfx_integrity_warn per beat of HeartbeatModel (same sim clock as the
## overlay and Cinder's core); UPGRADE_BOUGHT reaching a multiple of 25 -> sfx_milestone_x15 (the gold ring level);
## play_results_tally() from the results screen. Not wired (no sim event yet): sfx_overcrit and the feature sounds.
## Load control: at most CAP_PER_FRAME starts per id per update, at most MAX_BATCHES * 64 events read per update;
## a reader further behind skips the oldest events (no backlog; voice caps and cooldowns do the rest).
## Music: `MusicState` from the world (wave, a boss alive, integrity band) every update, pushed only on change.

const SFX_SHOT: String = "sfx_laser_shot"
const SFX_HIT: String = "sfx_hit_metal"
const SFX_CRIT: String = "sfx_crit"
const SFX_DEATH_SMALL: String = "sfx_enemy_death_small"
const SFX_DEATH_HEAVY: String = "sfx_enemy_death_heavy"
const SFX_PLAYER_HIT: String = "sfx_player_hit"
const SFX_WAVE: String = "sfx_wave_start"
const SFX_BOSS: String = "sfx_boss_warn"
const SFX_RUN_END: String = "sfx_death"
const SFX_BOSS_DEATH: String = "sfx_boss_death"
const SFX_SKIN_BURN: String = "sfx_skin_burn"
const SFX_HEARTBEAT: String = "sfx_integrity_warn"
const SFX_MILESTONE: String = "sfx_milestone_x15"
const SFX_TALLY: String = "sfx_results_tally"
## Pitch spread of the laser tick (fraction; the slot default is used for the other sounds).
const SHOT_JITTER: float = 0.04
const CAP_PER_FRAME: int = 3
const MAX_BATCHES: int = 8
const NO_BEAT: int = -1000000
const HEAVY_IDS: PackedStringArray = ["walker", "lancer"]

## True on the results screen and any menu: the music drops to its menu mix.
var in_menu: bool = false:
	set(value):
		in_menu = value
		_music_dirty = true

var _director: AudioDirector = null
var _world: SimWorld = null
var _events: EventCursor = EventCursor.new()
var _heavy: PackedByteArray = PackedByteArray()
var _boss: PackedByteArray = PackedByteArray()
var _budget: Dictionary[String, int] = {}
var _crit_enemy: int = -1
var _music_dirty: bool = true
var _last_wave: int = -1
var _last_boss: bool = false
var _last_band: int = -1
## Index of the last heartbeat that sounded (NO_BEAT = none yet since entering band 3 or after a skip).
var _last_beat: int = NO_BEAT


func _init(director: AudioDirector = null) -> void:
	_director = director


## Starts observing `world` (events already pushed are skipped), sets the in-run music state and starts the music.
func bind(world: SimWorld) -> void:
	_world = world
	_events.sync_to(world.events)
	_crit_enemy = -1
	_heavy = heavy_table(world.config.enemies)
	_boss = boss_table(world.config.enemies)
	_last_beat = NO_BEAT
	in_menu = false
	_last_wave = -1
	_feed_music()
	if _director != null:
		_director.start_music()


## Events lost because the ring wrapped past this reader (tests, debug).
func events_lost_total() -> int:
	return _events.lost_total


## Drains new events into sounds and refreshes the music state. Call once per rendered frame.
func update() -> void:
	if _world == null or _director == null:
		return
	_budget.clear()
	# Too far behind (high speed, a hitch): skip the oldest events, keep the newest window (death, wave start...).
	var window: int = MAX_BATCHES * EventCursor.BATCH
	if _world.events.total_pushed - _events.cursor > window:
		_events.cursor = _world.events.total_pushed - window
	while _events.poll(_world.events) > 0:
		for i: int in _events.count:
			_route(_events.kind_at(i), _events.a_at(i), _events.b_at(i))
	_heartbeat()
	_feed_music()


## Skips pending events without sound (fast-forward, hidden frames).
func skip() -> void:
	if _world != null:
		_events.sync_to(_world.events)
		_crit_enemy = -1
		_last_beat = NO_BEAT


## The tally ticks of the results screen (call when it is shown; not in reduce-motion, where the numbers do not roll).
func play_results_tally(animated: bool = true) -> void:
	if _director != null and animated:
		_play(SFX_TALLY)


## Per enemy type index: 1 = heavy death sound.
static func heavy_table(defs: Array[EnemyDef]) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	for def: EnemyDef in defs:
		@warning_ignore("return_value_discarded")
		out.append(1 if is_heavy(def.id) else 0)
	return out


## Per enemy type index: 1 = boss (plays the boss death instead of the heavy one).
static func boss_table(defs: Array[EnemyDef]) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	for def: EnemyDef in defs:
		@warning_ignore("return_value_discarded")
		out.append(1 if def.id.begins_with("boss") else 0)
	return out


static func is_heavy(enemy_id: String) -> bool:
	return HEAVY_IDS.has(enemy_id) or enemy_id.begins_with("boss")


## The music inputs of `world` (pure; wave, a boss alive, integrity band).
static func music_state(world: SimWorld, menu: bool) -> MusicState:
	return MusicState.make(world.wave, world.alive_boss_count() > 0, world.cinder.band, menu)


func _route(kind: int, a: int, b: int) -> void:
	match kind:
		SimEventKind.SHOT_FIRED:
			_crit_enemy = a if b != 0 else -1
			_play(SFX_SHOT, SHOT_JITTER)
		SimEventKind.ENEMY_HIT:
			var crit: bool = a == _crit_enemy
			_crit_enemy = -1
			_play(SFX_CRIT if crit else SFX_HIT)
		SimEventKind.ENEMY_KILLED:
			var heavy: bool = b >= 0 and b < _heavy.size() and _heavy[b] != 0
			var boss: bool = b >= 0 and b < _boss.size() and _boss[b] != 0
			if boss:
				_play(SFX_BOSS_DEATH)
			else:
				_play(SFX_DEATH_HEAVY if heavy else SFX_DEATH_SMALL)
		SimEventKind.CINDER_HIT:
			_play(SFX_PLAYER_HIT)
		SimEventKind.WAVE_STARTED:
			_play(SFX_WAVE)
		SimEventKind.BOSS_SPAWNED:
			_play(SFX_BOSS)
		SimEventKind.RUN_ENDED:
			_play(SFX_RUN_END)
		SimEventKind.BAND_CHANGED:
			if b > a:
				_play(SFX_SKIN_BURN)
		SimEventKind.UPGRADE_BOUGHT:
			if b > 0 and b % StatResolver.MILESTONE_STEP == 0:
				_play(SFX_MILESTONE)


## One sfx_integrity_warn per heartbeat while band 3 lasts. Beat index = floor(sim_time * HZ - FIRST_PHASE), so a sound
## starts at the first peak of the overlay's beat; a paused or slowed sim (tick not advancing) makes no sound, and the
## first beat after entering band 3 is the next one (no double trigger with the band-change sound).
func _heartbeat() -> void:
	if in_menu or _world.cinder.band < 3:
		_last_beat = NO_BEAT
		return
	var clock_s: float = float(_world.tick) * SimWorld.DT
	var beat: int = floori(clock_s * HeartbeatModel.HZ - HeartbeatModel.FIRST_PHASE)
	if _last_beat == NO_BEAT:
		_last_beat = beat
	elif beat != _last_beat:
		_last_beat = beat
		_play(SFX_HEARTBEAT)


func _play(sfx_id: String, jitter: float = -1.0) -> void:
	var used: int = _budget.get(sfx_id, 0)
	if used >= CAP_PER_FRAME:
		return
	_budget[sfx_id] = used + 1
	@warning_ignore("return_value_discarded")
	_director.play_sfx(sfx_id, jitter)


func _feed_music() -> void:
	var boss: bool = _world.alive_boss_count() > 0
	var band: int = _world.cinder.band
	if not _music_dirty and _world.wave == _last_wave and boss == _last_boss and band == _last_band:
		return
	_music_dirty = false
	_last_wave = _world.wave
	_last_boss = boss
	_last_band = band
	if _director != null:
		_director.set_music_state(MusicState.make(_last_wave, boss, band, in_menu))
