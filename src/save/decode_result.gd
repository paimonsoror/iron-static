class_name DecodeResult
extends RefCounted
## Outcome of `SaveCodec.decode` / `decode_json` (M3-01).

enum Status { OK, TRUNCATED, BAD_MAGIC, BAD_HMAC, BAD_PAYLOAD, TOO_NEW }

var status: Status = Status.TRUNCATED
## Schema version from the header (valid for OK and TOO_NEW; 0 otherwise).
var schema: int = 0
## Decompressed payload bytes (OK only).
var raw: PackedByteArray = PackedByteArray()
## Parsed JSON object (`decode_json` and status OK only). (impl) lives here instead of a bare Dictionary
## return so the caller also gets the status.
var data: Dictionary = {}


func is_ok() -> bool:
	return status == Status.OK


static func make(st: Status) -> DecodeResult:
	var r: DecodeResult = DecodeResult.new()
	r.status = st
	return r
