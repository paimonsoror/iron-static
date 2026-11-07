#!/usr/bin/env python3
"""Repo lint rules for IRON STATIC (stdlib only). See docs/setup/lint.md.

Rules (ids are printed on every finding):
  encoding-bom / encoding-crlf   text files must be UTF-8 without BOM and LF
  layer-forbidden-api            src/sim, src/meta, src/save: no Node/Input/OS/randf... APIs
  layer-autoload                 same dirs: no autoload names as identifiers
  file-size                      .gd over 300 lines warns, over 500 fails
  class-name                     .gd under src/: one class_name, or an autoload/scene script
  filename-case                  snake_case file names
A line ending in `# lint-allow: <rule> <reason>` suppresses layer findings on that line.
Directories containing a `.lintignore` file are skipped (lint fixtures, the parse canary).
Usage: lint_repo.py [--self-test] [--list-gd]
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEXT_EXT = {
    ".gd", ".tscn", ".tres", ".cfg", ".godot", ".md", ".csv", ".json", ".ps1", ".py", ".txt", ".yml",
    ".yaml", ".svg", ".uid", ".gdignore", ".lintignore", ".gitignore", ".gitattributes", ".editorconfig",
    ".gdlintrc", ".gradle", ".properties", ".kts", ".xml", ".import",
}
LAYER_DIRS = ("src/sim/", "src/meta/", "src/save/")
FORBIDDEN_API = re.compile(
    r"\b(Node|Node2D|Node3D|Control|CanvasItem|SceneTree|get_tree|get_node|Input|DisplayServer|OS\.|"
    r"randf|randi|randomize|RenderingServer|Engine\.get_main_loop)\b"
)
AUTOLOADS = re.compile(r"\b(Game|Profile|SaveManager|Content|Services|Clock|Events|Log)\b")
ALLOW = re.compile(r"#\s*lint-allow:\s*(\S+)\s+(\S.*)$")
SNAKE = re.compile(r"^[a-z][a-z0-9_]*$")
CLASS_NAME = re.compile(r"^class_name\s+\w+", re.M)
SIZE_EXCLUDE = ("addons/", "src/data_gen/")

Finding = tuple[str, str, int, str, bool]  # (rule, path, line, message, is_failure)


def code_part(line: str) -> str:
    """Return the line without string literals and trailing comment."""
    out: list[str] = []
    quote = ""
    for ch in line:
        if quote:
            if ch == quote:
                quote = ""
            continue
        if ch in "\"'":
            quote = ch
        elif ch == "#":
            break
        else:
            out.append(ch)
    return "".join(out)


def check_bytes(path: str, data: bytes) -> list[Finding]:
    found: list[Finding] = []
    if data.startswith(b"\xef\xbb\xbf"):
        found.append(("encoding-bom", path, 1, "UTF-8 BOM present", True))
    if b"\r\n" in data:
        found.append(("encoding-crlf", path, 1, "CRLF line endings", True))
    return found


def check_layer(path: str, text: str) -> list[Finding]:
    if not path.startswith(LAYER_DIRS) or not path.endswith(".gd"):
        return []
    found: list[Finding] = []
    for n, line in enumerate(text.splitlines(), 1):
        if ALLOW.search(line):
            continue
        code = code_part(line)
        m = FORBIDDEN_API.search(code)
        if m:
            found.append(("layer-forbidden-api", path, n, f"`{m.group(1)}` not allowed in sim/meta/save", True))
        m = AUTOLOADS.search(code)
        if m:
            found.append(("layer-autoload", path, n, f"autoload `{m.group(1)}` referenced in sim/meta/save", True))
    return found


def check_size(path: str, text: str) -> list[Finding]:
    if not path.endswith(".gd") or path.startswith(SIZE_EXCLUDE):
        return []
    n = len(text.splitlines())
    if n > 500:
        return [("file-size", path, 1, f"{n} lines (hard cap 500)", True)]
    if n > 300:
        return [("file-size", path, 1, f"{n} lines (soft cap 300)", False)]
    return []


def check_class(path: str, text: str, referenced: set[str]) -> list[Finding]:
    if not path.startswith("src/") or not path.endswith(".gd"):
        return []
    count = len(CLASS_NAME.findall(text))
    if count > 1:
        return [("class-name", path, 1, f"{count} class_name declarations (one class per file)", True)]
    if count == 0 and "res://" + path not in referenced:
        return [("class-name", path, 1, "no class_name and not an autoload/scene script", True)]
    return []


def check_name(path: str) -> list[Finding]:
    p = Path(path)
    if p.suffix in (".gd", ".tscn", ".tres") and path.startswith(("src/", "tests/", "tools/")):
        if not SNAKE.match(p.stem):
            return [("filename-case", path, 1, f"`{p.name}` is not snake_case", True)]
    return []


def check_file(path: str, data: bytes, referenced: set[str]) -> list[Finding]:
    text = data.decode("utf-8-sig", "replace").replace("\r\n", "\n")
    return (
        check_bytes(path, data)
        + check_layer(path, text)
        + check_size(path, text)
        + check_class(path, text, referenced)
        + check_name(path)
    )


def candidate_files() -> list[str]:
    """Tracked + untracked-but-not-ignored files (git), else a directory walk."""
    try:
        raw = subprocess.run(
            ["git", "-C", str(ROOT), "ls-files", "-z", "-c", "-o", "--exclude-standard"],
            capture_output=True, check=True,
        ).stdout.decode("utf-8")
        files = [f for f in raw.split("\0") if f]
    except (OSError, subprocess.CalledProcessError):
        skip = (".godot", ".venv", "build", ".git")
        files = [
            p.relative_to(ROOT).as_posix() for p in ROOT.rglob("*")
            if p.is_file() and not any(part in skip for part in p.relative_to(ROOT).parts)
        ]
    skipped: set[str] = set()
    for f in files:
        if f.endswith(".lintignore"):
            skipped.add(str(Path(f).parent.as_posix()))
    out = []
    for f in files:
        if not (ROOT / f).is_file():
            continue
        parent = Path(f).parent
        if any(str(a.as_posix()) in skipped for a in [parent, *parent.parents]):
            continue
        out.append(f)
    return out


def referenced_scripts(files: list[str]) -> set[str]:
    """res:// scripts that are autoloads or attached in scenes/resources."""
    refs: set[str] = set()
    proj = ROOT / "project.godot"
    if proj.is_file():
        for m in re.finditer(r'^\w+="\*?(res://[^"]+\.gd)"', proj.read_text(encoding="utf-8"), re.M):
            refs.add(m.group(1))
    for f in files:
        if f.endswith((".tscn", ".tres")):
            for m in re.finditer(r'path="(res://[^"]+\.gd)"', (ROOT / f).read_text(encoding="utf-8", errors="replace")):
                refs.add(m.group(1))
    return refs


def run_lint() -> int:
    files = candidate_files()
    refs = referenced_scripts(files)
    findings: list[Finding] = []
    for f in files:
        if Path(f).suffix.lower() not in TEXT_EXT and Path(f).name not in TEXT_EXT:
            continue
        findings += check_file(f, (ROOT / f).read_bytes(), refs)
    fails = 0
    for rule, path, line, msg, is_fail in findings:
        print(f"{'FAIL' if is_fail else 'WARN'} {rule} {path}:{line}: {msg}")
        fails += is_fail
    print(f"lint_repo: {len(files)} files, {fails} failure(s), {len(findings) - fails} warning(s)")
    return 1 if fails else 0


def self_test() -> int:
    """Each bad fixture in tests/lint_fixtures/ declares `# fixture: path=<logical> expect=<rule>`."""
    fx_dir = ROOT / "tests" / "lint_fixtures"
    bad = 0
    n = 0

    def expect(name: str, got: list[Finding], rule: str | None) -> None:
        nonlocal bad, n
        n += 1
        rules = {g[0] for g in got if g[4]}
        ok = (rule in rules) if rule else not rules
        print(f"  [{'ok' if ok else 'FAIL'}] {name}: expected {rule or 'clean'}, got {sorted(rules) or 'clean'}")
        bad += not ok

    for fx in sorted(fx_dir.glob("*.gd")):
        text = fx.read_text(encoding="utf-8")
        m = re.search(r"# fixture: path=(\S+) expect=(\S+)", text)
        if not m:
            print(f"  [FAIL] {fx.name}: missing fixture header")
            bad += 1
            continue
        expect(fx.name, check_file(m.group(1), text.encode("utf-8"), set()), None if m.group(2) == "clean" else m.group(2))
    expect("synthetic bom", check_file("src/x.gd", b"\xef\xbb\xbfclass_name X\n", set()), "encoding-bom")
    expect("synthetic crlf", check_file("src/x.gd", b"class_name X\r\n", set()), "encoding-crlf")
    big = ("class_name Big\n" + "var a: int = 0\n" * 520).encode()
    expect("synthetic 520 lines", check_file("src/big.gd", big, set()), "file-size")
    print(f"lint_repo self-test: {n - bad}/{n} ok")
    return 1 if bad else 0


def list_gd() -> int:
    for f in candidate_files():
        if f.endswith(".gd") and f.startswith(("src/", "tests/", "tools/")):
            print(f)
    return 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    if "--list-gd" in sys.argv:
        sys.exit(list_gd())
    sys.exit(run_lint())
