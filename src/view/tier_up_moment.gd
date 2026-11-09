class_name TierUpMoment
extends RefCounted
## One announced tier-up (VT-5, docs/design/12 s5): which upgrade row reached which tier. Plain value; the banner and
## the flash read it. `flat` is set by the director when the banner starts (reduce motion or LOW quality: fade only).

var row: int = -1
var stat: String = ""
var tier: int = 0
var level: int = 0
var banner_key: String = ""
var flat: bool = false


## `LASER MK II`: the row name (`vt.banner.*`) and the mark of the tier (`vt.mark.N`).
func title() -> String:
	return "%s %s" % [Strings.get_text(banner_key), Strings.get_text("vt.mark.%d" % tier)]


## `BEAM OUTPUT TIER UP` (`vt.sub.*`, named after the banner key).
func sub() -> String:
	return Strings.get_text(banner_key.replace("vt.banner.", "vt.sub."))
