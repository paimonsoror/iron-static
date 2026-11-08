"""Title and Home ambience loops for IRON STATIC (M3-31, design 11 s4): a low wind bed and sparse distant metal.

Both are stereo loops of exact sample length (wind 36 s = 1587600 samples, creak 52 s = 2293200 samples at 44100 Hz).
The lengths share no short common period (LCM 468 s), so layered together the pattern never audibly repeats.
Seamless by construction: every modulator has an integer number of cycles per loop, filters and reverbs run on a tiled
copy and keep the middle copy (dsp.loop_process), event tails wrap to the loop start (dsp.mix_at).
IP rules (docs/design/07 s7): no melody, no motif, no pulse, no samples; groans glide at random pitches, clinks are
inharmonic and irregularly spaced, nothing rhythmic or tonal enough to echo any film theme.
Deterministic: fixed seeds (wind 31x, creak 32x). Final loudness comes from mix.py through the slot `volume_db`."""

import numpy as np

import dsp
from dsp import SR, biquad, biquad_sweep, drive, exp_decay, noise, saw

WIND_SECONDS = 36
CREAK_SECONDS = 52
WIND_N = WIND_SECONDS * SR
CREAK_N = CREAK_SECONDS * SR
PEAK_DB = -12.0  # file peak before the slot trim


def _fx(fn):
    return lambda x: np.stack([fn(x[:, 0]), fn(x[:, 1])], axis=1)


def _periodic(n, seconds, cycles, seed):
    """Smooth 0..1 modulator: a sum of sines with integer cycles per loop (exactly periodic), random phases."""
    rng = np.random.default_rng(seed)
    t = np.arange(n) / n
    m = np.zeros(n)
    for c, a in zip(cycles, (1.0, 0.8, 0.6, 0.4, 0.3)):
        m += a * np.sin(2 * np.pi * c * t + rng.uniform(0, 2 * np.pi))
    m = (m - m.min()) / (m.max() - m.min())
    return m


def wind():
    """Low filtered wind with slow gusts (a gust every 4 to 18 s), a faint airy band and a barely there whistle."""
    n = WIND_N
    gust = _periodic(n, WIND_SECONDS, (2, 3, 5, 8), 311)
    air_mod = _periodic(n, WIND_SECONDS, (3, 4, 7), 312)
    whistle_f = 540.0 + 90.0 * (_periodic(n, WIND_SECONDS, (1, 2, 3), 313) - 0.5)
    chans = []
    for ch in range(2):
        shift = int(0.35 * SR) * ch  # the two ears hear the gust a moment apart
        g = np.roll(gust, shift)
        am = np.roll(air_mod, shift)
        wf = np.roll(whistle_f, shift)
        src = noise(n, 314 + ch)

        def bed(x, g=g, am=am, wf=wf):
            gt, at, wt = np.tile(g, 3), np.tile(am, 3), np.tile(wf, 3)
            low = biquad_sweep(x, "lp", 180.0 + 520.0 * gt, 0.7, block=256)
            low = dsp.onepole_lp(low, 700.0)
            air = biquad_sweep(x, "bp", 750.0 + 500.0 * at, 0.9, block=256) * (0.08 + 0.2 * gt**2)
            whistle = biquad_sweep(x, "bp", wt, 14.0, block=256) * (0.9 * gt**4)
            return (low * (0.3 + 0.7 * gt) + air + whistle * 0.35) * 1.0

        y = bed(np.tile(src, 3))
        chans.append(y[n : 2 * n])
    out = np.stack(chans, axis=1)
    out = dsp.loop_process(out, _fx(lambda c: dsp.onepole_hp(c, 30.0)))
    return _finish(out)


def _groan(rng, seconds):
    """One slow metal groan: a gliding, wobbling saw through a stick-slip amplitude and two resonances, plus friction hiss."""
    n = int(seconds * SR)
    f0 = rng.uniform(70.0, 190.0)
    glide = rng.uniform(0.78, 1.28)
    wob = biquad(noise(n, int(rng.integers(1, 10**6))), "lp", 3.0) * 25.0
    f = dsp.sweep(n, f0, f0 * glide) * (1.0 + 0.05 * np.clip(wob, -1, 1))
    tone = saw(f, n) * 0.6 + saw(f * 1.507, n) * 0.25
    slip = 0.55 + 0.45 * np.clip(biquad(noise(n, int(rng.integers(1, 10**6))), "lp", 22.0) * 30.0, -1, 1)
    r1, r2 = rng.uniform(260.0, 520.0), rng.uniform(900.0, 1700.0)
    body = biquad(tone, "bp", r1, 7.0) * 2.4 + biquad(tone, "bp", r2, 9.0) * 0.9
    fric = biquad(noise(n, int(rng.integers(1, 10**6))), "bp", rng.uniform(1300.0, 2400.0), 1.6) * 0.07
    env = np.hanning(n) ** 1.6
    y = drive((body + fric) * slip * env * 0.8, 2.0)
    return biquad(y, "lp", 2600.0)


def _clink(rng, f):
    """A small settling clink: noise burst into an inharmonic resonator bank (no clear pitch)."""
    n = int(rng.uniform(0.28, 0.6) * SR)
    burst = biquad(noise(n, int(rng.integers(1, 10**6))), "bp", 3200.0, 1.0) * exp_decay(n, 0.004, 0)
    res = dsp.resonator_bank(burst, [f, f * 2.32, f * 3.71, f * 5.43], [55, 70, 80, 90], [1.0, 0.65, 0.4, 0.25])
    return biquad(res * exp_decay(n, rng.uniform(0.07, 0.16), 0.0005), "lp", 5000.0)


# (start second, duration): irregular gaps from 5 to 11 s, none of them a multiple of another.
GROANS = [(2.3, 2.9), (9.8, 2.1), (17.4, 3.4), (26.9, 1.8), (32.6, 3.0), (41.7, 2.4), (47.3, 3.1)]
# clink clusters: (start second, number of clinks)
CLINKS = [(5.6, 2), (13.3, 1), (21.8, 3), (29.9, 1), (37.2, 2), (44.5, 3), (50.4, 1)]


def creak():
    """Sparse distant groans and settling clinks over 52 s, in a long dark reverb. No rhythm, no melody."""
    rng = np.random.default_rng(321)
    out = np.zeros((CREAK_N, 2))
    for start, dur in GROANS:
        y = _groan(rng, dur)
        pan = rng.uniform(-0.65, 0.65)
        amp = rng.uniform(0.7, 1.0)
        dsp.mix_at(out[:, 0], y * amp * (1 - pan) / 2 * 1.4, int(start * SR))
        dsp.mix_at(out[:, 1], y * amp * (1 + pan) / 2 * 1.4, int(start * SR))
    for start, count in CLINKS:
        t = start
        for _ in range(count):
            y = _clink(rng, rng.uniform(780.0, 2300.0))
            pan = rng.uniform(-0.8, 0.8)
            amp = rng.uniform(0.18, 0.4)
            dsp.mix_at(out[:, 0], y * amp * (1 - pan) / 2 * 1.4, int(t * SR))
            dsp.mix_at(out[:, 1], y * amp * (1 + pan) / 2 * 1.4, int(t * SR))
            t += rng.uniform(0.11, 0.95)
    out = dsp.loop_process(out, _fx(lambda c: dsp.reverb(c, 2.4, 0.9, 0.6, 2800.0)), tiles=3)
    return _finish(out)


def _finish(stereo):
    y = stereo - stereo.mean(axis=0)
    return dsp.normalize_peak(y, PEAK_DB)


LOOPS = {"amb_wasteland_wind": (wind, WIND_N), "amb_metal_creak": (creak, CREAK_N)}
