class_name ProfileReset
extends RefCounted
## The one profile-reset path (Q66), used by NEW GAME (after its confirm) and Settings > Data: archives the old files
## as `*.reset` (`SaveService.reset_profile`), then saves the fresh profile at once so the kept settings survive a
## restart. Never deletes; settings are kept; a failed rename leaves the old profile untouched.


## True when the profile was reset. `saves` null or blocked gives false.
static func run(saves: SaveService) -> bool:
	if saves == null or not saves.reset_profile():
		return false
	# The snapshot files were archived with the profile; the in-memory resume must go too, or the first DEPLOY of
	# the new game would resume the old run (boot now waits on the title with a resume pending).
	Game.discard_pending_resume()
	@warning_ignore("return_value_discarded")  # a failed write is retried by the scheduler; the reset itself held
	saves.save_now()
	return true
