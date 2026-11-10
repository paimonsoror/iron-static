# Plugin matrix (M0-10, M0-11, M0-12)

Changelog: 2026-11-07 v1.0 final M0 matrix: merged the former `plugin_matrix_m0-12.md` (Sentry, Firebase, Nakama, Play Games) into the Billing/AdMob/UMP rows; added Sentry Android results, APK size and the Sentry Android log decision (M0-14).

Tested on Godot 4.7.2 stable, Gradle build, AVD `tower_phone` (API 35, Play Store image), debug APK.
Size: Gradle APK with Services autoload + Sentry but no billing/ads plugin = 170,900,376 bytes; with Billing and AdMob (the combined M0 build) about 179.5 MB. Pre-Sentry baseline in `gradle_build.md` = 162,789,175 bytes.
Required plugins (Billing, AdMob/UMP, Nakama client) all pass on 4.7.2: see `godot_pin_decision.md`.

## Matrix

| Plugin | Version | Source | License | 4.7.2 status | APK size delta | Permissions added | Verdict |
|---|---|---|---|---|---|---|---|
| Google Play Billing | `godot-sdk-integrations/godot-google-play-billing` 3.3.0 (plugin v2); Play Billing Library 9.1.0 | https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/3.3.0/godot-google-play-billing.zip (sha256 20D75623D6F337F08D8283C83098B73678D5F575E39247AF5A8EB80588B18568) | MIT | works: Gradle build ok, singleton `GodotGooglePlayBilling` found, `start_connection` ran; emulator answers `connect_error code=3` (expected: not installed from Play) | +1,229,930 B (+1.17 MiB) | `com.android.vending.BILLING` | **works** (required) |
| AdMob rewarded ads | Poing Studios `godot-admob-plugin` 5.1.0 (android binaries `android-template-v4.7.2.zip`); Google Mobile Ads **Next-Gen** SDK 1.4.0 (not `play-services-ads`) | https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0 (zip sha256 8C53FF52719EDF6A81CC7D32A9CDAAD2D9E11693C85FACA25008A1C19355726F, android template sha256 F7FDF644D50C0E231D8F02AE044057E489D0BCAFCF50E908A4858477E7EE05EE) | MIT | works: Gradle build ok, SDK initialised, Google test rewarded ad `loaded` (needs working DNS, see notes) | +7,373,904 B (+7.03 MiB) | `INTERNET`, `ACCESS_NETWORK_STATE`, `android.permission.AD_ID`, `com.google.android.gms.permission.AD_ID`, `READ_BASIC_PHONE_STATE`, `WAKE_LOCK`, `FOREGROUND_SERVICE` (merged from the SDK); meta-data `APPLICATION_ID` (test id) | **works** (required) |
| UMP (consent) | bundled in the Poing plugin; UMP as pulled by ads-mobile-sdk 1.4.0 | same as AdMob | MIT (plugin) | works: `update` ran, status `1` NOT_REQUIRED (non-EEA), no form shown | included above | none extra | **works** (required) |
| Sentry Godot SDK | 2.4.0 (2026-10-21), GDExtension + Android plugin aar; `compatibility_minimum = "4.5"` | https://github.com/getsentry/sentry-godot (release zip), https://docs.sentry.io/platforms/godot/ | MIT | works: desktop and Android; extension auto-loads, DSN empty so inert; combined Gradle build `SMOKE OK`. Boot log noise on Android: see Sentry notes. | about +8.1 MB (170,900,376 B with Sentry vs 162,789,175 B before; Android libs for 4 ABIs) | none declared (needs `INTERNET`, already held) | **use** (optional; DSN and consent gate in M7) |
| Firebase Analytics (`godot-x/firebase`, `firebase_analytics` + `firebase_core`) | 3.1.0 (2026-07-22); README "Godot 4.7-stable", firebase-analytics 23.2.0, min SDK 24 | https://github.com/godot-x/firebase | MIT | not vendored, not tested (needs `google-services.json`); README targets 4.7 | estimate +1 to 2 MB (Analytics + Core only) | `INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `AD_ID` (per Firebase docs, unverified); reflect in Data safety and consent | `blocked on user Firebase/Play Console project` (optional) |
| Nakama client (GDScript) | 3.4.0 (2024-03-19), latest tag | https://github.com/heroiclabs/nakama-godot (`nakama-3.4.0.zip`) | Apache-2.0 | works: vendored at `addons/com.heroiclabs.nakama/`; loads under warnings-as-errors; client created headless; 3 unit tests pass (`tests/unit/test_nakama_client.gd`) | about +0.3 MB (GDScript only) | `INTERNET` only (project preset holds it) | **use** (required) |
| Play Games Services v2 (`godot-play-game-services`) | 3.4.0 (2026-07-20); play-services-games-v2 21.0.0 | https://github.com/godot-sdk-integrations/godot-play-game-services (`addons.zip`) | MIT | not vendored, not tested; its export plugin needs preset `godot_play_game_services/game_id`, so it cannot sit inert | estimate +1 to 2 MB | `INTERNET`, `ACCESS_NETWORK_STATE` (merged, unverified) | `blocked on user Firebase/Play Console project` (optional; fallback own ~150-line Kotlin plugin) |

## Notes (Billing, AdMob, UMP)


- Billing 1.4.0 on the releases page is the Godot 3 maintenance line; use 3.x. Billing 3.x API is class-based (`BillingClient.new()`, no autoload).
- AdMob: `poingstudios/godot-admob-android` is **archived**; the live source is the monorepo `poingstudios/godot-admob-plugin` (the TECH_ARCHITECTURE link is stale). Release 5.1.0 uses the Next-Gen SDK, which avoids the `play-services-ads` Gradle problem the community fork mentions; the export plugin appends an exclusion block for `play-services-ads` to `android/build/build.gradle` at export time (idempotent; the template is untracked, so no change is needed in `setup_android_template.ps1`). Min SDK 23 needed, project uses 24.
- Install was trimmed: `addons/admob/` has `admob.gd`, `plugin.cfg`, `LICENSE`, `internal/`, `gdscript/src/` (API + UMP), the few `assets/` icons the editor menu preloads, and `android/bin/{package.gd,ads/}` (ads + core AARs only, no mediation adapters). Omitted: samples, C#, iOS, skills, docs, music, fonts. The plugin tries to download binaries itself in `--headless` editor runs when `android/bin/package.gd` is missing; ours is committed so it does not.
- Both addons are excluded from warnings (Godot default `exclude_addons`), and `lint.ps1` only compile-checks `src/` and `tests/`: still `LINT OK`.
- Ads config: Google test ids only (app id `ca-app-pub-3940256099942544~3347511713` in Project Settings `admob/general/android/app_id`, rewarded unit `ca-app-pub-3940256099942544/5224354917` as a const in `src/services/ads/ads_android.gd`). Real ids must come from an ignored file before release (M7).
- Dev environment gotcha: the host DNS resolved `googleads.g.doubleclick.net` to 127.0.0.1 (ad-blocking DNS), so the first run failed to load with code 2 (`ERR_CONNECTION_REFUSED`) and consent update failed. Starting the emulator with `.	oolsun_emulator.ps1 -PublicDns` (`-dns-server 8.8.8.8,1.1.1.1`) fixed it: rewarded `loaded` after about 11 s.
- Data safety form: ads (device/advertising ID, `AD_ID`), purchases (Play Billing), network access.
- Service wiring: autoload `Services` (`src/services/services.gd`) picks `BillingAndroid`/`AdsAndroid` when `OS.get_name() == "Android"` and the singleton exists, else stubs. The connect-store / init-ads / load-rewarded probe runs only in debug builds with the user arg `--probe-services` (see `DEV_ENVIRONMENT.md`).

## Sentry notes


- Platforms shipped in the release zip: Windows (x86_64, x86_32, arm64), Linux (x86_64, x86_32, arm64), macOS (universal), Android (arm64, arm32, x86_64, x86_32), iOS, Web, .NET. Full addon is 124 MB unpacked.
- **Vendored subset (impl):** `addons/sentry/` keeps `sentry.gdextension` (unmodified), `LICENSE.md`, `README.md`, `user_feedback/`, all Android binaries (17 MB), `bin/windows/x86_64`, `bin/linux/x86_64` (CI). Dropped: iOS, macOS, Web, .NET, x86_32/arm desktop (89 MB), because we ship Android only and the repo should stay small. Missing libraries for other platforms are not an error on load. If a future platform is added, re-extract from the 2.4.0 zip.
- Windows sizes (x86_64): `libsentry.windows.release.x86_64.dll` 1.7 MB, debug 2.1 MB, `crashpad_handler.exe` 3.1 MB, `crashpad_wer.dll` 0.7 MB.
- Android needs the **Gradle build** (export hint added upstream in 1.x; the project already uses it). `compatibility_minimum = "4.5"`, so 4.7.2 is in range.
- **Native crash support on Android: yes** (sentry-android NDK with tombstone support, ANR detection enabled by default, `SentryOptions.android.enable_anr_detection` to opt out; GDScript line numbers on Android with Godot 4.6+ fixed in 2.x). Not exercised here; verify with a forced crash after an Android build with a real DSN (M7).
- Behaviour with empty DSN: auto-init is skipped and "Operations with Sentry SDK will result in no-ops", so it is inert until a DSN is set.
- Gotcha (benign): running Godot with `--script` (as `tools/compile_check.gd` does) prints `ERROR: Sentry: Failed to initialize engine lifecycle tracking - SceneTree is unavailable.` (from `engine_lifecycle.cpp`). `lint.ps1` still passes because it only scans the `--import` output for `ERROR:`; if the compile step ever starts scanning that run's output, whitelist this line.
- Required project settings for integration: none for a disabled build. When the user supplies a DSN: Project Settings > Sentry > Options > DSN (do not commit a real DSN; set it from `secrets.local.json` at export time or leave empty in git and inject through an override file, decision for M7), plus `Environment`/`Release` (use `Game.VERSION`), and consent gate (call `SentrySDK.init`/disable per consent state, TECH_ARCHITECTURE 7.4/9).

- **Android result (M0-14):** the combined Gradle build includes the GDExtension and plugin aar automatically; logcat shows `starting Sentry SDK version 2.4.0`, `Automatic initialization is disabled because no DSN was provided`, no `UnsatisfiedLinkError`. Two boot-time `ERROR` lines (`Sentry: Please enable File Logging in your Project Settings...` and one from `_verify_project_settings`) came from the SDK wanting a Godot log file to attach to events. **Fix (impl):** `[sentry] options/attach_log=false` in `project.godot` (setting `sentry/options/attach_log`); the errors are gone and nothing else changes (DSN stays empty, no network reporting). At M7, when a DSN is set, either keep it off or enable `debug/file_logging/enable_file_logging` and set `attach_log=true` to get log files with events (consent gate first).

## Nakama client notes


- Newest release is **3.4.0**, "Godot 4 support is now on master" (Godot 3 on branch `godot-3`). README says GDScript for Godot 4.0+. No newer release exists as of 2026-11-07; master has activity but is untagged. Vendored from the release zip, unmodified (plus upstream `LICENSE` copied into the addon folder).
- Scripts are LF, no BOM. Lint excludes `addons/` (only `src`, `tests`, `tools`); `tools\lint.ps1` stays `LINT OK` with the addon present.
- 4.7.2 findings: **no parse errors, no warnings-as-errors issues** (the project's strict warning settings apply to project scripts; the untyped addon code did not trip them, and Godot printed nothing about it during import). The only real problems were in our own test (Variant casts), not the addon.
- `Nakama.gd` is a `@tool extends Node` facade meant to be an autoload; it has no `class_name`. Everything else (`NakamaClient`, `NakamaHTTPAdapter`, `NakamaSession`, `NakamaAPI`, `NakamaSocket`...) registers as global classes, so typed code can use them directly.
- Satori files (`Satori*.gd`) ship in the addon and are unused.
- Integration step must add: autoload `Nakama="*res://addons/com.heroiclabs.nakama/Nakama.gd"` (and nothing else) to `project.godot`, ideally after `Log`/`Game`; **or** skip the autoload and let the future `BackendNakama` own an instance of the facade script (cleaner for our `Services` DI, and avoids a global name in sim-layer lint). **(impl)** recommendation: own the instance, no autoload, so `project.godot` needs no change for Nakama.
- Android needs `INTERNET` permission (export preset `permissions/internet`). Use `https`/`wss` in production; cleartext `http` to a LAN dev server needs `usesCleartextTraffic` or a network security config, only relevant for local Docker testing on the emulator (use `10.0.2.2`).


## Firebase and Play Games compile-only plans (for M7)
 (for the integration step or M7)

Neither is in the repo. Firebase's export plugin needs a `google-services.json` and edits `android/build/build.gradle`; Play Games needs the Game ID. Both would fail or misbehave when unconfigured.

1. Firebase Analytics, compile check without real project: create a throwaway Firebase project config is the only supported way; a fake `google-services.json` (package `com.normalexception.game`, dummy keys) is enough for the Gradle `google-services` plugin to compile, but must stay out of git (`.gitignore` it). Steps: unzip the 3.1.0 release into a new scratch folder, copy `addons/godotx_firebase/`, `android/firebase_core/`, `android/firebase_analytics/` only (not Crashlytics/Messaging); enable the editor plugin; in the Android preset enable Firebase Core and Analytics, set the config file; add the two `classpath`/`apply plugin` lines to `android/build/build.gradle` (that file belongs to the build-template owner); add the export filter `ios/*,addons/godotx_firebase/*`. Keep "Privacy-safe defaults" on (collection off and consent denied until UMP resolves). Logcat to check: `GodotxFirebaseCore`, `FirebaseApp initialization`.
2. Play Games: needs the user to create the Play Console game entry. Compile-only: enable the plugin, put any numeric dummy Game ID in the preset field, build; sign-in will fail with `DEVELOPER_ERROR` on the emulator, which is expected until OAuth client + SHA-1 exist. Because the editor plugin adds an autoload, run this only on a scratch branch or after the user approves.


## Integration checklist (for the agent that owns `project.godot`, `export_presets.cfg`, `android/`)
 (for the agent that owns `project.godot`, `export_presets.cfg`, `android/`)

Order: do this after Billing/AdMob are green, one plugin at a time, re-running `.\tools\smoke_android.ps1` between steps.

1. **Nakama** (no export change). Nothing required. If the autoload route is chosen: add `Nakama="*res://addons/com.heroiclabs.nakama/Nakama.gd"` under `[autoload]`. Ensure Android preset `permissions/internet=true`. Verify: `.\tools\test.ps1` shows `TEST SUMMARY` with `test_nakama_client` passing; on the emulator add a one-line `Log.info` from the future backend and look for it with `adb logcat -s godot`.
2. **Sentry**. `addons/sentry/` is already present and auto-loads; the editor plugin is not needed (it is a GDExtension; do not add it to `editor_plugins`). Export preset: Gradle build already on; make sure the Android preset architectures include `arm64-v8a` and `x86_64` (emulator), because libraries are listed per ABI in `sentry.gdextension`. First Gradle build must be able to reach Maven Central for `io.sentry:sentry-android*`. Do not set a DSN. Verify on the emulator: `adb logcat | findstr /i sentry` shows `starting Sentry SDK version 2.4.0` and `Automatic initialization is disabled because no DSN was provided`, with no `UnsatisfiedLinkError` / `libsentry` load failure, and `SMOKE OK`. Record the debug APK size delta against the pre-Sentry APK (expected +5 to 6 MB for two ABIs). If the Gradle build fails on a dependency, record the error and mark `own crash handler / skip` for Sentry; it is not a required plugin.
3. **Firebase Analytics** (only when the user has a Firebase project): follow the compile-only plan above; keep `google-services.json` untracked (add to `.gitignore`); add `android/build/build.gradle` classpath lines; verify logcat `FirebaseApp` init lines and that `INTERNET`/`AD_ID` appear in `aapt dump permissions` of the APK. Analytics init must be gated by consent (TECH_ARCHITECTURE 7.4).
4. **Play Games** (only when the user has a Play Console game): enable `GodotPlayGameServices` editor plugin, set `godot_play_game_services/game_id`, OAuth client with `com.normalexception.game` + SHA-1 of the signing key (debug key for emulator tests). Verify: logcat `GodotPlayGameServices` and no `DEVELOPER_ERROR`.
5. Check `aapt dump permissions` / merged manifest after each step and record the permission delta in `plugin_matrix.md` (Data safety form).

## Beta build: plugins stripped (B1-04)

Changelog: 2026-11-09 B1-04 (branch `b1-plugins`).

The beta AAB (`IronStaticBeta`) contains none of the plugins above. The debug preset `IronStatic` and `tools\deploy_android.ps1 -Preset IronStatic` keep all of them (`--probe-services` still works).

| Plugin | Beta decision | How it is kept out |
|---|---|---|
| Google Play Billing | not in the beta (no purchases) | addon folder absent from the export workspace; `BillingAndroid` script excluded from the pck |
| AdMob / UMP | not in the beta (no ads) | same; also removes `AD_ID`, `INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `FOREGROUND_SERVICE`, `READ_BASIC_PHONE_STATE` and the WorkManager components that came with the ads SDK |
| Sentry | not in the beta (Q81: no crash reporting) | addon folder absent from the workspace, so neither the GDExtension nor its Android plugin AAR exists; `[sentry]` settings removed from the workspace `project.godot` |
| Nakama client | not constructed (`BackendOffline` only); addon not in the bundle | addon folder absent; preset `permissions/internet=false` |

Mechanism (per preset, source tree never modified): the plugins are project-wide (editor plugins in `[editor_plugins]`, a GDExtension that registers its own Android plugin, AARs under `addons/`), and a preset `exclude_filter` only filters the pck, not Gradle dependencies. The first attempt (a gitignored `override.cfg` that emptied `editor_plugins`, plus moving `addons/sentry` out of the tree) still produced a bundle with AdMob, Billing and WorkManager (63 MB, 21 MB of dex), and it mutated the working tree, so a crashed build left the repo without Sentry. Instead `tools\release_build.ps1 -Preset IronStaticBeta` copies the project to `build\beta_ws` (robocopy, without `.git`, `addons/{sentry,admob,GodotGooglePlayBilling,com.heroiclabs.nakama,gdUnit4}`, docs, tests, tools, secrets), empties `[editor_plugins] enabled`, drops `[sentry]`, imports and exports there, then deletes the copy. A killed run leaves only that disposable folder; the next run wipes it first. The `exclude_filter` and `permissions/internet=false` in the preset are a second line of defence.

Fallback: `Services` loads `billing_android.gd` / `ads_android.gd` by path (`load()`), only on Android, only when the singleton exists and the script exists; otherwise `BillingStub` / `AdsStub`. Those two scripts reference plugin classes (`BillingClient`, `MobileAds`) and are excluded from the beta pck, so nothing in the beta names a plugin class. `tests/unit/test_beta_services.gd` covers the fallback.

Re-enabling for M7: remove the matching entry from the `$xd` list in `New-StripWorkspace` (`tools\release_build.ps1`) and from the preset `exclude_filter`, set `permissions/internet=true` if the plugin needs it, keep `[editor_plugins]` intact in the workspace (change the regex in `New-StripWorkspace`), then re-run `aab_check.ps1` with the matching `-AllowedPermissions` and redo the Data safety form (`docs/release/data_safety_answers.md`).