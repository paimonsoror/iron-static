extends SceneTree
## Decodes a save container with the real key and prints it (M3-04). Run through tools\save_dump.ps1.
## Usage: godot --headless -s res://tools/save_dump.gd -- <file.sav|.bak|run_snapshot.sav>
## Profile files print the JSON document; run snapshots print the header (SnapshotInfo) as JSON.
## Prints "SAVE DUMP OK" on success, "SAVE DUMP ERROR: <reason>" otherwise (wrapper exit 2).


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		print("SAVE DUMP ERROR: usage: save_dump.ps1 <file>")
		quit(2)
		return
	var path: String = args[0]
	if not FileAccess.file_exists(path):
		print("SAVE DUMP ERROR: no such file " + path)
		quit(2)
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var magic: String = bytes.slice(0, 4).get_string_from_ascii()
	if magic != SaveCodec.MAGIC_PROFILE and magic != SaveCodec.MAGIC_SNAPSHOT:
		print("SAVE DUMP ERROR: unknown magic '%s'" % magic)
		quit(2)
		return
	var dec: DecodeResult = SaveCodec.decode(magic, bytes, SaveStore.ANY_SCHEMA)
	if dec.status != DecodeResult.Status.OK:
		print("SAVE DUMP ERROR: %s" % DecodeResult.Status.keys()[dec.status])
		quit(2)
		return
	if magic == SaveCodec.MAGIC_PROFILE:
		var doc: Dictionary = SaveSchema.parse_raw(dec.raw)
		if doc.is_empty():
			print("SAVE DUMP ERROR: payload is not a JSON object")
			quit(2)
			return
		print(JSON.stringify(doc, "\t"))
		print(_mode_summary(doc))
	else:
		var info: SnapshotInfo = SimSnapshot.peek(dec.raw)
		if info == null:
			print("SAVE DUMP ERROR: not a run snapshot")
			quit(2)
			return
		print(JSON.stringify(_info_dict(info), "\t"))
	print("SAVE DUMP OK schema=%d bytes=%d" % [dec.schema, bytes.size()])
	quit(0)


## One line with the wave mode fields of a (v2) profile document; v1 documents print what is there.
func _mode_summary(doc: Dictionary) -> String:
	var raw: Variant = doc.get("profile", {})
	var prof: Dictionary = raw if raw is Dictionary else {}
	return (
		"modes: unlocked=%s last=%s best_by_mode=%s best_wave(timed mirror)=%s"
		% [
			JSON.stringify(prof.get("modes_unlocked", [])),
			JSON.stringify(prof.get("last_mode", "")),
			JSON.stringify(prof.get("best_wave_by_mode", {})),
			JSON.stringify(prof.get("best_wave", {})),
		]
	)


func _info_dict(i: SnapshotInfo) -> Dictionary:
	return {
		"format": i.format,
		"sim_version": i.sim_version,
		"config_hash": i.config_hash,
		"seed": i.seed_value,
		"run_id": i.run_id,
		"tick": i.tick,
		"wave": i.wave,
		"data_run": i.data_run,
		"frame_id": i.frame_id,
		"sector": i.sector,
		"best_wave_s1": i.best_wave_s1,
		"ruleset": i.ruleset,
		"debug_invulnerable": i.debug_invulnerable,
	}
