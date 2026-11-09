class_name ParticlePack
extends RefCounted
## Encoding of one particle (V1-13, hardened V1-26). The vertex shader `particle_ring.gdshader` integrates the
## particle analytically from these values, so the CPU writes a particle once at spawn.
##
## V1-26 (white flash on PowerVR C-Series via ANGLE/Vulkan): the old layout bit-packed several fields into each
## 16-bit half of the instance COLOR / CUSTOM data and decoded them with floor/shift/mask in the shader. A GPU that
## runs that arithmetic at fp16/mediump decodes garbage (pale colours became yellow, sizes 10-60x too big). Now NO
## field shares a number with another and nothing is bit-unpacked:
##   * MultiMesh instance = the 2D transform only (float32): origin = spawn position. No instance COLOR or CUSTOM.
##   * Every other field is a plain number in a one-row RGBAH (half) data texture the vertex shader reads with
##     `texelFetch` (3 texels per particle, texel index = INSTANCE_ID * 3), see `ParticlePool.data`:
##       texel 0: r g b a    tint 0..1 (additive pool: tint is NOT premultiplied) and peak alpha 0..1
##       texel 1: vx vy s0 s1  velocity px/s (-1024..1024), size at birth / death px (0..SIZE_CAP)
##       texel 2: birth life kind spare  birth on the 32 s wrapping clock (1/64 s steps), life s (0 = dead slot),
##                kind id (small integer, decoded with floor(x + 0.5))
##
## Precision budget (float32 is exact for all of these; the same table shows the fp16 worst case in case a driver
## stores or reads the texture as halves, 11-bit mantissa = relative error 2^-11):
##   tint / alpha 0..1        error <= 0.0005 (invisible, 8-bit output step is 0.0039)
##   velocity +-1024 px/s     error <= 0.5 px/s, over a 2 s life <= 1 px
##   size 0..1800 px          error <= 0.5 px at 1024..2048, <= 0.06 px below 128
##   birth 0..32 s            error <= 0.016 s above 16 s (one frame), exact multiples of 1/64 s below 16 s
##   life 1/64..127/64 s      error <= 0.001 s
##   kind 0..31               exact (integers <= 2048 are exact in a half)
## Rotation, spin, drag and the "align to velocity" flag are per KIND tables in the shader (and a hash of the
## instance id for the start angle / spin sign), so they cost no data.

const FLOATS: int = 8  ## MultiMesh buffer floats per instance (transform only)
## Floats per particle in the data texture and RGBA texels per particle.
const DATA_FLOATS: int = 12
const TEXELS: int = 3
## Float offsets inside one particle's data record.
const D_R: int = 0
const D_G: int = 1
const D_B: int = 2
const D_A: int = 3
const D_VX: int = 4
const D_VY: int = 5
const D_S0: int = 6
const D_S1: int = 7
const D_BIRTH: int = 8
const D_LIFE: int = 9
const D_KIND: int = 10
## The shader clock wraps every CLOCK_PERIOD_S seconds; the pool clears expired slots at least every SWEEP_S so a
## dead particle can never come back around.
const CLOCK_STEPS: float = 64.0
const CLOCK_PERIOD_S: float = 32.0
const CLOCK_RANGE: int = 2048
const SWEEP_S: float = 8.0
const LIFE_STEPS: float = 64.0
const LIFE_MAX_S: float = 127.0 / 64.0
const VEL_MAX: float = 1024.0
## Largest legitimate particle size in px (Cinder's death flash is 1800 px at most). The shader repeats this cap
## as SIZE_CAP so a corrupt value can never draw a screen-filling glow.
const SIZE_MAX: float = 1800.0

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


## Birth as the shader reads it: seconds on the wrapping clock, a multiple of 1/64 s.
static func clock_birth(sim_seconds: float) -> float:
	return float(clock_units(sim_seconds)) / CLOCK_STEPS


## Value of the shader's `u_now` for a sim time (seconds on the wrapping clock).
static func clock_now(sim_seconds: float) -> float:
	return fposmod(sim_seconds, CLOCK_PERIOD_S)


## Life in seconds as stored: a multiple of 1/64 s in [1/64, LIFE_MAX_S].
static func life_seconds(life_s: float) -> float:
	return float(clampi(roundi(life_s * LIFE_STEPS), 1, 127)) / LIFE_STEPS


static func clamp_vel(v: float) -> float:
	return clampf(v, -VEL_MAX, VEL_MAX)


static func clamp_size(px: float) -> float:
	return clampf(px, 0.0, SIZE_MAX)
