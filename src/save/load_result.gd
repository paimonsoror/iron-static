class_name LoadResult
extends RefCounted
## Outcome of `SaveStore.load` (M3-02).

enum Status { OK, FRESH, RECOVERED, CORRUPT, TOO_NEW }

var status: Status = Status.FRESH
## "live", "bak" or "tmp" (empty for FRESH, CORRUPT, TOO_NEW).
var source: String = ""
var schema: int = 0
var raw: PackedByteArray = PackedByteArray()
## For TOO_NEW: the newer schema found in the file.
var found_schema: int = 0


func has_data() -> bool:
	return status == Status.OK or status == Status.RECOVERED
