class_name TestAdsStub
extends GdUnitTestSuite
## AdsStub (desktop/headless) reports no ads SDK.


func test_stub_is_unavailable() -> void:
	var ads: AdsService = AdsStub.new()
	assert_bool(ads.is_available()).is_false()
