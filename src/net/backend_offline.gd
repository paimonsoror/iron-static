class_name BackendOffline
extends Backend
## Desktop/headless/no-network stub: auth succeeds locally, saves live in memory, everything else is offline.

var _blob: String = ""
var _revision: int = 0


func authenticate(device_id: String) -> Dictionary:
	return _ok("authenticate", {"user_id": "offline-" + device_id})


func cloud_save_read() -> Dictionary:
	return _ok("cloud_save_read", {"blob": _blob, "revision": _revision})


func cloud_save_write(blob: String, expected_revision: int) -> Dictionary:
	if expected_revision != _revision:
		return _fail("cloud_save_write", "revision_conflict")
	_blob = blob
	_revision += 1
	return _ok("cloud_save_write", {"revision": _revision})


func leaderboard_submit(_board_id: String, _score: int) -> Dictionary:
	return _fail("leaderboard_submit", Backend.ERR_OFFLINE)


func leaderboard_list(_board_id: String, _limit: int) -> Dictionary:
	return _fail("leaderboard_list", Backend.ERR_OFFLINE)


func remote_config_fetch() -> Dictionary:
	return _fail("remote_config_fetch", Backend.ERR_OFFLINE)


func iap_validate(_product_id: String, _purchase_token: String) -> Dictionary:
	return _fail("iap_validate", Backend.ERR_OFFLINE)
