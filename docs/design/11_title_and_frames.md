# 11 - Title Screen and Cinder Frames

Changelog: 2026-11-09 (frame balance pass after the Q54 retune: BULWARK and STRIKER final values, passive strengths are data columns `bastion_cap_frac`, `overclock_per_kill`, `overclock_cap`; SimVersion 2 so frame records of version 1 no longer replay) - 2026-11-08 v1.0 - first version. User scope addition to M3 ("M3 part B"): a smoky wasteland title screen and selectable Cinder frames for replayability. The user delegated the design choices; the numbers are starting values for the balance pass. Tasks: `docs/tasks/M3.md` M3-21 to M3-32. Visual rules follow `10_art_bible.md` and the IP guardrails of CLAUDE.md.

Scope tags: Title screen and frames VANGUARD, BULWARK, STRIKER = MVP (M3). SALVAGER and LONGSHOT = defined in data now, implemented and shown in M6 (Launch).

---

## 1. Cinder frames

A frame is the chassis configuration Cinder deploys in. Frames are **sidegrades, not upgrades**: each is stronger in one way and weaker in another, so a player may prefer a different frame depending on the situation, and the total power stays comparable (balance rule in section 1.4).

### 1.1 Rules
- Data: `data/frames.csv` -> generated `FrameDef` `.tres` (same pipeline as every table; ids below are stable).
- **Unlocked by play, never sold.** Unlock keys are `best_s1` (best wave reached in sector 1, the same progress key as 05 section 7). Cosmetic skins for frames are a later monetization question (06), not part of this document.
- **Frame mods multiply the base stats, then the Foundry applies on top** (02 section 5: `final = base x frame x run_factor x foundry_mult x external`). The Foundry is shared by all frames (a Foundry level helps every frame). Frame bonuses are not Foundry levels and do not count toward any cap on levels.
- The selected frame id is part of the run config, written in the run record header and the input log header and in the run snapshot; it is deterministic. **VANGUARD uses neutral modifiers: with it every state hash, golden and replay recorded before M3 stays valid, and no `SimVersion` bump is needed for frames (2026-11-09: the Q54 early-curve retune itself bumped it to 2, VANGUARD is still neutral).** Frame passives live in the pure sim (`src/sim/`) with unit tests; they use integer ticks and existing RNG streams only (none needs randomness).
- The selected frame is chosen between runs (frame bay, section 3), never in a run. The profile stores unlocked frames and the selected frame.
- Leaderboards (Launch, backend) are global; the submission carries the frame id and the UI shows a frame icon (09 Q65).

### 1.2 The frames (starting values, tunable)
| id | Name | Role | Stat modifiers | Passive | Unlock | Tag |
|---|---|---|---|---|---|---|
| `vanguard` | VANGUARD | Balanced baseline and the reference for balance | none (all x1.0, +0) | none | start | MVP |
| `bulwark` | BULWARK | Tank: outlasts, slower to kill | `hull_integrity` x3.00, `plating_pct` +0.10, `nano_repair` x1.30, `cycle_rate` x0.80, `laser_output` x1.30, `optic_range` x0.92 (final values, 2026-11-09, SimVersion 2) | **Bastion:** no single hit deals more than 20% of Cinder's max hull (`bastion_cap_frac`, data) | `best_s1` 8 | MVP |
| `striker` | STRIKER | Glass cannon: fast, fragile, short-sighted | `cycle_rate` x1.30, `crit_chance` +0.03, `laser_output` x0.85, `hull_integrity` x0.50, `nano_repair` x0.70, `optic_range` x0.80 (final values, 2026-11-09, SimVersion 2) | **Overclock:** each kill grants +1% fire rate for the rest of the wave (`overclock_per_kill` 0.01, `overclock_cap` 0.20, both data; resets at the next wave start) | `best_s1` 15 | MVP |
| `salvager` | SALVAGER | Economy: slower kills, better income | `scrap` income x1.25, `data` income x1.10, `laser_output` x0.85 | **Scrap Tithe:** bonus `scrap` from heavy kills (walker, lancer, bosses; exact numbers at M6) | M6 | M6 |
| `longshot` | LONGSHOT | Sniper: reach and burst, slow cadence | `optic_range` x1.33, `laser_output` x1.40, `crit_mult` x2.0 of the base multiplier step, `cycle_rate` x0.60 | **First Sight:** the first shot at a newly acquired target always crits | M6 | M6 |

Implementation notes (impl, starting points): modifiers enter `StatResolver` as the existing `ExternalMults` (a per-stat multiplier and additive bonus; multiplier-type stats multiply after clamping, additive stats add before clamping), so no formula changes. `cycle_rate` after the frame multiplier may exceed the Type C hard cap of 12 only if the frame multiplier is applied after the clamp; the task states which and tests it. Bastion applies at the single point where damage is applied to Cinder (the 20% cap uses max hull including Foundry). Overclock keeps one per-wave integer counter in sim state (hashed only when the frame is not VANGUARD, saved in the snapshot, reset at wave start). SALVAGER and LONGSHOT rows are loaded and validated but the frame bay does not list them and the sim rejects them until M6 (`implemented` column false).

### 1.3 Unlock presentation
- A frame unlocks when a banked run raises `best_s1` to its threshold: the Results screen shows a one-line "FRAME UNLOCKED: BULWARK" chip under the best-wave row (the Foundry/FRAME actions follow). The frame bay shows locked frames with their condition ("REACH WAVE 8") and a locked silhouette (not hidden: the bay is where the goal is shown; Home and the title only show the selected frame).
- A new profile has only VANGUARD. NEW GAME on an existing profile resets unlocks together with everything else (section 2.4).

### 1.4 Balance acceptance (gates for the M3 frames, measured with `balance_run --frame <id>`)
**Final result (2026-11-09, after the Q54 retune, SimVersion 2; 40 seeds, fresh profile, VANGUARD greedy4 11.55 / idle 8.13):** BULWARK greedy4 12.30 (+6.5%), idle 8.70 (+7.1%, wins idle); STRIKER greedy4 12.43 (+7.6%, wins greedy4), idle 8.45 (+4.0%). Both stay inside the identity bounds (STRIKER cycle >= 1.30, hull <= 0.75, laser 0.85-1.0; BULWARK cycle <= 0.80, hull >= 1.4). Levers: BULWARK hull x3.0 and laser x1.3 (cycle 0.80 alone loses 33%); STRIKER optic x0.80 (the shorter reach costs it kills). On the `foundry_300` profile the frames spread more (BULWARK +30.1%, STRIKER +15.6% vs VANGUARD): the gate is the fresh profile, tracked in Q67. Details: `docs/playtests/m3/balance_m3.md`.
1. On a **fresh profile** (no Foundry), each M3 frame's mean death wave over at least 40 runs of the `greedy4` policy is within +-10% of VANGUARD's (the median alone is too coarse at waves 8-10; report both).
2. Each M3 frame **wins at least one scenario** against VANGUARD: BULWARK with an idle policy that never buys (`--policy none`: only its starting stats matter), STRIKER with the greedy active buyer (`greedy4`). "Wins" means a higher mean death wave over at least 40 runs with the same seeds.
3. Tuning is done only in `data/frames.csv` (config, no sim change). If the targets cannot be met without a sim change, the task stops and reports.
4. VANGUARD's results and all goldens are identical to the pre-frame numbers.

### 1.5 Visuals
Each frame is a variant of the layered Cinder SVG rig (art bible section 4.3): same layer names and pivots so the rig code is shared; the variant swaps or adds layers and trim material. VANGUARD is today's rig. **BULWARK:** wider, heavier plates, a broader shoulder block, bronze trim. **STRIKER:** slimmer vented plates, a twin emitter, white-hot trim. All within the art bible and the IP guardrails (no skull, no endoskeleton, no chrome skull with red eyes, no half-flesh face). The silhouette of each frame must be distinguishable from the others at 96 px (readability check as in V1-19).

---

## 2. Title screen

### 2.1 Look
A smoky wasteland of metal and machine at dusk, portrait first, drawn with Claude-authored SVG layers in the V1 style (amber primary light, gunmetal, warm ember accents; no franchise imagery).
- **Parallax layers** (back to front, 4 to 5 sprites, slow horizontal drift and a small vertical offset; drift off under reduce motion): sky/glow band, distant broken spires and cooling towers, mid toppled machine hulks, near scrap ridges with half-buried plates and gears, a foreground ridge.
- **The SELECTED frame silhouetted on a ridge** in the mid-ground with its core glowing (a small additive glow sprite, pulse off under reduce motion). The silhouette is the frame's rig drawn flat (unlit) or a dedicated silhouette sprite per frame.
- **Smoke and fog:** 2 to 3 procedural layers from a cheap fbm noise shader (value noise, 3 octaves, drifting at different speeds, additive or alpha-blended, amber-tinted low light). **Embers:** rising embers through the existing particle system (`ParticlePack` path, no new renderer). **Distant flare:** an occasional (every 8 to 20 s, seeded by the view's own RNG, never the sim RNG) brief sky flash with a faint ground light change.
- **Logo:** "IRON STATIC" in the heading font on a chamfered plate or free-floating, with a static/glitch shimmer shader (occasional horizontal tear and channel offset, 0.15 s, at most every few seconds; off under reduce motion; text stays readable at all times).
- Fade-in from black on first show (about 0.6 s); this fade hides the shader warm-up (`ShaderWarmup`, TECH_ARCHITECTURE 2.8): the warm-up runs behind it.

### 2.2 Buttons and flow
- Buttons (V1 plates, touch targets at least 148 px): **CONTINUE** (shown only when a save exists with progress), **NEW GAME**, **SETTINGS**.
- Flow: boot -> TITLE -> NEW GAME -> (confirm dialog when it would overwrite progress) -> **frame bay** -> HOME -> DEPLOY (M4-26: on a fresh profile the bay's CONFIRM goes to the **cold open** (07 s3) and then straight into run 1; only the bay opened from the title does this). CONTINUE -> HOME, or straight into the resumed run (paused behind the overlay) when a run snapshot exists (05/TECH 5.3). SETTINGS opens the settings screen and returns to the title.
- A save exists when the loaded profile has `runs_total > 0`, any Foundry level, or `run_counter > 0`. A fresh install shows only NEW GAME and SETTINGS.
- The CONTINUE / resume destination is decided by `AppFlow` (M3-14 extended by M3-30); the title never starts a run itself.

### 2.3 Quality, budget and layout
- Budget: **at most about 15 draw calls on the title** (counted with the rendering info draw-call counter in a test scene and recorded). Draw plan: 5 parallax + 3 smoke + 1 embers + 1 logo + 1 frame silhouette/glow + 3 button/plate = 14.
- Quality tiers (`VisualQuality`): HIGH/MID all effects (MID: 2 smoke layers); **LOW: 1 smoke layer, no embers, no distant flare**. Reduce motion: no drift, no logo shimmer, no flare, smoke frozen (static noise offset), embers off.
- Layouts: portrait plus the wide layout (`LayoutMode`): in WIDE the scene is cropped from the sides of the art (parallax layers are 2160 base px wide) and the buttons stack in the 1080 column at the right or center; the safe area insets apply; all text inside the safe area.
- Back gesture on the title: opens a **QUIT?** confirm dialog (YES quits, NO or back again closes it).
- Audio: the menu ambient music layer (`in_menu` music state) plus a new wind/metal ambience (SFX request in section 4). UI taps through `AudioHooks`.

### 2.4 NEW GAME semantics (09 Q66)
- No progress: NEW GAME goes straight to the frame bay.
- Existing progress: a **confirm dialog** ("START OVER? THIS ERASES YOUR PROGRESS.", YES / NO). YES **resets the profile**: the old files are renamed (never deleted) to `*.reset` copies so an accident can be recovered with `save_dump` and support, then a fresh profile is created. The settings (sound, shake, ...) are kept across a reset (impl: they are device preferences).
- A profile reset also lives in **Settings > Data** behind a **double confirm** (two separate dialogs; the second names the amount of `data` and the best wave about to be lost). It does the same reset and returns to the title.

---

## 3. Frame bay (frame select)

Reached from NEW GAME, and from a frame chip on Home (visible after the first death). **Implemented (2026-11-09):** the Home chip "FRAME: VANGUARD  >" is a 148 px plate button (`frames_pressed`, `AppFlow` HOME -OPEN_FRAMES-> FRAME_BAY); the bay returns to its opener, so CONFIRM and back go to Home when opened from Home, and back goes to the title after NEW GAME. A "NEW" marker is not built (it needs a profile "seen" field). One screen, V1 kit, wide layout like the Foundry.
- A carousel or vertical list of frame cards (swipe or tap): silhouette, name, role line, **stat comparison against the selected/current frame** (`hull`, `fire rate`, `damage`, `range`, `crit`, `repair` as arrows and percentages computed from the frame mods, not hand-written), the passive name and one line, and the lock state ("REACH WAVE 8" with progress "BEST W5").
- SELECT button on an unlocked frame (disabled look and `AudioHooks.deny` on a locked one); the selected frame has a `SELECTED` tag. Selecting persists immediately (`request_save`) and the Home diorama and the title silhouette change. Changing the frame never refunds or costs anything.
- A preview line shows the Power Rating of the frame with the current Foundry levels (`PowerRating` of the resolved start stats) so the comparison includes permanent progress.

---

## 4. Audio request (for the audio pipeline, A1 slots)
New looping ambience slots in `assets/audio/slots.csv` (rendered by `tools/audio_gen/`): `amb_wasteland_wind` (low filtered wind, slow gusts, 30 to 40 s seamless loop, quiet) and `amb_metal_creak` (sparse distant metal groans and settling clinks, 40 to 60 s seamless loop, quiet, no rhythmic pattern, no melody; same IP rules as 07 section 7: nothing that echoes a film theme). Both play on the AMBIENCE/SFX bus under the title and Home only (not in battle), faded with the music state `in_menu`. Owner: the audio agent, after it finishes its current work.

---

## 5. Out of scope
Frame-specific cosmetics and skins, frame-specific Foundry rows, per-frame leaderboards (Q65 default: global with an icon), SALVAGER and LONGSHOT behavior (M6), a story intro or cinematic, title-screen news or ads.
