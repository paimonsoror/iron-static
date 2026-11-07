# CI (GitHub Actions)

Workflow: `.github/workflows/ci.yml`, one job `check` on `ubuntu-latest`. Triggers: push to `main` and every pull request. No export, signing or secrets (`permissions: contents: read`). Export and release workflows come later (TECH_ARCHITECTURE 10.5 items 2-3).

## What runs (in order, any failure fails the job)

| # | Step | Command | Local equivalent |
|---|---|---|---|
| 1 | Setup | `bash tools/ci_setup.sh` (downloads Godot 4.7.2-stable Linux x86_64, SHA512-verified; `pip install -r tools/requirements.txt`) | `docs/setup/DEV_ENVIRONMENT.md` (Godot is already installed) |
| 2 | Repo rules | `python tools/lint_repo.py` | `.\tools\lint.ps1` ("repo rules") |
| 3 | Format + lint | `gdformat --line-length 120 --check` and `gdlint` on `lint_repo.py --list-gd` | `.\tools\lint.ps1` |
| 4 | Compile gate | `python tools/compile_gate.py --godot $GODOT_BIN --project .` | `.\tools\lint.ps1` (same logic in PowerShell) or `.venv\Scripts\python.exe tools\compile_gate.py --godot C:\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe` |
| 5 | Tests | `python tools/test_runner.py --godot $GODOT_BIN --project .` | `.\tools\test.ps1` |
| 6 | Canary | `python tools/test_runner.py --godot $GODOT_BIN --canary` | `.\tools\test.ps1 -Canary` |
| 7 | Runner self-test | `python tools/test_runner.py --self-test` | `py -3.12 tools/test_runner.py --self-test` |

Gates judge by output text, not Godot's exit code (headless Godot can exit 0 on failure). `tools/test_runner.py` and `tools/compile_gate.py` are stdlib Python and run unchanged on Windows and Linux.

Pinned actions: `actions/checkout@v7`, `actions/setup-python@v7` (Python 3.12, pip cache keyed on `tools/requirements.txt`), `actions/cache@v6` (Godot binary, key `godot-linux-<hash of tools/GODOT_VERSION>`). **(impl)** major-version tags, not SHAs.

## Godot binary

- Asset: `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`
- SHA512: `9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65` (from the release's `SHA512-SUMS.txt`; verified by downloading it).
- Upgrading Godot: change `tools/GODOT_VERSION`, the URL version and `SHA512` in `tools/ci_setup.sh` together (the script refuses a mismatched version), and `$Godot` in `tools/_common.ps1`.
- The cache key depends only on `GODOT_VERSION`; the script re-downloads and re-verifies on a cache miss.

## Expected timing (target < 8 min)

Estimates, to be confirmed on the first real run: cold run about 3-5 min (Godot download about 150 MB 10-20 s, pip 15 s, import 30-60 s, compile gate 30 s, tests 30-60 s, canary 60-90 s because it imports a project copy twice); warm run 2-4 min. Job `timeout-minutes: 15` is a safety net, not the target. Record the real number here after the first run.

## Reproduce locally

From `C:\dev\tower` in PowerShell: `.\tools\lint.ps1`, `.\tools\test.ps1`, `.\tools\test.ps1 -Canary`, `py -3.12 tools/test_runner.py --self-test`. The Linux `ci_setup.sh` can be tried in Git Bash with `SKIP_PIP=1 bash tools/ci_setup.sh <scratch dir>` (downloads and verifies the ELF; it cannot run on Windows).

## One-time GitHub setup (pending: `gh` not installed or logged in yet)

Decision Q25: private repo under the user's personal account. Do not do these until the user confirms `gh` is ready.

1. `gh auth login`
2. `gh repo create <name> --private --source C:\dev\tower --remote origin`
3. `git push -u origin main` (the first push triggers CI; check with `gh run watch`)
4. Only with user approval, after one green run: branch protection on `main` requiring the `check` status check, for example `gh api -X PUT repos/<user>/<name>/branches/main/protection --input protection.json` with `required_status_checks.contexts = ["check"]`. Private repos on the free plan may not support branch protection; if so, skip it and rely on discipline.

First-run risks to watch: Linux-only differences (file case sensitivity, line endings are already LF via `.gitattributes`), GdUnit4 headless flags on Linux, and `.godot/` import time on a cold runner.
