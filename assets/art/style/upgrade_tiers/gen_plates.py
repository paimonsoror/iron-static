"""Generates ut_plates.svg (body) and ut_plates_glow.svg (additive) for the upgrade tier style frame.
Mockup art only. Three 640x640 cells in a row: tier 1, 2, 3 plate rings, centered on Cinder.
Texel = 0.5 px of the rig reference, armor ring outer radius = 200 texels, integrity ring = 287 texels.
Run: python gen_plates.py   (writes next to this file). ThorVG-safe: no use, filter, mask, text."""
import math, os

HERE = os.path.dirname(os.path.abspath(__file__))
C = 320.0
SHADOW = (0x2B, 0x34, 0x3B)
BASE = (0x56, 0x65, 0x6F)
LIGHT = (0x8F, 0xA3, 0xB0)
HI = (0xD4, 0xE0, 0xE8)


def hexc(c):
    return "#%02X%02X%02X" % tuple(int(max(0, min(255, round(v)))) for v in c)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def ramp(t):
    """0 = shadow .. 1 = highlight."""
    if t < 0.5:
        return mix(SHADOW, BASE, t * 2)
    return mix(BASE, LIGHT, (t - 0.5) * 2) if t < 0.85 else mix(LIGHT, HI, (t - 0.85) / 0.15)


def pt(r, a):
    return (C + r * math.cos(a), C + r * math.sin(a))


def sector(r0, r1, a0, a1, chamfer=0.0, steps=8):
    """Annular sector polygon, outer arc then inner arc, optional corner chamfer (in texels along radius)."""
    pts = []
    ch = chamfer
    ao = ch / r1
    ai = ch / r0
    for i in range(steps + 1):
        a = a0 + ao + (a1 - a0 - 2 * ao) * i / steps
        pts.append(pt(r1, a))
    pts.append(pt(r1 - ch, a1))
    pts.append(pt(r0 + ch, a1))
    for i in range(steps + 1):
        a = a1 - ai - (a1 - a0 - 2 * ai) * i / steps
        pts.append(pt(r0, a))
    pts.append(pt(r0 + ch, a0))
    pts.append(pt(r1 - ch, a0))
    return pts


def poly(pts, fill, extra=""):
    d = " ".join("%.1f,%.1f" % p for p in pts)
    return '<polygon points="%s" fill="%s" %s/>' % (d, fill, extra)


def line(p, q, stroke, w, op=1.0):
    return '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%.1f" stroke-linecap="round" stroke-opacity="%.2f"/>' % (
        p[0], p[1], q[0], q[1], stroke, w, op)


def arc_poly(r, a0, a1, n=10):
    return [pt(r, a0 + (a1 - a0) * i / n) for i in range(n + 1)]


def polyline(pts, stroke, w, op=1.0):
    d = " ".join("%.1f,%.1f" % p for p in pts)
    return '<polyline points="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linecap="round" stroke-linejoin="round" stroke-opacity="%.2f"/>' % (d, stroke, w, op)


def light_t(a):
    # light from the upper left (screen angle -135 deg)
    return 0.5 + 0.5 * math.cos(a - math.radians(-135))


def plate(g, glow, ang, r0, r1, half, chamfer, rivets=2, accent="#FFB000"):
    a0, a1 = ang - half, ang + half
    lt = light_t(ang)
    base = ramp(0.06 + 0.34 * lt)
    # drop shadow toward lower right
    sh = [(x + 5, y + 7) for x, y in sector(r0, r1, a0, a1, chamfer)]
    g.append(poly(sh, "#07090C", 'fill-opacity="0.55"'))
    g.append(poly(sector(r0, r1, a0, a1, chamfer), hexc(ramp(0.0 + 0.12 * lt)), 'stroke="#07090C" stroke-width="4"'))
    inset = 5.0
    ai = inset / r1
    g.append(poly(sector(r0 + inset, r1 - inset, a0 + ai, a1 - ai, chamfer * 0.6), hexc(base)))
    # lit upper bevel: inner-inset sector lighter on the side facing the light
    g.append(poly(sector(r0 + 11, r1 - 11, a0 + 2.2 * ai, a1 - 2.2 * ai, chamfer * 0.3), hexc(ramp(0.2 + 0.42 * lt)), 'fill-opacity="0.9"'))
    # panel seam across the plate
    g.append(line(pt(r0 + 5, ang), pt(r1 - 5, ang), "#12181D", 2.5, 0.8))
    # highlight edge on the outer arc
    g.append(polyline(arc_poly(r1 - 3.5, a0 + 2.5 * ai, a1 - 2.5 * ai), hexc(ramp(0.55 + 0.4 * lt)), 2.5, 0.9))
    g.append(polyline(arc_poly(r0 + 14, a0 + 6 * ai, a1 - 6 * ai), "#07090C", 2.5, 0.8))
    # rivets
    for k in range(rivets):
        s = -1 if k == 0 else 1
        p = pt((r0 + r1) / 2, ang + s * half * 0.55)
        g.append('<circle cx="%.1f" cy="%.1f" r="3.2" fill="%s"/>' % (p[0], p[1], hexc(ramp(0.2))))
        g.append('<circle cx="%.1f" cy="%.1f" r="1.6" fill="%s" fill-opacity="0.9"/>' % (p[0] - 0.6, p[1] - 0.6, hexc(ramp(0.8))))
    # glow: amber trim along the outer edge + teal diode at the seam
    glow.append(polyline(arc_poly(r1 - 22, a0 + 5 * ai, a1 - 5 * ai), accent, 5.0, 0.95))
    glow.append(polyline(arc_poly(r1 - 22, a0 + 5 * ai, a1 - 5 * ai), "#FFF1C9", 1.8, 0.95))


def cell(index, build):
    body, glow = [], []
    build(body, glow)
    ox = index * 640
    return (
        '<g id="slot.tier_%d" transform="translate(%d,0)">%s</g>' % (index + 1, ox, "".join(body)),
        '<g id="slot.tier_%d_glow" transform="translate(%d,0)">%s</g>' % (index + 1, ox, "".join(glow)),
    )


def tier1(body, glow):
    for k in range(4):
        plate(body, glow, math.radians(45 + 90 * k), 214, 298, math.radians(25), 11)


def tier2(body, glow):
    # cell 2 holds ONLY the added layer: four bridge plates; the view draws cells 1 and 2 together
    for k in range(4):
        plate(body, glow, math.radians(90 * k), 214, 282, math.radians(16), 9, rivets=1)
    # lower retaining rings under the tier-1 plates
    for k in range(4):
        a = math.radians(45 + 90 * k)
        body.append(polyline(arc_poly(300, a - math.radians(24), a + math.radians(24)), "#12181D", 5.0, 0.9))
        body.append(polyline(arc_poly(300, a - math.radians(24), a + math.radians(24)), hexc(ramp(0.45)), 2.5, 1.0))


def tier3(body, glow):
    # heavy outer lip: 16 segments, plus four fortress caps on the tier-1 plates
    for k in range(16):
        a = math.radians(22.5 * k + 11.25)
        lt = light_t(a)
        pts = sector(302, 320, a - math.radians(9.2), a + math.radians(9.2), 5.0, 4)
        body.append(poly(pts, "#07090C", 'fill-opacity="0.5" transform="translate(4,6)"'))
        body.append(poly(pts, hexc(ramp(0.12 + 0.3 * lt)), 'stroke="#12181D" stroke-width="2.5"'))
        body.append(poly(sector(305, 317, a - math.radians(7.4), a + math.radians(7.4), 3.0, 4), hexc(ramp(0.35 + 0.5 * lt)), 'fill-opacity="0.9"'))
        if k % 2 == 0:
            glow.append(polyline(arc_poly(311, a - math.radians(5.5), a + math.radians(5.5), 4), "#2EE6D6", 3.0, 0.8))
    for k in range(4):
        plate(body, glow, math.radians(45 + 90 * k), 298, 316, math.radians(15), 5, rivets=0, accent="#FFD27A")


def main():
    bodies, glows = [], []
    for i, fn in enumerate((tier1, tier2, tier3)):
        b, g = cell(i, fn)
        bodies.append(b)
        glows.append(g)
    head = '<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="640" viewBox="0 0 1920 640">\n'
    with open(os.path.join(HERE, "ut_plates.svg"), "w") as f:
        f.write(head + "<!-- mockup: Cinder plate rings, tiers 1-3, cells 640x640 centered on Cinder -->\n" + "\n".join(bodies) + "\n</svg>\n")
    with open(os.path.join(HERE, "ut_plates_glow.svg"), "w") as f:
        f.write(head + "<!-- mockup: additive trim and diode lights of the plate rings -->\n" + "\n".join(glows) + "\n</svg>\n")


main()
