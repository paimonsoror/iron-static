# Building and tools

Everything you need to build IRON STATIC, run its tests and put it on an Android device. Full install notes and troubleshooting are in [`docs/setup/DEV_ENVIRONMENT.md`](https://github.com/paimonsoror/iron-static/blob/main/docs/setup/DEV_ENVIRONMENT.md).

## Prerequisites

Windows 11 with PowerShell, working from a normal drive path (for example `C:\dev\tower`), not a `\\wsl$` path.

| Tool | Version |
|---|---|
| Godot (standard, GDScript) | 4.7.2 stable, plus export templates (pinned in `tools/GODOT_VERSION`) |
| JDK | 17 (Temurin) |
| Android SDK | cmdline-tools, Platform-Tools, Build-Tools 35.0.1 and 36.0.0, platform android-35 |
| Android NDK / CMake | 28.1.13356709 (r28b) / 3.10.2.4988404 |
| Python | 3.12 (lint, the CI gate and audio tooling; `tools/requirements.txt`) |
| Emulator | AVD `tower_phone` (Android 35 x86_64, host GPU) |

## First steps

1. Install the toolchain per `DEV_ENVIRONMENT.md` and clone the repo to a local drive.
2. Install the Gradle build template once: `.\tools\setup_android_template.ps1`.
3. Run `.\tools\lint.ps1` and `.\tools\test.ps1` to confirm the setup.
4. Start the emulator (`.\tools\run_emulator.ps1`, then wait about 25 s after a cold boot) and deploy with the command below. The first launch shows about 30 s of black screen while shaders compile.

The editor can also run the project on the desktop: open `project.godot` in Godot 4.7.2. Debug-only launch arguments go after `--`: `--debug-load --debug-load-wave=<n>` (a fast-forwarded crowd), `--quality=high|mid|low`, `--shake=off|low|normal`.

## Commands

Run from the repo root in PowerShell. Judge Godot runs by the wrapper scripts' output, not by exit codes: headless Godot can exit 0 on failure.

| Task | Command |
|---|---|
| Tests | `.\tools\test.ps1` (`-Path <dir or file>` for a subset, `-Canary` proves failures are detected) |
| Lint (format, lint, layer rules, compile) | `.\tools\lint.ps1` |
| Format GDScript | `.\tools\format.ps1 [paths]` |
| CSV to `.tres` | `.\tools\import_data.ps1` |
| Export, install, launch | `.\tools\deploy_android.ps1 -ProjectPath C:\dev\tower -Package com.normalexception.games.ironstatic -Preset IronStatic` |
| Emulator smoke test | `.\tools\smoke_android.ps1` |
| Headless sim runs | `.\tools\sim_run.ps1 -Runs 20 -Seed 1` |
| Balance run against targets | `.\tools\balance_run.ps1 -Profile fresh -Waves 100 -Runs 20` |
| Sim performance bench | `.\tools\perf_bench.ps1 [-Check]` |
| Inspect a save file | `.\tools\save_dump.ps1 <file>` |
| Render SVGs to PNG | `.\tools\svg_render.ps1 [-Scale 2] <files>` |
| Art lint / pixel check | `.\tools\art_lint.ps1` / `.\tools\art_check.ps1` |
| Render all audio | `.\tools\audio_gen.ps1` |
| Start the emulator | `.\tools\run_emulator.ps1` |
| Re-render the README banner | `godot --path . res://src/debug/title_frame.tscn -- --tf-banner=<dir> --mute` |
| Re-render the README and codex screenshots | `godot --path . --windowed --resolution 540x600 res://src/debug/docs_shots.tscn -- --dx-out=<dir> --mute --no-save`, then `godot --headless --path . --script res://src/debug/img_tool.gd -- --out=<file.jpg> --width=540 <png>` to crop and downscale |

## Continuous integration

GitHub Actions (`.github/workflows/ci.yml`, Ubuntu 24.04) runs on every push to `main` and every pull request: repo rules, gdformat and gdlint, a compile gate with warnings as errors, the GdUnit4 suite through an output-parsing runner, a canary that proves the runner catches failures, and a runner self-test. No secrets or signing are involved. This codex is built with MkDocs and published by `.github/workflows/pages.yml`. See [`docs/setup/ci.md`](https://github.com/paimonsoror/iron-static/blob/main/docs/setup/ci.md).

## Repo layout

```text
assets/        art/src (SVG sprites), art/title (title screen art), audio (sfx, music, slot tables), fonts, shaders
data/          CSV source of truth for numbers, enemies, upgrades, frames, wave modes, strings
docs/          design (GDD), ROADMAP, TECH_ARCHITECTURE, tasks, setup, playtests, readme images
site/          this codex (MkDocs)
src/
  sim/         deterministic simulation (pure RefCounted)
  core/        run controller, tick driver, CSV importer, save service, number formatting
  meta/        profile, Foundry, frames and wave-mode rules (pure)
  save/        save codec, store, scheduler, migrations (pure)
  data_defs/   typed resource definitions      data_gen/  generated .tres (do not edit)
  view/        battle rendering: enemies, beam, particles, camera, Cinder rig
  ui/          title, Home, Foundry, frame bay, settings, HUD, upgrade panel, results, theme, mobile shell
  audio/       buses, SFX pool, adaptive music
  services/    ads and billing behind interfaces (desktop stubs)
  net/         offline backend stub
  debug/       desktop capture harnesses (style frames, title shots, README banner, screenshots for the README and the codex)
tests/         GdUnit4 unit and sim tests, fixtures, perf baseline
tools/         PowerShell and Python tooling (test, lint, deploy, balance, art, audio)
addons/        GdUnit4, Billing, AdMob, Nakama client, Sentry
```
