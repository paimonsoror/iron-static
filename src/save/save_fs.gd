class_name SaveFs
extends RefCounted
## File access interface for the save layer (M3-02). Implementations: `MemorySaveFs` (tests, fault
## injection) and `DiskSaveFs` (`src/core/`, `user://save/`). `SaveStore` touches files only through this.

## File bytes; an empty array means missing (or unreadable).
@warning_ignore("unused_parameter")
func read(path: String) -> PackedByteArray:  # gdlint: ignore=unused-argument
	return PackedByteArray()


## Create or truncate `path`, flush and close. False on any failure.
@warning_ignore("unused_parameter")
func write(path: String, bytes: PackedByteArray) -> bool:  # gdlint: ignore=unused-argument
	return false


## Move `from` onto `to`, replacing an existing target. False on failure.
@warning_ignore("unused_parameter")
func rename(from: String, to: String) -> bool:  # gdlint: ignore=unused-argument
	return false


@warning_ignore("unused_parameter")
func remove(path: String) -> bool:  # gdlint: ignore=unused-argument
	return false


@warning_ignore("unused_parameter")
func exists(path: String) -> bool:  # gdlint: ignore=unused-argument
	return false
