class_name LayoutMode
extends RefCounted
## Portrait or wide UI layout, chosen from the viewport aspect (V1-28). Pure.
## Under the project's canvas_items/expand stretch the viewport is at least 1080 x 1920, so a phone is 0.45 to 0.56
## (width / height) and a near-square foldable inner screen is about 1.03 (1990 x 1920). 0.75 is a 3:4 tablet held
## upright, where the phone layout still fits (1440 x 1920 base). The switch has hysteresis: WIDE from 0.78 up, back
## to PORTRAIT only below 0.72, so a window dragged across 0.75 (split screen, fold hinge angle) cannot flap.

enum Mode { PORTRAIT, WIDE }

const THRESHOLD: float = 0.75
const HYSTERESIS: float = 0.03
const WIDE_ENTER: float = THRESHOLD + HYSTERESIS
const PORTRAIT_ENTER: float = THRESHOLD - HYSTERESIS


## The layout for `viewport` given the `current` mode. A degenerate size keeps the current mode.
static func pick(viewport: Vector2, current: Mode) -> Mode:
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return current
	var aspect: float = viewport.x / viewport.y
	if current == Mode.WIDE:
		return Mode.PORTRAIT if aspect < PORTRAIT_ENTER else Mode.WIDE
	return Mode.WIDE if aspect >= WIDE_ENTER else Mode.PORTRAIT
