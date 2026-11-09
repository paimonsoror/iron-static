# Under the hood

This section is for people who want to know how IRON STATIC is built, or who want to build it themselves. The rest of the codex describes the game; these pages describe the code and the tools.

| Page | What it covers |
|---|---|
| [Architecture](architecture.md) | The deterministic simulation, numbers, saving, the data pipeline, rendering, audio and mobile handling |
| [Building and tools](building.md) | Prerequisites, first steps, every tool command, continuous integration, the repo layout |
| [Credits and sources](credits.md) | Where the art, audio and fonts come from, and the licenses of bundled components |

## The short version

- **Engine:** Godot 4.7.2, typed GDScript with warnings treated as errors, the Compatibility (GLES3) renderer for broad Android support.
- **Platform:** Android, portrait, one-handed. Tested on a Pixel 11 Pro Fold and an Android 35 emulator.
- **Simulation:** a fixed 30 Hz deterministic simulation in pure code. The same seed and inputs give the same result at any game speed, and golden hashes in the test suite catch any unintended change.
- **Data:** every number lives in CSV tables under `data/`, imported into typed resources. Nothing is tuned in code.
- **Tests:** a GdUnit4 suite of more than a thousand tests runs on every push in GitHub Actions, together with formatting, lint, layer rules and a warnings-as-errors compile gate.

## Documents in the repository

The source of truth for rules and decisions lives in the repository, not in this codex.

| What | Where |
|---|---|
| Game rules, numbers, glossary | [`docs/design/`](https://github.com/paimonsoror/iron-static/tree/main/docs/design) (the game design document, sections 00 to 11) |
| Technical decisions | [`docs/TECH_ARCHITECTURE.md`](https://github.com/paimonsoror/iron-static/blob/main/docs/TECH_ARCHITECTURE.md) |
| Milestones and exit criteria | [`docs/ROADMAP.md`](https://github.com/paimonsoror/iron-static/blob/main/docs/ROADMAP.md) |
| Agent-ready task files | [`docs/tasks/`](https://github.com/paimonsoror/iron-static/tree/main/docs/tasks) |
| Toolchain and troubleshooting | [`docs/setup/DEV_ENVIRONMENT.md`](https://github.com/paimonsoror/iron-static/blob/main/docs/setup/DEV_ENVIRONMENT.md) |
| Art direction | [`docs/design/10_art_bible.md`](https://github.com/paimonsoror/iron-static/blob/main/docs/design/10_art_bible.md) |
| Open questions | [`docs/design/09_open_questions.md`](https://github.com/paimonsoror/iron-static/blob/main/docs/design/09_open_questions.md) |
| Conventions, rules and gotchas for contributors and agents | [`CLAUDE.md`](https://github.com/paimonsoror/iron-static/blob/main/CLAUDE.md) |
