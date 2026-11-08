class_name SaveKey
extends RefCounted
## HMAC-SHA256 key of the save container (TECH_ARCHITECTURE 5.1, M3 "HMAC key decision").
##
## THIS IS NOT A SECRET. The key is source code: anyone who reads the repo or unpacks the APK can
## recompute a footer. It is split across XOR-masked constants only to stop casual file or memory
## editing. It is not in the "no secrets in git" category and must never be reused for the backend
## or any server-side verification. A release build may later `override()` it with a per-build key
## loaded from the ignored `secrets.local.json` (field `save_hmac_key`).

const KEY_SIZE: int = 32
# Four 8-byte parts, each stored as (part XOR mask). Top bit kept clear so literals stay positive.
const _PART_A: int = 5237916604883120817
const _MASK_A: int = 2981403362177468211
const _PART_B: int = 1192843760115544036
const _MASK_B: int = 6403527155108932501
const _PART_C: int = 8472950264105817363
const _MASK_C: int = 3318860472911406728
const _PART_D: int = 2745190573869921490
const _MASK_D: int = 7611283549038216175

static var _override: PackedByteArray = PackedByteArray()


## The current key (32 bytes): the test/release override when set, else the assembled default.
static func bytes() -> PackedByteArray:
	if _override.size() > 0:
		return _override.duplicate()
	return _assemble()


## Replace the key (tests, or a future ignored release key). An empty array is ignored.
static func override(b: PackedByteArray) -> void:
	_override = b.duplicate()


## Restore the built-in key.
static func reset() -> void:
	_override = PackedByteArray()


static func _assemble() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(KEY_SIZE)
	var parts: Array[int] = [_PART_A ^ _MASK_A, _PART_B ^ _MASK_B, _PART_C ^ _MASK_C, _PART_D ^ _MASK_D]
	for i: int in parts.size():
		out.encode_s64(i * 8, parts[i])
	return out
