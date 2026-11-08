class_name Backend
extends RefCounted
## Backend facade interface (TECH_ARCHITECTURE 6.2, Launch scope). Real impl: Nakama (M7); desktop and
## headless use BackendOffline. Every call is awaitable and returns a result Dictionary:
## `{"ok": bool, "error": String, "data": Dictionary}`; `request_completed` mirrors it for fire-and-forget use.

signal request_completed(operation: String, result: Dictionary)

const ERR_NOT_IMPLEMENTED: String = "not_implemented"
const ERR_OFFLINE: String = "offline"


## Device-id auth on first launch (optionally linked to a Play Games identity token later).
func authenticate(_device_id: String) -> Dictionary:
	return _fail("authenticate")


## Reads storage object `saves/profile`; `data` holds `blob` (String) and `revision` (int).
func cloud_save_read() -> Dictionary:
	return _fail("cloud_save_read")


## OCC write of `saves/profile`; `expected_revision` is the revision this save last synced from.
func cloud_save_write(_blob: String, _expected_revision: int) -> Dictionary:
	return _fail("cloud_save_write")


func leaderboard_submit(_board_id: String, _score: int) -> Dictionary:
	return _fail("leaderboard_submit")


func leaderboard_list(_board_id: String, _limit: int) -> Dictionary:
	return _fail("leaderboard_list")


## Fetches the `config/live` overlay (version, overrides, flags, events).
func remote_config_fetch() -> Dictionary:
	return _fail("remote_config_fetch")


## `iap_validate` RPC: server verifies the Play purchase token; the client acknowledges only on ok.
func iap_validate(_product_id: String, _purchase_token: String) -> Dictionary:
	return _fail("iap_validate")


func _ok(operation: String, data: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": true, "error": "", "data": data}
	request_completed.emit(operation, result)
	return result


func _fail(operation: String, error: String = ERR_NOT_IMPLEMENTED) -> Dictionary:
	var result: Dictionary = {"ok": false, "error": error, "data": {}}
	request_completed.emit(operation, result)
	return result
