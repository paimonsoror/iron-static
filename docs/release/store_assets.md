# Store graphics (B1-06)

Changelog: 2026-11-10 v1.0 (B1-06, branch `b1-store`).

> **Draft: do not upload until Q31 is cleared and the user approves the set.** The name IRON STATIC is baked into the
> feature graphic and the title screenshot (Q31, the trademark search, is still open). If Q31 forces a rename, redo
> the logo art, then run `tools\store_assets.ps1` again.

## What is in `release/store/`

All files are tracked (small). They are generated; do not edit them by hand.

| File | Size | What it shows | Play slot |
|---|---|---|---|
| `icon_512.png` | 512x512 RGBA | the launcher mark (amber hexagon on Void, rounded corners) from `assets/icons/icon.svg` | App icon (alpha allowed, max 1,024 KB) |
| `feature_1024x500.png` | 1024x500 RGB | the title banner art: logo on top, Cinder and the hulks on the ridge | Feature graphic (no alpha) |
| `phone_01.png` | 1080x1920 RGB | the hook: wave 20, a crowd, the boss hulk, damage numbers, the beam | Phone screenshot 1 |
| `phone_02.png` | 1080x1920 RGB | the patch draft at wave 10: three family cards (ARMS, CHASSIS, SYSTEMS) | 2 |
| `phone_03.png` | 1080x1920 RGB | upgrades: the CHASSIS tab at wave 13 | 3 |
| `phone_04.png` | 1080x1920 RGB | the Foundry with rows bought | 4 |
| `phone_05.png` | 1080x1920 RGB | the Frame Bay (BULWARK) | 5 |
| `phone_06.png` | 1080x1920 RGB | Results with NEW BEST | 6 |
| `phone_07.png` | 1080x1920 RGB | the title screen | 7 |
| `phone_08.png` | 1080x1920 RGB | Home with the TIMED and PURGE picker (optional extra) | 8 |

The exact byte sizes are printed by the validator (below). Play accepts 2 to 8 phone screenshots.

## How the pictures are made

Everything is the real game UI and art, rendered by the desktop capture harnesses into 1080x1920 SubViewports (9:16, the
shape of a 16:9 phone; the emulator is 2.22:1 and Play rejects sides beyond 2:1, so nothing is cropped or stretched).
The phone safe margins are the usual cutout 110 px and gesture bar 70 px. Nothing on screen shows a debug label.

- Battle shots: `src/debug/docs_shots.gd` with `--dx-size=1080x1920 --dx-speed=2` (scenarios `crowd`, `draft`, `upgrades`).
  They stage the run with an invulnerable Cinder and a bot that buys with scrap, which only keeps her alive to wave 20;
  the screen shows no sign of it. In the draft shot the three offers are chosen by the harness so that the three
  families show.
- Menu shots: `src/debug/store_shots.gd` (Foundry, Frame Bay, Results, title, Home) from a mid-game profile
  (14 runs, PURGE unlocked, some Foundry levels, BULWARK unlocked).
- Feature graphic: `title_frame.tscn -- --tf-banner-play=<dir>` (`TitleBanner`, play mode): the same 2160x2400 title
  stage as the README banner with a larger logo, cut 2160x1055 and scaled to 1024x500. The README banner output
  (1280x640) is unchanged. The logo text is about 60 px tall and sits in the central 45 percent of the width, clear of
  the area Play overlays or crops. No other text is on it.
- The captures are RGBA; `src/debug/png_rgb.gd` rewrites them as 24-bit RGB PNGs (Play wants no alpha).

## Regenerate and validate

```
powershell -NoProfile -File tools\store_assets.ps1               # everything, then the validator
powershell -NoProfile -File tools\store_assets.ps1 -ValidateOnly # only the validator
python -I tools\store_assets.py --dir release\store              # the validator alone
```

The script runs Godot one process at a time and waits until 2.5 GB of RAM is free and no `java`/Gradle process runs.
Intermediate captures go to `build\store` (git-ignored). The validator is plain Python (no PIL): it parses the PNG
header and tRNS chunk and the JPEG SOF marker and checks, per file, the exact size, no alpha (except the icon), the
byte limit, an aspect ratio of at most 2:1, no duplicate files, and 2 to 8 phone shots. It prints PASS or FAIL.

## Limits used

| Item | Rule | Source |
|---|---|---|
| Icon | 512x512 PNG, 32-bit with alpha allowed, at most 1,024 KB | Play Console help |
| Feature graphic | 1024x500, JPEG or 24-bit PNG, no alpha, at most 15 MB | Play Console help |
| Phone screenshots | 2 to 8; JPEG or 24-bit PNG, no alpha; each side 320 to 3,840 px; long side at most 2x the short side; at most 8 MB | Play Console help |

## Notes and open points

- **Adaptive launcher icon (task note for B1-01's owner).** `export_presets.cfg` has empty `launcher_icons/*`, so Godot
  builds the launcher icon from `assets/icons/icon.svg`. The SVG already has its own rounded square, so on a device
  with a round or squircle mask the corners may show as a darker ring, and the hexagon is inside the 66 percent safe
  zone (it spans about 54 percent of the width), so nothing is cropped. If the emulator launcher shows it badly,
  set `launcher_icons/adaptive_foreground_432x432` (hexagon and arcs on transparent, drawn within the central 288 px) and
  `launcher_icons/adaptive_background_432x432` (plain `#07090C`) in both presets. This task does not change the preset.
- **Foldable and tablet screenshots:** skipped (optional). The game is portrait only and no tablet emulator is
  configured, so there is nothing true to show. Phone shots are the only set.
- **No promo video**, no device frames, no franchise names or other games' marks in any picture.
- Before uploading, view every file once. Re-run the set after UI changes (for example the B1-08 Settings row does not
  appear in these shots, so nothing here depends on it).
