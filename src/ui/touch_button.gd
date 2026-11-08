class_name TouchButton
extends Button
## A button drawn small but hit-tested on a larger rect (V1-25: 80 px icon, >= 126 px touch target). `touch_pad`
## grows the clickable area on every side beyond the control's own rect; neighbors must keep their hit rects apart.

var touch_pad: float = 0.0


## The hit rect in the button's local space.
func touch_rect() -> Rect2:
	return Rect2(Vector2(-touch_pad, -touch_pad), size + Vector2(touch_pad, touch_pad) * 2.0)


func _has_point(point: Vector2) -> bool:
	return touch_rect().has_point(point)
