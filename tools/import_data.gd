extends SceneTree
## CSV to .tres importer CLI (M1-02). Run through tools\import_data.ps1.
## Usage: godot --headless --path . -s res://tools/import_data.gd -- [--data-dir <dir>] [--out-dir <dir>]
## Defaults: res://data -> res://src/data_gen. Prints "IMPORT OK: ..." or "IMPORT FAILED" plus one
## "IMPORT ERROR:" line per problem (never the engine's ERROR: prefix), and quits non-zero on failure.

const DEFAULT_DATA_DIR: String = "res://data"
const DEFAULT_OUT_DIR: String = "res://src/data_gen"


func _initialize() -> void:
	var data_dir: String = DEFAULT_DATA_DIR
	var out_dir: String = DEFAULT_OUT_DIR
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		if args[i] == "--data-dir" and i + 1 < args.size():
			data_dir = args[i + 1]
			i += 2
		elif args[i] == "--out-dir" and i + 1 < args.size():
			out_dir = args[i + 1]
			i += 2
		else:
			print("IMPORT ERROR: unknown argument '%s'" % args[i])
			print("IMPORT FAILED")
			quit(2)
			return
	var importer: DataImporter = DataImporter.new()
	if importer.run(data_dir, out_dir):
		print("IMPORT OK: %d files written to %s from %s" % [importer.files.size(), out_dir, data_dir])
		quit(0)
		return
	for e: String in importer.errors:
		print("IMPORT ERROR: %s" % e)
	print("IMPORT FAILED: %d errors" % importer.errors.size())
	quit(1)
