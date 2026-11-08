class_name AdsAndroid
extends AdsService
## AdMob rewarded ads + UMP consent via the Poing Studios plugin (addons/admob, v5.1.0).
## Only create this when `Engine.has_singleton(SINGLETON)` is true (see `Services`).
## TEST IDS ONLY: real ids never go into git (CLAUDE.md). The app id lives in Project Settings
## `admob/general/android/app_id` (plugin default is Google's test app id, same value as below).

const SINGLETON: String = "PoingGodotAdMob"
## Google's published sample rewarded unit (developers.google.com/admob/android/test-ads).
const TEST_REWARDED_UNIT: String = "ca-app-pub-3940256099942544/5224354917"
const CODE_LOCAL: int = -1

var _initializing: bool = false
var _is_initialized: bool = false
var _loader: RewardedAdLoader
var _ad: RewardedAd
var _loading_placement: String = ""
var _showing_placement: String = ""


func is_available() -> bool:
	return Engine.has_singleton(SINGLETON)


func backend_name() -> String:
	return "poing-admob-" + MobileAds.get_version() + " (" + MobileAds.get_platform_version() + ")"


func initialize() -> void:
	if _is_initialized or _initializing:
		return
	_initializing = true
	Log.info("ads: singleton " + SINGLETON + " found=" + str(is_available()) + ", requesting consent info")
	# Consent first (architecture 7.3). Outside the EEA/UK the status is NOT_REQUIRED and no form is shown.
	var params := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(params, _on_consent_info_updated, _on_consent_info_failed)


func load_rewarded(placement: String) -> void:
	if not _is_initialized:
		Log.warn("ads: load_rewarded before initialize")
		failed.emit(CODE_LOCAL)
		return
	_loading_placement = placement
	_loader = RewardedAdLoader.new()
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = _on_ad_loaded
	callback.on_ad_failed_to_load = _on_ad_failed_to_load
	Log.info("ads: load rewarded placement=" + placement + " unit=" + TEST_REWARDED_UNIT)
	_loader.load(TEST_REWARDED_UNIT, AdRequest.new(), callback)


func show_rewarded(placement: String) -> void:
	if _ad == null:
		Log.warn("ads: show_rewarded with no loaded ad")
		failed.emit(CODE_LOCAL)
		return
	_showing_placement = placement
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = _on_user_earned_reward
	_ad.show(listener)


func _on_consent_info_updated() -> void:
	var info: ConsentInformation = UserMessagingPlatform.consent_information
	var status: int = info.get_consent_status()
	Log.info("ads: consent info updated, status=" + str(status) + " (1=NOT_REQUIRED, 2=REQUIRED, 3=OBTAINED)")
	if status == ConsentInformation.ConsentStatus.REQUIRED and info.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_form_loaded, _on_form_failed)
	else:
		_init_sdk()


func _on_consent_info_failed(error: FormError) -> void:
	Log.warn("ads: consent info update failed [" + str(error.error_code) + "] " + error.message)
	_init_sdk()


func _on_form_loaded(form: ConsentForm) -> void:
	form.show(_on_form_dismissed)


func _on_form_failed(error: FormError) -> void:
	Log.warn("ads: consent form load failed [" + str(error.error_code) + "] " + error.message)
	_init_sdk()


func _on_form_dismissed(error: FormError) -> void:
	if error != null:
		Log.warn("ads: consent form dismissed with error [" + str(error.error_code) + "] " + error.message)
	_init_sdk()


func _init_sdk() -> void:
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_initialization_complete
	MobileAds.initialize(listener)


func _on_initialization_complete(status: InitializationStatus) -> void:
	_initializing = false
	_is_initialized = true
	Log.info("ads: initialization complete, adapters=" + str(status.adapter_status_map.keys()))
	initialized.emit()


func _on_ad_loaded(ad: RewardedAd) -> void:
	_ad = ad
	var content := FullScreenContentCallback.new()
	content.on_ad_dismissed_full_screen_content = _on_ad_dismissed
	content.on_ad_failed_to_show_full_screen_content = _on_ad_failed_to_show
	_ad.full_screen_content_callback = content
	Log.info("ads: rewarded loaded placement=" + _loading_placement)
	rewarded_ready.emit(_loading_placement)


func _on_ad_failed_to_load(error: LoadAdError) -> void:
	Log.warn("ads: rewarded failed to load code=" + str(error.code) + " message=" + error.message)
	failed.emit(error.code)


func _on_ad_failed_to_show(error: AdError) -> void:
	Log.warn("ads: rewarded failed to show code=" + str(error.code) + " message=" + error.message)
	_ad = null
	failed.emit(error.code)


func _on_ad_dismissed() -> void:
	_ad = null


func _on_user_earned_reward(item: RewardedItem) -> void:
	Log.info("ads: reward earned amount=" + str(item.amount) + " type=" + item.type)
	reward_earned.emit(_showing_placement)
