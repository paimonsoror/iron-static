# Google Play requirements research, November 2026

Read on 2026-11-09 (all "read" dates below). Method: official Google pages first (support.google.com/googleplay/android-developer, developer.android.com, Godot docs); web search only to find gaps, marked **[secondary]**. Where an official page was fetched through a summarizer and a detail was not on the page, it is marked **[not on page]**. Play Console help pages change often: re-read the linked page before you act on a number here. Used by `PLAY_BETA_GUIDE.md` and `docs/tasks/B1.md`.

## 1. Summary of what decides the plan

1. A personal account created after 2023-11-13 must run a closed test (12 opted-in testers, 14 days) and apply for production access. **Open testing stays locked until production access is granted.** An older account skips all of that and can open an open test directly.
2. New apps and updates must target API 36 (Android 16) since 2026-08-31. Godot 4.7.2 exports with target 36 by default, but the preset has `target_sdk` empty: set it to 36 explicitly and check the AAB.
3. 16 KB page size support is required for apps targeting API 35+ on 64-bit devices. Play stops accepting updates that lack it from 2027-02-01. Godot's own libraries are built with NDK r28 (aligned); every plugin library must be checked.
4. An AAB is required. Play App Signing is automatic on the first upload; we keep only an upload key.
5. Data safety, privacy policy URL, content rating, target audience, ads declaration and app access are all required even for a no-data, no-ads app.
6. Screenshots must not be taller than 2:1. Our 1080x2400 emulator shots (2.22:1) are rejected as is.

## 2. Findings with sources

### 2.1 Testing requirement for new personal accounts
- Source: https://support.google.com/googleplay/android-developer/answer/14151465 (read 2026-11-09, fetched twice).
- "Google Play requires personal developer accounts created after November 13, 2023, to test their apps." Accounts created on or before that date are outside the rule (the page states the cutoff; the exemption is the inverse). Organization accounts: not covered **[secondary]**: https://www.testerscommunity.com/blog/google-play-closed-testing-requirements-2026.
- Closed test with **at least 12 testers opted in, continuously for at least 14 days**. A tester who opts out and back in has to be in for 14 consecutive days to count.
- Then: Play Console Dashboard > **Apply for production** > three sections (About your closed test, About your app/game, About your production readiness) > Next, Next, Apply. Leaving a page before Next/Apply loses edits.
- Review "usually takes seven days or less, but can occasionally take longer"; email on completion.
- Production and Pre-registration stay disabled until met. Review can send you back for "fewer than 12 opted-in testers" or "insufficient tester engagement".
- **Open testing:** the page says "Open testing becomes available after you gain production access", and its track table lists the access requirement as "Gain access to production". So for an account under the rule, open test is after the closed test and production access, not instead of it. Conflicting secondary note: one guide says the same order (https://www.testerscommunity.com/research/the-12-tester-era). No source says otherwise.
- The tester count was 20 until December 2024, then 12 **[secondary]**. Old guides that say 20 are outdated. A 2026 "engagement checks" claim exists only in secondary sources; the official page does mention "insufficient tester engagement" as a rejection reason, so plan for real use, not empty opt-ins.
- Not on the page: how an account's creation date is shown in the console. See the guide for how to infer it.

### 2.2 Testing tracks
- Source: https://support.google.com/googleplay/android-developer/answer/9845334 (read 2026-11-09).
- Path: Play Console > Test and release > Testing. Internal (up to 100 testers), closed (lists or Google Groups; 200 lists per account, 50 per track, 2,000 testers per list), open (unlimited, or a limit of at least 1,000).
- Open test: needs a **feedback channel** (URL or email) shown on the opt-in page; a shareable link; for apps not yet in production users also find the test through Play search. "Testers cannot leave public reviews on Google Play for test versions."
- Early-access label on the store page: **[not on page]**. Play is known to mark open-test apps as "Early access" in the listing; not verified from an official page, so do not promise it in the plan.
- Review time for a test release: **[not on page]**. Plan for a few hours to several days, longer for the first release.

### 2.3 Developer account verification
- Source: https://support.google.com/googleplay/android-developer/answer/10841920 (read 2026-11-09).
- Personal accounts: official government ID if the Google Payments profile is not yet verified; legal name and home address from the payments profile are **shown publicly on Google Play**; a public developer email verified with a 6-digit code; contact phone/email verified but hidden; website optional; a **real Android device check through the Play Console mobile app** before apps can be made available; verification can start 60 days before the individual deadline. If verification fails, apps can be removed.
- Source: https://developer.android.com/developer-verification (read 2026-11-09). Android developer verification: from 2026-09-30 protections apply in Brazil, Indonesia, Singapore and Thailand on certified devices, and expand globally in 2027. "Google Play automatically registers 99% of apps"; use Play Console to check whether yours is one of the remaining apps and register manually if so. The page does not state whether Play-only apps are otherwise affected **[not on page]**. Action: look for a verification notice in Play Console; none expected for a Play-only app, but check before the first upload and again at launch.

### 2.4 Target API level
- Source: https://developer.android.com/google/play/requirements/target-sdk (read 2026-11-09); policy article https://support.google.com/googleplay/android-developer/answer/11926878 (fetch returned no content; the developer.android.com page links to it and is the source used).
- From 2026-08-31: new apps and updates must target **Android 16 (API 36)** or higher (Wear/Auto: 35; TV/XR: 34). Existing apps must target 35+ to stay visible to new users on newer Android. Extension to 2026-11-01 existed and is over.
- Android 16 behaviour for targetSdk 36 (https://developer.android.com/about/versions/16/behavior-changes-16, read 2026-11-09): edge-to-edge cannot be opted out; predictive back is on by default (apps that intercept back must use the new APIs or set `android:enableOnBackInvokedCallback=false`); orientation/resizability limits are ignored on screens >= 600dp **except games** (by `android:appCategory`; our preset has `package/app_category=2`, Game). Check the merged manifest has the game category and that the portrait layout is fine on a foldable/tablet window.

### 2.5 16 KB memory page size
- Source: https://developer.android.com/guide/practices/page-sizes (read 2026-11-09).
- "All apps targeting Android 15 (API level 35) and higher must support 16 KB memory page sizes on 64-bit devices on Google Play. Starting February 1, 2027, if your app updates don't support 16 KB memory page sizes, you won't be able to release these updates." (Earlier schedules named 2025-11-01 and a 2026-05-31 extension; the page now says 2027-02-01. Re-read before release.)
- Pure Java/Kotlin apps are fine. Any native `.so` (Godot, GDExtensions, NDK-based SDKs) needs ELF LOAD alignment of 2**14 and 16 KB zip alignment of uncompressed libs. NDK r28+ is aligned by default; AGP 8.5.1+ aligns zip. Checks: `bundletool dump config --bundle=app.aab | grep alignment` must say `PAGE_ALIGNMENT_16K`; `zipalign -c -P 16 -v 4 app.apk`; `llvm-objdump -p lib.so | grep LOAD` (align 2**14); optional 16 KB emulator image or Pixel "Boot with 16KB page size" developer option; `adb shell getconf PAGE_SIZE` returns 16384.
- Godot: the Godot docs page for Android export (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html, read 2026-11-09) lists NDK r28b, Build-Tools 35.0.1, Platform 35, JDK 17 and does not mention 16 KB. A 2025 Godot commit moved to NDK r28 which "automatically adds support for 16kib page" **[secondary: commit mirror via search]**. A forum thread reports 4.7 targets SDK 36 by default with AGP 8.6.1 **[secondary]** https://forum.godotengine.org/t/how-to-target-latest-android-sdk/142631. The official 4.7 release notes (https://godotengine.org/releases/4.7/) were not confirmed to state it. Conclusion: likely fine for the engine, **verify our actual AAB**. A known failure pattern is third-party prebuilt binaries (a 4.6.2 AAB failed because of the GdUnit4 plugin binaries): ours are excluded from export (`addons/gdUnit4/*`), but the Sentry GDExtension and Android Sentry/AdMob/Billing AARs must be checked, or removed (task B1-04).
- Size: our debug APK is about 170-180 MB (docs/setup/plugin_matrix.md). Play's AAB/base-module download size limits: **[not verified here]**, check on the first upload; B1-01 reports the AAB size.

### 2.6 AAB and Play App Signing
- Source: https://support.google.com/googleplay/android-developer/answer/9842756 (read 2026-11-09).
- New apps are enrolled automatically on the first AAB upload with a Google-generated app signing key. You keep an **upload key** (Java keystore, RSA 2048+). If the upload key is lost you can create a new one and use "Request upload key reset"; if you manage your own app signing key and lose it, it cannot be reset. Register the app signing key's SHA-1/256 (from Play Console) with API providers, not the local upload key. Use 2-Step Verification for all console users.
- Godot: AAB needs the Gradle build; Godot's release keystore variables `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER`, `_PASSWORD` override preset values (key and keystore passwords must be equal; use only letters and numbers); uncheck Export With Debug. Source: Godot docs page above.

### 2.7 Data safety, privacy policy
- Source: https://support.google.com/googleplay/android-developer/answer/10787469 (read 2026-11-09).
- Every developer with an app on closed, open or production tracks must complete the form (internal-only testing is exempt). A privacy policy URL is required, **even for apps that collect nothing**. Answering "No" to "does your app collect or share required user data types" shows "no data collected" on the listing.
- "Collected" means data leaving the device, including by third-party SDKs and webviews you control. You must declare what SDKs do. Crash logs and diagnostics are separate data types. Google does not verify accuracy; mismatch can lead to enforcement.
- Therefore the beta build must really send nothing: no ads SDK, no billing library, no Sentry with a DSN, no analytics, no backend calls (task B1-04).

### 2.8 Account deletion
- Source: https://support.google.com/googleplay/android-developer/answer/13327111 (read 2026-11-09).
- Required only when the app lets users create an account (in-app deletion path plus a web link). All developers still answer the "data deletion" questions on the App content page. IRON STATIC beta has no accounts, so: answer "no accounts". Needed again in M7 (Nakama accounts).

### 2.9 Content rating
- Source: https://support.google.com/googleplay/android-developer/answer/9859655 (read 2026-11-09).
- Path: Play Console > Policy and programs > App content > Content rating > Start. Email for IARC correspondence, choose category (Game), answer questionnaire, review the calculated ratings on the Summary page, Submit. Systems: ESRB, PEGI, USK, ACB, ClassInd, GRAC, IARC generic. Retake when content changes in ways that affect answers. Whether a test track needs it: **[not on page]**; do it before the first closed-test release anyway (a rating is needed before publishing). Nothing found about new 2025-2026 age-rating categories on this page.

### 2.10 Target audience, ads, app access
- Source: https://support.google.com/googleplay/android-developer/answer/9859455 (read 2026-11-09).
- Declare target age groups; including children under 13 triggers the Families policy requirements (we avoid that by not selecting under-13 groups and not designing for children). Ads declaration: Yes/No; house ads and third-party SDK ads count; misrepresenting can suspend the app. App access: provide credentials only if parts are gated; ours are not.

### 2.11 Store listing assets and limits
- Sources: https://support.google.com/googleplay/android-developer/answer/9859152 (text limits) and https://support.google.com/googleplay/android-developer/answer/9866151 (graphics), both read 2026-11-09.
- App name 30 characters; short description 80; full description 4,000.
- Icon: 512x512, 32-bit PNG with alpha, up to 1024 KB. Feature graphic: 1024x500, JPEG or 24-bit PNG, no alpha.
- Phone screenshots: at least 2 to publish, up to 8; JPEG or 24-bit PNG no alpha; each side 320-3840 px; **the longer side cannot be more than twice the shorter**. Recommended for games: at least 3 at 9:16 portrait, min 1080x1920. Tablet screenshots (Chromebook/tablet): 4 recommended, 1080-7680 px, 16:9 or 9:16. Promo video: optional, public/unlisted YouTube URL.
- Category (Game > Strategy), tags, contact email (public), website (optional for personal), privacy policy URL: Play Console > Grow users > Store presence > Main store listing, and Policy and programs > App content.

### 2.12 Pre-launch report and Android vitals
- Pre-launch report: https://support.google.com/googleplay/android-developer/answer/9842757 (read 2026-11-09). Runs automatically on upload "subject to capacity"; a crawler taps and swipes for several minutes on lab devices; results under Test and release > Testing > Pre-launch report (stability, compatibility, performance, accessibility). Cannot be skipped. A game with a long first-run black screen (about 30 s shader compile, CLAUDE.md gotchas) can show as a crash or blank screen: look at its screenshots.
- Android vitals bad behaviour thresholds: https://support.google.com/googleplay/android-developer/answer/9844486 (read 2026-11-09): user-perceived crash rate 1.09% of daily users overall, 8% on one device model; ANR 0.47% overall, 8% per device. Exceeding them lowers discoverability and can show a warning on the listing; evaluated over 28 days.

### 2.13 Age signals and other 2025-2026 items
- Play Age Signals API: https://support.google.com/googleplay/android-developer/answer/16569691 (read 2026-11-09): beta; "Google Play doesn't mandate the use of these features"; relates to US state age-verification laws (Texas named, others coming); developers decide how the laws apply to them. A free game with no accounts, no purchases and no data: no action planned; revisit in M7 when accounts, ads and purchases arrive. A July 2026 Android Developers Blog post announced worldwide expansion **[secondary, not opened]**: https://android-developers.googleblog.com/2026/07/google-play-age-signals-api-safer-experiences.html.
- Developer verification and 16 KB: sections 2.3 and 2.5.
- Not researched: tax/payments profile (only needed for paid features), Play Games Services, EU DSA trader status (a "trader" declaration appears for accounts that distribute in the EU; a free hobby game from an individual normally declares "not a trader" if not commercial: **uncertain**, read the prompt Play Console shows and see Q83).

## 3. Disagreements and uncertainty
- Open test vs production access: official page says open testing needs production access; no source contradicts it. Treat as true.
- 16 KB deadline: several dates over time; the current page says 2027-02-01.
- Godot 4.7.2 16 KB statement: no official sentence found; test the artifact.
- Early-access label, review times, size limits, creation-date display: not confirmed on official pages.
