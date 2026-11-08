# M1 playtest - core combat prototype

Question sheet from `docs/ROADMAP.md` section 3 (M1 "User playtest") and the FC8 preview in
`docs/design/08_mvp_scope.md`. Fill in what you can; blanks are fine. You can also answer in chat.

## Session (fill in)

- Date:
- Build: `3806bde` or later (run `git log -1 --oneline`)
- Device: emulator `tower_phone` / phone model:
- Speed used: 1x / 2x
- Runs watched:

## How to run it

The emulator `tower_phone` may already be running a fresh deployment. If not:

```
powershell -NoProfile -File C:\dev\tower\tools\run_emulator.ps1
powershell -NoProfile -File C:\dev\tower\tools\deploy_android.ps1 -ProjectPath C:\dev\tower -Package com.ironstatic.game -Preset IronStatic
```

A fresh Cinder has no upgrades yet (they arrive in M2), so expect death around wave 7-8, about
3 minutes in. Tap REDEPLOY on the results screen for another run. Debug overlay: double tap (or
long press) the top-left corner; B0-B3 force a skin-burn band, AUTO returns to normal.

## Questions

### 1. Is the swarm readable?
Can you tell the enemy types apart (skitter triangle, dart chevron, walker trapezoid, lancer
diamond with barrel, boss square-hex)? Are they big enough? (Enemies are about 15-30 px wide.)
- Answer:
- Readability 1-5:

### 2. Does the beam read as a laser?
The hitscan beam flashes for 80 ms per shot.
- Answer:

### 3. Do the skin-burn bands read at a glance? (FC8 preview)
As integrity drops, Cinder's synthetic skin chars and burns away (bands 0-3). Could you tell Cinder
was in trouble without reading the numbers? Any flicker?
FC8 bar for M5: 8/10 testers identify the low-health band without numbers; no visible flicker.
- Answer:
- Legibility 1-5:

### 4. Does the machine-vision look feel right?
Amber HUD, teal for Cinder, red enemies, magenta enemy fire, dark polar grid.
- Answer:
- Look 1-5:

### 5. Is the first-run length right? (open question Q38)
About 3 minutes and death at wave 7-8 with no upgrades. (The M5 target with upgrades bought is
2-4 minutes and wave 9-14.)
- Answer:

### 6. Smoothness and stability
Any stutter at 1x or 2x, freezes, or crashes? (The emulator on this laptop's Intel graphics shows
14-34 fps; a real phone is needed for a real frame-rate verdict, Q23/Q40.)
- Answer:

## Free notes

-

## Bugs seen

| What | When (wave / time) | Screenshot |
|---|---|---|
| | | |

<!-- Report section is added by the playtest-report skill (mode analyze m1) after the answers. -->
