# 12 - Upgrade Visual Tiers

Changelog: 2026-11-09 v0.1 - first version, a DRAFT for the user gate. User request: "visual changes to the upgrades ... as we reach certain values for the strength of our laser, it changes the visual look and feel of the shot, and same with armor upgrades, etc. this way the consumer can get visual satisfaction of purchasing upgrades". Direction accepted by the user: tiers, not every level. This chapter is a design and a mockup only; nothing is built. The style frame (section 15) is the thing to approve first. Visual rules follow `10_art_bible.md` and the IP guardrails of CLAUDE.md.

Scope tags: first slice (laser beam tiers, hull and plating armor tiers, repair motes, tier-up moment, upgrade-row mark) = MVP/M4-M5 candidate, pending approval. Cycle Rate heat-glow and the Crit spark = a second slice (section 4.5).

---

## 1. Goals

1. A purchase should feel like it did something you can see. The numbers already move; the picture should move at the same points.
2. Few, big steps. A tier is a clear change in the picture, not a tweak. Four marks per upgrade: MK I (base, today's look), MK II, MK III, MK IV.
3. A typical run sees 2 to 3 tier-ups early and up to about 5 in a deep run (section 3).
4. View only. The look reads upgrade levels, never changes the sim. No save, replay or `SimVersion` impact.
5. Cheap. Same draw calls as today for the beam and the rig, a few extra quads, a handful of pooled particles. The LOW quality tier drops the extras.
6. Readable. All new looks stay in Cinder's amber and teal family. Nothing new is red or magenta (those mean enemies). Armor must still look right while skin burn changes Cinder's wedges.
7. Data driven. Thresholds, looks and art slots live in one CSV, so commissioned art can replace the placeholders without code changes.

Non-goals: no new stats, no balance change, no new currency, no per-level cosmetics, no cosmetic shop (06 owns skins), no change to enemy art.

---

## 2. Tier points

A tier is a function of one upgrade row's current run level `L` (per deployment; run levels reset each run). The view looks the tier up in the table of section 6 and compares it with the tier it showed last frame. The sim is not involved: `UPGRADE_BOUGHT` (a = row index, b = new level) already carries what the view needs.

### 2.1 First slice

| Element | Row | MK I | MK II | MK III | MK IV |
|---|---|---|---|---|---|
| Laser beam | `laser_output` (type D) | L0 (today) | L5 | L12 | L25 |
| Armor plates | `hull_integrity` (type D) | L0 (no plates) | L5 | L12 | L25 |
| Repair motes | `nano_repair` (type D) | L0 (none) | L5 | L12 | L25 |
| Deflection sparks | `plating_pct` (type C, cap 0.90 at L99) | none | L3 | L8 | L16 (and L30 for the strongest) |

Notes:
- **MK IV is the existing x25 overclock.** GDD 02 s5 gives type D rows a x1.5 jump every 25 levels, and the upgrade row already shows a gold ring and the `sfx_milestone_x15` sound near each multiple of 25. MK IV lands exactly on the first of those, so the biggest look change and the biggest stat jump arrive together.
- **MK II and MK III are new, early points** (L5, L12). The measured runs never reach L25 (section 3), so with only the x25 point a normal run would see nothing. L5 costs 62 scrap on a type D row (c0 10, g 1.108) and L12 costs 224.
- **Plating deviates from the "25/50/75/100% of cap" idea.** The cap is level 99. Level 25 costs 1,967 scrap, level 50 about 23,000 and level 75 about 254,000 (c0 20, g 1.10). Capped-fraction steps would be invisible in any run. Proposed instead: level steps 3, 8, 16, 30 (cumulative cost 66, 229, 718, 3,290). Open question Q2.
- The marks are labels ("MK II"). Plating uses "PLATED I..IV" in the table so the row can tell two armor rows apart; the banner and the row show the same text.

### 2.2 Second slice (defined now so the table shape is final)

| Element | Row | Thresholds | Look |
|---|---|---|---|
| Emitter heat-glow and vent flicker | `cycle_rate` (type C, level cap 100) | L10, L30, L60, L100 | emitter ring and lens glow warmer, steam wisps at the vents |
| Crit spark | `crit_chance` / `crit_mult` | crit_mult L10, L40, L90, L150; crit chance read at 25/50/75/100% of its cap (reachable only later, see Q2) | forked spark on a crit, bigger burst with the multiplier |

The second slice is not mocked in the style frame. The thresholds above are placeholders, not measured.

---

## 3. How the thresholds were chosen

### 3.1 What the tools report

`tools\balance_run.ps1` prints the death wave per run and writes `build\balance\curve.csv` (average scrap per wave) and `build\balance\run0_buys.csv` (the purchase timeline of **run 0 only**: tick, wave, row, new level). It does not report levels for the other 19 runs. Nothing was added to production code. The numbers below are therefore:

- **Measured:** run 0 (seed 1) of each setup, final level per row from `run0_buys.csv`, plus the death wave statistics of all 20 runs.
- **Estimated:** levels a player could reach if they put all scrap into one row, computed from the cost curve `cost(L -> L+1) = ceil(c0 * g^L)` and the average scrap per wave from `curve.csv`. Labelled "estimate" below.

Setup: `-Waves 100 -Runs 20 -Seed 1 -Policy greedy4`, profiles `fresh` and `tests/profiles/foundry_300.json` (laser 5, hull 4, cycle 2), modes TIMED and PURGE. The bot buys by best `ref_dmg * ref_ehp` gain per cost, so it favors laser and repair and buys hull rarely; a human who likes armor will have a different mix.

### 3.2 Measured (run 0)

| Setup | Death wave p10 / p50 / p90 (20 runs) | Run 0: last purchase at wave | Laser | Hull | Nano repair | Cycle |
|---|---|---|---|---|---|---|
| fresh, TIMED | 11 / 12 / 13 | 11 | L8 | L1 | L7 | - |
| fresh, PURGE | 11 / 17 / 22 | 20 | L11 | L2 | L10 | L1 |
| foundry_300, TIMED | 14 / 16 / 18 | 15 | L12 | L4 | L9 | - |
| foundry_300, PURGE | 18 / 24 / 27 | 33 | L17 | L9 | L15 | L6 |

Run 0 is one run, not the median: the two TIMED runs sit near their median death wave, the two PURGE runs are above theirs (p50 17 and 24), so the PURGE rows lean optimistic.

Reading: no setup gets any row near L25. Laser reaches 8 to 17, repair 7 to 15, hull 1 to 9. A tier at L25 alone would never show in a normal run.

### 3.3 Estimated (all scrap into one row)

Cumulative scrap earned (average, plus the 60 starting scrap) from the foundry_300 PURGE curve: wave 11 about 356, wave 16 about 626, wave 24 about 1,277.

| By wave | Scrap | Laser or hull, all-in (estimate) | Nano repair, all-in (estimate) | Same scrap split over 3 rows (estimate, laser/nano) |
|---|---|---|---|---|
| 11 | 356 | L15 | L11 | L8 / L5 |
| 16 | 626 | L20 | L15 | L11 / L8 |
| 24 | 1,277 | L26 | L22 | L17 / L12 |

Cumulative cost of the chosen points (laser or hull): L5 = 62, L12 = 224, L25 = 1,110. Nano repair: L5 = 120, L12 = 403, L25 = 1,694.

### 3.4 Result

- **MK II at L5**: a fresh TIMED run passes it by about wave 6 on laser and repair.
- **MK III at L12**: foundry runs and PURGE runs reach it on laser; a focused player reaches it by wave 8 to 9.
- **MK IV at L25**: a late-run goal. Only an all-in laser in a deep PURGE run gets there (estimate: wave 22 to 24). It is meant to feel earned and it matches the x25 overclock.

Tier-ups seen by the bot's run 0 (laser, repair and hull together):

| Setup | Tier-ups |
|---|---|
| fresh, TIMED | 2 (laser II, repair II) |
| fresh, PURGE | 2 (laser II, repair II) |
| foundry_300, TIMED | 3 (laser II and III, repair II) |
| foundry_300, PURGE | 5 (laser II and III, repair II and III, hull II) |

That meets "2 to 3 early, more in a deep run". The numbers are a first guess from one seed per setup. The playtest report (M1-26 style) should log the real tier-up count per run; thresholds are CSV data, so retuning needs no code (task VT-7).

---

## 4. Looks per tier

All sizes are px at 1080 width before the view's sprite factor (0.85 at the base zoom). Tier values live in the CSV (section 6). Images: section 15.

### 4.1 Laser beam (`laser_output`)

Today: three strip quads (glow 36, core 8, hot 3 px; widths x1.5 on a crit), end caps, muzzle flare and cone, crit flare.

| Mark | Glow / core / hot | Core color | Impact | Muzzle | Extra |
|---|---|---|---|---|---|
| I | 36 / 8 / 3 (today) | `LASER_CORE` | none | x1.0 | none |
| II | 54 / 13 / 5 | 35% toward white | 4-point flare 70 px | x1.15 | none |
| III | 76 / 18 / 8 | 70% toward white, glow shifts toward `AMBER_GLOW` | 8-point flare 104 px plus a thin ring 84 px | x1.3 | none |
| IV | 100 / 24 / 11 | pure white-hot | 8-point flare 136 px plus ring 118 px | x1.5 | teal-white rim layer at 30%, charge ripple: 6 bright bands travel emitter to target |

The beam stays amber with a white-hot core. Teal appears only as the thin rim and the ripple at MK IV, so MK IV reads as "charged" without leaving the family. A crit still multiplies the widths by 1.5 on top.

### 4.2 Armor plates (`hull_integrity`)

Plates are metal segments on Cinder's outside, under the integrity ring and above the floor: gunmetal ramp of the art bible (`#2B343B` to `#D4E0E8`), light from the upper left, amber trim lights, teal diode strips at MK IV.

| Mark | Plates |
|---|---|
| I | none (today) |
| II | 4 corner plates at 45 degrees with amber trim |
| III | adds 4 bridge plates at the cardinal angles and retaining arcs: a full 8-plate ring |
| IV | adds a 16-segment outer lip with teal diode strips and amber-lit caps on the corner plates |

Silhouette grows with each mark (the mockup draws plates up to 14% beyond the integrity ring at MK IV). Plates do not rotate with the aim. The emitter ring, lens and shoulder piece stay above the plates.

### 4.3 Deflection sparks (`plating_pct`)

On each `CINDER_HIT` while plating is at tier 1 or higher, a short teal-white ricochet at the hit point on the plate edge: a small flash, a thin ring and 6 sparks fanned to both sides of the surface normal. Spark count and size scale with the tier (x0.8, 1.0, 1.2, 1.4). Teal-white is chosen so it never reads like the amber sparks Cinder's beam makes on enemies.

### 4.4 Repair motes (`nano_repair`)

Small teal motes drift around Cinder just outside the plates, each with a soft halo and a short fade.

| Mark | Live motes | Speed (px/s) | Size (px) |
|---|---|---|---|
| I | 0 | - | - |
| II | 5 | 70 | 14 |
| III | 10 | 85 | 15 |
| IV | 16 | 100 | 16 |

Motes spawn at the ring radius with a tangential velocity and live 1.3 s, so the eye reads an orbit. Rate is about count / 1.3 spawns per second. Proposed rule: 40% rate at full integrity and 100% while Cinder is below full integrity, so the motes also say "repair is working" (Q3).

### 4.5 Second slice (not mocked)

Cycle Rate: emitter lens and ring glow shift from amber toward `AMBER_GLOW`/white and add 2 to 4 short vent wisps per tier (additive, pool particles). Crit: a forked crit spark (2 to 3 thin branches) on the target at each mark, burst size scaled by the multiplier tier; amber/white only.

---

## 5. Tier-up moment

Triggered view-side when the displayed tier of a row rises (new purchase, or a multi-buy that crosses one or two points: only the final mark is announced).

| Part | Spec |
|---|---|
| Cinder flash | 0.45 s: soft halo (alpha 0.5 fading), one expanding teal-white ring, one amber thin ring, 8-point flare. Four quads from the `fx_sheet`, additive. Mock: `UtFlash`. |
| Banner | Dark plate with amber top and bottom lines and corner brackets, text `LASER MK II` (Oxanium, 54 px, spaced) and a small teal line `BEAM OUTPUT TIER UP`. Slide down 0.15 s, hold 1.3 s, fade 0.3 s. Position: top of the battle field, below the HUD bar, above Cinder. One banner at a time; a second tier-up inside 2 s replaces the waiting one. |
| Banner text keys | `vt.banner.laser`, `vt.banner.hull`, `vt.banner.plating`, `vt.banner.nano` plus `vt.mark.1..4` (rendered as `{row} {mark}`, e.g. LASER MK II); subline keys `vt.sub.laser` ("BEAM OUTPUT TIER UP"), `vt.sub.hull` ("ARMOR TIER UP"), `vt.sub.plating`, `vt.sub.nano` ("REPAIR TIER UP"). The CSV `label_key` and `banner_key` columns name them (section 6). Strings go in `data/strings_en.csv`. |
| Sound | New short sting slot `sfx_tier_up` (two rising notes, about 0.4 s, soft attack) for MK II and III. MK IV reuses `sfx_milestone_x15`, which already plays at multiples of 25, so the router must not play both: one rule in `AudioEventRouter`. Needs an audio task (A1 pipeline). |
| Haptic | One pulse that replaces the buy tick for that purchase: MK II and III 35 ms at amplitude 0.6, MK IV 70 ms at 0.8. (`Haptics.MIN_GAP_MS` is 60 ms, so a buy tick followed by a tier pulse would drop the second; `HapticHooks.route` picks the stronger one.) Honors the haptics switch. |
| Row | The row gets the existing gold ring expansion for 0.4 s and the mark chip updates (section 6). |
| Not shown | On resume from a save, on replay fast-forward and on a debug load: no flourish, the look just starts at the right tier (`skip()` pattern of `HapticHooks`). |

---

## 6. Upgrade row and data table

### 6.1 Row

Each covered row (laser, hull, repair, plating) gets:
- A **mark chip** left of the level, `MK II`, filled amber when the mark is the newest (just reached this run) and dim amber otherwise.
- A line **`next look at L12`** in dim mono text (teal for 3 s after a tier-up). At MK IV the line reads `top mark`.
- An optional thin **progress bar** toward the next point (mock: 5 of 12).
Rows without a table entry look as today. The mock is in `ut_tier_up.jpg`.

### 6.2 `data/visual_tiers.csv` (proposed)

Same pipeline as the other data tables (importer, generated resource, string keys). The checked-in proposal is `docs/design/style/upgrade_tiers/visual_tiers.proposed.csv`, and the style-frame harness reads that exact file.

| Column | Meaning |
|---|---|
| `id` | stable row id, `laser_2` |
| `upgrade` | run upgrade id (`laser_output`, `hull_integrity`, `plating_pct`, `nano_repair`) |
| `tier` | 1 to 4 |
| `mark` | label text, `MK II` (display default; strings may override) |
| `threshold_kind` | `level` (run level) or `cap_frac` (fraction of the row's level cap, for type C rows) |
| `threshold` | level, or fraction |
| `label_key`, `banner_key` | string keys (empty banner key = no banner for that tier, MK I) |
| `art_slot` | `-` (procedural) or `sheet:cell` of a commissioned art slot (plates use `ut_plates:tier_1..3` in the mock, `cinder_plate_*` cells in production) |
| `params` | `key=value;key=value` read by the element: beam `glow core hot flare ring whiten rim ripple muzzle`; hull `plates`; plating `deflect spark_scale`; nano `motes speed size` |

Rules: tiers are strictly increasing in threshold per upgrade; MK I has threshold 0; an unknown param key is ignored (so art can add keys); a missing row falls back to MK I. A unit test checks monotonic thresholds and that every `label_key` exists.

---

## 7. Rendering approach and budget

Reference: `TECH_ARCHITECTURE` 2.7 (battlefield draw calls target 25, hard 40; render prep 3 ms) and art bible 9.2 (battlefield about 17 to 20 calls). Constraints from CLAUDE.md gotchas: the Compatibility renderer; no MultiMesh `use_colors`/`use_custom_data` (transform-only MultiMesh plus RGBAH data textures, which the particle ring already does); one non-AA `draw_polyline_colors` rather than AA arcs.

| Element | Approach | Added draw calls | Added CPU per frame |
|---|---|---|---|
| Beam thickness, color | No shader needed. `BeamRenderer._draw_beam` already draws three stretched strip quads with `draw_texture_rect_region`; tier widths and colors are different rect sizes and modulates from a small `BeamLook` value (replaces the `BeamMath.widths` constants). The mockup `UtBeam` does exactly this by subclassing. | 0 (same texture, same additive material: they batch) | none |
| Beam rim, ripple, impact flare/ring | Extra quads on the same `fx_sheet` strip and flare cells: rim 1, ripple 6 x 2, flare 1, ring 1, per live beam | 0 (batch) | about 16 quads per beam, 16 beams max: under 0.05 ms |
| Armor plates | A new first child layer of `CinderView` below the body layer (so the integrity ring, a code `_draw`, stays on top; the body layer above is on the same texture and keeps batching). Plates are 3 small art cells (corner plate, bridge plate, lip segment) in the `cinder` sheet drawn rotated like the 12 wedges: 4 + 4 + 16 = 24 quads, plus the same count from `cinder_glow` for the trim. The mock bakes whole rings (3 x 640 cells) only to iterate fast; production must not ship that (texture size). | +0 to +1 (the new layer may not merge with the ring's polyline) | 48 quads, about 0.05 ms |
| Deflection sparks | New `FxEmitter.deflect(pos, normal, scale)` recipe (4 particles + 6 sparks) fired from the existing `CINDER_HIT` handling and its `_cinder_budget` | 0 (particle ring is one additive MultiMesh) | up to 10 particles per hit |
| Repair motes | `FxSpawner` spawns motes per frame from an accumulator (rate = count / 1.3 s); 2 particles each (mote + halo) in the pooled ring | 0 | at most 32 live of the 400 cap |
| Tier-up flash | `UtFlash`-like node: 4 quads, additive, 0.45 s | +0 (batches with beams) | trivial |
| Banner, row chip | Controls (UI budget); the banner is one `PanelContainer` | UI, not battlefield | one tween |

Total battlefield draw calls added: 0 to 1 (budget 25). Particle pressure: at most about 32 motes plus 10 per hit on a cap of 400 (HIGH), 200 (MID), 80 (LOW). Texture memory: three small plate cells plus glow twins, under 0.5 MB RGBA8 (cells of about 160 x 100 texels).

Why the particles cannot orbit: pool particles integrate position analytically from spawn (linear velocity and drag), so a true circular orbit is not possible. The tangential velocity plus a short 1.3 s life reads as orbiting at the densities above. If this is not good enough on device, the fallback is one small `_draw` node with at most 16 quads positioned from the view clock (no allocation); it adds no draw call either.

Determinism and boundaries: all state is in the view. The tier of a row is a pure function of `run_levels[row]` (`VisualTierModel.tier_for`), so tests run headless without a window. Nothing here reads `Rng`, writes `SimWorld`, adds a sim event or changes the replay hash.

---

## 8. Quality tiers and reduce motion

| Element | HIGH | MID | LOW | Reduce motion |
|---|---|---|---|---|
| Beam thickness, color, flare | all | all | thickness and color only (free) | all |
| Beam rim and ripple (MK IV) | on | ripple off, MK III look plus rim | off | ripple off, rim on |
| Impact ring | on | off (`impact_rings` false, same switch as hit rings) | off | on, no scale animation |
| Plates body | all | all | all | all |
| Plates glow twin | on | on | off (`glow_sheets` false) | on |
| Deflection sparks | on | 4 sparks, no ring | off | on, no motion blur: fewer sparks (3) |
| Repair motes | full count | 60% count, no halo | off | half count, they fade in place (no drift) |
| Tier-up flash | halo, 2 rings, flare | halo and 1 ring | single halo, 0.2 s | steady 0.25 s glow, no expanding ring |
| Banner | slide, hold, fade | same | fade only | fade only (no slide) |

Quality never changes what tier is shown, only how much of the look is drawn.

---

## 9. Colorblind interplay

Plates, beam and motes are authored in Cinder's amber and teal, the same roles `Palette` already uses (amber = Cinder and information, teal = friendly). The planned M4-24 palettes remap the hostile and the friendly roles; the tier looks go through `Palette` constants (`AMBER`, `AMBER_GLOW`, `TEAL`, `LASER_*`), never hard-coded hex, so a remap changes them with everything else. The tier steps are carried by shape and size (thicker beam, more plates, more motes), never by hue alone. Check with the remapped palettes: the MK IV teal rim and ripple must stay distinct from the amber glow in deuteranopia and protanopia; if not, the ripple uses brightness (white) only. Plate trim must stay readable against the integrity ring (the ring is teal at full health).

---

## 10. Skin burn interplay

Skin burn (GDD 02 s12.1) changes the 12 wedges inside the frame disc: charred plates, ribs, white-hot frame. Armor plates sit outside that disc and do not change with the band. Rules:
- Armor plates never char, crack or vanish with the band. They are equipment, the wedges are skin. The mock panel "HULL MK IV + SKIN BURN BAND 2" shows both.
- Band 3's red vignette and heartbeat stay as they are; the plate trim does not pulse.
- Deflection sparks and motes continue at every band (motes at 100% rate when integrity is below full, section 4.4).
- Hit shiver moves plates with the rig (the plates layer shares the body layer's shiver offset).

---

## 11. IP note

The look is original: layered gunmetal plates with amber trim and teal diodes on a round machine, plus a charged amber laser. Do not use or add: a chrome skull, glowing red eye pairs, exposed endoskeleton faces, a liquid-metal effect, any "T" mark or terminal-style red HUD, or the names of any franchise. Marks use "MK" and "PLATED" only. Banner and string text stays generic ("BEAM OUTPUT TIER UP"). New art follows the art bible (layered vector, dark plates, amber/teal glow). The trademark search (Q31) should include the strings "MK II/III/IV" next to a laser (low risk, generic military marks).

---

## 12. Task breakdown (after approval)

Sizes: S = under half a day, M = about a day, L = 2 days. IDs are placeholders (`VT-n`).

| Task | Size | Depends on | Summary |
|---|---|---|---|
| VT-1 Data and model | S | approval | `data/visual_tiers.csv`, importer, `VisualTierDef`, pure `VisualTierModel` (tier_for, next_threshold, mark label), string keys, unit tests (monotonic, keys exist, thresholds from this chapter) |
| VT-2 Beam tiers | M | VT-1 | `BeamLook` value into `BeamRenderer`, rim, ripple, impact flare and ring, muzzle scale; default look bit-identical to today at MK I (existing tests unchanged); LOW/MID rules |
| VT-3 Armor plates | L | VT-1 | art cells in `cinder` and `cinder_glow` sheets (+ slots.csv rows, art lint/check), plates layer in `CinderView`/`CinderRig`, coexist with bands and the integrity ring, 3 frames (vanguard, bulwark, striker) share the cells at first |
| VT-4 Sparks and motes | M | VT-1 | `FxEmitter.deflect` and mote spawner in `FxSpawner`, budgets, quality and reduce-motion rules, headless tests of counts and caps |
| VT-5 Tier-up moment | M | VT-1 (looks from VT-2..4) | view-side `TierUpDirector` (events to tier-up, multi-buy, resume skip), flash node, banner control, strings, `sfx_tier_up` slot request, `HapticHooks`/`Haptics` tier pulse, router rule against double sting at x25 |
| VT-6 Row mark | S | VT-1 | mark chip, `next look at L..` line, progress bar in `UpgradeRow`; gold ring tie-in |
| VT-7 Pass and tuning | S | VT-2..VT-6, M4-24 | colorblind check, perf bench with all effects (`tools\perf_bench.ps1`, draw calls and frame time), tier-up counts per run in the playtest report, threshold retune in the CSV |
| VT-8 Second slice | M | VT-7 | cycle rate heat-glow, crit spark |

Critical path: VT-1 -> (VT-2, VT-3, VT-4 in parallel) -> VT-5 -> VT-7. Total about 7 to 9 days for the first slice. VT-3 is the long pole (art).

---

## 13. Risks

- **Armor reads as a floating ring** (the mockup plates float a little away from the body). Production art should dock the plates to the frame. A commissioned or hand-polished pass may change the silhouette; the table's `art_slot` column allows it.
- **Beam MK IV hides the target** (a 100 px glow over a 54 px enemy). The glow alpha is soft; if it hides enemies on device, cap the glow at 84 and keep the core size.
- **Too many effects at once in a crowd.** Deflection sparks use the existing Cinder-hit budget; motes are capped at 32 live; the ripple is per live beam only. Perf bench in VT-7.
- **Thresholds are from one seed per setup** (section 3). They are data, retunable.
- **Banner spam** at high speed. One banner at a time with a 2 s coalesce window.

---

## 14. Open questions for the user

| # | Question | Recommended default |
|---|---|---|
| Q1 | Tier points for the three type D rows: L5, L12, L25 (MK IV = the x25 overclock), instead of only every 25 levels? | Yes: L5, L12, L25, because no measured run reaches L25 |
| Q2 | Plating (and later crit chance) tiers: level steps (3, 8, 16, 30) instead of 25/50/75/100% of the cap? | Level steps; cap fractions are unreachable (L50 costs about 23,000 scrap) |
| Q3 | Repair motes: always on at 40% rate and 100% while hurt, or only while repairing? | 40% / 100% |
| Q4 | Banner on every tier-up or only MK III and IV? | Every tier-up, shorter (1.0 s hold) for MK II |
| Q5 | Does the Foundry grant a starting mark (for example Foundry laser 20 starts a run at MK II)? | No: marks are earned each run so the climb always happens |
| Q6 | New sting sound `sfx_tier_up` for MK II and III, MK IV reuses the x25 milestone sound? | Yes, new sting plus reuse |
| Q7 | Tier pulse replaces the buy tick (haptics)? | Yes |
| Q8 | Plate style: floating segments as in the mockup, or plates docked to the frame body? | Docked in production art, floating look is a mockup shortcut |
| Q9 | Naming: "MK II/III/IV" for every row and "PLATED I..IV" for plating? | Yes |
| Q10 | Second slice (cycle heat-glow, crit spark) in M5 or later? | After the first slice is on a phone |

---

## 15. Style frame (review images)

Rendered by `src/debug/upgrade_tiers_frame.tscn` (desktop only): the real `BattleView` (arena, Cinder rig, enemies, particle ring) with mockup layers added. Full-size PNGs are written to `build/ut_frame/` (not committed); review copies are committed in `docs/design/style/upgrade_tiers/`. Command:

```
godot --path . --windowed --resolution 540x600 res://src/debug/upgrade_tiers_frame.tscn -- --ut-out=<dir>
```

| File | Content |
|---|---|
| `ut_beam_tiers.jpg` | beam MK I to IV, Cinder firing at an enemy (thickness, white-hot core, impact flare and ring, MK IV ripple) |
| `ut_armor_tiers.jpg` | Cinder with plate tiers 0 to 3 (hull MK I to IV) |
| `ut_armor_fx.jpg` | deflection sparks, repair motes at 5 and 16, and hull MK IV with skin burn band 2 |
| `ut_tier_up.jpg` | a full 1080 x 1440 battle frame at the tier-up moment: Cinder flash, `LASER MK II` banner, and the upgrade rows with mark chip and `next look at L12` |
| `visual_tiers.proposed.csv` | the proposed table the harness reads |

Mockup-only parts (not production): `UtBeam` (a `BeamRenderer` subclass), `UtPlates` (baked ring cells from `assets/art/style/upgrade_tiers/ut_plates.svg`, generated by `gen_plates.py`), `UtFlash`, the banner and rows (plain Controls), `UtTiers` (CSV reader). No production file was changed.

(impl) markers: none yet. Everything in this chapter is a proposal until the style frame is approved.
