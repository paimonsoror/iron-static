class_name RenderSampler
extends RefCounted
## Render-side numbers for the [PERF] line (V1-03). Per frame `sample(delta)` reads the Godot `Performance`
## monitors (draw calls, objects, primitives, texture/video memory, process time) and the wall frame time;
## `take_suffix(tier)` returns the period aggregate as the text appended after the existing [PERF] fields and
## starts a new period. Compatibility renderer notes: the monitors are filled by the GLES3 rasterizer;
## `viewport_get_measured_render_time_gpu` is 0 there when timestamp queries are unavailable (reported as is).
## No per-frame allocation: integers and floats only; the histogram is preallocated.

const MB: float = 1048576.0

var _hist := FrameHistogram.new()
var _frames: int = 0
var _frame_ms_sum: float = 0.0
var _draws_sum: int = 0
var _draws_max: int = 0
var _objects_sum: int = 0
var _prims_sum: int = 0
var _proc_ms_sum: float = 0.0
var _rcpu_ms_sum: float = 0.0
var _rgpu_ms_sum: float = 0.0
var _tex_mb: float = 0.0
var _vid_mb: float = 0.0
var _buf_mb: float = 0.0
var _viewport: RID


## Enables the viewport render-time measurement (small cost; only call when [PERF] logging is on).
func setup(viewport: Viewport) -> void:
	_viewport = viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport, true)


func sample(delta: float) -> void:
	var ms: float = delta * 1000.0
	_hist.add(ms)
	_frames += 1
	_frame_ms_sum += ms
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_draws_sum += draws
	_draws_max = maxi(_draws_max, draws)
	_objects_sum += int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_prims_sum += int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_proc_ms_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_tex_mb = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / MB
	_vid_mb = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB
	_buf_mb = Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / MB
	if _viewport.is_valid():
		_rcpu_ms_sum += RenderingServer.viewport_get_measured_render_time_cpu(_viewport)
		_rgpu_ms_sum += RenderingServer.viewport_get_measured_render_time_gpu(_viewport)


func frames() -> int:
	return _frames


## Text appended to the [PERF] line (leading space); resets the period. Empty with no samples.
func take_suffix(tier_name: String) -> String:
	if _frames == 0:
		return ""
	var n: float = float(_frames)
	var text: String = (
		" draws=%d objects=%d tex_mb=%.1f vid_mb=%.1f tier=%s"
		% [roundi(float(_draws_sum) / n), roundi(float(_objects_sum) / n), _tex_mb, _vid_mb, tier_name]
	)
	text += (
		" prims=%d draws_max=%d buf_mb=%.1f frame_ms=%.2f p95_ms=%.1f max_ms=%.1f proc_ms=%.2f rcpu_ms=%.2f rgpu_ms=%.2f"
		% [
			roundi(float(_prims_sum) / n),
			_draws_max,
			_buf_mb,
			_frame_ms_sum / n,
			_hist.percentile(95.0),
			_hist.maximum(),
			_proc_ms_sum / n,
			_rcpu_ms_sum / n,
			_rgpu_ms_sum / n,
		]
	)
	reset()
	return text


func reset() -> void:
	_hist.reset()
	_frames = 0
	_frame_ms_sum = 0.0
	_draws_sum = 0
	_draws_max = 0
	_objects_sum = 0
	_prims_sum = 0
	_proc_ms_sum = 0.0
	_rcpu_ms_sum = 0.0
	_rgpu_ms_sum = 0.0
