class_name AudioHooks
extends RefCounted
## One-line UI sound hooks (A1-06): `AudioHooks.tap()` etc. route to `Game.audio`, or to `override` when a test
## injects a spy. Presentation only: never touches the sim.

## Test seam: when set, every hook goes here instead of `Game.audio`.
static var override: AudioDirector = null


static func director() -> AudioDirector:
	if override != null:
		return override
	return Game.audio


static func tap() -> void:
	@warning_ignore("return_value_discarded")
	director().play_sfx("sfx_ui_tap")


static func deny() -> void:
	@warning_ignore("return_value_discarded")
	director().play_sfx("sfx_ui_deny")


## One step of a hold-to-buy (also a single tap buy): `sfx_upgrade_buy` with the streak's pitch.
static func buy_step() -> void:
	@warning_ignore("return_value_discarded")
	director().play_buy_step()


static func buy_end() -> void:
	director().end_buy_hold()


static func pause_audio() -> void:
	director().pause_all()


static func resume_audio() -> void:
	director().resume_all()
