class_name TestBillingStub
extends GdUnitTestSuite
## BillingStub (desktop/headless) reports no store.


func test_stub_is_unavailable() -> void:
	var billing: BillingService = BillingStub.new()
	assert_bool(billing.is_available()).is_false()
