"""Validate the Google Play store graphics in release/store (B1-06). Plain Python, no third-party packages.

Run:  python -I tools/store_assets.py [--dir release/store]
Parses the PNG IHDR (and tRNS) and the JPEG SOF marker for size, color type and alpha, checks the Play limits and
prints a sizes table, then PASS or FAIL (exit code 0 or 1).

Rules (Play Console, checked against docs/release/research_2026-11.md):
  icon_512.png          512x512 PNG, alpha allowed, at most 1024 KB
  feature_1024x500.*    1024x500 JPEG or 24-bit PNG, no alpha, at most 15 MB
  phone_NN.*            2 to 8 files, exactly 1080x1920 (9:16, the longer side at most 2x the shorter), JPEG or
                        24-bit PNG, no alpha, at most 8 MB each, no two identical
"""

import hashlib
import os
import re
import struct
import sys

PNG_SIG = b"\x89PNG\r\n\x1a\n"
KB = 1024
MB = 1024 * 1024


def png_info(data):
    """Returns (width, height, has_alpha, kind) of a PNG, or None when it is not one."""
    if data[:8] != PNG_SIG:
        return None
    width, height, depth, ctype = struct.unpack(">IIBB", data[16:26])
    alpha = ctype in (4, 6)
    pos = 8
    while pos + 8 <= len(data):
        length, name = struct.unpack(">I4s", data[pos : pos + 8])
        if name == b"tRNS":
            alpha = True
        if name == b"IDAT":
            break
        pos += 12 + length
    return width, height, alpha, "PNG ct%d/%dbit" % (ctype, depth)


def jpeg_info(data):
    """Returns (width, height, False, kind) of a JPEG (it has no alpha), or None."""
    if data[:2] != b"\xff\xd8":
        return None
    pos = 2
    while pos + 4 <= len(data):
        if data[pos] != 0xFF:
            pos += 1
            continue
        marker = data[pos + 1]
        if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7 or marker == 0xFF:
            pos += 1 if marker == 0xFF else 2
            continue
        (length,) = struct.unpack(">H", data[pos + 2 : pos + 4])
        if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
            _prec, height, width, comps = struct.unpack(">BHHB", data[pos + 4 : pos + 10])
            return width, height, False, "JPEG %dch" % comps
        pos += 2 + length
    return None


def inspect(path):
    with open(path, "rb") as f:
        data = f.read()
    info = png_info(data) or jpeg_info(data)
    if info is None:
        return None
    return info + (len(data), hashlib.sha256(data).hexdigest()[:12])


def main():
    folder = "release/store"
    if "--dir" in sys.argv:
        folder = sys.argv[sys.argv.index("--dir") + 1]
    problems = []
    rows = []
    names = sorted(os.listdir(folder)) if os.path.isdir(folder) else []
    phones = []
    seen = {}
    icon = [n for n in names if n.startswith("icon_512.")]
    feature = [n for n in names if n.startswith("feature_1024x500.")]
    for n in names:
        if re.match(r"phone_\d\d\.(png|jpg)$", n):
            phones.append(n)
    if len(icon) != 1:
        problems.append("need exactly one icon_512.png")
    if len(feature) != 1:
        problems.append("need exactly one feature_1024x500.png")
    if not 2 <= len(phones) <= 8:
        problems.append("need 2 to 8 phone_NN files, found %d" % len(phones))
    for n in icon + feature + phones:
        info = inspect(os.path.join(folder, n))
        if info is None:
            problems.append("%s: not a PNG or JPEG" % n)
            continue
        w, h, alpha, kind, size, digest = info
        limit, want, alpha_ok = None, None, False
        if n.startswith("icon_"):
            limit, want, alpha_ok = 1024 * KB, (512, 512), True
            if not n.endswith(".png"):
                problems.append("%s: the icon must be a PNG" % n)
        elif n.startswith("feature_"):
            limit, want = 15 * MB, (1024, 500)
        else:
            limit, want = 8 * MB, (1080, 1920)
        status = "ok"
        if (w, h) != want:
            problems.append("%s: size %dx%d, want %dx%d" % (n, w, h, want[0], want[1]))
            status = "SIZE"
        if alpha and not alpha_ok:
            problems.append("%s: has an alpha channel" % n)
            status = "ALPHA"
        if size > limit:
            problems.append("%s: %d KB exceeds %d KB" % (n, size // KB, limit // KB))
            status = "BYTES"
        if n.startswith("phone_") and max(w, h) > 2 * min(w, h):
            problems.append("%s: aspect ratio over 2:1" % n)
            status = "RATIO"
        if digest in seen:
            problems.append("%s: identical to %s" % (n, seen[digest]))
            status = "DUP"
        seen[digest] = n
        rows.append((n, "%dx%d" % (w, h), kind, "yes" if alpha else "no", "%.1f" % (size / KB), digest, status))
    print("%-22s %-10s %-14s %-6s %9s  %-12s %s" % ("file", "size", "format", "alpha", "KB", "sha256", "check"))
    for r in rows:
        print("%-22s %-10s %-14s %-6s %9s  %-12s %s" % r)
    if problems:
        for p in problems:
            print("FAIL: " + p)
        print("STORE ASSETS FAIL")
        return 1
    print("STORE ASSETS PASS (%d files: icon, feature graphic, %d phone screenshots)" % (len(rows), len(phones)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
