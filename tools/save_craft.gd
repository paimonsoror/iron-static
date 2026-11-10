extends SceneTree
## Verification helper (M3-19/32, M4-12): re-encode a profile (schema 2) with edits.
## Usage: godot --headless --path <project> -s res://tools/save_craft.gd -- <in.sav> <out.sav> <op> [value]
## ops: bestwave N (sets best_wave["1"] and best_wave_by_mode["timed"]["1"]) | purgebest N (PURGE record)
##      | modeflag ID (pending one-time mode-unlock chip) | frames (unlock all implemented, select striker)
##      | frames2 | select ID | schema N (re-stamp schema u16)
##      | lastmode ID (TIMED best 20, ID unlocked and preselected; M4-28 stress run)


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var f: FileAccess = FileAccess.open(a[0], FileAccess.READ)
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var dec: DecodeResult = SaveCodec.decode("ISAV", bytes, SaveStore.ANY_SCHEMA)
	if dec.status != DecodeResult.Status.OK:
		print("CRAFT ERROR decode ", dec.status)
		quit(2)
		return
	var doc: Dictionary = SaveSchema.parse_raw(dec.raw)
	var schema: int = dec.schema
	var op: String = a[2]
	var prof: Dictionary = doc["profile"]
	if op == "bestwave":
		var bw: Dictionary = prof.get("best_wave", {})
		bw["1"] = int(a[3])
		prof["best_wave"] = bw
		var by_mode: Dictionary = prof.get("best_wave_by_mode", {})
		var timed: Dictionary = by_mode.get("timed", {})
		timed["1"] = int(a[3])
		by_mode["timed"] = timed
		prof["best_wave_by_mode"] = by_mode
	elif op == "purgebest":
		var by_mode2: Dictionary = prof.get("best_wave_by_mode", {})
		var purge: Dictionary = by_mode2.get("purge", {})
		purge["1"] = int(a[3])
		by_mode2["purge"] = purge
		prof["best_wave_by_mode"] = by_mode2
	elif op == "modeflag":
		prof["mode_unlock_pending"] = [a[3]]
	elif op == "frames":
		prof["frames_unlocked"] = ["vanguard", "bulwark", "striker"]
		prof["frame_selected"] = "striker"
	elif op == "frames2":
		prof["frames_unlocked"] = ["vanguard", "bulwark"]
	elif op == "select":
		prof["frame_selected"] = a[3]
	elif op == "lastmode":
		var bm: Dictionary = prof.get("best_wave_by_mode", {})
		var tm: Dictionary = bm.get("timed", {})
		tm["1"] = 20
		bm["timed"] = tm
		prof["best_wave_by_mode"] = bm
		prof["last_mode"] = a[3]
		prof["modes_unlocked"] = ["timed", a[3]]
	elif op == "schema":
		schema = int(a[3])
	var out: PackedByteArray = SaveCodec.encode("ISAV", schema, SaveSchema.raw_from_document(doc))
	var w: FileAccess = FileAccess.open(a[1], FileAccess.WRITE)
	w.store_buffer(out)
	w.close()
	print("CRAFT OK ", op, " bytes=", out.size())
	quit(0)
