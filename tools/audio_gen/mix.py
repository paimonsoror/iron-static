"""Loudness scheme (A1-09). Files keep their recipe peaks; the per-slot `volume_db` brings every SFX to one effective
level per category: effective LUFS-ish = file loudness (analyze.stats, ungated K-weighted) + volume_db. Usage:
    mix.py --write-slots      rewrite volume_db of every sfx row in assets/audio/slots.csv from CATEGORY/TARGETS
    mix.py --table            print the loudness table (markdown) and the wave-60 load simulation
render.py also uses trim_db() so the full reel is rendered with the same trims. Deterministic (fixed seeds)."""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I mode ignores the script dir
import amb  # noqa: E402
import analyze  # noqa: E402
import sfx  # noqa: E402
from dsp import SR  # noqa: E402

REPO = Path(__file__).resolve().parents[2]

# Effective loudness targets (LUFS-ish after the slot trim), by category. Music layers stay at 0 dB (-22 to -28 each,
# about -22 summed, played at the AudioSettings default of 0.7 = -3 dB), so combat SFX sit around or below the music
# in the ungated number and "events" and "big" moments clearly above it; the Music bus also ducks under the SFX bus.
TARGETS = {
    "tick": -33.0,  # plays 10-30x per second: soft and non-fatiguing
    "frequent": -27.0,  # hits, small deaths: several per second
    "ui": -27.0,  # taps and confirmations
    "event": -21.0,  # discrete combat moments
    "stinger": -21.0,  # wave start, rewards, results
    "big": -18.0,  # rare big moments: boss, death, overdrive, meltdown
}
CATEGORY = {
    "tick": ["sfx_laser_shot", "sfx_razor_spin", "sfx_mine_beep", "sfx_nanite", "sfx_arc", "sfx_pod_heal"],
    "frequent": ["sfx_hit_metal", "sfx_enemy_death_small", "sfx_crit"],
    "ui": ["sfx_ui_tap", "sfx_upgrade_buy", "sfx_draft_pick", "sfx_firmware_pick", "sfx_cache_open", "sfx_ui_deny"],
    "event": [
        "sfx_overcrit", "sfx_player_hit", "sfx_integrity_warn", "sfx_skin_burn", "sfx_shock_ring",
        "sfx_missile_launch", "sfx_enemy_death_heavy", "sfx_aegis_break", "sfx_dilation", "sfx_purge",
    ],
    "stinger": [
        "sfx_wave_start", "sfx_milestone_x15", "sfx_draft_open", "sfx_lab_complete", "sfx_gauntlet_rank_up",
        "sfx_results_tally",
    ],
    "big": [
        "sfx_emp", "sfx_singularity", "sfx_overdrive_on", "sfx_overdrive_off", "sfx_reboot", "sfx_meltdown",
        "sfx_boss_warn", "sfx_boss_death", "sfx_death",
    ],
}
# Per-id target overrides (same unit): a crit must read over plain hits, a deny over a tap, the wave start over music.
OVERRIDE = {"sfx_crit": -24.0, "sfx_ui_deny": -24.0, "sfx_wave_start": -22.0}
# Ambience loops (M3-31) are their own category: far below the music (menu pad = -26.4 LUFS-ish x 0.8 menu level), so
# together they sit at least 6 dB under the lowest layer that plays with them, in RMS and in LUFS-ish (checked in main()).
AMB_TARGETS = {"amb_wasteland_wind": -37.0, "amb_metal_creak": -40.0}
AMB_MARGIN_DB = 6.0
PAD_MENU_RMS_DB = -24.0 + 20 * np.log10(0.8)  # music_pad RMS (music.LAYER_RMS_DB) at its menu_level
PAD_MENU_LUFS_DB = -26.4 + 20 * np.log10(0.8)  # music_pad file loudness (A1-01 sketch) at its menu_level
CEILING_DB = -1.0  # peak after the trim, before the Master limiter (-0.5 dB ceiling)

_BY_ID = {sid: cat for cat, ids in CATEGORY.items() for sid in ids}
assert sorted(_BY_ID) == sorted(sfx.SFX), "every SFX id needs exactly one category"


def category(sid):
    return "ambience" if sid in AMB_TARGETS else _BY_ID[sid]


def target(sid):
    if sid in AMB_TARGETS:
        return AMB_TARGETS[sid]
    return OVERRIDE.get(sid, TARGETS[_BY_ID[sid]])


def trim_db(sid, y):
    """volume_db for the slot (0.5 dB steps), limited so the trimmed peak stays at or below CEILING_DB."""
    st = analyze.stats(y, loop=False)
    trim = round((target(sid) - st["lufs_ish"]) * 2) / 2
    room = CEILING_DB - st["peak_dbfs"]
    return float(min(trim, np.floor(room * 2) / 2))


def _all():
    out = {}
    for sid in sfx.ORDER:
        y = sfx.render(sid)
        out[sid] = (y, trim_db(sid, y))
    for aid, (fn, _) in amb.LOOPS.items():
        y = fn()
        out[aid] = (y, trim_db(aid, y))
    return out


def check_ambience(rendered):
    """Raises when an ambience loop is not at least AMB_MARGIN_DB under the menu pad (RMS and LUFS-ish)."""
    for aid in amb.LOOPS:
        y, v = rendered[aid]
        st = analyze.stats(y, loop=False)
        assert st["rms_dbfs"] + v <= PAD_MENU_RMS_DB - AMB_MARGIN_DB, (aid, st["rms_dbfs"] + v)
        assert st["lufs_ish"] + v <= PAD_MENU_LUFS_DB - AMB_MARGIN_DB, (aid, st["lufs_ish"] + v)


def write_slots(rendered):
    path = REPO / "assets" / "audio" / "slots.csv"
    lines = path.read_text(encoding="utf-8").split("\n")
    out = []
    for ln in lines:
        parts = ln.split(",")
        if len(parts) == 7 and parts[0] in rendered:
            v = rendered[parts[0]][1]
            parts[3] = ("%g" % v) if v != int(v) else str(int(v))
            ln = ",".join(parts)
        out.append(ln)
    path.write_text("\n".join(out), encoding="utf-8", newline="")


def table(rendered):
    rows = ["| id | category | file LUFS-ish | volume_db | effective LUFS-ish | peak after trim dBFS |", "|---|---|---|---|---|---|"]
    for sid, (y, v) in rendered.items():
        st = analyze.stats(y, loop=False)
        rows.append(
            f"| `{sid}` | {category(sid)} | {st['lufs_ish']:.1f} | {v:g} | {st['lufs_ish'] + v:.1f} | {st['peak_dbfs'] + v:.1f} |"
        )
    return "\n".join(rows)


def amb_summary(rendered):
    rows = []
    for aid in amb.LOOPS:
        y, v = rendered[aid]
        st = analyze.stats(y, loop=True)
        rows.append(f"{aid}: file rms {st['rms_dbfs']} lufs {st['lufs_ish']} peak {st['peak_dbfs']} volume_db {v:g} -> "
                    f"rms {st['rms_dbfs'] + v:.1f} lufs {st['lufs_ish'] + v:.1f} seam {st['seam_jump_ratio']}")
    return chr(10).join(rows)


def load_sim(rendered, seconds=12.0, seed=60):
    """Wave-60 style load: event rates per second with the voice caps and cooldowns of the slot table, the four music
    layers at 0.7 (default Music fader). Returns stats of the mono sum before the Master limiter."""
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    mix = np.zeros(n)
    rates = {"sfx_laser_shot": 20, "sfx_hit_metal": 14, "sfx_crit": 2, "sfx_enemy_death_small": 6,
             "sfx_enemy_death_heavy": 0.8, "sfx_player_hit": 1.5, "sfx_upgrade_buy": 0.5, "sfx_razor_spin": 2,
             "sfx_arc": 1.5, "sfx_mine_beep": 1, "sfx_nanite": 0.5}
    caps = {}
    for line in (REPO / "assets" / "audio" / "slots.csv").read_text(encoding="utf-8").split("\n"):
        p = line.split(",")
        if len(p) == 7 and p[0] in rendered:
            caps[p[0]] = (int(p[5]), int(p[6]))
    for sid, rate in rates.items():
        y, v = rendered[sid]
        g = 10 ** (v / 20)
        cap, cool = caps.get(sid, (4, 0))
        ends, last = [], -1e9
        for t in np.sort(rng.uniform(0, seconds - 1.0, int(rate * seconds))):
            ends = [e for e in ends if e > t]
            if len(ends) >= cap or (t - last) * 1000 < cool:
                continue
            ends.append(t + len(y) / SR)
            last = t
            s = int(t * SR)
            mix[s : s + len(y)] += y * g
    # music: decoded layers at 0.7
    import soundfile as sf
    music = np.zeros(n)
    for lid in ("pad", "pulse", "perc", "lead"):
        d, _ = sf.read(str(REPO / "assets" / "audio" / "music" / f"music_{lid}.ogg"))
        d = d.mean(axis=1)
        music += np.resize(d, n) * 0.7
    return analyze.stats(mix, False), analyze.stats(music, False), analyze.stats(mix + music, False)


def main():
    rendered = _all()
    check_ambience(rendered)
    if "--write-slots" in sys.argv:
        write_slots(rendered)
        print("slots.csv volume_db rewritten")
    if "--table" in sys.argv:
        print(table(rendered))
        print(amb_summary(rendered))
        for name, st in zip(("sfx only", "music only", "sum"), load_sim(rendered)):
            print(name, st)


if __name__ == "__main__":
    main()
