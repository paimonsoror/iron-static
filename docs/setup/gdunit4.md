# GdUnit4 setup and test wrapper

Changelog: 2026-11-07 v1.0 (M0-04, M0-05).

## Version and source

- GdUnit4 **6.2.3** (tag `v6.2.3`, released 2026-11-01; its notes include a Godot 4.7 editor fix, GD-1348). Pinned in `tools/GDUNIT_VERSION`.
- Source: `https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/v6.2.3.zip` (repo formerly `MikeSchulze/gdUnit4`; the release has no binary assets, so the tag archive is used). Only `addons/gdUnit4/` is vendored into the repo. `plugin.cfg` reports `version="6.2.3"`.
- Plugin enabled in `project.godot` (`[editor_plugins]`). Verified to run on Godot 4.7.2 headless.
- Upgrade: replace `addons/gdUnit4/` from the new tag, update `tools/GDUNIT_VERSION`, run `.\tools\test.ps1` and `.\tools\test.ps1 -Canary`.

## Working CLI command

```
Godot_v4.7.2-stable_win64_console.exe --headless --path C:\dev\tower -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -c -rd res://build/test/report
```

- `--ignoreHeadlessMode` is required (without it GdUnit4 aborts with exit 103 "Headless mode is not supported").
- Do NOT add Godot's `-d` (debug) flag: on any script error the local debugger stops and waits on stdin, so the process hangs.
- Flags (from `-help`; note the help flag is `-help`, a plain `--help` is swallowed by Godot): `-a <dir|suite file>` add tests, `-i` ignore, `-c` continue after first failure, `-conf`, `-rd <dir>` report directory, `-rc <n>` report count, `--help-advanced`.
- Report: GdUnit4 creates `report_N/` inside the `-rd` directory. The JUnit file is `build/test/report/report_1/results.xml` (plus `index.html`). Root `<testsuites tests=.. failures=..>`, per `<testsuite tests failures errors skipped>`.
- GdUnit4 exit codes (0 pass, 100 failures, 103 headless refused, 105 script errors) are not trusted; `tools/test_runner.py` judges by parsed output and XML.

## Deviation: `return_value_discarded` is a warning

GdUnit4 assertions return the assert object, so every fluent call (`assert_int(1 + 1).is_equal(2)`) trips `return_value_discarded`, which was an error. `project.godot` now has `gdscript/warnings/return_value_discarded=1` (Warn). Everything else stays at error. Do not scatter `@warning_ignore` through tests.

## Test wrapper

`.\tools\test.ps1 [-Path res://tests/unit] [-Suite test_smoke] [-Canary]` calls `tools/test_runner.py` (stdlib Python, also for CI): import step, GdUnit4 run into a fresh `build/test/report`, parse output and XML. Full output: `build/test/last_output.txt` (import: `last_import.txt`); counts: `build/test/summary.json`. Last line: `TEST SUMMARY: tests=N failures=F errors=E skipped=S exit=X`.

Exit codes: 0 pass; 1 test failure/error; 2 `SCRIPT ERROR`/`Parse Error`/`ERROR:`/`Warning treated as error`/autoload failure in output (import or run); 3 zero tests; 4 tool failure (no Godot, no report). Benign output can be allowlisted as regex lines in `tools/test_allowlist.txt` (keep empty unless proven benign). `py -3.12 tools/test_runner.py --self-test` runs the parser checks. `-Suite` takes a suite file name (without `.gd`) inside `-Path`.

## Canaries and why they do not break normal runs

Godot scans the whole project, so a deliberately broken `.gd` in the live tree would break every import, export and editor session. Chosen design:

- `tests/canary/test_canary_fail.gd` is valid GDScript (an always-failing suite); it is only excluded from the normal run because `test.ps1` runs `res://tests/unit`.
- `tests/canary_parse/test_canary_parse.gd` has a syntax error and its folder contains a `.gdignore`, so Godot never loads it in the live project. `tests/lint_fixtures/` (deliberately bad files for the lint self-test) is `.gdignore`d too. Lint tools skip both folders explicitly.
- `.\tools\test.ps1 -Canary` copies `project.godot`, `addons`, `src`, `assets`, `data` and `tests/canary` (no `.godot/`) into `build/canary/`, runs the failing suite (must give exit 1), then materialises the parse canary there and runs it (must give exit 2 or 1), printing `CANARY OK`. The live project is never touched.
