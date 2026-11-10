# CLAUDE.md - IRON STATIC

IRON STATIC (code name `ironstatic`, applicationId `com.normalexception.game`) is an original Android-first, portrait, free-to-play idle defense game in Godot 4.7.2 (statically typed GDScript). You are CINDER, a reprogrammed combat cyborg at the Relay; rogue machine swarms attack from every side; Cinder auto-fires a hitscan laser; the player buys temporary upgrades with `scrap` during a deployment and permanent ones with `data` between deployments. The user directs and playtests on the emulator; Claude and AI agents write nearly all code.

## Doc map (read the one you need, not all)

| What | Where |
|---|---|
| Game rules, terms, numbers, ids (source of truth for the game) | `docs/design/00..09_*.md` (GDD; plus `10_art_bible.md`, `11_title_and_frames.md`). Start with `00_overview.md` section 8 glossary |
| Technical decisions (source of truth for technology) | `docs/TECH_ARCHITECTURE.md` |
| Milestones M0-M7, P1, P2, critical path, Play timeline | `docs/ROADMAP.md` |
| Agent-ready tasks | `docs/tasks/M0.md`, `M1.md`, `M2.md`, `V1.md`, `A1.md`, `M3.md` (meta loop, persistence, title screen and frames; done 2026-11-09, carried items listed at its end), `M4.md` (patches, wave modes, feel, FTUE), `B1.md` (Play open beta: signed AAB, privacy page, store assets, test tracks; user guide `docs/release/PLAY_BETA_GUIDE.md`) (later files are written when the previous milestone closes) |
| Toolchain, emulator, troubleshooting | `docs/setup/DEV_ENVIRONMENT.md` (+ other `docs/setup/*.md` written in M0) |
| Open questions (ONE list) | `docs/design/09_open_questions.md` |
| Background research on The Tower | `docs/research/` (comparison only) |

## Source-of-truth rules

- GDD wins on game rules, terms, numbers and ids. TECH_ARCHITECTURE wins on technology. If they conflict, stop, fix the losing doc in the same change, and add a changelog line at its top.
- Use GDD vocabulary only: currencies `scrap`, `data`, `flux`, `cipher`, `merit` (exactly five, never add one without a GDD change); Foundry, Lab, Arsenal, weapon systems, firmware, patches, sectors, deployments, Gauntlets, Incursions, Cells. Never use The Tower's words (Cash, Coins, Gems, Power Stones, Workshop, Ultimate Weapons, Cards) in code, data or UI.
- Numbers live in `data/*.csv` (ids from the GDD), not in code. Edit CSV, run the importer, commit CSV plus generated `src/data_gen/*.tres`. Never hand-edit `src/data_gen/`.
- Scope tags in the GDD: MVP, Launch, Post-launch. N1 adaptive swarm, N3 salvage caches, N4 overdrive are Launch; N2 skin burn visuals MVP; N5 turncoat is deferred (P2). Gauntlets, Incursions, Operation Pass are P1; Cells P2. Do not build ahead of the current milestone.
- Open or unspecified rule? Pick the simplest option, mark it **(impl)** in the commit message, and tell the main agent so it lands in the GDD or `09_open_questions.md`.

## Architecture rules (hard)

- `src/sim/` is pure `RefCounted` code: no Node, SceneTree, Input, OS/Time, autoloads, global `randf`/`randi`. Same for `src/meta/` and `src/save/` (injected interfaces only). Enforced by `tools\lint.ps1`.
- Fixed 30 Hz tick; one wave = 24 s = 720 ticks; timers in integer ticks; game speed = more ticks per frame (cap 4x), never a scaled tick length. All randomness through `Rng` (PCG32, per-stream). Same `(seed, config, input log)` must give the same state hash.
- Entities are packed-array stores with free lists; no Node per enemy or projectile; no allocation inside per-tick loops. Rendering is MultiMesh in `src/view/` and only reads the sim.
- Number types: `BigNum` for currency and cost values (persist as strings); BigNum is immutable, text form `1.5e12` (`to_text`/`parse`), never use float math for balances, display only through `NumberFormat` (floors, 3 significant digits); `float` for per-tick combat; `int` for `flux`/`cipher`/`merit`, levels, waves, ticks.
- Save-shape change = bump schema version + migration + fixture in `tests/fixtures/`. Services (ads, billing, analytics, backend) sit behind interfaces in `src/services/` and `src/net/` with desktop stubs.
- No new plugin or dependency without a decision note in `docs/setup/plugin_matrix.md`. No secrets, keystores or real ad ids in git (`secrets.local.json` is ignored).

## Coding conventions

- Typed GDScript everywhere (every var, param, return); no `Variant` in sim code. Warnings are errors (see `project.godot`); suppress only with `@warning_ignore("name")` plus a reason comment.
- `snake_case` files, `PascalCase` `class_name`, one class per file, `UPPER_SNAKE` consts, private `_leading_underscore`, past-tense signals. Files under 300 lines (hard cap 500). Scenes expose a typed `setup(...)` and signals; never `get_node("../..")`.
- Files are **UTF-8 without BOM**, LF line endings, tabs in `.gd`. PowerShell 5.1 `Set-Content -Encoding utf8` writes a BOM: use the Write tool or `[System.IO.File]::WriteAllText(path, text, (New-Object System.Text.UTF8Encoding($false)))`.
- UI text goes through `data/strings_en.csv` keys (English only for now).

## Commands (PowerShell, from `C:\dev\tower`; do not run from a `\\wsl$` path)

Godot CLI: `C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe` (version pinned in `tools/GODOT_VERSION`).
Headless Godot can exit 0 on failure: never judge by exit code alone and never call Godot test runs directly.

| Task | Command | Exists |
|---|---|---|
| Tests (import, run, parse output) | `.\tools\test.ps1` (`-Canary` proves the wrapper detects failures) (default runs tests/unit + tests/sim; -Path takes several) | done (M0-05) |
| Lint (gdformat, gdlint, layer rules, BOM, warnings-as-errors compile) | `.\tools\lint.ps1` | done (M0-06) |
| Format GDScript (gdformat + CRLF->LF; never run gdformat directly) | `.\tools\format.ps1 [paths]` | done |
| Start emulator (AVD `tower_phone`, wait 25 s after cold boot; `-ColdBoot`, `-PublicDns`) | `.\tools\run_emulator.ps1` | done |
| Install/repair Gradle build template (untracked; after clone or Godot upgrade) | `.\tools\setup_android_template.ps1` (`-Force` reinstalls) | done (M0-09) |
| Export, install, launch on emulator | `.\tools\deploy_android.ps1 -ProjectPath C:\dev\tower -Package com.normalexception.game -Preset IronStatic` | done (M0-07) |
| Emulator smoke test (log scan + screenshot check) | `.\tools\smoke_android.ps1` (`-SkipDeploy`; `-Soak <s>`, `-MinFps <n>` need `--debug-perf`; `-ImagePath <png>` checks a screenshot offline) | done (M0-08, M1-25/26) |
| CSV to `.tres` importer | `.\tools\import_data.ps1` | done (M1-02; flags -DataDir -OutDir -SkipImport) |
| Headless sim runs (M1 exit: p50 death wave 3-12) | `.\tools\sim_run.ps1 -Runs 20 -Seed 1` | done (M1-16; TIMING on stderr) |
| Sim perf bench | `.\tools\perf_bench.ps1 [-Check]` | done (M1-17; -UpdateBaseline, baseline tests/perf_baseline.json) |
| Playtest and soak (agent skills) | `.claude/skills/playtest-report/`, `.claude/skills/soak-test/` | done (M1) |
| Balance run vs targets | `.\tools\balance_run.ps1 -Profile fresh -Waves 100 -Runs 20` | done (M2-14; exit 0 PASS/WARN, 1 FAIL, 2 error; skill: balance-check) |
| CI compile gate (portable twin of lint's compile step; CI: `docs/setup/ci.md`) | `.venv\Scripts\python.exe tools\compile_gate.py --godot <godot> --project .` | done (M0-13) |
| Render SVGs to PNG (ThorVG, same as importer) to inspect art | `.\tools\svg_render.ps1 [-Scale 2] [-Bg "#07090C"] [-Out build\svg] <files>` | done (V1) |
| Art SVG lint (rules `tools/art_rules.json`, table `assets/art/slots.csv`; part of `lint.ps1`) / pixel check of sheets (`-Canary` proves detection) | `.\tools\art_lint.ps1 [files]` / `.\tools\art_check.ps1 [-Only f]` | done (V1-02) |
| Render all audio (Claude-synthesized SFX + music via `tools/audio_gen/`: `sfx.py` 12 core, `sfx2.py` 28 more, `mix.py` loudness; deterministic; writes `assets/audio/`, the sketch pack and `sfx_reel_full.ogg` in `docs/playtests/a1/`; venv `tools/audio_gen/.venv` auto-created) | `.\tools\audio_gen.ps1 [-Assets <dir>] [-Sketch <dir>]`; after changing a recipe or a mix category: `tools\audio_gen\.venv\Scripts\python.exe -I tools\audio_gen\mix.py --write-slots --table`, then render again | done (A1-02, A1-09) |
| Screenshot from emulator | `cmd /c "cd /d C:\ && adb exec-out screencap -p > C:\dev\tower\build\shot.png"` | done |

## Definition of done (every task)

1. `tools\lint.ps1` clean. 2. `tools\test.ps1` passes with tests > 0 (add or adjust tests with every behavior change; sim changes need a sim scenario test). 3. Economy or sim changes: `tools\balance_run.ps1` output pasted in the commit message and compared to `data/targets.csv`. 4. UI or view changes: debug APK installs and launches on `tower_phone`, `tools\smoke_android.ps1` passes, screenshot attached. 5. Save-shape changes: migration and fixture. 6. Docs updated if an interface, command, schema or rule changed (changelog line at the top of the doc). 7. Sim or view perf changes: `tools\perf_bench.ps1 -Check` within 10% of baseline. 8. Acceptance criteria of the task file are all met and quoted.

## Workflow and boundaries

- Work from a task in `docs/tasks/`; read only the task and the doc sections it cites. One agent per module directory at a time. Shared files (`project.godot`, `export_presets.cfg`, `src/sim/sim_world.gd`, autoload list, `.gitignore`) are edited by the main agent or by the one task that owns them.
- Do not modify `docs/setup/` or the toolchain scripts `tools/run_emulator.ps1`, `tools/deploy_android.ps1` unless the task says so. Do not touch export presets casually. Commit only when the user asks. Never skip hooks.
- Agents verify visuals only through emulator screenshots; the user judges feel and balance. Wait 20-30 s after an emulator cold boot; the first launch has about 30 s of black screen (shader compile).

## IP guardrails (hard)

- No Terminator franchise names, marks or likenesses: no Terminator, Skynet, Cyberdyne, T-800/T-1000/T-X or any "T-number" names, Hunter-Killer or "HK", Judgment Day, Sarah/John Connor, Kyle Reese, Miles Dyson; no signature lines ("I'll be back", "Hasta la vista"); no chrome skull endoskeleton with glowing red eyes, half-flesh face, liquid-metal enemy, time-travel plot, T-shaped logo, anvil-style four-note motif. Never write "Terminator-like" anywhere (code, listing, tags).
- Original names only: Cinder (serial ASH-07), CHORUS (hostile AI), Orrery Combine, Hollow Accord, Lantern Cell. Multi-color HUD (amber primary, teal friendly, red hostile, magenta enemy fire). No The Tower names, icons, tables or layouts. Details: `docs/design/00_overview.md` section 7.

## Gotchas log (append findings; keep entries one line)

- GDScript `int` is signed 64-bit and `>>` is arithmetic: mask after shifts in the RNG and hashes.
- Godot 4.7 export targets SDK 36: Build-Tools 36.0.0 must be installed. Project icon is required for export.
- Godot's editor setting `export/android/shutdown_adb_on_exit` (default true) kills the shared adb server whenever any editor-mode Godot run exits (imports, exports, test/compile runs), which drops the phone and emulator mid-test; it is set to false in `%APPDATA%\Godot\editor_settings-4.7.tres` on this machine (2026-11-08). Re-check it after a Godot reinstall.
- `adb exec-out screencap` fails from a UNC working directory; use `C:\`. After export Godot restarts adb: `adb start-server`.
- Emulator needs `hw.gpu.mode=host`; the one-time "Viewing full screen" dialog needs a tap on first launch.
- Warnings-as-errors print as `Parse Error: <description> (Warning treated as error.)` without the warning's name; Godot output has ANSI escapes (strip before matching).
- `return_value_discarded` is Warn (1), not Error: GdUnit4 fluent asserts return values. Packed-array `append`/`push_back`/`resize` also return values.
- Never pass `-d` to headless Godot: on a script error the debugger waits on stdin and the run hangs.
- Run tests only via `.\tools\test.ps1` (GdUnit4 6.2.3 CLI needs `--ignoreHeadlessMode`; reports land in `build/test/report/report_N/results.xml`).
- `--check-only --script` does not load autoloads; compile checks go through `tools/compile_check.gd` (run by `lint.ps1`).
- Deliberately broken `.gd` files live in folders with `.gdignore` + `.lintignore`; `test.ps1 -Canary` runs them in a copy under `build/canary/`.
- Nested `project.godot` files (Gradle template, `build/canary`) make Godot print a stderr warning that aborts `deploy_android.ps1` under PS 5.1: `build/` and `android/build/` must keep their `.gdignore` (tools create them).
- Run PS tools as `powershell -NoProfile -File tools\<script>.ps1` from `C:\dev\tower`; never run two deploys at once (adb/log collisions).
- Gradle: first build ~10 min, then ~4 min per deploy; combined debug APK (Billing, AdMob, Sentry) ~179.5 MB. `org.gradle.daemon=false` is required (a daemon hangs the deploy script).
- Smoke test: `D`/`I AndroidRuntime` lines from `monkey` are normal; only error-level lines fail.
- Sentry (GDExtension, auto-loads, inert without DSN): prints a benign `ERROR: Sentry: Failed to initialize engine lifecycle tracking - SceneTree is unavailable.` on every `--script` run (allowlist it if a gate scans that output). On Android `[sentry] options/attach_log=false` in `project.godot` silences its "enable File Logging" boot errors; revisit when a DSN is set (M7).
- Emulator: host DNS may resolve ad domains to 127.0.0.1 so test ads fail; start with `run_emulator.ps1 -PublicDns` (opt-in). adb "offline" after a warm boot: `adb emu kill`, then `run_emulator.ps1 -ColdBoot`.
- Signals declared on an interface and emitted only by subclasses need `@warning_ignore("unused_signal")` (warnings are errors).
- The AdMob rewarded unit id in `ads_android.gd` is Google's test id; real ad ids must come from an ignored config before release (M7). The billing/ads boot probe in `services.gd` runs only with `--probe-services` in a debug build (how: `docs/setup/DEV_ENVIRONMENT.md`).
- Plugin verdict (M0): Billing 3.3.0, AdMob 5.1.0 + UMP, Nakama 3.4.0, Sentry 2.4.0 work on 4.7.2 (`docs/setup/plugin_matrix.md`, `godot_pin_decision.md`); Firebase and Play Games wait on the user's Firebase/Play Console project (Q37).
- `x.call(...) as SomeClass` trips `unsafe_cast`; assign to a `Variant` var first, then to a typed var.
- GDScript: `int / int` is an error (integer_division): use `floori(float(a) / float(b))` or shifts. Hex literals above 0x7FFFFFFFFFFFFFFF overflow: write signed decimals.
- gdlint rejects underscore-prefixed locals/params (`var _i`, `exp_`); `PackedXArray[-1]` silently reads the last element, so check `alloc()` results for -1 before indexing.
- Parallel test runs can collide on Sentry's GDExtension DLL copy at import; `test_runner.py` retries that transient error twice. Write large `.gd` files with the Write tool, not shell heredocs.
- Godot imports every `.csv` as a translation (fails with Invalid locale): every data CSV folder needs a `.gdignore` (`data/` has one); `FileAccess` reads `res://data/...` only in the editor and headless tools, never on a device.
- Passing a Variant (`dict[k]`, `arr[i]`) to a typed param or `float()`/`int()` fails compile: assign to a typed local first. `Resource.duplicate()` skipped non-exported vars before M1-26 (all def vars are `@export` now).
- `HashingContext.update()` errors on an empty `PackedByteArray` (skip empty slices). A param named like a method (e.g. `capacity`) shadows it (error). Unused args: `@warning_ignore("unused_parameter")` + `# gdlint: ignore=unused-argument` (underscore prefix is not enough).
- PS tools: use `Invoke-GodotRetry` (`_common.ps1`) for Godot runs that may overlap other agents; it retries the transient Sentry DLL copy collision.
- Export converts text `.tres` to binary and drops every non-`@export` script var (all sim data loaded as 0 on Android). Def vars in `src/data_defs/` must be `@export`; `project.godot` keeps `export/convert_text_resources_to_binary=false`; `test_resource_roundtrip.gd` guards it.
- `data/` is `.gdignore`d: its CSVs are never exported and `include_filter` cannot fix it; runtime data must be generated `.tres` under `src/data_gen/` (`docs/setup/android_export.md`).
- `deploy_android.ps1` output piped to a tool wrapper can hang (the adb server inherits the pipe): run via `Start-Process` with stdout/stderr redirected to files and poll for `== RUNNING`.
- GDScript `%` formatting has no `%g` (use `%.3f`); an unsupported format logs `String formatting error` on every call.
- The emulator's qemu can hang under heavy GL load (host GPU driver suspected): `adb emu kill`, then `run_emulator.ps1 -ColdBoot`; the first launch after a cold boot may lose its process once.
- Run `perf_bench` with the emulator idle or stopped: a running emulator inflates avg_ms by about 45-60% (2.65 vs 1.7 ms) and fails `-Check` against the baseline.
- `test.ps1 -Path` takes several paths comma-separated (`-Path res://tests/unit/core,res://tests/unit/ui`); space-separated silently runs only the last. GdUnit test classes: max 20 public test methods (gdlint max-public-methods).
- `floor()`/`ceil()` return Variant: use `floori`/`ceili`. UI sizes are in 1080-wide base pixels: 1 dp = 2.63 px (body text >= 38 px, touch targets >= 148 px; see `ThemeBuilder` constants).
- Call `world.command_buy` only between frames (never inside `driver.advance`); it logs `world.tick` and applies before that tick. Sim outcome changes need a `SimVersion.CURRENT` bump; after CSV balance edits refresh the golden constants in `tests/sim/test_replay.gd`.
- GDScript `%` formatting breaks on `%`-prefixed node paths (`"%Node/x_%d" % k`): concatenate. `test.ps1 -Path a,b` only splits when run from PowerShell, not via `powershell -File` from bash.
- Audio (A1): slots in `assets/audio/slots.csv` + `music_layers.csv` (`keep` importer, read by `AudioSlots`/`MusicIntensity`); audio files must not sit in a `.gdignore`d folder; python tools run with `-I` ignore the script dir, so `render.py` adds it to `sys.path`; libsndfile overflows the stack on one huge OGG `write()` on Windows (write in chunks); pitch jitter uses `AudioDirector`'s own RNG, never the sim `Rng`. A new SFX = recipe in `sfx2.py` + a row in `slots.csv` + a category in `mix.py` (its assert fails otherwise); `mix.py --write-slots` owns the `volume_db` of every sfx row (do not hand-edit); the router's heartbeat uses a `NO_BEAT` sentinel because beat index -1 is valid at tick 0.
- Art slots (V1-02): `assets/art/slots.csv` uses the `keep` importer (not a translation) and is read by `ArtSlots` via FileAccess; edit art layout there, never in code. Run python tools with `-I` (a stray `types.py` in the cwd or script dir shadows the stdlib); `ArtSlots.log_errors = false` in tests that exercise missing files (push_error fails a test run).
- Exported scripts are binary-tokenized: invisible chars (U+FEFF) inside .gd strings vanish on device (broke all art on Android, lint rule encoding-inline-bom). Use code points (0xFEFF). Data loading must be verified on the emulator/device, not only desktop; smoke fails on ERROR: ArtSlots:/Strings:.
- MultiMesh 2D buffer (V1-10, changed V1-29): 8 floats per instance = transform only (`c0.x c1.x 0 c2.x c0.y c1.y 0 c2.y`); flash, frame, spawn-in, phase are 4 floats per instance in a per-type RGBAH data texture (built as RGBAF, then `Image.convert`: the Pixel's ANGLE driver has no float32 textures and Godot would convert plus warn on every upload; `MultiMeshBuffer.DATA_FLOATS`, texel x = INSTANCE_ID, one row, max 4096 instances); `mm.buffer` is empty under the headless dummy renderer; `VisualQuality`/`Log` need autoloads, so `-s` capture scripts must not name `BattleView` as a type (use `load()` + `call`).
- A Control already in the tree (in `_ready`) needs `set_anchors_and_offsets_preset`, not `set_anchors_preset`: the latter keeps the current (0x0) rect, so a FULL_RECT overlay collapses to the top-left corner (pause overlay bug on the phone).
- Compatibility renderer: MultiMesh instance COLOR/CUSTOM arrive in vertex() as 16-bit halves (exact ints <= 2047; only the transform is float32). Antialiased draw_arc/draw_polyline cost extra draw calls: use one non-AA draw_polyline_colors. No return inside vertex().
- Do not use MultiMesh `use_colors` / `use_custom_data` for per-frame data (V1-26, V1-29): on the Pixel's PowerVR GPU via ANGLE the packed-half COLOR/CUSTOM attributes arrive as garbage once they change every frame (white/green/invisible enemies, giant yellow particle flashes), while a static buffer renders fine and the desktop/emulator never show it. Keep the MultiMesh transform-only and put per-instance fields in a data texture (built RGBAF, uploaded as RGBAH: keep each field fp16-safe) read with `texelFetch(..., ivec2(INSTANCE_ID * n + k, 0))` (see `ParticlePack`, `MultiMeshBuffer`, `enemy_sprite.gdshader`); highp and clamp in the shader.
- Save/meta code (M3): `src/meta/`, `src/save/` and `src/core/save_service.gd` may not use the autoload words `Game Profile SaveManager Content Services Clock Events Log` as identifiers (`tools/lint_repo.py` word match), hence `PlayerProfile`, `SaveService`, `ClockSource`; `Game` owns `saves`, `clock` and the profile (`saves.profile`), no new autoloads. Windows `DirAccess.rename` onto an existing file fails: `DiskSaveFs.rename` removes the target first.
- `ConfirmDialog` (`src/ui/flow/confirm_dialog.gd`) is built in code only, no `.tscn`: create it with `ConfirmDialog.new()` and `add_child` (the router and the Settings screen each own one).
- Adding a data table (`data/*.csv` built by `DataMetaTables`): also add it to the `TABLES` copy list and bump the expected file count in `tests/unit/data/test_importer.gd`, or the importer test fails on the count.
- Parallel test runs in several git worktrees used to share one `user://` (same project name, `%APPDATA%\Godot\app_userdata\IRON STATIC`) and clobbered each other's scratch files (flaky `test_importer.gd`, "Godot timed out"). `tools\test.ps1` now points `APPDATA` at `build\test_appdata` per checkout; keep that if you add another Godot test wrapper.
