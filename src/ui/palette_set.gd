class_name PaletteSet
extends RefCounted
## One accessibility palette (M4-24): the gameplay colors of a colorblind mode plus the shader multipliers that
## remap the baked enemy art. Built once per mode from `assets/art/palettes.csv` by `Palette.for_mode`; read-only after.

## Highest per-channel gain: the baked art is dark in the weak channels, so a bigger gain only clips.
const MAX_GAIN: float = 4.0

var mode: String = "off"
var amber: Color = Palette.AMBER
var teal: Color = Palette.TEAL
var hostile: Color = Palette.ENEMY_OUTLINE
var fire: Color = Palette.ENEMY_FIRE
var critical: Color = Palette.CRITICAL
## Per-channel multiplier the enemy shader applies to the baked sprite (hostile / default hostile); (1,1,1) = unchanged.
var tint_hostile: Vector3 = Vector3.ONE
## Same for the bolt sprite (fire / default fire).
var tint_fire: Vector3 = Vector3.ONE
## High-contrast rules (only the "high_contrast" set differs from the normal UI colors).
var text: Color = Palette.TEXT
var text_dim: Color = Palette.TEXT_DIM
var text_disabled: Color = Palette.UNAFFORDABLE
var plate: Color = Palette.PANEL
var edge: Color = Palette.GRID
## Background layer brightness multiplier (floor, grid); 1 = unchanged.
var bg_dim: float = 1.0


## Fills the role `role` from `value`; returns false for an unknown role or an unparsable color.
func set_role(role: String, value: String) -> bool:
	if role == "bg_dim":
		bg_dim = clampf(value.to_float(), 0.0, 1.0)
		return true
	if not value.begins_with("#") or not value.is_valid_html_color():
		return false
	var c := Color(value)
	match role:
		"amber":
			amber = c
		"teal":
			teal = c
		"hostile":
			hostile = c
		"fire":
			fire = c
		"critical":
			critical = c
		"text":
			text = c
		"text_dim":
			text_dim = c
		"text_disabled":
			text_disabled = c
		"plate":
			plate = c
		"edge":
			edge = c
		_:
			return false
	return true


## Computes the shader multipliers after all roles are set.
func finish() -> void:
	tint_hostile = gain(Palette.ENEMY_OUTLINE, hostile)
	tint_fire = gain(Palette.ENEMY_FIRE, fire)


## Per-channel multiplier that turns `base` into `target` (clamped to 0..MAX_GAIN).
static func gain(base: Color, target: Color) -> Vector3:
	return Vector3(
		clampf(target.r / maxf(base.r, 0.01), 0.0, MAX_GAIN),
		clampf(target.g / maxf(base.g, 0.01), 0.0, MAX_GAIN),
		clampf(target.b / maxf(base.b, 0.01), 0.0, MAX_GAIN)
	)
