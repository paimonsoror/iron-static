class_name TestBetaServices
extends GdUnitTestSuite
## B1-04: the beta build ships without the Billing, AdMob and Nakama plugins, so `Services` must fall back to the
## stubs, every call must be a harmless no-op, and nothing under `src/` may construct a networked backend.


func test_services_fall_back_to_stubs_without_android_singletons() -> void:
	assert_object(Services.billing).is_instanceof(BillingStub)
	assert_object(Services.ads).is_instanceof(AdsStub)
	assert_bool(Services.billing.is_available()).is_false()
	assert_bool(Services.ads.is_available()).is_false()
	assert_str(Services.billing.backend_name()).is_equal("stub")
	assert_str(Services.ads.backend_name()).is_equal("stub")


func test_stub_calls_report_unavailable_and_nothing_else() -> void:
	var billing: BillingService = BillingStub.new()
	var ads: AdsService = AdsStub.new()
	var billing_codes: Array[int] = []
	var ads_codes: Array[int] = []
	billing.error.connect(func(code: int, _m: String) -> void: billing_codes.append(code))
	ads.failed.connect(func(code: int) -> void: ads_codes.append(code))
	billing.connect_store()
	billing.query_products(PackedStringArray(["x"]))
	billing.purchase("x")
	billing.consume("t")
	ads.initialize()
	ads.load_rewarded("p")
	ads.show_rewarded("p")
	assert_int(billing_codes.size()).is_equal(4)
	assert_int(ads_codes.size()).is_equal(2)
	for code: int in billing_codes:
		assert_int(code).is_equal(BillingStub.BILLING_UNAVAILABLE)
	for code: int in ads_codes:
		assert_int(code).is_equal(AdsStub.CODE_UNAVAILABLE)


func test_no_plugin_singletons_are_registered_in_the_test_run() -> void:
	assert_bool(Engine.has_singleton(Services.BILLING_SINGLETON)).is_false()
	assert_bool(Engine.has_singleton(Services.ADS_SINGLETON)).is_false()


func test_backend_offline_never_reaches_the_network() -> void:
	var backend: Backend = BackendOffline.new()
	var res: Dictionary = backend.leaderboard_submit("b", 1)
	var ok: Variant = res.get("ok", true)
	var err: Variant = res.get("error", "")
	assert_bool(ok == false).is_true()
	assert_bool(err == Backend.ERR_OFFLINE).is_true()


func test_src_never_references_the_nakama_client() -> void:
	assert_array(_scripts_mentioning("res://src", "NakamaClient")).is_empty()


func _scripts_mentioning(dir_path: String, needle: String) -> Array[String]:
	var hits: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return hits
	for sub: String in dir.get_directories():
		hits.append_array(_scripts_mentioning(dir_path.path_join(sub), needle))
	for f: String in dir.get_files():
		if f.ends_with(".gd") and FileAccess.get_file_as_string(dir_path.path_join(f)).contains(needle):
			hits.append(dir_path.path_join(f))
	return hits
