"""Remaining IRON STATIC sound effects (A1-08): the 28 ids of 07 s7 beyond the 12 core sounds. Same toolkit and
timbre family as sfx.py (cold machine tones: FM metal, band-limited saws, band-passed noise bursts, bit-crush,
Schroeder reverb). Each recipe returns a mono float array; the registry SFX2 maps id -> (function, peak_dbfs).
Seeds are fixed per effect (noise seeds 201..), so output is reproducible. Final loudness is set by tools/audio_gen/
mix.py through the slot `volume_db`, not here."""

import numpy as np

import dsp
from dsp import SR, adsr, biquad, biquad_sweep, bitcrush, drive, exp_decay, fade, fm, noise, saw, sine, square, sweep


def _n(sec):
    return int(sec * SR)


def _put(dst, src, t0):
    s = int(t0 * SR)
    m = min(len(src), len(dst) - s)
    if m > 0:
        dst[s : s + m] += src[:m]
    return dst


def _tick(freq, dur, seed, q=1.5, tau=0.004):
    n = _n(dur)
    return biquad(noise(n, seed), "bp", freq, q) * exp_decay(n, tau, 0.0)


def _bell(freq, dur, ratio=3.5, index=3.0, tau=0.12, idx_tau=0.08):
    n = _n(dur)
    return fm(freq, ratio, index, n, exp_decay(n, idx_tau)) * exp_decay(n, tau, 0.001)


def _thud(f0, f1, dur, tau):
    n = _n(dur)
    return sine(sweep(n, f0, f1), n) * exp_decay(n, tau, 0.001)


# ---------------------------------------------------------------- combat feedback
def overcrit():
    n = _n(0.95)
    y = np.zeros(n)
    _put(y, _thud(130, 42, 0.5, 0.16) * 1.1, 0.0)
    _put(y, _bell(988.0, 0.8, 3.5, 3.5, 0.28, 0.1) * 0.55, 0.01)
    _put(y, _bell(1480.0, 0.6, 2.76, 2.0, 0.18, 0.06) * 0.3, 0.012)
    _put(y, biquad(noise(_n(0.12), 201), "lp", 3500) * exp_decay(_n(0.12), 0.025, 0.0) * 0.5, 0.0)
    return fade(dsp.reverb(drive(y, 1.6), 0.7, 0.72, 0.2), 0.001, 0.05)


def integrity_warn():
    """Lub-dub at the shape of HeartbeatModel: second pulse 0.18 s after the first at 70%."""
    n = _n(0.5)
    y = np.zeros(n)
    for t0, amp in ((0.0, 1.0), (0.18, 0.7)):
        m = _n(0.2)
        body = _thud(78, 38, 0.2, 0.05) * amp
        skin = biquad(noise(m, 202), "lp", 260) * exp_decay(m, 0.02, 0.001) * 0.5 * amp
        _put(y, body + skin, t0)
    return fade(drive(y, 1.8), 0.001, 0.03)


def skin_burn():
    n = _n(0.55)
    t = dsp.t_axis(n)
    rng = np.random.default_rng(203)
    y = np.zeros(n)
    k = 0
    for t0 in np.sort(rng.uniform(0.0, 1.0, 26) ** 1.6 * 0.45):
        f = float(rng.uniform(1800, 6500))
        a = float(rng.uniform(0.3, 1.0)) * float(np.exp(-t0 / 0.25))
        _put(y, _tick(f, 0.012, 300 + k, 2.0, 0.003) * a, t0)
        k += 1
    hiss = bitcrush(biquad(noise(n, 204), "bp", 3200, 0.8), 6, 2) * exp_decay(n, 0.12, 0.01) * 0.25
    glow = sine(sweep(n, 180, 90), n) * exp_decay(n, 0.08, 0.002) * 0.25
    return fade(drive(y + hiss + glow, 1.5) * np.minimum(1.0, (t[-1] - t) / 0.05), 0.001, 0.02)


def boss_death():
    n = _n(3.4)
    t = dsp.t_axis(n)
    y = np.zeros(n)
    _put(y, _thud(110, 26, 1.4, 0.4) * 1.2, 0.0)
    for i, t0 in enumerate((0.0, 0.32, 0.7, 1.15)):
        m = _n(1.0)
        crash = biquad_sweep(noise(m, 210 + i), "lp", sweep(m, 8000, 260), 0.9) * exp_decay(m, 0.2, 0.001)
        _put(y, crash * (0.8 / (1 + i * 0.35)), t0)
        for j, f in enumerate((420 + i * 90, 310 + i * 40, 590 - i * 50)):
            r = _n(0.5)
            h = fm(f, 2.76, 3.0, r, exp_decay(r, 0.06)) * exp_decay(r, 0.14) * (0.35 / (1 + j * 0.6))
            _put(y, h, t0 + 0.05 + 0.09 * j)
    f = sweep(n, 700, 34, "exp")
    whine = fm(f, 1.0, 1.6, n, exp_decay(n, 0.9)) * 0.4 + saw(f * 0.5, n) * 0.2
    whine = biquad_sweep(whine, "lp", sweep(n, 5000, 140), 1.2) * exp_decay(n, 1.1, 0.05)
    y += whine
    _put(y, _thud(70, 28, 0.6, 0.16) * 0.9, 2.3)
    y = drive(y, 1.9)
    return fade(dsp.reverb(y, 1.2, 0.8, 0.26), 0.002, 0.25) * np.minimum(1.0, (t[-1] - t) / 0.4)


def milestone_x15():
    """Gold chime: two bell strikes a fifth apart (A5, E6), glassy partials, long shimmer tail."""
    n = _n(1.3)
    y = np.zeros(n)
    _put(y, _bell(880.0, 1.2, 3.5, 2.2, 0.35, 0.12), 0.0)
    _put(y, _bell(1318.5, 1.1, 3.5, 2.0, 0.4, 0.12) * 0.85, 0.11)
    _put(y, _bell(2637.0, 0.6, 2.0, 1.0, 0.15, 0.05) * 0.25, 0.11)
    _put(y, biquad(noise(_n(0.3), 220), "hp", 7500) * exp_decay(_n(0.3), 0.04, 0.0) * 0.15, 0.1)
    return fade(dsp.delay(dsp.reverb(y, 0.8, 0.78, 0.25), 0.19, 0.3, 0.2), 0.001, 0.1)


# ---------------------------------------------------------------- draft, caches, lab
def draft_open():
    n = _n(0.8)
    t = dsp.t_axis(n)
    swell = np.minimum(1.0, t / 0.45) * np.minimum(1.0, (t[-1] - t) / 0.25)
    pad = saw(220.0, n) + saw(220.9, n) + saw(329.6, n) * 0.7 + saw(331.0, n) * 0.5
    pad = biquad_sweep(pad, "lp", sweep(n, 300, 2600), 1.6) * swell * 0.35
    air = biquad_sweep(noise(n, 221), "bp", sweep(n, 600, 5200), 1.2) * swell * 0.45
    click = _tick(2400, 0.02, 222) * 0.6
    y = pad + air
    y[: len(click)] += click
    return fade(dsp.reverb(y, 0.7, 0.7, 0.22), 0.004, 0.08)


def draft_pick():
    n = _n(0.4)
    y = np.zeros(n)
    _put(y, fm(sweep(_n(0.12), 320, 180), 1.51, 3.0, _n(0.12), exp_decay(_n(0.12), 0.03)) * exp_decay(_n(0.12), 0.05, 0.0006) * 0.9, 0.0)
    _put(y, _bell(1568.0, 0.35, 3.5, 2.0, 0.1, 0.05) * 0.55, 0.035)
    _put(y, _tick(3200, 0.012, 223) * 0.5, 0.0)
    return fade(dsp.reverb(y, 0.35, 0.55, 0.14), 0.0004, 0.04)


def cache_open():
    n = _n(0.95)
    y = np.zeros(n)
    _put(y, _tick(1400, 0.03, 224, 1.2, 0.006) * 1.1, 0.0)  # latch
    _put(y, _tick(900, 0.02, 225, 1.5, 0.004) * 0.9, 0.07)
    m = _n(0.5)
    hiss = biquad_sweep(noise(m, 226), "bp", sweep(m, 3500, 900), 0.9) * np.minimum(1.0, np.linspace(0, 6, m)) * exp_decay(m, 0.15, 0.01)
    _put(y, hiss * 0.5, 0.12)
    f = sweep(_n(0.4), 420, 1260)
    _put(y, (sine(f, _n(0.4)) * 0.45 + square(f, _n(0.4), 0.3) * 0.12) * exp_decay(_n(0.4), 0.14, 0.01), 0.3)
    return fade(dsp.reverb(y, 0.6, 0.65, 0.18), 0.0005, 0.06)


def pod_heal():
    n = _n(0.85)
    t = dsp.t_axis(n)
    f = sweep(n, 440, 660, "lin")
    y = sine(f, n) * 0.6 + sine(f * 2.0, n) * 0.12
    y *= (0.6 + 0.4 * np.sin(2 * np.pi * 7.0 * t)) * np.minimum(1.0, t / 0.2) * np.minimum(1.0, (t[-1] - t) / 0.3)
    air = biquad(noise(n, 227), "bp", 4200, 1.0) * np.minimum(1.0, t / 0.3) * np.minimum(1.0, (t[-1] - t) / 0.3) * 0.08
    return fade(dsp.reverb(y + air, 0.6, 0.7, 0.2), 0.01, 0.1)


# ---------------------------------------------------------------- weapon systems
def razor_spin():
    n = _n(0.42)
    t = dsp.t_axis(n)
    f = sweep(n, 780, 1100, "lin")
    y = saw(f, n) * 0.5 + square(f * 1.5, n, 0.3) * 0.15
    y = biquad(y, "bp", 1500, 0.9) * (0.5 + 0.5 * np.sin(2 * np.pi * 17.0 * t))
    y += biquad(noise(n, 228), "bp", 3600, 1.1) * (0.5 + 0.5 * np.sin(2 * np.pi * 17.0 * t + 1.5)) * 0.25
    return fade(y, 0.05, 0.1)


def shock_ring():
    n = _n(0.7)
    y = np.zeros(n)
    _put(y, _thud(420, 70, 0.55, 0.12) * 0.9, 0.0)
    m = _n(0.6)
    wave = biquad_sweep(noise(m, 229), "bp", sweep(m, 6000, 500), 1.1) * exp_decay(m, 0.16, 0.003)
    _put(y, wave * 0.6, 0.0)
    _put(y, _bell(1100.0, 0.5, 2.76, 3.0, 0.14, 0.07) * 0.35, 0.0)
    return fade(dsp.reverb(drive(y, 1.4), 0.6, 0.65, 0.2), 0.001, 0.07)


def mine_beep():
    n = _n(0.14)
    t = dsp.t_axis(n)
    y = square(1800.0, n, 0.5) * 0.35 + sine(1800.0, n) * 0.5
    gate = (t < 0.09).astype(float) * np.minimum(1.0, t / 0.002) * np.minimum(1.0, np.maximum(0.0, 0.09 - t) / 0.01)
    return fade(biquad(y, "lp", 5000) * gate, 0.0005, 0.01)


def arc():
    n = _n(0.28)
    t = dsp.t_axis(n)
    z = biquad_sweep(noise(n, 230), "bp", sweep(n, 5200, 900), 1.4)
    z *= np.sign(np.sin(2 * np.pi * 130.0 * t)) * 0.5 + 0.5
    z = bitcrush(z, 7, 2) * exp_decay(n, 0.07, 0.0005)
    crack = _tick(4500, 0.01, 231, 2.0, 0.002)
    z[: len(crack)] += crack * 0.8
    return fade(drive(z * 1.6, 1.6), 0.0004, 0.03)


def emp():
    n = _n(1.2)
    t = dsp.t_axis(n)
    y = np.zeros(n)
    _put(y, _thud(160, 36, 0.7, 0.2) * 1.1, 0.0)
    m = _n(1.0)
    sweepn = biquad_sweep(noise(m, 232), "bp", sweep(m, 7000, 250), 1.0) * exp_decay(m, 0.28, 0.002)
    _put(y, sweepn * 0.6, 0.0)
    hum = sine(sweep(n, 220, 55), n) * np.exp(-t / 0.35) * 0.35
    y += hum
    for i, t0 in enumerate((0.15, 0.31, 0.47, 0.72)):
        _put(y, _tick(3800 - i * 600, 0.012, 233 + i, 2.0, 0.003) * 0.4, t0)
    return fade(dsp.reverb(drive(y, 1.7), 0.8, 0.74, 0.22), 0.001, 0.12)


def missile_launch():
    n = _n(1.0)
    t = dsp.t_axis(n)
    thrust = biquad_sweep(noise(n, 238), "lp", sweep(n, 400, 3200), 0.9)
    thrust *= np.minimum(1.0, t / 0.08) * np.exp(-np.maximum(0.0, t - 0.25) / 0.4)
    core = biquad(saw(sweep(n, 70, 150), n), "lp", 400) * np.exp(-t / 0.5) * 0.6
    ign = _tick(1800, 0.04, 239, 1.0, 0.01)
    y = thrust * 0.8 + core
    y[: len(ign)] += ign * 0.9
    return fade(dsp.reverb(drive(y, 1.5), 0.6, 0.65, 0.18), 0.002, 0.15)


def singularity():
    n = _n(2.2)
    t = dsp.t_axis(n)
    f = sweep(n, 900, 38, "exp")
    y = saw(f, n) + saw(f * 1.012, n) * 0.8 + saw(f * 0.5, n) * 0.7
    y = biquad_sweep(y, "lp", sweep(n, 4000, 120), 2.0)
    cut = np.clip((1.85 - t) / 0.08, 0.0, 1.0)
    y *= np.minimum(1.0, t / 0.5) * cut
    suck = biquad_sweep(noise(n, 240), "bp", sweep(n, 7000, 300), 1.3) * np.minimum(1.0, t / 0.9) * cut
    y = y * 0.5 + suck * 0.35
    out = y.copy()
    _put(out, _thud(95, 28, 0.35, 0.1) * 1.0, 1.85)
    return fade(dsp.reverb(drive(out, 1.8), 1.0, 0.8, 0.25), 0.01, 0.2)


def dilation():
    n = _n(1.3)
    t = dsp.t_axis(n)
    f = sweep(n, 620, 90, "exp")
    wob = 1.0 + 0.02 * np.sin(2 * np.pi * (9.0 * np.exp(-t / 0.6)) * t)
    y = fm(f * wob, 1.0, 2.2, n, exp_decay(n, 0.5)) * 0.5 + dsp.tri(f * 0.5, n) * 0.35
    y = biquad_sweep(y, "lp", sweep(n, 4200, 220), 1.4)
    bell = _bell(1568.0, 0.5, 3.5, 1.5, 0.1, 0.05) * 0.2
    y[: len(bell)] += bell
    return fade(dsp.reverb(y * np.exp(-t / 0.9), 0.9, 0.78, 0.25), 0.003, 0.15)


def nanite():
    n = _n(0.55)
    t = dsp.t_axis(n)
    rng = np.random.default_rng(241)
    y = np.zeros(n)
    for k, t0 in enumerate(np.sort(rng.uniform(0.0, 0.5, 60))):
        f = float(rng.uniform(4500, 9500))
        _put(y, _tick(f, 0.006, 400 + k, 3.0, 0.0015) * float(rng.uniform(0.3, 1.0)), t0)
    env = np.sin(np.pi * np.clip(t / t[-1], 0, 1)) ** 1.3
    return fade(biquad(y, "hp", 3500) * env, 0.02, 0.05)


# ---------------------------------------------------------------- power-ups and big moments
def overdrive_on():
    n = _n(1.15)
    t = dsp.t_axis(n)
    f = sweep(n, 70, 420, "exp")
    y = saw(f, n) + saw(f * 1.006, n) * 0.8 + saw(f * 2.0, n) * 0.3
    y = biquad_sweep(y, "lp", sweep(n, 200, 4800), 1.8)
    whine = fm(sweep(n, 300, 2600, "exp"), 1.0, 1.4, n) * 0.18
    ramp = np.minimum(1.0, t / 0.9) ** 1.5 * np.clip((0.95 - t) / 0.03, 0.0, 1.0)
    out = (y * 0.55 + whine) * ramp
    _put(out, _thud(120, 40, 0.4, 0.12) * 1.0, 0.95)
    _put(out, _bell(1318.5, 0.2, 2.76, 2.0, 0.08, 0.04) * 0.4, 0.95)
    return fade(dsp.reverb(drive(out, 1.7), 0.7, 0.7, 0.2), 0.004, 0.08)


def overdrive_off():
    n = _n(1.0)
    t = dsp.t_axis(n)
    f = sweep(n, 1800, 70, "exp")
    y = fm(f, 1.0, 1.5, n, exp_decay(n, 0.45)) * 0.45 + saw(f * 0.5, n) * 0.3
    y = biquad_sweep(y, "lp", sweep(n, 4500, 150), 1.5) * np.exp(-t / 0.5)
    out = y.copy()
    _put(out, _thud(90, 34, 0.35, 0.1) * 0.7, 0.55)
    return fade(dsp.reverb(drive(out, 1.5), 0.7, 0.7, 0.2), 0.003, 0.12)


def aegis_break():
    n = _n(1.0)
    y = np.zeros(n)
    _put(y, _thud(150, 45, 0.4, 0.09) * 0.9, 0.0)
    rng = np.random.default_rng(242)
    for k in range(14):
        f = float(rng.uniform(1800, 5200))
        t0 = float(rng.uniform(0.0, 0.25))
        _put(y, fm(f, 2.76, 2.5, _n(0.3), exp_decay(_n(0.3), 0.04)) * exp_decay(_n(0.3), 0.07, 0.0005) * 0.3, t0)
    shard = bitcrush(biquad(noise(_n(0.5), 243), "hp", 3500), 6, 2) * exp_decay(_n(0.5), 0.1, 0.0)
    _put(y, shard * 0.5, 0.0)
    return fade(dsp.reverb(drive(y, 1.7), 0.7, 0.7, 0.2), 0.0005, 0.1)


def reboot():
    n = _n(1.9)
    t = dsp.t_axis(n)
    hum = sine(sweep(n, 40, 110, "exp"), n) * 0.5 + saw(sweep(n, 40, 110, "exp"), n) * 0.12
    hum = biquad_sweep(hum, "lp", sweep(n, 120, 900), 1.2) * np.minimum(1.0, t / 0.6) * np.minimum(1.0, (t[-1] - t) / 0.4)
    y = hum
    for t0, f, d in ((0.45, 520, 0.06), (0.62, 780, 0.06), (0.74, 1180, 0.06), (0.95, 1760, 0.05), (1.12, 1180, 0.05)):
        m = _n(d + 0.02)
        b = (square(f, m, 0.4) * 0.2 + sine(f, m) * 0.5) * exp_decay(m, d * 0.6, 0.001)
        _put(y, b, t0)
    _put(y, _bell(1760.0, 0.6, 3.5, 1.5, 0.2, 0.06) * 0.4, 1.3)
    _put(y, _tick(2200, 0.02, 244) * 0.5, 0.45)
    return fade(dsp.reverb(y, 0.8, 0.74, 0.22), 0.01, 0.15)


def meltdown():
    n = _n(2.6)
    t = dsp.t_axis(n)
    g = np.minimum(1.0, t / 1.8)
    f = 55.0 * (1.0 + 0.05 * np.sin(2 * np.pi * (3.0 + 6.0 * g) * t))
    y = saw(f, n) + saw(f * 1.5, n) * 0.5 + saw(f * 1.007, n) * 0.8
    y = biquad_sweep(y, "lp", sweep(n, 220, 3200), 1.8)
    y = drive(y * (0.25 + 0.75 * g), 5.0)
    crackle = np.zeros(n)
    rng = np.random.default_rng(245)
    for k, t0 in enumerate(np.sort(rng.uniform(0, 1.9, 70) ** 0.8 * 1.9 / 1.9 ** 0.8)):
        _put(crackle, _tick(float(rng.uniform(2000, 7000)), 0.01, 500 + k, 2.0, 0.002) * (0.2 + 0.6 * t0 / 1.9), t0)
    out = y * 0.5 * np.clip((2.0 - t) / 0.05, 0.0, 1.0) + crackle * 0.6
    blast = biquad_sweep(noise(_n(0.6), 246), "lp", sweep(_n(0.6), 9000, 300), 0.9) * exp_decay(_n(0.6), 0.14, 0.001)
    _put(out, blast * 1.0, 2.0)
    _put(out, _thud(90, 26, 0.6, 0.18) * 1.2, 2.0)
    return fade(dsp.reverb(drive(out, 1.5), 1.1, 0.8, 0.25), 0.01, 0.25)


def purge():
    n = _n(1.5)
    t = dsp.t_axis(n)
    m = _n(1.1)
    w = biquad_sweep(noise(m, 247), "bp", sweep(m, 200, 6500), 1.2) * np.sin(np.pi * np.linspace(0, 1, m)) ** 0.8
    y = np.zeros(n)
    _put(y, w * 0.8, 0.0)
    f = sweep(m, 150, 1500)
    _put(y, sine(f, m) * np.sin(np.pi * np.linspace(0, 1, m)) * 0.45, 0.0)
    _put(y, _bell(1760.0, 0.7, 3.5, 1.8, 0.2, 0.07) * 0.35, 0.95)
    _put(y, _thud(100, 40, 0.3, 0.07) * 0.5, 0.95)
    return fade(dsp.reverb(y, 0.8, 0.76, 0.24), 0.01, 0.15)


# ---------------------------------------------------------------- meta and UI stingers
def lab_complete():
    n = _n(1.5)
    t = dsp.t_axis(n)
    y = np.zeros(n)
    _put(y, _bell(740.0, 1.2, 3.5, 2.0, 0.3, 0.1), 0.0)
    _put(y, _bell(1109.0, 1.2, 3.5, 1.8, 0.35, 0.1) * 0.8, 0.14)
    pad = (saw(185.0, n) + saw(185.7, n) + saw(277.0, n) * 0.6) * np.minimum(1.0, t / 0.3) * np.exp(-t / 0.5)
    y += biquad(pad, "lp", 900) * 0.25
    for k, t0 in enumerate((0.0, 0.14, 0.2)):
        _put(y, _tick(5200, 0.01, 248 + k, 2.0, 0.003) * 0.35, t0)
    return fade(dsp.delay(dsp.reverb(y, 0.9, 0.78, 0.25), 0.21, 0.3, 0.18), 0.002, 0.15)


def firmware_pick():
    n = _n(0.9)
    y = np.zeros(n)
    _put(y, _tick(1100, 0.03, 251, 1.2, 0.006) * 1.0, 0.0)  # chip seat
    _put(y, _tick(2600, 0.02, 252, 1.5, 0.004) * 0.7, 0.05)
    f = sweep(_n(0.25), 500, 1500)
    _put(y, (sine(f, _n(0.25)) * 0.5 + square(f, _n(0.25), 0.3) * 0.12) * exp_decay(_n(0.25), 0.07, 0.003), 0.1)
    _put(y, _bell(880.0, 0.6, 3.5, 1.5, 0.2, 0.06) * 0.4, 0.3)
    _put(y, _thud(110, 55, 0.3, 0.08) * 0.5, 0.0)
    return fade(dsp.reverb(y, 0.5, 0.65, 0.16), 0.0005, 0.1)


def gauntlet_rank_up():
    n = _n(1.8)
    t = dsp.t_axis(n)
    y = np.zeros(n)
    _put(y, _thud(100, 36, 0.6, 0.16) * 0.8, 0.0)
    _put(y, fm(sweep(_n(0.5), 300, 140), 2.76, 3.0, _n(0.5), exp_decay(_n(0.5), 0.1)) * exp_decay(_n(0.5), 0.2, 0.001) * 0.4, 0.0)
    for k, (f, g) in enumerate(((587.0, 0.7), (880.0, 0.7), (1760.0, 0.5))):
        _put(y, _bell(f, 1.4, 3.5, 2.0, 0.4, 0.12) * g, 0.2)
    swell = (saw(147.0, n) + saw(147.6, n) + saw(220.0, n) * 0.6) * np.minimum(1.0, t / 0.7) * np.exp(-np.maximum(0.0, t - 0.7) / 0.5)
    y += biquad(swell, "lp", 1100) * 0.2
    _put(y, biquad(noise(_n(0.3), 253), "hp", 6000) * exp_decay(_n(0.3), 0.06, 0.0) * 0.2, 0.2)
    return fade(dsp.delay(dsp.reverb(y, 1.0, 0.8, 0.28), 0.23, 0.3, 0.18), 0.002, 0.2)


def results_tally():
    n = _n(1.0)
    y = np.zeros(n)
    t0 = 0.0
    gap = 0.11
    for k in range(9):
        f = 1000.0 + 55.0 * k
        m = _n(0.04)
        tone = sine(f, m) * exp_decay(m, 0.01, 0.0004) * 0.6 + _tick(3000, 0.04, 254 + k, 1.5, 0.003) * 0.3
        _put(y, tone, t0)
        t0 += gap * (0.95 ** k)
    _put(y, _bell(1480.0, 0.5, 3.5, 1.4, 0.16, 0.06) * 0.5, t0 + 0.03)
    return fade(dsp.reverb(y, 0.4, 0.6, 0.15), 0.0004, 0.08)


# id -> (function, target peak dBFS). Loudness shaping beyond this is done by the runtime slot volume_db (mix.py).
SFX2 = {
    "sfx_overcrit": (overcrit, -6.0),
    "sfx_integrity_warn": (integrity_warn, -8.0),
    "sfx_skin_burn": (skin_burn, -5.0),
    "sfx_boss_death": (boss_death, -3.0),
    "sfx_milestone_x15": (milestone_x15, -9.0),
    "sfx_draft_open": (draft_open, -8.0),
    "sfx_draft_pick": (draft_pick, -9.0),
    "sfx_cache_open": (cache_open, -8.0),
    "sfx_pod_heal": (pod_heal, -10.0),
    "sfx_razor_spin": (razor_spin, -9.0),
    "sfx_shock_ring": (shock_ring, -9.0),
    "sfx_mine_beep": (mine_beep, -14.0),
    "sfx_arc": (arc, -7.0),
    "sfx_emp": (emp, -5.0),
    "sfx_missile_launch": (missile_launch, -8.0),
    "sfx_singularity": (singularity, -5.0),
    "sfx_dilation": (dilation, -7.0),
    "sfx_nanite": (nanite, -7.0),
    "sfx_overdrive_on": (overdrive_on, -5.0),
    "sfx_overdrive_off": (overdrive_off, -6.0),
    "sfx_aegis_break": (aegis_break, -5.0),
    "sfx_reboot": (reboot, -6.0),
    "sfx_meltdown": (meltdown, -4.0),
    "sfx_purge": (purge, -6.0),
    "sfx_lab_complete": (lab_complete, -9.0),
    "sfx_firmware_pick": (firmware_pick, -10.0),
    "sfx_gauntlet_rank_up": (gauntlet_rank_up, -6.0),
    "sfx_results_tally": (results_tally, -12.0),
}
