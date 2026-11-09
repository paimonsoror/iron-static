"""Generates the armor plate cells of the Cinder rig (VT-3, docs/design/12_upgrade_visual_tiers.md section 4.2) and
writes them into the six Cinder sheets (vanguard, bulwark, striker; body + glow): the three frames share the same
plate art at first, so each sheet carries its own copy of the cells (a few KB of texture, no new sheet).

Plates are DOCKED: each cell is an annular sector that starts under the frame disc (r 190, the frame edge is r 200)
and is authored pointing up with the pivot on Cinder's center, exactly like the 12 skin wedges, so the rig draws
the cells rotated: 4 corner plates (45 degrees), 4 bridge plates (cardinals), 16 lip segments and 4 caps (MK IV).
The glow twins are tight trim lines (amber on plates and caps, teal diodes on the lip) in the half-size glow sheets.
All colors come from the art palette; texel = 0.5 px of the reference rig (armor ring r 200, integrity ring r 287).

  .venv\\Scripts\\python.exe -I tools\\gen_cinder_plates.py            (rewrites the plate cells in the six sheets)
  .venv\\Scripts\\python.exe -I tools\\gen_cinder_plates.py --slots    (prints the slots.csv rows)
"""

import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "art" / "src"
BEGIN = "<!-- plates:begin (tools/gen_cinder_plates.py) -->"
END = "<!-- plates:end -->"

# gunmetal ramp of the art bible
D0, D1, S0, S1, M0, M1, L0, L1, H0 = "#07090C", "#12181D", "#2B343B", "#38434B", "#56656F", "#6B7882", "#8FA3B0", "#C9D1D9", "#D4E0E8"
AMBER, AMBER_L, AMBER_H, TEAL = "#FFB000", "#FFD27A", "#FFF1C9", "#2EE6D6"

# Body cells: sheet origins inside the free block of the body sheets (x 128..672, y 768..1024).
BODY_ORIGIN = {"corner": (128, 768), "bridge": (416, 768), "lip": (128, 940), "cap": (260, 940)}
# Glow cells: free strip x 0..248, y 480..512 and column x 440..512, y 384..512 of the half-size glow sheets.
GLOW_ORIGIN = {"corner": (0, 480), "bridge": (126, 480), "lip": (440, 412), "cap": (440, 392)}
TRIM_NAME = {"corner": "trim", "bridge": "trim", "lip": "diode", "cap": "trim"}


def f(v: float) -> str:
    s = f"{v:.1f}"
    s = s.rstrip("0").rstrip(".") if "." in s else s
    return "0" if s in ("-0", "") else s


class Cell:
    """Polar drawing around the rig center O; angles in radians clockwise from up; r in cell texels."""

    def __init__(self, name: str, scale: float) -> None:
        self.name, self.k = name, scale
        self.items: list[tuple[str, list[tuple[float, float]]]] = []  # (svg template, points in rig coords, y down)
        self.pts: list[tuple[float, float]] = []

    def p(self, r: float, a: float) -> tuple[float, float]:
        return (r * self.k * math.sin(a), -r * self.k * math.cos(a))

    def arc(self, r: float, a0: float, a1: float, n: int = 10) -> list[tuple[float, float]]:
        return [self.p(r, a0 + (a1 - a0) * i / n) for i in range(n + 1)]

    def sector(self, r0: float, r1: float, half: float, ch: float = 0.0, steps: int = 8) -> list[tuple[float, float]]:
        ao, ai = ch / r1, ch / r0
        out = [self.p(r1, -half + ao + (2 * half - 2 * ao) * i / steps) for i in range(steps + 1)]
        out += [self.p(r1 - ch, half), self.p(r0 + ch, half)]
        out += [self.p(r0, half - ai - (2 * half - 2 * ai) * i / steps) for i in range(steps + 1)]
        out += [self.p(r0 + ch, -half), self.p(r1 - ch, -half)]
        return out

    def poly(self, pts, fill, extra="") -> None:
        self.items.append(("poly", pts, fill, extra))

    def line(self, pts, stroke, w, op=1.0) -> None:
        self.items.append(("line", pts, stroke, (w * self.k, op)))

    def circle(self, c, r, fill, op=1.0) -> None:
        self.items.append(("circle", [c], fill, (r * self.k, op)))

    def bounds(self, pad: float) -> tuple[float, float, float]:
        """(half width, top, bottom) around O in cell texels, including stroke half widths and padding."""
        xs, ys = [], []
        for kind, pts, _fill, extra in self.items:
            grow = 0.0
            if kind == "line":
                grow = extra[0] / 2
            elif kind == "circle":
                grow = extra[0]
            elif "stroke-width" in extra:
                grow = float(re.search(r'stroke-width="([\d.]+)"', extra).group(1)) / 2
            for x, y in pts:
                xs += [abs(x) + grow]
                ys += [y - grow, y + grow]
        return max(xs) + pad, min(ys) - pad, max(ys) + pad

    def svg(self, ox: float, oy: float, w: int, h: int) -> str:
        out = []
        for kind, pts, fill, extra in self.items:
            def xy(p): return f"{f(ox + p[0])},{f(oy + p[1])}"
            if kind == "poly":
                out.append(f'<polygon points="{" ".join(xy(p) for p in pts)}" fill="{fill}" {extra}'.rstrip() + "/>")
            elif kind == "line":
                w_, op = extra
                out.append(
                    f'<polyline points="{" ".join(xy(p) for p in pts)}" fill="none" stroke="{fill}" '
                    f'stroke-width="{f(w_)}" stroke-linecap="round" stroke-linejoin="round" stroke-opacity="{op:.2f}"/>'
                )
            else:
                (c,) = pts
                out.append(f'<circle cx="{f(ox + c[0])}" cy="{f(oy + c[1])}" r="{f(extra[0])}" fill="{fill}" fill-opacity="{extra[1]:.2f}"/>')
        return "\n".join(out)


def plate_body(c: Cell, r0, r1, half, ch, groove_r, groove_half, rivets, face, rim, lugs=True) -> None:
    c.poly(c.sector(r0, r1, half, ch), S0, f'stroke="{D0}" stroke-width="4"')
    c.poly(c.sector(r0 + 6, r1 - 5, half - 5 / r1, ch * 0.6), face)
    c.poly(c.sector(r0 + 18, r1 - 12, half - 12 / r1, ch * 0.3), M1, 'fill-opacity="0.85"')
    c.line([c.p(r0 + 6, 0), c.p(r1 - 6, 0)], D1, 2.5, 0.75)
    c.line(c.arc((r0 + r1) / 2 - 8, -half + 8 / r1, half - 8 / r1), D1, 2.0, 0.7)
    c.line(c.arc(r1 - 3.5, -half + 12 / r1, half - 12 / r1), rim, 2.5, 0.9)
    c.line(c.arc(r1 - 3.5, -half + 30 / r1, half - 30 / r1), H0, 1.2, 0.9)
    c.line(c.arc(groove_r, -groove_half, groove_half), D1, 7.0, 0.95)
    for s in (-1, 1) * (rivets // 2) if rivets else ():
        pos = c.p((r0 + r1) / 2 + 12, s * half * 0.62)
        c.circle(pos, 3.2, M1)
        c.circle((pos[0] - 0.6 * c.k, pos[1] - 0.6 * c.k), 1.5, L1, 0.9)
    if lugs:  # mounts that dock the plate to the frame disc
        for s in (-1, 1):
            a = s * half * 0.55
            c.poly([c.p(r0 + 6, a - 0.07), c.p(r0 + 6, a + 0.07), c.p(r0 + 30, a + 0.06), c.p(r0 + 30, a - 0.06)], D1, f'stroke="{D0}" stroke-width="2"')
            c.circle(c.p(r0 + 18, a), 3.0, L0)


def build(kind: str, k: float, glow: bool) -> Cell:
    c = Cell(kind, k)
    d = math.radians
    if kind == "corner":
        if glow:
            for w, col in ((5.0, AMBER), (1.8, AMBER_H)):
                c.line(c.arc(306, -d(21), d(21)), col, w, 0.95)
        else:
            plate_body(c, 190, 330, d(24), 12, 306, d(21), 2, M0, L1)
    elif kind == "bridge":
        if glow:
            for w, col in ((5.0, AMBER), (1.8, AMBER_H)):
                c.line(c.arc(292, -d(13), d(13)), col, w, 0.95)
        else:
            plate_body(c, 190, 312, d(15), 10, 292, d(13), 0, M0, L1)
    elif kind == "lip":
        if glow:
            for w, col in ((5.0, TEAL), (1.8, "#FFFFFF")):
                c.line(c.arc(319, -d(5.5), d(5.5), 4), col, w, 0.85)
        else:
            c.poly(c.sector(308, 330, d(9.4), 4, 4), S0, f'stroke="{D0}" stroke-width="3"')
            c.poly(c.sector(311, 327, d(7.6), 3, 4), M0)
            c.line(c.arc(326, -d(6.5), d(6.5), 4), L1, 1.6, 0.9)
            c.line(c.arc(319, -d(5.5), d(5.5), 4), D1, 7.0, 0.95)
    else:  # cap on a corner plate
        if glow:
            for w, col in ((5.0, AMBER_L), (1.8, AMBER_H)):
                c.line(c.arc(332, -d(10), d(10)), col, w, 0.95)
        else:
            c.poly(c.sector(320, 344, d(19), 6, 6), S1, f'stroke="{D0}" stroke-width="3"')
            c.poly(c.sector(323, 341, d(16.5), 4, 6), M1)
            c.line(c.arc(338, -d(14), d(14), 6), H0, 1.6, 0.9)
            c.line(c.arc(332, -d(10), d(10)), D1, 7.0, 0.95)
    return c


def cells(glow: bool) -> dict:
    """kind -> dict(svg, x, y, w, h, px, py) with the cell origin from the origin tables."""
    out = {}
    pad = 5.0 if glow else 7.0
    for kind in ("corner", "bridge", "lip", "cap"):
        c = build(kind, 0.5 if glow else 1.0, glow)
        hw, top, bot = c.bounds(pad)
        w = 2 * math.ceil(hw)
        py = math.ceil(-top)
        h = py + math.ceil(bot)
        ox, oy = (GLOW_ORIGIN if glow else BODY_ORIGIN)[kind]
        out[kind] = {"svg": c.svg(ox + w / 2, oy + py, w, h), "x": ox, "y": oy, "w": w, "h": h, "px": w // 2, "py": py}
    return out


def inject(path: Path, group_xml: str) -> None:
    text = path.read_text(encoding="utf-8")
    text = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END) + r"\n?", "", text, flags=re.S)
    block = f"{BEGIN}\n{group_xml}\n{END}\n"
    text = text.replace("</svg>", block + "</svg>")
    path.write_text(text, encoding="utf-8", newline="\n")


def group(kind: str, name: str, info: dict) -> str:
    return f'<g id="slot.{name}" transform="translate({info["x"]},{info["y"]})">\n' + info["svg"].replace(
        "\n", "\n"
    ).replace('points="', 'points="') + "\n</g>"


def shift(info: dict) -> str:
    """The cell body is drawn in sheet coordinates; the group transform is a translate to the cell origin, so shift back."""
    return info["svg"]


def main() -> None:
    body, glow = cells(False), cells(True)
    # rewrite coordinates relative to the cell origin (the cell group carries translate(x,y))
    def rel(kind: str, glow_: bool) -> dict:
        c = build(kind, 0.5 if glow_ else 1.0, glow_)
        info = (glow if glow_ else body)[kind]
        info = dict(info)
        info["svg"] = c.svg(info["w"] / 2, info["py"], info["w"], info["h"])
        return info

    rows: list[str] = []
    for prefix in ("cinder", "cinder_bulwark", "cinder_striker"):
        suffix = "" if prefix == "cinder" else prefix[len("cinder"):]
        body_file, glow_file = f"{prefix}.svg", f"{prefix}_glow.svg"
        bx, gx = [], []
        for kind in ("corner", "bridge", "lip", "cap"):
            b, g = rel(kind, False), rel(kind, True)
            name = f"plate_{kind}"
            gname = f"plate_{kind}_{TRIM_NAME[kind]}"
            bx.append(group(kind, name, b))
            gx.append(group(kind, gname, g))
            full, gfull = f"cinder{suffix}_{name}", f"cinder{suffix}_{gname}"
            rows.append(
                f"{full},{body_file},{glow_file},{gfull},1024,1024,{b['x']},{b['y']},{b['w']},{b['h']},1,{b['px']},{b['py']},,,2,1,,4,,normal,cinder,ready,"
                f'"VT-3 armor plate cell ({kind}), drawn rotated around the rig center; shared art of the three frames"'
            )
            rows.append(
                f"{gfull},{glow_file},,,512,512,{g['x']},{g['y']},{g['w']},{g['h']},1,{g['px']},{g['py']},,,1,1,,3,,add,cinder,ready,"
                f'"VT-3 armor plate trim glow ({kind}), half size, additive"'
            )
        if "--slots" not in sys.argv:
            inject(SRC / body_file, "\n".join(bx))
            inject(SRC / glow_file, "\n".join(gx))
    if "--slots" in sys.argv:
        print("\n".join(rows))
    else:
        for kind in ("corner", "bridge", "lip", "cap"):
            b, g = body[kind], glow[kind]
            print(f"{kind}: body {b['w']}x{b['h']} pivot ({b['px']},{b['py']})  glow {g['w']}x{g['h']} pivot ({g['px']},{g['py']})")


main()
