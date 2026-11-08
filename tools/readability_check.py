"""Objective readability checks on 1080-wide portrait screenshots (V1-19; FC5 / FC8 preview).

Pure Python (no Pillow): `tools/png_io.py` reads the PNGs. Run with `-I`:
    .venv\\Scripts\\python.exe -I tools\\readability_check.py crowd <png> [--cinder 540,672]
    .venv\\Scripts\\python.exe -I tools\\readability_check.py bands <b0.png> <b1.png> <b2.png> <b3.png>
    .venv\\Scripts\\python.exe -I tools\\readability_check.py hud <png>
    .venv\\Scripts\\python.exe -I tools\\readability_check.py crops <png> <out_dir>

crowd : per accent type (skitter/dart/walker/lancer/boss accent hue keys, art bible V1-GATE 3) connected-region
        count and median size, Cinder luminance margin over the brightest enemy pixel (L*), occlusion of Cinder's
        centre by enemy-accent pixels.
bands : sector occupancy of Cinder's 12 plate wedges (expected 12 / 9 / 4 / 0 intact per band).
hud   : WCAG contrast ratio of the HUD number rows (text colour vs the local background).
crops : writes a 2x contact crop per accent class (PNG, via zlib) for the human review of signature features.
Exit code is 0 if every printed check is within its threshold, 1 otherwise.
"""

import colorsys
import math
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png_io import read_png  # noqa: E402

# Accent hue keys: (name, hue degrees, tolerance). Hull stays dark; rims, vents and emissives carry the accent.
TYPES = [
    ("skitter_or_boss_red", 350.0, 14.0),  # #FF2D4B / #FF1F3D share a hue: boss is told apart by region size
    ("dart_pink", 312.0, 16.0),  # #FF4FD8
    ("walker_orange", 27.0, 9.0),  # #FF7A1A
    ("lancer_violet", 266.0, 16.0),  # #A35CFF
]
MIN_SAT = 0.55
MIN_VAL = 0.62
CINDER_RADIUS = 150  # px around Cinder excluded from the enemy search (armor ring + emitters)
BODY_MIN_PX = {"skitter_or_boss_red": 56, "dart_pink": 56, "walker_orange": 56, "lancer_violet": 56}

HUD_ROWS = {  # name: (x0, y0, x1, y1) in 1080-wide base px (HUD plates, art bible 7.2)
    "wave_number": (40, 25, 320, 95),
    "timer": (480, 110, 560, 160),
    "integrity_numbers": (850, 205, 1055, 250),
    "scrap_counter": (110, 292, 340, 345),
    "data_counter": (650, 292, 860, 345),
}


def srgb_to_lstar(r, g, b):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    y = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    return 116.0 * (y ** (1.0 / 3.0)) - 16.0 if y > 0.008856 else 903.3 * y


def rel_lum(r, g, b):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def classify(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    if s < MIN_SAT or v < MIN_VAL:
        return -1
    deg = h * 360.0
    for i, (_n, hue, tol) in enumerate(TYPES):
        d = abs((deg - hue + 180.0) % 360.0 - 180.0)
        if d <= tol:
            return i
    return -1


def regions(mask, w, h, dilate=7):
    """Connected components (4-neighbour) of a boolean grid on a coarse (every 2nd px) lattice."""
    seen = bytearray(w * h)
    out = []
    for start in range(w * h):
        if not mask[start] or seen[start]:
            continue
        stack = [start]
        seen[start] = 1
        x0 = y0 = 10**9
        x1 = y1 = -1
        n = 0
        while stack:
            p = stack.pop()
            y, x = divmod(p, w)
            n += 1
            x0 = min(x0, x)
            x1 = max(x1, x)
            y0 = min(y0, y)
            y1 = max(y1, y)
            for dy in range(-dilate, dilate + 1):
                yy = y + dy
                if yy < 0 or yy >= h:
                    continue
                for dx in range(-dilate, dilate + 1):
                    xx = x + dx
                    if xx < 0 or xx >= w:
                        continue
                    q = yy * w + xx
                    if mask[q] and not seen[q]:
                        seen[q] = 1
                        stack.append(q)
        out.append((x0, y0, x1, y1, n))
    return out


def crowd(path, cx, cy, y_min=370, y_max=1340):
    w, h, rows = read_png(path)
    step = 2
    gw = w // step
    gh = h // step
    cls = [bytearray(gw * gh) for _ in TYPES]
    enemy_lmax = 0.0
    cinder_lmax = 0.0
    occl_hit = 0
    occl_tot = 0
    for gy in range(gh):
        y = gy * step
        if y < y_min or y > y_max:
            continue
        row = rows[y]
        for gx in range(gw):
            x = gx * step
            r, g, b = row[x * 3], row[x * 3 + 1], row[x * 3 + 2]
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if d2 < 110**2:
                cinder_lmax = max(cinder_lmax, srgb_to_lstar(r, g, b))
            k = classify(r, g, b)
            if d2 < 60**2:
                occl_tot += 1
                if k >= 0:
                    occl_hit += 1
            if d2 < CINDER_RADIUS**2 or k < 0:
                continue
            cls[k][gy * gw + gx] = 1
            enemy_lmax = max(enemy_lmax, srgb_to_lstar(r, g, b))
    ok = True
    print("file: %s (%dx%d), Cinder centre (%d,%d)" % (path, w, h, cx, cy))
    for i, (name, _hue, _tol) in enumerate(TYPES):
        reg = [q for q in regions(cls[i], gw, gh) if q[4] >= 6]
        if not reg:
            print("  %-20s no accent regions found" % name)
            continue
        widths = sorted((q[2] - q[0] + 1) * step for q in reg)
        heights = sorted((q[3] - q[1] + 1) * step for q in reg)
        med_w = widths[len(widths) // 2]
        med_h = heights[len(heights) // 2]
        big = sum(1 for wd in widths if wd >= BODY_MIN_PX[name])
        print(
            "  %-20s regions=%d  median bbox %dx%d px  max width %d  regions >= %d px wide: %d"
            % (name, len(reg), med_w, med_h, widths[-1], BODY_MIN_PX[name], big)
        )
    margin = cinder_lmax - enemy_lmax
    occl = 100.0 * occl_hit / max(occl_tot, 1)
    print("  Cinder peak L* %.1f, brightest enemy-accent pixel L* %.1f, margin %.1f (threshold >= 20)" % (cinder_lmax, enemy_lmax, margin))
    print("  Cinder centre (r < 60 px) covered by enemy-accent pixels: %.1f %% (threshold < 15)" % occl)
    if margin < 20.0:
        ok = False
        print("  FAIL luminance margin")
    if occl >= 15.0:
        ok = False
        print("  FAIL occlusion")
    return ok


def bands(paths, cx, cy):
    """Cinder's 12 plate wedges live inside the armor disc (radius about 62..100 px). Per wedge sector the mean L*
    is compared with the same sector in the first image (band 0, all plates intact): below 0.72x of it = the plate
    is gone or charred (frame visible). Outer clutter (walkers around Cinder) is outside this annulus."""
    expected = [12, 9, 4, 0]
    destroyed = [[], [2, 7, 10], [0, 3, 5, 8, 11], [1, 4, 6, 9]]
    ok = True
    ref = None
    for band, path in enumerate(paths):
        w, h, rows = read_png(path)
        sums = [0.0] * 12
        ns = [0] * 12
        for y in range(cy - 105, cy + 106):
            for x in range(cx - 105, cx + 106):
                dx = x - cx
                dy = y - cy
                rr = math.sqrt(dx * dx + dy * dy)
                if rr < 62 or rr > 100:
                    continue
                r, g, b = rows[y][x * 3], rows[y][x * 3 + 1], rows[y][x * 3 + 2]
                ang = (math.atan2(dy, dx) + math.pi * 0.5) % math.tau
                k = int(ang / (math.tau / 12.0)) % 12
                sums[k] += srgb_to_lstar(r, g, b)
                ns[k] += 1
        means = [sums[k] / max(ns[k], 1) for k in range(12)]
        if ref is None:
            ref = means
        intact = [k for k in range(12) if means[k] >= 0.72 * ref[k]]
        gone = [k for k in range(12) if k not in intact]
        flag = "ok" if len(intact) == expected[band] else "MISMATCH"
        print("  B%d %s  plates intact %d (expected %d) %s; gone %s (expected gone %s)" % (band, os.path.basename(path), len(intact), expected[band], flag, gone, destroyed[band]))
        print("     sector mean L*: " + " ".join("%.0f" % m for m in means))
        if len(intact) != expected[band]:
            ok = False
    return ok

def hud(path):
    w, h, rows = read_png(path)
    ok = True
    for name, (x0, y0, x1, y1) in HUD_ROWS.items():
        vals = []
        for y in range(y0, min(y1, h)):
            for x in range(x0, min(x1, w)):
                r, g, b = rows[y][x * 3], rows[y][x * 3 + 1], rows[y][x * 3 + 2]
                vals.append((rel_lum(r, g, b), r, g, b))
        vals.sort()
        n = len(vals)
        bg = vals[n // 4][0]
        fg = vals[int(n * 0.985)][0]
        ratio = (fg + 0.05) / (bg + 0.05)
        status = "ok" if ratio >= 4.5 else "LOW"
        print("  %-18s text/background contrast %.1f : 1 (WCAG AA body 4.5, large 3.0) %s" % (name, ratio, status))
        if ratio < 3.0:
            ok = False
    return ok


def write_png(path, width, height, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(kind, data):
        c = struct.pack(">I", len(data)) + kind + data
        return c + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def crops(path, out_dir, y_min=370, y_max=1340):
    """Per accent class: 2x crops (nearest) around the strongest regions, for the reviewer's signature checklist."""
    w, h, rows = read_png(path)
    step = 2
    gw = w // step
    gh = h // step
    os.makedirs(out_dir, exist_ok=True)
    for i, (name, _hue, _tol) in enumerate(TYPES):
        mask = bytearray(gw * gh)
        for gy in range(gh):
            y = gy * step
            if y < y_min or y > y_max:
                continue
            for gx in range(gw):
                x = gx * step
                if classify(rows[y][x * 3], rows[y][x * 3 + 1], rows[y][x * 3 + 2]) == i:
                    mask[gy * gw + gx] = 1
        reg = sorted(regions(mask, gw, gh), key=lambda q: -q[4])[:3]
        for k, (gx0, gy0, gx1, gy1, _n) in enumerate(reg):
            x0 = max(gx0 * step - 24, 0)
            y0 = max(gy0 * step - 24, 0)
            x1 = min(gx1 * step + 24, w - 1)
            y1 = min(gy1 * step + 24, h - 1)
            cw = x1 - x0 + 1
            ch = y1 - y0 + 1
            out_rows = []
            for y in range(y0, y1 + 1):
                line = bytearray()
                for x in range(x0, x1 + 1):
                    px = rows[y][x * 3 : x * 3 + 3]
                    line += px + px
                out_rows.append(bytes(line))
                out_rows.append(bytes(line))
            fn = os.path.join(out_dir, "%s_%d.png" % (name, k + 1))
            write_png(fn, cw * 2, ch * 2, out_rows)
            print("  wrote %s (%dx%d crop at 2x)" % (fn, cw, ch))
    return True


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    cx, cy = 540, 672
    if "--cinder" in argv:
        i = argv.index("--cinder")
        cx, cy = [int(v) for v in argv[i + 1].split(",")]
        del argv[i : i + 2]
    cmd = argv[1]
    if cmd == "crowd":
        ok = crowd(argv[2], cx, cy)
    elif cmd == "bands":
        ok = bands(argv[2:], cx, cy)
    elif cmd == "hud":
        ok = hud(argv[2])
    elif cmd == "crops":
        ok = crops(argv[2], argv[3])
    else:
        print(__doc__)
        return 2
    print("RESULT: %s" % ("within thresholds" if ok else "THRESHOLD FAILURE"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
