class_name TestSaveCodec
extends GdUnitTestSuite
## SaveCodec container and SaveKey (M3-01).

const MAGIC: String = "ISAV"
const MAX_SCHEMA: int = 3
const GOLDEN_FOOTER: String = "c217c8be17fa1c8cf3a371f69d653abfdb8dba76b11d7a5101afba356e0fae0a"


func after_test() -> void:
	SaveKey.reset()


func _bytes(n: int, seed_v: int) -> PackedByteArray:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var b: PackedByteArray = PackedByteArray()
	b.resize(n)
	for i: int in n:
		# Mildly compressible: small alphabet with runs.
		b[i] = rng.randi_range(0, 15) if floori(float(i) / 7.0) % 2 == 0 else 65
	return b


func _fixed_key() -> PackedByteArray:
	var k: PackedByteArray = PackedByteArray()
	k.resize(32)
	for i: int in 32:
		k[i] = i
	return k


func test_round_trip_sizes() -> void:
	for n: int in [0, 1, 1024, 300 * 1024]:
		var raw: PackedByteArray = _bytes(n, n + 1)
		var r: DecodeResult = SaveCodec.decode(MAGIC, SaveCodec.encode(MAGIC, 2, raw), MAX_SCHEMA)
		assert_int(r.status).is_equal(DecodeResult.Status.OK)
		assert_int(r.schema).is_equal(2)
		assert_bool(r.raw == raw).is_true()


func test_single_bit_flips_never_ok() -> void:
	var enc: PackedByteArray = SaveCodec.encode(MAGIC, 1, _bytes(2000, 5))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var positions: Array[int] = [0, 3, 4, 5, 6, 9, 10, 13, 14, enc.size() - 1, enc.size() - 32, enc.size() - 33]
	while positions.size() < 20:
		positions.append(rng.randi_range(0, enc.size() - 1))
	for p: int in positions:
		var m: PackedByteArray = enc.duplicate()
		m[p] = m[p] ^ (1 << rng.randi_range(0, 7))
		var st: int = SaveCodec.decode(MAGIC, m, MAX_SCHEMA).status
		assert_bool(st != DecodeResult.Status.OK).is_true()
		(
			assert_bool(
				st in [DecodeResult.Status.BAD_HMAC, DecodeResult.Status.BAD_MAGIC, DecodeResult.Status.TRUNCATED]
			)
			. is_true()
		)


func test_truncation_0_to_40() -> void:
	var enc: PackedByteArray = SaveCodec.encode(MAGIC, 1, _bytes(100, 1))
	for n: int in range(0, 41):
		var st: int = SaveCodec.decode(MAGIC, enc.slice(0, n), MAX_SCHEMA).status
		assert_bool(st in [DecodeResult.Status.TRUNCATED, DecodeResult.Status.BAD_MAGIC]).is_true()
	# Shortened by one byte anywhere is never OK either.
	var st2: int = SaveCodec.decode(MAGIC, enc.slice(0, enc.size() - 1), MAX_SCHEMA).status
	assert_bool(st2 != DecodeResult.Status.OK).is_true()


func test_wrong_magic() -> void:
	var enc: PackedByteArray = SaveCodec.encode("ISNP", 1, _bytes(50, 1))
	assert_int(SaveCodec.decode(MAGIC, enc, MAX_SCHEMA).status).is_equal(DecodeResult.Status.BAD_MAGIC)


func test_different_key_gives_bad_hmac() -> void:
	SaveKey.override(_fixed_key())
	var enc: PackedByteArray = SaveCodec.encode(MAGIC, 1, _bytes(300, 2))
	assert_int(SaveCodec.decode(MAGIC, enc, MAX_SCHEMA).status).is_equal(DecodeResult.Status.OK)
	SaveKey.reset()
	assert_int(SaveCodec.decode(MAGIC, enc, MAX_SCHEMA).status).is_equal(DecodeResult.Status.BAD_HMAC)


func test_too_new_schema_is_precise() -> void:
	var enc: PackedByteArray = SaveCodec.encode(MAGIC, MAX_SCHEMA + 1, _bytes(300, 2))
	var r: DecodeResult = SaveCodec.decode(MAGIC, enc, MAX_SCHEMA)
	assert_int(r.status).is_equal(DecodeResult.Status.TOO_NEW)
	assert_int(r.schema).is_equal(MAX_SCHEMA + 1)


func test_raw_len_bomb_is_bad_payload() -> void:
	var enc: PackedByteArray = SaveCodec.encode(MAGIC, 1, _bytes(300, 2))
	var body: PackedByteArray = enc.slice(0, enc.size() - 32)
	body.encode_u32(6, 16 * 1024 * 1024 + 1)
	var c: Crypto = Crypto.new()
	body.append_array(c.hmac_digest(HashingContext.HASH_SHA256, SaveKey.bytes(), body))
	assert_int(SaveCodec.decode(MAGIC, body, MAX_SCHEMA).status).is_equal(DecodeResult.Status.BAD_PAYLOAD)
	# A lying raw_len below the real size (valid HMAC) is BAD_PAYLOAD too.
	var body2: PackedByteArray = enc.slice(0, enc.size() - 32)
	body2.encode_u32(6, 10)
	body2.append_array(c.hmac_digest(HashingContext.HASH_SHA256, SaveKey.bytes(), body2))
	assert_int(SaveCodec.decode(MAGIC, body2, MAX_SCHEMA).status).is_equal(DecodeResult.Status.BAD_PAYLOAD)


func test_random_bytes_never_crash() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 1000:
		var b: PackedByteArray = PackedByteArray()
		b.resize(rng.randi_range(0, 200))
		for j: int in b.size():
			b[j] = rng.randi_range(0, 255)
		if i % 3 == 0 and b.size() >= 4:
			b.set(0, 73)  # 'I'
			b.set(1, 83)  # 'S'
			b.set(2, 65)  # 'A'
			b.set(3, 86)  # 'V'
		assert_bool(SaveCodec.decode(MAGIC, b, MAX_SCHEMA).status != DecodeResult.Status.OK).is_true()


func test_speed_300kb_informational() -> void:
	var raw: PackedByteArray = _bytes(300 * 1024, 3)
	var t0: int = Time.get_ticks_usec()
	var r: DecodeResult = SaveCodec.decode(MAGIC, SaveCodec.encode(MAGIC, 1, raw), MAX_SCHEMA)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("save codec 300 KB round trip: %.2f ms" % ms)
	assert_bool(r.raw == raw).is_true()


func test_save_key() -> void:
	var def: PackedByteArray = SaveKey.bytes()
	assert_int(def.size()).is_equal(32)
	SaveKey.override(_fixed_key())
	assert_bool(SaveKey.bytes() == _fixed_key()).is_true()
	SaveKey.reset()
	assert_bool(SaveKey.bytes() == def).is_true()


func test_golden_footer_pins_format() -> void:
	SaveKey.override(_fixed_key())
	var enc: PackedByteArray = SaveCodec.encode(MAGIC, 1, "IRON STATIC golden".to_utf8_buffer())
	var footer: String = enc.slice(enc.size() - 32).hex_encode()
	assert_int(enc.size()).is_equal(73)
	assert_str(footer).is_equal(GOLDEN_FOOTER)


func test_json_helpers() -> void:
	var d: Dictionary = {"a": 5, "b": 1.5, "c": "x", "n": {"k": [1, 2, 3]}, "big": "1.5e12"}
	var enc: PackedByteArray = SaveCodec.encode_json(MAGIC, 1, d)
	var r: DecodeResult = SaveCodec.decode_json(MAGIC, enc, MAX_SCHEMA)
	assert_int(r.status).is_equal(DecodeResult.Status.OK)
	assert_int(typeof(r.data["a"])).is_equal(TYPE_INT)
	assert_float(r.data["b"]).is_equal(1.5)
	assert_str(r.data["big"]).is_equal("1.5e12")
	var nested: Dictionary = r.data["n"]
	var arr: Array = nested["k"]
	assert_int(typeof(arr[0])).is_equal(TYPE_INT)


func test_json_garbage_is_bad_payload() -> void:
	var enc: PackedByteArray = SaveCodec.encode(MAGIC, 1, "{not json".to_utf8_buffer())
	assert_int(SaveCodec.decode_json(MAGIC, enc, MAX_SCHEMA).status).is_equal(DecodeResult.Status.BAD_PAYLOAD)
	var enc2: PackedByteArray = SaveCodec.encode(MAGIC, 1, "[1,2]".to_utf8_buffer())
	assert_int(SaveCodec.decode_json(MAGIC, enc2, MAX_SCHEMA).status).is_equal(DecodeResult.Status.BAD_PAYLOAD)
