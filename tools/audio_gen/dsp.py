"""Deterministic DSP building blocks for the IRON STATIC audio generators (A1-02).

Everything is numpy/scipy, mono float64 arrays in [-1, 1] at SR, no global state: every random source takes an
explicit seed (`noise(n, seed)`), so re-running a generator reproduces identical samples.
"""

import numpy as np
from scipy import ndimage, signal

SR = 44100  # project audio mix rate (project.godot has no override: Godot default 44100)


# ---------------------------------------------------------------- basics
def t_axis(n):
    return np.arange(n) / SR


def db(x):
    return 10.0 ** (x / 20.0)


def snap(freq, n, sr=SR):
    """Snap a frequency so that exactly an integer number of cycles fits n samples (loop-safe oscillators)."""
    cycles = max(1, round(freq * n / sr))
    return cycles * sr / n


def noise(n, seed):
    return np.random.default_rng(seed).uniform(-1.0, 1.0, n)


def _phase(freq, n):
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    return np.cumsum(f / SR) - f[0] / SR, f / SR


def sine(freq, n, phase0=0.0):
    ph, _ = _phase(freq, n)
    return np.sin(2 * np.pi * (ph + phase0))


def _blep(t, dt):
    out = np.zeros_like(t)
    a = t < dt
    x = t[a] / dt[a]
    out[a] = x + x - x * x - 1.0
    b = t > 1.0 - dt
    x = (t[b] - 1.0) / dt[b]
    out[b] = x * x + x + x + 1.0
    return out


def saw(freq, n, phase0=0.0):
    ph, dt = _phase(freq, n)
    t = (ph + phase0) % 1.0
    return 2.0 * t - 1.0 - _blep(t, dt)


def square(freq, n, width=0.5, phase0=0.0):
    ph, dt = _phase(freq, n)
    t = (ph + phase0) % 1.0
    y = np.where(t < width, 1.0, -1.0)
    y += _blep(t, dt)
    y -= _blep((t - width) % 1.0, dt)
    return y


def tri(freq, n, phase0=0.0):
    ph, _ = _phase(freq, n)
    t = (ph + phase0) % 1.0
    return 4.0 * np.abs(t - 0.5) - 1.0


def fm(carrier, ratio, index, n, index_env=None):
    """Two-operator FM. index_env (array) scales the modulation index over time (bell/metal tones)."""
    mod_f = np.broadcast_to(np.asarray(carrier, dtype=np.float64), (n,)) * ratio
    ph_m, _ = _phase(mod_f, n)
    idx = index * (1.0 if index_env is None else index_env)
    ph_c, _ = _phase(carrier, n)
    return np.sin(2 * np.pi * ph_c + idx * np.sin(2 * np.pi * ph_m))


# ---------------------------------------------------------------- envelopes
def adsr(n, a, d, s, r, hold=None):
    """ADSR over n samples (seconds for a/d/r, level s). Release starts at `hold` seconds (default n - r)."""
    h = int(hold * SR) if hold is not None else n - int(r * SR)
    h = max(0, min(h, n))
    ia, idc, ir = max(1, int(a * SR)), max(1, int(d * SR)), max(1, int(r * SR))
    env = np.zeros(n)
    for i, (lo, hi, v0, v1) in enumerate(
        [(0, ia, 0.0, 1.0), (ia, ia + idc, 1.0, s)]
    ):
        lo, hi = min(lo, h), min(hi, h)
        if hi > lo:
            env[lo:hi] = np.linspace(v0, v1, hi - lo, endpoint=False)
    sus_lo = min(ia + idc, h)
    env[sus_lo:h] = s
    if h < n:
        start = env[h - 1] if h > 0 else 0.0
        rr = min(ir, n - h)
        env[h : h + rr] = start * np.linspace(1.0, 0.0, rr, endpoint=False) ** 2
    return env


def exp_decay(n, tau, attack=0.002):
    t = t_axis(n)
    e = np.exp(-t / tau)
    if attack > 0:
        e *= np.minimum(1.0, t / attack)
    return e


def sweep(n, f0, f1, curve="exp"):
    """Frequency trajectory from f0 to f1 (exponential by default)."""
    x = np.linspace(0.0, 1.0, n)
    if curve == "exp":
        return f0 * (f1 / f0) ** x
    return f0 + (f1 - f0) * x


def fade(x, fin=0.002, fout=0.005):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


# ---------------------------------------------------------------- filters
def biquad_coeffs(kind, f, q):
    f = float(np.clip(f, 20.0, SR * 0.45))
    w0 = 2 * np.pi * f / SR
    al = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    if kind == "lp":
        b = [(1 - c) / 2, 1 - c, (1 - c) / 2]
    elif kind == "hp":
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    elif kind == "bp":
        b = [al, 0.0, -al]
    elif kind == "notch":
        b = [1.0, -2 * c, 1.0]
    else:
        raise ValueError(kind)
    a = [1 + al, -2 * c, 1 - al]
    return np.array(b) / a[0], np.array(a) / a[0]


def biquad(x, kind, f, q=0.707):
    b, a = biquad_coeffs(kind, f, q)
    return signal.lfilter(b, a, x)


def biquad_sweep(x, kind, f_curve, q=0.707, block=64):
    """Biquad with a time-varying cutoff (array, Hz per sample), state carried across blocks."""
    out = np.empty_like(x)
    zi = np.zeros(2)
    f_curve = np.broadcast_to(np.asarray(f_curve, dtype=np.float64), x.shape)
    for s in range(0, len(x), block):
        e = min(s + block, len(x))
        b, a = biquad_coeffs(kind, f_curve[s : s + (e - s) // 2 + 1].mean(), q)
        out[s:e], zi = signal.lfilter(b, a, x[s:e], zi=zi)
    return out


def onepole_lp(x, f):
    a = np.exp(-2 * np.pi * f / SR)
    return signal.lfilter([1 - a], [1, -a], x)


def onepole_hp(x, f):
    return x - onepole_lp(x, f)


def resonator_bank(x, freqs, qs, gains):
    out = np.zeros_like(x)
    for f, q, g in zip(freqs, qs, gains):
        out += g * biquad(x, "bp", f, q)
    return out


# ---------------------------------------------------------------- distortion
def drive(x, amount):
    return np.tanh(x * amount) / np.tanh(amount)


def bitcrush(x, bits=8, hold=4):
    y = np.repeat(x[::hold], hold)[: len(x)]
    step = 2.0 / (2**bits)
    return np.round(y / step) * step


# ---------------------------------------------------------------- time effects
def _comb(x, d, g):
    """y[n] = x[n] + g*y[n-d], computed block-wise (exact, fast for long delays)."""
    y = x.copy()
    for s in range(d, len(x), d):
        e = min(s + d, len(x))
        y[s:e] += g * y[s - d : e - d]
    return y


def _allpass(x, d, g):
    """y[n] = -g*x[n] + x[n-d] + g*y[n-d]."""
    y = -g * x
    for s in range(d, len(x), d):
        e = min(s + d, len(x))
        y[s:e] += x[s - d : e - d] + g * y[s - d : e - d]
    return y


def delay(x, seconds, feedback=0.4, mix=0.3, damp=4000.0):
    d = int(seconds * SR)
    wet = np.concatenate([np.zeros(d), _comb(x, d, feedback)])[: len(x)]
    wet = onepole_lp(wet, damp)
    return x + mix * wet


def reverb(x, size=1.0, decay=0.82, mix=0.3, damp=5000.0):
    """Light Schroeder reverb: 4 parallel combs into 2 series allpasses."""
    wet = np.zeros_like(x)
    for d in (1557, 1617, 1491, 1422):
        wet += _comb(x, int(d * size), decay)
    wet = onepole_lp(wet / 4.0, damp)
    for d, g in ((225, 0.5), (556, 0.5)):
        wet = _allpass(wet, d, g)
    return x * (1.0 - mix * 0.5) + mix * wet


def loop_process(x, fn, tiles=3):
    """Apply a stateful effect to a loop so that its tail wraps: process tiled x and keep the middle copy."""
    n = len(x)
    y = fn(np.tile(x, (tiles, 1) if x.ndim == 2 else tiles))
    k = tiles // 2
    return y[k * n : (k + 1) * n]


def stereo_widen(x, seed, width=0.012):
    """Mono -> stereo with a short Haas-style micro delay plus decorrelated tone on one side (deterministic)."""
    d = int(width * SR)
    left = x
    right = np.concatenate([x[-d:], x[:-d]]) if d else x  # circular shift keeps loops seamless
    return np.stack([left, right], axis=1)


# ---------------------------------------------------------------- dynamics
def limiter(x, ceiling=0.89, lookahead=0.004, release=0.06):
    """Look-ahead peak limiter (min-filter of the required gain, smoothed, then slow release)."""
    n = max(2, int(lookahead * SR))
    peak = np.max(np.abs(x), axis=1) if x.ndim == 2 else np.abs(x)
    need = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
    g = ndimage.minimum_filter1d(need, size=n, origin=-(n // 2))
    g = ndimage.uniform_filter1d(g, size=n)
    g = np.minimum(g, need)
    if release > 0:  # slow recovery: running min over the release window, then smoothed
        r = max(2, int(release * SR))
        g = ndimage.uniform_filter1d(ndimage.minimum_filter1d(g, size=r, origin=r // 2 - 1), size=r)
        g = np.minimum(g, need)
    y = x * (g[:, None] if x.ndim == 2 else g)
    return np.clip(y, -ceiling, ceiling)


def normalize_peak(x, peak_db):
    p = np.max(np.abs(x))
    return x * (db(peak_db) / p) if p > 0 else x


def remove_dc(x):
    return x - np.mean(x, axis=0)


def mix_at(dst, src, start):
    """Add src into dst at sample `start`; overflow past the end wraps to the start (loop-safe)."""
    n = len(dst)
    start %= n
    end = start + len(src)
    if end <= n:
        dst[start:end] += src
    else:
        k = n - start
        dst[start:] += src[:k]
        rest = src[k:]
        while len(rest):
            m = min(len(rest), n)
            dst[:m] += rest[:m]
            rest = rest[m:]
    return dst
