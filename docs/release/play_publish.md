# Publishing to Google Play from the command line

Changelog: 2026-11-11 v1.1 (branch `play-closed`): the default track is now closed testing, the default status is `completed`, new `status` command and `--changes-not-sent-for-review`. 2026-11-10 v1.0 (branch `play-publish`). Tool: `tools/play_publish.py` (wrapper `tools\play_publish.ps1`), self-test `tools/play_publish_selftest.py`.

The tool uploads a signed AAB to a **testing** track and can push the store listing text and graphics that are already in this repo. It uses the Google Play Developer API (Android Publisher v3). It is optional: everything it does can also be done by hand in Play Console (`PLAY_BETA_GUIDE.md`). The repo is public, so the design rule is: the tool must be unable to leak a credential or a personal detail, even by mistake.

## What the tool will never do

- Read, print, log, copy or write the service-account key. It reads the key path only; the Google library opens the file. Every line the tool prints passes through a scrubber that removes private keys, tokens, `Authorization` headers and any email address, and the tool never prints a traceback.
- Accept a key that is inside this repo or inside any git working tree.
- Upload a test-key or debug-signed bundle, a bundle whose sha256 differs from its `.sha256` file, whose manifest package is not the one in `export_presets.cfg`, or whose versionCode/versionName differ from `release/version.json`.
- Touch the production track (only `closed`, `internal` and `open` can be chosen), manage tester emails or Google Groups, create the app, change pricing, countries, content rating or Data safety.
- Commit anything unless you pass `--commit`, see the exact package, track, versionCode, status and notes first, and confirm by typing the versionCode. The question says either "ROLL OUT to closed testing" or "save as DRAFT".
- Use the open track unless you also pass `--allow-open`. Open testing is on hold (decision Q88) until the human playtest passes.
- Send an email address, a name or a device detail: the payload is the AAB, release notes (checked: no email, at most 500 characters), listing text and the PNG files in `release/store/` (checked: no text or EXIF metadata chunks).
- Make a network call in the default mode.

## One-time setup (you)

1. **Create the app in Play Console** (game, free, package `com.normalexception.games.ironstatic`). The API cannot create an app.
2. **Complete App content** from the answer files in `docs/release/` (`data_safety_answers.md`, `content_rating_answers.md`, `declarations.md`, privacy page). Data safety stays a Console task: Google's CSV import format is not documented well enough to automate it safely, so this tool has no `data-safety` command.
3. **Create the tester list in Console** (Testing > Closed testing > Testers). The internal track has its own list. The tool does not touch testers, so no email address ever enters the repo.
4. **Google Cloud:** create a project, enable the *Google Play Android Developer API*, create a *service account* (no Cloud roles needed), and create a JSON key for it. Download the key to a folder **outside any repo**, for example `C:\dev\keys\play\`. Never put it under `C:\dev\tower*`.
5. **Play Console > Users and permissions:** invite the service account's email address as a user with the least privilege: access to **this app only**; the permission to release to testing tracks (and to view app information); add the store-presence/listing editing permission only if you want the `listing` command. Do **not** grant production release or financial permissions. Menu names move around; use the search box. New service accounts can take some time to become active.
6. **Add the path to `secrets.local.json`** (git-ignored; copy the file to the checkout you run from, or use `--secrets <path>`):

   ```json
   { "play_service_account_json": "C:\\dev\\keys\\play\\ironstatic-play.json" }
   ```

   The environment variable `PLAY_SERVICE_ACCOUNT_JSON` overrides it.
7. **Python libraries, in a venv outside the repo** (done once):

   ```
   python -m venv C:\dev\tools\venvs\play
   C:\dev\tools\venvs\play\Scripts\python.exe -m pip install -r tools\requirements-play.txt
   ```

   The wrapper finds `C:\dev\tools\venvs\play` (or `$env:PLAY_VENV`). The versions are pinned in `tools/requirements-play.txt`. `--self-test` and the local checks need no Google library.

## Commands

All commands run from the repo root. The tool is always run as `python -I` (the wrapper does it) and refuses to talk to Google otherwise.

| Command | What it does |
|---|---|
| `.\tools\play_publish.ps1 --self-test` | offline tests with a fake API (also a step of `tools\lint.ps1`) |
| `.\tools\play_publish.ps1 release <aab>` | **dry run**: local checks only, prints what it would release, no network |
| `... release <aab> --auth-check` | local checks, then `edits.insert` + `edits.delete`: proves the key and permissions work, uploads nothing |
| `... release <aab> --validate` | uploads into an edit, sets the track, runs `edits.validate`, then **deletes the edit**: nothing is committed |
| `... release <aab> --commit` | same, then commits. Prints the plan first and asks you to type the versionCode (`--yes` skips the question) |
| `.\tools\play_publish.ps1 status` | **read-only**: lists every track with its releases (name, status, versionCodes, userFraction). Opens an edit and deletes it. Uploads nothing |
| `... listing [--validate\|--commit]` | the same three modes for the store listing text and graphics |

Options for `release`: `--track closed|internal|open` (default `closed`), `--status completed|draft` (default `completed`), `--allow-open`, `--changes-not-sent-for-review`, `--notes <file in the repo>` (default: the release-notes block of `docs/release/store_listing.md`), `--skip-aab-check` (prints a warning; by default the tool runs `tools\aab_check.ps1` on the bundle).

Track names. The tool uses friendly names. Play uses other names in its API:

| `--track` | Play Console | API name | Notes |
|---|---|---|---|
| `closed` (default) | Closed testing | `alpha` | where the testers are now |
| `internal` | Internal testing | `internal` | quick checks, no review |
| `open` | Open testing | `beta` | on hold (Q88); refused without `--allow-open` |

The plan prints both, for example `track  closed testing (API: alpha)`. Production is not available.

Status. `completed` rolls the release out to all testers on that track. `userFraction` is not used. `draft` saves the release without rolling it out. You then finish it in Console.

Review. Closed-track releases go through Google review, unlike internal. After a successful commit the tool says so. Review usually takes hours to a few days. Testers get the update after approval.

If Google says "changes cannot be sent for review automatically" (the message names `changesNotSentForReview`), nothing was committed. Run the same command again with `--changes-not-sent-for-review`. The release is then committed. You send it for review yourself in Play Console > Publishing overview.

Typical release:

```
.\tools\release_build.ps1                               # signed AAB + .sha256 in build\release\
.\tools\play_publish.ps1 release build\release\ironstatic-<versionName>-<versionCode>.aab
.\tools\play_publish.ps1 release build\release\ironstatic-<versionName>-<versionCode>.aab --auth-check
.\tools\play_publish.ps1 release build\release\ironstatic-<versionName>-<versionCode>.aab --validate
.\tools\play_publish.ps1 release build\release\ironstatic-<versionName>-<versionCode>.aab --commit
```

Notes on Play behaviour:

- **Draft app.** While the app is still a draft in Console, Play may accept only releases with status `draft`; finish the rollout once in Console. The default is `completed`. If Play refuses it, use `--status draft`; the tool says so.
- **First upload.** Historically the very first bundle of a new app had to be uploaded by hand in Console. If the API refuses the first upload, the tool tells you to upload that one file in Console (Testing > Internal testing > Create release); later versions go through the tool. versionCode must always be higher than every earlier upload.
- **Release notes** come from a file inside the repo, language `en-US`, at most 500 characters.
- **Listing.** `listing` reads the app name, short and full description from `docs/release/store_listing.md` (limits 30 / 80 / 4,000) and the images from `release/store/` (`icon_512.png`, `feature_1024x500.png`, `phone_*.png`, sizes checked). It **refuses while `docs/release/store_assets.md` carries the "Draft: do not upload" banner** (Q31, the trademark search, is open). `--allow-draft-assets` overrides that; use it only for `--validate` or after you have said the set is approved. Contact details, privacy URL and category stay in Console. Existing images of the three types are replaced.
- Exit codes: 0 ok, 1 refused or failed, 2 usage or configuration.

## Running it in GitHub Actions

The release workflow can run `--validate`, a draft `--commit --yes` or a rollout to closed testing for you, with the keys held in a protected GitHub environment. Setup and the leak steps for those secrets: [ci_release.md](ci_release.md).

## If a key leaks

1. Google Cloud Console > IAM and Admin > Service accounts > your account > Keys: **delete the key**. A deleted key stops working at once.
2. Play Console > Users and permissions: remove the service account's access (or the user entirely).
3. Create a new key only after you know where the old one escaped to. If it reached a git commit, the history needs cleaning as well; deleting the key is what makes the leaked copy harmless.
4. Check the Play Console release history for anything you did not do.

## Belt and braces in this repo

- `.gitignore` ignores `*service-account*.json`, `*service_account*.json`, `play-*.json`, `client_secret*.json`, `*.p12`, `*.pfx`, `*.pem`, `*.jks`, `*.keystore` and `secrets.local.json`.
- `tools\lint.ps1` (repo rules, `tools/lint_repo.py`) fails if any file git would add contains a private-key block, a service-account key JSON, a private-key field or a service-account email address. The patterns are built from parts so the rule and its tests do not trip themselves.
- Do not paste a key, a token or an email address of the service account into docs, issues, commit messages or chat.
