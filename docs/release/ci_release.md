# Release pipeline (GitHub Actions)

Changelog: 2026-11-10 v1.0 (branch `ci-release`). Workflow `.github/workflows/release.yml`, runner setup `tools/ci_setup_windows.ps1`.

The workflow builds the beta AAB on a GitHub runner with the same scripts you run on your PC. It has no build logic of its own.

| Step | Script (same as local) |
|---|---|
| Build, sign, check signer | `tools\release_build.ps1` |
| Audit the bundle | `tools\aab_check.ps1` |
| Validate / upload a draft to Play | `tools\play_publish.py` (through `tools\play_publish.ps1`) |

Before the scripts run, `tools\ci_setup_windows.ps1` installs the tools. Every download is checked against a hash that is pinned in this repo.

## The two modes

**Test key.** No secrets, no approval. It signs with a throwaway key made on the runner. It proves the pipeline works. The result is named `...-TESTKEY.aab` and is never published.

**Upload.** Uses the real upload key from the GitHub environment `release`. A job that uses this environment waits for your approval. It can also validate or upload a draft to Google Play.

## How to run it

```
gh workflow run release.yml -f signing=testkey
gh workflow run release.yml -f signing=upload -f publish=validate
gh workflow run release.yml -f signing=upload -f publish=draft
```

- `publish` is `none` (default), `validate` (checks the bundle with Google, commits nothing) or `draft` (validates, then commits a **draft** release on the **internal** track).
- Any `publish` other than `none` needs `signing=upload`. The `guard` job fails the run otherwise.
- `signing=upload` only runs from `main` or from a `v*` tag.
- Pushing a tag `v<versionName>` (for example `v0.5.0-beta.1`) runs upload signing and a `draft` publish. The tag must equal `v` plus `versionName` in `release/version.json`. If it does not, the job fails before it builds.
- Only one release runs at a time. A second one waits.

## What the runner uses

- Runner: `windows-2025`. It has Windows PowerShell 5.1, robocopy, JDK 17, and an Android SDK with platform 36, build-tools 35.0.1 and an NDK. So the local scripts run with no port. `ci_setup_windows.ps1` installs a missing SDK piece with `sdkmanager` at a pinned version.
- Godot editor and export templates for `tools/GODOT_VERSION`: from the official `godot-builds` release. SHA512 values are in `tools/godot_sha512.txt` (copied from the official `SHA512-SUMS.txt`).
- bundletool: version and sha256 in `tools/bundletool_version.txt`.
- The archives are cached. They are checked again on every run, so a bad cache entry cannot get through.
- The scripts find the tools through environment variables. If they are not set, the old local paths apply: `IRONSTATIC_GODOT` (console exe), `IRONSTATIC_JDK` (JDK 17 home), `IRONSTATIC_BUNDLETOOL` (jar), `ANDROID_HOME`.
- Upgrading Godot: change `tools/GODOT_VERSION`, `tools/godot_sha512.txt` and the hash in `tools/ci_setup.sh` together.

## What it stores

The AAB is **never** uploaded as a workflow artifact. On a public repo, anyone signed in to GitHub could download it. Only text is kept, for 7 days: the `aab_check` output, the size report (`.txt`) and the `.sha256` file. In upload mode the bundle reaches Google only through `play_publish` and only as a draft.

## One-time setup for the upload path (you)

Do this in your own terminal. Never paste a value into a chat, an issue or a file in the repo.

1. In the repo on GitHub: Settings, Environments, New environment, name `release`.
2. Required reviewers: add yourself.
3. Deployment branches and tags: select "Selected branches and tags". Add the branch rule `main` and the tag rule `v*`.
4. Add these to the `release` environment. Run them from PowerShell in a folder outside the repo:

| Name | Kind | Value | How to set it |
|---|---|---|---|
| `ANDROID_UPLOAD_KEYSTORE_B64` | secret | the upload keystore, base64 | `[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\dev\keys\ironstatic-upload.jks')) \| gh secret set ANDROID_UPLOAD_KEYSTORE_B64 --env release --repo paimonsoror/iron-static` |
| `ANDROID_UPLOAD_KEYSTORE_PASSWORD` | secret | the keystore password | `gh secret set ANDROID_UPLOAD_KEYSTORE_PASSWORD --env release --repo paimonsoror/iron-static` (gh asks for the value and hides it) |
| `PLAY_SERVICE_ACCOUNT_JSON` | secret | the contents of the service-account key file | `Get-Content -Raw <path to the key file> \| gh secret set PLAY_SERVICE_ACCOUNT_JSON --env release --repo paimonsoror/iron-static` |
| `ANDROID_UPLOAD_KEY_ALIAS` | variable (not secret) | `ironstatic-upload` | `gh variable set ANDROID_UPLOAD_KEY_ALIAS --env release --body ironstatic-upload --repo paimonsoror/iron-static` |

`PLAY_SERVICE_ACCOUNT_JSON` is only needed when `publish` is not `none`. The other three are always needed in upload mode. If one is missing, the first step of the job fails and names it. The job never falls back to the test key.

Where the secrets go on the runner: the upload job decodes the keystore and writes the service-account file and a small secrets JSON into the runner's temp folder, which is outside the checkout and outside any git tree. It passes them to `release_build.ps1 -SecretsPath` and to `play_publish` (through `PLAY_SERVICE_ACCOUNT_JSON`, which holds the file path). A last step that always runs deletes them. No step prints a secret value.

Only the `upload` job reads secrets. `tools/check_workflows.py` (part of `lint.ps1` and of CI) fails if `secrets.` appears anywhere else, or if an action is not pinned to a full commit SHA.

## If a key leaks

1. Upload key: in Play Console, App integrity, App signing, use "Request upload key reset". Then make a new keystore.
2. Service account: in Google Cloud, IAM, Service accounts, open the account, Keys, delete the leaked key. Make a new one if you still need it.
3. GitHub: delete the three secrets in the `release` environment (Settings, Environments, release). Set them again after step 1 and 2.
4. Check Actions runs for anything odd. Delete runs you do not trust.

## If a run fails

- Download the failed log (`gh run view <id> --log-failed`). Secret values are masked there.
- Most likely causes: a changed runner image (SDK or JDK version), a download that changed (the hash check names the file), Godot export errors (the build script prints them).
- The same commands work on your PC: `tools\release_build.ps1 -TestKey` then `tools\aab_check.ps1 <aab>`.

## Verified runs

- 2026-11-11, test key, run 42932673695 (branch `ci-release`, temporary push trigger, since removed): cold cache, test-key job 3 min 18 s. All three downloads passed their hash checks. Bundle 56.2 MB, signer = test key, `aab_check` PASS (targetSdk 36, VIBRATE only, 16 KB alignment). The upload job was skipped as designed.
- The upload path (environment `release`, secrets, Play validate/draft) has not run yet.
