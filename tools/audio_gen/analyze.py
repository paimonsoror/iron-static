"""Objective audio checks: peak, RMS, K-weighted loudness (LUFS-ish, ungated BS.1770 K filter), DC offset,
clipping, and loop-seam click ratio."""

import numpy as np
from scipy import signal

from dsp import SR


def _k_weight(x):
    # BS.1770 K-weighting: high-shelf (+4 dB @ ~1.68 kHz) then 38 Hz high-pass, designed for SR via RBJ forms.
    A = 10 ** (3.999843853973347 / 40)
    f0, q = 1681.974450955533, 0.7071752369554196
    w0 = 2 * np.pi * f0 / SR
    al = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    b = [A * ((A + 1) + (A - 1) * c + 2 * np.sqrt(A) * al), -2 * A * ((A - 1) + (A + 1) * c),
         A * ((A + 1) + (A - 1) * c - 2 * np.sqrt(A) * al)]
    a = [(A + 1) - (A - 1) * c + 2 * np.sqrt(A) * al, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - 2 * np.sqrt(A) * al]
    y = signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], x, axis=0)
    f1, q1 = 38.13547087602444, 0.5003270373238773
    w1 = 2 * np.pi * f1 / SR
    al1 = np.sin(w1) / (2 * q1)
    c1 = np.cos(w1)
    bh = [(1 + c1) / 2, -(1 + c1), (1 + c1) / 2]
    ah = [1 + al1, -2 * c1, 1 - al1]
    return signal.lfilter(np.array(bh) / ah[0], np.array(ah) / ah[0], y, axis=0)


def seam_ratio(y):
    """|jump across the loop seam| / 99.9th percentile of |first difference| elsewhere (<= ~1.5 means no click)."""
    m = y if y.ndim == 1 else y.mean(axis=1)
    d = np.abs(np.diff(m))
    seam = abs(m[0] - m[-1])
    return float(seam / np.percentile(d, 99.9))


def stats(y, loop):
    peak = np.max(np.abs(y))
    out = {
        "seconds": round(len(y) / SR, 3),
        "samples": int(len(y)),
        "channels": 1 if y.ndim == 1 else y.shape[1],
        "peak_dbfs": round(20 * np.log10(peak), 2),
        "rms_dbfs": round(20 * np.log10(np.sqrt(np.mean(y**2))), 2),
        "lufs_ish": round(-0.691 + 10 * np.log10(np.mean(_k_weight(y) ** 2) * (1 if y.ndim == 1 else y.shape[1])), 2),
        "dc_offset": round(float(np.max(np.abs(np.mean(y, axis=0)))), 6),
        "clipped_samples": int(np.sum(np.abs(y) >= 0.9999)),
    }
    if loop:
        out["seam_jump_ratio"] = round(seam_ratio(y), 3)
    return out


def table(report):
    rows = ["file                       sec    peak   rms   lufs   dc       clip"]
    for k, v in report.items():
        rows.append(
            f"{k:26s} {v['seconds']:6.2f} {v['peak_dbfs']:6.1f} {v['rms_dbfs']:6.1f} {v['lufs_ish']:6.1f} "
            f"{v['dc_offset']:.5f} {v['clipped_samples']}" + (f"  seam={v['seam_jump_ratio']}" if "seam_jump_ratio" in v else "")
        )
    return "\n".join(rows)
