# Release signing (upload key)

Changelog: 2026-11-09 v1.0 (B1-01).

- Google Play App Signing holds the real app-signing key. You create only the UPLOAD key (guide: `docs/release/PLAY_BETA_GUIDE.md` phase 2). The keystore file lives OUTSIDE the repo (for example `C:\Users\<you>\keys\ironstatic-upload.jks`) and is backed up in at least two places off this machine. If it is lost, Play lets you request an upload-key reset (Play Console, App integrity), which takes days.
- `secrets.local.json` (repo root, gitignored; template `secrets.local.json.example`) has three fields: `android_release_keystore_path` (absolute path), `android_release_keystore_user` (alias), `android_release_keystore_password` (keystore and key password, equal). Never put real values in any tracked file, commit message or log. `*.keystore`, `*.jks`, `secrets.local.json` and `/build/` are in `.gitignore`.
- `tools\release_build.ps1` sets `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER`, `_PASSWORD` for the Godot child process only. It stops if a field is empty, the keystore does not exist, or the keystore path is inside the repo.
- Local verification without the real key: `tools\release_build.ps1 -TestKey` makes `build/testkey/NOT-FOR-UPLOAD-test.keystore` (random password in `build/testkey/`, gitignored) and writes `ironstatic-<version>-<code>-TESTKEY.aab`. The script prints a loud warning; Play would reject it or, worse, bind the app to a throwaway key. Never upload a `-TESTKEY` file.
- Certificate fingerprints (SHA-1/SHA-256) of the built bundle are printed by the build script and saved next to the AAB (`.txt`).
