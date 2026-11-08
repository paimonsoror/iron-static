#!/usr/bin/env python3
"""Test runner for IRON STATIC: import, run GdUnit4 headless, parse output + JUnit XML.

Headless Godot can exit 0 on failure, so this script judges only by parsed output and report.
Exit codes: 0 pass, 1 test failure/error, 2 script/parse error in output, 3 zero tests,
4 tool failure (Godot missing, no report).
Stdlib only (also used by CI). See docs/setup/gdunit4.md.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
# Import errors that only mean another Godot process held a GDExtension library copy.
TRANSIENT_IMPORT_RE = re.compile(r"~lib\S*\.(dll|so)|\.(dll|so)\b|GDExtension|dynamic library", re.IGNORECASE)
ERROR_PATTERNS = [
    re.compile(p)
    for p in (
        r"SCRIPT ERROR",
        r"Parse Error",
        r"\bERROR:",
        r"Warning treated as error",
        r"Failed to instantiate an autoload",
        r"Nonexistent function",
    )
]
REPO_ROOT = Path(__file__).resolve().parent.parent
ALLOWLIST_FILE = Path(__file__).resolve().parent / "test_allowlist.txt"
CANARY_COPY_DIRS = ("addons", "src", "assets", "data")


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def load_allowlist(path: Path = ALLOWLIST_FILE) -> list[re.Pattern[str]]:
    if not path.is_file():
        return []
    out: list[re.Pattern[str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(re.compile(line))
    return out


def scan_errors(output: str, allowlist: list[re.Pattern[str]]) -> list[str]:
    """Return output lines matching an error pattern and not allowlisted."""
    hits: list[str] = []
    for line in strip_ansi(output).splitlines():
        if any(a.search(line) for a in allowlist):
            continue
        if any(p.search(line) for p in ERROR_PATTERNS):
            hits.append(line.strip())
    return hits


def parse_junit(xml_text: str) -> dict[str, int]:
    root = ET.fromstring(xml_text)
    totals = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}
    suites = root.findall(".//testsuite") or [root]
    for suite in suites:
        for key in totals:
            totals[key] += int(suite.get(key, "0") or 0)
    return totals


def evaluate(output: str, junit_xml: str | None, allowlist: list[re.Pattern[str]]) -> tuple[dict[str, int], int, list[str]]:
    """Pure decision function: (counts, exit code, error lines)."""
    counts = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}
    errors = scan_errors(output, allowlist)
    if errors:
        return counts, 2, errors
    if junit_xml is None:
        return counts, (3 if "No test cases found" in output else 4), errors
    try:
        counts = parse_junit(junit_xml)
    except ET.ParseError:
        return counts, 4, errors
    if counts["tests"] == 0:
        return counts, 3, errors
    if counts["failures"] or counts["errors"]:
        return counts, 1, errors
    return counts, 0, errors


def kill_tree(pid: int) -> None:
    if os.name == "nt":
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(pid)], capture_output=True, check=False)
    else:  # POSIX: the child runs in its own session/process group (see run_godot)
        try:
            os.killpg(pid, signal.SIGKILL)
        except OSError:
            pass


def run_godot(godot: str, project: Path, args: list[str], timeout: int) -> tuple[int, str]:
    cmd = [godot, "--headless", "--path", str(project)] + args
    proc = subprocess.Popen(
        cmd, cwd=str(project), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
        start_new_session=(os.name != "nt"),
    )
    try:
        raw, _ = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        kill_tree(proc.pid)
        proc.kill()
        raw, _ = proc.communicate()
        return 124, strip_ansi(raw.decode("utf-8", "replace")) + "\nTOOL ERROR: Godot timed out\n"
    return proc.returncode, strip_ansi(raw.decode("utf-8", "replace"))


def write_summary(build_dir: Path, counts: dict[str, int], code: int) -> str:
    line = "TEST SUMMARY: tests={tests} failures={failures} errors={errors} skipped={skipped} exit={x}".format(
        x=code, **counts
    )
    (build_dir / "summary.json").write_text(json.dumps({**counts, "exit": code}, indent=2) + "\n", encoding="utf-8")
    return line


def ensure_build_root(project: Path) -> None:
    """build/ holds nested projects (canary) and PNGs; .gdignore keeps Godot from scanning it."""
    root = project / "build"
    root.mkdir(parents=True, exist_ok=True)
    (root / ".gdignore").touch(exist_ok=True)


def prune_old_runs(runs_root: Path, keep: Path, max_age_s: float = 6 * 3600) -> None:
    """Delete per-run folders older than max_age_s (never the current one)."""
    now = time.time()
    for d in runs_root.iterdir():
        if d == keep or not d.is_dir():
            continue
        try:
            if now - d.stat().st_mtime > max_age_s:
                shutil.rmtree(d, ignore_errors=True)
        except OSError:
            pass


def run_pipeline(godot: str, project: Path, res_path: str, suite: str | None, timeout: int, quiet: bool = False) -> int:
    """Import, run GdUnit4, parse. Prints the summary line last. Returns the exit code."""
    ensure_build_root(project)
    # Each invocation gets its own folder so parallel agents never clobber each other's
    # report; the latest results are also copied to build/test/ (last writer wins).
    latest_dir = project / "build" / "test"
    runs_root = latest_dir / "runs"
    run_name = f"{os.getpid()}_{int(time.time() * 1000)}"
    build_dir = runs_root / run_name
    build_dir.mkdir(parents=True, exist_ok=True)
    prune_old_runs(runs_root, keep=build_dir)
    zero = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}
    allow = load_allowlist()

    def finish(counts: dict[str, int], code: int) -> int:
        print(write_summary(build_dir, counts, code))
        for name in ("summary.json", "last_import.txt", "last_output.txt"):
            src = build_dir / name
            if src.is_file():
                try:
                    shutil.copyfile(src, latest_dir / name)
                except OSError:
                    pass  # another run is copying at the same moment; its copy is as good
        return code

    if not Path(godot).is_file():
        print("TOOL ERROR: Godot not found: " + godot)
        return finish(zero, 4)

    rc, imp = run_godot(godot, project, ["--import"], timeout)
    errs = scan_errors(imp, allow)
    # Parallel runs can collide on the temp copy Godot makes of GDExtension DLLs (e.g.
    # "Failed to open ...~libsentry...dll"); that is transient, so retry the import.
    for attempt in range(2):
        if not errs or not all(TRANSIENT_IMPORT_RE.search(e) for e in errs):
            break
        print(f"Transient GDExtension copy error during import; retrying ({attempt + 1}/2)")
        time.sleep(15)
        rc, imp = run_godot(godot, project, ["--import"], timeout)
        errs = scan_errors(imp, allow)
    (build_dir / "last_import.txt").write_text(imp, encoding="utf-8")
    if errs:
        print("Import step reported errors:")
        for e in errs[:20]:
            print("  " + e)
        return finish(zero, 2)

    report_dir = build_dir / "report"
    if report_dir.exists():
        shutil.rmtree(report_dir, ignore_errors=True)
    report_dir.mkdir(parents=True)
    target = res_path.rstrip("/")
    if suite:
        target = suite if suite.startswith("res://") else f"{target}/{suite}.gd"
    args = [
        "-s",
        "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
        "--ignoreHeadlessMode",
        "-a",
        target,
        "-c",
        "-rd",
        f"res://build/test/runs/{run_name}/report",
    ]
    rc, out = run_godot(godot, project, args, timeout)
    (build_dir / "last_output.txt").write_text(out, encoding="utf-8")
    if not quiet:
        print(out)

    xmls = sorted(report_dir.rglob("results.xml"), key=lambda p: p.stat().st_mtime)
    xml_text = xmls[-1].read_text(encoding="utf-8") if xmls else None
    counts, code, errors = evaluate(out, xml_text, allow)
    if errors:
        print("Errors found in test output:")
        for e in errors[:20]:
            print("  " + e)
    return finish(counts, code)


def remove_tree(path: Path) -> None:
    def onerror(func, p, _exc):  # type: ignore[no-untyped-def]
        os.chmod(p, 0o700)
        func(p)

    if path.exists():
        shutil.rmtree(path, onerror=onerror)


def run_canary(godot: str, timeout: int) -> int:
    """Run the canary suites inside a temp copy of the project; broken file only exists there."""
    ensure_build_root(REPO_ROOT)
    copy = REPO_ROOT / "build" / "canary"
    remove_tree(copy)
    copy.mkdir(parents=True)
    shutil.copy2(REPO_ROOT / "project.godot", copy / "project.godot")
    for d in CANARY_COPY_DIRS:
        if (REPO_ROOT / d).is_dir():
            shutil.copytree(REPO_ROOT / d, copy / d)
    shutil.copytree(REPO_ROOT / "tests" / "canary", copy / "tests" / "canary")

    print("== canary 1: failing test must give exit 1")
    c1 = run_pipeline(godot, copy, "res://tests/canary", None, timeout, quiet=True)

    print("== canary 2: parse error must give exit 2")
    dst = copy / "tests" / "canary_parse"
    dst.mkdir(parents=True)
    shutil.copy2(REPO_ROOT / "tests" / "canary_parse" / "test_canary_parse.gd", dst / "test_canary_parse.gd")
    c2 = run_pipeline(godot, copy, "res://tests/canary_parse", None, timeout, quiet=True)

    if c1 == 1 and c2 in (1, 2):
        print("CANARY OK")
        return 0
    print(f"CANARY FAILED: canary1 exit={c1} (want 1), canary2 exit={c2} (want 2 or 1)")
    return 1


def self_test() -> int:
    allow = [re.compile(r"known benign thing")]
    ok_xml = '<testsuites><testsuite tests="2" failures="0" errors="0" skipped="0"/></testsuites>'
    fail_xml = '<testsuites><testsuite tests="2" failures="1" errors="0" skipped="0"/></testsuites>'
    zero_xml = '<testsuites><testsuite tests="0" failures="0" errors="0" skipped="0"/></testsuites>'
    cases = [
        ("pass", evaluate("all good\n0 errors", ok_xml, allow)[1], 0),
        ("failure", evaluate("FAILED", fail_xml, allow)[1], 1),
        ("parse error", evaluate("SCRIPT ERROR: Parse Error: x (Warning treated as error.)", ok_xml, allow)[1], 2),
        (
            "transient dll copy matches",
            int(bool(TRANSIENT_IMPORT_RE.search("ERROR: Failed to open 'res://addons/sentry/bin/~libsentry.dll'."))),
            1,
        ),
        ("parse error is not transient", int(bool(TRANSIENT_IMPORT_RE.search("Parse Error: Expected ')'"))), 0),
        ("zero tests xml", evaluate("fine", zero_xml, allow)[1], 3),
        ("zero tests no report", evaluate("No test cases found, abort test run!", None, allow)[1], 3),
        ("allowlisted error", evaluate("ERROR: known benign thing happened", ok_xml, allow)[1], 0),
        ("ansi stripped", evaluate("\x1b[31mERROR: boom\x1b[0m", ok_xml, [])[1], 2),
        ("no report", evaluate("something", None, allow)[1], 4),
        ("counts", evaluate("x", fail_xml, allow)[0]["tests"], 2),
    ]
    bad = 0
    for name, got, want in cases:
        status = "ok" if got == want else "FAIL"
        bad += got != want
        print(f"  [{status}] {name}: got {got}, want {want}")
    print("SELF-TEST " + ("OK" if bad == 0 else "FAILED"))
    return 0 if bad == 0 else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot", help="Godot console executable")
    ap.add_argument("--project", default=str(REPO_ROOT), help="project directory")
    ap.add_argument("--path", default="res://tests/unit", help="res:// directory of suites")
    ap.add_argument("--suite", help="suite file name (without .gd) inside --path, or a res:// path")
    ap.add_argument("--canary", action="store_true", help="prove the runner detects failures")
    ap.add_argument("--self-test", action="store_true", help="run parser unit checks")
    ap.add_argument("--timeout", type=int, default=300)
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    if not a.godot:
        ap.error("--godot is required")
    if a.canary:
        return run_canary(a.godot, a.timeout)
    return run_pipeline(a.godot, Path(a.project).resolve(), a.path, a.suite, a.timeout)


if __name__ == "__main__":
    sys.exit(main())
