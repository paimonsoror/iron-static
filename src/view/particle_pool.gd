class_name ParticlePool
extends RefCounted
## Fixed-capacity ring of particles written into a MultiMesh instance buffer (V1-13). Pure data, no Node and no
## allocation after setup(): `emit()` overwrites the OLDEST slot when the ring is full (round-robin head), so a
## burst of kills can never exceed the cap and never grows memory. The renderer uploads `buffer` when `dirty`.

## Instance buffer, `capacity` * ParticlePack.FLOATS floats.
var buffer := PackedFloat32Array()
var capacity: int = 0
## Next slot to write (the oldest particle once the ring has wrapped).
var head: int = 0
## Slots ever used (<= capacity): the renderer draws this many instances.
var used: int = 0
## Particles written since setup/clear (also the id of the next particle).
var total_written: int = 0
## True when `buffer` changed since the renderer last uploaded it.
var dirty: bool = false
## Id (write sequence number) per slot, -1 for an empty slot.
var ids := PackedInt32Array()
## End of life (birth + life, sim seconds) per slot, for live counting.
var ends := PackedFloat32Array()


## Sizes the ring (no allocation afterwards). Existing content is dropped.
func setup(cap: int) -> void:
	capacity = maxi(cap, 1)
	var ok: bool = buffer.resize(capacity * ParticlePack.FLOATS) == OK
	ok = ok and ids.resize(capacity) == OK and ends.resize(capacity) == OK
	if not ok:
		push_error("ParticlePool: resize failed")
	clear()


## Empties the ring without touching the allocation.
func clear() -> void:
	buffer.fill(0.0)
	ids.fill(-1)
	ends.fill(-1.0e9)
	for i: int in capacity:
		var o: int = i * ParticlePack.FLOATS
		buffer[o] = 1.0  # identity basis; the packed fields stay 0 (life 0 = dead slot)
		buffer[o + 5] = 1.0
		buffer[o + 12] = float(ParticlePack.VEL_BIAS)
		buffer[o + 13] = float(ParticlePack.VEL_BIAS)
	head = 0
	used = 0
	total_written = 0
	dirty = true


## Writes one particle into the head slot (overwriting the oldest one) and returns the slot index.
## `color.a` is the peak alpha; `size` = (px at birth, px at death); `kind` is a ParticlePack.KIND_*.
func emit(pos: Vector2, vel: Vector2, birth: float, life: float, size: Vector2, color: Color, kind: int) -> int:
	# the packing of ParticlePack is inlined here: this runs hundreds of times in a heavy frame
	var slot: int = head
	var o: int = slot * 16
	var lu: int = int(life * 64.0 + 0.5)
	lu = 1 if lu < 1 else (127 if lu > 127 else lu)
	var vx: int = int(vel.x + 1024.5)
	var vy: int = int(vel.y + 1024.5)
	var s0: int = int(size.x + 0.5)
	var s1: int = int(size.y + 0.5)
	buffer[o + 3] = pos.x
	buffer[o + 7] = pos.y
	buffer[o + 8] = float(int(birth * 64.0) & 2047)
	buffer[o + 9] = float(lu | (int(color.a * 15.0 + 0.5) << 7))
	buffer[o + 10] = float((kind & 31) | (int(color.b * 31.0 + 0.5) << 5))
	buffer[o + 11] = float(int(color.r * 31.0 + 0.5) | (int(color.g * 31.0 + 0.5) << 5))
	buffer[o + 12] = float(0 if vx < 0 else (2047 if vx > 2047 else vx))
	buffer[o + 13] = float(0 if vy < 0 else (2047 if vy > 2047 else vy))
	buffer[o + 14] = float(s0 if s0 < 2047 else 2047)
	buffer[o + 15] = float(s1 if s1 < 2047 else 2047)
	ids[slot] = total_written
	ends[slot] = birth + minf(life, ParticlePack.LIFE_MAX_S)
	total_written += 1
	head = slot + 1 if slot + 1 < capacity else 0
	used = used + 1 if used < capacity else capacity
	dirty = true
	return slot


## Marks every slot whose life ended before `now` as dead (life 0) so the wrapping 32 s shader clock cannot bring
## it back. Call at least every ParticlePack.SWEEP_S seconds of sim time. Returns the number of slots cleared.
func sweep(now: float) -> int:
	var n: int = 0
	for i: int in used:
		var o: int = i * ParticlePack.FLOATS + 9
		if ends[i] < now and (int(buffer[o]) & 127) != 0:
			buffer[o] = 0.0
			n += 1
	if n > 0:
		dirty = true
	return n


## Particles whose life has not ended at sim time `now` (O(capacity); call for stats, not per particle).
func live_count(now: float) -> int:
	var n: int = 0
	for i: int in used:
		if ends[i] > now:
			n += 1
	return n


func id_at(slot: int) -> int:
	return ids[slot]


## Birth in clock units (1/64 s, wrapping at 32 s).
func birth_units_at(slot: int) -> int:
	return int(buffer[slot * ParticlePack.FLOATS + ParticlePack.COLOR_OFFSET])


func kind_at(slot: int) -> int:
	return ParticlePack.unpack_kind(buffer[slot * ParticlePack.FLOATS + ParticlePack.COLOR_OFFSET + 2])


func is_dead_slot(slot: int) -> bool:
	return (int(buffer[slot * ParticlePack.FLOATS + ParticlePack.COLOR_OFFSET + 1]) & 127) == 0


func pos_at(slot: int) -> Vector2:
	var o: int = slot * ParticlePack.FLOATS
	return Vector2(buffer[o + 3], buffer[o + 7])
