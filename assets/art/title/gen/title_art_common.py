"""Shared SVG helpers of the M3-26 title art generator (deterministic; run: python -I gen_title_art.py)."""
import math

TAU = math.pi * 2

PAL = {
    "void": "#07090C", "ink": "#0B0E13", "g0": "#0D1117", "g1": "#12171D", "g2": "#1B222B", "g3": "#222B38",
    "g4": "#2B343B", "g5": "#38434B", "g6": "#56656F", "g7": "#6B7882", "brown0": "#1F1612", "brown1": "#3A2A22",
    "brown2": "#5A4034", "bronze": "#8A5F00", "bronze2": "#7A5A48", "amber": "#FFB000", "orange": "#FF8A1F",
    "pale": "#FFD27A", "cream": "#FFF1C9", "white": "#FFFFFF", "dead": "#7A1E30", "vent": "#FF5A3C",
}


def f(v):
    s = "%.1f" % v
    return s[:-2] if s.endswith(".0") else s


def pts(points):
    return " ".join("%s,%s" % (f(x), f(y)) for x, y in points)


def poly(points, fill, extra=""):
    return '<polygon points="%s" fill="%s"%s/>' % (pts(points), fill, (" " + extra) if extra else "")


def line(points, stroke, w=3, op=1.0, extra=""):
    o = "" if op >= 0.999 else ' stroke-opacity="%.2f"' % op
    return '<polyline points="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"%s%s/>' % (
        pts(points), stroke, f(w), o, (" " + extra) if extra else "")


def circle(cx, cy, r, fill, extra=""):
    return '<circle cx="%s" cy="%s" r="%s" fill="%s"%s/>' % (f(cx), f(cy), f(r), fill, (" " + extra) if extra else "")


def rect(x, y, w, h, fill, extra=""):
    return '<rect x="%s" y="%s" width="%s" height="%s" fill="%s"%s/>' % (f(x), f(y), f(w), f(h), fill, (" " + extra) if extra else "")


def mirror(points, cx=300.0):
    return [(2 * cx - x, y) for x, y in reversed(points)]


def quad_pts(p0, p1, p2, n=10):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append((
            (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1],
        ))
    return out


def cable(p0, p2, sag, stroke, w=3, op=1.0):
    mx = (p0[0] + p2[0]) * 0.5
    my = max(p0[1], p2[1]) + sag
    return line(quad_pts(p0, (mx, my), p2, 9), stroke, w, op)


def scale_slot(body, k):
    """Wraps the content of every cell group (one per line when there are several) in a scale group."""
    if k == 1.0:
        return body
    tag = '<g id="slot.'
    if body.count(tag) > 1:
        return chr(10).join(scale_slot(ln, k) if ln.startswith(tag) else ln for ln in body.split(chr(10)))
    i = body.index(">") + 1
    j = body.rindex("</g>")
    return body[:i] + '<g transform="scale(%s)">' % ("%.5f" % k).rstrip("0") + body[i:j] + "</g>" + body[j:]


def wrap(w, h, defs, body, width=None, height=None):
    """SVG document whose canvas is the texel size (width x height, the slot table size); the authored w x h content
    is scaled down inside the cell group (the lint wants viewBox == sheet size and translate-only cell groups)."""
    tw, th = width or w, height or h
    body = scale_slot(body, tw / float(w))
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s">\n<defs>\n%s\n</defs>\n%s\n</svg>\n'
        % (tw, th, tw, th, defs, body)
    )


def stops_xml(stops):
    out = ""
    for o, c, a in stops:
        out += '<stop offset="%s" stop-color="%s"%s/>' % (f(o), c, (' stop-opacity="%s"' % a) if a is not None else "")
    return out


def lin(id_, stops, x1=0, y1=0, x2=0, y2=1, units=False):
    u = ' gradientUnits="userSpaceOnUse"' if units else ""
    return '<linearGradient id="%s" x1="%s" y1="%s" x2="%s" y2="%s"%s>%s</linearGradient>' % (
        id_, f(x1), f(y1), f(x2), f(y2), u, stops_xml(stops))


def rad(id_, stops):
    return '<radialGradient id="%s" cx="0.5" cy="0.5" r="0.5">%s</radialGradient>' % (id_, stops_xml(stops))


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def gear(cx, cy, r, teeth, fill, hub_fill, ring_stroke, rot=0.0, notch=0.0):
    """Gear polygon with trapezoid teeth; `notch` (0..1 of the turn) sinks a wedge (a broken gear)."""
    out = []
    n = teeth * 4
    for i in range(n):
        a = rot + TAU * i / n
        k = i % 4
        rr = r if k in (1, 2) else r * 0.84
        if notch and (i / n) < notch:
            rr = r * 0.55
        out.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    s = poly(out, fill)
    s += circle(cx, cy, r * 0.62, "none", 'stroke="%s" stroke-width="3"' % ring_stroke)
    s += circle(cx, cy, r * 0.26, hub_fill)
    return s
