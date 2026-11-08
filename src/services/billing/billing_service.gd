class_name BillingService
extends RefCounted
## Interface for in-app purchases (Google Play Billing). Implementations: `BillingStub`
## (desktop/headless) and `BillingAndroid` (wraps the GodotGooglePlayBilling plugin).
## Responses are the plugin's dictionaries passed through unchanged (M0 spike; typed models come with M7).

## The store connection is ready.
@warning_ignore("unused_signal")
signal connected
## Reply to `query_products`; `response` has `response_code` and `product_details`.
@warning_ignore("unused_signal")
signal products_loaded(response: Dictionary)
## A purchase finished or changed state; `response` has `response_code` and `purchases`.
@warning_ignore("unused_signal")
signal purchase_updated(response: Dictionary)
## Any failure: `code` is a Play BillingResponseCode (or -1 for local failures).
@warning_ignore("unused_signal")
signal error(code: int, message: String)


## True when a native store implementation is active (false for the desktop stub).
func is_available() -> bool:
	return false


## Short name of the implementation, for logs.
func backend_name() -> String:
	return "none"


func connect_store() -> void:
	pass


func query_products(_ids: PackedStringArray) -> void:
	pass


func purchase(_id: String) -> void:
	pass


func consume(_token: String) -> void:
	pass
