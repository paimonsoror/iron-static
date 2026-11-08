"""Adaptive music layers for IRON STATIC (A1): ambient drone/pad -> pulse -> industrial percussion -> lead.

All four layers are stereo loops of identical, sample-accurate length: 8 bars of 4/4 at 90 BPM (21.3333 s =
940800 samples at 44100 Hz), so Godot's AudioStreamSynchronized keeps them locked. Loops are made seamless by
wrapping note tails to the loop start (dsp.mix_at) and by running time effects on a tiled copy
(dsp.loop_process). IP rules (docs/design/07 s7): 4/4 only, no odd-meter ostinato, no march, no samples,
original material; the clank pattern is generated per bar from a fixed seed so it never repeats as a 4-note hook.
"""

import numpy as np

import dsp
from dsp import SR, adsr, biquad, biquad_sweep, drive, exp_decay, fm, mix_at, noise, saw, sine, square, sweep

BPM = 90
BARS = 8
STEP = int(round(60.0 / BPM / 4 * SR))  # one 16th = 7350 samples (exact)
BAR = STEP * 16
N = BAR * BARS  # loop length in samples
LAYER_RMS_DB = {"pad": -24.0, "pulse": -26.0, "perc": -24.0, "lead": -28.0}

D1, D2, A1 = 36.708, 73.416, 55.0

# Pedal on D; the upper structure changes every two bars (not a functional progression, mostly open fifths/seconds).
CHORDS = [
    [146.83, 220.0, 329.63, 440.0],  # D A E A
    [174.61, 220.0, 261.63, 392.0],  # F A C G
    [116.54, 146.83, 174.61, 293.66],  # Bb D F D
    [110.0, 164.81, 196.0, 246.94],  # A E G B
]


def _finish(stereo, rms_db):
    y = stereo - stereo.mean(axis=0)
    rms = np.sqrt(np.mean(y**2))
    y = y * dsp.db(rms_db) / rms
    return dsp.limiter(y, 0.7, 0.004, 0.0)


def _fx(fn):
    return lambda x: np.stack([fn(x[:, 0]), fn(x[:, 1])], axis=1)


def pad():
    rng = np.random.default_rng(7)
    out = np.zeros((N, 2))
    seg = BAR * 3
    t = np.arange(seg) / SR
    win = np.hanning(seg)
    for ch in range(2):
        sign = -1.0 if ch else 1.0
        for ci, notes in enumerate(CHORDS):
            sig = np.zeros(seg)
            for k, f in enumerate(notes):
                for det in (-0.004, 0.0, 0.0045):
                    sig += saw(f * (1 + det * sign + rng.uniform(-0.0006, 0.0006)), seg, rng.uniform()) * 0.18
            lfo = 650 + 350 * np.sin(2 * np.pi * (t / (BAR * 2 / SR)) + ci)
            sig = biquad_sweep(sig, "lp", lfo, 0.9)
            mix_at(out[:, ch], sig * win, ci * BAR * 2 - BAR // 2)
    # drone + air (integer cycles per loop = seamless)
    t = np.arange(N) / SR
    drone = sine(dsp.snap(D1, N), N) * 0.9 + saw(dsp.snap(D2, N), N) * 0.18
    drone = biquad(drone, "lp", 220)
    drone *= 0.85 + 0.15 * np.sin(2 * np.pi * t / (N / SR))
    air = biquad(noise(N, 21), "bp", 2400, 0.6) * (0.5 + 0.5 * np.sin(2 * np.pi * 2 * t / (N / SR)))
    out += drone[:, None] * 0.9 + np.stack([air, np.roll(air, 4000)], axis=1) * 0.05
    out = dsp.loop_process(out, _fx(lambda c: dsp.reverb(c, 1.6, 0.86, 0.45, 4000.0)))
    return _finish(out, LAYER_RMS_DB["pad"])


def pulse():
    mono = np.zeros(N)
    hits = [0, 3, 6, 8, 11, 14]  # 3-3-2 syncopation in 4/4
    for bar in range(BARS):
        for s in hits:
            f = D2
            if bar % 4 == 3 and s == 14:
                f = A1  # a fifth below the root at the end of the phrase
            n = int(STEP * 2.2)
            tt = np.arange(n) / SR
            osc = saw(f, n) * 0.6 + square(f * 0.5, n, 0.45) * 0.5
            cut = 160 + 1500 * np.exp(-tt / 0.07)
            y = biquad_sweep(osc, "lp", cut, 2.5) * adsr(n, 0.003, 0.1, 0.35, 0.08, hold=0.11)
            acc = 1.0 if s in (0, 8) else 0.75
            mix_at(mono, y * acc, bar * BAR + s * STEP)
    # quiet 16th "tick" (soft filtered noise) with offbeat accents
    for i in range(BARS * 16):
        n = int(STEP * 0.9)
        tk = biquad(noise(n, 300 + i), "hp", 6500) * exp_decay(n, 0.012, 0) * (0.35 if i % 2 else 0.12)
        mix_at(mono, tk * 0.5, i * STEP)
    mono = drive(mono * 1.4, 1.8)
    stereo = np.stack([mono, np.roll(mono, 90)], axis=1)
    stereo = dsp.loop_process(stereo, _fx(lambda c: dsp.delay(c, 60.0 / BPM * 0.75, 0.38, 0.28, 3000.0)))
    stereo = dsp.loop_process(stereo, _fx(lambda c: dsp.reverb(c, 0.9, 0.7, 0.16)))
    return _finish(stereo, LAYER_RMS_DB["pulse"])


def _kick():
    n = int(0.32 * SR)
    body = sine(sweep(n, 130, 42), n) * exp_decay(n, 0.11, 0.0008)
    click = biquad(noise(n, 401), "bp", 2200, 1.0) * exp_decay(n, 0.004, 0) * 0.35
    return drive(body + click, 1.6)


def _plate_hit(f, seed, decay=0.25):
    """Steel plate: inharmonic FM + a bank of resonators excited by a short noise burst."""
    n = int(decay * 4 * SR)
    env = exp_decay(n, decay, 0.0006)
    metal = fm(f, 2.756, 5.0, n, exp_decay(n, 0.05)) * env
    burst = biquad(noise(n, seed), "bp", 3500, 1.0) * exp_decay(n, 0.006, 0)
    res = dsp.resonator_bank(burst, [f * 1.0, f * 2.32, f * 3.7, f * 5.1], [40, 50, 60, 70], [1.0, 0.7, 0.5, 0.3])
    return (metal * 0.7 + res * 0.9 + burst * 0.3) * 0.9


def _hiss(seconds, seed, f_start=2500, f_end=7000):
    n = int(seconds * SR)
    tt = np.arange(n) / SR
    x = biquad_sweep(noise(n, seed), "bp", sweep(n, f_start, f_end), 0.8)
    env = np.minimum(1.0, tt / 0.012) * np.exp(-tt / (seconds * 0.45))  # quick burst, long bleed-off
    return x * env


def perc():
    rng = np.random.default_rng(11)
    mono = np.zeros(N)
    kicks = {0: [0, 10], 1: [0, 7, 10], 2: [0, 10], 3: [0, 7, 10, 14]}
    pitches = [312.0, 389.0, 467.0, 247.0, 523.0, 351.0]
    for bar in range(BARS):
        for s in kicks[bar % 4]:
            mix_at(mono, _kick() * 0.9, bar * BAR + s * STEP)
        mix_at(mono, _plate_hit(185.0, 410 + bar, 0.18) * 0.8, bar * BAR + 8 * STEP)  # steel "snare", beat 3
        if bar % 2 == 1:
            mix_at(mono, _hiss(0.55, 450 + bar) * 0.33, bar * BAR + 12 * STEP)  # hydraulic release
        if bar % 2 == 0:
            mix_at(mono, _hiss(0.35, 470 + bar, 5000, 9000) * 0.18, bar * BAR + 4 * STEP)
        for s in sorted(rng.choice([2, 3, 5, 7, 9, 11, 13, 15], size=int(rng.integers(1, 3)), replace=False)):
            f = float(rng.choice(pitches))
            mix_at(mono, _plate_hit(f, int(rng.integers(1, 10**6)), 0.12) * rng.uniform(0.28, 0.45), bar * BAR + int(s) * STEP)
    # big steel impact on the downbeat of bars 1 and 5, long ring
    big = _plate_hit(92.0, 480, 0.6) * 0.9
    mix_at(mono, big, 0)
    mix_at(mono, big * 0.8, 4 * BAR)
    stereo = np.stack([mono, np.roll(mono, 140)], axis=1)
    stereo = dsp.loop_process(stereo, _fx(lambda c: dsp.reverb(c, 1.2, 0.8, 0.3, 6000.0)))
    return _finish(stereo, LAYER_RMS_DB["perc"])


# bell events: (bar, 16th step, frequency, length in beats-ish decay seconds)
BELLS = [
    (0, 0, 587.33, 1.6), (0, 5, 698.46, 1.2), (0, 10, 659.26, 1.4),
    (1, 3, 440.0, 1.8), (1, 12, 523.25, 1.2),
    (2, 6, 783.99, 1.5), (3, 1, 587.33, 1.6), (3, 9, 440.0, 1.4),
    (4, 0, 698.46, 1.6), (4, 7, 880.0, 1.2), (5, 4, 659.26, 1.6),
    (6, 2, 523.25, 1.4), (6, 11, 587.33, 1.5), (7, 6, 392.0, 2.0),
]  # irregular, sparse, descending/ascending mix: no repeated motif, no known theme


def lead():
    bells = np.zeros(N)
    for bar, s, f, dec in BELLS:
        n = int(dec * 3.2 * SR)
        env = exp_decay(n, dec * 0.45, 0.001)
        y = fm(f, 3.5, 2.5, n, exp_decay(n, 0.35)) * env + fm(f * 2.0, 1.0, 1.0, n, exp_decay(n, 0.2)) * env * 0.25
        mix_at(bells, y * 0.6, bar * BAR + s * STEP)
    # boss wail: low saw lead holding notes of two bars with glides, crossfaded (wraps seamlessly)
    wail = np.zeros(N)
    notes = [146.83, 174.61, 130.81, 146.83]
    seg = BAR * 2 + int(BAR * 0.5)
    win = np.hanning(seg)
    for i, f in enumerate(notes):
        tt = np.arange(seg) / SR
        vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.0 * tt) * np.minimum(1.0, tt / 1.0)
        gl = np.concatenate([np.linspace(0.97, 1.0, int(0.25 * SR)), np.ones(seg - int(0.25 * SR))])
        y = saw(f * vib * gl, seg) + saw(f * 1.006 * vib * gl, seg) * 0.8
        y = biquad_sweep(y, "lp", 500 + 600 * np.sin(np.pi * tt / (seg / SR)), 2.0)
        mix_at(wail, drive(y * 0.5, 3.0) * win, i * BAR * 2 - BAR // 4)
    mono = bells * 0.9 + wail * 0.4
    stereo = np.stack([mono, np.roll(bells, 2500) * 0.9 + wail * 0.4], axis=1)
    stereo = dsp.loop_process(stereo, _fx(lambda c: dsp.delay(c, 60.0 / BPM * 0.75, 0.42, 0.3, 3500.0)))
    stereo = dsp.loop_process(stereo, _fx(lambda c: dsp.reverb(c, 1.5, 0.85, 0.4)))
    return _finish(stereo, LAYER_RMS_DB["lead"])


LAYERS = {"music_pad": pad, "music_pulse": pulse, "music_perc": perc, "music_lead": lead}

# Preview arrangement: per bar (0..23) gain of each layer; three loops = 64 s.
ARRANGEMENT = {
    "music_pad": lambda b: min(1.0, 0.25 + b / 2.0) * (1.0 if b < 22 else max(0.0, 23 - b)),
    "music_pulse": lambda b: float(np.clip((b - 6) / 1.0, 0.0, 1.0)),
    "music_perc": lambda b: float(np.clip((b - 12) / 1.0, 0.0, 1.0)),
    "music_lead": lambda b: float(np.clip((b - 18) / 1.0, 0.0, 1.0)),
}


def preview(layers):
    total = N * 3
    out = np.zeros((total, 2))
    for lid, y in layers.items():
        loops = np.tile(y, (3, 1))
        bars = np.arange(total) / BAR
        pts = np.arange(0, 25)
        g = np.interp(bars, pts, [ARRANGEMENT[lid](min(b, 23)) for b in pts])
        out += loops * g[:, None]
    out = dsp.limiter(out, 0.89, 0.006, 0.08)
    fade_n = 2 * SR
    out[-fade_n:] *= np.linspace(1, 0, fade_n)[:, None]
    return out
