# Credits and sources

IRON STATIC is original work. This page lists where its art, audio and fonts come from and the licenses of the components bundled with it.

## Art

Claude-authored layered SVG sprites: Cinder and its three frames, the five enemies, the bolt, an effects sheet, the UI kit, 25 icons, the arena floor and the title-screen layers. They live in `assets/art/src/` and `assets/art/title/src/`.

Every sprite sits in a named slot in [`assets/art/slots.csv`](https://github.com/paimonsoror/iron-static/blob/main/assets/art/slots.csv), so a commissioned set can replace it file by file with no code change. The SVGs are linted (`tools\art_lint.ps1`) and pixel-checked (`tools\art_check.ps1`). Art direction: [`docs/design/10_art_bible.md`](https://github.com/paimonsoror/iron-static/blob/main/docs/design/10_art_bible.md).

## Audio

Original Claude-synthesized sound effects, music layers and menu ambience, in swappable slots ([`assets/audio/slots.csv`](https://github.com/paimonsoror/iron-static/blob/main/assets/audio/slots.csv)). No samples are used. The sketch pack and notes are in [`docs/playtests/a1/`](https://github.com/paimonsoror/iron-static/blob/main/docs/playtests/a1/A1-01_sketch.md).

## Fonts

Oxanium (body and headings) and Share Tech Mono (numbers), both under the SIL Open Font License 1.1. Sources, hashes and license texts: [`assets/fonts/LICENSES.md`](https://github.com/paimonsoror/iron-static/blob/main/assets/fonts/LICENSES.md).

## Bundled components

| Component | License |
|---|---|
| GdUnit4 test framework (`addons/gdUnit4`) | MIT, copyright Mike Schulze (`addons/gdUnit4/LICENSE`) |
| Play Billing, AdMob, Nakama client, Sentry plugins | See each addon folder; listed in [`docs/setup/plugin_matrix.md`](https://github.com/paimonsoror/iron-static/blob/main/docs/setup/plugin_matrix.md) |

## The game's own license

No license has been chosen yet, so all rights are reserved by default. The third-party components above keep their own licenses.
