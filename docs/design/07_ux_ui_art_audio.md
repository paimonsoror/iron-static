# 07 - UX, UI, Art and Audio

Changelog: 2026-11-11 (v0.5.2, Service Record: new screen SERVICE_RECORD opened from a RECORD tab in the Home nav row (shown with the Foundry, after the first deployment), back returns to the opener; lifetime stats (time played and deployed, deployments and best wave per mode, waves cleared, machines destroyed per enemy type, shots, crits, damage, hull damage, scrap, data, Foundry levels, patches, per-frame runs) kept in profile `extra["record"]` v1, no schema bump, committed once per banked run, seeded from older saves; all list controls ignore the mouse so touch drags scroll) - 2026-11-11 (v0.5.1-beta.2: LASER SOUND off now also silences the per-shot impact, `sfx_hit_metal` and `sfx_crit`; on the phone the impact, 7 dB louder and brighter than the shot tick, was the sound players hear as the laser) - 2026-11-10 (v0.5.1, upgrade-info: tapping an upgrade row body opens a tooltip that now leads with one plain sentence of what the stat improves (`upgrade.<id>.desc`, at most 70 characters, derived from the sim), then `Now a -> next b` from the same preview the row uses (`Now a (max)` at the level cap or a hard limit), then the unchanged formula, cap and Foundry lines; Foundry row tooltips lead with the same sentence; the tooltip stays up 4 s plus 0.05 s per character (max 12 s) and tapping the row again hides it; a data test requires a description for every run upgrade and Foundry row; presentation only, no sim change) - 2026-11-10 (v0.5.1: Settings gains LASER SOUND, default on; off silences only `sfx_laser_shot`, saved as optional `laser` in the profile settings, no schema bump) - 2026-11-10 (M4-28: s2.3 Home mode picker described, s3 lists the M4 FTUE changes) - 2026-11-10 (R1-07: readable text, view and text only; `UNAFFORDABLE` `#5C5546` -> `#8A8170` (2.6 -> 4.9:1 on PANEL, closes 09 Q48); new `AMBER_TEXT` `#B88A1E` (6.0:1) for dim-amber labels while `AMBER_DIM` `#8A5F00` stays for lines and frames; `OVER_LIMIT` `#FF8A1F` -> `#FF7A2E`; body text is Oxanium at weight 500 (the variable font defaulted to 200) through `ThemeBuilder.BODY_WEIGHT`; explanatory text over four words is sentence case, buttons, labels, titles and numbers stay capitals; a test asserts every text color is 4.5:1 or better on its background in the normal, colorblind and high-contrast palettes; normal damage numbers 30 -> 36 px; the three row hints read "TAP: MORE DAMAGE", "TAP: FIRE FASTER", "TAP: SURVIVE LONGER"; the hull hint also fires in runs 2 and 3, every other beat still stops after run 2) - 2026-11-10 (R1-04: s2.9 draft cards are image-first: a 160 px stat icon on a family-colored backing (amber ARMS, teal CHASSIS, scrap-gold SYSTEMS), the patch name, the concrete change for this run ("LASER OUTPUT 28.6 > 32.9") and pick pips; a gamble shows its cost line on a red-tinted lower band; a REROLL ALL button under the cards shows REROLLED once used; the first draft note adds the reroll) - 2026-11-10 (R1-06: beam afterglow, view only; the hot core stays 0.08 s, 0.12 s under 2 shots a second, plus a glow-layer afterglow of about 0.3 s and a faint floor scorch line of about 1 s, capped and scaled by quality tier, shortened but kept under reduce motion; R1-08: the Settings button COPY PLAY SUMMARY and the local 30-day flight recorder, nothing leaves the device unless pasted; R1-03: HUD speed control shows the chosen speed dimmed and the effective speed lit during the high-speed fall-back, speeds 1x/2x/4x/8x cycle the unlocked ones, GDD 02 s14). Earlier: 2026-11-09 (M4-25/26: s3 FTUE is data and code, `data/ftue.csv` (12 beats in the s3 order) read by `FtueScript` / `FtueState` (state in profile `extra["ftue"]`, no schema bump); only runs 1 and 2 of a fresh profile show hints; every hint is skippable (SKIP HINTS) and expires after 12 s; the cold open is its own screen after the frame bay on NEW GAME, tap or back skips it, CONTINUE never shows it; row hints point at the upgrade row, or at its tab while another tab is selected; the wave-10 draft note stays the draft overlay's own `draft.note` line; the FOUNDRY pulse is the existing Results pulse, forced on while the hint is up) - 2026-11-09 (M4-24: s5.4 colorblind palettes are live from `assets/art/palettes.csv` via `Palette.for_mode`; in the red-green modes enemy bolts become pale yellow `#FFF7B0` and low-integrity red becomes the hostile magenta-violet, so no two gameplay roles collide; high contrast makes UI text white on black plates with white edges, dims the arena floor and grid to 45 percent, and turns scanlines and motes off) - 2026-11-09 (M4-23: s4 settings gain haptics, colorblind mode and high contrast rows, stored in the profile settings, optional on read, no schema bump) - 2026-11-09 (M4-16: s2.9 draft overlay built as three stacked cards with no timer and no auto-pick; `vfx_draft_open` is two amber rings drawn by the overlay in wall time, because the sim clock is frozen behind a draft; back during a draft opens the pause menu over it) - 2026-11-09 (menu side margin: every menu screen and dialog keeps `UiKit.MENU_SIDE_MARGIN` = 100 px per side on the 1080 reference, the same as the pause card; Home heading 72 px) - 2026-11-09 (M4: s2.10 results screen is image-first: wave as the biggest text, killer sprite card, icon stat tiles, kill strip of enemy sprites with x{count}, compact unlock badges) - 2026-11-09 (pause menu: s2.1.1 new, the first back or the HUD pause opens RESUME / ABORT MISSION / EXIT GAME, back no longer quits from pause; the run record gains an optional "ended":"aborted") - 2026-11-08 (A1-08/09: s7 all 40 SFX ids are produced and slotted, five wired to existing events, loudness scheme in docs/playtests/a1/A1-01_sketch.md; A1-GATE approved by the user) - 2026-11-08 (V1-28: s2 wide layout for near-square screens) - 2026-11-08 (V1-25: s2.1 wireframe is the compact HUD, s2.2 buying rule implemented) - 2026-11-08 (A1 audio pass: s7 rewritten - Claude-synthesized audio in swappable slots, ambient-to-industrial direction, 4/4 meter rule, sfx_upgrade_buy now steps up in pitch during a hold-to-buy) - 2026-11-08 (M2-16: unaffordable-text contrast note, see 09 Q48) - 2026-11-08 - V1 visual pass: `10_art_bible.md` is now the authority for all visuals (style, sizes, sprite slots, VFX looks and budgets, HUD styling); sections 5.1, 5.3 and 5.6 below are reconciled with it (illustrated SVG sprites replace procedural-only enemies and Cinder; glow is baked additive; VFX/skin-burn polish and battle HUD styling moved from M4 to V1). Palette hex values (5.2), VFX ids (6), damage numbers (5.5), accessibility (4, 5.4) and layout/wireframes (1-3) are unchanged. 2026-11-07 - Gauntlet screen and shop Pass tab tagged P1 (not in the Launch build); title IRON STATIC (icon and splash use the title text only on the splash).

**Visual authority:** `docs/design/10_art_bible.md` (V1 visual pass). Where this chapter and the art bible differ on look, sizes, sprites, effects or budgets, the art bible wins; this chapter keeps layout, UX flows, the palette values, ids, damage-number rules, accessibility and audio.

References: genre notes [GENRE A2] recommend neon vector/glow shapes on dark with a HUD "machine vision" chrome as the cheapest way to get strong sci-fi mood while keeping enemy readability at swarm density; The Tower praised for being one-handed and well-optimized [GENRE A1, AppSpy]. Everything here is design direction; engine specifics are not prescribed. All hex values are tunable but are the starting palette.

---

## 1. Layout principles
- Reference screen: 1080 x 2400 (9:20 portrait); design for 9:16 to 9:21. Respect notches and gesture bars (safe-area insets).
- **Battlefield top 56%** (roughly y 0-1340 px), **panel bottom 44%** (y 1340-2400). Thumb zone = bottom 40%. The right thumb must reach everything in the panel; left-handed mode mirrors the panel's small buttons (Settings).
- Primary touch targets >= 56 dp, secondary >= 48 dp. Text >= 14 sp (numbers >= 16 sp). One screen = one purpose. No dialogs that cover the battlefield except drafts and results.
- The battlefield never needs a tap to progress. Optional taps: salvage caches, Overdrive, weapon-system toggles, speed button.

## 2. Screen wireframes (ASCII)

### 2.1 Battle screen (in deployment)
```
+--------------------------------------+
| WAVE 37     14s          1x  [>>] [||]|  <- line 1 (84 px): wave, time left, speed, buttons (80 px drawn, 126 px touch)
| [==========wave timer bar===========]|  <- line 2 (16 px): thin segmented timer bar
| [##########integrity##########] 80/100|  <- line 3 (48 px): integrity bar, number in its pocket
| [SCRAP 12.4K]            [DATA +3.2K] |  <- line 4 (64 px): currency chips (amber / blue)
|                                      |     HUD total about 244 px at 1080 wide, plus the safe-area inset
|         .  v  .      /\              |
|     v        \  |  /     .           |
|      .   <-- (  CINDER  ) -->  v      |   BATTLEFIELD (circle arena, enemies from all sides);
|     /\    /  |  \     .              |   Cinder is centered in the open field between the HUD
|        .      ^                      |   and the panel (BattleView.set_field_insets)
|   (OD)                  [1][2][3]    |   OD = Overdrive button (bottom-left of field)
+--------------------------------------+   weapon-system buttons (toggle) bottom-right of field
| [ARMS] [CHASSIS] [SYSTEMS] [INTEL]   |  <- upgrade panel tabs; panel height = content, max 36% of the screen
| (icon) LASER OUTPUT  L24  1.2K>1.3K  |
|        ................ [   9.8K ]   |  <- cost button: tap = +1 level, hold = repeat
| (icon) CYCLE RATE    L11  1.44>1.48  |
|        ................ [   410  ]   |
|   Next unlock at wave 3              |  <- scrolls inside when the rows exceed the cap
+--------------------------------------+
```
HUD elements (ids): `hud_wave`, `hud_sector`, `hud_timer_bar`, `hud_speed`, `hud_pause`, `hud_scrap`, `hud_data_run`, `hud_flux_orb_counter`, `hud_integrity_ring`, `hud_adapt_bars`, `hud_overdrive_btn`, `hud_weapon_btn_1..3`, `hud_boss_chip`, `hud_draft_chip`, `hud_exposure_label` (shows band when it changes), `hud_cache_ping`. Tapping `hud_wave` opens Intel.

- **Wide layout (V1-28):** when width/height >= 0.78 (foldable inner screen, tablets; back to portrait below 0.72) the upgrade panel docks to the right as a full-height column (40 percent of the width, 700-840 px), the top HUD spans only the field column (bar at most 1080 px wide) and Cinder plus the arena center in the field left of the panel. Phones keep the portrait layout above.

### 2.1.1 Pause menu and the back gesture (battle)
- **Opens** on the first Android back, the HUD pause button, the app going to the background (lifecycle) and a resumed run (with the notice line "RUN RESTORED"). The sim stops (no ticks), audio freezes.
- **Card:** centered plate (880 px wide on the 1080 reference, side margins kept) with PAUSED, an optional notice line and three stacked buttons, 160 px tall: **RESUME**, **ABORT MISSION**, **EXIT GAME**. Tapping outside the buttons does nothing. A button acts on a completed tap only (press and release on the same button, not cancelled): the gesture-navigation back swipe delivers a press and then a cancel, which must never activate anything.
- **Back, topmost first:** the ABORT MISSION confirm closes (menu stays), else a debug panel closes, else the open menu closes and **resumes** (back never quits from it), else a running battle opens the menu.
- **ABORT MISSION** asks a confirm ("ABORT MISSION?", "The run ends now. Data earned is kept.", ABORT / CANCEL). ABORT ends the run at the current tick and banks it exactly like a death (data, best wave per mode, frame and mode unlocks, run snapshot cleared), skips Results and goes Home with the toast "MISSION ABORTED: +n DATA". The run record stores the same `final_tick` plus `"ended":"aborted"` (absent = died); replays of it stop at `final_tick`.
- **EXIT GAME** saves (profile, then the run snapshot) and quits with no confirm; CONTINUE on the title resumes the run.

### 2.2 Upgrade panel details (row spec)
Each row (height 88 dp): icon (40 dp, damage-type color), name, run level `L`, current value -> next value, cost button (right, 120 dp wide). Gold ring flashes on rows within 3 levels of a x1.5 milestone (every 25 levels). Locked rows are not shown (progressive disclosure; a single "Next unlock at wave X" line at list bottom). Tapping the row body (anywhere except the cost button) opens a tooltip: line 1 a plain sentence of what the stat improves, line 2 `Now a -> next b` (`Now a (max)` at the cap), then the formula and Foundry contribution (no hidden info). **Buying (2026-11-08, user: the x1/x10/x100/Max selector was confusing; removed in V1-25 for the run panel):** there is no buy-mode selector. Tap the cost button = buy 1 level on release (a scroll drag cancels it); press and hold it = repeat buy that accelerates the longer it is held (first repeat 0.35 s, interval easing 250 -> 50 ms over 2 s, steps of 10 levels after 3 s and 100 after 6 s (impl)), stopping at the cap or when the next level is unaffordable; a drag past the tap slop cancels the hold. The panel height follows its content, capped at 36 percent of the screen height. The same rule applies to the Foundry and every other upgrade list.
```
Tabs: [ARMS]   rows: laser_output, cycle_rate, crit_chance, crit_mult, optic_range, standoff, split_*, burst_*, ricochet_*, overcrit_*, armor_tear_*
      [CHASSIS] rows: hull_integrity, nano_repair, plating_*, spike_return, siphon_cell, push_*, razor_*, shock_*, mine_*, fail_safe, barricade_*
      [SYSTEMS] rows: scrap_yield, scrap_per_wave, data_*, reinvest, free_*, pod_*, signal_lag_*, sensor_reach
      [INTEL]   panels: Wave (current enemies/weights/hp/atk), Stats (final stat values and eHP), Adapt (per type %), Log (kills, damage by type, last 3 deaths)
```
Auto-buy and priority lists (Lab) appear as a gear icon on each tab header.

### 2.3 Home screen (between runs)
```
+--------------------------------------+
| CINDER  ASH-07        PR 52   [gear] |
| flux 120   cipher 3   merit 20       |
|                                      |
|            ( CINDER idle )           |  <- battlefield area shows Cinder at rest, slow scan sweep
|          visor tracks a drifting dot |
|                                      |
|        [ SECTOR 02 v ]  best W45     |
|        [     DEPLOY     ]  [x data]  |  <- ad_data_surge chip (optional)
+--------------------------------------+
|  (content of selected menu below)    |
|  Standby patrol: 3h 20m  +12.4K      |
|    [CLAIM] [x2 watch ad]             |
|  Research: LASER TUNING L12  4h 12m  |
|                                      |
|[HOME][FOUNDRY][LAB][ARSENAL][OPS][SHOP]|
+--------------------------------------+
```
Nav items unlock progressively (02/05 unlock order); locked items are hidden, not grayed.
**Mode picker (M4-08/09, Q75):** above DEPLOY a two-segment WAVE MODE picker, TIMED | PURGE, each segment a touch target of at least 148 px with a margin between them; the selected one is lit amber and shows its one-line description (`mode.timed.desc`, `mode.purge.desc`). The last chosen mode is stored in the profile and preselected, and REDEPLOY from Results repeats it. A locked PURGE is dimmed, cannot be selected and shows "Reach wave 20 in TIMED to unlock" with "Best TIMED wave: n" (the number comes from `wave_modes.csv`); tapping it only shows that condition. When the TIMED best first reaches the threshold a one-time "PURGE MODE UNLOCKED" chip is shown on Home and a badge on Results. The Home best line reads "BEST TIMED n" and "BEST PURGE n"; the battle HUD shows a MODE chip, and in PURGE the wave counter shows "n LEFT" (the quota) with a backstop timer on the Intel Wave panel.

### 2.4 Foundry
```
| FOUNDRY                     DATA 12.4K |
| [ARMS][CHASSIS][SYSTEMS]               |
| LASER OUTPUT  F42   x10.1 -> x10.7     |
|   next milestone F50 (x1.25)    [ 18.7K]|
| HULL INTEGRITY F38  x8.6 -> x9.1        |
|   ................................ [ 9.2K] |
| NANO REPAIR F30 ...                    |
| (Recommended glow on cheapest milestone-adjacent) |
```
### 2.5 Lab
```
| R&D LAB                       FLUX 120 |
| SLOT 1  LASER TUNING L12   [###---] 4h12m   [RUSH 13f] [AD -30m 2/6] |
| SLOT 2  LAB SPEED L4       [#-----] 55m     [RUSH 1f]  [AD]          |
| SLOT 3  (locked: 250 flux) [UNLOCK]                                  |
| Catalogue: Core | Tuning | Systems | Enemy studies  [search]         |
|  LASER TUNING L12 -> L13 +2%   time 7.1h   cost 2.3K   [START]       |
```
### 2.6 Arsenal (tabs: Weapons | Firmware | Drones | Modules)
```
| ARSENAL  [WEAPONS][FIRMWARE][DRONES][MODULES(P)] |
| Weapon slots [ARC][EMP][  +400f ]               |
| ARC DISCHARGE  A L12 B L8 C L10  next: [A 3.4K] |
| Offers (3): [Singularity 20c] [Painter 20c] [Grid 20c]  (unlock cost 20 cipher) |
| FIRMWARE: slots 5/8  presets [1][2][3]            |
|  chip grid 4x6 with stars, tap = detail, drag = equip |
|  [PICK 1 OF 3  45 flux]  odds (i)                 |
```
### 2.7 Shop
```
| SHOP                         flux 120  |
| [Flux][Packs][Pass (P1)][Cosmetics][Odds] |
| DAILY SALVAGE DROP  +8 flux  [Watch ad 4/6]    |
| STARTER PACK $2.99 (once)  6d left               |
| flux packs: $0.99 80 | $4.99 450 | $9.99 1000 ... |
| data caches: 4h $1.99 | 12h $4.99 | 28h $9.99  |
| Operation Pass: free track / premium $7.99        |
| "Ad-Free Claims" $7.99  (no forced ads exist)    |
| Odds (i): Firmware pick: Common 62 Rare 30 Epic 8 |
```
### 2.8 Gauntlet (tournament) screen (P1, not in the Launch build)
```
| GAUNTLET  LG 2 ALLOY    ends 1d 14h    |
| Bracket 30   PR 61   Attempts 1/3      |
| rank | player        | best wave | time|
|  1   | STATIC_WOLF   |    71     | 14:02|
|  2   | ...                               |
| ...  YOU 9  | 58 |                       |
|   ----- promotion line (top 6) -----     |
|   [ENTER GAUNTLET]   [+1 attempt: watch ad]|
| Rules: no patches, 5 firmware slots, seed 4F2A (same for all) |
| Rewards: rank 7-12: 24 flux, 8 cipher           |
```
### 2.9 Draft (patches) overlay
```
|         PATCH DRAFT (wave 20)            |
| [ARMS: OVERCHARGE     ] [CHASSIS: NANO REGEN  ] [SYSTEMS: GREED (gamble)] |
|  icon + LASER OUTPUT 28.6 > 32.9 + pips o o o o o   (gamble: COST line on a red band) |
| [REROLL ALL]   Picks so far: overcharge 2/5, plating 1/5 |
```
The battlefield dims 60% and freezes behind the overlay. One card per family, top to bottom ARMS, CHASSIS, SYSTEMS. Each card: the stat icon at 160 px on the left in the family color (amber, teal, scrap-gold), the patch name, the concrete change for this run using the same stat formatting as the upgrade rows, and pick pips (picks held of max). Gamble cards have a dashed amber border and show their cost as the same kind of concrete change on a red-tinted lower band. The REROLL ALL button (156 px tall) rerolls the three cards once per draft and then reads REROLLED. The first draft of a fresh profile adds the note "Patches last this deployment. One reroll per draft."; there is no timer and no auto-pick.

### 2.10 Results screen
Image-first (M4): readable in about two seconds, numbers and pictures, few words. Top to bottom, in one chamfered plate:
```
| [PURGE]            BEST 31 [NEW BEST] |  mode chip, short best line, badge only when the mode record moved
|              WAVE 31                  |  the wave reached, biggest text on the screen
| ///////////////////////////////////// |
| DESTROYED BY                          |  card: the killer's battle sprite (same art slot as the battle), small name
|              (sprite)                 |
|               HULK                    |
| [clock 15m 12s]   [kills 570]         |  stat tiles: icon + number + one word
| [data +2.6K  TOTAL 381] [scrap 4.18K] |  data tile has the new total as a small second line
| [skit x412][dart x96][..][boss x1]    |  kill strip: one sprite per type killed, most kills first, boss on the highlighted plate
| [check FRAME UNLOCKED: BULWARK]       |  compact badges (frame art or check icon); PURGE MODE UNLOCKED the same way
| SAVE FAILED                           |  only when the bank save failed
| [REDEPLOY]  [FOUNDRY n AFFORDABLE]  [HOME]
```
Data: per-type kills are `RunStats.kills_by_type` (already in the snapshot and the state hash); enemy names are `enemy.name.<id>`. New icons `ic_clock` and `ic_kills` follow the art bible icon style. The entry animation reveals the five sections (header, killer, tiles, strip, badges) 0.12 s apart; numbers still count up and end on the exact value; reduce motion shows the final screen at once.

## 3. First-time user experience (first 10 minutes)

Goals: a first death within ~3 minutes, first Foundry purchase by minute 4, a patch draft in run 1 or 2, and a clear "next unlock" goal. No text walls; no forced waits; no ads; no permission prompts before minute 9.

| Time | Screen | Beat | Notes |
|---|---|---|---|
| 0:00-0:15 | Splash/title | Logo, "tap to start" | Load, consent screens only if required by law (GDPR) - shown after tutorial where permitted; age gate if required |
| 0:15-0:40 | Cold open | 3 amber system lines: `RELAY 06 ONLINE`, `HOSTILE SWARM DETECTED`, `HOLD THE RELAY` + Cinder fades in | Skippable; sets tone; story light |
| 0:40-1:10 | Run 1, waves 1-2 | Cinder auto-fires; skitters approach; hand pointer on `laser_output` row ("TAP: MORE DAMAGE") | The starting scrap (230 since R1-02) affords it immediately |
| 1:10-1:50 | Waves 2-4 | After first kills, highlight `cycle_rate` when affordable ("TAP: FIRE FASTER", queued behind the laser hint, dropped if the row was bought meanwhile); show scrap rising; speed button teased (2x available) | One line of text each |
| 1:50-2:30 | Waves 5-8 | `dart` appears (first fast enemy) with a tiny label "DART - FAST"; `hull_integrity` highlighted after first damage taken ("TAP: SURVIVE LONGER"; fires on the first damage in any of the first three runs); hold-to-buy hint; wave 5: first Patch draft (R1-04: one ARMS, one CHASSIS, one SYSTEMS card, a gamble sometimes replaces one) with the note "Patches last this deployment. One reroll per draft." | Cinder's skin begins to scorch at band 1 (visual hook); the player chooses, auto-pick off |
| 2:30-3:10 | Waves 9-12 | Wave 10: second Patch draft (cards show the concrete change, one reroll) | Player chooses; auto-pick off |
| 3:10-3:30 | Death | Skin burn peaks; integrity 0; "RELAY LOST" fade | Death is dramatic, short |
| 3:30-4:15 | Results | `DATA +190`, damage breakdown, "FOUNDRY" button pulses | `best_s1` 12 unlocks: optic_range, plating_pct, reinvest preview |
| 4:15-5:30 | Foundry (guided) | Pointer on `laser_output`: tap to buy one level, then hold to buy several; show "+X% starting damage" and preview of next run | Teaches permanence vs temporary |
| 5:30-8:30 | Run 2 | Redeploy; stronger start; reaches wave ~16-20; run counters; first salvage? no (no elites yet); `crit_chance` upgrade appears | The "I got further" beat |
| 8:30-9:30 | Death 2 / Results | New best; progress bar to "Next unlock: R&D Lab at wave 25"; Foundry spend again | Show checklist: 3 upcoming unlocks |
| 9:30-10:00 | Home | Soft prompt: enable notifications ("Tell me when research finishes?") only after Lab is unlocked; for now: invite 2x speed toggle | No ads or IAP offer yet; starter pack appears at `best_s1` 25 or day 2 |
FTUE changes in M4 (M4-25/26, R1-04, R1-07): first launch of a fresh profile goes title, frame bay, cold open, then run 1 (this replaces the M3 default of going straight to Home, Q63); the beats are data (`data/ftue.csv`), only runs 1 and 2 show hints, every hint is skippable with SKIP HINTS and expires after 12 s; the wave-10 draft row above became waves 5 and 10 after R1-04; the Foundry explainer dialog (FO-1) opens on the first Foundry visit independently of the FTUE.
Day 1 follow-up: when the Lab unlocks (wave 25) first research is free (0 `data`, 5 min). Ops Board arrives at wave 40. Standby Patrol tutorial when first closing the app after wave 30.

## 4. Settings and accessibility
- Number format (short / scientific), language, sound/music/haptics sliders, left-handed mode, reduce motion (disables scanlines, vignette pulse, screen shake), high-contrast mode, colorblind palettes (Deuteranopia/Protanopia/Tritanopia), screen-always-on toggle during deployments, battery saver (30 FPS cap + disable glow), auto-pick / auto-buy toggles, notifications, odds viewer, privacy/consent, restore purchases, cloud save.
- Vibration: short tick on purchase, medium on boss spawn, long on death; off by default for micro-events.

## 5. Art style guide: "machine-vision vector"

### 5.1 Overall look
Dark void background and a world seen through Cinder's targeting optics: an animated polar grid, range rings and radar sweep, amber HUD text. **Hybrid (V1, see 10 s2):** Cinder, enemies, bosses, enemy bolts, icons and HUD frames are **illustrated layered SVG sprites** (shaded plates, gradients, baked glow); the beam, sparks, embers, shards, rings, grid and scanlines are procedural vector FX. The old 'shapes only' rule and the stroke widths below are superseded by 10 s2 and s4 (rim 3 px, seams 2 px, sprites 1.5x hit radius).
- Superseded by 10 s2/s4/s6.1 (kept for history): stroke widths enemies 3, elites 4 + inner line, bosses 6, Cinder frame 3, beam 3 core + 8 glow, grid 1. V1 values: beam 36 glow / 8 core / 3 center, grid 1-1.5, enemy rim 3.
- Enemy hull base stays `#2A0A10` (10 s3.2 ramps); Cinder is layered illustrated sprites.
- Silhouette vocabulary (triangle wedge, chevron, trapezoid, diamond, hexagon) stays; the 12-segment cap is replaced by the sprite node/texture budgets of 10 s4.4 and s9.
- Cinder is always the brightest, most saturated object at screen center; the swarm is darker with bright outlines.

### 5.2 Palette (hex)
| Role | Name | Hex | Use |
|---|---|---|---|
| Background | Void | `#07090C` | battlefield base |
| Background | Grid | `#12171D` | polar grid lines, range rings |
| Background | Red haze | `#140508` | edge vignette at low integrity |
| HUD | Amber | `#FFB000` | primary HUD/text/affordable |
| HUD | Amber glow | `#FFD27A` | highlights, active |
| HUD | Amber dim | `#8A5F00` | lines, frames, ticks (3.4:1 on PANEL: never text) |
| HUD | Amber text | `#B88A1E` | dim-amber labels (milestone line, top mark, frame lock), 6.0:1 on PANEL |
| UI panel | Panel | `#0D1117` | bottom panel bg |
| UI text | Text | `#F2E6C9` | primary text |
| UI text | Text dim | `#9A8F78` | secondary text |
| UI | Unaffordable | `#8A8170` | disabled costs, 4.9:1 on PANEL (R1-07; was `#5C5546`) |
| UI | Over limit | `#FF7A2E` | Foundry cost over the soft cap, 7.0:1 on PANEL (R1-02, R1-07) |

(R1-07, closes 09 Q48) Unaffordable cost text was 2.56:1 on the button fill `#0D1117`; it is now `#8A8170` (4.9:1). Rule: every text color is at least 4.5:1 on its background in every palette (`tests/unit/ui/test_theme_builder.gd`). Body text is Oxanium at weight 500 (`ThemeBuilder.BODY_WEIGHT`; the variable font's default weight is 200, which rendered thin). Explanatory text longer than four words (explainers, tooltips, hints, unlock and cap lines, dialog bodies) is sentence case; buttons, labels, titles, numbers and stat lines such as patch card changes stay in capitals.
| Player | Core | `#FFE3A3` | chest core, beam core |
| Player | Frame | `#8FA3B0` | frame lines |
| Player | Skin | `#D9A383` | skin wedges |
| Player | Char | `#3A2A22` | scorched skin |
| Player | Emitter | `#FFFFFF` | muzzle flash |
| Player shots | Laser | `#FFF1C9` core, `#FFB000` glow | `laser` hits |
| Player shots | Kinetic | `#C9D1D9` | razors, shock ring |
| Player shots | Arc | `#46E6F0` | arc_discharge, emp |
| Player shots | Blast | `#FF8A1F` | missiles, mines, drone_ember |
| Player shots | Nano | `#B28CFF` | nanite cloud |
| Friendly/heal | Teal | `#2EE6D6` | heal, shield, `drone_*`, flux |
| Enemy | Outline | `#FF2D4B` | normal enemy outline |
| Enemy | Fill | `#2A0A10` | enemy interior |
| Enemy | Elite | `#FF5A3C` | elite double outline |
| Enemy fire | Magenta | `#FF4FD8` | enemy projectiles (diamond shape) |
| Stealth | Ghost | `#FF2D4B` at 15% | shade |
| Warning | Warning amber | `#FFC21A` | boss warning ring, spawn warning |
| Warning | Critical | `#FF3B30` | integrity < 25% vignette, death |
| Currency | scrap | `#D6B36A` | bent plate icon |
| Currency | data | `#5BC8FF` | hex cell icon |
| Currency | flux | `#2EE6D6` | diamond icon |
| Currency | cipher | `#E0B0FF` | key-ring icon |
| Currency | merit | `#FFD84D` | chevron star icon |
Red is reserved for hostile units/danger; amber is Cinder and information; teal is "friend/positive"; magenta is only enemy projectiles. This multi-color system keeps the look from echoing any single franchise's red-tint trade dress [GENRE B1].

### 5.3 Glow, scanlines, effects rules
- Glow is **baked additive** (10 s4.3 and s10): `_glow` sheets composited with premultiplied alpha in the same draw as the body, halo sprites, beam strips; no WorldEnvironment glow by default. Glow reach <= 12 px for enemies, ~30 px for Cinder's core halo. The per-enemy glow switch for high density is the quality tier (10 s9.3: LOW stops sampling glow sheets), not a runtime enemy-count rule.
- Scanlines: 2 px lines at 6% opacity over the battlefield only (not the panel); disabled in reduce-motion/high-contrast.
- Vignette: edge darken 20%; pulses red when integrity < 25%.
- Polar grid: rings at 10 m, 20 m, 30 m (labelled for `standoff`); fades when > 100 enemies.
- Projectile readability: beams are hitscan lines with 80 ms fade; at >8 shots/s merge consecutive beams into a single pulsing line to avoid a wall of lines. Missiles and mines are distinct shapes (triangle + trail, hexagon + blink).
- Enemy palette uses outline luminance (L* >= 55) over dark fill; player effects L* >= 80, guaranteeing at least 25 L* difference between "friendly" and "hostile" regardless of hue.

### 5.4 Readability and colorblind safety
- Never rely on hue alone: hostile = dark fill + outline + angular shape set; friendly = bright fill + rounded shapes/rings; enemy projectiles are diamonds; player damage types are distinguished by shape (line/square/zigzag/circle/dots) as well as hue.
- Colorblind modes swap pairs: Deuteranopia/Protanopia: enemy outline `#FF2D4B` -> magenta-violet `#FF5CF0` with a thicker stroke, and player amber -> `#FFD84D` (final values to be validated with a colorblind simulator); Tritanopia: teal `#2EE6D6` -> `#7CFFB0`, amber unchanged. All palette values live in one theme resource so modes are data-driven.
- Contrast: all text >= 4.5:1 on its background; costs affordable vs not distinguished by color and a lock/dim icon.
- Max simultaneous distinct effect colors on screen is limited by types equipped (5 damage types plus enemy colors).

### 5.5 Damage and info numbers
- Font: condensed monospace for numbers (e.g. "Share Tech Mono", OFL) and a squared sci-fi sans for headings (e.g. "Oxanium", OFL). Both are free fonts; verify licenses.
- Show-rules: crits, overcrits, hits >= 1% of target max HP, plus the top 6 numbers per 0.5 s. Max 24 live numbers.
- Style: normal `#F2E6C9` 36 px (R1-07; 18 px in the original, 30 px after the V1 phone scale-up), crit `#FFD27A` 26 px with bracket `[ ]`, overcrit `#FFFFFF` 34 px with starburst, damage taken by Cinder `#FF3B30` 22 px near Cinder, heal `#2EE6D6` with `+`. Lifetime 0.6 s, rise 30 px, fade; 2-frame punch scale-in. Format: big-number short format (04).
- Aggregation: repeated hits on the same enemy within 0.2 s are summed into one number.

### 5.6 Cinder rendering
Layer list and cell table: `10_art_bible.md` s4.5 (sprites: shadow, frame, 12 plated wedges A/B, core housing, core, emitter ring, visor, shoulder emitter, glow layers; procedural: integrity ring, range rings in the arena shader). Original list kept for reference: (1) range rings, (2) frame, (3) skin wedge ring (12 wedges), (4) chest core with pulse, (5) emitter ring (3 nodes, rotates toward target), (6) visor slit arc at facing direction, (7) integrity ring (thin arc around Cinder: teal -> amber -> red). Skin Burn states per 02 section 12.1. Idle animation: core pulse 1 Hz, slow scan sweep every 8 s. Death: wedges fly outward as ember lines, frame lines fade last (looks and timings in 10 s6.4-6.5). The 'skin' is plated synthetic armor, not organic (10 s4.2, 09 Q42).

### 5.7 App icon and store art
Icon: hex chest core in amber on near-black with a faint broken-circle range ring; no text; no skull or human face. Splash: amber text lines. Original art only; no The Tower look-alike hexagon-over-tower icon.

## 6. VFX list (ids)
`vfx_beam`, `vfx_muzzle`, `vfx_hit_spark`, `vfx_kill_shatter` (3 line shards), `vfx_crit_flare`, `vfx_overcrit_burst`, `vfx_ricochet_line`, `vfx_split_lines`, `vfx_razor_trail`, `vfx_shock_ring`, `vfx_mine_arm`, `vfx_mine_blast`, `vfx_arc_zigzag`, `vfx_emp_ring`, `vfx_missile_trail`, `vfx_singularity_swirl`, `vfx_dilation_ripple`, `vfx_nanite_cloud`, `vfx_beacon_pulse`, `vfx_painter_zone`, `vfx_skin_embers`, `vfx_band_transition`, `vfx_meltdown_whiteout`, `vfx_overdrive_afterimage`, `vfx_milestone_ring` (gold ring on x1.5), `vfx_wave_banner_glitch`, `vfx_boss_warning`, `vfx_draft_open`, `vfx_cache_glow`, `vfx_pod_beam`, `vfx_barricade_hex`, `vfx_turncoat_flip`, `vfx_adaptation_outline`, `vfx_death_unravel`.
Performance budget: particle pool cap 400; each VFX has an LOD level that reduces at high enemy counts (exact looks, counts and budgets per VFX: 10 s6 and s9).

## 7. Audio direction
- **Source (decision 2026-11-08):** all SFX and music are **Claude-synthesized**: offline Python synth scripts (`tools/audio_gen/`, deterministic, fixed seeds) write original audio files into swappable **audio slots** (`assets/audio/slots.csv`, same idea as the art slots, art bible 4.3), so a commissioned composer pack can replace the files one by one later with no code change (Q19). Sketch gate: `docs/playtests/a1/`; tasks: `docs/tasks/A1.md`.
- **Music:** **ambient to industrial**. Early waves: calm cold-analog-synth drone, sub-bass and detuned pads (home screen: stripped pad only; menus: soft resonant hum). As waves climb and in boss fights the industrial layers come in: a syncopated filtered pulse, then metal clanks, steel-plate impacts, hydraulic hits and hisses, a kick-like thud, and a glassy FM bell or low saw lead for boss and low integrity. Tempo 84-96 BPM (shipped: 90), **4/4 (or 6/8) only**, syncopation inside the bar. Mood: lonely, mechanical, tense. Adaptive layers (thresholds in `assets/audio/music_layers.csv`): base pad (always) -> pulse (wave >= 10 or boss) -> percussion (wave >= 30 or boss) -> lead (boss, or integrity band 3). The layers are equal-length, sample-locked loops (`AudioStreamSynchronized`).
- **IP avoid-list (hard):** any anvil-style four-note motif; any melody, motif or chord progression that resembles a famous film theme; **no repeating anvil or metal-clank ostinato in an odd meter (13/16, 13/8, 7/8 and the like) as a hook**; no heavy synth march; no samples from any existing recording; never name a film franchise in files, code, comments or docs (the genre mood is matched, nothing else) [GENRE B1].
- **Mix:** SFX priority over music (the Music bus has a compressor side-chained to SFX, so effects duck the music slightly); a limiter on Master; per-id voice caps and cooldowns from the slot table (`sfx_laser_shot` voice cap 6 with a short cooldown; it is soft and non-fatiguing because it plays very often; at very high fire rate a looping pulsing "charged beam" loop may replace it). Music/SFX volume and mute are `AudioSettings` (settings screen: M3/M4). The player option LASER SOUND (`AudioSettings.laser_sound`) skips only `sfx_laser_shot`; hits, crits, warnings and music are unchanged.
- **SFX list (ids):** `sfx_laser_shot` (short soft tick-zap, pitch randomized +-3%), `sfx_hit_metal`, `sfx_crit` (bright ping), `sfx_overcrit` (low boom + ring), `sfx_enemy_death_small`, `sfx_enemy_death_heavy`, `sfx_player_hit` (dull thud), `sfx_integrity_warn` (heartbeat at band 3), `sfx_skin_burn` (crackle at band change), `sfx_wave_start` (low pulse), `sfx_boss_warn` (rising drone), `sfx_boss_death`, `sfx_upgrade_buy` (short click-chirp; during a press-and-hold repeat buy its pitch steps up slightly with each consecutive buy, capped at about +5 semitones, and resets on release; voice cap 3 and a 45 ms cooldown keep it pleasant at up to about 20 buys per second), `sfx_milestone_x15` (gold chime), `sfx_draft_open`, `sfx_draft_pick`, `sfx_cache_open`, `sfx_pod_heal`, `sfx_razor_spin`, `sfx_shock_ring`, `sfx_mine_beep`, `sfx_arc`, `sfx_emp`, `sfx_missile_launch`, `sfx_singularity`, `sfx_dilation`, `sfx_nanite`, `sfx_overdrive_on/off`, `sfx_aegis_break`, `sfx_reboot`, `sfx_meltdown`, `sfx_purge`, `sfx_ui_tap`, `sfx_ui_deny`, `sfx_lab_complete`, `sfx_firmware_pick`, `sfx_gauntlet_rank_up`, `sfx_death` (system shutdown whine), `sfx_results_tally`. A1 ships all 40 ids as synthesized files in slots (gate approved 2026-11-08): the 12 core ids (`laser_shot`, `hit_metal`, `crit`, `enemy_death_small`, `enemy_death_heavy`, `player_hit`, `wave_start`, `boss_warn`, `upgrade_buy`, `ui_tap`, `ui_deny`, `death`) plus `boss_death`, `integrity_warn`, `skin_burn`, `milestone_x15` and `results_tally` wired to existing sim events; the other 23 (`overcrit`, draft, cache, weapon systems, abilities, overdrive, Lab, firmware, Gauntlet) are slotted and get their trigger with their feature. Loudness scheme (effective LUFS-ish by category: tick -33, frequent and ui -27, event and stinger -21, big -18) and per-id trims: `docs/playtests/a1/A1-01_sketch.md`.
- **Voice:** no voice acting; machine "terminal" blips for text lines.
- **Haptics:** tied to audio events (purchase tick, boss pulse, death thud).
