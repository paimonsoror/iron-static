"""Bakes the seamless fbm noise texture the title smoke shader samples (assets/art/title/noise/smoke_fbm.png).

Why a texture: on the Pixel's PowerVR GPU (ANGLE) per-pixel hash/value-noise collapsed into hard blocks even with
highp. A baked, tileable 8-bit texture sampled with linear filtering needs no fract/hash maths in the shader.
Same fbm as the old shader: 3 octaves of smoothstep value noise (lattice 8, 16, 32 cells per tile, weights .5/.25/.125,
divided by .875). Pure Python, deterministic: `python -I tools/gen_smoke_noise.py`.
"""

import math
import os
import struct
import sys
import zlib

SIZE = 256
BASE_CELLS = 8
OCTAVES = 3
SEED = 20261108


def lattice(cells, salt):
    out = []
    state = (SEED * 2654435761 + salt * 40503) & 0xFFFFFFFF
    for _ in range(cells * cells):
        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF
        out.append(((state >> 8) & 0xFFFF) / 65535.0)
    return out


def octave(cells, salt):
    g = lattice(cells, salt)
    rows = []
    for y in range(SIZE):
        fy = y * cells / SIZE
        iy = int(fy)
        ty = fy - iy
        uy = ty * ty * (3.0 - 2.0 * ty)
        row = []
        for x in range(SIZE):
            fx = x * cells / SIZE
            ix = int(fx)
            tx = fx - ix
            ux = tx * tx * (3.0 - 2.0 * tx)
            ix1 = (ix + 1) % cells
            iy1 = (iy + 1) % cells
            a = g[iy * cells + ix]
            b = g[iy * cells + ix1]
            c = g[iy1 * cells + ix]
            d = g[iy1 * cells + ix1]
            row.append((a + (b - a) * ux) * (1.0 - uy) + (c + (d - c) * ux) * uy)
        rows.append(row)
    return rows


def write_png(path, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 0, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def main():
    acc = [[0.0] * SIZE for _ in range(SIZE)]
    amp = 0.5
    total = 0.0
    for o in range(OCTAVES):
        layer = octave(BASE_CELLS << o, o + 1)
        for y in range(SIZE):
            for x in range(SIZE):
                acc[y][x] += amp * layer[y][x]
        total += amp
        amp *= 0.5
    rows = [[max(0, min(255, int(round(v / total * 255.0)))) for v in r] for r in acc]
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "art", "title", "noise", "smoke_fbm.png")
    write_png(out, rows)
    flat = sorted(v for r in rows for v in r)
    print("wrote", os.path.normpath(out), "p5/p50/p95", flat[len(flat) // 20], flat[len(flat) // 2], flat[-len(flat) // 20])


if __name__ == "__main__":
    sys.exit(main())
