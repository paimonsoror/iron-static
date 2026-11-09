class_name FtuePlacement
extends RefCounted
## Where the FTUE label plate and the arrow go (M4-27 F1-F3): pure geometry, so it is unit-tested. The plate never sits
## on the target's own content. Each target kind names an ANCHOR rect (the panel, the Results card, the Foundry
## free band) and the plate goes next to it; the arrow aims at the target from the side of its free space.
##   ROW (run upgrade row): the plate sits ABOVE the upgrade panel (over the arena); the arrow comes from above
##     at the blank strip between the CHASSIS and SYSTEMS tabs and the blank middle of a row.
##   RESULTS (FOUNDRY button): the plate sits BELOW the Results card (above it when there is no room); the arrow
##     comes from below at the left blank part of the HOME button.
##   FOUNDRY (a Foundry row): the plate sits IN the free band between the last row and DEPLOY; the arrow comes
##     from above through the gap between BACK and the DATA balance.

enum Kind { FIELD, ROW, RESULTS, FOUNDRY }

const EDGE_GAP: float = 24.0
## Fraction of a row's width where the arrow aims: the middle, which is the gap between two tabs when the row is first.
const ROW_ARROW_FRAC: float = 0.5
## Fraction of the FOUNDRY button's width where the arrow aims from below (left of the centered HOME label).
const RESULTS_ARROW_FRAC: float = 0.14


static func kind_of(target: String) -> Kind:
	if target == FtueScript.TARGET_RESULTS_FOUNDRY:
		return Kind.RESULTS
	if target.begins_with(FtueScript.FOUNDRY_PREFIX):
		return Kind.FOUNDRY
	if target.begins_with(FtueScript.ROW_PREFIX):
		return Kind.ROW
	return Kind.FIELD


## True when the arrow points down at the target from above.
static func arrow_from_above(kind: Kind) -> bool:
	return kind != Kind.RESULTS


## X of the arrow tip in the target rect's coordinates; NAN = the rect's center.
static func arrow_x(kind: Kind, target: Rect2) -> float:
	match kind:
		Kind.ROW:
			return target.position.x + target.size.x * ROW_ARROW_FRAC
		Kind.RESULTS:
			return target.position.x + target.size.x * RESULTS_ARROW_FRAC
	return NAN


## Top-left of the plate. `anchor` is the rect it goes next to (Rect2() = none known), `view` the overlay size.
static func plate_pos(
	kind: Kind, target: Rect2, anchor: Rect2, plate: Vector2, view: Vector2, margin: float
) -> Vector2:
	var ref: Rect2 = anchor if anchor.size != Vector2.ZERO else target
	var x: float = clampf(ref.get_center().x - plate.x * 0.5, margin, maxf(view.x - margin - plate.x, margin))
	var y: float
	match kind:
		Kind.ROW:
			y = ref.position.y - plate.y - EDGE_GAP
		Kind.RESULTS:
			y = ref.end.y + EDGE_GAP
			if y + plate.y > view.y - EDGE_GAP:
				y = ref.position.y - plate.y - EDGE_GAP
		Kind.FOUNDRY:
			y = minf(ref.position.y + (ref.size.y - plate.y) * 0.5, ref.end.y - plate.y)  # never over DEPLOY
		_:
			y = ref.position.y + (ref.size.y - plate.y) * 0.5
	return Vector2(x, clampf(y, EDGE_GAP, maxf(view.y - plate.y - EDGE_GAP, EDGE_GAP)))
