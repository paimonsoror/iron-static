class_name CinderFrameSpec
extends RefCounted
## Per-frame layout data of the Cinder rig (M3-27, design 11 section 1.5): which sheet pair the frame draws from and
## the few placement numbers that differ between frames. VANGUARD is the V1 rig exactly (its slot ids are the
## unprefixed ones and every number equals the `CinderLayout` constant it replaces). BULWARK and STRIKER draw from
## `cinder_<id>.svg` / `cinder_<id>_glow.svg` through slots named `cinder_<id>_*` that mirror the VANGUARD rows
## cell for cell (same origins and pivots), so the band logic and the wedge structure are shared.
## Emitter positions are layout data: `node_radius_texels` is the beam start radius on the ring cell.

const VANGUARD: String = "vanguard"
const BULWARK: String = "bulwark"
const STRIKER: String = "striker"
const BASE_PREFIX: String = "cinder_"

static var _cache: Dictionary = {}

var frame_id: String = VANGUARD
## Slot id prefix replacing `cinder_`; "" = the base ids themselves (VANGUARD).
var prefix: String = ""
var shoulder_pos: Vector2 = CinderLayout.SHOULDER_POS
var shoulder_lens_offset: Vector2 = CinderLayout.SHOULDER_LENS_OFFSET
var ticks_pos: Vector2 = CinderLayout.TICKS_POS
var ticks_scale: float = CinderLayout.TICKS_SCALE
var shadow_offset: Vector2 = CinderLayout.SHADOW_OFFSET
var shadow_scale: float = CinderLayout.SHADOW_SCALE
## Radius of the emitter nodes on the ring cell in texels (beam start). Twin emitters fire from the node center.
var node_radius_texels: float = CinderLayout.NODE_RADIUS_TEXELS

var _slots: Dictionary = {}


## The spec of a frame id; unknown or empty ids give VANGUARD. Instances are shared (read-only).
static func for_frame(id: String) -> CinderFrameSpec:
	var key: String = id if id == BULWARK or id == STRIKER else VANGUARD
	if not _cache.has(key):
		_cache[key] = _make(key)
	var found: CinderFrameSpec = _cache[key]
	return found


static func is_known(id: String) -> bool:
	return id == VANGUARD or id == BULWARK or id == STRIKER


static func _make(id: String) -> CinderFrameSpec:
	var s := CinderFrameSpec.new()
	s.frame_id = id
	if id == VANGUARD:
		return s
	s.prefix = BASE_PREFIX + id + "_"
	# Both variants keep the VANGUARD shoulder anchor, ticks and shadow; the art differs inside the cells.
	return s


## Slot id of a base (VANGUARD) slot for this frame. VANGUARD returns the id itself (no allocation); a variant
## builds the prefixed id once and caches it.
func slot(base_id: String) -> String:
	if prefix.is_empty() or base_id.is_empty():
		return base_id
	if _slots.has(base_id):
		var cached: String = _slots[base_id]
		return cached
	var out: String = prefix + base_id.substr(BASE_PREFIX.length())
	_slots[base_id] = out
	return out
