#!/usr/bin/env python3
"""Compile gate (portable twin of the compile step in tools/lint.ps1). Stdlib only.

Imports the project, then loads every lintable .gd through tools/compile_check.gd in chunks of 60.
Judges by output text, never by exit code (headless Godot can exit 0 on failure).
Usage: compile_gate.py --godot <path> [--project .]
Exit 0 pass, 1 compile errors, 4 tool failure.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
BAD_IMPORT = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:")
BAD_COMPILE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:|Warning treated as error|Failed to instantiate|COMPILE FAIL")
CHUNK = 60
TOOLS = Path(__file__).resolve().parent


def godot(exe: str, project: Path, args: list[str], timeout: int = 300) -> str:
    cmd = [exe, "--headless", "--path", str(project)] + args
    try:
        proc = subprocess.run(
            cmd, cwd=str(project), capture_output=True, stdin=subprocess.DEVNULL, timeout=timeout, check=False
        )
    except subprocess.TimeoutExpired:
        return "TOOL ERROR: Godot timed out\n"
    return ANSI_RE.sub("", (proc.stdout + proc.stderr).decode("utf-8", "replace"))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--godot", required=True)
    ap.add_argument("--project", default=str(TOOLS.parent))
    a = ap.parse_args()
    project = Path(a.project).resolve()
    if not Path(a.godot).is_file():
        print("TOOL ERROR: Godot not found: " + a.godot)
        return 4

    listing = subprocess.run(
        [sys.executable, str(TOOLS / "lint_repo.py"), "--list-gd"], capture_output=True, text=True, check=False
    )
    files = [f.strip() for f in listing.stdout.splitlines() if f.strip()]
    if listing.returncode != 0 or not files:
        print("TOOL ERROR: lint_repo.py --list-gd gave no files")
        return 4

    bad: list[str] = []
    imp = godot(a.godot, project, ["--import"])
    bad += [ln for ln in imp.splitlines() if BAD_IMPORT.search(ln)]
    for i in range(0, len(files), CHUNK):
        chunk = ["res://" + f for f in files[i : i + CHUNK]]
        text = godot(a.godot, project, ["-s", "res://tools/compile_check.gd", "--"] + chunk)
        bad += [ln for ln in text.splitlines() if BAD_COMPILE.search(ln)]
        if f"COMPILE SUMMARY: checked={len(chunk)} " not in text:
            bad.append("compile_check did not finish (no summary)")
    if bad:
        print(f"[FAIL] compile (warnings-as-errors) ({len(files)} scripts)")
        for b in bad[:20]:
            print("    " + b)
        return 1
    print(f"[PASS] compile (warnings-as-errors) ({len(files)} scripts)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
