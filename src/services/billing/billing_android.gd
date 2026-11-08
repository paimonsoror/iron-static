class_name BillingAndroid
extends BillingService
## Google Play Billing via the GodotGooglePlayBilling plugin (addons/GodotGooglePlayBilling, v3.3.0).
## Only create this when `Engine.has_singleton(SINGLETON)` is true (see `Services`).

const SINGLETON: String = "GodotGooglePlayBilling"
const CODE_LOCAL: int = -1

var _client: BillingClient
var _pending_purchase: String = ""


func _init() -> void:
	_client = BillingClient.new()
	_client.connected.connect(_on_connected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_products)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.consume_purchase_response.connect(_on_consume)
	Log.info("billing: BillingClient created, singleton found=" + str(Engine.has_singleton(SINGLETON)))


func is_available() -> bool:
	return Engine.has_singleton(SINGLETON)


func backend_name() -> String:
	return "GodotGooglePlayBilling"


func connect_store() -> void:
	Log.info("billing: start_connection")
	_client.start_connection()


func query_products(ids: PackedStringArray) -> void:
	_client.query_product_details(ids, BillingClient.ProductType.INAPP)


func purchase(id: String) -> void:
	_pending_purchase = id
	var result: Dictionary = _client.purchase(id)
	var code: int = result.get("response_code", CODE_LOCAL)
	if code != BillingClient.BillingResponseCode.OK:
		error.emit(code, "purchase(" + id + ") failed to launch: " + str(result.get("debug_message", "")))


func consume(token: String) -> void:
	_client.consume_purchase(token)


func _on_connected() -> void:
	Log.info("billing: connected")
	connected.emit()


func _on_connect_error(code: int, message: String) -> void:
	Log.warn("billing: connect_error code=" + str(code) + " message=" + message)
	error.emit(code, message)


func _on_products(response: Dictionary) -> void:
	products_loaded.emit(response)


func _on_purchase_updated(response: Dictionary) -> void:
	purchase_updated.emit(response)


func _on_consume(response: Dictionary) -> void:
	var code: int = response.get("response_code", CODE_LOCAL)
	if code != BillingClient.BillingResponseCode.OK:
		error.emit(code, "consume failed: " + str(response.get("debug_message", "")))
