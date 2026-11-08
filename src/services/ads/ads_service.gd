class_name AdsService
extends RefCounted
## Interface for rewarded ads + UMP consent. Rewarded only, never interstitials, never mid-run
## (GDD 06 section 2). Implementations: `AdsStub` (desktop/headless) and `AdsAndroid` (Poing AdMob).

## SDK initialised (consent resolved first).
@warning_ignore("unused_signal")
signal initialized
## A rewarded ad for `placement` is loaded and can be shown.
@warning_ignore("unused_signal")
signal rewarded_ready(placement: String)
## The user earned the reward for `placement`.
@warning_ignore("unused_signal")
signal reward_earned(placement: String)
## Load/show/init failure; `code` is the AdMob error code (or -1 for local failures).
@warning_ignore("unused_signal")
signal failed(code: int)


func is_available() -> bool:
	return false


func backend_name() -> String:
	return "none"


## Resolve consent (no-op outside the EEA/UK), then initialise the ads SDK.
func initialize() -> void:
	pass


func load_rewarded(_placement: String) -> void:
	pass


func show_rewarded(_placement: String) -> void:
	pass
