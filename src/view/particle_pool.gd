class_name ParticlePool
extends RefCounted
## Fixed-capacity ring of particles written into a MultiMesh instance buffer (V1-13). Pure data, no Node and no
## allocation after setup(): `emit()` overwrites the OLDEST slot when the ring is full (round-robin head), so a
## burst of kills can never exceed the cap and never grows memory. The renderer uploads `buffer` when `dirty`.

## MultiMesh instance buffer (transform only), `capacity` * ParticlePack.FLOATS floats.
var buffer := PackedFloat32Array()
## Per-particle data (tint, alpha, velocity, size, birth, life, kind), `capacity` * ParticlePack.DATA_FLOATS floats;
## the renderer uploads it as a float32 RGBA texture (layout and precision budget: ParticlePack).
var data := PackedFloat32Array()
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
	ok = ok and data.resize(capacity * ParticlePack.DATA_FLOATS) == OK
	ok = ok and ids.resize(capacity) == OK and ends.resize(capacity) == OK
	if not ok:
		push_error("ParticlePool: resize failed")
	clear()


## Empties the ring without touching the allocation.
func clear() -> void:
	buffer.fill(0.0)
	data.fill(0.0)  # life 0 = dead slot
	ids.fill(-1)
	ends.fill(-1.0e9)
	for i: int in capacity:
		var o: int = i * ParticlePack.FLOATS
		buffer[o] = 1.0  # identity basis
		buffer[o + 5] = 1.0
	head = 0
	used = 0
	total_written = 0
	dirty = true


## Writes one particle into the head slot (overwriting the oldest one) and returns the slot index.
## `color.a` is the peak alpha; `size` = (px at birth, px at death); `kind` is a ParticlePack.KIND_*.
func emit(pos: Vector2, vel: Vector2, birth: float, life: float, size: Vector2, color: Color, kind: int) -> int:
	# the packing of ParticlePack is inlined here: this runs hundreds of times in a heavy frame
	var slot: int = head
	var o: int = slot * ParticlePack.FLOATS
	var d: int = slot * ParticlePack.DATA_FLOATS
	var lu: int = int(life * 64.0 + 0.5)
	lu = 1 if lu < 1 else (127 if lu > 127 else lu)
	buffer[o + 3] = pos.x
	buffer[o + 7] = pos.y
	data[d] = clampf(color.r, 0.0, 1.0)
	data[d + 1] = clampf(color.g, 0.0, 1.0)
	data[d + 2] = clampf(color.b, 0.0, 1.0)
	data[d + 3] = clampf(color.a, 0.0, 1.0)
	data[d + 4] = clampf(vel.x, -ParticlePack.VEL_MAX, ParticlePack.VEL_MAX)
	data[d + 5] = clampf(vel.y, -ParticlePack.VEL_MAX, ParticlePack.VEL_MAX)
	data[d + 6] = clampf(size.x, 0.0, ParticlePack.SIZE_MAX)
	data[d + 7] = clampf(size.y, 0.0, ParticlePack.SIZE_MAX)
	data[d + 8] = float(posmod(int(birth * 64.0), ParticlePack.CLOCK_RANGE)) / 64.0
	data[d + 9] = float(lu) / 64.0
	data[d + 10] = float(clampi(kind, 0, 31))
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
		var o: int = i * ParticlePack.DATA_FLOATS + ParticlePack.D_LIFE
		if ends[i] < now and data[o] != 0.0:
			data[o] = 0.0
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
	return roundi(data[slot * ParticlePack.DATA_FLOATS + ParticlePack.D_BIRTH] * ParticlePack.CLOCK_STEPS)


func kind_at(slot: int) -> int:
	return roundi(data[slot * ParticlePack.DATA_FLOATS + ParticlePack.D_KIND])


func is_dead_slot(slot: int) -> bool:
	return data[slot * ParticlePack.DATA_FLOATS + ParticlePack.D_LIFE] == 0.0


func pos_at(slot: int) -> Vector2:
	var o: int = slot * ParticlePack.FLOATS
	return Vector2(buffer[o + 3], buffer[o + 7])
