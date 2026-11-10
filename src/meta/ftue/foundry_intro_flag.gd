class_name FoundryIntroFlag
extends RefCounted
## The "don't show the Foundry explainer again" flag (FO-1). Pure. Lives in the profile `extra` dictionary under
## `KEY` (no schema bump, like `FtueState` and `ModeUnlockFlag`); a missing or non-bool value means "show it", so
## every existing profile sees the dialog once on its next Foundry visit. Independent of the FTUE `skip_all`.

const KEY: String = "foundry_intro_hidden"


static func is_hidden(profile: PlayerProfile) -> bool:
	var raw: Variant = profile.extra.get(KEY, false)
	return raw is bool and raw


## Stores the flag; true when it changed (the caller then saves). `false` removes the key.
static func set_hidden(profile: PlayerProfile, hidden: bool) -> bool:
	if is_hidden(profile) == hidden:
		return false
	if hidden:
		profile.extra[KEY] = true
	else:
		@warning_ignore("return_value_discarded")
		profile.extra.erase(KEY)
	return true
