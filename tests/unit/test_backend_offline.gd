class_name TestBackendOffline
extends GdUnitTestSuite


func test_cloud_save_conflict_when_revision_is_stale() -> void:
	var backend: Backend = BackendOffline.new()
	backend.cloud_save_write("blob", 0)
	var stale: Dictionary = backend.cloud_save_write("other", 0)
	assert_str(str(stale["error"])).is_equal("revision_conflict")
