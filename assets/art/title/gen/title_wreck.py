"""Wreckage layer of the title (hulks_mid.svg, M3-26): broken machines and mech husks, pylons, gears, torn plating,
scrap piles and hanging cables, in three depth ranks. Authored 2160 x 580, ground near y 470. Deterministic."""
import math
import random
import re

from title_art_common import PAL, circle, f, gear, line, lin, poly, rad, rect, wrap, cable, pts

W, H = 2160, 580
GROUND = 470.0


def tf(x, y, s=1.0, flip=1, rot=0.0):
    return 'transform="translate(%s,%s) rotate(%s) scale(%s,%s)"' % (f(x), f(y), f(rot), f(s * flip), f(s))


class Tone:
    def __init__(self, body, plate, edge, rim, rim_op):
        self.body, self.plate, self.edge, self.rim, self.rim_op = body, plate, edge, rim, rim_op


BACK = Tone("url(#g_far)", "#222B38", "#2B343B", PAL["bronze"], 0.45)
MIDT = Tone("url(#g_mid)", "#1B222B", "#2B343B", PAL["orange"], 0.5)
FRONT = Tone("url(#g_near)", "#12171D", "#1B222B", PAL["orange"], 0.4)


def jag(rng, x0, x1, y_base, h, step=26, rough=0.45):
    """Jagged top edge from x0 to x1 (list of points, left to right), heights up to h above y_base."""
    out = []
    x = x0
    while x < x1:
        out.append((x, y_base - h * (0.35 + rng.random() * rough)))
        x += step * (0.6 + rng.random() * 0.8)
    out.append((x1, y_base - h * 0.3))
    return out


def plate(x, y, w, h, rot, t, rng, torn=True):
    """Torn armour plate: a quad with a sawtooth torn side, rotated about its centre."""
    hw, hh = w / 2, h / 2
    p = [(-hw, -hh), (hw, -hh * (0.8 + 0.2 * rng.random()))]
    if torn:
        n = 5
        for i in range(n):
            xx = hw - (i + 0.5) * (w * 0.1)
            p.append((hw, hh * (-0.2 + 0.25 * i)))
            p.append((hw - w * 0.06 * (1 + rng.random()), hh * (-0.1 + 0.25 * i + 0.1)))
        p.append((hw, hh))
    else:
        p.append((hw, hh))
    p += [(-hw * 0.9, hh), (-hw, hh * 0.2)]
    s = '<g %s>' % tf(x, y, 1.0, 1, rot)
    s += poly(p, t.plate)
    s += line([(-hw, -hh), (hw, -hh * 0.9)], t.rim, 2.5, t.rim_op)
    s += line([(-hw * 0.7, hh * 0.1), (hw * 0.4, 0)], t.edge, 2, 0.8)
    s += "</g>"
    return s


def pylon(x, base, h, lean, t, rng, cables=True):
    top_x = x + lean
    w0, w1 = 22, 9
    left = [(x - w0, base), (top_x - w1, base - h)]
    right = [(x + w0, base), (top_x + w1, base - h)]
    s = poly([left[0], left[1], right[1], right[0]], "none", 'stroke="%s" stroke-width="4" stroke-linejoin="round"' % t.edge)
    n = 7
    zz = []
    for i in range(n + 1):
        u = i / n
        a = (x - w0 + (top_x - w1 - x + w0) * u, base - h * u)
        b = (x + w0 + (top_x + w1 - x - w0) * u, base - h * u)
        zz.append(a if i % 2 == 0 else b)
    s += line(zz, t.edge, 3, 0.95)
    s += poly([(x - w0 - 4, base), (x + w0 + 4, base), (x + w0 - 4, base - 18), (x - w0 + 4, base - 18)], t.plate)
    # cross arm, snapped on one side, with a hanging cable and a dim beacon
    ay = base - h * 0.78
    ax = x + lean * 0.78
    s += poly([(ax - 70, ay), (ax + 8, ay - 10), (ax + 40, ay - 4), (ax + 62, ay + 18), (ax + 30, ay + 8), (ax - 70, ay + 14)], t.plate)
    s += line([(ax - 70, ay), (ax + 8, ay - 10), (ax + 40, ay - 4)], t.rim, 2.5, t.rim_op)
    if cables:
        s += cable((ax - 68, ay + 10), (ax - 56, ay + h * 0.32), 14, t.edge, 3, 0.95)
        s += cable((ax + 58, ay + 16), (ax + 30, ay + h * 0.22), 10, t.edge, 3, 0.9)
    s += circle(ax - 70, ay - 6, 5, PAL["bronze"], 'opacity="0.9"')
    # snapped top
    s += poly([(top_x - w1, base - h), (top_x - 2, base - h - 26), (top_x + 4, base - h - 8), (top_x + w1, base - h)], t.plate)
    return s


def husk_standing(x, gy, sc, flip, t, rng, vent=False):
    """Broken biped husk: one intact leg, one stump, torso with a torn shoulder, no head, dangling arm and cables."""
    s = '<g %s>' % tf(x, gy, sc, flip)
    # legs
    s += poly([(-44, -150), (-12, -150), (-14, -86), (-34, -78), (-60, -90)], t.body)          # left thigh
    s += poly([(-60, -90), (-34, -78), (-30, -8), (-20, 0), (-70, 0), (-62, -12)], t.plate)    # left shin and foot
    s += poly([(-76, 0), (-14, 0), (-8, -9), (-68, -9)], t.edge)
    s += line([(-52, -84), (-48, -12)], t.edge, 3, 0.9)
    s += poly([(10, -150), (40, -150), (46, -100), (30, -66), (20, -96)], t.body)              # right thigh, snapped
    s += cable((24, -70), (22, -4), 18, t.edge, 3, 1.0)
    s += cable((34, -72), (52, -8), 14, t.edge, 2.5, 0.95)
    s += circle(30, -66, 4, PAL["bronze"], 'opacity="0.9"')
    # pelvis and torso (leaning)
    s += poly([(-52, -150), (50, -150), (62, -176), (-62, -176)], t.plate)
    s += '<g %s>' % tf(0, -176, 1.0, 1, -9)
    s += poly([(-76, 0), (74, 0), (86, -30), (80, -96), (58, -124), (-60, -124), (-84, -90), (-86, -26)], t.body)
    s += poly([(-60, -20), (58, -20), (62, -86), (-58, -86)], t.plate)
    s += rect(-44, -70, 88, 14, "#07090C", 'opacity="0.85"')
    s += rect(-40, -66, 42, 6, PAL["bronze"], 'opacity="0.75"')
    s += poly([(-58, -124), (-30, -146), (-14, -128)], t.plate)                       # neck stump
    s += poly([(58, -124), (70, -134), (84, -112), (96, -92), (80, -96)], t.edge)      # torn shoulder
    s += line([(-84, -90), (-60, -124), (58, -124)], t.rim, 3, t.rim_op)
    if vent:
        s += circle(-20, -48, 12, "url(#g_vent)")
    s += "</g>"
    # left arm hanging
    s += poly([(-106, -166), (-84, -170), (-86, -112), (-112, -106)], t.plate)
    s += poly([(-112, -106), (-86, -112), (-84, -50), (-100, -44)], t.body)
    s += cable((-98, -46), (-92, 2), 20, t.edge, 3.5, 1.0)
    s += cable((-90, -108), (-70, -20), 10, t.edge, 2.5, 0.9)
    s += "</g>"
    return s


def husk_fallen(x, gy, sc, flip, t, rng, vent=False):
    """Fallen walker: big torso lying on its side, one bird-like leg bent upward, hip cables, a gear half buried."""
    s = '<g %s>' % tf(x, gy, sc, flip)
    s += poly([(-130, 0), (-146, -52), (-98, -96), (40, -120), (120, -92), (150, -40), (140, 0)], t.body)
    s += poly([(-96, -14), (-84, -72), (30, -92), (100, -70), (112, -20)], t.plate)
    s += poly([(-60, -44), (60, -54), (64, -66), (-60, -56)], "#07090C", 'opacity="0.85"')
    s += rect(-48, -48, 38, 5, PAL["bronze"], 'opacity="0.7"')
    s += line([(-98, -96), (40, -120), (120, -92)], t.rim, 3, t.rim_op)
    # raised leg: thigh up and out, knee, shin angled back, claw foot
    s += poly([(80, -100), (112, -96), (160, -176), (140, -194)], t.body)
    s += poly([(140, -194), (160, -176), (150, -248), (126, -250)], t.plate)
    s += poly([(126, -250), (150, -248), (176, -270), (134, -268)], t.edge)
    s += line([(140, -190), (140, -250)], t.edge, 3, 0.9)
    s += circle(150, -186, 12, t.plate)
    s += circle(150, -186, 5, t.edge)
    # arm stub and cables
    s += poly([(-146, -52), (-186, -40), (-200, -4), (-158, -2)], t.edge)
    s += cable((-188, -34), (-180, 0), 24, t.edge, 3.5, 1.0)
    s += cable((-60, -100), (-110, -4), 30, t.edge, 3, 0.9)
    if vent:
        s += circle(70, -64, 12, "url(#g_vent)")
    s += "</g>"
    return s


def crawler(x, gy, sc, flip, t, rng):
    """Tracked turret wreck: half-sunk dome, snapped gun barrel, road wheels, torn tread."""
    s = '<g %s>' % tf(x, gy, sc, flip)
    s += poly([(-130, 0), (-134, -34), (130, -34), (136, 0)], t.edge)
    for wx in (-100, -50, 0, 50, 100):
        s += circle(wx, -18, 17, t.plate)
        s += circle(wx, -18, 6, t.edge)
    s += line([(-130, -34), (-60, -38), (20, -30), (90, -40), (134, -34)], t.plate, 6, 1.0)
    s += poly([(-96, -34), (-86, -86), (-30, -118), (40, -112), (92, -78), (100, -34)], t.body)
    s += poly([(-60, -56), (-24, -92), (30, -90), (60, -60)], t.plate)
    s += line([(-86, -86), (-30, -118), (40, -112), (92, -78)], t.rim, 3, t.rim_op)
    s += poly([(30, -104), (112, -150), (122, -138), (46, -92)], t.plate)       # barrel, snapped
    s += poly([(112, -150), (132, -168), (134, -156), (122, -138)], t.edge)
    s += cable((124, -142), (140, -34), 14, t.edge, 3, 0.95)
    s += "</g>"
    return s


def gantry(x, gy, sc, flip, t, rng):
    """Collapsed crane gantry: leaning lattice boom over a pile, hook cable hanging."""
    s = '<g %s>' % tf(x, gy, sc, flip)
    s += poly([(-30, 0), (30, 0), (24, -26), (-24, -26)], t.plate)
    boom_a, boom_b = (-10, -26), (230, -230)
    s += line([boom_a, boom_b], t.edge, 7, 1.0)
    s += line([(8, -26), (246, -222)], t.edge, 5, 1.0)
    zz = []
    for i in range(9):
        u = i / 8
        a = (-10 + 240 * u, -26 - 204 * u)
        b = (8 + 238 * u, -26 - 196 * u)
        zz += [a, b]
    s += line(zz, t.edge, 3, 0.95)
    s += line([(-10, -26), (230, -230)], t.rim, 2.5, t.rim_op)
    s += poly([(230, -232), (250, -224), (246, -200), (222, -210)], t.plate)
    s += cable((236, -214), (214, -60), 6, t.edge, 3, 1.0)
    s += poly([(206, -64), (222, -64), (224, -48), (212, -38), (204, -50)], t.plate)
    s += line([(40, -50), (60, -150)], t.edge, 4, 0.9)       # stay cable
    s += "</g>"
    return s


def tank(x, gy, sc, flip, t, rng):
    """Burst cooling tank on legs: ellipse-ish drum, a rip showing the dark inside, ladder."""
    s = '<g %s>' % tf(x, gy, sc, flip)
    s += poly([(-34, 0), (-26, -80), (-16, -80), (-20, 0)], t.edge)
    s += poly([(34, 0), (26, -80), (16, -80), (20, 0)], t.edge)
    s += poly([(-70, -78), (-72, -150), (-52, -190), (0, -204), (52, -190), (72, -150), (70, -78)], t.body)
    s += poly([(-40, -150), (-6, -176), (30, -166), (14, -120), (-30, -108)], "#07090C", 'opacity="0.9"')
    s += line([(-72, -150), (-52, -190), (0, -204), (52, -190), (72, -150)], t.rim, 3, t.rim_op)
    s += line([(-70, -120), (70, -122)], t.edge, 3, 0.9)
    s += line([(-70, -98), (70, -100)], t.edge, 3, 0.9)
    s += line([(46, -80), (62, -4)], t.edge, 3, 0.9)
    s += cable((-60, -150), (-62, -30), 16, t.edge, 3, 1.0)
    s += "</g>"
    return s


def scrap_pile(rng, x0, x1, base, h, t, plates=4, gears=1):
    """Pile of scrap between x0 and x1: jagged mound, torn plates leaning on it, spikes, optional half-buried gear."""
    if plates >= 3:
        plates -= 1
    top = jag(rng, x0, x1, base, h)
    s = poly([(x0, base + 30)] + [(x0, base - h * 0.2)] + top + [(x1, base + 30)], t.body)
    for i in range(plates):
        px = x0 + (x1 - x0) * (0.12 + 0.76 * rng.random())
        py = base - h * (0.3 + 0.5 * rng.random())
        s += plate(px, py, 46 + rng.random() * 70, 18 + rng.random() * 26, rng.uniform(-48, 48), t, rng, rng.random() < 0.7)
    for i in range(int(plates * 0.5)):
        px = x0 + (x1 - x0) * rng.random()
        py = base - h * (0.2 + 0.4 * rng.random())
        a = rng.uniform(-1.2, 1.2)
        ln = 30 + rng.random() * 46
        s += line([(px, py), (px + math.sin(a) * ln, py - math.cos(a) * ln)], t.edge, 3 + rng.random() * 2.5, 0.95)
    for i in range(gears):
        gx = x0 + (x1 - x0) * (0.25 + 0.5 * rng.random())
        gy = base - h * 0.35
        r = 26 + rng.random() * 26
        s += gear(gx, gy, r, 8, t.plate, t.edge, t.edge, rng.random() * 3, 0.22 if rng.random() < 0.5 else 0.0)
    s += line(top, t.rim, 2.5, t.rim_op)
    return s


def build():
    rng = random.Random(2611)
    defs = "\n".join([
        lin("g_far", [(0, "#222B38", None), (1, "#12171D", None)]),
        lin("g_mid", [(0, "#1B222B", None), (1, "#0D1117", None)]),
        lin("g_near", [(0, "#12171D", None), (1, "#07090C", None)]),
        lin("g_haze", [(0, "#3A2A22", 0.0), (0.5, "#5A4034", 0.22), (1, "#5A4034", 0.5)], 0, 0, 0, H, True),
        lin("g_haze_far", [(0, "#3A2A22", 0.0), (1, "#5A4034", 0.6)], 0, 0, 0, H, True),
        rad("g_vent", [(0, "#FF5A3C", 0.9), (1, "#7A1E30", 0)]),
    ])
    b = []
    # ---- rank 1: far wrecks (small, hazy, behind everything)
    far = []
    far.append(pylon(250, 470, 330, -26, BACK, rng))
    far.append(pylon(1500, 470, 300, 24, BACK, rng))
    far.append(pylon(1980, 470, 340, -30, BACK, rng))
    far.append(tank(1730, 470, 0.9, -1, BACK, rng))
    far.append(gantry(870, 470, 0.7, 1, BACK, rng))
    far.append(gantry(1290, 470, 0.75, -1, BACK, rng))
    far.append(husk_standing(1040, 470, 0.5, 1, BACK, rng))
    far.append(husk_standing(1190, 470, 0.46, -1, BACK, rng))
    far.append(husk_fallen(650, 470, 0.5, -1, BACK, rng))
    far.append(husk_fallen(1840, 470, 0.5, 1, BACK, rng))
    far.append(scrap_pile(rng, 0, 2160, 470, 70, BACK, 0, 0))
    b.extend(far)
    b.append(poly([(0, 0), (W, 0), (W, H), (0, H)], "url(#g_haze_far)", 'opacity="0.55"'))
    # ---- rank 2: mid wrecks
    mid = []
    mid.append(scrap_pile(rng, -30, 420, 490, 120, MIDT, 5, 1))
    mid.append(husk_standing(250, 490, 1.0, 1, MIDT, rng, True))
    mid.append(tank(560, 492, 1.05, 1, MIDT, rng))
    mid.append(husk_fallen(700, 494, 1.2, 1, MIDT, rng, False))
    mid.append(scrap_pile(rng, 800, 940, 494, 80, MIDT, 4, 0))
    mid.append(crawler(850, 496, 0.9, -1, MIDT, rng))
    mid.append(scrap_pile(rng, 1180, 1330, 496, 76, MIDT, 4, 0))
    mid.append(gantry(1230, 496, 0.95, -1, MIDT, rng))
    mid.append(crawler(1330, 496, 0.9, 1, MIDT, rng))
    mid.append(husk_standing(1500, 494, 1.3, -1, MIDT, rng, True))
    mid.append(husk_fallen(1790, 494, 1.1, -1, MIDT, rng, True))
    mid.append(husk_standing(1960, 492, 1.0, -1, MIDT, rng))
    mid.append(scrap_pile(rng, 1560, 2190, 494, 140, MIDT, 6, 1))
    b.extend(mid)
    b.append(poly([(0, 220), (W, 220), (W, H), (0, H)], "url(#g_haze)", 'opacity="0.7"'))
    # ---- rank 3: front scrap, cables and gears (dark, big)
    fr = []
    fr.append(scrap_pile(rng, -20, 330, 540, 110, FRONT, 4, 1))
    fr.append(scrap_pile(rng, 520, 760, 548, 70, FRONT, 3, 1))
    fr.append(scrap_pile(rng, 1420, 1650, 546, 74, FRONT, 3, 1))
    fr.append(scrap_pile(rng, 1860, 2170, 540, 120, FRONT, 4, 1))
    for sx, sy, ex, ey, sg in ((120, 250, 250, 520, 60), (1790, 230, 1940, 520, 70), (560, 330, 600, 520, 40), (1570, 340, 1520, 520, 40)):
        fr.append(cable((sx, sy), (ex, ey), sg, FRONT.edge, 4, 1.0))
    b.extend(fr)
    b.append(poly([(0, 430), (0, 520), (60, 505), (150, 515)] + [(x, 500 + 20 * math.sin(x / 90.0) + rng.random() * 14) for x in range(200, 2160, 60)] + [(W, 512), (W, H), (0, H)], "#0D1117"))
    groups = []
    cur = []
    n = 0
    for piece in b:
        c = len(re.findall(r"<(?:polygon|polyline|circle|rect|ellipse|path|line)[ ]", piece))
        if n + c > 76 and cur:
            groups.append(cur)
            cur, n = [], 0
        cur.append(piece)
        n += c
    groups.append(cur)
    names = ["slot.hulks_mid"] + ["slot.hulks_mid_%d" % i for i in range(1, len(groups))]
    body = chr(10).join('<g id="%s">%s</g>' % (nm, "".join(g)) for nm, g in zip(names, groups))
    return wrap(W, H, defs, body, width=1620, height=435)


if __name__ == "__main__":
    import sys
    sys.stdout.write(build())
