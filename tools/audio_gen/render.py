"""Render all IRON STATIC audio (A1). Usage (via tools/audio_gen.ps1):
    render.py [--assets DIR] [--sketch DIR] [--only sfx|music|sketch]
Writes game assets (assets/audio/sfx/*.wav 16-bit mono, assets/audio/music/*.ogg stereo) and the sketch pack
(copies, 64 s preview, sfx reel, analysis.json). Deterministic: re-running reproduces identical bytes.
"""

import argparse
import json
import struct
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I mode ignores the script dir
import amb  # noqa: E402
import analyze  # noqa: E402
import dsp  # noqa: E402,F401
import mix  # noqa: E402
import music  # noqa: E402
import sfx  # noqa: E402
from dsp import SR  # noqa: E402

REPO = Path(__file__).resolve().parents[2]


def _ogg_crc_table():
    t = []
    for i in range(256):
        r = i << 24
        for _ in range(8):
            r = ((r << 1) ^ 0x04C11DB7) & 0xFFFFFFFF if r & 0x80000000 else (r << 1) & 0xFFFFFFFF
        t.append(r)
    return t


_CRC = _ogg_crc_table()


def _fix_ogg_serial(data, serial=0x1A57A71C):
    """libsndfile picks a random Ogg stream serial; pin it (and redo page CRCs) so output is reproducible."""
    out = bytearray(data)
    pos = 0
    while pos < len(out):
        if out[pos : pos + 4] != b"OggS":
            raise ValueError("bad ogg page")
        nseg = out[pos + 26]
        size = 27 + nseg + sum(out[pos + 27 : pos + 27 + nseg])
        struct.pack_into("<I", out, pos + 14, serial)
        struct.pack_into("<I", out, pos + 22, 0)
        crc = 0
        for b in out[pos : pos + size]:
            crc = ((crc << 8) & 0xFFFFFFFF) ^ _CRC[((crc >> 24) & 0xFF) ^ b]
        struct.pack_into("<I", out, pos + 22, crc)
        pos += size
    return bytes(out)


def write_wav(path, y):
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(str(path), y, SR, subtype="PCM_16", format="WAV")


def write_ogg(path, y):
    path.parent.mkdir(parents=True, exist_ok=True)
    # Chunked writes: one giant write() overflows libsndfile's stack on Windows.
    with sf.SoundFile(str(path), "w", SR, y.shape[1] if y.ndim == 2 else 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(y), 32768):
            f.write(y[i : i + 32768])
    path.write_bytes(_fix_ogg_serial(path.read_bytes()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--assets", default=str(REPO / "assets" / "audio"))
    ap.add_argument("--sketch", default=str(REPO / "docs" / "playtests" / "a1"))
    ap.add_argument("--only", choices=["sfx", "music", "sketch"], default=None)
    args = ap.parse_args()
    assets, sketch = Path(args.assets), Path(args.sketch)
    report = {}
    sfx_audio = {}
    for sid in sfx.ORDER:
        y = sfx.render(sid)
        sfx_audio[sid] = y
        write_wav(assets / "sfx" / f"{sid}.wav", y)
        if sid in sfx.CORE:
            write_wav(sketch / f"{sid}.wav", y)  # the approved sketch pack keeps only the 12 core sounds
        report[f"{sid}.wav"] = analyze.stats(y, loop=False)
        print("sfx", sid, f"{len(y) / SR:.2f}s")
    layers = {}
    for lid, fn in music.LAYERS.items():
        y = fn()
        layers[lid] = y
        write_ogg(assets / "music" / f"{lid}.ogg", y)
        write_ogg(sketch / f"{lid}.ogg", y)
        st = analyze.stats(y, loop=True)
        dec, _ = sf.read(str(assets / "music" / f"{lid}.ogg"))
        st["decoded_samples"] = int(len(dec))
        st["expected_samples"] = int(len(y))
        st["decoded_seam_jump_ratio"] = analyze.seam_ratio(dec)
        report[f"{lid}.ogg"] = st
        print("music", lid, f"{len(y) / SR:.2f}s")
    for aid, (fn, expected) in amb.LOOPS.items():  # M3-31 title ambience loops (stereo OGG, exact length)
        y = fn()
        assert len(y) == expected, aid
        write_ogg(assets / "amb" / f"{aid}.ogg", y)
        st = analyze.stats(y, loop=True)
        dec, _ = sf.read(str(assets / "amb" / f"{aid}.ogg"))
        st["decoded_samples"] = int(len(dec))
        st["expected_samples"] = int(expected)
        st["decoded_seam_jump_ratio"] = analyze.seam_ratio(dec)
        report[f"{aid}.ogg"] = st
        print("amb", aid, f"{len(y) / SR:.2f}s")
    prev = music.preview(layers)
    write_ogg(sketch / "music_preview.ogg", prev)
    report["music_preview.ogg"] = analyze.stats(prev, loop=False)
    gap = np.zeros(int(0.45 * SR))
    core_reel = np.concatenate([np.concatenate([sfx_audio[s], gap]) for s in sfx.CORE])
    write_wav(sketch / "sfx_reel.wav", core_reel)
    report["sfx_reel.wav"] = analyze.stats(core_reel, loop=False)
    # Full reel = every SFX in 07 s7 id order with its slot trim (volume_db from mix.py), 0.45 s gaps.
    reel = np.concatenate([np.concatenate([sfx_audio[s] * 10 ** (mix.trim_db(s, sfx_audio[s]) / 20), gap]) for s in sfx.ORDER])
    write_ogg(sketch / "sfx_reel_full.ogg", reel)  # OGG: the WAV was 5.2 MB in git
    report["sfx_reel_full.ogg"] = analyze.stats(reel, loop=False)
    # A/B of the laser redesign: old x8 at 6/s, a pause, new x8 at 6/s, each at its slot trim (old -8 dB, new from mix.py).
    old = sfx.render_fn(sfx.laser_shot_v1, -14.0)
    new = sfx_audio["sfx_laser_shot"]
    ab_len = int(8 * SR / 6 + 0.3 * SR)
    ab_parts = []
    for y, v in ((old, -8.0), (new, mix.trim_db("sfx_laser_shot", new))):
        seg = np.zeros(ab_len + len(y))
        for i in range(8):
            s0 = int(i * SR / 6)
            seg[s0 : s0 + len(y)] += y * 10 ** (v / 20)
        ab_parts.append(seg[:ab_len])
    ab = np.concatenate([ab_parts[0], np.zeros(int(1.2 * SR)), ab_parts[1]])
    write_ogg(sketch / "laser_ab.ogg", ab)
    report["laser_ab.ogg"] = analyze.stats(ab, loop=False)
    (sketch / "analysis.json").write_text(json.dumps(report, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(analyze.table(report))


if __name__ == "__main__":
    sys.exit(main())
