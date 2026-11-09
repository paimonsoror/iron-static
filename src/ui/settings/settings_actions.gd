class_name SettingsActions
extends RefCounted
## Applies one player edit to the runtime objects and persists it (M3-18). Every change goes: release the session
## override of that control, write the runtime object, capture the persisted meaning into the profile, request
## a save. Reads `Game` directly (menu screens never own state).


static func set_volume(setting: String, v: float) -> void:
	var audio: AudioSettings = Game.audio.settings
	if setting == SettingsModel.KEY_SFX:
		audio.set_sfx_volume(v)
	else:
		audio.set_music_volume(v)
	audio.apply()
	_persist()


static func set_muted(on: bool) -> void:
	Game.settings_applier.release_override(SettingsApplier.KEY_MUTED)
	Game.audio.settings.muted = on
	Game.audio.settings.apply()
	_persist()


static func set_reduce_motion(on: bool) -> void:
	Game.visual.reduce_motion = on
	_persist()


static func set_haptics(on: bool) -> void:
	if Game.haptics != null:
		Game.haptics.enabled = on
	_persist()


## Stores and applies through the M4-24 hook (`VisualSettings.set_accessibility`).
static func set_high_contrast(on: bool) -> void:
	Game.visual.set_accessibility(Game.visual.colorblind, on)
	_persist()


## `index` into `SettingsModel.options(setting)` for the four choice settings.
static func set_choice(setting: String, index: int) -> void:
	var names: Array[String] = SettingsModel.options(setting)
	var opt: String = names[clampi(index, 0, names.size() - 1)]
	match setting:
		SettingsModel.KEY_SHAKE:
			Game.settings_applier.release_override(SettingsApplier.KEY_SHAKE)
			Game.visual.screen_shake = VisualSettings.parse_shake(opt)
		SettingsModel.KEY_SCANLINES:
			Game.visual.scanline_intensity = PlayerSettings.SCANLINE_VALUES[index]
		SettingsModel.KEY_NUMBER_FORMAT:
			NumberFormat.style = index
		SettingsModel.KEY_FPS_CAP:
			Game.settings_applier.release_override(SettingsApplier.KEY_FPS_CAP)
			Game.visual.set_fps_cap(int(opt))
		SettingsModel.KEY_COLORBLIND:
			Game.visual.set_accessibility(opt, Game.visual.high_contrast)
	_persist()


## The settings as the screen shows them now (runtime values, session overrides included for display).
static func current() -> PlayerSettings:
	var s: PlayerSettings = Game.settings_applier.capture(Game.visual, Game.audio.settings)
	var applier: SettingsApplier = Game.settings_applier
	if applier.is_overridden(SettingsApplier.KEY_MUTED):
		s.muted = Game.audio.settings.muted
	if applier.is_overridden(SettingsApplier.KEY_SHAKE):
		s.shake = VisualSettings.SHAKE_NAMES[Game.visual.screen_shake]
	return s


static func _persist() -> void:
	if Game.saves == null:
		return
	Game.profile().settings = Game.settings_applier.capture(Game.visual, Game.audio.settings).to_dict()
	Game.saves.request_save()
