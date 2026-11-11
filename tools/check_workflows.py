#!/usr/bin/env python3
"""Offline rules for the release pipeline files (docs/release/ci_release.md).

Checked in .github/workflows/release.yml and .github/actions/**/action.yml:
  1. every `uses:` is a local action (./...) or owner/repo@<40 hex commit SHA>;
  2. `secrets.` appears only inside a job that has `environment: release` (never at top level, never in an action);
  3. every actions/checkout step sets `persist-credentials: false`;
  4. top-level `permissions:` is `contents: read`; no pull_request_target trigger.

Usage: python -I tools/check_workflows.py [--self-test]      Exit 0 ok, 1 findings.
Text based on purpose (no YAML library needed); the files use a fixed layout: 2-space job keys under `jobs:`.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
USES = re.compile(r"^\s*(?:-\s+)?uses:\s*(\S+)")
SHA_REF = re.compile(r"^[\w.-]+/[\w./-]+@[0-9a-f]{40}$")
SECRET_REF = re.compile(r"(?<![\w-])secrets\s*[.\[]|toJSON\(\s*secrets|secrets:\s*inherit")
JOB_KEY = re.compile(r"^  ([\w-]+):\s*$")


def code_lines(text: str) -> list[tuple[int, str]]:
    """(line number, line without trailing comment) for non-comment lines."""
    out = []
    for n, raw in enumerate(text.splitlines(), 1):
        if raw.lstrip().startswith("#"):
            continue
        out.append((n, re.sub(r"\s+#\s.*$", "", raw)))
    return out


def check_text(name: str, text: str, is_action: bool = False) -> list[str]:
    errs: list[str] = []
    lines = code_lines(text)
    # 1. uses
    for n, ln in lines:
        m = USES.match(ln)
        if m:
            ref = m.group(1).strip("'\"")
            if not (ref.startswith("./") or SHA_REF.match(ref)):
                errs.append(f"{name}:{n}: 'uses: {ref}' is not pinned to a full commit SHA")
    # 4. triggers and permissions
    if not is_action:
        body = "\n".join(ln for _, ln in lines)
        if "pull_request_target" in body:
            errs.append(f"{name}: pull_request_target is not allowed")
        if not re.search(r"(?m)^permissions:\s*\n\s+contents:\s*read\s*$", body):
            errs.append(f"{name}: top-level 'permissions: contents: read' is missing")
    # 3. checkout
    for i, (n, ln) in enumerate(lines):
        m = USES.match(ln)
        if m and m.group(1).startswith("actions/checkout@"):
            window = [x for _, x in lines[i + 1 : i + 6]]
            nxt = []
            for x in window:
                if USES.match(x) or re.match(r"^\s*-\s", x):
                    break
                nxt.append(x)
            if not any(re.search(r"persist-credentials:\s*false", x) for x in nxt):
                errs.append(f"{name}:{n}: actions/checkout without persist-credentials: false")
    # 2. secrets
    if is_action:
        for n, ln in lines:
            if SECRET_REF.search(ln):
                errs.append(f"{name}:{n}: secrets referenced in a composite action")
        return errs
    in_jobs = False
    jobs: list[tuple[str, int, list[tuple[int, str]]]] = []
    for n, ln in lines:
        if re.match(r"^jobs:\s*$", ln):
            in_jobs = True
            continue
        if not in_jobs:
            if SECRET_REF.search(ln):
                errs.append(f"{name}:{n}: secrets referenced outside a job")
            continue
        m = JOB_KEY.match(ln)
        if m:
            jobs.append((m.group(1), n, []))
        elif jobs:
            jobs[-1][2].append((n, ln))
    for jname, jn, jl in jobs:
        has_env = any(re.match(r"^    environment:\s*['\"]?release['\"]?\s*$", ln) for _, ln in jl)
        if has_env:
            continue
        for n, ln in jl:
            if SECRET_REF.search(ln):
                errs.append(f"{name}:{n}: secrets referenced in job '{jname}', which has no 'environment: release'")
    return errs


def check_repo(root: Path) -> list[str]:
    errs: list[str] = []
    files = [root / ".github" / "workflows" / "release.yml"]
    actions = sorted((root / ".github" / "actions").glob("**/action.yml"))
    for f in files:
        if not f.is_file():
            errs.append(f"{f.relative_to(root)}: missing")
            continue
        errs += check_text(f.relative_to(root).as_posix(), f.read_text(encoding="utf-8"))
    for f in actions:
        errs += check_text(f.relative_to(root).as_posix(), f.read_text(encoding="utf-8"), is_action=True)
    return errs


GOOD = """name: x
on:
  workflow_dispatch:
permissions:
  contents: read
jobs:
  a:
    runs-on: x
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - run: echo hi
  b:
    environment: release
    runs-on: x
    steps:
      - run: echo
        env:
          K: ${{ secrets.K }}
"""


def self_test() -> int:
    ok = True

    def expect(label: str, errs: list[str], needle: str | None) -> None:
        nonlocal ok
        good = (not errs) if needle is None else any(needle in e for e in errs)
        print(("[PASS] " if good else "[FAIL] ") + label + ("" if good else f"  got {errs}"))
        ok = ok and good

    expect("good sample is clean", check_text("g", GOOD), None)
    expect("tag-pinned action", check_text("g", GOOD.replace("@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1", "@v7")), "not pinned")
    expect("short sha", check_text("g", GOOD.replace("3d3c42e5aac5ba805825da76410c181273ba90b1", "3d3c42e")), "not pinned")
    expect("secret in job without environment", check_text("g", GOOD.replace("      - run: echo hi", "      - run: echo ${{ secrets.X }}")), "no 'environment: release'")
    expect("secret via toJSON", check_text("g", GOOD.replace("      - run: echo hi", "      - run: echo ${{ toJSON(secrets) }}")), "no 'environment: release'")
    expect("secret at top level", check_text("g", GOOD.replace("name: x", "name: x\nenv:\n  A: ${{ secrets.A }}")), "outside a job")
    expect("wrong environment name", check_text("g", GOOD.replace("environment: release", "environment: staging")), "no 'environment: release'")
    expect("checkout keeps credentials", check_text("g", GOOD.replace("        with:\n          persist-credentials: false\n", "")), "persist-credentials")
    expect("missing permissions", check_text("g", GOOD.replace("permissions:\n  contents: read\n", "")), "permissions")
    expect("pull_request_target", check_text("g", GOOD.replace("workflow_dispatch:", "pull_request_target:")), "pull_request_target")
    expect("secret in composite action", check_text("a", "runs:\n  steps:\n    - run: x ${{ secrets.A }}\n", True), "composite action")
    expect("comment mentioning secrets. is ignored", check_text("g", GOOD.replace("      - run: echo hi", "      # uses secrets.X later\n      - run: echo hi")), None)
    print("SELF-TEST " + ("OK" if ok else "FAILED"))
    return 0 if ok else 1


def main() -> int:
    if "--self-test" in sys.argv:
        return self_test()
    errs = check_repo(ROOT)
    for e in errs:
        print("FAIL " + e)
    print("workflow rules: " + ("OK" if not errs else f"{len(errs)} finding(s)"))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
