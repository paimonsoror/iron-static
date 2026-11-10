# Store listing texts (B1-09)

Changelog: 2026-11-09 v1.0 (B1-09, branch `b1-docs`). Refines the drafts in `PLAY_BETA_GUIDE.md` section 9 and 15 after checking them against the game (`data/strings_en.csv`, `data/sim_constants.csv`, `docs/design/`). Character counts were measured with `wc -m` on the exact text between the fences (Play counts characters, not bytes).

| Field | Limit | Text length |
|---|---|---|
| App name | 30 | 11 |
| Short description | 80 | 76 |
| Full description | 4,000 | 1,466 |
| Release notes (per release) | 500 | 351 |

Changes from the guide's draft, each checked against the build:
- "armor plates burn away" became "synthetic skin burns away": the game burns Cinder's skin to expose the frame (GDD 00, skin burn), not plates.
- PURGE is not available from the start: it unlocks by reaching a TIMED wave (`mode.locked`, `mode.unlocked_toast`). The text now says "unlock PURGE".
- Frames: VANGUARD, BULWARK, STRIKER are in the build and unlock by best wave. SALVAGER and LONGSHOT exist in the data but are M6 (`data/frames.csv`), so they are not named.
- The first patch pick is at wave 5 (`draft_first_wave,5` in `data/sim_constants.csv`; R1-04).
- Upgrade list names only things that exist (`upgrade.*` strings: laser output, cycle rate, crit, optic range, hull integrity, nano repair, plating, scrap yield, reinvest).
- The Settings feedback link is part of B1-08. If B1-08 is not in the uploaded build, delete the sentence "use the feedback link in Settings" and say "use the feedback link on the store page".
- No franchise names, no competitor names and no look-alike wording (CLAUDE.md IP guardrails; the scan command is in `docs/release/RELEASE_CHECKLIST.md`).

## Fields

- **App name:** `Iron Static` (mixed case to match the Android launcher label, user 2026-11-09; the in-game logo keeps its all-caps art)
- **Default language:** English (United States). **App or game:** Game. **Free or paid:** Free.
- **Category:** Game > Strategy. **Tags** (only those Play offers, up to 5): Strategy, Idle, Tower defense, Sci-fi, Offline.
- **Developer name:** `Paimon Sorornejad` (decided 2026-11-09, Q83; must match the privacy page).
- **Contact:** email `support@normalexception.net` (public support address on the developer domain, decided 2026-11-09, Q83), website `https://paimonsoror.github.io/iron-static/`, phone: not required. Privacy policy: `https://paimonsoror.github.io/iron-static/privacy/`. Feedback channel (open test): the Google Form URL from Q82, `[FEEDBACK FORM URL]`.

## Short description

```
Auto-fire a laser, buy upgrades, hold the line. An idle sci-fi defense game.
```

## Full description

```
You are CINDER, a reprogrammed combat cyborg at the Relay. Rogue machine swarms attack from every side. Cinder fires on her own. You decide what she becomes.

IRON STATIC is an idle defense game for your phone. Drop into a deployment, spend scrap on upgrades while the waves roll in, and see how far the line holds. When Cinder falls, the data you recovered makes the next deployment stronger.

WHAT YOU DO
- Watch Cinder auto-fire a laser at swarms that close in from all sides.
- Buy temporary upgrades with scrap during a deployment: laser output, fire rate, crits, range, hull, repair, plating and more.
- Bank data between deployments and spend it in the Foundry on permanent upgrades.
- Play TIMED waves that keep coming on a clock, then unlock PURGE waves that end only when the whole swarm is destroyed.
- Pick a patch at wave 10 and shape the rest of the deployment.
- Unlock frames (VANGUARD, BULWARK, STRIKER) that change how Cinder plays.
- Watch Cinder's synthetic skin burn away as the pressure rises.

THIS IS AN EARLY BETA
IRON STATIC is still in development. Expect rough edges, changing numbers and the occasional bug. Your feedback shapes the game: use the feedback link in Settings.

NO ADS. NO PURCHASES. NO ACCOUNT.
This beta has no ads, no in-app purchases and no sign-in. Your progress is saved on your device only. We collect no data.

Portrait, one-handed, short sessions or long idle stretches. Built for phones running Android 7 or newer.
```

## Release notes, first build

```
First beta of IRON STATIC. Play a few deployments and tell us what feels off.
Try: both wave modes (TIMED, then PURGE once it unlocks), the wave-10 patch pick, the Foundry, the three frames.
Known: first launch can show a black screen for up to 30 seconds while shaders compile.
No ads, no purchases, no account. Progress is saved on this device only.
```

Later releases: one short note per upload, plain facts (what changed, what to test). Keep the "no ads, no purchases, no account" line only while it is true.

## Graphics

Files and sizes come from B1-06 (`release/store/`): icon 512x512 PNG, feature graphic 1024x500 no alpha, at least 2 phone screenshots at 9:16 (no side more than twice the other). Check them against the franchise list before upload.
