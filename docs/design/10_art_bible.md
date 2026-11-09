# 10 - Art Bible (IRON STATIC visual pass)

Changelog: 2026-11-08 (V1-23: camera auto-fits Cinder's optic range, sprites 85 percent; V1-GATE decision 2 superseded) 2026-11-08 v1.1 - V1-GATE decisions block added (approved with changes). 2026-11-08 v1.0 - first version. Written after the user watched the M1/M2 emulator build and judged it low quality (flat, too small and thin, bland Cinder/enemies, generic HUD). Decisions of 2026-11-08: hybrid direction (illustrated sprites + vector/neon FX + styled sci-fi HUD), Claude-drawn layered SVG as the art source, timing "now" as milestone V1 between M2 and M3. This chapter is the **authority for everything visual**; `07_ux_ui_art_audio.md` sections 5-6 keep the palette hex values, VFX ids, damage-number rules and accessibility rules, and defer to this chapter where they differ (see 07 changelog). Task file: `docs/tasks/V1.md`. Milestone: `docs/ROADMAP.md` V1.

Status of facts: items marked **[V: url]** were verified against Godot or ThorVG documentation on 2026-11-08; **[U]** = unverified, to be settled by the probe/spike named next to it; **[D]** = a design decision of this chapter.


> **V1-GATE decisions (2026-11-08, user) - these override the rest of this chapter where they differ; V1-22 folds them into the body.**
> 1. **Approved for production**: the hybrid direction of the V1-01 style frame (`docs/playtests/v1/`).
> 2. **Camera 32 m** (33.75 px/m), sprites 1.5x hit radius, stand-off 72 px (Q41 resolved as recommended). **Superseded by V1-23 (2026-11-08, user, after emulator play showed Cinder shooting enemies off-screen): the camera auto-fits Cinder's current optic range, width = 2 x (optic_range + 2 m) = 52 m at the base 24 m, easing out over 0.65 s as Optic Range is bought (clamped 38 m to the 108 m spawn-ring diameter; fitted to the smaller of viewport width and battle height). Sprites, Cinder, beams and particles are decoupled from the camera and drawn at 85 percent of the old pixel size at 52 m (skitter 54 px, walker 95 px, boss 255 px, armor ring about 86 px radius), shrinking by sqrt(52 / camera width) to a floor of 70 percent at wide cameras. Rings and enemies keep real meters (20.8 px/m at base). Cinder is drawn at 75 percent of the sprite scale and centered in the field left open by the HUD and panel (`BattleView.set_field_insets`). Formulas: `ViewMath.fit_width_m`, `sprite_factor`, `sprite_ppm`; task `docs/tasks/V1.md` V1-23.**
> 3. **Crowd readability** (all three requested):
>    - **Distinct accent color per enemy type** (hull stays dark; rim, vents and emissives carry the accent): skitter = red `#FF2D4B`, dart = pink-magenta `#FF4FD8`, walker = orange `#FF7A1A`, lancer = violet `#A35CFF`, boss = deep red `#FF1F3D` with white-hot reactor. Hostile still reads hostile against Cinder's amber/teal; check FC5 and color-blind safety (shape stays the primary cue).
>    - **Walkers about 20% smaller on screen** (visual scale only; body ~112 px instead of 140; sim radius unchanged).
>    - **Density-based glow reduction**: enemy glow strength and rim brightness fall automatically as alive enemies rise (e.g. 100% up to 40 enemies, linearly to 45% at 165), so silhouettes separate instead of merging into one red mass.
> 4. **Cinder skin = metallic** (Q42 changed from the recommendation): the 12 skin wedges become **gunmetal / ceramic armor plates with amber trim and panel detail**, not tan/peach skin tones. The burn-away still chars plates and reveals the frame (band 1 charred plates, band 2 frame ribs, band 3 white-hot frame + cracked core).
> 5. Defaults kept as recommended (user did not change them): screen shake on Low, never on kills, off with reduce motion (Q43); scanlines 6% (Q44); bold flat glyph icons on chamfered plates (Q45); slow-mo only on boss/Cinder death if view-only (Q46); no WorldEnvironment glow by default - measured -26% fps on the emulator (Q47).
> 6. Style-frame review fixes to fold into production: full-strength hit flash turns a sprite into a white ghost (cap it per art bible); skitter legs are thin detached strokes (thicken / connect); band-0 core halo washes the wedges (reduce); beams need a proper `beam_strip` cell (stepped glow today); the floor's 10 m seam ring doubles the shader grid ring.

---

## 1. Visual target

### 1.1 Statement
IRON STATIC looks like **worn, hand-built hardware lit by its own weapon, seen from above on a black deck**. Cinder is a heavy, warm-plated machine at the center, big enough to read as a character (about 18% of the screen width), with an amber core that is the brightest point on the screen. The swarm is a crowd of dark, angular, individually detailed machines whose hot vents and cutting edges glow red against the void; everything that glows adds light to the scene (halos, sparks, embers), and everything that is hit reacts (flash, shake, burst). The HUD is the same world's cockpit glass: chamfered plates, corner brackets, tick marks, amber phosphor numbers.

Three tests every asset must pass: (1) **Silhouette first**: filled solid black, each enemy type is identifiable at 64 px. (2) **Cinder first**: at a glance the eye goes to Cinder's core, then to the nearest threat. (3) **Light is honest**: only things that emit (core, beam, vents, bolts, embers) glow; hulls never glow.

### 1.2 Mood references (words only, no images are to be copied)
1. **Sodium-lit rail yard at night in rain**: black wet metal, one amber lamp, hazard paint chipped to bare steel. Source of Cinder's amber-on-gunmetal palette and "worn" surface treatment (scratches, chipped edges, rivet rows).
2. **Phosphor oscilloscope / radar scope**: light that blooms from thin lines, soft green-amber falloff, sweeping arm. Source of the beam look, the animated polar grid and the radar sweep.
3. **Deep-sea ROV lights in black water**: a warm cone of light and things drifting at the edge of visibility. Source of the dark arena, the ambient drifting motes and the way enemies emerge from darkness into amber light.
4. **Heavy industrial machinery and mining plant**: stamped plates, ribbed armor, exposed hydraulics, stencilled markings. Source of enemy hull construction (plates, seams, pistons) and the HUD's stencilled labels.
5. **Aircraft instrument panels and avionics displays**: angled bezels, corner brackets, tick scales, segmented bars. Source of the HUD frame language.

### 1.3 What it must not look like
Not a franchise trade dress (no chrome skull, no glowing red eye pairs, no half-flesh face, no liquid metal, no "T" logo; section 11). Not a flat neon-line toy (the old look). Not a photoreal render: shapes stay graphic and shaded in 3-5 tonal steps per material so the swarm stays readable at 165 units.

---

## 2. Style rules: illustrated vs procedural

| Thing | Made as | Why |
|---|---|---|
| Cinder (all layers), enemies, bosses, enemy bolt, upgrade/tab/currency icons, HUD frames and panels | **Illustrated layered SVG** (agent-authored, shaded, section 4) | Detail, material read, swappable art slots |
| Beam, muzzle flash, impact sparks, embers, shards, rings, halos, smoke puffs | **Procedural vector FX** drawn from a small set of neutral SVG FX sprites (`fx_sheet`) plus code (lines, arcs, shader math), tinted per use | Cheap, many instances, recolorable |
| Arena floor | One illustrated static SVG (deck plating, hazard ring) | Fills the "empty arena" without per-frame cost |
| Grid, range rings, radar sweep, scanlines, vignette | **Shader math** in one full-rect shader (section 6.7) | Animated for free, no geometry |
| Integrity ring, timer bar fill, damage numbers, wave banner glitch | Code (`_draw`, Label) with SVG ornaments | Values change every frame |

Common rules:
- **Top-down, light from the upper left** for anything that does not rotate (Cinder body, HUD, floor). Enemy sprites **rotate** to face Cinder, so their baked shading is rotation-invariant: a soft ambient-occlusion look (lighter center and top plates, darker rim shadow) plus an **amber rim light on the front edge** (the edge facing Cinder), because Cinder is the light source. This single trick makes the swarm look lit by Cinder at any angle. [D]
- **Material read in four tones**: shadow, base, light, highlight, plus an emissive tone for glowing parts (section 3.2). No pure black, no pure white except the hottest 5% of an emissive.
- **Edges**: every enemy has a 3 px (on-screen, 1080 wide) bright rim line in its edge color so shape reads against the dark floor; interior seam lines are 2 px in the shadow tone. No hairlines below 2 px on-screen.
- **Wear**: scratches (2-4 per large plate), chipped corners, rivet rows (dots, max 12 per sprite), hazard stripes on walker and boss only. Wear is part of the SVG, never a texture overlay.
- **Detail budget**: every sprite readable at its target on-screen size; details smaller than 2 px on-screen are cut, not kept.

---

## 3. Palette usage (extends `Palette`; GDD 07 s5.2 hex values unchanged)

### 3.1 Roles that do not change
Amber = Cinder and information; red = hostile only; teal = friendly/positive; magenta = enemy projectiles only (07 s5.2). New ramp colors below are **additions** to `Palette` (new consts, same file); the 07 colors keep their names and values.

### 3.2 Material ramps (hex)
| Material | Shadow | Base | Light | Highlight | Emissive / glow |
|---|---|---|---|---|---|
| **Cinder armor plates** (gunmetal / ceramic, V1-GATE decision 4, replaces the tan skin ramp; section 4.2) | `#38434B` (= `ARMOR_SHADOW`) | `#6B7882` (= `ARMOR_BASE`) | `#9AA8B3` (= `ARMOR_LIGHT`) | `#DCE6EC` (= `ARMOR_HIGHLIGHT`) | amber trim `#FFB000` (trim glow only, not a plate wash) |
| **Cinder skin, legacy tan** (superseded by the armor plates; consts `SKIN*` stay only until the view/test code is migrated) | `#8A5A44` | `#D9A383` (= `SKIN`) | `#F0C4A0` | `#FFE6CC` | none |
| **Cinder skin, charred** | `#1F1612` | `#3A2A22` (= `CHAR`) | `#5A4034` | `#7A5A48` | ember edge `#FF8A1F`, spark `#FFD27A` |
| **Cinder frame** (gunmetal; deepest cavity tone `#12181D` = `FRAME_DEEP`) | `#2B343B` | `#56656F` | `#8FA3B0` (= `FRAME`) | `#D4E0E8` | none (hot state: `#FFF1C9`) |
| **Cinder trim** (amber hazard paint) | `#8A5F00` (= `AMBER_DIM`) | `#FFB000` (= `AMBER`) | `#FFD27A` (= `AMBER_GLOW`) | `#FFF1C9` | `#FFB000` |
| **Cinder core** | `#8A5F00` | `#FFB000` | `#FFE3A3` (= `CORE`) | `#FFFFFF` | halo `#FFB000`, hot `#FFF1C9`, crack glow `#FF3B30` |
| **Enemy hull** (all normal types) | `#12060A` | `#2A0A10` (= `ENEMY_FILL`) | `#4A1220` | `#7A1E30` | rim/edge `#FF2D4B` (= `ENEMY_OUTLINE`), hot edge `#FF6B7E`, vent core `#FFC2CC` |
| **Enemy accent** (lancer lens, dart thruster) | `#8A1F78` | `#FF4FD8` (= `ENEMY_FIRE`) | `#FF9AE8` | `#FFE0F8` | halo `#FF4FD8` |
| **Boss hull** | `#1A0509` | `#3A0F18` | `#6A1C2A` | `#9A2E3E` | trim `#FF5A3C` (= `ENEMY_ELITE`), reactor `#FF3B30` to `#FFE3A3` core |
| **Enemy bolt** | `#8A1F78` | `#FF4FD8` | `#FF9AE8` | `#FFE0F8` core | halo `#FF4FD8` |
| **Floor** | `#07090C` (= `VOID`) | `#0B0E13` | `#12171D` (= `GRID`) | `#1B222B` | grid glow `#8A5F00` at 35% |
| **UI plate** | `#080B10` | `#0D1117` (= `PANEL`) | `#151B24` | `#222B38` | edge `#8A5F00`, active edge `#FFD27A` |

Rules:
- **Hostile vs friendly separation stays >= 25 L\*** (07 s5.3): enemy rim `#FF2D4B` and enemy accent magenta must always sit on a hull base darker than L\* 20; Cinder surfaces are always lighter than L\* 55 at base.
- **Cinder is the most saturated and brightest object**: no enemy emissive may exceed `#FFC2CC` at the vent core; only Cinder's core and the beam reach `#FFFFFF`.
- **Elite/boss differentiation** uses the orange-red trim `#FF5A3C` plus size; never new hues.
- **Glow colors equal the object's edge/emissive color**, additive, never white halos on enemies.
- Colorblind modes (07 s5.4) swap `ENEMY_OUTLINE`/rim and accent via a shader uniform `tint_hostile` on enemy materials (mapped in `Palette`); sprites are authored in the default palette. Full mode UI is M4; V1 only exposes the uniform.
- New `Palette` consts (V1-02 adds): `SKIN_SHADOW/LIGHT/HIGHLIGHT`, `CHAR_*`, `FRAME_SHADOW/LIGHT/HIGHLIGHT`, `HULL_*`, `ENEMY_RIM_HOT`, `ENEMY_VENT`, `BOSS_*`, `PLATE_*`, `ENEMY_FIRE_*`. Sprites bake these hex values; `Palette` holds them for code-drawn parts and tests assert the SVG sources only use hex values from the allowed list in `assets/art/slots.csv` (`palette` column) plus gradient stops derived from them (lint warns, not fails, for off-palette).

---

## 4. Sprites: scale, spec sheet and SVG rules

### 4.1 Visual scale (the "too small" fix, view-only)
Problem measured on the M1/M2 screenshots: camera 38 m wide gives 28.4 px/m; skitter radius 0.6 m is 17 px (34 px across, strokes 2.5 px), Cinder 56 px radius (112 px across, 10% of the width), and the 52 m arena shows mostly empty rings.

Proposal [D], three view-only changes (no sim number changes; GDD 02 s2 "camera about 38 m" becomes the *simulation reference*, the V1 view shows 32 m):
1. **Tighter camera: `VIEW_CAMERA_WIDTH_M = 32.0`** (from 38.0): 33.75 px/m, +19% everywhere. Alternative: keep 38 m and rely only on sprite scale (rejected: swarm overlap grows at the same time); alternative 28 m (33% bigger, rejected for now: the base `optic_range` 24 m ring would leave the screen on all sides and the first enemies are seen only 14 m out). Decided with the user at the style-frame gate (09 Q41).
2. **Visual scale `VISUAL_SCALE = 1.5`**: sprites are drawn 1.5x the hit radius. Hit radii are unchanged; beams end on the sprite edge nearest Cinder (section 6.1).
3. **Radial stand-off**: positions are remapped radially for drawing only, `r_draw = r_m * px_per_m + STANDOFF_PX * clamp(1 - (r_m - 2.0) / 8.0, 0, 1)` with `STANDOFF_PX = 72` (monotonic: slope 33.75 - 9 px/m > 0). Contact enemies (sim stop at 2.0 m) therefore appear touching Cinder's armor instead of overlapping its enlarged body. Enemies draw **below** Cinder in z-order. All view code that places something at a sim position (enemies, bolts, beam ends, death FX, damage numbers) calls the one remap function `ViewMath.map_pos`.

Resulting on-screen sizes at 1080 px width (body = armor/hull without legs, glow or barrel):
| Thing | Hit radius (m / px at 33.75) | Old body radius px | **New body radius px** | New body width | Share of width |
|---|---|---|---|---|---|
| skitter | 0.6 / 20 | 17 | **32** | 64 | 5.9% |
| dart | 0.5 / 17 | 14 | **28** (body length 90 incl. thrusters) | 56 x 90 | 8.3% long axis |
| walker | 1.4 / 47 | 40 | **70** | 140 | 13% |
| lancer | 0.7 / 24 | 20 | **36** (barrel to 58) | 72 x 116 | 10.7% long axis |
| boss_hulk | 3.0 / 101 | 85 | **150** | 300 | 28% |
| Cinder (skin ring outer) | 2.0 / 67.5 | 52 | **100** (emitters to 125, shoulder to 150) | 200 | 18.5% |
| enemy bolt | 0.3 / 10 | 8 | **22 long x 9 wide** | 44 x 18 | 4% |
Minimum on-screen sizes (acceptance for readability, V1-19): no enemy body narrower than 56 px; boss at least 280 px; Cinder at least 190 px; bolts at least 40 px long and 16 px wide; strokes/rims at least 3 px; interior seams at least 2 px; HUD text unchanged (GDD minimums).
The values live in `assets/art/slots.csv` (`body_radius_px`) and `ViewMath` consts so one edit rescales a type.

### 4.2 Cinder look decisions
- **Plated "skin"** [D]: the outer ring is **gunmetal / ceramic armor plates** (V1-GATE decision 4: raised light panels on dark plates, amber trim arc and indicator marks, rivets, scratches; supersedes the earlier warm sand-peach glaze), not organic skin: no pores, veins, flesh texture, gore or face. This keeps the GDD 01 idea "synthetic skin over a combat frame" and the IP guardrails. Open question 09 Q42 (recommendation: plated).
- **No face, no skull, no red eyes**: the visor is a horizontal **amber slit** on the facing arc (GDD 01 s3); no unit in the game has eyes.
- **Asymmetry**: left shoulder emitter assembly (larger than the skin ring's detail), fixed to the screen; three emitter nodes at 0/120/240 degrees on the rotating ring; one **amber hazard-paint bar** on the upper right frame only.
- **Construction**, back to front: shadow, frame (gunmetal ribbed disc with under-skin cavities), 12 skin wedges (alternating 2 art variants A/B so the ring is not identical), trim ring, core housing, core, emitter ring (rotates to the target), visor slit, shoulder assembly, glow layers (additive, half resolution).

### 4.3 Sheet format and global conventions
- **One SVG sheet per rendering family**, many frames/layers placed at fixed rectangles (cells) on it. Godot imports the SVG as one texture; the shader or sprite code selects the cell. This keeps draw calls low (one texture per MultiMesh/Cinder family) and keeps every slot a single replaceable file pair. [D]
- **File pair per family**: `<slot>.svg` (body, normal alpha blend) and `<slot>_glow.svg` (emissive layer, additive; **half the width and height** of the body sheet, same cell layout, so glow cells are 1/2 size and sampled with the same UVs). The shader combines them with `blend_premul_alpha` in one draw: `rgb = body.rgb * body.a + glow.rgb * glow_strength`, `a = body.a` (the glow adds light where the body is transparent and on top of it). [V: `blend_premul_alpha` and `blend_add` exist as canvas_item render modes, https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html]
- **Orientation**: art faces **+x (right)**; enemy sprites rotate so +x points at Cinder (as `ShapeMeshes` does now). Cinder's static layers are drawn pointing **up (-y)** where direction matters (wedge 0 starts at 12 o'clock, clockwise, matching `CinderWedges` indices).
- **Coordinates**: SVG user units = texels; `viewBox="0 0 W H"` with `width="W" height="H"` equal (so Godot's import scale 1.0 yields W x H texels); origin top-left; pivot is the cell center unless the table says otherwise.
- **Texel density D** (texels per on-screen px at 1080 width): enemies, bolt, Cinder 2.0; boss 1.5; glow sheets half of body; icons are DPI-independent (section 4.6). 
- **Import**: Godot rasterizes SVG at import by default; SVG is the only format importable as `DPITexture` (re-rasterized at runtime to match scale); `SVG > Scale` sets the render scale (1.0 = design size); mipmaps only help when zooming out, so **off**; `Process > Size Limit` can cap size; mobile textures should stay <= 4096 px per side [V: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html]. Sheets are all <= 2048 px per side. Sprite sheets import as `Texture2D` with **Compress = Lossless** (VRAM compression bands gradients and chroma-bleeds glow edges; the memory budget in section 9 assumes RGBA8), filter Linear, repeat off, **fix_alpha_border on**.
- **Imported texture location**: sources live at `assets/art/src/<slot>.svg`; Godot's import writes `<slot>.svg.import` next to them (committed) and the imported data under `.godot/imported/` (ignored). The code references `res://assets/art/src/<slot>.svg` through one loader `ArtSlots` that reads `assets/art/slots.csv`; **swapping commissioned or AI art = replace the SVG (or PNG with the same name and `.import`) and keep the cell table**, no code change. The table gives the cell size, frame count, pivot, body radius and fps per slot.

### 4.4 SVG authoring rules for agents
ThorVG (Godot's SVG rasterizer) targets SVG Tiny 1.2; its wiki lists supported elements/attributes including gradients, `stop-opacity`, `opacity`/`fill-opacity`/`stroke-opacity`, `mask`, `clip-path`, `filter`+`feGaussianBlur`, `pattern`, `use`/`symbol`, dashes, `mix-blend-mode`, and CSS only partially (no child combinators, ID selectors pending) [V: https://github.com/thorvg/thorvg/wiki/SVG-Support]. Godot's own docs say "SVG feature support is limited" and "complex vectors may not render correctly" and advise checking with ThorVG's viewer [V: importing_images.html above]. A listing in the wiki does **not** prove the ThorVG build bundled in Godot 4.7.2 renders it identically, so:

**Allowlist (agents may use)**: `svg`, `g`, `defs`, `path`, `rect`, `circle`, `ellipse`, `line`, `polyline`, `polygon`, `linearGradient`, `radialGradient`, `stop` (with `stop-color` and `stop-opacity`), attributes `fill`, `stroke`, `stroke-width`, `stroke-linecap`, `stroke-linejoin`, `fill-rule`, `opacity`, `fill-opacity`, `stroke-opacity`, `transform` (`translate`, `rotate`, `scale` only), `id`, `gradientUnits="userSpaceOnUse"`, `gradientTransform` (translate/scale only), one `clipPath` per file at most (for panel-line clipping; only after the probe passes).
**Forbidden**: `filter`/`feGaussianBlur`/drop shadows (bake blur by stacking gradient-filled shapes instead: a soft shadow = a radial gradient ellipse), `mask`, `pattern`, `image`, `text`/`tspan` (convert to paths), `style` blocks and CSS classes (inline attributes only), `use`/`symbol` (duplicate geometry so each layer id stays self-contained; repeated rivets are written out), `mix-blend-mode`, `marker`, `animate*`, `foreignObject`, external references, `skewX/skewY/matrix` transforms.
**Probe first [U]**: V1-01 step 1 renders `assets/art/probe/svg_probe.svg` (one tile per feature: linear and radial gradient with stop-opacity, group opacity, clipPath, mask, blur filter, pattern, `use`, dash) through the Godot importer on the dev machine and the emulator and writes the real support table to `docs/art/svg_support.md`. **That table overrides the allowlist above in both directions** (anything that passes may be added; anything that fails is removed). The lint (V1-02) reads the allowlist from `tools/art_rules.json`, generated from that table.
**Structure rules**:
- Top-level children of `<svg>` are groups named `slot.<cell_name>` (for example `slot.frame_0`, `slot.wedge_a`), each placed inside its cell rectangle; inside, sub-groups named `layer.<name>` (`layer.shadow`, `layer.base`, `layer.light`, `layer.highlight`, `layer.edge`, `layer.emissive`) in painting order. Nothing outside cells; nothing drawn within 4 texels of a cell border (glow bleed margin) except glow sheets, which use a 6-texel margin.
- Coordinates: absolute, integers or one decimal; **no `transform` on cell groups** other than a single `translate(x,y)` to the cell origin.
- **Node budget**: <= 400 drawing elements per sheet, <= 80 per cell (path complexity: <= 40 segments per path). Gradients: <= 24 `<defs>` entries per file, reused by id.
- Naming: lowercase snake_case ids, no spaces, ids unique per file.
- Palette: fills/strokes/stops use the hex values of section 3.2 only.
- **Authoring workflow for an agent**: write the SVG, run `tools\art_lint.ps1 <file>` (static rules), import in Godot and run `tools\art_check.ps1` (pixel rules: alpha outside cells is 0, every cell non-empty, silhouette solidity thresholds), view in the style-frame scene, screenshot at 1x and 3x crop. Reject-and-redo if the silhouette test (section 5) fails.

### 4.5 Sprite spec sheet
All sizes in texels; D as in 4.3; "px" = on-screen px at 1080 width. Frame cells are laid out left to right in one row. Glow sheet = same layout at half size. Pivot = cell center unless stated. `fps` = flipbook rate (frame = floor(time * fps + phase) mod n, phase from the instance id so the crowd does not march in step).

#### Enemies and bolt (MVP set)
| Slot (file) | Cell (texels) | Frames | Sheet size (body / glow) | Body radius | Animation | Silhouette identity (shape first) |
|---|---|---|---|---|---|---|
| `skitter` | 192 x 192 | 4 | 768x192 / 384x96 | 32 px | 4-frame crawl: alternating leg pairs, vent flicker; 8 fps | **Wedge crawler**: swept triangular carapace, 3 jointed legs per side splayed wide (legs reach 1.35 r), single rear vent glow |
| `dart` | 256 x 160 | 4 | 1024x160 / 512x80 | 28 px (length 90) | thruster flame cycle + wing-flap; 14 fps | **Thin arrowhead** twice as long as wide, swept wings, 3-line wake, magenta thruster accent (fast = magenta hint) |
| `walker` | 384 x 384 | 4 | 1536x384 / 768x192 | 70 px | 4-frame stomp: leg pairs lift, body bobs 4 px, vents pulse; 5 fps | **Wide trapezoid siege hull** with 4 thick piston legs, double rim, hazard stripe on the front plate; widest non-boss shape |
| `lancer` | 288 x 224 (pivot x 112 of 288, y center) | 3 (idle, charge, fire) | 864x224 / 432x112 | 36 px (barrel to 58) | idle breathing is shader pulse; frame 1 = lens charging (last 0.4 s before a shot is not exposed by the sim, so charge frame plays on the 0.5 s after a shot as recoil instead); 3 states picked by event | **Diamond with a long forward barrel**, magenta lens at the barrel tip (previews its bolts), fins; always readable as "has a gun" |
| `boss_hulk` | 640 x 640 at D 1.5 | 1 body + 4 glow frames (glow cell 320x320) | 640x640 / 1280x320 | 150 px | body static; reactor/vent glow cycles 4 frames at 6 fps, slow 1.2 s breathing scale of glow 4%; armor plates are separate overlay cells (reserved `boss_hulk_plates.svg`, 4 plates for the Launch plate mechanic) | **Hexagonal heavy node** with 6 clamp arms, central reactor cluster, orange trim; the only enemy with an orange-red trim and a reactor |
| `bolt` (enemy fire) | 128 x 64 | 2 | 256x64 / 128x32 | 22 px long | 2-frame flicker 12 fps | **Magenta diamond** with a trailing tail, white-pink core (07 s5.4: enemy projectiles are diamonds) |

Pivots: skitter, walker, boss at cell center; dart at (112, 80) (center of mass behind the tip); lancer at (112, 112); bolt at (56, 32).
States per enemy: **normal**, **hit flash** (shader, section 6.2), **spawn-in** (shader: 0.2 s scale 0.6 to 1.0 and alpha 0 to 1, driven by instance custom data), **death** (no sprite state: the instance disappears and the death burst plays, section 6.4). Elites/later types may add an `_alt` sheet.

#### Reserved slots for future enemies (do not author in V1; cells fixed now so code and tables do not change later)
| Slot | Cell | Frames | Silhouette note |
|---|---|---|---|
| `aegis_node` | 320x320 | 4 | hexagon ring, dotted inner circle, field drawn by shader as a dashed ring |
| `shade` | 192x192 | 4 | skitter-like outline, shader renders 15% alpha, no glow sheet |
| `jammer` | 256x256 | 4 | disc with 3 antenna spikes, teal-free (hostile) |
| `mender` | 288x288 | 4 | rounded cross carrier, orange-red trim |
| `siege_lance` | 384x384 | 4 | long barrel, planted legs, charge-line shader |
| `siphon`, `brood` | 256x256 | 4 | tendril-hose plate; segmented egg-hive |
| `boss_hive`, `boss_lance`, `boss_null` | 640x640 | 1 + 4 glow | each a boss hexagon variant with a distinct central feature (spawner doors, giant barrel, antenna array) |

#### Cinder (`cinder` sheet 1024 x 1024, `cinder_glow` 512 x 512, density 2.0; reference radius 100 px = 200 texels)
Cells (x, y, w, h) in texels; "center" = the layer is drawn around the cell center; the Cinder node places all layers at its origin.
| Cell (name) | Rect | Pivot | Content | Animation / use |
|---|---|---|---|---|
| `frame` | 0,0,448,448 | center | gunmetal ribbed disc r 200, 12 rib spokes, under-skin cavities at all 12 wedge positions (visible when a wedge is gone), 2 amber hazard bars (upper right), bolts | static; band 3 adds `frame_hot` glow |
| `emitter_ring` | 448,0,448,448 | center | ring r 190-210 with 3 emitter nodes (0/120/240 deg), lenses, small cooling fins | rotates to aim (smoothed, max 540 deg/s); active node = the one nearest the aim |
| `wedge_a_intact`, `wedge_b_intact` | 0,448,128,112 and 128,448,128,112 | (64, 196) | annular sector 30 deg, r 100-184 (so the cell holds the sector pointing up with center 196 texels below the cell top), panel lines, glaze highlight upper-left | one per wedge, rotated k*30 deg around the pivot; even k uses A, odd k B |
| `wedge_a_charred`, `wedge_b_charred` | 256,448,128,112 and 384,448,128,112 | (64, 196) | same sector, scorched panels, cracked glaze, exposed dark seams | charred state; ember overlay lives in the glow sheet |
| `core_housing` | 512,448,160,160 | center | hex bezel r 70 with 6 bolts, amber trim | static |
| `core` | 672,448,128,128 | center | hex core r 54, bright center to amber falloff, 2 inner facet lines | pulse 1 Hz scale +8%, brightness; band 3: swapped for `core_hot`, crack overlay |
| `core_crack` | 800,448,128,128 | center | jagged dark fissures over the core | band 3 only |
| `visor` | 0,576,160,48 | (80, 164) | amber slit arc +-23 deg at r 140 texels (bounding box 160x48), bezel above and below | authored pointing **up**; the pivot is the Cinder center, 164 texels below the cell top (outside the cell, like the wedges); rotated by `aim + 90 deg` |
| `shoulder` | 448,576,224,160 | (150, 96) mount point | left shoulder emitter assembly: mount arm, housing, lens, ribs; larger than ring detail; placed at (-125, -22) px from the center | fixed to screen; lens pulses when firing |
| `shadow` | 672,576,336,336 | center | soft elliptical drop shadow (radial gradient, black 55% to 0) offset applied in code (+8, +12 px) | static |
| `integrity_ticks` | 0,704,448,64 | (224, 32) | tick/scale ornament segment (repeated by code around the integrity ring at 5 deg) | static |
Glow sheet cells (half size, same arrangement; **additive**): `halo_core` (core halo r 130 texels at the half scale), `frame_hot` (frame rib glow, white-hot, band 3), `ember_edge_a/b` (orange rim light for charred wedges, same 30 deg sector shape), `emitter_glow` (3 lens glows), `visor_glow`, `shoulder_glow`, `seam_glow` (warm seam light across the intact skin ring, 40% amber), `core_hot_halo`, `integrity_halo` (soft ring behind the integrity arc).

**Cinder states**:
| Band | Skin wedges (by `CinderWedges.states`) | Frame | Core | Extras |
|---|---|---|---|---|
| 0 intact | 12 intact (A/B alternating) | normal | pulse 1 Hz amber | seam glow |
| 1 scorch | wedges 2, 7, 10 charred (+ ember_edge), rest intact | normal | pulse 1 Hz | embers 3/s from charred wedges, sparks 1/s |
| 2 exposed | wedges 0,2,3,5,7,8,10,11 gone (frame cavity visible), 1,4,6,9 charred | ribs visible, flicker 6 Hz of ember edges | pulse 1.3 Hz, brighter | embers 8/s, sparks 3/s, frame glints |
| 3 white-hot | all gone | **white-hot frame glow** (`frame_hot` at 0.65 + 0.35 pulse) | `core_hot` + `core_crack`, heartbeat pulse 1.2 Hz double beat | embers 14/s, heat shimmer, red vignette (section 6.5) |
The `CinderWedges` logic and the debug band override are kept as is; the rig only changes how a state is drawn.

#### Lancer bolt
Already above (`bolt`). Player-side shots are not sprites (beam, section 6.1).

#### Floor and FX sheets
| Slot | Size | Content |
|---|---|---|
| `arena_floor` | 1080 x 1344 at D 1.0 (battle rect) | circular deck: concentric dark plate rings with seams, hazard-stripe ring at the 52 m edge (only the part inside the view), stencilled range markers "10 20 30" at the rings (paths, not text), a few cable runs and hatches off-center (asymmetry), dark center ring under Cinder |
| `fx_sheet` | 1024 x 512, one **white/neutral** sprite per cell, tinted at use | 128x128 cells: `halo_soft` (radial gradient), `flash_disc`, `flare_star_4` (4-point star), `flare_star_8`, `ring_thin`, `ring_thick`, `smoke_puff_a/b`, `spark_a/b/c` (streaks, 64x16 within 128 cells), `ember_a/b`, `shard_1..6`, `scan_sweep` (wedge fade 128x128), `muzzle_cone`, `beam_cap`; beam body texture `beam_strip` 256 x 32 in a separate cell row |
| `ui_kit` | see 7.1 | 9-slice frames, brackets, bars |
| `icons/*.svg` | 128 x 128 viewBox each | one per icon id (7.4), DPI-independent import |

### 4.6 Icons
UI icons import as **DPITexture** [V: SVG is the only format importable as DPITexture, re-rasterized at runtime for the current oversampling, importing_images.html] so they stay crisp at any dp/size; they are small and few, so runtime re-rasterization cost is acceptable. In-game sprites do not use it (fixed raster, predictable cost). [U: DPITexture cost on the emulator is measured in V1-20; fallback is a fixed 192 px raster import.]

---

## 5. Silhouette rules for readability (FC5)

Every enemy type is distinguishable by **shape first, color second** (07 s5.4). Rules:
1. **Aspect and mass ranking** (solid-black test, at 64 px): skitter = compact wedge (aspect 1:1, spiky legs), dart = long thin arrow (aspect 3:1.6, no legs), walker = widest/heaviest block (aspect 1:1.1, thick legs), lancer = diamond with a forward barrel (aspect 1.6:1 along the facing), boss = hexagon larger than anything (>= 2x walker area).
2. **One signature feature each**: skitter splayed legs, dart swept wings and tail wake, walker piston legs + hazard front plate, lancer barrel + magenta lens, boss reactor + clamp arms. No two types share a signature.
3. **No pair of round eyes, no skull motif, no face** on any unit; sensors are slits, vents and lenses, single and asymmetric (IP, section 11).
4. **Facing is legible**: every sprite has an unmistakable front (tip, barrel, plate) at +x.
5. **Danger tier by brightness of rim**: normal rim `#FF2D4B`; elite `#FF5A3C` double rim (reserved); boss orange trim + reactor; lancer additionally has a magenta lens ("dangerous: ranged").
6. **Crowd test (V1-19)**: the wave-50-style frozen screenshot (31 slots, FC5) rendered at 1080x2400 must pass: five type names recoverable by a reviewer agent from a 1 s equivalent crop test (agent compares labelled crops) and the user's FC5 check later. Failing types get redesigned before FX polish.
7. **Cinder always wins the eye**: Cinder luminance peak (core + beam) must exceed the brightest enemy pixel by >= 20 L\* in the style frame; measured by `art_check` on a screenshot crop.

---

## 6. VFX list (exact looks and budgets)
General: all FX are **additive** unless stated, tinted from the neutral `fx_sheet`, drawn through the **particle ring** (6.3) or a dedicated node, **view-only** (driven by sim events `SHOT_FIRED`, `ENEMY_HIT`, `ENEMY_KILLED`, `CINDER_HIT`, `BAND_CHANGED`, `BOSS_SPAWNED`, `RUN_ENDED`, `WAVE_STARTED`; never feeding back into the sim). Counts are **caps**; above the caps, effects are skipped (not queued). Every FX respects the QualityTier (section 9.3) and reduce motion (07 s4).

### 6.1 Beam (`vfx_beam`, `vfx_muzzle`, `vfx_hit_spark`)
- **Beam** (replaces `BeamRenderer._draw` lines): three stacked textured quads from the active emitter to the target's **near sprite edge** (end point = target position remapped, pulled back by 0.6 x its visual body radius so it ends on the hull): **glow** 36 px wide, `LASER_GLOW` `#FFB000` at 55%; **core** 8 px wide, `LASER_CORE` `#FFF1C9`; **hot center** 3 px, `#FFFFFF`. Texture `beam_strip` (soft across, slight bright noise along), width jitter +-12% and 2 px lateral wobble per beam for a live look. Lifetime **80 ms** linear fade (GDD), crit: widths x1.5, core `#FFFFFF`, plus crit flare at the end. Pool 16 (as now); draw calls: glow 1 + core/center 1 (batched same texture) = 2. At > 8 shots/s consecutive beams merge into one pulsing line (07 s5.3): the merged beam keeps one quad and pulses brightness at the shot rate.
- **Muzzle flash**: `flare_star_4` 64 px at the active emitter node, additive `#FFE3A3`, 60 ms, scale 0.6 to 1.3 then fade, plus `muzzle_cone` 90 px forward at 40% for 50 ms; the shoulder lens and the active emitter glow brighten 1.0 to 1.6 for 80 ms. Budget: 2 particles per shot.
- **Impact**: `spark` x 6 radial streaks (length 18-34 px, speed 260-420 px/s, 0.18 s), `ring_thin` 40 px expanding to 70 px in 0.12 s at 60%, `flash_disc` 28 px for 50 ms; **crit**: `flare_star_8` 90 px 0.15 s, 12 sparks, amber ring 110 px 0.2 s. Budget 9 particles per hit; cap 4 sparks per hit when > 6 shots/s; global cap with the particle ring. Burn mark: none (cost).
- Hit screen shake: none (section 6.6).

### 6.2 Hit flash (`ENEMY_HIT`)
Shader flash on the enemy instance: `rgb = mix(rgb, vec3(1.0, 0.93, 0.82), flash)`, `flash` = 1.0 at the hit, linear to 0 over 90 ms, set from `ENEMY_HIT` into a per-index `PackedFloat32Array` (flash timers) written into the instance custom data. Walker/boss flash capped at 0.6 so heavy units still show their shape. No extra draw call. Also a 1-frame 2 px recoil offset along the beam direction (shader or CPU: CPU, since the position is already computed).

### 6.3 Particle system (recommendation and alternatives)
**Recommended: one pooled "particle ring" MultiMeshInstance2D** [D]: capacity 400 (GDD 07 s6 cap), one quad mesh, one additive material, `use_colors` + `use_custom_data`; the CPU writes a particle **once at spawn** (position, velocity, color, lifetime, kind/cell, size, spin) and the **vertex shader integrates it analytically** from `view_time - birth` (position = p0 + v t + 0.5 g t^2, alpha/size curves by age). No per-frame CPU work per particle; the buffer is re-uploaded only on frames that spawned something. Dead slots are reused round-robin (oldest overwritten). `fx_sheet` cell chosen in the fragment shader from the kind. **[U]** whether canvas_item `vertex()` can displace a MultiMesh instance's quad per-instance in 4.7.2 Compatibility (INSTANCE_CUSTOM is a vertex-stage built-in [V: canvas_item_shader.html]; MultiMesh custom data is 16-bit per component on Compatibility [V: https://docs.godotengine.org/en/stable/classes/class_multimesh.html], enough for lifetimes up to a few seconds but not for large absolute positions, so positions are written in the instance transform, not custom data). Spike in V1-13; **fallback**: CPU-integrated particles in GDScript over packed arrays (400 particles x 8 floats; budget <= 0.8 ms/frame on the emulator, to be measured) writing the same MultiMesh buffer.
Alternatives rejected: **GPUParticles2D** (docs: "may not run on older devices" [V: https://docs.godotengine.org/en/stable/classes/class_cpuparticles2d.html], one node per effect adds draw calls, hard to pool per-event bursts); **CPUParticles2D per effect** (many nodes, one draw call each, 8 simultaneous bursts = 8+ calls). CPUParticles2D remains acceptable for the 24 ambient motes (one node, one call) if the ring is saturated.

Particle budget: cap 400 live (hard), typical combat 80-160; LOD: when enemies alive > 100 the per-hit spark count halves; > 150 it drops to 2 sparks and no impact ring; kill bursts keep their shards but skip smoke.

### 6.4 Death bursts (`vfx_kill_shatter`, `vfx_death_unravel`)
- **Normal kill**: `flash_disc` 1.2 x body radius for 70 ms in the enemy's glow color, 5-7 `shard_*` (tinted hull `#4A1220` to rim `#FF2D4B`, size 10-22 px, speed 120-300 px/s, spin, 0.45 s, fade), 4 `spark`, 1 `smoke_puff` (alpha blend, `#2A0A10` at 40%, 0.5 s; skipped above 100 alive). Walker: shards x2 and a short 6 px shake-free `ring_thick`. Particles per kill: <= 12 (skitter/dart/lancer), <= 22 (walker). Kills per frame can reach 10+ at high fire rates: global cap makes the ring drop the oldest particles first.
- **Boss death** (`boss_hulk`): 0.25 s white-hot `flash_disc` 2.5 x radius, 3 expanding `ring_thick` (amber then red), 24 shards, 40 sparks, 3 secondary mini-bursts at random hull points at 0.15/0.3/0.45 s, smoke 6 puffs; **120 particles max**, screen shake (6.6) and 0.4 s slow-mo (6.6). Boss spawn: warning ring (07 s6 `vfx_boss_warning`) in `WARNING` amber at the spawn bearing plus 0.25 s shake.
- Cinder death (`RUN_ENDED`): wedges fly out, frame fades last, 0.4 s white `flash_disc` over the arena at 35%, then slow vignette to black; hands over to the results overlay with the existing timing.

### 6.5 Cinder damage, skin burn and low HP (`vfx_skin_embers`, `vfx_band_transition`)
- **Hit on Cinder** (`CINDER_HIT`): core brightness +60% for 100 ms; frame shiver (+-2 px random offset for 100 ms on frame/skin/ring layers, off under reduce motion); integrity ring segment at the current value flashes `CRITICAL` for 120 ms; 4 red-orange sparks from the impact side (angle from attacker bearing is not in the event: random around the ring); shake `CINDER_HIT` (6.6).
- **Band transition** (`BAND_CHANGED`, going down): an expanding ring (amber `#FFB000` for 1, orange `#FF8A1F` for 2, red `#FF3B30` for 3; from 90 to 260 px in 0.35 s), the newly lost wedges **detach**: scale 1 to 1.15, fly outward 60-110 px with spin over 0.6 s and fade, each spawning 4 embers; 0.3 s brightness flash on the frame; shake 8 px (band 3: 10 px). Going **up** (heal): wedges re-form one by one every 0.125 s (1.5 s total, GDD 02 s12.1) with a quick scale 0.7 to 1 and a teal-white 60 ms edge flash.
- **Ember emission** (continuous): band 1: 3/s (2 charred wedges at a time), band 2: 8/s, band 3: 14/s + heat shimmer (a slow additive `halo_soft` wobble on the frame, no distortion shader). Embers: `ember_*` 6-10 px, `#FF8A1F` to `#FFD27A`, rise outward 30-70 px/s, 0.8-1.2 s.
- **Low-HP vignette and heartbeat** (moved from M4): band 3 only (and a faint static 8% at band 2): the arena shader (6.7) darkens the edges with `RED_HAZE`/`CRITICAL`, intensity 0.25 to 0.45 pulsing as a **double beat (lub-dub) at 1.2 Hz** with the core `core_hot` pulse in sync; reduce motion = static 0.3. Heartbeat SFX id `sfx_integrity_warn` is M4 (audio). `vfx_meltdown_whiteout` is not in V1.

### 6.6 Screen shake and slow-mo policy
Shake is **subtle, view-only and toggleable** [D]:
- Applied as a position offset on the **BattleView root** only (HUD and panel never shake). Trauma model: `offset = max_offset * trauma^2 * noise(t)`, trauma decays 2.5/s, **no rotation**, `max_offset = 10 px` hard clamp at 1080 wide.
- Events (trauma added): Cinder hit 0.08 + 0.4 x (damage / max_hp) capped at 0.3 (so a hit for 5% hp shakes about 1 px, a hit for 50% about 3-5 px); band transition 0.5 (band 3: 0.65); boss spawn 0.35; boss death 0.7; Cinder death 0.9. **Never on enemy kills, enemy hits or the player's own beam.**
- Setting: `screen_shake` = Off / Low (max 5 px, default) / Normal (10 px). `reduce_motion` (07 s4) forces Off. Default: **Low** (09 Q43). The settings screen itself arrives in M3/M4; V1 reads `VisualSettings` (a view-side autoload-free resource) with a debug-overlay toggle and a `--shake=off|low|normal` arg.
- **Hit-stop: no sim hit-stop.** The sim is never paused or slowed per hit. **Slow-mo is allowed only at boss death (0.4 s at 0.35x) and Cinder death (0.8 s at 0.25x)**, implemented in the view-side tick driver as a reduced accumulator rate (ticks are never skipped or merged, so every state hash is identical; only wall-clock pacing changes), disabled under reduce motion, never active at game speed > 2x. If the tick driver cannot be changed without touching sim code, the feature is dropped and recorded (the sim stays untouched).

### 6.7 Arena: animated grid, scanlines, vignette (`arena_fx`)
One full-rect ColorRect over the battle rect with one shader, cost = one full-rect pass: (a) **polar grid** drawn analytically (spokes every 30 degrees, rings every 10 m at 1 px/1.5 px antialiased) with glow `#8A5F00` at 35%; (b) **radar sweep**: a rotating wedge (`scan_sweep` gradient math, 90 deg trailing fade, `AMBER_DIM` at 12%) once per 8 s (the existing 8 s Cinder scan period); (c) **range ring pulses**: every 4 s a faint ring expands from Cinder to 30 m (amber 8%); fades when > 100 enemies (07 s5.3, grid fades above 100); (d) **optic range ring** unchanged (amber 35%, drawn in the same shader from a uniform); (e) **scanlines** 2 px at 6% opacity (GDD; user-adjustable, section 6.8), battlefield only, off in reduce motion/high contrast; (f) **vignette** 20% edge darken plus the low-HP red pulse; (g) **ambient motes**: 24 drifting dim specks (`CPUParticles2D`, one node) in `AMBER_DIM`/`FRAME` at 10-20% alpha, slow upward drift, off in LOW tier.
Order (bottom to top): `arena_floor` sprite, `arena_fx` shader quad, enemies, Cinder, beams/particles, `arena_fx_overlay` (scanlines + vignette only, so grid does not draw over units). Two full-rect passes at most (floor + fx) plus one overlay pass: **3 full-rect passes** budgeted; the sweep/grid pass is merged into the floor's material if the overlay is merged with it (decision at V1-08 by measured cost).

### 6.8 Scanline / CRT overlay
Only scanlines + vignette (no curvature, no chromatic aberration, no bloom; they cost fill-rate and blur the sprites). Intensity setting: Off / Low 3% / Normal 6% (GDD default) (09 Q44; recommendation: Normal 6%, because it is faint and the user asked for atmosphere, with a one-tap Off). Moire check at 1080 wide: lines are 2 px period 4 px; screenshot review at 1x.

### 6.9 Other FX ids touched in V1
`vfx_hit_spark`, `vfx_kill_shatter`, `vfx_crit_flare`, `vfx_skin_embers`, `vfx_band_transition`, `vfx_death_unravel`, `vfx_boss_warning` (ring only), `vfx_wave_banner_glitch` (HUD, 7.5), `vfx_milestone_ring` (upgrade row, 7.3). Later (not V1): overcrit burst, ricochet, split, razor, shock/mine/arc/EMP/missile/singularity/nanite/beacon/painter/barricade/turncoat, draft open, cache, pod, overdrive afterimage, meltdown whiteout.

---

## 7. HUD and UI styling

### 7.1 Frame language
- **Chamfered plates**: rectangles with 20 px (1080 base) cut corners at top-left/bottom-right only (asymmetric, not rounded), 2 px edge in `AMBER_DIM`, active/hover edge `AMBER_GLOW` with a 6 px soft glow (additive halo texture behind the control).
- **Corner brackets**: amber `AMBER` 3 px L-shaped brackets (24 px legs) on the outer corners of major groups (top bar, panel, results card).
- **Inner bevel**: 1 px lighter line top/left, darker bottom/right on plates (fake depth), plus a faint horizontal scanline texture inside plates (4%).
- **Tick marks and stencil labels**: tick rows on bars (every 10%, longer at 25/50/75), stencilled small labels in `TEXT_DIM`, hazard-stripe accents on the Foundry/Max button only.
- **9-slice SVG panels** (in `ui_kit.svg`, imported as `Texture2D` at D 1.0 and used by `StyleBoxTexture` with `texture_margin` 28): `panel_plate` (96x96, corner cuts + edge, margin 28), `panel_plate_active` (same with glow edge), `panel_inset` (row background, 96x96, margin 24), `button_plate` (+ `_pressed`, `_disabled`, `_affordable`), `tab_plate` (+ `_active` with open bottom), `bar_frame` (timer/integrity: 96x40 margin 16, end caps), `bar_fill_segment`, `tooltip_plate`, `bracket_corner`, `divider`. Rules for 9-slice SVGs: only the four 28 px corner cells carry the cut-corner art; edge cells and center are uniform along their stretch axis (no gradients that vary along the stretched direction, no ornaments in edge cells); verified by `art_check`.
- **Touch targets unchanged** (07 s1: >= 148 px); styling must never shrink the clickable rect.

### 7.2 Battle HUD (07 s2.1, ids unchanged)
Top bar plate (chamfered) holding `hud_wave` (stencil "WAVE" small + number big, Oxanium 600), a **segmented timer bar** (bar_frame with 24 segments + moving bright segment head; 1 segment per second), speed and pause as `button_plate` squares with icons; integrity shown as the **segmented bar** under the top plate (40 px tall, 20 segments, teal -> amber -> red like the ring, `hp 80/100` numbers in `LabelNumber` right-aligned inside, damaged segments flash `CRITICAL` 120 ms); `SCRAP` / `DATA` counters on small plates with their currency icons (`SCRAP` `#D6B36A`, `DATA` `#5BC8FF`). A **wave banner** (`vfx_wave_banner_glitch`): "WAVE 37" in a chamfered plate sliding in from the left, 0.35 s with 2 horizontal slice offsets for 80 ms, holds 0.8 s, out 0.25 s; boss wave: `WARNING` amber with hazard stripes and the boss chip.

### 7.3 Upgrade panel, rows, tabs, buttons
- Panel background: `panel_plate` with corner brackets; tabs = `tab_plate` (active tab has an amber top bar and glow; icon + label); buy-mode chips x1/x10/x100/MAX = small `button_plate`, the active one with glow edge.
- **Row** (231 px high): `panel_inset` background, **icon 96 px** in a chamfered icon plate tinted by damage-type color (07 s2.2), name in `LabelBody`, level `L24` in a small plate, `current -> next` in `LabelNumber`, the **cost button** a `button_plate` (`_affordable` = amber edge + inner glow pulse 1.2 s when affordable, `_disabled` = dim plate with a small lock mark; never red). **Milestone ring** (`vfx_milestone_ring`): rows within 3 levels of x1.5 show a gold animated ring (2 s sweep) around the icon plate; on the milestone purchase, a gold ring expands over the row 0.4 s.
- Purchase feedback: the button depresses 4 px, a 120 ms amber flash runs across the row, the level number rolls (7.5).
- Rows of locked upgrades remain hidden (07 s2.2); "Next unlock at wave X" is a stencil line at the list bottom.

### 7.4 Icons: one SVG per id (128 x 128 viewBox, flat 2-tone + highlight, damage-type color)
- **Upgrades (10, M2 ids)**: `laser_output` (beam through a lens), `cycle_rate` (circular arrows over a pulse), `crit_chance` (target reticle with a spark), `crit_mult` (starburst x), `optic_range` (concentric rings with a scale), `hull_integrity` (plate with a hex bolt), `nano_repair` (wrench + plus, teal), `plating_pct` (stacked plates), `scrap_yield` (bent plate stack, `SCRAP` color), `reinvest` (loop arrow over a coin-less plate).
- **Tabs (4)**: `tab_arms`, `tab_chassis`, `tab_systems`, `tab_intel`.
- **Currencies (5)**: `cur_scrap` (bent plate), `cur_data` (hex cell), `cur_flux` (diamond), `cur_cipher` (key ring), `cur_merit` (chevron star), colors per 07 s5.2.
- **HUD (8)**: `ic_speed`, `ic_pause`, `ic_play`, `ic_settings`, `ic_lock`, `ic_check`, `ic_clock` (time survived, amber), `ic_kills` (hostile wedge struck through, red; results screen, M4).
- Icon style (09 Q45): **bold flat glyphs on a chamfered plate** (recommended) vs thin outline icons; no text in icons; 2 px minimum strokes at 96 px.

### 7.5 Numbers and motion
- **Number roll**: counters (`SCRAP`, `DATA`, wave, costs) interpolate to the new value over 0.25 s ease-out (display only), at most 10 label updates per second (TECH 2.7: throttle to 10 Hz), and flash `AMBER_GLOW` for 120 ms on increase; decreases flash `TEXT_DIM`. BigNum values roll on the formatted mantissa only.
- Fonts unchanged (Oxanium headings, Share Tech Mono numbers; GDD minimum sizes).
- All UI motion respects reduce motion (instant changes).

### 7.6 Results screen (07 s2.10)
Full-width `panel_plate` card with corner brackets; header "DEPLOYMENT ENDED" glitch-in 0.3 s; stat lines appear one by one (0.12 s apart) with number roll; `DATA +x` as a large `LabelHeading` with the `cur_data` icon and a 0.6 s tally; cause-of-death chip with the killer's small sprite (from the slot table, 64 px); damage-by-type bars as segmented bars; `REDEPLOY` = large amber `button_plate` with glow, `HOME` secondary. No ad slot art in V1.

---

## 8. Background and environment
`arena_floor` (4.5) + `arena_fx` (6.7) + ambient motes + spawn markers (small amber chevrons on the screen edge at the bearing of upcoming spawns, 0.8 s, from `WAVE_STARTED`/`ENEMY_SPAWNED` events, cap 12; optional, V1-08 only if budget allows). Cinder sits on a dark circular **pad** drawn in the floor (r ~ 170 px) so its shadow reads. No parallax, no animated floor texture (static texture, animated light only).

---

## 9. Performance budgets

### 9.1 Reference numbers
Measured (M1, `docs/playtests/m1_emulator.md`): Intel Iris Plus emulator, 1080x2400, ~165 enemies, **31.9 fps average** (windows 27.4-34.5, dips to 12), 14-34 fps with few enemies; sim 0.2-1.2 ms/tick; memory 187 MB PSS. The emulator is GL-translation bound and slower than a 2020 mid-range phone for GL; a real-device check waits on 09 Q23. Targets (TECH 2.7, GDD FC6): 55 fps at 100 enemies and >= 30 fps at 160 on the reference device; battlefield draw calls <= 25 (hard 40).

### 9.2 Per-item budgets (battlefield, 1080 x 1344 area; "MP" = megapixels of fill)
| Item | Draw calls | Overdraw / fill | Count caps | Texture mem (RGBA8) | CPU render prep |
|---|---|---|---|---|---|
| Arena floor + `arena_fx` + overlay | 3 (full-rect passes) | 3 x 1.45 MP = 4.3 MP | - | floor 5.8 MB | ~0 |
| Enemies (5 types + bolt MultiMeshes) | 6 | avg body 65 px square x 165 = 0.7 MP; worst crowd near Cinder x3 = 2.1 MP | 160 normal + 8 boss + 100 bolts | skitter 0.6 + dart 0.7 + walker 2.4 + lancer 0.8 + boss 2.0 + bolt 0.1 = ~6.6 MB (+ glow ~1.7) | <= 2.0 ms (fill loop + 6 uploads; M1 measured fill is well below) |
| Cinder rig | 4 (normal batch, glow batch, ring/arc procedural, integrity) | ~0.2 MP | 12 wedges + 8 layers | sheet 4 MB + glow 1 MB | <= 0.3 ms |
| Beams | 2 | <= 16 quads x 40 px wide | 16 beams | in `fx_sheet` | <= 0.1 ms |
| Particle ring | 1 (additive) | 400 x avg 24 px square = 0.23 MP | 400 | `fx_sheet` 2 MB | <= 0.8 ms (CPU fallback) / ~0.1 ms (shader) |
| Damage numbers (M4) | 1 | small | 24 | font | - |
| Ambient motes | 1 | negligible | 24 | - | - |
| **Total battlefield** | **~17-20** | **<= 8 MP (5.5x of 1.45 MP) typical, hard 11.6 MP (8x)** | | **<= 30 MB art textures (hard 48 MB)** | **<= 3.5 ms (TECH render prep 3, hard 5)** |
UI: panel and HUD use `StyleBoxTexture` plates (batched) and icons; UI <= 2 ms (TECH 2.7), draw calls for UI not counted in the battlefield 25 but tracked.

### 9.3 Quality tiers (view-only; never change the sim) and fallback
| Tier | Intended for | Differences |
|---|---|---|
| **HIGH** (default on emulator until measured) | mid/high phones | everything on |
| **MID** | 2020 mid-range if HIGH misses 45 fps floor | particle cap 200, scanlines off, ambient motes off, range-ring pulse off, impact rings off, shake Low max |
| **LOW** (also the battery saver of 07 s4: 30 fps cap) | old/low phones | cap 80 particles, glow sheets not sampled (alternate material without the second texture), no radar sweep, no vignette pulse, wedges snap instead of animate, 2 sparks per hit |
The tiers are one `VisualQuality` resource (view side, not a sim input) with a debug toggle and `--quality=high|mid|low` arg; auto-detection is M6 (6D QualityTier detection) and the real-device values wait for Q23. **Fallback ladder when over budget** (TECH 2.7 order): lower shake and particles, then scanlines/motes, then glow sheets, then flipbook frozen at frame 0 for crowd units. WorldEnvironment glow is not part of any tier (section 10).

### 9.4 Acceptance numbers (also in V1-20)
- Emulator at ~165 enemies (the debug LOAD scenario to wave 60): **average fps >= 28.7** over a 180 s window (<= 10% below the 31.9 fps M1 baseline), measured with FX on at HIGH; if the emulator misses it, MID must reach >= 31.9 and the miss is documented (Q40 still stands).
- Draw calls (battlefield) **<= 25** read from `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` (the monitor exists in the Performance singleton; confirm the exact name when implementing, U) printed in the `[PERF]` line; texture memory from the Performance monitors <= 48 MB art.
- No growth: PSS within +10% of the 187 MB M1 baseline plus the texture budget (<= 240 MB), flat over 4 minutes.

---

## 10. Glow technology decision (verified facts)
- **WorldEnvironment glow in the Compatibility renderer exists** with "a different implementation with some properties being unavailable" (Levels, Normalized, Strength, Blend Mode, Mix, Map hidden) and is "optimized to run on low-end devices" [V: https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html]. **HDR 2D is documented only for Forward+ and Mobile** ("Since Godot 4.2 ... when using the Forward+ and Mobile rendering methods", same page). In 2D without HDR 2D, glow needs the environment background set to **Canvas** and the **Glow HDR Threshold lowered**, with UI in a separate CanvasLayer (same page). A community answer says glow-level tuning is unavailable in Compatibility [U, forum thread, 4.6-era].
- **Decision [D]:** the default look uses **baked additive glow** (the `_glow` sheets with premultiplied-alpha one-draw compositing, `halo_soft` sprites, the beam strips) because it is zero post-process cost, deterministic across devices and tunable per asset. WorldEnvironment glow is **not used by default**. V1-01's style frame includes one **A/B capture** with Canvas-mode environment glow enabled (threshold lowered, UI on a CanvasLayer) to document its look and emulator fps cost; it may be adopted later as a HIGH-only extra only if (a) its fps cost on the emulator is under 10% and (b) the real-device check (Q23) agrees. [U: cost on the target devices.]
- TECH_ARCHITECTURE 1.1 point 4 ("glow is done with our own additive blend shaders") is consistent; the "half-resolution blur SubViewport bloom" of TECH 2.6 is **dropped** from V1 (too costly for the gain).

---

## 11. IP guardrails for art (hard; extends 00 s7 and CLAUDE.md)
- Cinder: no skull or skull-like face, no red eyes (the visor is amber; no paired lights), no chrome endoskeleton look (frame is dark gunmetal with warm plating, never mirror-chrome), no half-flesh face, no human face or hands, no flesh texture. The warm panels are **armor plates**.
- Enemies: no skull faces, no paired red eyes, no humanoid endoskeleton, no tank-tread flying-craft clones of film hardware, no liquid-metal morphing, no T-shaped logos; enemies are insectoid/industrial machines.
- No text or logo from any franchise or from The Tower; no hexagon-over-tower composition; icons are original.
- HUD: no cloned layouts from The Tower; the chamfered-plate language is generic sci-fi.
- Palette stays multi-color (amber/teal/red/magenta); not a mono red-tint look.
- Agents must not reference any film or game by name inside SVG ids, comments or filenames. Review step in V1-22: grep the art sources and docs for the banned strings in CLAUDE.md.
- Commissioned/AI replacements (09 Q14): the same slot table and guardrails apply; AI-generated art needs a provenance note per file in `assets/art/PROVENANCE.csv` (source, tool, license).
