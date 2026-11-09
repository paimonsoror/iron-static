class_name VersionInfo
extends RefCounted
## B1-08: the build's version name and code for display. The name is `Game.VERSION`; the code is read from
## `release/version.json` (the B1-02 single source, packed into the build). Nothing is hard-coded here.

const VERSION_PATH: String = "res://release/version.json"


## versionCode as the AAB carries it (MAJOR*1000000 + MINOR*10000 + PATCH*100 + BUILD); 0 if unreadable.
static func code() -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VERSION_PATH))
	if not parsed is Dictionary:
		return 0
	var v: Dictionary = parsed
	var major: int = v.get("major", 0)
	var minor: int = v.get("minor", 0)
	var patch: int = v.get("patch", 0)
	var build: int = v.get("build", 0)
	return major * 1000000 + minor * 10000 + patch * 100 + build


## "0.5.0-beta.1 (50001)"; just the name when the code is unreadable.
static func text() -> String:
	var c: int = code()
	if c <= 0:
		return Game.VERSION
	return "%s (%d)" % [Game.VERSION, c]
