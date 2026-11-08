extends Node
## Autoload `Services`: picks the billing and ads implementation at runtime (Android plugin when its
## singleton exists, desktop stub otherwise) and runs the M0 plugin probes on Android.

var billing: BillingService
var ads: AdsService


func _ready() -> void:
	billing = _make_billing()
	ads = _make_ads()
	Log.info("services: billing=" + billing.backend_name() + " ads=" + ads.backend_name())
	if OS.get_name() == "Android":
		_probe_billing()
		_probe_ads()


func _make_billing() -> BillingService:
	if OS.get_name() == "Android" and Engine.has_singleton(BillingAndroid.SINGLETON):
		return BillingAndroid.new()
	return BillingStub.new()


func _make_ads() -> AdsService:
	if OS.get_name() == "Android" and Engine.has_singleton(AdsAndroid.SINGLETON):
		return AdsAndroid.new()
	return AdsStub.new()


func _probe_billing() -> void:
	var found: bool = Engine.has_singleton(BillingAndroid.SINGLETON)
	Log.info("probe billing: singleton " + BillingAndroid.SINGLETON + " found=" + str(found))
	billing.connected.connect(func() -> void: Log.info("probe billing: connected event"))
	billing.error.connect(_on_billing_error)
	billing.connect_store()


func _probe_ads() -> void:
	var found: bool = Engine.has_singleton(AdsAndroid.SINGLETON)
	Log.info("probe ads: singleton " + AdsAndroid.SINGLETON + " found=" + str(found))
	ads.initialized.connect(_on_ads_initialized)
	ads.rewarded_ready.connect(func(p: String) -> void: Log.info("probe ads: rewarded loaded placement=" + p))
	ads.failed.connect(func(code: int) -> void: Log.warn("probe ads: failed code=" + str(code)))
	ads.initialize()


func _on_ads_initialized() -> void:
	Log.info("probe ads: initialized")
	ads.load_rewarded("probe")


func _on_billing_error(code: int, msg: String) -> void:
	Log.warn("probe billing: error code=" + str(code) + " msg=" + msg)
