class_name CvdSim
extends RefCounted
## Test helper (M4-24): colour-vision-deficiency simulation (Machado, Oliveira and Fernandes 2009, severity 1.0, on
## linear sRGB) and CIE Lab delta E, to prove the palettes keep hostile, friendly and enemy fire apart.

const DEUTERANOPIA: Array[float] = [
	0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.011820, 0.042940, 0.968881
]
const PROTANOPIA: Array[float] = [
	0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998
]
const TRITANOPIA: Array[float] = [
	1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.303900
]
const RGB_TO_XYZ: Array[float] = [0.4124, 0.3576, 0.1805, 0.2126, 0.7152, 0.0722, 0.0193, 0.1192, 0.9505]


## Colour as a person with `mode` ("off" = unchanged) sees it, in linear RGB, each channel clamped 0..1.
static func linear_seen(c: Color, mode: String) -> PackedFloat64Array:
	var lin := PackedFloat64Array([_lin(c.r), _lin(c.g), _lin(c.b)])
	var m: Array[float] = _matrix(mode)
	if m.is_empty():
		return lin
	var out := PackedFloat64Array([0.0, 0.0, 0.0])
	for i: int in 3:
		out[i] = clampf(m[i * 3] * lin[0] + m[i * 3 + 1] * lin[1] + m[i * 3 + 2] * lin[2], 0.0, 1.0)
	return out


## CIE76 delta E between two colours as seen in `mode` (about 2.3 is just noticeable; 25+ is clearly different).
static func delta_e(a: Color, b: Color, mode: String) -> float:
	return _lab(linear_seen(a, mode)).distance_to(_lab(linear_seen(b, mode)))


## WCAG contrast ratio between the two colours as seen in `mode`.
static func luminance_ratio(a: Color, b: Color, mode: String) -> float:
	var la: float = _luma(linear_seen(a, mode))
	var lb: float = _luma(linear_seen(b, mode))
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _matrix(mode: String) -> Array[float]:
	match mode:
		"deuteranopia":
			return DEUTERANOPIA
		"protanopia":
			return PROTANOPIA
		"tritanopia":
			return TRITANOPIA
	var none: Array[float] = []
	return none


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _luma(l: PackedFloat64Array) -> float:
	return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]


static func _lab(l: PackedFloat64Array) -> Vector3:
	var xyz := PackedFloat64Array([0.0, 0.0, 0.0])
	for i: int in 3:
		xyz[i] = RGB_TO_XYZ[i * 3] * l[0] + RGB_TO_XYZ[i * 3 + 1] * l[1] + RGB_TO_XYZ[i * 3 + 2] * l[2]
	var fx: float = _f(xyz[0] / 0.95047)
	var fy: float = _f(xyz[1])
	var fz: float = _f(xyz[2] / 1.08883)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
