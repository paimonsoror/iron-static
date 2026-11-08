"""M3-26 title art generator. Run from this folder: python -I gen_title_art.py
Writes assets/art/title/src/*.svg (deterministic). Inputs: base/*.svgsrc (the approved M3-25 style-frame sheets that
are only resized or tightened), title_wreck.py (new wreckage), title_figures.py (three frame silhouettes)."""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import title_art_common as common  # noqa: E402
from title_art_common import write  # noqa: E402
import title_figures  # noqa: E402
import title_wreck  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "..", "src"))


def base(name):
    with open(os.path.join(HERE, "base", name + ".svgsrc"), encoding="utf-8") as fh:
        return fh.read()


def resize(text, w, h):
    """Canvas w x h (the slot table size) with the authored content scaled inside the cell group."""
    m = re.search(r'<svg xmlns="http://www.w3.org/2000/svg" width="(\d+)" height="(\d+)" viewBox="0 0 (\d+) (\d+)">', text)
    aw = int(m.group(3))
    head = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (w, h, w, h)
    text = text.replace(m.group(0), head, 1)
    i = text.index('<g id="slot.')
    head_pre, rest = text[:i], text[i:]
    return head_pre + common.scale_slot(rest, w / float(aw))


def sky():
    t = base("sky_glow")
    t = t.replace('<stop offset="0" stop-color="#07090C"/><stop offset="0.4" stop-color="#0D1117"/>',
                  '<stop offset="0" stop-color="#0D1117"/><stop offset="0.4" stop-color="#1B222B"/>')
    t = t.replace("</defs>", '<radialGradient id="g_hz" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#5A4034" stop-opacity="0.7"/>'
                  '<stop offset="1" stop-color="#5A4034" stop-opacity="0"/></radialGradient>\n'
                  '<radialGradient id="g_hzd" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#07090C" stop-opacity="0.85"/>'
                  '<stop offset="1" stop-color="#07090C" stop-opacity="0"/></radialGradient>\n</defs>')
    haze = [
        ("g_hz", 250, 70, 420, 34), ("g_hz", 800, 118, 380, 30), ("g_hz", 520, 40, 520, 26),
        ("g_hzd", 640, 96, 440, 22), ("g_hzd", 180, 150, 360, 20), ("g_hz", 400, 214, 470, 24),
        ("g_hz", 900, 262, 300, 22), ("g_hzd", 540, 300, 540, 18), ("g_hz", 160, 340, 340, 22),
        ("g_hz", 700, 396, 440, 18),
    ]
    add = "".join('<ellipse cx="%d" cy="%d" rx="%d" ry="%d" fill="url(#%s)"/>\n' % (x, y, rx, ry, g) for g, x, y, rx, ry in haze)
    t = t.replace("</g>\n</svg>", add + "</g>\n</svg>")
    return resize(t, 720, 500)


def logo():
    t = base("logo")
    iron_b = [120.0, 400.0, 680.0]
    iron_s = [0, -33, -66, -99]
    stat_b = [185.0, 356.0, 528.0, 700.0, 775.0]
    stat_s = [0, -20, -40, -60, -80, -100]
    lines = t.split("\n")
    out = []
    static = False
    margin = 50.0

    def shift_for(cx):
        b, s = (stat_b, stat_s) if static else (iron_b, iron_s)
        i = 0
        while i < len(b) and cx > b[i]:
            i += 1
        return s[i] + margin

    def fmt(v):
        s = "%.1f" % v
        return s[:-2] if s.endswith(".0") else s

    for ln in lines:
        if 'id="slot.logo_static"' in ln:
            static = True
        m = re.search(r'points="([^"]+)"', ln)
        if m and ln.startswith("<polygon"):
            pl = [tuple(float(v) for v in p.split(",")) for p in m.group(1).split()]
            cx = (min(p[0] for p in pl) + max(p[0] for p in pl)) / 2
            d = shift_for(cx)
            ln = ln.replace(m.group(1), " ".join("%s,%s" % (fmt(x + d), fmt(y)) for x, y in pl))
        elif ln.startswith("<rect"):
            mx = re.search(r' x="([\d.]+)"', ln)
            mw = re.search(r' width="([\d.]+)"', ln)
            x, w = float(mx.group(1)), float(mw.group(1))
            d = shift_for(x + w / 2)
            ln = ln.replace(' x="%s"' % mx.group(1), ' x="%s"' % fmt(x + d), 1)
        elif ln.startswith("<polyline") and "40," in ln and "920," in ln:
            ln = ln.replace("40,", "%s," % fmt(40 + margin), 2).replace("920,", "%s," % fmt(920 - 99 + margin) if not static else "%s," % fmt(920 - 100 + margin), 2)
        out.append(ln)
    return "\n".join(out)


def main():
    write(os.path.join(OUT, "hulks_mid.svg"), title_wreck.build())
    write(os.path.join(OUT, "sky_glow.svg"), sky())
    write(os.path.join(OUT, "spires_far.svg"), resize(base("spires_far"), 810, 240))
    write(os.path.join(OUT, "ridge_near.svg"), resize(base("ridge_near"), 1620, 480))
    write(os.path.join(OUT, "ridge_front.svg"), resize(base("ridge_front"), 1080, 220))
    write(os.path.join(OUT, "logo.svg"), logo())
    for n in ("vanguard", "bulwark", "striker"):
        write(os.path.join(OUT, "sil_%s.svg" % n), title_figures.sil_svg(n))
        write(os.path.join(OUT, "sil_%s_glow.svg" % n), title_figures.glow_svg(n))
    write(os.path.join(OUT, "sil_locked.svg"), title_figures.locked_svg())


if __name__ == "__main__":
    main()
