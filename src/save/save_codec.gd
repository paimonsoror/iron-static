class_name SaveCodec
extends RefCounted
## Signed, compressed container for every persisted blob (TECH_ARCHITECTURE 5.1, M3-01).
##
## Layout (little endian): magic(4) schema u16 | raw_len u32 | payload_len u32 | payload | hmac(32).
## payload = zstd(raw); hmac = HMAC-SHA256(SaveKey, header + payload).
## Decode order: length, magic, HMAC (constant time), lengths, decompress, TOO_NEW.

const HEADER_SIZE: int = 14
const FOOTER_SIZE: int = 32
const MAX_RAW_LEN: int = 16 * 1024 * 1024
const MAGIC_PROFILE: String = "ISAV"
const MAGIC_SNAPSHOT: String = "ISNP"


## Build a container. Returns an empty array when `magic` is not 4 ASCII chars or `schema` is out of u16 range.
static func encode(magic: String, schema: int, raw: PackedByteArray) -> PackedByteArray:
	var mb: PackedByteArray = magic.to_ascii_buffer()
	if mb.size() != 4 or schema < 0 or schema > 0xFFFF or raw.size() > MAX_RAW_LEN:
		return PackedByteArray()
	var payload: PackedByteArray = PackedByteArray()
	if raw.size() > 0:  # (impl) an empty raw is stored as an empty payload (compress of empty is undefined)
		payload = raw.compress(FileAccess.COMPRESSION_ZSTD)
	var out: PackedByteArray = PackedByteArray()
	out.resize(HEADER_SIZE)
	for i: int in 4:
		out[i] = mb[i]
	out.encode_u16(4, schema)
	out.encode_u32(6, raw.size())
	out.encode_u32(10, payload.size())
	out.append_array(payload)
	out.append_array(_mac(out))
	return out


static func decode(magic: String, bytes: PackedByteArray, max_schema: int) -> DecodeResult:
	var n: int = bytes.size()
	if n < HEADER_SIZE + FOOTER_SIZE:
		return DecodeResult.make(DecodeResult.Status.TRUNCATED)
	var mb: PackedByteArray = magic.to_ascii_buffer()
	if mb.size() != 4 or bytes.slice(0, 4) != mb:
		return DecodeResult.make(DecodeResult.Status.BAD_MAGIC)
	var body: PackedByteArray = bytes.slice(0, n - FOOTER_SIZE)
	if not _equal_ct(_mac(body), bytes.slice(n - FOOTER_SIZE, n)):
		return DecodeResult.make(DecodeResult.Status.BAD_HMAC)
	var schema: int = bytes.decode_u16(4)
	var raw_len: int = bytes.decode_u32(6)
	var payload_len: int = bytes.decode_u32(10)
	if raw_len > MAX_RAW_LEN or payload_len != n - HEADER_SIZE - FOOTER_SIZE:
		return DecodeResult.make(DecodeResult.Status.BAD_PAYLOAD)
	var raw: PackedByteArray = PackedByteArray()
	if raw_len > 0:
		if payload_len == 0:
			return DecodeResult.make(DecodeResult.Status.BAD_PAYLOAD)
		raw = bytes.slice(HEADER_SIZE, HEADER_SIZE + payload_len).decompress(raw_len, FileAccess.COMPRESSION_ZSTD)
		if raw.size() != raw_len:
			return DecodeResult.make(DecodeResult.Status.BAD_PAYLOAD)
	elif payload_len != 0:
		return DecodeResult.make(DecodeResult.Status.BAD_PAYLOAD)
	if schema > max_schema:
		var t: DecodeResult = DecodeResult.make(DecodeResult.Status.TOO_NEW)
		t.schema = schema
		return t
	var r: DecodeResult = DecodeResult.make(DecodeResult.Status.OK)
	r.schema = schema
	r.raw = raw
	return r


## JSON text (UTF-8) container, used by the profile.
static func encode_json(magic: String, schema: int, d: Dictionary) -> PackedByteArray:
	return encode(magic, schema, JSON.stringify(d).to_utf8_buffer())


## Decode and parse JSON. Not an object or a parse error gives BAD_PAYLOAD. Godot's parser returns every
## number as float, so (impl) whole-valued floats below 2^53 are turned back into `int` (`_normalize`);
## models re-cast with `float()` for real float fields.
static func decode_json(magic: String, bytes: PackedByteArray, max_schema: int) -> DecodeResult:
	var r: DecodeResult = decode(magic, bytes, max_schema)
	if r.status != DecodeResult.Status.OK:
		return r
	var parser: JSON = JSON.new()  # (impl) JSON.new().parse: parse_string prints an engine error on bad input
	if parser.parse(r.raw.get_string_from_utf8()) != OK:
		r.status = DecodeResult.Status.BAD_PAYLOAD
		return r
	var parsed: Variant = _normalize(parser.data)
	if not (parsed is Dictionary):
		r.status = DecodeResult.Status.BAD_PAYLOAD
		return r
	var d: Dictionary = parsed
	r.data = d
	return r


static func _mac(data: PackedByteArray) -> PackedByteArray:
	var c: Crypto = Crypto.new()
	return c.hmac_digest(HashingContext.HASH_SHA256, SaveKey.bytes(), data)


static func _equal_ct(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	var diff: int = 0
	for i: int in a.size():
		diff |= a[i] ^ b[i]
	return diff == 0


static func _normalize(v: Variant) -> Variant:
	if v is float:
		var f: float = v
		if f == floorf(f) and absf(f) < 9007199254740992.0:
			return int(f)
		return f
	if v is Array:
		var src: Array = v
		var out_a: Array = []
		for item: Variant in src:
			out_a.append(_normalize(item))
		return out_a
	if v is Dictionary:
		var src_d: Dictionary = v
		var out_d: Dictionary = {}
		for k: Variant in src_d:
			out_d[k] = _normalize(src_d[k])
		return out_d
	return v
