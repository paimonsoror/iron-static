<p align="center">
  <a href="https://paimonsoror.github.io/iron-static/">
    <img src="docs/readme/banner.jpg" width="100%" alt="IRON STATIC: Cinder, a cybernetic combat unit with a glowing core, on a ridge of machine wrecks under a smoky amber sky">
  </a>
</p>

<p align="center"><b>Hold the last relay. Burn away what is left of being human. Go deeper every time.</b></p>

<p align="center">
  An original portrait idle-defense game for Android, built with Godot 4.7.2.
</p>

<p align="center">
  <a href="https://paimonsoror.github.io/iron-static/"><b>Codex</b></a> ·
  <a href="https://paimonsoror.github.io/iron-static/lore/">Lore</a> ·
  <a href="https://paimonsoror.github.io/iron-static/systems/">Game systems</a> ·
  <a href="https://paimonsoror.github.io/iron-static/status/">Status</a> ·
  <a href="https://paimonsoror.github.io/iron-static/dev/">Under the hood</a> ·
  <a href="docs/ROADMAP.md">Roadmap</a>
</p>

<p align="center">
  <a href="https://github.com/paimonsoror/iron-static/actions/workflows/ci.yml"><img src="https://github.com/paimonsoror/iron-static/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/paimonsoror/iron-static/actions/workflows/pages.yml"><img src="https://github.com/paimonsoror/iron-static/actions/workflows/pages.yml/badge.svg" alt="Codex build"></a>
  <img src="https://img.shields.io/badge/Godot-4.7.2-478cbf?logo=godotengine&logoColor=white" alt="Godot 4.7.2">
  <img src="https://img.shields.io/badge/platform-Android%20(portrait)-3ddc84?logo=android&logoColor=white" alt="Android, portrait">
  <img src="https://img.shields.io/badge/milestone-M4%20in%20progress-ffb000" alt="Milestone M4 in progress">
</p>

## Start here

| If you want to | Go here |
|---|---|
| See what the game looks like | [Screenshots](#what-it-is) below, or the [codex home](https://paimonsoror.github.io/iron-static/) |
| Learn how a deployment plays | [The run loop and waves](https://paimonsoror.github.io/iron-static/systems/run-loop/), [Run upgrades](https://paimonsoror.github.io/iron-static/systems/upgrades/), [Enemies](https://paimonsoror.github.io/iron-static/characters/enemies/) |
| Read the story | [Lore](https://paimonsoror.github.io/iron-static/lore/) and [Cinder](https://paimonsoror.github.io/iron-static/characters/cinder/) |
| Know what works today and what is next | [Development status](https://paimonsoror.github.io/iron-static/status/) and the [roadmap](docs/ROADMAP.md) |
| Build it and run it on a phone | [Quick start](#quick-start) below, then [Building and tools](https://paimonsoror.github.io/iron-static/dev/building/) |
| Understand the code | [Architecture](https://paimonsoror.github.io/iron-static/dev/architecture/) |
| Read the design documents | [`docs/design/`](docs/design/00_overview.md) (the source of truth for rules and numbers) |
| Work on it with a coding agent | [`CLAUDE.md`](CLAUDE.md) (conventions and gotchas) and [`docs/tasks/`](docs/tasks/) (agent-ready tasks) |

## What it is

You are **Cinder**, a reprogrammed cybernetic combat unit fixed at the center of a circular arena. Rogue machine swarms close in from every side while Cinder fires its laser on its own. You never aim: you choose what to buy. Scrap from kills buys temporary upgrades during a deployment; data recovered from the wreckage buys permanent upgrades in the Foundry, so the next deployment goes deeper. As Cinder's integrity drops, its synthetic skin burns away and exposes the armored frame beneath. The look is a dark machine-vision HUD: amber, teal and red glow on black.

| | | | |
|:-:|:-:|:-:|:-:|
| <img src="site/docs/assets/img/title_screen.jpg" width="200" alt="Title screen with CONTINUE, NEW GAME and SETTINGS"> | <img src="site/docs/assets/img/frame_bay.jpg" width="200" alt="Frame bay with a locked BULWARK card"> | <img src="site/docs/assets/img/home.jpg" width="200" alt="Home screen"> | <img src="site/docs/assets/img/foundry.jpg" width="200" alt="Foundry with four rows"> |
| Title screen | Frame bay | Home | Foundry |
| <img src="docs/readme/01_wave1.png" width="200" alt="Wave 1, Cinder centered, ARMS panel"> | <img src="docs/readme/02_crowd_boss.png" width="200" alt="Wave 20 crowd with the boss hulk"> | <img src="docs/readme/03_upgrades.png" width="200" alt="Upgrade panel with a formula tooltip"> | <img src="docs/readme/04_results.png" width="200" alt="Results screen"> |
| Wave 1 | Wave 20 and the boss hulk | Upgrades and a formula tooltip | Results |

<sub>Captures of the current build at 1080x2400, downscaled. Menu screens use test profiles; the wave 20 shot is a debug scenario (invulnerable, fast-forwarded).</sub>

**In the build today:** 24-second waves of four enemy types plus a boss hulk every ten waves; ten run upgrades with tap and hold-to-buy; the title screen, Home, the Foundry, three frames (VANGUARD, BULWARK, STRIKER) and Settings; crash-safe saving with resume after the app is killed; synthesized sound and adaptive music. Every system, with its numbers and status, is in the [codex](https://paimonsoror.github.io/iron-static/systems/).

## Status

Milestones M0 to M3 are done, along with the V1 visual pass and the A1 audio pass; M3 closed on 2026-11-09 after checks on a real phone. **M4 is in progress**, starting with two wave modes chosen before each deployment: **TIMED** (today's 24-second waves) and **PURGE** (a wave ends when every enemy in it is destroyed; unlocks at best TIMED wave 20, each mode keeps its own record). The patch draft, the Intel tab, damage numbers, haptics and a guided first ten minutes follow.

| Milestone | Goal | Status |
|---|---|---|
| M0 to M2 | Foundation, deterministic combat, in-run economy | Done |
| V1 / A1 | Visual pass / audio pass | Done |
| M3 | Meta loop: Foundry, saving and resume, title screen, frames | Done |
| M4 | Wave modes, patch draft, Intel, feel, first-time experience | In progress |
| M5 to M7 | MVP validation, launch content, online and release | Planned |

On a Pixel 11 Pro Fold the game holds 60 fps with 165 enemies on screen. Details: [development status](https://paimonsoror.github.io/iron-static/status/) and [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Quick start

Windows 11 with PowerShell, Godot 4.7.2 with export templates, JDK 17 and the Android SDK and NDK. Clone to a normal drive path such as `C:\dev\tower` (not `\\wsl$`). Exact versions and install notes: [Building and tools](https://paimonsoror.github.io/iron-static/dev/building/) and [`docs/setup/DEV_ENVIRONMENT.md`](docs/setup/DEV_ENVIRONMENT.md).

```powershell
.\tools\setup_android_template.ps1   # once: install the Gradle build template
.\tools\lint.ps1                     # format, lint, layer rules, warnings-as-errors compile
.\tools\test.ps1                     # the GdUnit4 suite
.\tools\run_emulator.ps1             # start the emulator, then deploy:
.\tools\deploy_android.ps1 -ProjectPath C:\dev\tower -Package com.normalexception.game -Preset IronStatic
```

You can also open `project.godot` in Godot 4.7.2 and run it on the desktop. Every other tool (balance runs, perf bench, art and audio pipelines, save inspection) is listed on the [Building and tools](https://paimonsoror.github.io/iron-static/dev/building/) page.

## Documentation

| What | Where |
|---|---|
| Player codex: lore, characters, every system | [paimonsoror.github.io/iron-static](https://paimonsoror.github.io/iron-static/) (source in [`site/`](site/)) |
| How it is built | [Under the hood](https://paimonsoror.github.io/iron-static/dev/) |
| Game rules, numbers, glossary (source of truth) | [`docs/design/`](docs/design/00_overview.md) |
| Technical decisions | [`docs/TECH_ARCHITECTURE.md`](docs/TECH_ARCHITECTURE.md) |
| Milestones and exit criteria | [`docs/ROADMAP.md`](docs/ROADMAP.md) |
| Open questions | [`docs/design/09_open_questions.md`](docs/design/09_open_questions.md) |
| Art, audio and font sources | [Credits and sources](https://paimonsoror.github.io/iron-static/dev/credits/) |

## License

No license has been chosen yet, so all rights are reserved by default. Third-party components keep their own licenses: Oxanium and Share Tech Mono (SIL OFL 1.1, `assets/fonts/`), GdUnit4 (MIT, `addons/gdUnit4/LICENSE`), and the other plugins under `addons/`.
