# SVG support in Godot 4.7.2 (ThorVG) - probe result

Changelog: 2026-11-08 v1.0 - first version (V1-01 step 1). **This file overrides `docs/design/10_art_bible.md` section 4.4 where they differ.**

Probe file: `assets/art/probe/svg_probe.svg` (824 x 560, 24 tiles of 128 x 128). Rasterized with `Image.load_svg_from_buffer` (the importer's rasterizer) via `tools\svg_render.ps1`, **and** through a real headless `--import` of the same file: the imported `CompressedTexture2D` is pixel-identical to the direct rasterization (0 differing pixels, max delta 0), so `svg_render.ps1` output is what the game gets. Follow-up probes of mask and pattern variants were run from a throwaway file (results folded in below).

Not run on the emulator (another agent holds it); the integrator verifies on-device later. ThorVG is software-rasterized at import time on the host, so the emulator only sees the imported texture; device risk is limited to texture format, not SVG features.

## Result table

Tile position: column c, row r (0-based); tile origin x = 8 + 136c, y = 8 + 136r, size 128 x 128. Labels are `<!-- t<r><c> -->` comments in the probe file (`<text>` does not render, see t32).

| Tile | Feature | Result | Note |
|---|---|---|---|
| t00 (c0,r0) | `linearGradient` (objectBoundingBox) | PASS | exact |
| t01 (c1,r0) | `radialGradient` with `stop-opacity` 1 to 0 | PASS | smooth falloff, transparent edge (no dark fringe) |
| t02 (c2,r0) | group `opacity` | PASS | group is flattened first (overlap lens is not darker) |
| t03 (c3,r0) | `clipPath` (circle on a `g`) | PASS | clean antialiased edge |
| t04 (c4,r0) | `mask` with a **gradient** inside | **FAIL** | renders nothing at all |
| t05 (c5,r0) | `filter` + `feGaussianBlur` | PASS | soft blur, works with explicit filter region; (follow-up: `stdDeviation` 12 on a r20 disc also fine) |
| t10 (c0,r1) | `pattern` | **FAIL** | draws nothing (also fails with `viewBox`, `patternTransform`, objectBoundingBox units) |
| t11 (c1,r1) | `use` (`xlink:href` and plain `href`) | PASS | both attribute spellings work |
| t12 (c2,r1) | `stroke-dasharray` + round caps | PASS | dots and dashes correct |
| t13 (c3,r1) | `transform` translate + rotate + scale | PASS | |
| t14 (c4,r1) | inline `style="fill:..;stroke:..;opacity:.."` | PASS | |
| t15 (c5,r1) | `gradientTransform` translate + scale | PASS | |
| t20 (c0,r2) | `userSpaceOnUse` linear gradient | PASS | |
| t21 (c1,r2) | radial gradient with `fx`/`fy` | PASS | |
| t22 (c2,r2) | `userSpaceOnUse` radial with mid `stop-opacity` | PASS | |
| t23 (c3,r2) | `stroke-linejoin`/`linecap`, `fill-rule="evenodd"` | PASS | |
| t24 (c4,r2) | `fill-opacity` / `stroke-opacity` | PASS | |
| t25 (c5,r2) | gradient used as `stroke` paint | PASS | |
| t30 (c0,r3) | `symbol` (with `viewBox`) + `use` width/height | PASS | |
| t31 (c1,r3) | `mix-blend-mode:screen` | **FAIL** | ignored (opaque normal blend) |
| t32 (c2,r3) | `<text>` | **FAIL** | draws nothing (no font) |
| t33 (c3,r3) | CSS class from a `<style>` block | PASS | simple `.cls{}` selectors work |
| t34 (c4,r3) | `skewX`, `matrix` transforms | PASS | |
| t35 (c5,r3) | `ellipse`, `line`, `polygon`, rounded `rect`, path arc + cubic | PASS | |

Follow-up variants (`build/svg_probe2.svg`, `svg_probe3.svg`, not committed):

| Feature | Result | Note |
|---|---|---|
| `mask` containing a **solid** white rect with a black circle (`maskUnits="userSpaceOnUse"`) | PASS | luminance of solid fills works |
| `mask` with gradient fill, `mask-type:alpha`, `fill-opacity` inside the mask | **FAIL** | blank |
| `feDropShadow` | **FAIL** | shape drawn, no shadow (bake shadows with a gradient ellipse) |
| `feColorMatrix` | not tested | do not use |

## Import settings (Godot defaults already match; keep them)

`.import` produced by Godot 4.7.2 for an SVG: `importer="texture"`, `svg/scale=1.0`, `mipmaps/generate=false`, `compress/mode=0` (Lossless), `process/fix_alpha_border=true`, `process/premult_alpha=false`, `process/size_limit=0`, filter/repeat left to the node. Commit the generated `<name>.svg.import` next to each SVG. Texture size = `width x height` of the SVG at scale 1.0 (probe: 824 x 560, 1.8 MB as RGBA8). Full-project headless import after adding the probe took 14 s total. Sheet memory (RGBA8, from sizes): boss_hulk 1.6 MB, boss_hulk_glow 1.6 MB, bolt 0.06 MB, bolt_glow 0.02 MB, fx_sheet 2.0 MB, arena_floor 5.8 MB.

Because import is **straight alpha** (`premult_alpha=false`), shaders that composite with `blend_premul_alpha` multiply `rgb * a` themselves (see `assets/shaders/style_frame_enemy.gdshader`).

## Final allowlist (agents may use)

Elements: `svg`, `title` (ignored), `defs`, `g`, `path`, `rect` (with `rx`/`ry`), `circle`, `ellipse`, `line`, `polyline`, `polygon`, `linearGradient`, `radialGradient` (with `fx`/`fy`), `stop` (`stop-color`, `stop-opacity`), `clipPath` (tested with one; keep to <= 4 per file), `mask` (**solid-fill content only**, `maskUnits="userSpaceOnUse"`; never a gradient inside), `filter` containing **only** `feGaussianBlur` (always give an explicit generous region `x/y/width/height`, use at most 8 per file because each is a full raster pass at import; never rely on a blur crossing a cell border), `use` / `symbol` (both `href` and `xlink:href`; the art bible's "duplicate geometry" rule still applies for layer-id self-containment, use only for repeated identical items), `style` block with plain class selectors (discouraged; prefer attributes).

Attributes: `fill`, `stroke`, `stroke-width`, `stroke-linecap`, `stroke-linejoin`, `stroke-dasharray`, `fill-rule`, `opacity`, `fill-opacity`, `stroke-opacity`, inline `style="..."` for those properties, `transform` (`translate`, `rotate`, `scale`, **plus `skewX`/`skewY`/`matrix`**), `gradientUnits` (both values), `gradientTransform` (translate/scale tested), `clip-path`, `mask`, `filter`, `id`, `viewBox`, `xmlns`, `xmlns:xlink`.

**Forbidden (FAIL or untested)**: `pattern` (draws nothing: write dots/hatches out as path geometry), `mask` with gradients (bake the fade into gradient `stop-opacity` instead), `mix-blend-mode`, `<text>`/`tspan` (convert to paths), `feDropShadow` and every filter primitive other than `feGaussianBlur`, `image`, `marker`, `animate*`, `foreignObject`, external references, `switch`.

Differences to art bible 4.4: **added** `use`/`symbol`, `filter`+`feGaussianBlur`, solid `mask`, `clipPath` (the bible allowed one per file), `stroke-dasharray`, `skewX/skewY/matrix`, inline `style`; **confirmed forbidden** `pattern`, gradient `mask`, `mix-blend-mode`, `text`. Everything else in 4.4 (structure rules, node budget, palette) stands.

## Authoring notes learned in the probe

- Render with `& .\tools\svg_render.ps1 -Bg "" ...` in the same PowerShell session; `powershell -NoProfile -File ... -Bg ""` loses the empty argument (parse error "Missing an argument for parameter 'Bg'"). Omit `-Bg` and pass a color instead, or call the script in-process.
- `Image.load_svg_from_buffer` and the importer agree exactly, so no separate import render is needed to judge a sheet.
- Soft glows: radial gradient with `stop-opacity` going to 0 and **constant hue** in every stop gives clean premultiplied-friendly edges.
