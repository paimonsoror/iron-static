# Versioning

Single source: `release/version.json` (`major`, `minor`, `patch`, `stage` = `beta` or empty, `build` 1-99).

- versionName: `MAJOR.MINOR.PATCH`, plus `-beta.BUILD` while stage is `beta` (now `0.5.0-beta.1`).
- versionCode: `MAJOR*1000000 + MINOR*10000 + PATCH*100 + BUILD` (now 50001). Play needs every upload higher than the last and at most 2,100,000,000.
- `tools\release_version.ps1 -Show | -Bump build|patch|minor|major | -Apply | -Check`. `-Apply` writes the name and code into every preset of `export_presets.cfg`, `config/version` in `project.godot` and the `VERSION` const in `src/core/game.gd` (all generated: never hand-edit them). It refuses a code lower than the one in the presets or in git HEAD. `-Check` exits 1 if they drift.
- `tools\release_build.ps1` runs `-Apply` before every export. `tests/unit/core/test_version.gd` fails if the files disagree.
- To launch: set `stage` to `""` in `version.json`, bump `minor`/`patch` so the code rises, run `-Apply`.
