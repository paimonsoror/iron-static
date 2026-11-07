# Lint

Changelog: 2026-11-07 v1.0 (M0-06).

Run `.\tools\lint.ps1` (from `C:\dev\tower`; `-SkipCompile` skips the Godot step). It creates `.venv` and installs `tools/requirements.txt` (pinned `gdtoolkit==4.5.0`, the newest 4.x release; it parses all project GDScript on Godot 4.7.2) when the requirements hash changes. Output is one `[PASS]`/`[FAIL]` line per step, then `LINT OK` or `LINT FAILED: <steps>`; exit 0 only if every step passed. Failing steps print their details right below.

| Step | Tool | Notes |
|---|---|---|
| gdformat | `gdformat --line-length 120 --check` | fix with `.venv\Scripts\gdformat.exe --line-length 120 <files>` |
| gdlint | `gdlint` with `.gdlintrc` (max line 120, tabs) | |
| repo rules | `tools/lint_repo.py` | rule ids below |
| compile | `tools/compile_check.gd` via Godot `-s` | `ERROR`, `SCRIPT ERROR`, `Parse Error`, `Warning treated as error` text fails the step (never the exit code) |

Files linted: every `.gd` under `src/`, `tests/`, `tools/` (list from `lint_repo.py --list-gd`). A directory containing a `.lintignore` file is skipped by everything (used by `tests/lint_fixtures/` and `tests/canary_parse/`; both also hold a `.gdignore` so Godot never loads their deliberately bad files).

## Deviation: compile gate does not use `--check-only`

`godot --check-only --script res://x.gd` does not register autoloads, so any script mentioning `Log` or `Game` fails with `Identifier not found: Log`. `tools/compile_check.gd` instead runs as a SceneTree script (`-s ... -- res://a.gd res://b.gd`), waits one frame so autoloads exist, and `load()`s each script; parse errors and warnings-as-errors then appear as `Parse Error` / `SCRIPT ERROR` text.

## `lint_repo.py` rules

Findings print as `FAIL|WARN <rule> <path>:<line>: <message>`.

- `encoding-bom`, `encoding-crlf`: text files (tracked or untracked-not-ignored) must be UTF-8 without BOM and LF.
- `layer-forbidden-api`, `layer-autoload`: in `src/sim`, `src/meta`, `src/save` no `Node`, `Input`, `OS.`, `randf`... and no autoload names (`Game`, `Log`, ...) as identifiers. Comments and string literals are ignored. Suppress one line with a trailing `# lint-allow: layer <reason>`.
- `file-size`: `.gd` over 300 lines warns, over 500 fails (not `addons/`, `src/data_gen/`).
- `class-name`: a `.gd` under `src/` has exactly one `class_name`, or is an autoload (`project.godot`) or a script referenced by a `.tscn`/`.tres`.
- `filename-case`: `.gd/.tscn/.tres` under `src`, `tests`, `tools` are snake_case.

`py -3.12 tools\lint_repo.py --self-test` checks that every bad file in `tests/lint_fixtures/` (header `# fixture: path=<logical path> expect=<rule>`) plus synthetic BOM, CRLF and 520-line cases is caught.
