# Release checklist (B1-09)

Changelog: 2026-11-09 v1.0 (B1-09, branch `b1-docs`).

One page, copied per release. Tick with `[x]`, add the date and initials of who ticked (agent or user). Part A is done once before the first upload. Part B is repeated for every upload. Each Play Console answer behind this list is recorded in `data_safety_answers.md`, `content_rating_answers.md`, `declarations.md` and `store_listing.md`. The guide for the user is `PLAY_BETA_GUIDE.md`.

**Hard gate:** the privacy page, Data safety and declaration answers are true only for the B1-04 beta build (no Billing, no AdMob/UMP, no Sentry, no Nakama, only `VIBRATE`). Do not submit any answer until B1-04 is done and `tools\aab_check.ps1` prints PASS on the exact AAB.

## A. Once, before the first upload

Owner: **U** = user, **A** = agents.

- [ ] **A** B1-04 done: plugins off, permissions exactly `VIBRATE` (`docs/release/beta_build_decisions.md` exists, `plugin_matrix.md` has the four decision lines).
- [ ] **A** `tools\aab_check.ps1` PASS on the release AAB (permissions, exported components, 16 KB, target SDK 36, min SDK 24).
- [ ] **A** B1-07 smoke test on the exact AAB: emulator and phone, report with AAB sha256.
- [ ] **U** Real-phone smoke done: install, full run to Results and back, resume after killing the app, haptics, no black screen over 30 seconds.
- [ ] **A** B1-05 privacy page merged to `main`, Pages workflow green. **U** `https://paimonsoror.github.io/iron-static/privacy/` loads in a private window. (A done 2026-11-09: d3d307d, Pages green after one rerun of a GitHub-side deploy error, URL returns 200; the U check is yours.)
- [x] **U** Placeholders filled in `site/docs/privacy.md` (2026-11-09): developer name `Paimon Sorornejad` (must match the name shown on Google Play) and support email `support@normalexception.net`. No personal email committed anywhere (grep below).
- [ ] **U** Public developer details decided (Q83): developer name `Paimon Sorornejad` and support email `support@normalexception.net` decided 2026-11-09; the address shown on the store page and the EU trader status still open.
- [ ] **U** Trademark and name search done (Q31): Google Play, USPTO, EUIPO, web, handles. Result recorded. Fallback name EMBER CHASSIS.
- [x] **U** Package name final (Q79): `com.normalexception.games.ironstatic`, decided 2026-11-10 (replacing `com.normalexception.game`) and applied to both presets, the tools and the docs (permanent after the first upload).
- [ ] **U** Upload keystore created and **backed up in two places** (not in the repo, never pasted into chat); passwords in a password manager; only in `secrets.local.json` or environment variables locally.
- [ ] **U** Developer account verified, 2-Step Verification on, Play Console app installed on a real device (guide section 3, phase 1).
- [ ] **U** Account path known (Q78): exempt (open test directly) or Path B (closed test 12 testers x 14 days, then production access).
- [ ] **A** Store graphics B1-06 in `release/store/` meet the size rules; no franchise names in text or art.
- [ ] **A** B1-08 shipped in the build (version label, feedback link). If not, remove the feedback sentences from `store_listing.md` and the "Feedback" section of the privacy page.
- [ ] **U** Feedback form URL (Q82) filled in `[FEEDBACK FORM URL]` entries and in Play's open-test feedback-channel field.
- [ ] **U** Answers entered in Play Console from the record files, in this order: privacy URL, app access, ads, content rating (record the ratings), target audience, Data safety, government/financial/health/news, advertising ID, account/data deletion, trader status. Each result matches the expected one (Teen-class rating; Data safety "No data collected / No data shared").
- [ ] **U** Said "reviewed" on the record files (B1-09 acceptance).

## B. Every release (each AAB upload)

1. [ ] Decide the build: `release/version.json` stage and number; `tools\release_version.ps1 -Bump build` (or patch/minor), then `-Apply` (done by `release_build.ps1`). versionCode is higher than every earlier upload.
2. [ ] Clean working tree on the release commit; `git status` shows no `.jks`, `.keystore`, `.aab`, password or `secrets.local.json`.
3. [ ] `.\tools\test.ps1` green. `.\tools\lint.ps1` green. CI green on the commit (watch GitHub Actions).
4. [ ] `.\tools\release_build.ps1` produces `build/release/ironstatic-<versionName>-<versionCode>.aab`; note size and sha256.
5. [ ] `.\tools\aab_check.ps1` PASS; paste the permission list and checks into the release notes file or issue.
6. [ ] Exact-AAB install (bundletool universal APK) on emulator and phone; `.\tools\smoke_android.ps1` clean (B1-07 procedure); full run to Results and back.
7. [ ] **Re-do check** (see list below): did anything in this build change data handling? If yes, redo the affected answers and the privacy page first.
8. [ ] Listing text check: `store_listing.md` still matches the build (mode names TIMED/PURGE, frames VANGUARD/BULWARK/STRIKER, first patch pick at wave 5, "no ads, no purchases, no account" still true). Lengths: name <= 30, short <= 80, full <= 4,000, release notes <= 500.
9. [ ] Scans clean on the changed files: franchise/brand scan and profanity scan of `data/strings_en.csv` (commands below), no email pattern in the privacy page and the record files.
10. [ ] Release notes written (what changed, what to test, known issues).
    Optional: `tools\play_publish.ps1` can do this upload through the Play API (dry run by default, `--validate`, then `--commit`); setup and safety rules in `docs/release/play_publish.md`.
11. [ ] **U** Upload the AAB to the chosen track (internal first, then closed/open per the guide). Read the warnings; read the pre-launch report when it arrives; any permission or SDK notice other than vibration means stop.
12. [ ] Tag the release commit `v<versionName>` (local tag; the user pushes). Record the Play release date, track and versionCode in this file's log below.

## Re-do when

Adding any of these to a build requires redoing **Data safety, content rating, the ads and target-audience declarations and the privacy page before that build is uploaded**: any SDK or plugin that touches the network (ads, billing, Sentry or any crash reporter, analytics, Firebase, Nakama), any new permission (INTERNET included), any network call, ads, purchases, accounts or sign-in, user-generated content or chat, leaderboards, cloud save, an age gate, a change of target audience, a change of developer or contact details. These arrive in M7 with their own checklist.

## Scan commands (run from the repo root)

```
git grep -n -i -E "terminator|skynet|cyberdyne|t-800|t-1000|hunter-killer|judgment day|i'll be back|connor|kyle reese|miles dyson" -- docs/release site/docs data/strings_en.csv ":!docs/release/RELEASE_CHECKLIST.md"
git grep -n -E "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}" -- site/docs/privacy.md docs/release/store_listing.md docs/release/data_safety_answers.md docs/release/content_rating_answers.md docs/release/declarations.md
```

The first should print nothing (the checklist file is excluded from it because it contains the pattern). The second may print only the public support address `support@normalexception.net` (Q83), which is meant to be public; any other address is a mistake. Matches that are quotations in the IP guardrail documents themselves (`docs/design/00_overview.md`, `CLAUDE.md`) are expected and not part of these paths. The profanity scan of the strings file is described in `content_rating_answers.md`.

## Release log

| Date | versionName | versionCode | Track | Notes |
|---|---|---|---|---|
| | | | | |
