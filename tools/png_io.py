"""Minimal pure-Python PNG reader (no third-party dependency) for the screenshot checks.

read_png(path) -> (width, height, rows) with rows = list of bytes, 3 bytes (RGB) per pixel (alpha dropped).
Supports 8-bit RGB/RGBA/gray, non-interlaced, which is what `adb screencap -p` produces.
"""

import struct
import zlib


def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG: " + path)
    pos = 8
    width = height = depth = ctype = interlace = 0
    idat = []
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        kind = data[pos + 4 : pos + 8]
        body = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, ctype, _comp, _flt, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat.append(body)
        elif kind == b"IEND":
            break
    if depth != 8 or interlace != 0 or ctype not in (0, 2, 6):
        raise ValueError("unsupported PNG (need 8-bit gray/RGB/RGBA, not interlaced)")
    bpp = {0: 1, 2: 3, 6: 4}[ctype]
    raw = zlib.decompress(b"".join(idat))
    stride = width * bpp
    rows = []
    prev = bytearray(stride)
    p = 0
    for _y in range(height):
        ft = raw[p]
        line = bytearray(raw[p + 1 : p + 1 + stride])
        p += 1 + stride
        if ft == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ft == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 255
        elif ft == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                pa = abs(b - c)
                pb = abs(a - c)
                pc = abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        prev = line
        if ctype == 2:
            rows.append(bytes(line))
        elif ctype == 6:
            rows.append(bytes(b for i, b in enumerate(line) if i % 4 != 3))
        else:
            rows.append(bytes(b for v in line for b in (v, v, v)))
    return width, height, rows
