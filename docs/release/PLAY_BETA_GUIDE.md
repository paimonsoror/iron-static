# IRON STATIC - Google Play beta guide (for you)

Changelog: v1.0 2026-11-09 (planning, milestone B1). Facts checked against Google's pages on 2026-11-09: `docs/release/research_2026-11.md` has every source link. Play Console is rearranged often: if a menu name below is not where I say, use the search box at the top of Play Console and the page title.

You have published before, but not for a while. This guide is the whole path from "nothing uploaded" to "anyone can install the beta from the store". Do the phases in order. Tick the boxes. Steps marked **YOU** only you can do. Steps marked **AGENTS** are prepared by Claude and the agents from `docs/tasks/B1.md`; you only check the result.

## 0. The short version

- The beta is an **open test**: anyone can find IRON STATIC on Google Play and install it. No ads, no purchases, no accounts, no data collected.
- **Big catch:** if your developer account was created after 13 November 2023, Google locks the open test until you have run a **closed test with 12 testers for 14 days in a row** and been granted production access. Google's page says: "Open testing becomes available after you gain production access."
- So the path is either:
  - **Path A (account created on or before 2023-11-13):** internal test (dry run) -> open test. About 1-2 weeks.
  - **Path B (account created after 2023-11-13, or you are not sure):** internal test -> closed test (12+ testers, 14 days) -> apply for production access (about 7 days) -> open test. About 5-7 weeks. Start recruiting testers before the first build is ready.
- Roughly 20 hours of your own time, spread over those weeks, plus the work the agents do first (milestone B1 in `docs/ROADMAP.md`).

## 1. Is your account exempt? (do this first, 5 minutes)

You do not remember when you created the account. How to find out, best first:

- [ ] **YOU** Search your email for "Welcome to Google Play Console" or "Google Play Developer registration" (the $25 receipt from Google Payments). The date of that mail is the creation date. Anything on or before 2023-11-13 is exempt.
- [ ] **YOU** In Play Console, create the app (phase 4). Then open **Dashboard**. If you see a card like "Test your app with at least 12 testers for 14 days" or "Apply for production", **you are under the rule (Path B)**. If you see no such card and **Test and release > Testing > Open testing** is clickable, you are exempt (Path A).
- [ ] **YOU** Not sure? Assume Path B. Costs nothing: you need the internal test first anyway.

Write the result down: `Account created: ____ / Path: A or B`. Tell the agents (it is open question Q78).

## 2. Who does what

| Item | Who | Where it is described |
|---|---|---|
| Play Console clicks, declarations, uploads, testers | **YOU** | this guide |
| Release signing key (upload keystore) creation and backup | **YOU** (agents write the build script that uses it) | phase 2 |
| Beta AAB (signed bundle), version numbers, 16 KB check, target API 36 | AGENTS: B1-01 to B1-04, B1-07 | `docs/tasks/B1.md` |
| Privacy policy page on the codex site | AGENTS: B1-05; you approve the text | phase 3 |
| Icon 512, feature graphic 1024x500, screenshots | AGENTS: B1-06; you approve | phase 6 |
| Settings "send feedback" link and version label | AGENTS: B1-08 | section 13 |
| Answers record for data safety, content rating | AGENTS: B1-09; this guide has the same answers | phase 5 |
| Trademark search (Q31), final package name (Q30) | **YOU** | section 3 |
| Recruiting 12+ testers (Path B) | **YOU** | phase 8 |

## 3. Before you upload anything (checklist)

All of these are one-time. An upload with a wrong answer here can be impossible to undo.

- [x] **Package name is final.** `com.normalexception.game` (decided 2026-11-09, matches your domain normalexception.net). It is permanent once uploaded (a different name later means a new listing, losing installs).
- [ ] **Trademark and name search (Q31).** Search "IRON STATIC" in: Google Play (search the store), USPTO trademark search (tmsearch.uspto.gov), EUIPO eSearch, a web search, and game-name social handles. If a game with that name already exists in a game or software class, tell us before the upload; fallback name is EMBER CHASSIS. Also check that no text or art in the listing uses a franchise name.
- [ ] **Version scheme agreed.** versionName `0.5.0-beta.1`, versionCode `50001` (formula in B1-02: MAJOR*1,000,000 + MINOR*10,000 + PATCH*100 + BUILD). Every upload needs a higher code than the last one, forever.
- [ ] **Upload keystore created and backed up** (phase 2). A lost upload key can be reset by Google, but it costs days.
- [ ] **Play Console security:** 2-Step Verification on for your Google account.
- [ ] **Identity verified** (phase 1).
- [ ] **A real Android device** with the Play Console app installed (Google asks individual accounts to verify with a real device).
- [ ] **Privacy policy URL live** (phase 3) before you fill the Data safety form.
- [ ] **Beta AAB built and tested** by the agents (B1-07) and sizes noted.

## 4. Phase 1 - Account health (YOU)

1. [ ] Open https://play.google.com/console and sign in with the developer account.
2. [ ] Look at the top banner and **Inbox** for anything unfinished: identity verification, payments profile, "Verify your device", "Android developer verification" notices. Finish each. Personal accounts must verify identity with a government ID if the payments profile is not verified yet, and verify a public developer email with a 6-digit code (Settings > Developer account > Account details / Identity verification).
3. [ ] **Public details warning.** For a personal account Google shows your legal name and home address on the store page ("Developer contact" section). Decide whether that is acceptable (open question Q83). If not, a registered organization account would be needed (D-U-N-S number; exempt from the tester rule), which is a different path.
4. [ ] Install the **Play Console** mobile app on your Android phone, sign in, and complete "device verification" if it asks.
5. [x] Public support email: `support@normalexception.net` (a dedicated address on your domain, decided 2026-11-09). It is public, so it appears on the privacy page and in the listing records. Never put a personal email in the repo.

## 5. Phase 2 - Your release key (YOU, 15 minutes)

You create the key once. The agents' build script reads it. It must never go into git.

1. [ ] Make a folder outside the repo, for example `C:\dev\keys\`.
2. [ ] In PowerShell (JDK 17 is installed for Godot; `keytool` comes with it):

   ```powershell
   keytool -genkeypair -v -keystore C:\dev\keys\ironstatic-upload.jks -alias ironstatic-upload -keyalg RSA -keysize 2048 -validity 10000
   ```

   Use **the same password for the keystore and the key**, letters and numbers only (Godot cannot handle special characters here). Answer the name questions with anything sensible.
3. [ ] **Back it up now:** copy the `.jks` file and write the passwords into your password manager. Keep a second copy on a USB stick or a cloud drive that is not the repo. If you lose the key you need Play's "Request upload key reset".
4. [ ] Put the paths into `secrets.local.json` in the repo root (it is git-ignored). B1-01 defines the field names (`android_release_keystore_path`, `android_release_keystore_user`, `android_release_keystore_password`). Tell the agent running B1-01 the file is ready; never paste the passwords into a chat.
5. [ ] Play App Signing: Google creates and holds the real app signing key on your first upload. You only keep this upload key.

## 6. Phase 3 - Privacy policy (AGENTS draft, YOU approve)

Play requires a privacy policy URL even if you collect nothing.

- [ ] AGENTS (B1-05) add `site/docs/privacy.md` to the codex. The URL will be `https://paimonsoror.github.io/iron-static/privacy/` (from `site/mkdocs.yml`). It is only live after the change is merged to `main` and the Pages workflow finishes. Open the URL in a browser and in a private window before you continue.
- [ ] **YOU** Read it. It must say: the game stores progress only on your device; no accounts; no ads; no purchases; no analytics; the beta makes no network connections; one permission (vibration); not directed at children under 13; how to ask questions (your feedback form). It must use the app name "IRON STATIC" and the developer name exactly as it shows on Google Play.

## 7. Phase 4 - Create the app (YOU)

1. [ ] Play Console > **Create app**.
2. [ ] App name: `IRON STATIC`. Default language: English (United States). App or game: **Game**. Free or paid: **Free**. Tick the declarations (Developer Program Policies, US export laws). Create.
3. [ ] On the **Dashboard**, the "Set up your app" list is your to-do list. The next phases fill it in. (If you are on Path B, the testing-requirement card shows here too.)

## 8. Phase 5 - App content declarations (YOU)

Play Console > **Policy and programs > App content** (older name: Policy > App content). Do each item. Answers below are for the beta build: no ads, no purchases, no accounts, no data leaves the device.

- [ ] **Privacy policy:** paste the codex URL from phase 3.
- [ ] **App access:** "All functionality is available without special access." (No login.)
- [ ] **Ads:** "No, my app does not contain ads."
- [ ] **Content rating:** click Start. Email: your public developer email. Category: **Game**. Expected answers:

  | Question | Answer |
  |---|---|
  | Violence | Yes, cartoon / fantasy violence: a cyborg shoots robotic enemies with a laser; no blood, no gore, no human characters harmed, no realistic violence |
  | Sexual content, nudity | No |
  | Profanity / crude humor | No (agents re-check the strings in B1-09) |
  | Controlled substances (drugs, alcohol, tobacco) | No |
  | Gambling, simulated gambling, loot boxes | No |
  | User-generated content, chat, user interaction | No |
  | Shares user location | No |
  | Allows purchases of digital goods | No (the beta has none; redo the questionnaire in M7) |
  | Unrestricted web access | No |

  Expect a Teen-class result (ESRB Teen / PEGI 12 or similar). If the result says Mature or 18+, stop and tell us: an answer was probably wrong. Submit and note the ratings.
- [ ] **Target audience and content:** select age groups **13-15, 16-17 and 18+**. Do **not** select anything under 13. Reasoning: sci-fi combat with machine enemies suits teens and up; the Teen rating and the roadmap (Q6) already assume 13+; selecting under-13 groups would pull the app into Google's Families policy (extra rules, no ads SDKs outside a certified list, more review). Because the beta collects no data, no age gate is needed in the beta; Q6 (age gate) returns in M7 with accounts, ads and purchases. When Play asks "might the app appeal to children?", answer honestly: **No** (dark industrial art, no cartoon characters or mascots). Alternative if you prefer extra caution: 16+ only (16-17, 18+). Open question Q80.
- [ ] **Data safety:** Start > "Does your app collect or share any of the required user data types?" **No**. Then the form shows a summary of "No data collected" and "No data shared". No account creation: "My app does not allow users to create an account". No data deletion question applies. Save, then **Submit**. (If a later build adds Sentry, Firebase, ads or billing, this form must change before that build is uploaded.) Full answer record: `docs/release/data_safety_answers.md` (B1-09).
- [ ] **Government apps:** No. **Financial features:** none. **Health:** none. **News:** not a news app. Anything else the page lists that does not apply: "No" / "None of the above".
- [ ] **Advertising ID:** if Play asks, "No" (the beta build has no AD_ID permission after B1-04). If it says your bundle declares the permission, the agents did not finish B1-04: stop.
- [ ] **Account deletion / data deletion:** answer "no accounts".
- [ ] If Play shows an **EU trader status** prompt (Digital Services Act): read it. A hobby game from an individual that earns nothing is normally "not a trader" for the beta; if you plan to sell things later you may need to switch to trader. Open question Q83.

## 9. Phase 6 - Store listing (YOU enter, AGENTS provide the files)

Play Console > **Grow users > Store presence > Main store listing** (or "Store presence > Main store listing").

**Texts (drafts; change what you like, keep within the limits):**

- App name (30 max): `IRON STATIC`
- Short description (80 max, this draft is 76): `Auto-fire a laser, buy upgrades, hold the line. An idle sci-fi defense game.`
- Full description (4,000 max):

```
You are CINDER, a reprogrammed combat cyborg at the Relay. Rogue machine swarms attack from every side. Cinder fires on her own. You decide what she becomes.

IRON STATIC is an idle defense game for your phone. Drop into a deployment, spend scrap on upgrades while the waves roll in, and see how far the line holds. When Cinder falls, the data you recovered makes the next deployment stronger.

WHAT YOU DO
- Watch Cinder auto-fire a laser at swarms that close in from all sides.
- Buy temporary upgrades with scrap during a deployment: laser output, fire rate, crits, range, hull, repair, plating and more.
- Bank data between deployments and spend it in the Foundry on permanent upgrades.
- Play TIMED waves that keep coming on a clock, then unlock PURGE waves that end only when the whole swarm is destroyed.
- Pick a patch at wave 10 and shape the rest of the deployment.
- Unlock frames (VANGUARD, BULWARK, STRIKER) that change how Cinder plays.
- Watch Cinder's synthetic skin burn away as the pressure rises.

THIS IS AN EARLY BETA
IRON STATIC is still in development. Expect rough edges, changing numbers and the occasional bug. Your feedback shapes the game: use the feedback link in Settings.

NO ADS. NO PURCHASES. NO ACCOUNT.
This beta has no ads, no in-app purchases and no sign-in. Your progress is saved on your device only. We collect no data.

Portrait, one-handed, short sessions or long idle stretches. Built for phones running Android 7 or newer.
```

  (Checked against the game in B1-09. The final texts and character counts are in `docs/release/store_listing.md`: paste from that file, it wins over this draft.)
- [ ] **App category:** Game > **Strategy**. Tags (pick up to 5 offered): Strategy, Idle, Tower defense, Sci-fi, Offline (only those Play offers).
- [ ] **Contact details:** public email (phase 1), website `https://paimonsoror.github.io/iron-static/` (optional but nice), phone not required.
- [ ] **Graphics** (AGENTS B1-06 make them in `release/store/`):
  - App icon: 512x512 PNG (alpha OK, under 1,024 KB).
  - Feature graphic: 1024x500 PNG or JPEG, **no transparency**.
  - Phone screenshots: at least 2, aim for 6-8, portrait 9:16, **no taller than 2:1** (the emulator's 1080x2400 is 2.22:1 and will be rejected: B1-06 crops/resizes to 1080x1920). No alpha.
  - Optional: tablet/foldable screenshots (7-inch and 10-inch), promo video (YouTube link).
- [ ] Save. Each section shows a green tick when complete.
- [ ] Check no franchise or competitor names appear in any text or image.

## 10. Phase 7 - Dry run with the internal test (YOU, 1 day)

The internal track has no review wait and no tester rule (up to 100 testers). It proves the file, the signing and the install before the long tests.

1. [ ] AGENTS deliver `build/release/ironstatic-0.5.0-beta.1.aab` plus its checksum and a short report (B1-01, B1-07). You do not build it yourself.
2. [ ] Play Console > **Test and release > Testing > Internal testing > Create new release**.
3. [ ] Play App Signing: accept the default ("Use Play App Signing") the first time.
4. [ ] Drag the `.aab` into the upload box. Wait for processing. Read the warnings:
   - "not 16 KB aligned" or "doesn't support 16 KB": stop, send to agents (B1-03).
   - "target API level too low": stop (B1-03).
   - "permissions" notices: expect only vibration. Anything with ads or billing: stop (B1-04).
5. [ ] Release name: `0.5.0-beta.1 (50001)`. Release notes: `First internal build.`
6. [ ] **Testers** tab: create an email list "me" with your own Google account(s) and your phone's account. **Save**. **Next > Save > Go to publishing overview > Send changes for review** (or "Publish").
7. [ ] Open the opt-in link on your phone, accept, install from Play. Launch the game. Play 5 minutes. First launch has a black screen of up to 30 s on some GPUs (shader compile); wait.
8. [ ] Look at **Test and release > Pre-launch report** after about a day. Look at the screenshots it took: a black screen all the way means a crash or the long first start.
9. [ ] Looks good? Continue to phase 8 (Path B) or phase 9 (Path A).

## 11. Phase 8 - Closed test, Path B only (YOU, 14+ days)

**Rule (verified 2026-11-09):** at least **12 testers opted in, for at least 14 days in a row**. A tester who leaves and comes back must be in for 14 consecutive days to count. Google may also reject for "insufficient tester engagement". Aim for **20+** testers so that a few drop-outs do not reset you.

### Recruiting tips

- [ ] Start now, before the build is ready. You need Google account emails (Gmail), and each tester needs an Android phone with Play.
- [ ] Easiest tester list: create a **Google Group** (groups.google.com), add everyone, and give Play the group address. People join the group; you do not retype emails. Then people use the opt-in link.
- [ ] Who: friends and family with Android phones (aim for 8-10), colleagues, your Discord or community, game testing communities (search for "Android closed testing" groups on Reddit and Discord; many are mutual: you test theirs, they test yours). Be honest in your ask: "Install, open it a few times over two weeks, tell me what is broken."
- [ ] Avoid paid "install farms" and fake accounts. Google checks engagement, and bad testing can cost the account.
- [ ] Message to send: the opt-in link, "stay opted in and keep it installed for 14 days", "open it on at least 4 different days", and where to send feedback.
- [ ] Ask testers to press Back out of nothing special; just play. Idle-game players: tell them it is fine to leave it running.
- [ ] Day 1 of the clock is the day 12+ people are opted in. Count by the Testers tab in Play Console. Keep a spare list of 5 more people to add if somebody drops.

### Steps

1. [ ] **Test and release > Testing > Closed testing > Create track** (name it "Beta testers") > **Create new release**. Upload the same AAB (or a newer one: each upload needs a higher versionCode). Release notes: what to try (see section 15).
2. [ ] **Testers** tab: add the Google Group or email list. Set the **feedback channel** (URL or email shown to testers; use the feedback form link from B1-08, or your public email).
3. [ ] **Countries/regions** tab: pick the countries where your testers live.
4. [ ] Send for review. Closed-test releases are reviewed too; first review can take days.
5. [ ] Send testers the opt-in link (Testers tab > "Copy link"). The testers must accept it on the web page, then install from Play.
6. [ ] Wait 14 days. You can ship fixes during this time (new AAB, higher code, same track). Keep a note of the date when you first reached 12.
7. [ ] When the Dashboard shows the requirement met: **Dashboard > Apply for production**. Fill the three parts:
   - *About your closed test:* how you recruited, how many testers, what feedback you got and what you changed. Be specific and true.
   - *About your app/game:* what it is, who it is for, what value it gives.
   - *About your production readiness:* what is left to do before a public launch (it is a beta; say so).
8. [ ] Click Next, Next, **Apply** (leaving a page without Next or Apply loses your text). Google replies by email, "usually seven days or less, but can occasionally take longer". If they say you need more testing, keep the test running and fix what testers reported.

## 12. Phase 9 - Open test (YOU)

Only available after production access (Path B) or straight away (Path A).

1. [ ] **Test and release > Testing > Open testing**. Select the countries (default recommendation: English-first countries first - US, Canada, UK, Ireland, Australia, New Zealand and the Nordics; widen later; open question Q85).
2. [ ] **Create new release**, upload the beta AAB (higher versionCode than anything uploaded before), release notes (section 15).
3. [ ] **Testers** tab: **Manage testers**: unlimited (recommended), or a limit of at least 1,000. Add the **feedback channel** (URL or email; shown on the opt-in page).
4. [ ] Save. Check **Publishing overview** shows no errors. **Send changes for review**. Wait. Reviews can take hours to several days (not documented by Google).
5. [ ] After approval: for a new app not yet in production, people find the test by searching Play; anyone with the shareable link can join. Copy the link and share it on the codex site and wherever you recruit. The store page shows the app as a test version; testers cannot leave public star reviews on test versions (feedback goes to your channel). Whether the page shows an "Early access" badge is not documented by Google; do not rely on it.
6. [ ] Open the link on your own phone from a clean state (uninstall the internal test build first, or use another account) and install.

## 13. What to do after the beta opens

- [ ] **Feedback:** check the feedback form / inbox every few days. Triage into: crash, wrong number, confusing, wish. Send the list to the main agent as a playtest report (`docs/playtests/`).
- [ ] **Crashes:** Play Console > **Quality > Android vitals > Crashes and ANRs**. No Sentry in the beta (Q81), so this is the only crash source. Google's "bad behavior" thresholds: user-perceived crash rate 1.09% of daily users (8% on one phone model), ANR rate 0.47% (8% per model). Going over lowers discoverability and may show a warning on the listing. Check weekly.
- [ ] **Pre-launch report:** open it after every upload.
- [ ] **Updates:** every fix is a new AAB with a higher versionCode (B1-02 bumps it), uploaded to the same track and sent for review. Keep release notes short and honest ("Fixed PURGE stalling at wave 40").
- [ ] **Saves:** progress is stored on the device. Uninstalling wipes it (backup is off). Tell testers.
- [ ] **Keep the clock honest:** do not let a Path B closed test drop below 12 testers before production access is granted.
- [ ] Before the public launch (M7): redo Data safety, content rating, ads declaration and the privacy policy when ads, billing, accounts, Sentry or analytics arrive. A store build with different data behavior than the form says is a policy violation.

## 14. Troubleshooting - common rejections and errors

| Message or symptom | Cause | Fix |
|---|---|---|
| "You uploaded an APK or AAB that is signed with a debug key" / "debug certificate" | Built with the debug keystore | Rebuild with B1-01 script (release preset, "Export With Debug" off) |
| "Version code N has already been used" | Reused versionCode | Bump with the B1-02 tool; codes only go up |
| "Your app targets API level 35. New apps must target API 36 or higher" | `target_sdk` empty or old template | B1-03: set 36, rebuild template |
| "Your app doesn't support 16 KB memory page sizes" | A native library is 4 KB aligned (often a plugin) | B1-03; remove or update the plugin (B1-04 removes Sentry/Ads/Billing from the beta) |
| "Declaration of Advertising ID / AD_ID permission missing or present" | A plugin merged `AD_ID` into the manifest | B1-04: strip it; Ads declaration says "No ads" |
| Data safety mismatch / "your app collects data that you did not declare" | A library sends data (Sentry, Firebase, ads) | Remove the library or change the form; never ship a mismatch |
| "Privacy policy URL not accessible" / "doesn't mention your app" | Pages not deployed, not public, or wrong app name | Open the URL in a private window; policy must name IRON STATIC and the developer name as shown on Play |
| "Screenshots rejected: aspect ratio" | Longer side more than 2x the shorter (1080x2400) | Use B1-06 files (1080x1920) |
| "Feature graphic must be 1024x500 without alpha" | Banner is 1280x640 or a PNG with alpha | Use the B1-06 file |
| "Your app has a content rating issue" | Questionnaire missing or changed content | Redo the questionnaire (phase 5) |
| "Target audience: appeals to children" warning | Under-13 selected, or art looks child-directed | Select 13+ only; do not use cartoon mascots; contact policy support if challenged |
| "Package name already exists / is not available" | Another developer owns `com.normalexception.game` | Pick a new ID before ever uploading (Q30), update the preset |
| Rejected for impersonation / intellectual property | Listing text or art looks like another game or a film franchise | Remove the offending text or image; the game is original (CLAUDE.md IP rules) |
| "Closed testing requirement not met" / production access denied | Fewer than 12 opted-in testers, or low engagement | Keep the test open, add testers, ask them to play; reapply |
| Opt-in link says "item not found" | Tester not on the list, wrong Google account, release not yet approved | Check the Testers tab and the account they use; wait for review |
| Pre-launch report shows a black screen / crash | First start shader compile, or a real crash | Read the logs in the report; run the AAB on the emulator and phone (B1-07) |
| "App not compatible with your device" | Wrong ABI or min SDK | We ship arm64-v8a and x86_64, min Android 7; tell us the model |
| Account suspended / developer verification prompt | Incomplete verification or policy issue | Follow the email; do not publish more until resolved |

## 15. Texts you will paste

**Release notes (internal / closed / open), first build:**

```
First beta of IRON STATIC. Play a few deployments and tell us what feels off.
Try: both wave modes (TIMED, then PURGE once it unlocks), the wave-10 patch pick, the Foundry, the three frames.
Known: first launch can show a black screen for up to 30 seconds while shaders compile.
No ads, no purchases, no account. Progress is saved on this device only.
```

**Tester invitation (closed test):**

```
I'm testing the beta of my Android game IRON STATIC (an idle sci-fi defense game).
1. Open this link on your Android phone and tap "Become a tester": <opt-in link>
2. Install it from Google Play.
3. Please keep it installed for 14 days and open it on a few different days.
4. Tell me what is confusing or broken: <feedback link>
Thanks, it really helps.
```

## 16. Open questions for you (recommended defaults)

These are also in `docs/design/09_open_questions.md` as Q78-Q86. If you do not answer, the default is used.

| Q | Question | Default |
|---|---|---|
| Q78 | When was the developer account created, and is it exempt from the 12 testers x 14 days rule (Path A vs B)? | Unknown: treat as Path B until the Dashboard proves otherwise (phase 1) |
| Q79 | Keep package name `com.ironstatic.game`? | Decided 2026-11-09: no, it is `com.normalexception.game` |
| Q80 | Target audience for the beta | 13-15, 16-17, 18+ (not under 13); no age gate in the beta; alternative 16+ only |
| Q81 | Sentry crash reporting in the beta build? | Remove it from the beta; use Play Console vitals and tester feedback; re-add at M7 with a DSN and an updated Data safety form |
| Q82 | Feedback channel | A Google Form linked from the codex Feedback page and from Settings; the same link goes in Play's feedback-channel field |
| Q83 | Public developer details and EU trader status | Support email decided 2026-11-09: `support@normalexception.net`. Use your own name and address as Play requires; "not a trader" while there is no income; revisit before M7 |
| Q84 | Where B1 sits in the roadmap | After M4 exits; closed test runs in parallel with M5; open test opens while M5 and M6 run |
| Q85 | Beta countries | US, CA, UK, IE, AU, NZ and the Nordics; widen after two weeks without crash spikes |
| Q86 | Closed-test size and who | 20 testers (12 minimum) via a Google Group; this replaces the Q36 plan to wait until M5 |
