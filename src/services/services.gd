extends Node
## Autoload `Services`: picks the billing and ads implementation at runtime (Android plugin when its
## singleton exists, desktop stub otherwise). The M0 plugin probe (connect store, init ads, load one
## rewarded test ad) runs only in a debug build on Android when the user arg `--probe-services` is given:
## Android strips intent extras sent to the exported launcher, so bake the arg into the build: set the
## export preset option `command_line/extra_args` to `-- --probe-services`, deploy, then revert it (never commit).

const PROBE_ARG: String = "--probe-services"
## The Android implementations are loaded by path, never named: the beta export (B1-04) leaves the plugin addons and
## these two scripts out, so a hard reference would be a parse error there. Missing script or singleton = stub.
const BILLING_SCRIPT: String = "res://src/services/billing/billing_android.gd"
const ADS_SCRIPT: String = "res://src/services/ads/ads_android.gd"
const BILLING_SINGLETON: String = "GodotGooglePlayBilling"
const ADS_SINGLETON: String = "PoingGodotAdMob"

var billing: BillingService
var ads: AdsService


func _ready() -> void:
	billing = _make_billing()
	ads = _make_ads()
	Log.info("services: billing=" + billing.backend_name() + " ads=" + ads.backend_name())
	if _probe_requested():
		Log.info("services: boot probe requested")
		_probe_billing()
		_probe_ads()


func _probe_requested() -> bool:
	return OS.get_name() == "Android" and OS.is_debug_build() and PROBE_ARG in OS.get_cmdline_user_args()


func _make_billing() -> BillingService:
	if OS.get_name() == "Android" and Engine.has_singleton(BILLING_SINGLETON) and ResourceLoader.exists(BILLING_SCRIPT):
		var script: GDScript = load(BILLING_SCRIPT) as GDScript
		var made: Object = script.new()
		if made is BillingService:
			return made as BillingService
	return BillingStub.new()


func _make_ads() -> AdsService:
	if OS.get_name() == "Android" and Engine.has_singleton(ADS_SINGLETON) and ResourceLoader.exists(ADS_SCRIPT):
		var script: GDScript = load(ADS_SCRIPT) as GDScript
		var made: Object = script.new()
		if made is AdsService:
			return made as AdsService
	return AdsStub.new()


func _probe_billing() -> void:
	var found: bool = Engine.has_singleton(BILLING_SINGLETON)
	Log.info("probe billing: singleton " + BILLING_SINGLETON + " found=" + str(found))
	billing.connected.connect(func() -> void: Log.info("probe billing: connected event"))
	billing.error.connect(_on_billing_error)
	billing.connect_store()


func _probe_ads() -> void:
	var found: bool = Engine.has_singleton(ADS_SINGLETON)
	Log.info("probe ads: singleton " + ADS_SINGLETON + " found=" + str(found))
	ads.initialized.connect(_on_ads_initialized)
	ads.rewarded_ready.connect(func(p: String) -> void: Log.info("probe ads: rewarded loaded placement=" + p))
	ads.failed.connect(func(code: int) -> void: Log.warn("probe ads: failed code=" + str(code)))
	ads.initialize()


func _on_ads_initialized() -> void:
	Log.info("probe ads: initialized")
	ads.load_rewarded("probe")


func _on_billing_error(code: int, msg: String) -> void:
	Log.warn("probe billing: error code=" + str(code) + " msg=" + msg)
