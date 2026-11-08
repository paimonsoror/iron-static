# Android export preset `IronStatic`

Changelog: 2026-11-07 v1.0 (M0-07). Gradle switched on in M0-09, see `gradle_build.md`.

`export_presets.cfg` (tracked, no secrets) holds one preset, `IronStatic` (Android, runnable):

| Option | Value |
|---|---|
| `package/unique_name` / `package/name` | `com.ironstatic.game` (provisional) / `IRON STATIC` |
| `version/code` / `version/name` | `1` / `0.0.1` |
| architectures | arm64-v8a and x86_64 on; armeabi-v7a and x86 off |
| `screen/immersive_mode` | `true` |
| `package/signed` | `true` (Godot debug keystore from editor settings) |
| `permissions/internet` | `true` |
| `export_path` | `build/com.ironstatic.game.debug.apk` |
| `exclude_filter` | `tests/*, tools/*, docs/*, addons/gdUnit4/*, reports/*, backend/*` |
| `gradle_build/use_gradle_build` | `true` since M0-09 (was `false` for the M0-07 deploy; M0-07 APK size below is the non-Gradle build) |

## Deploy

```powershell
.\tools\run_emulator.ps1                     # wait 25 s after a cold boot
.\tools\deploy_android.ps1 -ProjectPath C:\dev\tower -Package com.ironstatic.game -Preset IronStatic -LogSeconds 40
.\tools\smoke_android.ps1 -SkipDeploy
```

## M0-07 result (non-Gradle export)

- Deploy ended with `== RUNNING (pid 4214)`; log lines `game boot, version 0.0.1` and `boot ok` from the `Log` autoload.
  Godot reported `OpenGL ES 3.0 ... Compatibility ... Intel(R) Iris(R) Plus Graphics` (host GPU working).
- Debug APK size (arm64-v8a + x86_64, no Gradle): **57,132,262 bytes (54.5 MiB)**.
- Wall time of that first deploy incl. import, export, install and 40 s log: about 273 s.
- Screenshot `docs/setup/ironstatic_skeleton.png`: 1080x2400 portrait, near-black `#07090C` background, amber `IRON STATIC`
  centred, dim amber `build 0.0.1` at the bottom.
- `adb logcat -d` contains no `SCRIPT ERROR` or `FATAL`.
- Immersive-mode dialog ("Viewing full screen"): did not appear on this emulator image (already dismissed by the earlier
  smoke-test project, state persists in the AVD). `adb shell settings put secure immersive_mode_confirmations confirmed`
  returns 0 and reads back `confirmed`; whether it suppresses the dialog on a fresh AVD was not testable here. If the
  dialog shows, tap "Got it" once.

## Gotchas

- Deploy script and PowerShell 5.1: `deploy_android.ps1` sets `ErrorActionPreference=Stop`; any native stderr line
  (adb "daemon not running", a Godot WARNING) in `& exe 2>&1` becomes a terminating error in some hosts. Run it as
  `powershell -NoProfile -File tools\deploy_android.ps1 ...` from a local drive path; `smoke_android.ps1` does so itself.
- Gradle build: see `gradle_build.md` (sets `gradle_build/min_sdk="24"`).
- Release keystore: see `export/README.md`.

## Files in `.gdignore`d folders are never exported (M2-16)

Changelog: 2026-11-08 added after the M2 emulator bug where every label showed its string key.

`data/` contains a `.gdignore`, so Godot does not see its files at all and never packs them into the APK or PCK. An
`include_filter="data/strings_en.csv"` does NOT help (verified on the emulator; keep `include_filter` empty). Anything
the game reads at runtime from `res://data/` silently fails on a device (`FileAccess` says file not found) while
working in the editor and in headless tests.

Rule: runtime data must be a generated resource under `src/data_gen/` (written by the importer, loaded with `load()`),
never a raw CSV. Current examples: `strings_en.tres` (`StringTable`), `number_suffixes.tres` (`NumberSuffixTable`), the
sim tables. The CSV stays the source and the loader may fall back to it for tools and tests. Each such table has a test
that the generated resource exists and equals its CSV.

Check what an APK really contains (after `deploy_android.ps1`, or any export):

```powershell
py -3.12 -I -c "import zipfile; z = zipfile.ZipFile(r'C:\dev\tower\build\com.ironstatic.game.debug.apk'); print([n for n in z.namelist() if 'data_gen' in n or n.endswith('.csv')])"
```

Expect `assets/src/data_gen/*.tres` (and `.gdc` scripts) and no `data/*.csv`.
