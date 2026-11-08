class_name SafeArea
extends RefCounted
## Converts the OS safe area (display cutouts, rounded corners) into HUD margins (V1-24). Under the project's
## `canvas_items` stretch with `expand` aspect the viewport is the window scaled uniformly, so a window pixel maps
## to `viewport / window` viewport units on each axis. Inputs are in window pixels with the origin at the window's
## top left (on Android the window is the screen); the safe rect is clipped to the window first, so a window that
## is larger or offset from the safe rect never gives a negative margin. Result is (left, top, right, bottom).


static func margins(window_px: Vector2, safe_px: Rect2, viewport: Vector2) -> Vector4:
	if window_px.x <= 0.0 or window_px.y <= 0.0 or safe_px.size.x <= 0.0 or safe_px.size.y <= 0.0:
		return Vector4.ZERO
	var clipped: Rect2 = safe_px.intersection(Rect2(Vector2.ZERO, window_px))
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		return Vector4.ZERO
	var kx: float = viewport.x / window_px.x
	var ky: float = viewport.y / window_px.y
	return Vector4(
		clipped.position.x * kx,
		clipped.position.y * ky,
		(window_px.x - clipped.end.x) * kx,
		(window_px.y - clipped.end.y) * ky
	)
