# V1-19 Readability verification (FC5 and FC8 preview)

Changelog: 2026-11-08 v1.0 (first measurement). **Pre auto-fit camera**: all captures are the 32 m camera of the V1-GATE (before V1-23). The pack is re-captured in V1-21 after the camera change; the tool and the method stay.

Device: AVD `tower_phone` (1080x2400, host GPU), debug APK with `--debug-perf`, tier HIGH, cold boot 12 min before the capture. Screenshots are `adb exec-out screencap` at 1x, overlay hidden.

## What was captured

| File | What |
|---|---|
| `V1-19_wave30_dense.png` | `D165` scenario (wave 30 loaded, sim paused, 162 enemies in the sim), band override B0. 2 bosses, 3 walkers, 5 lancers and many enemy bolts are on screen. |
| `V1-19_band0.png` .. `V1-19_band3.png` | The same frozen crowd with the debug override B0, B1, B2, B3 (view only; routed to Cinder, haze and FX). |
| `V1-19_bands_in_crowd.png` | Copy of the B2 frame (the one with the most visible wedge change). |
| `V1-19_crops/*.png` | 2x contact crops per accent class (`tools/readability_check.py crops`). |

**Limit of this capture (important):** with the 32 m camera only about 10-20 of the 162 enemies of the D165 scenario are inside the 1080x1344 field (the rest are 16 m+ away, outside the picture). So this is **not** a dense crowd test: it is a "boss and walkers touching Cinder, lancers and bolts around" frame. The skitter and dart types are not on screen at wave 30 in this composition (the pink pixels counted as `dart_pink` are mostly enemy bolts, which share the magenta family). No "31 slots wave 50" preset was added to the style frame (V1-23 changes the framing; the preset is only useful once the camera is final). A truly dense frame needs the auto-fit camera.

## Objective results (`tools/readability_check.py`, pure Python, no dependency)

Commands (repeatable): `.venv\Scripts\python.exe -I tools\readability_check.py crowd|bands|hud|crops <png...> [--cinder 540,672]`.

### FC5 crowd frame (`V1-19_band0.png`)

| Check | Threshold | Measured | Result |
|---|---|---|---|
| Walker accent regions, median size | body >= 56 px | 162 x 154 px (3 regions >= 56 px) | PASS (bible says about 112 px body; regions here include merged pairs) |
| Lancer accent regions, median size | >= 56 px | 74 x 74 px (max 144) | PASS |
| Boss (red accent, largest region) | >= 280 px | 482 px (two overlapping bosses) | PASS |
| Skitter / dart body width | >= 56 px | **not measurable**: no isolated skitter or dart in the frame | OPEN (needs a frame with them, V1-21) |
| Cinder luminance margin over the brightest enemy-accent pixel | >= 20 L* | Cinder peak L* 100.0, enemy accent peak L* 80.3, **margin 19.7** | **FAIL by 0.3 L***, see below |
| Cinder centre (r < 60 px) covered by enemy-accent pixels | < 15 % | 0.0 % | PASS |
| HUD number contrast (WCAG ratio text vs plate), B0 and B3 identical | >= 4.5 (large text 3.0) | wave 10.3, timer 15.3, integrity 15.9, scrap 9.5, data 10.0 | PASS |

Luminance margin failure: the brightest "enemy" pixels are the **white-hot reactor of the boss** (`#FF1F3D` boss with a white-hot core, by design in the V1-GATE decision 3) and the walker's lit panel lamps. Cinder's core is at L* 100 (clipped). The margin is 19.7 instead of 20 because the boss reactor is near white. Proposal (does not need a redraw): either accept the boss reactor as the one allowed exception (the boss is meant to draw the eye, art bible 5 rule 5), or cap the boss reactor glow at 0.9 so its peak is about L* 75. The main agent decides; the check is recorded as a near miss, not closed.

### FC8 preview: Cinder bands (B0..B3 in the crowd, sector mean L* at r 62..100 px, 12 wedges)

| Band | Expected plates intact | Mean L* per sector (12) | Reading |
|---|---|---|---|
| B0 | 12 | 50 47 45 48 57 51 45 46 50 46 44 46 | reference |
| B1 | 9 | 50 44 44 48 57 51 45 45 50 44 44 46 | not separable from B0 by luminance (charred plates keep the same lightness); the hue of the ember edges is the cue, needs the eye |
| B2 | 4 | 38 35 26 35 53 40 34 24 37 32 21 22 | 5 sectors drop clearly (darker frame ribs visible); the count tool says 7 intact (threshold 0.72 of B0): partial |
| B3 | 0 | 61 61 59 62 72 65 59 58 60 56 55 56 | brighter than B0 (white-hot frame ribs replace the plates), so a "dark = gone" rule cannot classify it |

The automatic 12 / 9 / 4 / 0 region count of the spec is **not reliably measurable by luminance**; what the viewed screenshots show: B0 intact gunmetal plates with amber trim; B2 half of the plates replaced by dark frame with orange crack lines and a cracked core; B3 plates gone, gold white-hot frame ribs and a white core. B1 (3 charred plates) was not visibly distinct from B0 at 1x in the crowd. **Open item for V1-21 / user:** judge whether B1 reads at 1x (a hue/ember-edge detector can be added, but the question is a human one).

### Signature features (agent review of the crops, viewed)

| Type | Signature | Seen in crops | Notes |
|---|---|---|---|
| Lancer | forward barrel + magenta lens, violet rim | yes (`lancer_violet_1.png`: barrel with ribbed neck and a glowing magenta lens on both lancers) | violet rim holds on a dark floor and under red haze |
| Walker | piston legs, orange rim, hazard front plate | yes (`walker_orange_2.png`: orange rim, lit amber vents, hazard-striped plate; it touches Cinder's emitter at the stand-off) | big dark hull, the orange rim separates it |
| Boss | reactor + clamp arms | yes (`skitter_or_boss_red_2.png`: six-armed hull, white-hot hex core in concentric rings) | the brightest object in the frame after Cinder |
| Skitter, dart | legs / swept wings and wake | **not in this frame** | measured on the earlier hold100 frame: skitter legs visible as thin red strokes (phone capture), dart shape not verified |

## What the user or testers still have to judge (not measurable here)

- **FC5 itself**: "name the enemy types from a frozen dense screenshot" is a human test (and only meaningful with the final camera and a really dense frame). The agent can only say the accents and silhouettes are distinct in the frame above.
- **FC8**: whether the player understands "armor burning away = danger" without the number (B1 especially).
- **Color blindness**: shape is the primary cue by design; red/orange/pink accents were not simulated (no simulator tool here).
- **Haze vs numbers while playing**: HUD numbers sit on opaque plates (contrast 9-16 : 1 measured, haze does not reach them); the haze behind the world is a feel question.

## Questions for the user

1. After the camera change (V1-23 auto-fit), do skitters and darts still read at the smaller sprite size (85 %)?
2. Is the boss reactor allowed to be (nearly) as bright as Cinder's core, or should Cinder win by a clear margin?
3. Do you see the difference between B0 and B1 in a real run, or should the first burn stage get a stronger cue?
4. Pink enemy bolts and dart accents are close in hue (`#FF4FD8` vs magenta bolt): keep or separate?

## Known tool limits

- Region sizes are accent-pixel bounding boxes merged with a 14 px gap: overlapping enemies merge into one region (the boss pair shows as 482 px).
- Accent classes are hue keys: skitter and boss share the red hue (told apart by size); dart pink and the enemy bolt share the magenta family.
- Cinder's centre is a fixed parameter (`--cinder 540,672` for 1080x2400; the phone's 1080x2342 cover screen needs `--cinder 540,655`).
