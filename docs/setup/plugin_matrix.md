# Plugin matrix (M0-10, M0-11)

Changelog: 2026-11-07 v0.1 (M0-10/M0-11): Billing and AdMob/UMP rows. M0-12 results are in `plugin_matrix_m0-12.md` (to be merged).

Tested on Godot 4.7.2 stable, Gradle build, AVD `tower_phone` (API 35, Play Store image), debug APK.
Size baseline: Gradle APK with Services autoload + Sentry addon but no billing/ads plugin = 170,900,376 bytes
(the earlier 162,789,175 baseline in `gradle_build.md` predates the Sentry addon).

| Plugin | Version | Underlying library | Source | License | 4.7.2 status | APK size delta | Permissions added | Verdict |
|---|---|---|---|---|---|---|---|---|
| Google Play Billing | `godot-sdk-integrations/godot-google-play-billing` 3.3.0 (Godot 4.2+, plugin v2) | Play Billing Library 9.1.0 (`billing-ktx`) | https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/3.3.0/godot-google-play-billing.zip (sha256 20D75623D6F337F08D8283C83098B73678D5F575E39247AF5A8EB80588B18568) | MIT | works: Gradle build ok, singleton `GodotGooglePlayBilling` found, `start_connection` ran, emulator answers `connect_error code=3 "Billing service unavailable on device"` (expected: not installed from Play) | +1,229,930 bytes (+1.17 MiB) | `com.android.vending.BILLING` | **works** |
| AdMob rewarded ads | Poing Studios `godot-admob-plugin` v5.1.0 (plugin 5.1.0, android binaries `android-template-v4.7.2.zip`; lists 4.7.2 as tested) | Google Mobile Ads **Next-Gen** SDK 1.4.0 (`com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk`), not `play-services-ads` | https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0 (zip sha256 8C53FF52719EDF6A81CC7D32A9CDAAD2D9E11693C85FACA25008A1C19355726F, android template sha256 F7FDF644D50C0E231D8F02AE044057E489D0BCAFCF50E908A4858477E7EE05EE) | MIT | works: Gradle build ok, SDK initialised, test rewarded ad `loaded` | +7,373,904 bytes (+7.03 MiB) | `INTERNET`, `ACCESS_NETWORK_STATE`, `android.permission.AD_ID`, `com.google.android.gms.permission.AD_ID`, `READ_BASIC_PHONE_STATE`, `WAKE_LOCK`, `FOREGROUND_SERVICE` (merged from the SDK); manifest meta-data `APPLICATION_ID` (test id) | **works** |
| UMP (consent) | bundled in the Poing plugin (`UserMessagingPlatform` classes) | UMP as pulled by ads-mobile-sdk 1.4.0 | same as AdMob | MIT (plugin) | works: `update` ran, status `1` NOT_REQUIRED (non-EEA), no form shown | included above | none extra | **works** |

## Notes

- Billing 1.4.0 on the releases page is the Godot 3 maintenance line; use 3.x. Billing 3.x API is class-based (`BillingClient.new()`, no autoload).
- AdMob: `poingstudios/godot-admob-android` is **archived**; the live source is the monorepo `poingstudios/godot-admob-plugin` (the TECH_ARCHITECTURE link is stale). Release 5.1.0 uses the Next-Gen SDK, which avoids the `play-services-ads` Gradle problem the community fork mentions; the export plugin appends an exclusion block for `play-services-ads` to `android/build/build.gradle` at export time (idempotent; the template is untracked, so no change is needed in `setup_android_template.ps1`). Min SDK 23 needed, project uses 24.
- Install was trimmed: `addons/admob/` has `admob.gd`, `plugin.cfg`, `LICENSE`, `internal/`, `gdscript/src/` (API + UMP), the few `assets/` icons the editor menu preloads, and `android/bin/{package.gd,ads/}` (ads + core AARs only, no mediation adapters). Omitted: samples, C#, iOS, skills, docs, music, fonts. The plugin tries to download binaries itself in `--headless` editor runs when `android/bin/package.gd` is missing; ours is committed so it does not.
- Both addons are excluded from warnings (Godot default `exclude_addons`), and `lint.ps1` only compile-checks `src/` and `tests/`: still `LINT OK`.
- Ads config: Google test ids only (app id `ca-app-pub-3940256099942544~3347511713` in Project Settings `admob/general/android/app_id`, rewarded unit `ca-app-pub-3940256099942544/5224354917` as a const in `src/services/ads/ads_android.gd`). Real ids must come from an ignored file before release (M7).
- Dev environment gotcha: the host DNS resolved `googleads.g.doubleclick.net` to 127.0.0.1 (ad-blocking DNS), so the first run failed to load with code 2 (`ERR_CONNECTION_REFUSED`) and consent update failed. Starting the emulator with `-dns-server 8.8.8.8,1.1.1.1` fixed it: rewarded `loaded` after about 11 s.
- Data safety form: ads (device/advertising ID, `AD_ID`), purchases (Play Billing), network access.
- Service wiring: autoload `Services` (`src/services/services.gd`) picks `BillingAndroid`/`AdsAndroid` when `OS.get_name() == "Android"` and the singleton exists, else stubs; on Android it runs a boot probe (connect store, init ads, load one rewarded) that M1 should remove or gate behind a debug flag.
