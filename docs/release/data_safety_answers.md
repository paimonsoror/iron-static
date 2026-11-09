# Play Console Data safety: answer record (B1-09)

Changelog: 2026-11-09 v1.0 (B1-09, branch `b1-docs`).

**Precondition: these answers are true only for the B1-04 beta build** (no Billing, no AdMob/UMP, no Sentry, no Nakama, permission list exactly `VIBRATE`) **and only after `tools\aab_check.ps1` passes on the exact AAB.** Today's `docs/release/aab_audit.md` shows the pre-B1-04 bundle failing (INTERNET, AD_ID, BILLING, Sentry libraries). Do not submit the form until B1-04 is done and the evidence table below is filled from the final AAB.

Where: Play Console > Policy and programs > App content > Data safety. Policy basis: `docs/release/research_2026-11.md` 2.7 (collected means data leaving the device, including by SDKs; Google does not verify, mismatches can lead to enforcement).

## Answers

| Form question | Answer | Reason | Repo evidence |
|---|---|---|---|
| Does your app collect or share any of the required user data types? | **No** | Nothing leaves the device. | Search of `src/` for HTTPRequest, HTTPClient, WebSocket, StreamPeer, ENet, PacketPeer (2026-11-09): no network use. `src/net/backend_offline.gd` is the only backend. Re-run on the release commit. |
| Is all of the user data collected by your app encrypted in transit? | not asked (nothing collected) | | |
| Do you provide a way for users to request that their data is deleted? | not asked (nothing collected) | If Play still shows it: we hold no data; local data is removed by Clear data or uninstall (privacy page). | `site/docs/privacy.md` |
| Account creation | **My app does not allow users to create an account** | No sign-in exists. | No account code in `src/`; `BackendOffline` only (Nakama is M7). |
| Data types collected (every category: location, personal info, financial info, health and fitness, messages, photos and videos, audio, files and docs, calendar, contacts, app activity, web browsing, app info and performance, device or other IDs) | **None selected** | No analytics, no crash reporting, no ads SDK, no advertising id. The random id inside the save file stays on the device. | `src/core/game.gd` line 118 (local `Crypto` random bytes); permission list below. |
| Data shared with third parties | **None** | No third-party SDK in the beta bundle. | Plugin list below. |
| Security practices shown on the listing | "No data collected", "No data shared" | Derived by Play from the answers above. | |
| Advertising ID declaration (App content) | **No** | No `AD_ID` permission after B1-04. If Play says the bundle declares it, B1-04 is not finished: stop. | `bundletool dump manifest` finds no `AD_ID`. |
| Privacy policy URL | `https://paimonsoror.github.io/iron-static/privacy/` | Required even when nothing is collected. Must be live before the form is saved. | `site/docs/privacy.md`, `docs/release/privacy_policy_notes.md` |

## Evidence to paste from the final AAB (fill before submitting)

Run `tools\aab_check.ps1` on `build/release/ironstatic-<versionName>-<versionCode>.aab` and record:

| Item | Expected | Found (fill in) |
|---|---|---|
| AAB file and sha256 | recorded by `release_build.ps1` / B1-07 | |
| Permissions in the merged manifest (`bundletool dump manifest`) | exactly `android.permission.VIBRATE` | |
| Absent: `INTERNET`, `ACCESS_NETWORK_STATE`, `AD_ID` (both spellings), `BILLING`, `WAKE_LOCK`, `FOREGROUND_SERVICE`, `READ_BASIC_PHONE_STATE` | none found | |
| Absent: `ads.APPLICATION_ID`, `sentry`, billing activity entries | none found | |
| Native libraries | only `libgodot_android.so` and `libc++_shared.so` per ABI; no `libsentry*.so` | |
| Exported components | launcher alias only | |
| Plugin checkboxes in the beta preset | Billing off, AdMob/UMP off, Sentry excluded, Nakama addon excluded (`docs/setup/plugin_matrix.md` lines from B1-04, `docs/release/beta_build_decisions.md`) | |
| `allowBackup` | false (`docs/release/aab_audit.md`) | |

## If this changes (Q81 alternative: Sentry kept in the beta)

The answer to the first question becomes **Yes**: declare "Crash logs" and "Diagnostics" (App info and performance) as collected, purpose "App functionality" and "Analytics", encrypted in transit yes, and give a deletion-request route. INTERNET returns, and the privacy page and `privacy_policy_notes.md` change. B1-04 says stop and tell the user in that case. The same rule applies to every item in the "re-do when" list in `declarations.md` and `RELEASE_CHECKLIST.md`.
