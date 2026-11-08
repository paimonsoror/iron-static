class_name BillingStub
extends BillingService
## Desktop/headless billing: no store. Every call that needs a store reports BILLING_UNAVAILABLE (3).

const BILLING_UNAVAILABLE: int = 3


func backend_name() -> String:
	return "stub"


func connect_store() -> void:
	error.emit(BILLING_UNAVAILABLE, "billing stub: no store on this platform")


func query_products(_ids: PackedStringArray) -> void:
	error.emit(BILLING_UNAVAILABLE, "billing stub: no store on this platform")


func purchase(_id: String) -> void:
	error.emit(BILLING_UNAVAILABLE, "billing stub: no store on this platform")


func consume(_token: String) -> void:
	error.emit(BILLING_UNAVAILABLE, "billing stub: no store on this platform")
