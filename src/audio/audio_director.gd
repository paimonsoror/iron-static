class_name AudioDirector
extends Node
## Plays sound effects from the slot table and owns the MusicDirector. Owned by the `Game` autoload (`Game.audio`).
## Per id: a pool of `voice_cap` players (each with its own pitch) plus a cooldown, both decided by the pure
## VoiceGate. Pitch jitter uses a presentation-only RandomNumberGenerator: NEVER the sim Rng (determinism).
## Lifecycle: the main scene calls `pause_all()` / `resume_all()` (app pause); nothing here hooks the lifecycle.

const JITTER_SEED: int = 0x5EED

var settings: AudioSettings = AudioSettings.new()
var music: MusicDirector = null
var buy_ramp: BuyPitchRamp = BuyPitchRamp.new()

## Debug `--mute`: no sound and no music at all (benches, captures); see AudioSettings.is_mute_arg.
var disabled: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pools: Dictionary = {}
var _paused: bool = false


func setup() -> void:
	_rng.seed = JITTER_SEED
	settings.apply()
	music = MusicDirector.new()
	add_child(music)


## Drops the cached streams on shutdown so no audio resource outlives the engine (the CI exit-leak check).
func _exit_tree() -> void:
	_pools.clear()
	AudioSlots.release_streams()


## Plays sound `sfx_id`. `pitch_jitter` < 0 uses the slot's `pitch_var`; `semitones` shifts the pitch (buy ramp).
## Returns false when the sound was skipped (unknown id, missing file, cooldown, all voices busy, paused).
func play_sfx(sfx_id: String, pitch_jitter: float = -1.0, semitones: float = 0.0) -> bool:
	if _paused or disabled:
		return false
	var slot: AudioSlot = AudioSlots.slot(sfx_id)
	if not slot.valid:
		return false
	var stream: AudioStream = AudioSlots.stream(sfx_id)
	if stream == null:
		return false
	var pool: SfxPool = _pool_for(slot)
	var jitter: float = slot.pitch_var if pitch_jitter < 0.0 else pitch_jitter
	var pitch: float = BuyPitchRamp.pitch_scale(semitones) * (1.0 + jitter * _rng.randf_range(-1.0, 1.0))
	var length_ms: int = int(stream.get_length() * 1000.0 / pitch)
	var voice: int = pool.gate.acquire(Time.get_ticks_msec(), length_ms)
	if voice < 0:
		return false
	var player: AudioStreamPlayer = pool.players[voice]
	player.pitch_scale = pitch
	player.volume_db = slot.volume_db
	player.stream = stream
	player.play()
	return true


## One step of a press-and-hold repeat buy: `sfx_upgrade_buy` with the next pitch of the streak.
func play_buy_step() -> bool:
	return play_sfx("sfx_upgrade_buy", -1.0, buy_ramp.next_semitones(Time.get_ticks_msec()))


## The buy button was released: the next buy starts again at the base pitch.
func end_buy_hold() -> void:
	buy_ramp.reset()


## Loads the music layers on first use and starts them (no-op when already started or `disabled`).
func start_music() -> void:
	if music == null or disabled:
		return
	music.ensure_setup()
	music.start()


## Feeds the adaptive music model (view-side snapshot of the run).
func set_music_state(state: MusicState) -> void:
	if music != null:
		music.set_state(state)


## App pause: freezes every voice and the music.
func pause_all() -> void:
	_paused = true
	for pool: SfxPool in _pools.values():
		pool.set_paused(true)
	if music != null:
		music.pause()


func resume_all() -> void:
	_paused = false
	for pool: SfxPool in _pools.values():
		pool.set_paused(false)
	if music != null:
		music.resume()


func is_paused() -> bool:
	return _paused


func _pool_for(slot: AudioSlot) -> SfxPool:
	if _pools.has(slot.id):
		var existing: SfxPool = _pools[slot.id]
		return existing
	var pool: SfxPool = SfxPool.new()
	pool.gate = VoiceGate.new(slot.voice_cap, slot.cooldown_ms)
	for i: int in range(slot.voice_cap):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = slot.bus
		add_child(p)
		pool.players.append(p)
	_pools[slot.id] = pool
	return pool
