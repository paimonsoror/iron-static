#!/usr/bin/env python3
"""Static lint for IRON STATIC art SVGs (stdlib only). Rules: docs/art/svg_support.md (allowlist),
docs/design/10_art_bible.md 4.4 (structure, budgets, palette), data: tools/art_rules.json, assets/art/slots.csv.

Checks per SVG: UTF-8 without BOM and LF; well-formed XML; canvas (width/height/viewBox) equals the sheet size in
the slot table; allowed elements and attributes only; top-level groups are `slot.*` cells whose translate is a
cell origin of the slot table; element budgets (sheet, cell, defs, clipPath, filter, path segments); ids unique
snake_case and every reference resolves; no external references; mask content solid, filter region given;
off-palette colors (warning); banned IP strings over ids, comments, titles and the file name.
Exit codes: 0 pass, 1 findings with errors, 2 tool error (bad arguments, unreadable rules).
Usage: art_lint.py [--rules F] [--slots F] [--self-test] [files...]   (default: assets/art/src/**/*.svg)
"""
from __future__ import annotations

import csv
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "assets" / "art" / "src"
Finding = tuple[str, str, str]  # (severity "error"|"warn", rule, message)
STYLE_PROPS = {"fill", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "stroke-dasharray",
               "fill-rule", "opacity", "fill-opacity", "stroke-opacity"}
COLOR_ATTRS = ("fill", "stroke", "stop-color")
NUM = re.compile(r"-?\d*\.\d+|-?\d+")
CMD = re.compile(r"[MmLlHhVvCcSsQqTtAaZz]")
URL_REF = re.compile(r"url\(\s*#([^)\s]+)\s*\)")
HEX = re.compile(r"#([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")


def local(tag: object) -> str:
    return tag.rsplit("}", 1)[-1] if isinstance(tag, str) else ""


def attr_name(name: str) -> str:
    if name.startswith("{http://www.w3.org/1999/xlink}"):
        return "xlink:" + name.split("}", 1)[1]
    if name.startswith("{http://www.w3.org/XML/1998/namespace}"):
        return "xml:" + name.split("}", 1)[1]
    return name.rsplit("}", 1)[-1]


def load_table(path: Path) -> list[dict[str, str]]:
    lines = [ln for ln in path.read_text(encoding="utf-8").splitlines() if ln.strip() and not ln.lstrip().startswith("#")]
    return list(csv.DictReader(lines))


def sheet_info(table: list[dict[str, str]], rel: str) -> dict | None:
    """Sheet size and the set of valid cell origins for a file (relative to assets/art/src, posix)."""
    rows = [r for r in table if r["file"] == rel]
    if not rows:
        return None
    origins: set[tuple[int, int]] = set()
    for r in rows:
        frames = int(r["frames"] or 1)
        for f in range(frames):
            origins.add((int(r["cell_x"]) + f * int(r["cell_w"]), int(r["cell_y"])))
    return {"size": (int(rows[0]["sheet_w"]), int(rows[0]["sheet_h"])), "origins": origins, "family": rows[0]["family"]}


def parse_translate(transform: str) -> tuple[float, float] | None:
    m = re.fullmatch(r"\s*translate\(\s*(-?[\d.]+)[\s,]+(-?[\d.]+)\s*\)\s*", transform)
    return (float(m.group(1)), float(m.group(2))) if m else None


def style_props(style: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in style.split(";"):
        if ":" in part:
            k, v = part.split(":", 1)
            out[k.strip()] = v.strip()
    return out


def norm_hex(h: str) -> str:
    h = h.upper()
    if len(h) == 4:
        h = "#" + "".join(c * 2 for c in h[1:])
    return h[:7]


def banned_hits(text: str, rules: dict) -> list[str]:
    low = text.lower()
    return [p for p in rules["banned_strings"] if re.search(p, low)]


def lint_svg(rel: str, data: bytes, rules: dict, info: dict | None, display: str | None = None) -> list[Finding]:
    """Lint one SVG (bytes). `rel` is the path relative to assets/art/src, used for the table lookup."""
    out: list[Finding] = []
    E = lambda rule, msg: out.append(("error", rule, msg))  # noqa: E731
    W = lambda rule, msg: out.append(("warn", rule, msg))  # noqa: E731
    lim = rules["limits"]
    if data.startswith(b"\xef\xbb\xbf"):
        E("encoding", "UTF-8 BOM present")
    if b"\r\n" in data:
        E("encoding", "CRLF line endings")
    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError:
        E("encoding", "not valid UTF-8")
        return out
    for pat in banned_hits(display or rel, rules):
        E("banned-string", f"file name matches banned pattern {pat!r}")
    try:
        parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
        root = ET.fromstring(text, parser=parser)
    except ET.ParseError as ex:
        E("xml", f"not well-formed XML: {ex}")
        return out
    if local(root.tag) != "svg":
        E("xml", f"root element is <{local(root.tag)}>, expected <svg>")
        return out
    if info is None:
        E("not-in-table", f"{rel} is not referenced by any row of assets/art/slots.csv")
    else:
        w, h = info["size"]
        vb = root.get("viewBox", "")
        try:
            got = (float(root.get("width", "x").replace("px", "")), float(root.get("height", "x").replace("px", "")))
            vbv = tuple(float(v) for v in vb.replace(",", " ").split())
        except ValueError:
            got, vbv = (0.0, 0.0), ()
        if got != (float(w), float(h)):
            E("canvas-size", f"width/height {got[0]:g}x{got[1]:g} != slot table sheet {w}x{h}")
        if vbv != (0.0, 0.0, float(w), float(h)):
            E("canvas-size", f"viewBox '{vb}' != '0 0 {w} {h}'")
    allowed_el = set(rules["elements"])
    allowed_at = set(rules["attributes"])
    forbidden = set(rules["forbidden_elements"])
    draw = set(rules["drawing_elements"])
    ids: dict[str, int] = {}
    refs: list[str] = []
    colors: dict[str, int] = {}
    decimals = 0
    counts = {"draw": 0, "clip": 0, "filter": 0, "defs": 0}
    seen_el: set[str] = set()
    seen_at: set[str] = set()
    cell_counts: dict[str, int] = {}

    def check_text_banned(label: str, value: str) -> None:
        for pat in banned_hits(value, rules):
            E("banned-string", f"{label} matches banned pattern {pat!r}: {value[:60]!r}")

    def visit(el: ET.Element, cell: str | None, in_defs: bool, in_mask: bool, depth: int) -> None:
        nonlocal decimals
        if not isinstance(el.tag, str):  # comment
            check_text_banned("comment", el.text or "")
            return
        name = local(el.tag)
        if name in forbidden:
            if name not in seen_el:
                E("forbidden-element", f"<{name}> is forbidden (docs/art/svg_support.md)")
            seen_el.add(name)
        elif name not in allowed_el:
            if name not in seen_el:
                E("unknown-element", f"<{name}> is not on the allowlist")
            seen_el.add(name)
        if name == "title":
            check_text_banned("title", el.text or "")
        if name in draw:
            counts["draw"] += 1
            if cell:
                cell_counts[cell] = cell_counts.get(cell, 0) + 1
        if name == "clipPath":
            counts["clip"] += 1
        if name == "filter":
            counts["filter"] += 1
            if not all(el.get(k) for k in ("x", "y", "width", "height")):
                E("filter-region", "<filter> needs an explicit x/y/width/height region")
        if name == "mask":
            if el.get("maskUnits") != "userSpaceOnUse":
                E("mask-units", '<mask> needs maskUnits="userSpaceOnUse"')
        if name == "style":
            W("style-block", "<style> block is discouraged: prefer attributes")
        for raw, val in el.attrib.items():
            an = attr_name(raw)
            if an not in allowed_at:
                if an not in seen_at:
                    E("unknown-attribute", f"attribute '{an}' on <{name}> is not on the allowlist")
                seen_at.add(an)
            if re.search(r"(https?|file|data):", val, re.I) and not an.startswith("xmlns"):
                E("external-ref", f"external reference in {an}: {val[:50]!r}")
            if an == "id":
                if not re.fullmatch(rules["id_pattern"], val):
                    E("id-name", f"id '{val}' is not lowercase snake_case (dots allowed for slot./layer. prefixes)")
                check_text_banned("id", val)
                ids[val] = ids.get(val, 0) + 1
            if an in ("href", "xlink:href"):
                if not val.startswith("#"):
                    E("external-ref", f"{an}='{val[:50]}' is not an internal reference")
                else:
                    refs.append(val[1:])
            refs.extend(URL_REF.findall(val))
            if an == "transform":
                for fn in re.findall(r"([A-Za-z]+)\s*\(", val):
                    if fn not in rules["transform_funcs"]:
                        E("transform", f"transform function '{fn}' not allowed")
            if an == "style":
                for k, v in style_props(val).items():
                    if k not in STYLE_PROPS:
                        E("style-property", f"style property '{k}' not allowed")
                    if k in COLOR_ATTRS:
                        note_color(v)
            if an in COLOR_ATTRS:
                note_color(val)
            if an in ("d", "points"):
                for n in NUM.findall(val):
                    if "." in n and len(n.split(".")[1]) > lim["max_decimals"]:
                        decimals += 1
            if an == "d":
                worst = max((len(CMD.findall(sub)) for sub in re.split(r"(?=[Mm])", val)), default=0)
                if worst > lim["max_path_segments"]:
                    E("path-segments", f"sub-path with {worst} segments (max {lim['max_path_segments']} per contour)")
            if in_mask and an in COLOR_ATTRS and "url(" in val:
                E("mask-gradient", "mask content must be solid fills (a gradient inside a mask renders nothing)")
        for ch in el:
            visit(ch, cell, in_defs or name == "defs", in_mask or name == "mask", depth + 1)

    def note_color(val: str) -> None:
        for m in HEX.finditer(val):
            h = norm_hex("#" + m.group(1))
            if h not in palette:
                colors[h] = colors.get(h, 0) + 1

    palette = set(rules["palette"])
    top_ok = {"title", "defs", "style"}
    for ch in root:
        if not isinstance(ch.tag, str):
            check_text_banned("comment", ch.text or "")
            continue
        nm = local(ch.tag)
        if nm == "defs":
            counts["defs"] += sum(1 for d in ch if isinstance(d.tag, str))
            visit(ch, None, True, False, 1)
        elif nm in top_ok:
            visit(ch, None, False, False, 1)
        elif nm == "g" and (ch.get("id") or "").startswith(rules["cell_group_prefix"]):
            cell = ch.get("id", "")
            tr = ch.get("transform")
            origin: tuple[float, float] | None = (0.0, 0.0)
            if tr is not None:
                origin = parse_translate(tr)
                if origin is None:
                    E("cell-transform", f"cell group {cell}: transform must be a single translate(x,y), got '{tr}'")
            if origin is not None and info is not None and origin not in info["origins"]:
                E("cell-origin", f"cell group {cell} at {origin[0]:g},{origin[1]:g} is not a cell origin in slots.csv")
            visit(ch, cell, False, False, 1)
        else:
            E("top-level", f"top-level <{nm}{' id=' + ch.get('id', '') if ch.get('id') else ''}> must be defs/title or a group named 'slot.*'")
            visit(ch, None, False, False, 1)
    for k, c in ids.items():
        if c > 1:
            E("id-duplicate", f"id '{k}' used {c} times")
    for r in sorted(set(refs)):
        if r not in ids:
            E("dangling-ref", f"reference to missing id '{r}'")
    if counts["draw"] > lim["max_elements_per_sheet"]:
        E("budget-sheet", f"{counts['draw']} drawing elements (max {lim['max_elements_per_sheet']} per sheet)")
    for cell, n in cell_counts.items():
        if n > lim["max_elements_per_cell"]:
            E("budget-cell", f"{cell}: {n} drawing elements (max {lim['max_elements_per_cell']} per cell)")
    if counts["defs"] > lim["max_defs"]:
        E("budget-defs", f"{counts['defs']} <defs> entries (max {lim['max_defs']})")
    if counts["clip"] > lim["max_clip_paths"]:
        E("budget-clip", f"{counts['clip']} clipPath (max {lim['max_clip_paths']})")
    if counts["filter"] > lim["max_filters"]:
        E("budget-filter", f"{counts['filter']} filters (max {lim['max_filters']})")
    if colors:
        top = ", ".join(f"{h}x{n}" for h, n in sorted(colors.items(), key=lambda kv: -kv[1])[:8])
        W("palette", f"{len(colors)} off-palette colors ({sum(colors.values())} uses): {top}")
    if decimals:
        W("decimals", f"{decimals} coordinates with more than {lim['max_decimals']} decimal")
    return out


def lint_file(path: Path, rules: dict, table: list[dict[str, str]]) -> list[Finding]:
    try:
        rel = path.resolve().relative_to(SRC_DIR.resolve()).as_posix()
    except ValueError:
        rel = path.name
    return lint_svg(rel, path.read_bytes(), rules, sheet_info(table, rel))


def report(name: str, findings: list[Finding]) -> tuple[int, int]:
    errs = sum(1 for f in findings if f[0] == "error")
    warns = len(findings) - errs
    print(f"{'FAIL' if errs else 'PASS'} {name} ({errs} errors, {warns} warnings)")
    for sev, rule, msg in findings:
        print(f"  {sev.upper():5} {rule}: {msg}")
    return errs, warns


def self_test(rules: dict, table: list[dict[str, str]]) -> int:
    """Fixtures in tests/lint_fixtures/art/*.svg declare `<!-- art-lint-fixture: file=<slot file> expect=<rule|clean> -->`."""
    fx_dir = ROOT / "tests" / "lint_fixtures" / "art"
    bad = 0
    n = 0

    def check(name: str, found: list[Finding], expect: str) -> None:
        nonlocal bad, n
        n += 1
        rules_hit = {f[1] for f in found if f[0] == "error"}
        ok = (not rules_hit) if expect == "clean" else (expect in rules_hit)
        print(f"  [{'ok' if ok else 'FAIL'}] {name}: expected {expect}, got {sorted(rules_hit) or 'clean'}")
        bad += not ok

    for fx in sorted(fx_dir.glob("*.svg")):
        data = fx.read_bytes()
        m = re.search(rb"art-lint-fixture: file=(\S+) expect=(\S+)", data)
        if not m:
            print(f"  [FAIL] {fx.name}: missing fixture header")
            bad += 1
            n += 1
            continue
        rel = m.group(1).decode()
        check(fx.name, lint_svg(rel, data, rules, sheet_info(table, rel), display=fx.name), m.group(2).decode())
    tiny = b'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><g id="slot.cur_data"/></svg>'
    info = sheet_info(table, "icons/cur_data.svg")
    check("synthetic clean", lint_svg("icons/cur_data.svg", tiny, rules, info), "clean")
    check("synthetic bom", lint_svg("icons/cur_data.svg", b"\xef\xbb\xbf" + tiny, rules, info), "encoding")
    check("synthetic crlf", lint_svg("icons/cur_data.svg", tiny.replace(b"><", b">\r\n<"), rules, info), "encoding")
    check("synthetic malformed", lint_svg("icons/cur_data.svg", tiny[:-8], rules, info), "xml")
    check("synthetic not in table", lint_svg("nope.svg", tiny, rules, None), "not-in-table")
    print(f"art_lint self-test: {n - bad}/{n} ok")
    return 1 if bad else 0


def main(argv: list[str]) -> int:
    rules_path = ROOT / "tools" / "art_rules.json"
    slots_path = ROOT / "assets" / "art" / "slots.csv"
    files: list[str] = []
    do_self = False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--rules" and i + 1 < len(argv):
            rules_path = Path(argv[i + 1])
            i += 2
        elif a == "--slots" and i + 1 < len(argv):
            slots_path = Path(argv[i + 1])
            i += 2
        elif a == "--self-test":
            do_self = True
            i += 1
        elif a.startswith("-"):
            print(f"art_lint: unknown option {a}")
            return 2
        else:
            files.append(a)
            i += 1
    try:
        rules = json.loads(rules_path.read_text(encoding="utf-8"))
        table = load_table(slots_path)
    except (OSError, ValueError, KeyError) as ex:
        print(f"art_lint: cannot read rules or slot table: {ex}")
        return 2
    if do_self:
        return self_test(rules, table)
    paths = [Path(f) for f in files] if files else sorted(SRC_DIR.rglob("*.svg"))
    if not paths:
        print("art_lint: no SVG files")
        return 2
    total_e = total_w = 0
    for p in paths:
        if not p.is_file():
            print(f"art_lint: not found: {p}")
            return 2
        e, w = report(p.resolve().relative_to(ROOT).as_posix() if ROOT in p.resolve().parents else str(p), lint_file(p, rules, table))
        total_e += e
        total_w += w
    print(f"ART LINT: files={len(paths)} errors={total_e} warnings={total_w}")
    return 1 if total_e else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
