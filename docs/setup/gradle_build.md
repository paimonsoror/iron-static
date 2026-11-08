# Gradle build spike (Godot 4.7.2 + Android build template)

Changelog: 2026-11-07 v1.0 (M0-09). Result: Gradle export works on this machine.

## Setup done

- Build template installed by the **fallback**: `android_source.zip` from
  `%APPDATA%\Godot\export_templates\4.7.2.stable\` expanded into `android\build\`
  (`Expand-Archive`, 11 s, 207 MB), and `android\.build_version` written with the text `4.7.2.stable` (no newline).
  The format was inferred (a project on 4.7.2 holds exactly that string; newer Godot refuses a template whose
  `.build_version` differs from the running editor). The export accepted it ("build template not installed" was not reported).
  The editor menu Project > Install Android Build Template should produce the same result.
- `android\build\gradle.properties`: `org.gradle.jvmargs=-Xmx3g` (template default was 4536m) and `org.gradle.daemon=false` (see below).
- `android\build\.gdignore` (empty): keeps Godot from scanning the template; it contains a test project
  (`src/instrumented/assets/project.godot`) that otherwise produces a "Detected another project.godot" WARNING on stderr.
- `export_presets.cfg`: `gradle_build/use_gradle_build=true`, `gradle_build/min_sdk="24"`, `gradle_build/export_format=0`.
- Gradle 8.11.1 (wrapper) is downloaded on first build into `%USERPROFILE%\.gradle` (about 1.2 GB after the first build).
  JDK comes from the editor setting `java_sdk_path` (JDK 17); the system `java` (11) is not used.

## Timings (4-core laptop, emulator running, Gradle 8.11.1, JDK 17)

| Build | What | Wall time |
|---|---|---|
| 1st | cold: Gradle download + dependency download + build | about 10 min to a finished APK (template copied 18:39, APK 18:49) |
| 2nd | no changes, `org.gradle.daemon=false` | **247 s for the whole `deploy_android.ps1` run**, including import, install and its 40 s log window |

Build 1's script run showed 1165 s because of the daemon hang below, not because of Gradle.
APK size with Gradle: **162,789,175 bytes (155 MiB)** versus 57.1 MB for the non-Gradle export (M0-07). The Gradle template ships
the full debug engine AAR for both ABIs (unstripped native libs); release builds are expected to be much smaller.
Both runs ended with `== RUNNING`, logcat showed `game boot, version 0.0.1` and `boot ok`, and
`tools\smoke_android.ps1 -SkipDeploy` printed `SMOKE OK`.

## Errors hit and fixes

1. **Godot WARNING on stderr aborts `deploy_android.ps1`** (`Detected another project.godot at res://android/build/src/instrumented/assets`,
   later `res://build/canary`): the script has `ErrorActionPreference=Stop` and `& godot ... 2>&1 | Out-Null`; in Windows PowerShell 5.1
   the first stderr line becomes a terminating error in hosts that capture streams. Fix: `android\build\.gdignore` and
   `build\.gdignore` (the `build/` output folder is also scanned by Godot otherwise, which even created `build\pre.png.import`).
2. **`deploy_android.ps1` hangs after the APK is built** until the Gradle daemon dies (observed about 10 minutes until `gradlew --stop`):
   the daemon inherits Godot's stdout pipe, so `| Out-String` never reaches end of file. Fix: `org.gradle.daemon=false` in
   `android\build\gradle.properties` (also saves about 1.7 GB RAM). Recovery if it happens anyway: run
   `$env:JAVA_HOME='C:\dev\tools\jdk-17'; C:\dev\tower\android\build\gradlew.bat --stop`.
3. Running the deploy script a second time while the first one still writes its log fails with "Device or resource busy" on the log file
   (harmless; do not start a second copy, wait for the first).
4. Memory: Gradle daemon reached 1.7 GB resident next to the emulator (about 3 GB); no OOM with `-Xmx3g`.

## Version control

- `.gitignore` line `build/` is unanchored, so it also ignores the whole `android/build/` template (including `gradle.properties`).
  The template is NOT tracked right now. To track the config but not outputs, replace `build/` with `/build/` and add
  `android/build/libs/` (two 100-112 MB AARs, above GitHub's 100 MB limit, they come from the zip). See the report to the main agent.
- Gradle outputs (`android/build/build/`, `android/build/.gradle/`) are already ignored; `git status --short` shows no build outputs.
- `android/.build_version` is not ignored and is untracked (commit it).
