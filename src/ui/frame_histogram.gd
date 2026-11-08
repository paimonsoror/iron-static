class_name FrameHistogram
extends RefCounted
## Fixed-bucket histogram of frame times in ms for percentile reports (V1-03). No allocation after
## construction: `add` increments a bucket of BUCKET_MS width; values at or above MAX_MS land in the last bucket.

const BUCKET_MS: float = 0.5
const MAX_MS: float = 250.0

var _buckets := PackedInt32Array()
var _count: int = 0
var _max: float = 0.0


func _init() -> void:
	if _buckets.resize(int(MAX_MS / BUCKET_MS)) != OK:
		push_error("FrameHistogram: resize failed")


func add(ms: float) -> void:
	var idx: int = clampi(int(ms / BUCKET_MS), 0, _buckets.size() - 1)
	_buckets[idx] += 1
	_count += 1
	_max = maxf(_max, ms)


func count() -> int:
	return _count


func maximum() -> float:
	return _max


## Upper edge of the bucket holding the `p`-th percentile (p in 0-100), 0.0 with no samples.
func percentile(p: float) -> float:
	if _count == 0:
		return 0.0
	var target: int = maxi(ceili(float(_count) * clampf(p, 0.0, 100.0) / 100.0), 1)
	var seen: int = 0
	for i: int in _buckets.size():
		seen += _buckets[i]
		if seen >= target:
			return float(i + 1) * BUCKET_MS
	return MAX_MS


func reset() -> void:
	_buckets.fill(0)
	_count = 0
	_max = 0.0
