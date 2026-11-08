class_name TitleFrameLogo
extends Sprite2D
## The IRON STATIC logo sheet (960 x 400, two cells) with the shimmer shader: a slow light sweep, and every few
## seconds a 0.15 s glitch (horizontal tear, channel offset, sparkles). Timing is view-side (own RNG); reduce motion
## zeroes every uniform so the word is static.

const TEAR_LEN_S: float = 0.15
const TEAR_GAP_S: Vector2 = Vector2(2.5, 5.5)
const SWEEP_PERIOD_S: float = 7.0

var reduce_motion: bool = false

var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial = null
var _next_tear: float = 3.0
var _tear_t: float = -1.0


func setup() -> void:
	_rng.seed = 21
	texture = TitleFrameArt.tex("logo")
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_mat = ShaderMaterial.new()
	_mat.shader = load(TitleFrameArt.SHADER_LOGO) as Shader
	material = _mat
	_next_tear = _rng.randf_range(TEAR_GAP_S.x, TEAR_GAP_S.y)


func is_tearing() -> bool:
	return _tear_t >= 0.0


## Starts a glitch now (the capture script and the debug button use this).
func force_tear() -> void:
	_tear_t = 0.0
	_mat.set_shader_parameter("tear_y", _rng.randf_range(0.18, 0.4))
	_mat.set_shader_parameter("tear_y2", _rng.randf_range(0.6, 0.85))
	_mat.set_shader_parameter("tear_dx", _rng.randf_range(0.012, 0.026) * (1.0 if _rng.randf() < 0.5 else -1.0))
	_mat.set_shader_parameter("noise_seed", _rng.randf() * 50.0)


func tick(t: float, dt: float) -> void:
	if reduce_motion:
		_tear_t = -1.0
		_mat.set_shader_parameter("tear", 0.0)
		_mat.set_shader_parameter("sweep_strength", 0.0)
		return
	_mat.set_shader_parameter("sweep_strength", 0.35)
	_mat.set_shader_parameter("sweep", fmod(t / SWEEP_PERIOD_S, 1.0) * 2.2 - 0.6)
	if _tear_t >= 0.0:
		_tear_t += dt
		if _tear_t >= TEAR_LEN_S:
			_tear_t = -1.0
			_next_tear = t + _rng.randf_range(TEAR_GAP_S.x, TEAR_GAP_S.y)
			_mat.set_shader_parameter("tear", 0.0)
		else:
			var u: float = _tear_t / TEAR_LEN_S
			_mat.set_shader_parameter("tear", 1.0 - absf(u - 0.5) * 0.6)
	elif t >= _next_tear:
		force_tear()
