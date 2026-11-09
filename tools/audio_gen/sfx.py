"""Synthesis recipes for the IRON STATIC sound effects (A1). Each function returns a mono float array; the
registry SFX maps id -> (function, peak_dbfs). Seeds are fixed per effect, so output is reproducible."""

import numpy as np

import dsp
from dsp import SR, adsr, biquad, biquad_sweep, bitcrush, drive, exp_decay, fade, fm, noise, saw, sine, square, sweep


def _n(sec):
    return int(sec * SR)


def laser_shot_v1():
    """The sketch-gate laser (2600 -> 950 Hz tick-zap). Replaced after the phone playtest (too high, rain on a tin can);
    kept only so render.py can build the old/new A/B file docs/playtests/a1/laser_ab.ogg. Not in the SFX registry."""
    n = _n(0.085)
    f = sweep(n, 2600, 950)
    body = sine(f, n) * 0.6 + dsp.tri(f * 0.5, n) * 0.25
    click = biquad(noise(n, 101), "bp", 4800, 1.2) * exp_decay(n, 0.004, 0) * 0.6
    y = (body * exp_decay(n, 0.026, 0.001) + click)
    return fade(biquad(y, "lp", 6500))


def laser_shot():
    """Weighty energy pulse (v2): 190 -> 70 Hz sine thump with a fast pitch drop, a saw one octave up low-passed so it
    carries on a phone speaker, a little band-passed noise at 300 Hz for texture. No click, nothing above 1.6 kHz."""
    n = _n(0.105)
    thump = sine(sweep(n, 190, 70), n) * exp_decay(n, 0.034, 0.003)
    mid = saw(sweep(n, 380, 150), n)
    mid = biquad(mid, "lp", 1000, 0.707) * exp_decay(n, 0.02, 0.003) * 0.6
    air = biquad(noise(n, 101), "bp", 300, 0.8) * exp_decay(n, 0.016, 0.003) * 0.25
    y = thump + mid + air
    return fade(biquad(y, "lp", 1600, 0.707), 0.002, 0.02)


def hit_metal():
    n = _n(0.22)
    env = exp_decay(n, 0.05, 0.0008)
    tone = fm(sweep(n, 640, 520), 2.76, 4.0, n, exp_decay(n, 0.04)) * env
    ring = fm(1480.0, 1.51, 2.0, n, exp_decay(n, 0.03)) * exp_decay(n, 0.07) * 0.35
    tick = biquad(noise(n, 102), "bp", 3200, 1.5) * exp_decay(n, 0.008, 0)
    return fade(dsp.reverb(tone + ring + tick * 0.7, 0.25, 0.6, 0.15))


def crit():
    n = _n(0.45)
    env = exp_decay(n, 0.11, 0.001)
    a = fm(1760.0, 3.5, 3.0, n, exp_decay(n, 0.08)) * env
    b = fm(2637.0, 2.0, 1.2, n, exp_decay(n, 0.05)) * exp_decay(n, 0.08) * 0.5
    sparkle = biquad(noise(n, 103), "hp", 7000) * exp_decay(n, 0.02, 0) * 0.25
    return fade(dsp.delay(a + b + sparkle, 0.07, 0.3, 0.25), 0.001, 0.02)


def enemy_death_small():
    n = _n(0.3)
    env = exp_decay(n, 0.07, 0.001)
    crunch = bitcrush(noise(n, 104), 6, 3) * env
    crunch = biquad_sweep(crunch, "bp", sweep(n, 4200, 500), 1.1)
    blip = sine(sweep(n, 520, 130), n) * exp_decay(n, 0.09) * 0.7
    return fade(drive(crunch * 2.0 + blip, 1.5))


def enemy_death_heavy():
    n = _n(0.85)
    thud = sine(sweep(n, 95, 32), n) * exp_decay(n, 0.22, 0.001)
    crash = biquad_sweep(noise(n, 105), "lp", sweep(n, 7000, 300), 0.9) * exp_decay(n, 0.2, 0.001)
    rattle = np.zeros(n)
    for i, (t0, f) in enumerate([(0.05, 410), (0.13, 330), (0.24, 560), (0.37, 250)]):
        m = _n(0.25)
        s = _n(t0)
        h = fm(f, 2.76, 3.0, m, exp_decay(m, 0.05)) * exp_decay(m, 0.08) * (0.4 / (1 + i * 0.5))
        rattle[s : s + m] += h[: n - s]
    y = drive(thud * 1.2 + crash * 0.9 + rattle, 2.0)
    return fade(dsp.reverb(y, 0.8, 0.7, 0.22), 0.001, 0.05)


def player_hit():
    n = _n(0.32)
    thud = sine(sweep(n, 130, 48), n) * exp_decay(n, 0.09, 0.001)
    body = biquad(noise(n, 106), "lp", 700) * exp_decay(n, 0.04, 0.001) * 0.8
    return fade(drive(thud + body, 2.5), 0.001, 0.03)


def wave_start():
    n = _n(1.0)
    t = dsp.t_axis(n)
    lo = saw(49.0, n) + saw(49.4, n) * 0.8
    lo = biquad_sweep(lo, "lp", sweep(n, 120, 520), 1.5)
    pulse = 0.55 + 0.45 * np.sin(2 * np.pi * 3.0 * t - 1.2)  # two slow swells
    env = adsr(n, 0.04, 0.2, 0.8, 0.4, hold=0.55)
    sub = sine(49.0, n) * 0.8
    return fade(dsp.reverb((lo * 0.5 + sub) * env * pulse, 0.9, 0.78, 0.25), 0.005, 0.1)


def boss_warn():
    n = _n(2.4)
    t = dsp.t_axis(n)
    f = sweep(n, 52.0, 110.0, "lin")
    y = saw(f, n) + saw(f * 1.007, n) + saw(f * 0.5, n) * 0.8
    y = biquad_sweep(y, "lp", sweep(n, 160, 1400), 2.0)
    trem = 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 2.5 * t)) * 0.5 + 0.2 * np.sin(2 * np.pi * 2.5 * t)
    env = np.minimum(1.0, t / 0.5) * np.minimum(1.0, (t[-1] - t) / 0.35)
    y = drive(y * env * trem * 0.6, 2.2)
    return fade(dsp.reverb(y, 1.1, 0.8, 0.25), 0.01, 0.2)


def upgrade_buy():
    """Short click-chirp (A1-02 design: repeat-buy pitch steps are applied at runtime via pitch_scale)."""
    n = _n(0.13)
    f = sweep(n, 760, 1350)
    chirp = square(f, n, 0.35) * 0.25 + sine(f, n) * 0.5
    click = biquad(noise(n, 109), "hp", 2500) * exp_decay(n, 0.003, 0) * 0.5
    y = chirp * exp_decay(n, 0.045, 0.001) + click
    return fade(biquad(y, "lp", 7000), 0.0005, 0.01)


def ui_tap():
    n = _n(0.06)
    tone = sine(1250.0, n) * exp_decay(n, 0.012, 0.0005)
    tick = biquad(noise(n, 110), "bp", 3000, 1.0) * exp_decay(n, 0.004, 0) * 0.5
    return fade(tone * 0.7 + tick, 0.0003, 0.01)


def ui_deny():
    n = _n(0.26)
    t = dsp.t_axis(n)
    gate = ((t % 0.12) < 0.085).astype(float) * np.minimum(1.0, (t % 0.12) / 0.004)
    y = square(sweep(n, 190, 150, "lin"), n, 0.5) * 0.6 + saw(95.0, n) * 0.4
    y = biquad(y, "lp", 900) * gate * np.minimum(1.0, (t[-1] - t) / 0.03)
    return fade(y, 0.001, 0.02)


def death():
    n = _n(2.6)
    t = dsp.t_axis(n)
    f = sweep(n, 1500, 38, "exp")
    wob = 1.0 + 0.015 * np.sin(2 * np.pi * 7.0 * t)
    y = fm(f * wob, 1.0, 1.8, n, exp_decay(n, 0.7)) * 0.6 + saw(f * 0.5, n) * 0.25
    y = biquad_sweep(y, "lp", sweep(n, 6000, 150), 1.2)
    hiss = biquad(noise(n, 112), "hp", 5000) * exp_decay(n, 0.25) * 0.08
    env = np.minimum(1.0, t / 0.01) * np.exp(-t / 1.5)
    thump_n = _n(0.4)
    thump = sine(sweep(thump_n, 80, 30), thump_n) * exp_decay(thump_n, 0.12, 0.001) * 0.9
    out = (y + hiss) * env
    s = _n(1.9)
    out[s : s + thump_n] += thump[: n - s]
    return fade(dsp.reverb(out, 0.9, 0.75, 0.2), 0.005, 0.15)


# id -> (function, target peak dBFS). Loudness shaping beyond this is done by the runtime slot volume_db.
SFX = {
    "sfx_laser_shot": (laser_shot, -10.0),
    "sfx_hit_metal": (hit_metal, -9.0),
    "sfx_crit": (crit, -9.0),
    "sfx_enemy_death_small": (enemy_death_small, -8.0),
    "sfx_enemy_death_heavy": (enemy_death_heavy, -4.0),
    "sfx_player_hit": (player_hit, -5.0),
    "sfx_wave_start": (wave_start, -6.0),
    "sfx_boss_warn": (boss_warn, -5.0),
    "sfx_upgrade_buy": (upgrade_buy, -10.0),
    "sfx_ui_tap": (ui_tap, -12.0),
    "sfx_ui_deny": (ui_deny, -10.0),
    "sfx_death": (death, -4.0),
}


def render_fn(fn, peak):
    """Render an alternate recipe at the given peak (the old laser for the A/B file)."""
    y = fade(dsp.remove_dc(fn()), 0.0005, 0.008)
    return dsp.normalize_peak(y, peak)


def render(sfx_id):
    fn, peak = SFX[sfx_id]
    # DC removal shifts the faded ends off zero: re-fade the first 0.5 ms / last 8 ms so no file starts or ends with a step.
    y = fade(dsp.remove_dc(fn()), 0.0005, 0.008)
    return dsp.normalize_peak(y, peak)


CORE = tuple(SFX)  # the 12 sounds approved at the A1-GATE (sketch pack); never reordered

import sfx2  # noqa: E402  (A1-08: the other 28 ids)

SFX.update(sfx2.SFX2)

# Reel / table order = the id order of 07 s7 (core ids included).
ORDER = (
    "sfx_laser_shot", "sfx_hit_metal", "sfx_crit", "sfx_overcrit", "sfx_enemy_death_small", "sfx_enemy_death_heavy",
    "sfx_player_hit", "sfx_integrity_warn", "sfx_skin_burn", "sfx_wave_start", "sfx_boss_warn", "sfx_boss_death",
    "sfx_upgrade_buy", "sfx_milestone_x15", "sfx_draft_open", "sfx_draft_pick", "sfx_cache_open", "sfx_pod_heal",
    "sfx_razor_spin", "sfx_shock_ring", "sfx_mine_beep", "sfx_arc", "sfx_emp", "sfx_missile_launch",
    "sfx_singularity", "sfx_dilation", "sfx_nanite", "sfx_overdrive_on", "sfx_overdrive_off", "sfx_aegis_break",
    "sfx_reboot", "sfx_meltdown", "sfx_purge", "sfx_ui_tap", "sfx_ui_deny", "sfx_lab_complete", "sfx_firmware_pick",
    "sfx_gauntlet_rank_up", "sfx_death", "sfx_results_tally",
)
assert sorted(ORDER) == sorted(SFX), "ORDER must list every SFX id once"
