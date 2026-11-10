#!/usr/bin/env python3
"""Generate tools/art_rules.json from docs/art/svg_support.md (allowlist) and the art bible (palette, budgets).

The allowlist paragraphs of svg_support.md ("Final allowlist") are parsed: backticked names in the
`Elements:` and `Attributes:` paragraphs. Geometry attributes that belong to the allowed elements by
definition (d, cx, points, offset, ...) are added from GEOMETRY_ATTRS below; the palette is every hex
value in the art bible section 3.2 tables, the V1-GATE accent colors, and src/ui/palette.gd.
Usage: python tools/art_rules_gen.py [--check]   (--check exits 1 when art_rules.json is stale)
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUPPORT = ROOT / "docs" / "art" / "svg_support.md"
BIBLE = ROOT / "docs" / "design" / "10_art_bible.md"
PALETTE_GD = ROOT / "src" / "ui" / "palette.gd"
OUT = ROOT / "tools" / "art_rules.json"

# Names in the md paragraphs that are attributes/functions, not elements.
NOT_ELEMENTS = {"rx", "ry", "fx", "fy", "href"}
TRANSFORM_FUNCS = ["translate", "rotate", "scale", "skewX", "skewY", "matrix"]
# Attributes that belong to the allowed elements by definition (SVG Tiny subset).
GEOMETRY_ATTRS = [
    "d", "x", "y", "width", "height", "cx", "cy", "r", "rx", "ry", "x1", "y1", "x2", "y2", "points", "offset",
    "fx", "fy", "stop-color", "stop-opacity", "stdDeviation", "in", "result", "maskUnits", "clipPathUnits",
    "filterUnits", "href", "xlink:href", "xmlns", "xmlns:xlink", "version", "viewBox", "class", "type",
    "preserveAspectRatio", "color-interpolation-filters",
]
# Elements the md names in prose or with wildcards (`animate*`, `<text>/tspan`) or that are untested.
EXTRA_FORBIDDEN = {"text", "tspan", "animate", "animateTransform", "animateMotion", "set", "image", "marker",
                   "foreignObject", "switch", "feDropShadow", "feColorMatrix", "pattern"}
# Gate decisions block (10_art_bible.md top): per-type accent colors.
GATE_ACCENTS = ["#FF2D4B", "#FF4FD8", "#FF7A1A", "#A35CFF", "#FF1F3D"]
# Colors baked into sprites that no longer match a Palette constant (R1-07 lifted UNAFFORDABLE; the ui_kit lock art keeps it).
BAKED_LEGACY = ["#5C5546"]
# CLAUDE.md IP guardrail list (lowercase regexes, matched against ids, comments, titles, file names).
BANNED = [
    r"terminator", r"skynet", r"cyberdyne", r"\bt-?800\b", r"\bt-?1000\b", r"\bt-?x\b", r"\bt-\d+", r"hunter[- _]?killer",
    r"\bhk\b", r"judg(e)?ment[- _]?day", r"sarah[- _]?connor", r"john[- _]?connor", r"kyle[- _]?reese",
    r"miles[- _]?dyson", r"i'?ll[- _]?be[- _]?back", r"hasta[- _]?la[- _]?vista", r"endoskeleton", r"liquid[- _]?metal",
    r"the[- _]?tower",
]


def para(text: str, label: str) -> str:
    m = re.search(r"^" + re.escape(label) + r"(.*)$", text, re.M)
    if not m:
        raise SystemExit(f"art_rules_gen: paragraph '{label}' not found in svg_support.md")
    return m.group(1)


def ticks(s: str) -> list[str]:
    return re.findall(r"`([^`]+)`", s)


def build() -> dict:
    sup = SUPPORT.read_text(encoding="utf-8")
    sec = sup.split("## Final allowlist", 1)[1].split("## Authoring notes", 1)[0]
    el_p = para(sec, "Elements:")
    at_p = para(sec, "Attributes:")
    fb_p = para(sec, "**Forbidden (FAIL or untested)**:")
    elements = sorted({t for t in ticks(el_p) if re.fullmatch(r"[A-Za-z]+", t) and t not in NOT_ELEMENTS})
    attrs = {t for t in ticks(at_p) if re.fullmatch(r"[A-Za-z:-]+", t)}
    attrs -= set(TRANSFORM_FUNCS)
    attrs |= set(GEOMETRY_ATTRS)
    named = {w for t in ticks(fb_p) for w in re.split(r"[/<>\s]+", t) if re.fullmatch(r"[A-Za-z]+", w)}
    forbidden = sorted((named | EXTRA_FORBIDDEN) - set(elements))
    bible = BIBLE.read_text(encoding="utf-8")
    sec32 = bible.split("### 3.2 Material ramps", 1)[1].split("### 4.", 1)[0].split("\n## 4.", 1)[0]
    pal = set(h.upper() for h in re.findall(r"#[0-9A-Fa-f]{6}\b", sec32))
    pal |= set(GATE_ACCENTS)
    pal |= set(h.upper() for h in re.findall(r'Color\("(#[0-9A-Fa-f]{6})"\)', PALETTE_GD.read_text(encoding="utf-8")))
    pal |= set(BAKED_LEGACY)
    pal |= {"#000000", "#FFFFFF"}
    return {
        "_generated_by": "tools/art_rules_gen.py from docs/art/svg_support.md, docs/design/10_art_bible.md 3.2/4.4 and src/ui/palette.gd; do not hand-edit",
        "elements": elements,
        "attributes": sorted(attrs),
        "transform_funcs": TRANSFORM_FUNCS,
        "cell_group_transform": "single translate(x,y) to the cell origin",
        "forbidden_elements": forbidden,
        "filter_children": ["feGaussianBlur"],
        "limits": {
            "max_elements_per_sheet": 400,
            "max_elements_per_cell": 80,
            "max_defs": 24,
            "max_clip_paths": 4,
            "max_filters": 8,
            "max_path_segments": 40,  # per contour (sub-path); batch paths of many small contours are fine
            "max_decimals": 1,
        },
        "drawing_elements": ["path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "use"],
        "id_pattern": r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$",
        "cell_group_prefix": "slot.",
        "palette": sorted(pal),
        "banned_strings": BANNED,
    }


def render() -> str:
    return json.dumps(build(), indent=2, sort_keys=False) + "\n"


def main() -> int:
    text = render()
    if "--check" in sys.argv:
        cur = OUT.read_text(encoding="utf-8") if OUT.is_file() else ""
        if cur != text:
            print("art_rules.json is stale: run python tools/art_rules_gen.py")
            return 1
        print("art_rules.json is current")
        return 0
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
