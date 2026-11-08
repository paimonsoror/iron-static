"""Generates the Cinder frame variant sheets (M3-27) from the VANGUARD sheets `assets/art/src/cinder.svg` and
`cinder_glow.svg`: `cinder_bulwark(.svg|_glow.svg)` and `cinder_striker(.svg|_glow.svg)`.

Same cell origins, pivots and layer names as the VANGUARD sheets (rig code is shared); the variant replaces the plates
(wedge a/b intact and charred), the shoulder block, the emitter ring look, the trim colors and the matching glow cells.
The core, crack, shadow and integrity cells are copied unchanged, so the core glow and the band logic stay identical.

  .venv\\Scripts\\python.exe -I tools\\cinder_variants.py            (rewrites the four files)
  .venv\\Scripts\\python.exe -I tools\\cinder_variants.py --slots    (prints the slots.csv rows to append)
"""

import csv
import io
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "art" / "src"
PX, PY = 64.0, 196.0  # wedge pivot inside its 128x112 cell


def f(v: float) -> str:
    s = f"{v:.1f}"
    s = s.rstrip("0").rstrip(".") if "." in s else s
    return "0" if s in ("-0", "") else s


def pp(r: float, a: float, cx: float = PX, cy: float = PY) -> str:
    t = math.radians(a)
    return f"{f(cx + r * math.sin(t))} {f(cy - r * math.cos(t))}"


def sector(ri: float, ro: float, h: float) -> str:
    return (
        f"M{pp(ri, -h)}L{pp(ro, -h)}A{f(ro)} {f(ro)} 0 0 1 {pp(ro, h)}L{pp(ri, h)}A{f(ri)} {f(ri)} 0 0 0 {pp(ri, -h)}Z"
    )


def arc(r: float, a1: float, a2: float, cx: float = PX, cy: float = PY) -> str:
    return f"M{pp(r, a1, cx, cy)}A{f(r)} {f(r)} 0 0 1 {pp(r, a2, cx, cy)}"


def seg(r1: float, a1: float, r2: float, a2: float) -> str:
    return f"M{pp(r1, a1)}L{pp(r2, a2)}"


def poly(pts: list[tuple[float, float]], close: bool = False) -> str:
    s = "M" + "L".join(pp(r, a) for r, a in pts)
    return s + ("Z" if close else "")


def path(d: str, fill: str = "none", stroke: str = "", sw: float = 0, op: float = 1.0, cap: str = "butt") -> str:
    out = f'<path d="{d}" fill="{fill}"'
    if stroke:
        out += f' stroke="{stroke}" stroke-width="{f(sw)}" stroke-linejoin="round"'
        if cap != "butt":
            out += f' stroke-linecap="{cap}"'
    if op < 1.0:
        out += f' opacity="{op}"'
    return out + "/>"


def circ(cx: float, cy: float, r: float, fill: str, stroke: str = "", sw: float = 0, op: float = 1.0) -> str:
    out = f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{fill}"'
    if stroke:
        out += f' stroke="{stroke}" stroke-width="{f(sw)}"'
    if op < 1.0:
        out += f' opacity="{op}"'
    return out + "/>"


def rivet(r: float, a: float, rad: float, base: str, hi: str) -> str:
    x, y = (float(v) for v in pp(r, a).split())
    return circ(x, y, rad, base) + circ(x - rad * 0.3, y - rad * 0.3, rad * 0.4, hi)


# ---- svg text helpers ------------------------------------------------------------------------------------------


def group_span(svg: str, slot: str) -> tuple[int, int]:
    start = svg.index(f'<g id="slot.{slot}"')
    nxt = svg.find('\n<g id="slot.', start + 10)
    end = nxt if nxt >= 0 else svg.index("</svg>")
    return start, end


def get_group(svg: str, slot: str) -> str:
    a, b = group_span(svg, slot)
    return svg[a:b]


def put_group(svg: str, slot: str, text: str) -> str:
    a, b = group_span(svg, slot)
    return svg[:a] + text.rstrip("\n") + "\n" + svg[b:]


def cell(slot: str, x: int, y: int, layers: list[tuple[str, str, str]]) -> str:
    """layers: (layer name, attrs on the layer group, inner svg)."""
    out = f'<g id="slot.{slot}" transform="translate({x},{y})">\n'
    for name, attrs, inner in layers:
        out += f'\n  <g id="layer.{slot}.{name}"{attrs}>{inner}</g>\n'
    return out.rstrip("\n") + "</g>\n"


def set_stops(svg: str, gid: str, stops: list[tuple[float, str]]) -> str:
    m = re.search(r'(<(linear|radial)Gradient id="%s"[^>]*>)(.*?)(</\2Gradient>)' % gid, svg, re.S)
    assert m, gid
    inner = "".join(f'<stop offset="{o:g}" stop-color="{c}"/>' for o, c in stops)
    return svg[: m.start(3)] + inner + svg[m.end(3) :]


def add_def(svg: str, text: str) -> str:
    return svg.replace("</defs>", text + "</defs>", 1)


BRONZE_RAMP = [(0, "#FFD27A"), (0.35, "#D6B36A"), (0.7, "#8A5F00"), (1, "#5A4034")]
WHITE_RAMP = [(0, "#FFFFFF"), (0.5, "#FFF1C9"), (1, "#FFD27A")]


def bronze_def() -> str:
    return (
        '<linearGradient id="g_bronze" gradientUnits="userSpaceOnUse" x1="64" y1="12" x2="64" y2="100">'
        '<stop offset="0" stop-color="#FFD27A"/><stop offset="0.35" stop-color="#D6B36A"/>'
        '<stop offset="1" stop-color="#8A5F00"/></linearGradient>'
    )


# ---- plates ----------------------------------------------------------------------------------------------------

# crack polylines in (radial fraction u, angular fraction v) of a plate, so they follow each variant's outline
CRACKS_A = [[(0.96, 0.5), (0.86, 0.78), (0.78, 0.3), (0.66, 0.55), (0.55, 0.05), (0.44, 0.3), (0.34, -0.15)]]
CRACKS_B = [[(0.9, -0.55), (0.8, -0.2), (0.7, -0.5), (0.58, -0.1), (0.46, -0.4), (0.36, -0.1)]]
BREAK_A = [(0.66, -0.55), (0.62, -0.05), (0.7, 0.35), (0.6, 0.5), (0.5, 0.1), (0.52, -0.45)]
BREAK_B = [(0.72, 0.1), (0.66, 0.5), (0.56, 0.4), (0.5, -0.1), (0.6, -0.2)]


class Plate:
    """Geometry and look of one variant's skin-burn plate (12 per ring, rotated 30 degrees apart)."""

    def __init__(self, name: str, h: float, ri: float, ro: float) -> None:
        self.name, self.h, self.ri, self.ro = name, h, ri, ro

    def uv(self, u: float, v: float) -> tuple[float, float]:
        return self.ri + (self.ro - self.ri) * u, self.h * v

    def crack(self, pts: list[tuple[float, float]]) -> str:
        return poly([self.uv(u, v) for u, v in pts])

    def outline(self) -> str:
        return sector(self.ri, self.ro, self.h)

    def charred(self, which: str) -> tuple[str, str]:
        ri, ro, h = self.ri, self.ro, self.h
        cracks = CRACKS_A if which == "a" else CRACKS_B
        brk = BREAK_A if which == "a" else BREAK_B
        scorch = "g_scorch_a" if which == "a" else "g_scorch_b"
        base = (
            path(self.outline(), "url(#g_char)", "#1F1612", 3)
            + path(self.outline(), f"url(#{scorch})")
            + path(sector(ro - 15, ro - 1, h - 1.6), "#7A5A48", op=0.55)
            + path(arc(148, -h + 3.5, h - 3.5), "none", "#1F1612", 5)
            + path(arc(150, -h + 3.5, h - 3.5), "none", "#7A5A48", 2.5, 0.5)
            + path(sector(ri + 14, 138, h - 5), "none", "#1F1612", 3.5)
            + path(sector(158, ro - 20, h - 4.5), "none", "#1F1612", 3.5)
        )
        pts = [self.uv(u, v) for u, v in brk]
        crk = "".join(self.crack(c) for c in cracks)
        detail = (
            path(poly(pts, True), "#2B343B", "#1F1612", 2.5)
            + path(poly(pts[:4]), "none", "#56656F", 2.5, 0.8)
            + path(crk, "none", "#1F1612", 4, cap="round")
            + path(crk, "none", "#7A5A48", 1.8, 0.7, cap="round")
            + rivet(ro - 10, h - 6 if which == "a" else -h + 6, 4.5, "#1F1612", "#7A5A48")
            + path(
                f"M{pp(ro, h)}L{pp(ro - 1.5, h - 4.5)}L{pp(ro - 14, h - 1)}Z", "#1F1612"
            )
        )
        return base, detail

    def ember(self, which: str) -> str:
        """Glow cell content (body coordinates, wrapped by `translate(4 4) scale(0.5)`)."""
        cracks = CRACKS_A if which == "a" else CRACKS_B
        crk = "".join(self.crack(c) for c in cracks)
        o = self.outline()
        cx, cy = (float(v) for v in pp(0.5 * (self.ri + self.ro), 0.0).split())
        return (
            path(o, "#FF8A1F", op=0.12)
            + path(o, "none", "#FF8A1F", 9, 0.18)
            + path(o, "none", "#FF8A1F", 5, 0.45)
            + path(o, "none", "#FFD27A", 2.5, 0.8)
            + path(crk, "none", "#FF8A1F", 11, 0.22, "round")
            + path(crk, "none", "#FF8A1F", 6.5, 0.6, "round")
            + path(crk, "none", "#FFD27A", 2.6, 0.9, "round")
            + circ(cx, cy, 9, "#FFD27A", op=0.35)
            + circ(cx, cy, 4, "#FFF1C9", op=0.9)
        )

    def seam(self) -> str:
        h = self.h - 3.5
        col = "#FFF1C9" if self.name == "striker" else "#FFD27A"
        wide = 14.0 if self.name == "striker" else 9.0
        core = 5.0 if self.name == "striker" else 3.5
        return path(arc(150, -h, h), "none", "#FFB000", wide, 0.16) + path(arc(150, -h, h), "none", col, core, 0.45)


def bulwark_plates() -> tuple[Plate, dict[str, str]]:
    p = Plate("bulwark", 16.5, 100.0, 187.0)
    ri, ro, h = p.ri, p.ro, p.h
    base = (
        path(p.outline(), "url(#g_plate)", "#38434B", 3)
        + path(sector(ri, ri + 9, h - 1), "#38434B", op=0.5)
        + path(sector(ro - 15, ro - 1, h - 1.6), "url(#g_bronze)", "#5A4034", 2)
        + path(arc(ro - 3.5, -h + 4, h - 4), "none", "#FFF1C9", 2, 0.7, "round")
        + path(seg(ri + 4, -h + 2.5, ro - 17, -h + 2.5), "none", "#DCE6EC", 2, 0.3, "round")
        + path(arc(150, -h + 3.5, h - 3.5), "none", "#38434B", 9)
        + path(arc(150, -h + 3.5, h - 3.5), "none", "#D6B36A", 5)
        + path(sector(ri + 14, 138, h - 5), "url(#g_panel)", "#38434B", 3)
        + path(arc(137, -h + 6, h - 6), "none", "#DCE6EC", 2, 0.5)
        + path(sector(158, ro - 20, h - 4.5), "url(#g_panel)", "#38434B", 3)
    )
    det_a = (
        path(seg(ri + 22, -6, 130, -6) + seg(ri + 22, 0, 130, 0) + seg(ri + 22, 6, 130, 6), "none", "#12181D", 4.5, cap="round")
        + rivet(ro - 8, -h + 5.5, 4.8, "#5A4034", "#FFF1C9")
        + rivet(ro - 8, h - 5.5, 4.8, "#5A4034", "#FFF1C9")
        + rivet(166, -h + 6, 3.8, "#38434B", "#DCE6EC")
        + rivet(166, h - 6, 3.8, "#38434B", "#DCE6EC")
        + path(poly([(165, -5.5), (174, 0), (165, 5.5), (168.5, 0)], True), "#D6B36A", "#8A5F00", 1.5)
        + path(seg(ri + 12, h - 3, ri + 18, h - 4), "none", "#DCE6EC", 2, 0.7, "round")
    )
    det_b = (
        path(arc(122, -9, 9) + arc(130, -9, 9), "none", "#12181D", 4, cap="round")
        + "".join(circ(*(float(v) for v in pp(166, a).split()), 3.4, "#38434B") for a in (-9, -4.5, 0, 4.5, 9))
        + rivet(ro - 8, -h + 5.5, 4.8, "#5A4034", "#FFF1C9")
        + rivet(ro - 8, h - 5.5, 4.8, "#5A4034", "#FFF1C9")
        + path(poly([(ri + 28, -3), (ri + 22, 0), (ri + 28, 3)]), "none", "#D6B36A", 3, cap="round")
        + path(seg(ro - 24, h - 5, ro - 30, h - 8) + seg(ro - 26, -h + 6, ro - 34, -h + 9), "none", "#38434B", 2.5, 0.8, "round")
    )
    return p, {"base": base, "det_a": det_a, "det_b": det_b}


def striker_plates() -> tuple[Plate, dict[str, str]]:
    p = Plate("striker", 11.8, 108.0, 179.0)
    ri, ro, h = p.ri, p.ro, p.h
    base = (
        path(p.outline(), "url(#g_plate)", "#2B343B", 3)
        + path(sector(ri, ri + 8, h - 1), "#12181D", op=0.55)
        + path(arc(ro - 3, -h + 2.8, h - 2.8), "none", "#FFF1C9", 2.5, 0.9, "round")
        + path(seg(ri + 4, -h + 2.2, ro - 6, -h + 2.2), "none", "#DCE6EC", 2, 0.3, "round")
        + path(arc(150, -h + 3, h - 3), "none", "#12181D", 6)
        + path(arc(150, -h + 3, h - 3), "none", "#FFF1C9", 3)
        + path(sector(158, ro - 10, h - 3.5), "url(#g_panel)", "#2B343B", 2.5)
        + path(arc(ro - 11, -h + 5, h - 5), "none", "#DCE6EC", 2, 0.5)
    )
    det_a = (
        path("".join(seg(ri + 10, a, 140, a) for a in (-7, -2.3, 2.3, 7)), "none", "#12181D", 3.2, cap="round")
        + path(poly([(ro - 3, -4), (ro - 14, 0), (ro - 3, 4), (ro - 7, 0)], True), "#12181D")
        + rivet(ro - 20, -h + 4.5, 3.6, "#2B343B", "#DCE6EC")
        + rivet(ro - 20, h - 4.5, 3.6, "#2B343B", "#DCE6EC")
        + path(seg(ri + 12, h - 3, ri + 20, h - 3.5), "none", "#FFF1C9", 2, 0.8, "round")
    )
    det_b = (
        path(
            poly([(120, -6.5), (127, 0), (120, 6.5)])
            + poly([(131, -6.5), (138, 0), (131, 6.5)])
            + poly([(142, -5), (148.5, 0), (142, 5)]),
            "none",
            "#12181D",
            3.2,
            cap="round",
        )
        + path(poly([(ro - 3, -4), (ro - 14, 0), (ro - 3, 4), (ro - 7, 0)], True), "#12181D")
        + path(seg(165, -6, ro - 14, -6.5) + seg(165, 6, ro - 14, 6.5), "none", "#FFF1C9", 1.8, 0.7, "round")
        + rivet(ro - 20, 0, 3.4, "#2B343B", "#DCE6EC")
    )
    return p, {"base": base, "det_a": det_a, "det_b": det_b}


def plate_cells(svg: str, p: Plate, parts: dict[str, str]) -> str:
    for name, x, which, kind in (
        ("wedge_a_intact", 0, "a", "intact"),
        ("wedge_b_intact", 128, "b", "intact"),
        ("wedge_a_charred", 256, "a", "charred"),
        ("wedge_b_charred", 384, "b", "charred"),
    ):
        if kind == "intact":
            layers = [("base", "", parts["base"]), ("detail", "", parts["det_" + which])]
        else:
            b, d = p.charred(which)
            layers = [("base", "", b), ("detail", "", d)]
        svg = put_group(svg, name, cell(name, x, 448, layers))
    return svg


def glow_plate_cells(svg: str, p: Plate) -> str:
    tr = ' transform="translate(4 4) scale(0.5)"'
    for name, y, which in (("ember_edge_a", 0, "a"), ("ember_edge_b", 72, "b")):
        svg = put_group(svg, name, cell(name, 440, y, [("glow", tr, p.ember(which))]))
    return put_group(svg, "seam_glow", cell("seam_glow", 440, 144, [("glow", tr, p.seam())]))


# ---- shoulder, ring, trim --------------------------------------------------------------------------------------


def shoulder_bulwark() -> str:
    block = "M10 38L38 8L136 8L164 36L164 124L136 152L38 152L10 124Z"
    rec = "M22 46L44 20L130 20L152 44L152 116L130 140L44 140L22 116Z"
    shadow = "M18 46L46 16L144 16L172 44L172 132L144 156L46 156L18 132Z"
    lens = (
        circ(84, 74, 34, "#14191D", "#D6B36A", 3.5)
        + circ(84, 74, 28, "none", "#2B343B", 3)
        + circ(84, 74, 22, "url(#g_slens)")
        + path("M66 74L102 74M84 56L84 92", "none", "#8A5F00", 3, 0.7)
        + path("M69.9 68.9A15 15 0 0 1 80.1 59.5", "none", "#FFFFFF", 3, 0.85, "round")
    )
    return cell(
        "shoulder",
        448,
        608,
        [
            ("shadow", "", path(shadow, "#0A0D10", op=0.4)),
            (
                "arm",
                "",
                path("M158 64L196 60L196 128L158 124Z", "url(#g_arm)", "#2B343B", 3)
                + path("M188 54L218 58L218 134L188 138Z", "url(#g_arm)", "#2B343B", 3)
                + path("M189 58L217 61", "none", "#FFF1C9", 2.5, 0.8)
                + circ(203, 72, 5, "#2B343B", "#D6B36A", 1.5)
                + circ(203, 120, 5, "#2B343B", "#D6B36A", 1.5)
                + circ(201.8, 70.8, 1.8, "#FFF1C9")
                + circ(201.8, 118.8, 1.8, "#FFF1C9"),
            ),
            (
                "base",
                "",
                path(block, "url(#g_sh)", "url(#g_sh_edge)", 5)
                + path(rec, "url(#g_sh_rec)", "#2B343B", 3)
                + path("M40 118L136 118M40 127L136 127M40 136L136 136", "none", "#12181D", 4.5)
                + path("M40 115L136 115M40 124L136 124M40 133L136 133", "none", "#8FA3B0", 1.5, 0.6)
                + path("M22 44L40 22L40 44ZM152 44L134 22L134 44Z", "#D6B36A", "#8A5F00", 2),
            ),
            ("lens", "", lens),
            (
                "trim",
                "",
                path("M52 28L124 28", "none", "#D6B36A", 7)
                + circ(30, 40, 4, "#D6B36A")
                + circ(146, 40, 4, "#D6B36A")
                + circ(30, 118, 4, "#D6B36A")
                + circ(146, 118, 4, "#D6B36A"),
            ),
        ],
    )


def shoulder_striker() -> str:
    block = "M50 36L72 8L100 8L122 36L122 124L100 152L72 152L50 124Z"
    rec = "M60 40L76 18L96 18L112 40L112 120L96 142L76 142L60 120Z"
    shadow = "M58 40L80 14L108 14L130 40L130 128L108 154L80 154L58 128Z"
    lens = (
        circ(84, 74, 27, "#14191D", "#FFF1C9", 3)
        + circ(84, 74, 22, "none", "#2B343B", 3)
        + circ(84, 74, 18, "url(#g_slens)")
        + path("M70 74L98 74M84 60L84 88", "none", "#8A5F00", 2.5, 0.7)
        + path("M72 69.5A13 13 0 0 1 80.5 62", "none", "#FFFFFF", 2.5, 0.85, "round")
    )
    return cell(
        "shoulder",
        448,
        608,
        [
            ("shadow", "", path(shadow, "#0A0D10", op=0.4)),
            (
                "arm",
                "",
                path("M116 68L176 64L176 80L116 82Z", "url(#g_arm)", "#2B343B", 2.5)
                + path("M116 92L176 96L176 112L116 110Z", "url(#g_arm)", "#2B343B", 2.5)
                + path("M170 56L214 62L214 128L170 134Z", "url(#g_arm)", "#2B343B", 3)
                + path("M171 60L213 65", "none", "#FFF1C9", 2.5, 0.9)
                + path("M180 86L206 86", "none", "#12181D", 4)
                + circ(200, 74, 4, "#2B343B", "#DCE6EC", 1.5)
                + circ(200, 118, 4, "#2B343B", "#DCE6EC", 1.5),
            ),
            (
                "base",
                "",
                path(block, "url(#g_sh)", "url(#g_sh_edge)", 4)
                + path(rec, "url(#g_sh_rec)", "#2B343B", 3)
                + path("M70 108L102 108M70 116L102 116M70 124L102 124M70 132L102 132", "none", "#12181D", 4)
                + path("M70 105L102 105M70 113L102 113M70 121L102 121M70 129L102 129", "none", "#DCE6EC", 1.5, 0.5),
            ),
            ("lens", "", lens),
            (
                "trim",
                "",
                path("M62 40L62 118M110 40L110 118", "none", "#FFF1C9", 2.5, 0.95, "round")
                + path("M76 24L96 24", "none", "#FFF1C9", 4)
                + circ(66, 44, 3, "#DCE6EC")
                + circ(106, 44, 3, "#DCE6EC")
                + circ(66, 118, 3, "#DCE6EC")
                + circ(106, 118, 3, "#DCE6EC"),
            ),
        ],
    )


def ring_striker(svg: str) -> str:
    def ac(r: float, a1: float, a2: float) -> str:
        return arc(r, a1, a2, 224, 224)

    segs = [(i * 120 + 19, i * 120 + 101) for i in range(3)]
    thick = "".join(ac(200, a, b) for a, b in segs)
    rim = "".join(ac(207.5, a, b) for a, b in segs)
    ticks = "".join(
        f"M{pp(190, a, 224, 224)}L{pp(184, a, 224, 224)}" for a in range(20, 110, 15) for _ in (0,)
    )
    ticks_all = "".join(
        f"M{pp(190, a + i * 120, 224, 224)}L{pp(183, a + i * 120, 224, 224)}" for i in range(3) for a in (25, 45, 65, 85)
    )
    del ticks
    base = (
        path(thick, "none", "#56656F", 9)
        + path(rim, "none", "#8FA3B0", 2.5)
        + circ(224, 224, 190, "none", "#2B343B", 3)
        + path(ticks_all, "none", "#2B343B", 3.5)
    )

    def node(rot: int) -> str:
        tr = f' transform="rotate({rot} 224 224)"' if rot else ""
        inner = (
            path("M198 52L206 12L242 12L250 52Z", "#2B343B", "#8FA3B0", 3)
            + path("M203 50L209 16L239 16L245 50Z", "url(#g_node)")
            + path("M224 10L228 34L224 42L220 34Z", "#12181D")
            + path("M204 40L246 40", "none", "#2B343B", 3.5)
            + circ(211, 24, 9, "#12181D", "#FFF1C9", 2.5)
            + circ(211, 24, 5.8, "url(#g_lens)")
            + circ(237, 24, 9, "#12181D", "#FFF1C9", 2.5)
            + circ(237, 24, 5.8, "url(#g_lens)")
            + circ(208.5, 21.5, 1.8, "#FFF1C9")
            + circ(234.5, 21.5, 1.8, "#FFF1C9")
        )
        return inner, tr

    layers = [("ring", "", base)]
    for k, rot in enumerate((0, 120, 240)):
        inner, tr = node(rot)
        layers.append((f"node_{k}", tr, inner))
    return put_group(svg, "emitter_ring", cell("emitter_ring", 448, 0, layers))


def ring_bulwark(svg: str) -> str:
    g = get_group(svg, "emitter_ring")
    g = g.replace(
        '<circle cx="224" cy="224" r="200" fill="none" stroke="#56656F" stroke-width="20"/>',
        '<circle cx="224" cy="224" r="200" fill="none" stroke="#56656F" stroke-width="32"/>',
    )
    g = g.replace(
        '<circle cx="224" cy="224" r="209" fill="none" stroke="#8FA3B0" stroke-width="3"/>',
        '<circle cx="224" cy="224" r="217" fill="none" stroke="#D6B36A" stroke-width="4"/>',
    )
    g = g.replace(
        '<circle cx="224" cy="224" r="191" fill="none" stroke="#2B343B" stroke-width="3"/>',
        '<circle cx="224" cy="224" r="185.5" fill="none" stroke="#2B343B" stroke-width="3"/>',
    )
    g = g.replace("M188 50L198 10L204 8L244 8L250 10L260 50Z", "M180 54L190 11L198 7L250 7L258 11L268 54Z")
    g = g.replace("M193 49L202 13L246 13L255 49Z", "M186 52L195 15L253 15L262 52Z")
    g = g.replace('stroke="#8FA3B0" stroke-width="3" stroke-linejoin="round"/>', 'stroke="#D6B36A" stroke-width="3.5" stroke-linejoin="round"/>')
    g = g.replace('r="13.5" fill="#12181D" stroke="#8FA3B0"', 'r="13.5" fill="#12181D" stroke="#D6B36A"')
    return put_group(svg, "emitter_ring", g)


def emitter_glow_striker(svg: str) -> str:
    g = get_group(svg, "emitter_glow")
    for cx, cy, rot in ((224.0, 23.0, 0), (398.1, 324.5, 120), (49.9, 324.5, 240)):
        old = (
            f'<circle cx="{f(cx)}" cy="{f(cy)}" r="10.5" fill="url(#gr_lens)"/>'
            f'<circle cx="{f(cx)}" cy="{f(cy)}" r="4.5" fill="#FFF1C9" opacity="0.9"/>'
        )
        assert old in g, (cx, cy)
        new = ""
        for dx in (-13.0, 13.0):
            t = math.radians(rot)
            x0, y0 = 224.0 + dx, 23.0
            rx = 224.0 + (x0 - 224.0) * math.cos(t) - (y0 - 224.0) * math.sin(t)
            ry = 224.0 + (x0 - 224.0) * math.sin(t) + (y0 - 224.0) * math.cos(t)
            new += circ(rx, ry, 8.5, "url(#gr_lens)") + circ(rx, ry, 3.6, "#FFFFFF", op=0.95)
        g = g.replace(old, new)
    return put_group(svg, "emitter_glow", g)


def sub(svg: str, slot: str, pairs: list[tuple[str, str]]) -> str:
    g = get_group(svg, slot)
    for a, b in pairs:
        assert a in g, (slot, a)
        g = g.replace(a, b)
    return put_group(svg, slot, g)


def build(variant: str) -> tuple[str, str]:
    body = (SRC / "cinder.svg").read_text(encoding="utf-8")
    glow = (SRC / "cinder_glow.svg").read_text(encoding="utf-8")
    body = body.replace("IRON STATIC Cinder body sheet", f"IRON STATIC Cinder {variant} body sheet")
    glow = glow.replace("IRON STATIC Cinder glow sheet", f"IRON STATIC Cinder {variant} glow sheet")
    if variant == "bulwark":
        p, parts = bulwark_plates()
        body = add_def(body, bronze_def())
        body = set_stops(body, "g_amberbar", BRONZE_RAMP)
        body = set_stops(body, "g_rim", BRONZE_RAMP)
        body = set_stops(body, "g_sh_edge", BRONZE_RAMP)
        body = plate_cells(body, p, parts)
        body = put_group(body, "shoulder", shoulder_bulwark())
        body = ring_bulwark(body)
        body = body.replace("#8FA3B0", "#8FA3B0")
        body = sub(body, "visor", [('stroke="#8FA3B0"', 'stroke="#D6B36A"')])
        body = sub(body, "core_housing", [('"#FFB000"', '"#D6B36A"')])
        glow = glow_plate_cells(glow, p)
    else:
        p, parts = striker_plates()
        body = set_stops(body, "g_plate", [(0, "#56656F"), (1, "#2B343B")])
        body = set_stops(body, "g_panel", [(0, "#8FA3B0"), (1, "#56656F")])
        body = set_stops(body, "g_amberbar", WHITE_RAMP)
        body = set_stops(body, "g_slit", [(0, "#FFF1C9"), (0.5, "#FFFFFF"), (1, "#FFF1C9")])
        body = plate_cells(body, p, parts)
        body = put_group(body, "shoulder", shoulder_striker())
        body = ring_striker(body)
        body = sub(body, "core_housing", [('"#FFB000"', '"#FFF1C9"')])
        glow = glow_plate_cells(glow, p)
        glow = emitter_glow_striker(glow)
    return body, glow


def slot_rows(variant: str) -> list[str]:
    lines = [
        ln
        for ln in (ROOT / "assets/art/slots.csv").read_text(encoding="utf-8").splitlines()
        if ln.strip() and not ln.lstrip().startswith("#")
    ]
    rows = list(csv.reader(lines))
    hdr, data = rows[0], rows[1:]
    ix = {n: i for i, n in enumerate(hdr)}
    out: list[str] = []
    for r in data:
        if r[ix["family"]] != "cinder" or r[ix["file"]] not in ("cinder.svg", "cinder_glow.svg"):
            continue
        r = list(r)
        r[ix["slot"]] = r[ix["slot"]].replace("cinder_", f"cinder_{variant}_", 1)
        if r[ix["glow_slot"]]:
            r[ix["glow_slot"]] = r[ix["glow_slot"]].replace("cinder_", f"cinder_{variant}_", 1)
        r[ix["file"]] = r[ix["file"]].replace("cinder", f"cinder_{variant}", 1)
        if r[ix["glow_file"]]:
            r[ix["glow_file"]] = r[ix["glow_file"]].replace("cinder", f"cinder_{variant}", 1)
        if r[ix["notes"]].startswith("cell of the cinder"):
            r[ix["notes"]] = r[ix["notes"]].replace("cinder", f"cinder {variant}", 1)
        buf = io.StringIO()
        csv.writer(buf, lineterminator="").writerow(r)
        out.append(buf.getvalue())
    return out


def main() -> None:
    if "--slots" in sys.argv:
        for v in ("bulwark", "striker"):
            print("\n".join(slot_rows(v)))
        return
    for v in ("bulwark", "striker"):
        body, glow = build(v)
        (SRC / f"cinder_{v}.svg").write_text(body, encoding="utf-8", newline="\n")
        (SRC / f"cinder_{v}_glow.svg").write_text(glow, encoding="utf-8", newline="\n")
        print("wrote", v)


if __name__ == "__main__":
    main()
