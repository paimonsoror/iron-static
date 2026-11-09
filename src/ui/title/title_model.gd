class_name TitleModel
extends RefCounted
## Pure rules of the title screen (M3-28): which buttons show, the quality ladder (smoke layers, embers, flare), the
## hero frame and the layout math. No nodes; `TitleScreen` applies the results.

const ROW_CONTINUE: String = "continue"
const ROW_NEW_GAME: String = "new_game"
const ROW_SETTINGS: String = "settings"
## Label key per row id (full literal keys so the string-key scan can verify them).
const ROW_LABEL_KEYS: Dictionary = {
	ROW_CONTINUE: "title.continue",
	ROW_NEW_GAME: "title.new_game",
	ROW_SETTINGS: "title.settings",
}
const ROW_H: float = 160.0
const ROW_GAP: float = 32.0
const ROW_WIDTH: float = 640.0
const BOTTOM_PAD: float = 48.0
const LOGO_CENTER_Y: float = 540.0
const LOGO_MIN_TOP: float = 24.0
const LOGO_HALF_H: float = 220.0
const FADE_S: float = 0.6
## Largest horizontal tear shift of the logo shimmer in base px (shader `tear_dx` is a fraction of the 960 px sheet).
const MAX_TEAR_PX: float = 12.0
const TEAR_DX_MIN: float = 0.006
const TEAR_DX_MAX: float = 0.011
const SHIMMER_SPLIT: float = 0.006
const SWEEP_STRENGTH: float = 0.35
const EMBER_RATE: Array[float] = [26.0, 14.0, 0.0]


## True when the profile shows CONTINUE (runs, Foundry level or run counter).
static func has_progress(profile: PlayerProfile) -> bool:
	return profile != null and profile.has_progress()


## Button ids top to bottom.
static func rows(has_progress_flag: bool) -> Array[String]:
	var out: Array[String] = []
	if has_progress_flag:
		out.append(ROW_CONTINUE)
	out.append(ROW_NEW_GAME)
	out.append(ROW_SETTINGS)
	return out


static func label_key(row_id: String) -> String:
	return str(ROW_LABEL_KEYS.get(row_id, ""))


## The hero frame: the profile's selected frame, falling back to vanguard (FrameRules).
static func hero_frame(profile: PlayerProfile, defs: Array[FrameDef]) -> String:
	var id: String = FrameRules.selected_id(profile, defs)
	return id if TitleArt.FRAMES.has(id) else FrameRules.DEFAULT_FRAME


## Smoke layers shown per tier: HIGH 3, MID 2, LOW 1 (indices into the back-to-front layer list).
static func smoke_layers(tier: VisualQuality.Tier) -> Array[int]:
	if tier == VisualQuality.Tier.LOW:
		return [1]
	if tier == VisualQuality.Tier.MID:
		return [0, 1]
	return [0, 1, 2]


static func embers_enabled(tier: VisualQuality.Tier) -> bool:
	return EMBER_RATE[int(tier)] > 0.0


static func flare_enabled(tier: VisualQuality.Tier, reduce_motion: bool) -> bool:
	return tier != VisualQuality.Tier.LOW and not reduce_motion


static func scanlines_enabled(tier: VisualQuality.Tier, reduce_motion: bool) -> bool:
	return tier == VisualQuality.Tier.HIGH and not reduce_motion


## Tear shift in base px for a shader `tear_dx` fraction at the shown logo scale.
static func tear_px(tear_dx: float) -> float:
	return absf(tear_dx) * TitleArt.LOGO_SHEET_W * TitleArt.LOGO_SCALE


static func buttons_size(row_count: int) -> Vector2:
	return Vector2(ROW_WIDTH, float(row_count) * ROW_H + float(maxi(row_count - 1, 0)) * ROW_GAP)


## The button block (rows) bottom-anchored in `column` (inside the safe area).
static func buttons_rect(column: Rect2, row_count: int) -> Rect2:
	var s: Vector2 = buttons_size(row_count)
	var w: float = minf(s.x, column.size.x)
	var h: float = s.y
	return Rect2(column.position.x + (column.size.x - w) * 0.5, column.end.y - BOTTOM_PAD - h, w, h)


## Logo centre y: 540 on the 2400 reference, squeezed on a shorter view, never above the safe top.
static func logo_center_y(size: Vector2, safe_top: float) -> float:
	var squeeze: float = minf(size.y - TitleArt.REF_H, 0.0)
	return maxf(LOGO_CENTER_Y + squeeze * 0.25, safe_top + LOGO_MIN_TOP + LOGO_HALF_H)
