# AAB audit (B1-03)

Changelog: 2026-11-09 v1.0 (B1-03, branch `b1-build`).

Tool: `tools\aab_check.ps1` (bundletool 1.18.3, zipalign from Build-Tools 36.0.0, llvm-objdump from NDK r28b). Input: `build/release/ironstatic-0.5.0-beta.1-50001-TESTKEY.aab` (66.03 MB, signed with the throwaway test key; the key does not change any result below). The beta preset still contains the M3 service plugins; B1-04 strips them, so the manifest checks FAIL by design today.

## Results on the current build (before B1-04)

| Check | Result |
|---|---|
| targetSdkVersion | 36, PASS |
| minSdkVersion | 24, PASS |
| `bundletool dump config` | `PAGE_ALIGNMENT_16K` present, PASS |
| `zipalign -c -P 16 -v 4` on the universal APK | Verification successful, PASS |
| LOAD alignment of every arm64-v8a and x86_64 `.so` | 2**14 for all 10 libraries, PASS |
| GNU_RELRO segment present | 10/10 (presence only; no deeper RELRO overlap analysis), PASS |
| allowBackup | false, PASS |
| Game category | `isGame="true"`, PASS |
| Size | 66.03 MB (limit used here 150 MB), PASS |
| Permissions | FAIL: ACCESS_NETWORK_STATE, AD_ID (android.permission and com.google.android.gms.permission), FOREGROUND_SERVICE, INTERNET, READ_BASIC_PHONE_STATE, VIBRATE, WAKE_LOCK, com.android.vending.BILLING, com.ironstatic.game.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION. Allowed: VIBRATE only. All the others come from the ads, billing, Sentry and WorkManager plugin AARs: B1-04 |
| Exported components | FAIL: androidx.work `SystemJobService`, `DiagnosticsReceiver`, and `androidx.profileinstaller.ProfileInstallReceiver` (all permission-guarded). The launcher alias `GodotAppLauncher` is accepted. Expected to disappear when the ads, billing and Sentry plugins go (B1-04); re-run after |

Native libraries: Godot 4.7.2's prebuilt `libgodot_android.so` and `libc++_shared.so` are 16 KB aligned, as are the Sentry libraries, so no library needs an update, removal or exclusion.

| Library | LOAD alignment | RELRO | Size (B) |
|---|---|---|---|
| lib/arm64-v8a/libc++_shared.so | 2**14 | True | 1374336 |
| lib/arm64-v8a/libgodot_android.so | 2**14 | True | 71114944 |
| lib/arm64-v8a/libsentry-android.so | 2**14 | True | 19928 |
| lib/arm64-v8a/libsentry.android.release.arm64.so | 2**14 | True | 2012712 |
| lib/arm64-v8a/libsentry.so | 2**14 | True | 884416 |
| lib/x86_64/libc++_shared.so | 2**14 | True | 1337488 |
| lib/x86_64/libgodot_android.so | 2**14 | True | 74061272 |
| lib/x86_64/libsentry-android.so | 2**14 | True | 19384 |
| lib/x86_64/libsentry.android.release.x86_64.so | 2**14 | True | 1911104 |
| lib/x86_64/libsentry.so | 2**14 | True | 868520 |

Owners: `libgodot_android.so`, `libc++_shared.so` = engine export template; `libsentry*.so` = Sentry plugin AAR (B1-04 removes them from the beta).

Biggest files in the AAB: `base/lib/x86_64/libgodot_android.so` 74.1 MB, `base/lib/arm64-v8a/libgodot_android.so` 71.1 MB, `base/dex/classes.dex` 9.7 MB (uncompressed sizes).

## Not run here (needs emulator or device; B1-07)

- Android 16 behavior notes (edge-to-edge insets, predictive back, large-screen orientation): not run.
- Running the exact AAB on a 16 KB page-size system image (`adb shell getconf PAGE_SIZE` = 16384): not run.
