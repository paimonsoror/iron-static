"""Title silhouettes of the three M3 Cinder frames (design 11 section 1.5) as part lists, plus their glow sheets.

Authored in a 600 x 840 box, feet at (300, 806). Sheets rasterize at 70% (420 x 588, shown 1:1) and the glow sheets at
half the box (the glow is soft; shown at 2x). Part kinds: ("p", points, tone), ("l", points, color, width, opacity),
("c", cx, cy, r, tone). Tones: g (darkest), d (body), p (plate), bz (bronze strip), wh (white-hot strip).
"""
from title_art_common import PAL, circle, lin, line, mirror, poly, rad

CX = 300.0


def S(side, pl):
    """Points given as (dx, y) offsets from the centre line on one side; side -1 mirrors to the left."""
    return [(CX + side * dx, y) for dx, y in pl]


def both(pl, tone):
    right = S(1, pl)
    left = S(-1, pl)
    return [("p", left, tone), ("p", right, tone)]


def hexagon(cx, cy, r):
    import math
    return [(cx + r * math.cos(math.radians(60 * i)), cy + r * math.sin(math.radians(60 * i))) for i in range(6)]


# ---------------------------------------------------------------- VANGUARD
def vanguard():
    P = []
    # legs
    P += both([(18, 520), (104, 516), (122, 600), (98, 656), (30, 656), (16, 590)], "g")
    P += both([(34, 656), (98, 656), (108, 740), (130, 782), (132, 806), (26, 806), (38, 766)], "d")
    P += both([(34, 636), (100, 636), (112, 668), (66, 694), (22, 668)], "p")
    P += both([(18, 782), (134, 792), (138, 806), (12, 806)], "p")
    P.append(("l", S(1, [(44, 700), (50, 770)]), PAL["g4"], 3, 1.0))
    P.append(("l", S(-1, [(44, 700), (50, 770)]), PAL["g4"], 3, 1.0))
    # pelvis
    P.append(("p", S(1, [(-96, 468), (96, 468), (116, 526), (46, 568), (-46, 568), (-116, 526)]), "d"))
    P.append(("p", S(1, [(-54, 534), (54, 534), (40, 562), (-40, 562)]), "p"))
    # arms: viewer's right arm hangs with a bracer; viewer's left arm is the emitter cannon (no fist)
    P += [("p", S(1, [(168, 320), (250, 316), (250, 420), (228, 472), (180, 468), (162, 390)]), "d")]
    P += [("p", S(1, [(180, 468), (228, 472), (240, 560), (224, 626), (190, 624), (178, 556)]), "g")]
    P += [("p", S(1, [(186, 498), (236, 502), (240, 556), (184, 552)]), "p")]
    P += [("p", S(1, [(190, 624), (224, 626), (220, 664), (204, 678), (188, 662)]), "d")]
    P += [("p", S(-1, [(168, 320), (250, 316), (250, 420), (228, 472), (180, 468), (162, 390)]), "d")]
    P += [("p", S(-1, [(180, 468), (232, 472), (246, 556), (236, 628), (188, 628), (178, 556)]), "g")]
    P += [("p", S(-1, [(186, 498), (240, 502), (244, 556), (184, 552)]), "p")]
    P += [("p", S(-1, [(192, 628), (236, 628), (234, 718), (218, 748), (202, 748), (192, 718)]), "p")]
    P.append(("l", S(-1, [(192, 628), (192, 718), (202, 748), (218, 748), (234, 718), (236, 628)]), PAL["orange"], 3, 0.85))
    P += [("p", S(-1, [(200, 740), (226, 740), (216, 760)]), "p")]
    # chest and core housing
    P.append(("p", S(1, [(-150, 262), (150, 262), (176, 336), (124, 470), (-124, 470), (-176, 336)]), "d"))
    P.append(("p", S(1, [(-122, 296), (122, 296), (104, 430), (-104, 430)]), "p"))
    P.append(("p", hexagon(CX, 366, 58), "g"))
    P.append(("l", hexagon(CX, 366, 58) + [hexagon(CX, 366, 58)[0]], PAL["g4"], 4, 1.0))
    P.append(("l", S(1, [(-100, 322), (-92, 424)]), PAL["g4"], 3, 1.0))
    P.append(("l", S(1, [(100, 322), (92, 424)]), PAL["g4"], 3, 1.0))
    # head
    P.append(("p", S(1, [(-34, 266), (34, 266), (40, 284), (-40, 284)]), "g"))
    P.append(("p", S(1, [(-54, 198), (54, 196), (68, 230), (66, 268), (-66, 268), (-68, 228)]), "d"))
    P.append(("p", S(1, [(-54, 198), (54, 196), (62, 216), (-62, 218)]), "p"))
    P.append(("p", S(1, [(-48, 236), (48, 236), (52, 252), (-52, 252)]), "g"))
    P.append(("p", S(1, [(66, 214), (92, 158), (98, 162), (86, 228)]), "d"))
    # pauldrons: right = plain heavy plate with a bronze stripe, left = low sensor pod
    P.append(("p", S(1, [(120, 246), (236, 232), (262, 290), (246, 336), (128, 326)]), "d"))
    P.append(("p", S(1, [(128, 248), (232, 234), (250, 268), (136, 284)]), "p"))
    P.append(("p", S(1, [(148, 300), (238, 296), (242, 308), (150, 312)]), "bz"))
    P.append(("p", S(-1, [(120, 246), (236, 232), (262, 290), (246, 336), (128, 326)]), "d"))
    P.append(("p", S(-1, [(128, 248), (232, 234), (250, 268), (136, 284)]), "p"))
    P.append(("p", S(-1, [(150, 222), (232, 214), (244, 236), (140, 240)]), "g"))
    # amber rim light on the upward edges
    O = PAL["orange"]
    P.append(("l", S(1, [(-54, 198), (54, 196), (68, 230)]), O, 3, 0.85))
    P.append(("l", S(1, [(120, 246), (236, 232), (262, 290)]), O, 3, 0.85))
    P.append(("l", S(-1, [(120, 246), (236, 232), (262, 290)]), O, 3, 0.85))
    P.append(("l", S(1, [(-150, 262), (150, 262), (176, 336)]), O, 3, 0.7))
    P.append(("l", S(1, [(92, 158), (66, 214)]), O, 3, 0.85))
    for sd in (1, -1):
        P.append(("l", S(sd, [(250, 316), (250, 420), (228, 472)]), PAL["bronze"], 3, 0.85))
        P.append(("l", S(sd, [(240, 560), (224, 626)]), PAL["bronze"], 3, 0.85))
        P.append(("l", S(sd, [(104, 516), (122, 600), (98, 656)]), PAL["bronze"], 3, 0.8))
    glow = dict(
        core=(150.0, 183.0, 25.0, "amber"), visor=(126.0, 119.0, 48.0, 5.0),
        lenses=[(CX - 214, 664), (CX - 214, 690), (CX - 214, 716)], lens_r=9.0, back=(150, 200, 138, 182),
        extra=[],
    )
    return P, glow


# ---------------------------------------------------------------- BULWARK
def bulwark():
    P = []
    # exhaust stacks behind the shoulders
    for sd in (1, -1):
        P.append(("p", S(sd, [(96, 196), (136, 196), (140, 300), (92, 300)]), "g"))
        P.append(("p", S(sd, [(92, 196), (140, 196), (140, 206), (92, 206)]), "p"))
        P.append(("l", S(sd, [(92, 196), (140, 196)]), PAL["bronze"], 4, 0.9))
    # legs: short, thick
    P += both([(20, 520), (136, 516), (156, 606), (132, 660), (34, 660), (18, 590)], "g")
    P += both([(36, 660), (134, 660), (146, 742), (172, 784), (174, 806), (26, 806), (36, 768)], "d")
    P += both([(24, 636), (150, 636), (166, 680), (90, 712), (16, 680)], "p")
    P += both([(12, 780), (178, 792), (184, 806), (6, 806)], "p")
    # pelvis
    P.append(("p", S(1, [(-128, 470), (128, 470), (154, 534), (60, 576), (-60, 576), (-154, 534)]), "d"))
    P.append(("p", S(1, [(-70, 540), (70, 540), (52, 570), (-52, 570)]), "p"))
    # arms: viewer's right = heavy gauntlet, viewer's left = slab shield on the forearm
    P += [("p", S(1, [(160, 372), (258, 372), (270, 466), (244, 518), (172, 514), (156, 440)]), "d")]
    P += [("p", S(1, [(172, 514), (248, 518), (270, 618), (250, 700), (188, 700), (166, 610)]), "g")]
    P += [("p", S(1, [(176, 546), (260, 552), (262, 610), (174, 604)]), "p")]
    P += [("p", S(1, [(188, 700), (250, 700), (246, 744), (222, 762), (192, 744)]), "d")]
    P += [("p", S(-1, [(160, 372), (258, 372), (270, 466), (244, 518), (172, 514), (156, 440)]), "d")]
    P += [("p", S(-1, [(170, 432), (286, 414), (290, 640), (252, 730), (186, 706), (164, 560)]), "d")]
    P += [("p", S(-1, [(184, 452), (276, 438), (278, 628), (246, 704), (196, 684), (178, 560)]), "p")]
    # chest
    P.append(("p", S(1, [(-176, 280), (176, 280), (206, 352), (150, 476), (-150, 476), (-206, 352)]), "d"))
    P.append(("p", S(1, [(-134, 304), (134, 304), (116, 456), (-116, 456)]), "p"))
    P.append(("p", S(1, [(-196, 352), (196, 352), (184, 376), (-184, 376)]), "bz"))
    P.append(("p", hexagon(CX, 400, 62), "g"))
    P.append(("l", hexagon(CX, 400, 62) + [hexagon(CX, 400, 62)[0]], PAL["bronze2"], 5, 1.0))
    # head
    P.append(("p", S(1, [(-90, 298), (90, 298), (122, 320), (-122, 320)]), "d"))
    P.append(("p", S(1, [(-64, 232), (64, 230), (80, 266), (78, 300), (-78, 300), (-80, 264)]), "d"))
    P.append(("p", S(1, [(-64, 232), (64, 230), (74, 252), (-74, 254)]), "p"))
    P.append(("p", S(1, [(-70, 266), (70, 266), (74, 284), (-74, 284)]), "g"))
    P.append(("p", S(1, [(-14, 212), (14, 212), (20, 232), (-20, 232)]), "p"))
    # pauldrons: two stacked plates per side with bronze trim
    for sd in (1, -1):
        P.append(("p", S(sd, [(128, 258), (252, 238), (290, 316), (276, 384), (136, 376)]), "d"))
        P.append(("p", S(sd, [(136, 242), (244, 226), (278, 276), (146, 292)]), "p"))
        P.append(("p", S(sd, [(150, 306), (276, 312), (268, 358), (152, 360)]), "g"))
        P.append(("p", S(sd, [(136, 242), (244, 226), (248, 236), (140, 254)]), "bz"))
        P.append(("l", S(sd, [(128, 258), (252, 238), (290, 316)]), PAL["orange"], 3, 0.8))
        P.append(("l", S(sd, [(150, 306), (276, 312)]), "#D6B36A", 3, 0.7))
        P.append(("l", S(sd, [(36, 636), (150, 636), (166, 680)]), "#D6B36A", 3, 0.65))
    P.append(("l", S(-1, [(184, 452), (276, 438), (278, 628), (246, 704)]), "#D6B36A", 4, 0.8))
    for ry in (480, 540, 600):
        P.append(("c", CX - 232, ry, 7, "bz"))
    P.append(("l", S(1, [(-64, 232), (64, 230), (80, 266)]), PAL["orange"], 3, 0.85))
    glow = dict(
        core=(150.0, 200.0, 28.0, "amber"), visor=(118.0, 133.0, 64.0, 6.0),
        lenses=[(CX - 232, 546)], lens_r=11.0, back=(150, 210, 128, 172), extra=[],
    )
    return P, glow


# ---------------------------------------------------------------- STRIKER
def striker():
    P = []
    # twin emitter rails behind the right shoulder
    P.append(("p", [(CX + 70, 244), (CX + 82, 240), (CX + 104, 138), (CX + 96, 136)], "g"))
    P.append(("p", [(CX + 78, 246), (CX + 90, 242), (CX + 120, 148), (CX + 112, 144)], "g"))
    # digitigrade legs: thigh kicks out, shin returns, long toe blade
    for sd in (1, -1):
        P.append(("p", S(sd, [(14, 520), (62, 520), (104, 590), (118, 650), (86, 658), (44, 592)]), "g"))
        P.append(("p", S(sd, [(100, 628), (128, 650), (102, 676)]), "p"))
        P.append(("p", S(sd, [(86, 656), (116, 650), (92, 756), (74, 776), (50, 764), (66, 730)]), "d"))
        P.append(("p", S(sd, [(34, 768), (104, 776), (142, 806), (16, 806)]), "p"))
        P.append(("l", S(sd, [(92, 590), (104, 632)]), "#FFF1C9", 3, 0.9))
        for k in range(3):
            P.append(("l", S(sd, [(34 + k * 12, 536 + k * 18), (52 + k * 12, 530 + k * 18)]), PAL["bronze"], 4, 0.9))
    P.append(("p", S(1, [(-60, 480), (60, 480), (72, 530), (34, 568), (-34, 568), (-72, 530)]), "d"))
    # arms: slim, forearm tapers to a blade; the right shoulder carries the twin emitter
    for sd in (1, -1):
        P.append(("p", S(sd, [(118, 304), (170, 304), (178, 396), (160, 434), (124, 430)]), "d"))
        P.append(("p", S(sd, [(126, 430), (166, 434), (180, 520), (164, 620), (150, 704), (134, 620), (122, 520)]), "g"))
        P.append(("l", S(sd, [(166, 434), (180, 520), (164, 620), (150, 704)]), "#FFF1C9", 3, 0.85))
        P.append(("p", S(sd, [(130, 470), (166, 474), (170, 512), (130, 508)]), "p"))
    # wedge chest with vents
    P.append(("p", S(1, [(-112, 276), (112, 276), (124, 330), (70, 470), (-70, 470), (-124, 330)]), "d"))
    P.append(("p", S(1, [(-84, 300), (84, 300), (54, 440), (-54, 440)]), "p"))
    P.append(("p", hexagon(CX, 350, 42), "g"))
    P.append(("l", hexagon(CX, 350, 42) + [hexagon(CX, 350, 42)[0]], "#FFF1C9", 3, 0.9))
    for sd in (1, -1):
        for k in range(4):
            y = 388 + k * 18
            P.append(("l", S(sd, [(40 - k * 4, y), (82 - k * 7, y - 20)]), PAL["bronze"], 4, 0.95))
    # head: swept visor and one tall fin
    P.append(("p", S(1, [(-26, 272), (26, 272), (32, 290), (-32, 290)]), "g"))
    P.append(("p", S(1, [(-44, 214), (44, 212), (56, 240), (50, 274), (-50, 274), (-56, 238)]), "d"))
    P.append(("p", S(1, [(-44, 214), (44, 212), (52, 230), (-52, 232)]), "p"))
    P.append(("p", S(1, [(-40, 240), (40, 240), (44, 252), (-40, 254)]), "g"))
    P.append(("p", [(CX - 8, 214), (CX + 8, 138), (CX + 18, 214)], "d"))
    # shoulder blades
    for sd in (1, -1):
        P.append(("p", S(sd, [(96, 262), (178, 246), (206, 282), (192, 312), (100, 310)]), "d"))
        P.append(("p", S(sd, [(102, 262), (176, 248), (194, 272), (108, 284)]), "p"))
        P.append(("l", S(sd, [(96, 262), (178, 246), (206, 282)]), "#FFF1C9", 3, 0.9))
    P.append(("l", S(1, [(-44, 214), (44, 212), (56, 240)]), "#FFF1C9", 3, 0.9))
    P.append(("l", [(CX - 8, 214), (CX + 8, 138)], "#FFF1C9", 3, 0.9))
    P.append(("l", [(CX + 70, 244), (CX + 100, 136)], "#FFF1C9", 2, 0.9))
    P.append(("l", [(CX + 78, 246), (CX + 116, 146)], "#FFF1C9", 2, 0.9))
    glow = dict(
        core=(150.0, 175.0, 20.0, "white"), visor=(130.0, 120.0, 40.0, 3.5),
        lenses=[(CX + 100, 132), (CX + 118, 140)], lens_r=8.0, back=(150, 190, 120, 175), extra=[],
    )
    return P, glow


FRAMES = {"vanguard": vanguard, "bulwark": bulwark, "striker": striker}

TONE = {"g": "url(#g_gn)", "d": "url(#g_dark)", "p": "url(#g_plate)", "bz": PAL["bronze"], "wh": PAL["cream"]}


def sil_defs():
    return "\n".join([
        lin("g_dark", [(0, PAL["g1"], None), (1, PAL["ink"], None)]),
        lin("g_plate", [(0, PAL["g2"], None), (1, PAL["g0"], None)]),
        lin("g_gn", [(0, PAL["g0"], None), (1, PAL["void"], None)]),
    ])


def render_parts(parts, style="fill"):
    out = []
    for p in parts:
        k = p[0]
        if k == "p":
            if style == "fill":
                extra = ' fill-opacity="0.9"' if p[2] == "bz" else ""
                out.append(poly(p[1], TONE[p[2]], extra.strip()))
            else:
                out.append('<polygon points="%s" fill="#0B0E13" fill-opacity="0.55" stroke="#56656F" stroke-width="7" stroke-linejoin="round"/>' % pts_s(p[1]))
        elif k == "l":
            if style == "fill":
                out.append(line(p[1], p[2], p[3], p[4]))
        elif k == "c":
            if style == "fill":
                out.append(circle(p[1], p[2], p[3], TONE[p[4]]))
    return "\n".join(out)


def pts_s(points):
    from title_art_common import pts
    return pts(points)


def sil_svg(name):
    parts, _ = FRAMES[name]()
    body = '<g id="slot.sil_%s">\n%s\n</g>' % (name, render_parts(parts))
    from title_art_common import wrap
    return wrap(600, 840, sil_defs(), body, width=420, height=588)


def glow_svg(name):
    from title_art_common import wrap
    _, g = FRAMES[name]()
    defs = "\n".join([
        rad("g_halo", [(0, PAL["amber"], 0.8), (0.2, PAL["amber"], 0.4), (0.6, PAL["orange"], 0.1), (1, PAL["orange"], 0)]),
        rad("g_core", [(0, PAL["white"], None), (0.3, PAL["cream"], None), (0.7, PAL["pale"], None), (1, PAL["amber"], None)]),
        rad("g_corew", [(0, PAL["white"], None), (0.55, PAL["white"], None), (0.85, PAL["cream"], None), (1, PAL["pale"], None)]),
        rad("g_lens", [(0, PAL["cream"], None), (0.5, PAL["amber"], 0.8), (1, PAL["amber"], 0)]),
        rad("g_back", [(0, PAL["orange"], 0.3), (1, PAL["orange"], 0)]),
        rad("g_lensw", [(0, PAL["white"], None), (0.5, PAL["cream"], 0.8), (1, PAL["pale"], 0)]),
    ])
    cx, cy, cr, kind = g["core"]
    out = []
    bx, by, brx, bry = g["back"]
    out.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="url(#g_back)"/>' % (bx, by, brx, bry))
    out.append('<circle cx="%s" cy="%s" r="%s" fill="url(#g_halo)"/>' % (cx, cy, cr * 3.8))
    hx = [(cx + cr * __import__("math").cos(__import__("math").radians(60 * i)), cy + cr * __import__("math").sin(__import__("math").radians(60 * i))) for i in range(6)]
    out.append(poly(hx, "url(#g_corew)" if kind == "white" else "url(#g_core)"))
    out.append(line([(cx + cr * 0.4, cy + cr * 0.87), (cx - cr * 0.4, cy - cr * 0.87)], PAL["amber"], 1.5, 0.8))
    vx, vy, vw, vh = g["visor"]
    out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % (vx, vy, vw, vh, PAL["white"] if kind == "white" else PAL["pale"]))
    out.append('<ellipse cx="%s" cy="%s" rx="%s" ry="10" fill="url(#g_lens)" opacity="0.5"/>' % (vx + vw / 2, vy + vh / 2, vw * 0.8))
    for lx, ly in g["lenses"]:
        out.append('<circle cx="%s" cy="%s" r="%s" fill="url(#%s)"/>' % (lx / 2, ly / 2, g["lens_r"], "g_lensw" if kind == "white" else "g_lens"))
    body = '<g id="slot.sil_%s_glow">\n%s\n</g>' % (name, "\n".join(out))
    return wrap(300, 420, defs, body, width=210, height=294)


def locked_svg():
    from title_art_common import wrap
    cells = []
    for i, n in enumerate(("vanguard", "bulwark", "striker")):
        parts, _ = FRAMES[n]()
        head = '<g id="slot.sil_locked_%s" transform="translate(%s,0)"><g transform="translate(6,8) scale(0.23)">' % (n, i * 150)
        cells.append(head + chr(10) + render_parts(parts, "outline") + chr(10) + "</g></g>")
    return wrap(450, 210, "", chr(10).join(cells))
