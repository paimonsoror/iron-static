# Godot pin decision

Godot 4.7.2 confirmed

Date: 2026-11-07. Pinned in `tools/GODOT_VERSION`. Evidence (details in `plugin_matrix.md`):

- **Google Play Billing 3.3.0**: Gradle build ok; singleton `GodotGooglePlayBilling` found on the emulator; `start_connection` runs ("billing unavailable" on the emulator is expected, no Play install).
- **AdMob 5.1.0 + UMP** (Poing `godot-admob-plugin`, lists 4.7.2 as tested): SDK initialised, consent update ran (NOT_REQUIRED), Google test rewarded ad loaded.
- **Nakama client 3.4.0**: loads under the project's warnings-as-errors settings; client instantiated headless; 3 unit tests pass.
- Optional: Sentry 2.4.0 in the combined Gradle build, `SMOKE OK`; Firebase Analytics and Play Games are blocked on a user Firebase/Play Console project (not vendored; both document 4.7 support).
- Combined debug APK about 179.5 MB; CI green on the same version.

Residual risk: Firebase and Play Games are unverified on 4.7.2 until the user creates the projects (M7); fallback for Play Games is an own small Kotlin plugin.
