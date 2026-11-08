class_name ParticlePack
extends RefCounted
## Encoding of one particle into the 16 floats of a MultiMesh instance (V1-13). The vertex shader
## `particle_ring.gdshader` integrates the particle analytically from these values, so the CPU writes a particle
## once at spawn.
##
## Spike finding (desktop GL, same Compatibility path as Android): instance COLOR and CUSTOM DATA reach the vertex
## shader as 16-bit half floats, so large packed integers are lost (a packed 24-bit value reads back rounded to
## 11 bits). Only the instance TRANSFORM keeps float32. Therefore the origin lives in the transform and every other
## field is a small integer (<= 2047, exact in a half float) stored in one of the 8 half slots:
##   [8]  COLOR.r  birth       11 bits: (sim seconds * 64) mod 2048, a 32 s wrapping clock (age = now - birth)
##   [9]  COLOR.g  life 7 bits (1/64 s units, 0 = dead slot) | peak alpha 4 bits << 7 (x/15)
##   [10] COLOR.b  kind 5 bits | blue 5 bits << 5 (x/31)
##   [11] COLOR.a  red 5 bits | green 5 bits << 5 (x/31)
##   [12] CUSTOM.x velocity x px/s + 1024    [13] CUSTOM.y velocity y px/s + 1024   (-1024..1023)
##   [14] CUSTOM.z size at birth in px (0..2047)   [15] CUSTOM.w size at death in px
## Rotation, spin, drag and the "align to velocity" flag are per KIND tables in the shader (and a hash of the
## instance id for the start angle / spin sign), so they cost no bits. The bit layout is repeated in the shader.

const FLOATS: int = MultiMeshBuffer.FLOATS_PER_INSTANCE
const COLOR_OFFSET: int = 8
const CUSTOM_OFFSET: int = 12
## The shader clock wraps every CLOCK_PERIOD_S seconds; the pool clears expired slots at least every SWEEP_S so a
## dead particle can never come back around.
const CLOCK_STEPS: float = 64.0
const CLOCK_PERIOD_S: float = 32.0
const CLOCK_RANGE: int = 2048
const SWEEP_S: float = 8.0
const LIFE_STEPS: float = 64.0
const LIFE_MAX_S: float = 127.0 / 64.0
const VEL_BIAS: int = 1024
const SIZE_MAX: int = 2047

## fx_sheet cell per kind (index = kind id, max 32). Spark kinds use the 128x32 band at rows 48..80.
const KIND_HALO: int = 0
const KIND_FLASH: int = 1
const KIND_FLARE4: int = 2
const KIND_FLARE8: int = 3
const KIND_RING_THIN: int = 4
const KIND_RING_THICK: int = 5
const KIND_SMOKE_A: int = 6
const KIND_SMOKE_B: int = 7
const KIND_SPARK_A: int = 8  ## 8..10 spark a, b, c
const KIND_EMBER_A: int = 11  ## 11..12 ember a, b
const KIND_SHARD_1: int = 13  ## 13..18 shard 1..6
const KIND_COUNT: int = 19
const SLOTS: Array[String] = [
	"fx_halo_soft",
	"fx_flash_disc",
	"fx_flare_star_4",
	"fx_flare_star_8",
	"fx_ring_thin",
	"fx_ring_thick",
	"fx_smoke_puff_a",
	"fx_smoke_puff_b",
	"fx_spark_a",
	"fx_spark_b",
	"fx_spark_c",
	"fx_ember_a",
	"fx_ember_b",
	"fx_shard_1",
	"fx_shard_2",
	"fx_shard_3",
	"fx_shard_4",
	"fx_shard_5",
	"fx_shard_6",
]
## Crop of a spark cell in texels (x, y, w, h inside the cell): a 4:1 band.
const SPARK_CROP := Rect2(0.0, 48.0, 128.0, 32.0)


static func is_spark(kind: int) -> bool:
	return kind >= KIND_SPARK_A and kind < KIND_SPARK_A + 3


static func is_smoke(kind: int) -> bool:
	return kind == KIND_SMOKE_A or kind == KIND_SMOKE_B


static func is_shard(kind: int) -> bool:
	return kind >= KIND_SHARD_1 and kind < KIND_SHARD_1 + 6


static func is_ember(kind: int) -> bool:
	return kind == KIND_EMBER_A or kind == KIND_EMBER_A + 1


## Birth on the wrapping 32 s clock, in 1/64 s units (0..2047), rounded down so a particle never starts late.
static func clock_units(sim_seconds: float) -> int:
	return posmod(floori(sim_seconds * CLOCK_STEPS), CLOCK_RANGE)


## Value of the shader's `u_now` for a sim time (seconds on the wrapping clock).
static func clock_now(sim_seconds: float) -> float:
	return fposmod(sim_seconds, CLOCK_PERIOD_S)


static func life_units(life_s: float) -> int:
	return clampi(roundi(life_s * LIFE_STEPS), 1, 127)


## Life + peak alpha half.
static func pack_life_alpha(life_s: float, alpha: float) -> float:
	return float(life_units(life_s) | (clampi(roundi(alpha * 15.0), 0, 15) << 7))


## Kind + blue half.
static func pack_kind_blue(kind: int, c: Color) -> float:
	return float((kind & 31) | (clampi(roundi(c.b * 31.0), 0, 31) << 5))


## Red + green half.
static func pack_red_green(c: Color) -> float:
	return float(clampi(roundi(c.r * 31.0), 0, 31) | (clampi(roundi(c.g * 31.0), 0, 31) << 5))


static func pack_vel(v: float) -> float:
	return float(clampi(roundi(v), -VEL_BIAS, VEL_BIAS - 1) + VEL_BIAS)


static func pack_size(px: float) -> float:
	return float(clampi(roundi(px), 0, SIZE_MAX))


static func unpack_life(v: float) -> float:
	return float(int(v) & 127) / LIFE_STEPS


static func unpack_alpha(v: float) -> float:
	return float((int(v) >> 7) & 15) / 15.0


static func unpack_kind(v: float) -> int:
	return int(v) & 31


static func unpack_color(kind_blue: float, red_green: float) -> Color:
	var rg: int = int(red_green)
	return Color(float(rg & 31) / 31.0, float((rg >> 5) & 31) / 31.0, float((int(kind_blue) >> 5) & 31) / 31.0)


static func unpack_vel(v: float) -> float:
	return float(int(v) - VEL_BIAS)
