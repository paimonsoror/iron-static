# IRON STATIC - Technical Architecture and Phased Development Plan

Changelog: 2026-11-07 v1.1 - Reconciled with the GDD (`docs/design/`): The Tower vocabulary replaced by GDD terms and ids; wave timing (24 s = 18 s spawn + 6 s lull), 4x speed cap, entity caps and performance budgets aligned to GDD 02/03/08; number-type conflict resolved (BigNum for currency and cost values from M2, float64 in per-tick combat; GDD 04/08/09 updated to agree); user decisions applied (title IRON STATIC with provisional applicationId `com.ironstatic.game`, novel mechanics N1-N4 approved and N5 deferred, Standby Patrol offline earnings approved, staged online rollout); milestones are now defined in `docs/ROADMAP.md` (section 12 here is the technical summary); open questions moved to `docs/design/09_open_questions.md`. Files normalized to LF line endings.
Changelog: 2026-11-07 v1.2 - AdMob source corrected to `poingstudios/godot-admob-plugin` v5.1.0 (Next-Gen SDK; `godot-admob-android` is archived), verified on 4.7.2 in M0 (section 7.2 table, references).

Status: v1.1, 2026-11-07. Owner: user (design/playtest). Primary implementers: Claude and AI subagents.
Scope: Android-first, portrait, free-to-play idle/roguelite defense game, Godot 4, statically typed GDScript. Working title **IRON STATIC**, code name `ironstatic`, provisional applicationId `com.ironstatic.game` (permanent once uploaded to Play Console; confirm first, see open question Q30).

**Source-of-truth rule:** the GDD (`docs/design/`) owns game rules, terminology, numbers and ids; this document owns technical decisions. Where they disagree, the GDD wins on game rules and this document wins on technology, and the other document is edited to agree.

Fixed decisions (not reopened): genre, original cybernetic-organism theme (rogue machine swarms, protagonist Cinder), Godot 4 GDScript build, Android/portrait/one-handed, "machine-vision vector" art, F2P model with rewarded ads / IAP / passes / online features (staged, see 6.4), AI-driven development.

**Vocabulary mapping** (this document was first written with The Tower's words; GDD terms and ids are now used throughout):

| Old term | GDD term / id | Old term | GDD term / id |
|---|---|---|---|
| Cash | `scrap` | Workshop | Foundry |
| Coins | `data` | Labs | R&D Lab |
| Gems | `flux` | Ultimate Weapons | weapon systems (9, `arc_discharge` ...) |
| Power Stones | `cipher` | Cards | firmware chips |
| Medals / event tokens | `merit` | Bots | companion drones |
| tier | sector (`s01`..) | Perks | patches (drafts) |
| round | deployment | tournament | Gauntlet (P1) |
| events | Incursions (P1) | guilds | Cells (P2) |
| tower / unit | Cinder (at the Relay) | season / milestone pass | Operation Pass (P1) |

Evidence labels used throughout: **[V]** verified via web source (URL given), **[A]** assumed or from general knowledge, must be checked at implementation time. Where a source is a secondary or third-party page I say so.

---

## 0. Decision summary

| # | Question | Decision | Main alternative |
|---|---|---|---|
| 1 | Engine | Godot **4.7.2** (installed at `C:\dev\tools\godot\4.7.2`), standard GDScript build | Godot 4.6 if a plugin breaks on 4.7 |
| 2 | Renderer | **Compatibility** (OpenGL ES 3.0), not Mobile (Vulkan) | Mobile renderer only if we add heavy 3D/HDR (we won't) |
| 3 | Simulation | Headless-capable `sim/` module of pure `RefCounted` classes, **fixed 30 Hz tick**, packed-array (SoA) entities, uniform spatial grid, no physics engine | Node-per-entity with Area2D (rejected: dies at ~500 entities on low-end) |
| 4 | Game speed | Run N fixed ticks per rendered frame (capped), never scale `delta` | Scale tick length (rejected: tunnels through collisions) |
| 5 | Numbers | **BigNum** (float64 mantissa + int exponent) for every persisted currency amount and every cost value (run and meta), implemented in M2 so the save format never needs a breaking migration; plain float64 for per-tick combat math (see section 3). Resolves GDD Q5 | Pure float64 (GDD 08 originally said doubles were enough for MVP; rejected because changing number type later touches every formula and save file) |
| 6 | Content | Godot **`.tres` Resources generated from CSV** (spreadsheet -> CSV -> importer script; importer v1 lands in M1), plus JSON remote-config overlay | Raw JSON loaded at runtime |
| 7 | Save | Versioned JSON -> compressed -> HMAC-signed local file, migrations chain, cloud save through the backend | Binary `var_to_bytes` (less debuggable) |
| 8 | Backend | **Nakama, self-hosted (Docker on one VPS)**, Postgres; Google Play Games Services v2 used only for sign-in identity. **Staged rollout:** Launch = accounts, cloud save, leaderboards, IAP validation, remote config on the VPS; P1 (first post-launch update) = Gauntlets + Incursions + Operation Pass; P2 = Cells (see 6.4) | Heroic Cloud (managed) once revenue justifies; Firebase as lighter fallback |
| 9 | Billing | Official `godot-google-play-billing` plugin + server-side validation in a Nakama RPC | RevenueCat (adds fee, saves time) |
| 10 | Ads | AdMob (Poing Studios plugin) first, mediation (AppLovin MAX) after launch if needed | LevelPlay |
| 11 | Analytics / crash | Firebase Analytics (events, retention) + Sentry Godot SDK (crashes, GDScript errors) | Firebase Crashlytics |
| 12 | Tests | **GdUnit4** (unit) + custom headless sim runner + adb smoke test | GUT |
| 13 | Anti-cheat | Launch: server plausibility + Play Integrity for leaderboard scores; P1 (Gauntlets): `run_ticket` + shared bracket seed + plausibility; P1.5: seed + input-log replay verification | Client-trust only (no) |
| 14 | Tick and wave timing | Fixed **30 Hz** sim tick; wave = 24 s = **720 ticks** (540 spawn + 180 lull; Gauntlet lull 90 ticks); game speed 1x/2x/3x/4x, hard cap 4x (GDD 02 sections 6 and 14) | 60 Hz tick (2x CPU, no visible gain) |
| 15 | Offline earnings | **Standby Patrol**: closed-form capped `data` payout on return (GDD 04 section 4), trusted-clock rules in 5.5; no offline simulation | Timers only (rejected by user decision 2026-11-07) |

---

## 1. Project structure

### 1.1 Engine and renderer

- **Engine**: Godot 4.7.2 standard build. Godot 4.7 stable shipped 2026-06-19 [V: https://80.lv/articles/godot-4-7-has-been-released, https://alternativeto.net/news/2026/6/godot-4-7-adds-arealight3d-asset-store-overhaul-gabe-support-and-hdr-output/]. A forum measurement was taken on 4.7.2 [V: https://forum.godotengine.org/t/things-that-exit-0-in-godot-4-headless-even-though-they-failed-measured-reproducible/145990], so 4.7.x is a real, patched line. Pin the exact version in `tools/GODOT_VERSION` and in CI.
- **Renderer: Compatibility.** Rationale:
  1. The game is pure 2D with additive glow. Compatibility (OpenGL ES 3.0) runs on every Android device we care about, including old Mali/Adreno GPUs with poor Vulkan drivers.
  2. Mobile renderer's strengths (clustered lighting, 3D, HDR) are irrelevant; its cost is higher startup, larger memory, and driver-bug surface on cheap phones.
  3. Dev machine is an Intel Iris Plus iGPU: Compatibility is also the smoothest renderer in the emulator and the editor.
  4. Glow is done with our own additive blend shaders and a cheap post-process (see 2.7), not `WorldEnvironment` glow (which is unreliable/expensive in Compatibility on mobile).
  Project settings: `rendering/renderer/rendering_method=gl_compatibility`, `rendering/renderer/rendering_method.mobile=gl_compatibility`, `textures/vram_compression/import_etc2_astc=true`, `rendering/2d/snap/*` off, MSAA off, `rendering/textures/canvas_textures/default_texture_filter=Linear`, `display/window/stretch/mode=canvas_items`, `stretch/aspect=expand`, base size 1080x1920 portrait (`handheld/orientation=portrait`). The exact key/value list is the contract in `docs/tasks/M0.md` task M0-02.
- **Physics**: disabled for gameplay (`physics/2d/physics_engine` left default but no bodies are ever created). Our own grid does collision. Physics tick rate set to 60 only because Godot needs a value; the sim does not use `_physics_process`.
- **Threading**: single-threaded sim in v1 (see budgets). Keep the sim API free of scene-tree access so it can move to a worker thread later without a rewrite.

### 1.2 Folder layout

```
C:\dev\tower
  project.godot
  CLAUDE.md                    # agent rules (see section 11)
  docs\                        # TECH_ARCHITECTURE.md, ROADMAP.md, design\ (GDD), tasks\ (agent task files), setup\ (toolchain), research (notes)
  tools\                       # PowerShell/py scripts: run_emulator.ps1, deploy_android.ps1, importers, sim runner
  data\                        # source-of-truth balancing: *.csv  (+ data\README.md describing columns)
  addons\                      # third-party: gdUnit4, nakama, admob, billing, sentry...
  android\                     # gradle build template + plugin configs (git-tracked, build\ ignored)
  src\
    core\                      # autoloads + tiny shared utilities (no gameplay)
    sim\                       # PURE SIMULATION, no Node, no scene tree, no rendering (headless-testable)
      entities\                # EnemyStore, ProjectileStore, EffectStore (packed arrays)
      systems\                 # SpawnSystem, MovementSystem, TargetingSystem, DamageSystem, EconomySystem
      weapon_systems\          # LaserCycle (Cinder starting laser) + the 9 weapon-system behaviours (data + behaviour, M6)
      spatial\                 # SpatialGrid
      ai\                      # PolicyBot (scripted buy policy for headless balance runs; never used in gameplay paths)
      math\                    # BigNum, Rng, Curves
      SimWorld.gd              # owns all stores/systems; step(dt_fixed) is the only entry point
    meta\                      # permanent progression: Foundry, Lab, Arsenal (weapon systems, firmware, companions, modules), Currencies, Milestones, StandbyPatrol (pure logic, RefCounted)
    save\                      # SaveManager, migrations, serializer, cloud sync
    net\                       # Backend facade (interfaces + Nakama impl + offline stub)
    services\                  # Ads, Billing, Analytics, Consent, Integrity (interfaces + Android impl + desktop stub)
    ui\                        # screens, widgets, theme; presentation only
    view\                      # battlefield renderer: reads SimWorld, draws via MultiMesh/_draw/shaders
    data_defs\                 # hand-written typed Resource classes (EnemyDef, RunUpgradeDef ...)
    data_gen\                  # importer-generated .tres only (checked in; never hand-edit)
  assets\
    shaders\  fonts\  audio\  icons\  themes\
  tests\
    unit\                      # GdUnit4 suites mirroring src\ layout
    sim\                       # headless sim scenarios + balance runs
    fixtures\                  # saved game fixtures per save version
  export\                      # export_presets.cfg template, keystore instructions (keystore itself NEVER committed)
  backend\                     # Nakama TypeScript runtime modules + tests (created in M7; Gauntlet modules in P1)
```

Rules: `sim/`, `meta/`, `save/` must never reference `Node`, `SceneTree`, `Input`, `OS` time, or autoloads (except via injected interfaces). A lint script (`tools/lint_layers.py`) greps for violations and runs in CI.

### 1.3 Autoloads (singletons) - kept to a minimum

| Autoload | Role | Notes |
|---|---|---|
| `Game` | App state machine (boot, menu, in-run, results), owns the active `SimWorld` and `Profile` | Thin; delegates |
| `Profile` | In-memory persistent player state (currencies, Foundry levels, Lab state, firmware, weapon systems, companions, best wave per sector) | Plain data + `changed` signals; saved by `SaveManager` |
| `SaveManager` | Load/save/migrate/cloud sync | Section 5 |
| `Content` | Loads data Resources (enemies, upgrades...), merges remote-config overlay, exposes typed getters | Read-only after boot |
| `Services` | Holds interface instances: `ads`, `billing`, `analytics`, `consent`, `integrity`, `backend` (real on Android, stubs on desktop/headless) | Dependency-injection point; tests swap stubs |
| `Clock` | Trusted time (server-offset-corrected UTC, monotonic ticks) | Section 5.5 |
| `Events` | Typed signal bus for UI-level events only (never per-entity) | Avoid hidden coupling; max ~20 signals |
| `Log` | Leveled logging with ring buffer, attached to crash reports | |

No gameplay logic lives in autoloads. The sim is constructed per run: `SimWorld.new(config, seed)`.

### 1.4 Scene composition

- `Main.tscn` (root, portrait): `BattleView` (top 56% of screen height) + `UpgradePanel` (bottom 44%) per GDD 07 section 1 + `Overlay` (popups, toasts).
- `BattleView.tscn`: `Node2D` containing `EnemyRenderer` (MultiMeshInstance2D per enemy shape class), `ProjectileRenderer` (MultiMesh), `EffectRenderer`, `CinderView` (Cinder, `_draw`: frame, 12 skin wedges, core, emitters, integrity ring, skin-burn bands), `RangeRing` (`_draw`), `FloatingText` pool, and a `SubViewport`-free glow pass (see 2.7). It is a *pure observer*: each frame it reads packed arrays from `SimWorld` and writes MultiMesh buffers.
- UI scenes are small, one per screen/widget (`UpgradeRow.tscn`, `CurrencyBar.tscn`...), built from a shared `Theme` resource. Lists of upgrades are generated from `Content` data, not hand-placed.
- Composition over inheritance: scenes expose a tiny typed `setup(...)` method and emit signals; no scene reaches up the tree via `get_node("../..")`.

### 1.5 Naming and style rules (enforced in CLAUDE.md and by `gdlint`)

- Files and folders `snake_case`; class names `PascalCase` via `class_name`; one class per file; files under ~300 lines (hard cap 500) so agents can read and edit them whole.
- Constants `UPPER_SNAKE`; private members/methods `_leading_underscore`; signals past tense (`wave_started`).
- **Static typing everywhere**: every variable, parameter and return type is declared; `var x := ...` only when the type is obvious. No `Variant` in sim code. Use typed arrays (`Array[int]`), `PackedFloat32Array` etc.
- No magic numbers in `sim/`: tunables come from `Content` data or `const` blocks at file top.
- Project Settings (`debug/gdscript/warnings/*`), set to **Error** so the headless run fails: `untyped_declaration`, `inferred_declaration` (warn only), `unsafe_property_access`, `unsafe_method_access`, `unsafe_cast`, `unsafe_call_argument`, `unused_variable`, `unused_parameter`, `unused_signal`, `shadowed_variable`, `return_value_discarded`, `integer_division`, `narrowing_conversion`, `confusable_identifier`. Exceptions go through `@warning_ignore("...")` with a comment explaining why.
- Formatting/lint: `gdtoolkit` (`gdformat`, `gdlint`) pinned via `tools/requirements.txt` [A: PyPI package `gdtoolkit` supports Godot 4 syntax; verify 4.7 syntax coverage]. CI fails on diff.
- Compile check as a gate: `godot --headless --check-only --script <file>` per file and a full `--headless --quit` import run; parse errors must fail the job (do not trust exit code alone, see 10.5).

---

## 2. Simulation core

### 2.1 Principle: simulation never touches rendering

`SimWorld` is a `RefCounted` with one mutator: `step() -> void` (advance exactly one fixed tick) plus command methods (`buy_upgrade(id, count)`, `pick_patch(index)`, `tap_cache(id)`, `activate_overdrive()`, `toggle_weapon_system(id)`; speed is a driver concern, not a sim command). It emits no signals per entity; it records **events** into a small ring buffer (`wave_started`, `boss_killed`, `draft_opened`, `exposure_band_changed`, `run_ended`) that UI/analytics drain. The view reads state; the headless runner reads state; tests assert on state. Same code path in all three.

### 2.2 Fixed timestep and game speed

- **Tick rate: 30 Hz** (dt = 1/30 s = 33.3 ms) for sim. Rationale: 60 Hz doubles CPU cost for no visible benefit in an auto-battler; the view interpolates positions between the last two ticks for smooth 60 fps motion.
- `Game._process(delta)`: `accumulator += delta * speed_multiplier` (wall-clock delta times the player's speed setting; the **tick length is never scaled**); `ticks = floor(accumulator / DT)`; `accumulator -= ticks * DT`; run up to `MAX_TICKS_PER_FRAME` (default 8) with a time guard (stop if the frame's sim budget of ~10 ms is exceeded; leftover is dropped and the effective speed gracefully degrades, shown in UI as a "throttled" indicator).
- **Wave clock in ticks:** 24 s = 720 ticks (spawn phase 540, lull 180; Gauntlet lull 90). All GDD seconds convert through one helper `Ticks.from_seconds(s) = roundi(s * 30)`; fractional rates (e.g. `cycle_rate` 1.04 shots/s) use a per-weapon integer-safe accumulator, never float timers.
- **Game speed 1x and 2x always, 3x unlocked by Lab `lab_game_speed` level 5, 4x at level 15; hard cap 4x** (GDD 02 section 14; GDD Q17). Higher speed = more ticks per frame, each tick identical. Collisions and cooldowns are tick-counted, so speed never causes tunnelling or skipped hits. Speed only costs CPU linearly; the cap bounds battery and cost. Gauntlets (P1) run at the player's max speed; the score is wave-based so speed does not affect fairness. Drafts, ads and backgrounding pause the run.
- Cooldowns/timers inside the sim are expressed in ticks (integers), not float seconds, to keep determinism and avoid drift.
- App pause/background: the sim freezes (no catch-up ticks). Away time is handled by Standby Patrol (5.5), a closed-form payout, not by simulating ticks.
- **Fast-forward for tests/balance**: the headless runner calls `step()` in a tight loop with no frame pacing: target >= 200x real time for a 40-wave run on the dev machine.

### 2.3 Determinism and RNG

- All randomness goes through `Rng` (PCG32 implemented in GDScript with integer ops; state is two 64-bit ints). **Never** use `randf()` or Godot's global RNG inside `sim/`.
- Separate sub-streams per concern (spawn, loot, crit, draft, effects) derived from the run seed (`seed ^ hash(stream_name)`), so adding a cosmetic random call cannot desync gameplay.
- Floating point: the sim uses `float` (64-bit in GDScript) for positions/damage. Within one engine build and one CPU architecture this is deterministic enough for balance tests. For server-side replay verification (section 8) we require the *server* to run the same Godot headless build on x86-64 Linux, and the client to record the seed and the input log; cross-architecture float divergence (ARM phone vs x86 server) is the known risk. Mitigation: sim avoids transcendental functions in outcome-affecting paths (use lookup tables for sin/cos, sqrt only for distances compared via squared values), and verification tolerance is a statistical/plausibility check in v1.5, bit-exact replay is a stretch goal [A].
- Inputs are the only external nondeterminism. They are logged as `(tick, command, args)`.

### 2.4 Data-oriented storage

- Entities live in **struct-of-arrays stores** with a free list:

```gdscript
class_name EnemyStore extends RefCounted
var count: int = 0                       # high-water mark
var alive: PackedByteArray
var pos_x: PackedFloat32Array
var pos_y: PackedFloat32Array
var hp: PackedFloat64Array               # float64: hp scales with wave
var speed: PackedFloat32Array
var type_id: PackedByteArray
var radius: PackedFloat32Array
var spawn_id: PackedInt32Array            # monotonically increasing; tie-break for targeting (GDD 02 section 3)
var level_hp: PackedInt32Array            # enemy health level at spawn (GDD 03 section 4.1)
var born_wave: PackedInt32Array           # for the stale-kill 50% rule (3 wave-ends)
var cell: PackedInt32Array               # current spatial grid cell
var free_list: PackedInt32Array
```
- Projectiles and effects use the same pattern (`ProjectileStore`: pos, vel, damage, ttl_ticks, owner, target_id). **Cinder's laser is hitscan (GDD 02 section 2) and never creates a projectile**; `ProjectileStore` holds only moving entities: lancer bolts, micro_missiles, mines, boss_lance bolts (Launch).
- **No Node per enemy or projectile.** Rendering is a separate step (2.6). Pooling is intrinsic: dead indices are recycled through the free list; stores pre-allocate capacity (default **512 enemies / 512 projectiles / 1,024 effects**; GDD 02 section 2 caps alive enemies at 160 normal + 6 per elite type + 20 brood splits + 8 bosses + convoy units, about 250 absolute) and grow in chunks; hitting the hard cap triggers the "spawn throttle" (spawns delayed, never dropped silently) and a metric.
- GDScript hot loops are the performance risk. Rules: (a) loop over `PackedArray`s with local variable caches, no function calls inside inner loops beyond tiny `static` inlines, (b) no allocations per tick (no `Vector2`/`Array` creation in loops: use scalar x/y arrays), (c) systems process in batches. If profiling shows a system over budget, port **that one system** to a C++ GDExtension [A: only if budgets in 2.8 fail on the reference phone; GDExtension is supported in the standard Godot build for Android but adds an NDK toolchain and CI complexity, so it is the escape hatch, not the plan].

### 2.5 Spatial grid instead of physics

- Uniform grid. **Sim unit = 1 meter** (GDD 02 section 2: arena radius 52 m, Cinder hit radius 2.0 m, enemy radius 0.5-3.0 m); the view scales meters to pixels (about 28 px/m for the 38 m wide camera). Cell size = 4 m, covering the 52 m arena circle (26 x 26 cells). Stored as `cell_head: PackedInt32Array` + `next_in_cell: PackedInt32Array` (intrusive linked list per cell), rebuilt every tick (O(n), cheap: one pass over alive enemies).
- Targeting: laser/projectile weapons query nearest enemy within range by scanning rings of cells outward from the unit (cell scan, not full list). Cached target per weapon, re-validated each tick, re-acquired only if dead/out of range.
- Hitscan laser: resolved the instant it fires (target by the GDD 02 section 3 rule, damage applied in the same tick; the view draws an 80 ms fade line). Projectile-vs-enemy (missiles, mines, Launch): for each projectile, test only enemies in its cell and neighbours; **swept test** (segment vs circle) so fast projectiles at high speed multipliers cannot tunnel. Area effects (splash, chain, orbit) use cell range queries.
- Enemy-vs-unit contact: enemies are circles moving toward the origin; contact test is `dist2 <= (r + unit_r)^2`. Enemies do not collide with each other (they overlap visually; this is the standard for the genre and saves O(n^2) separation).

### 2.6 Rendering

- **MultiMeshInstance2D** per visual class (e.g. skitter, dart, walker, lancer, boss_hulk, enemy bolt, particle; one MultiMesh per silhouette in GDD 03 section 1.5). Instance transform+color+custom data are written each frame into a `PackedFloat32Array` buffer and uploaded with `RenderingServer.multimesh_set_buffer()` in one call (fastest path in Godot 4) [A: API exists in 4.x; confirm exact name when implementing]. One draw call per class: total battlefield draw calls target <= 25.
- Meshes are generated procedurally at startup (`ArrayMesh` of line-loops/triangle fans for the vector shapes: skitter triangle, dart chevron, walker trapezoid, lancer diamond, boss square-hex; max 12 line segments per enemy, GDD 07 section 5.1). Outlines are drawn as thin quads so line width is controllable on mobile (Godot's `PRIMITIVE_LINES` is 1 px).
- Glow: a **fake glow** in the shader (the mesh has an inner bright core and an outer soft-alpha fringe with additive blending `blend_add`). Optional bloom is a half-resolution blur pass on a `SubViewport` of the battlefield, toggleable in settings and **off by default on low-tier devices** (auto device-tier detection on first run from GPU name + RAM + a 2-second benchmark).
- Interpolation: the view stores previous and current tick positions (the sim keeps `pos_prev_x/y` for the packed arrays) and lerps by `accumulator/DT`.
- Static HUD (range ring, grid background, scanlines) is one `_draw` call cached into a texture or a single shader quad. Damage numbers use a fixed pool of 24 live labels (GDD 07 section 5.5) drawn through one custom `_draw` batch; show rules (crits, overcrits, hits >= 1% target max HP, top 6 per 0.5 s) and 0.2 s same-enemy aggregation are applied before drawing (never one label per hit).
- Cinder (`CinderView`, GDD 07 section 5.6) is drawn with `_draw`. The **exposure band is computed in the sim** (`exposure_band`, with the 5% hysteresis of GDD 02 section 12.1) so determinism tests cover it; the view only animates the transition. Per-enemy glow is disabled above 150 alive enemies (GDD 07 section 5.3).
- Culling: everything on screen is in the battlefield; no culling needed. Enemy spawn at a ring just outside the view.

### 2.7 Performance budgets (reference: ~2020 mid-range phone, e.g. Snapdragon 665/720G or Helio G85, 4 GB RAM, 60 Hz display)

| Budget | Target | Hard limit |
|---|---|---|
| Frame time at x1 speed, late game | 16.6 ms (60 fps) | 22 ms (45 fps floor) |
| Sim step (one tick) | <= 1.5 ms at 200 enemies + 100 projectiles (realistic late state); stress bench 600 enemies + 600 projectiles <= 4 ms | 8 ms |
| Render prep (buffer fill + upload) | <= 3 ms | 5 ms |
| UI | <= 2 ms (update on signal, not per frame; throttle number labels to 10 Hz) | 3 ms |
| Alive enemies (typical late) | 100-200 | GDD caps (about 250 absolute); store capacity 512 |
| Projectiles alive | <= 100 typical (hitscan laser, few moving entities) | 512 |
| Draw calls (battlefield) | <= 25 | 40 |
| Resident memory | <= 350 MB | 500 MB |
| Cold start to menu | <= 3 s | 5 s |
| APK/AAB size | <= 60 MB | 150 MB (Play base limit is 200 MB for AAB base module [A]) |
| Battery | <= 4%/10 min at x1 [A: measure with `adb shell dumpsys batterystats`] | |

Acceptance gate: GDD 08 FC6 (>= 55 FPS with 100 enemies and an active beam, >= 30 FPS at 160 enemies, cold start <= 3 s on the 4 GB reference device). Fallback ladder if over budget: cap speed multiplier, disable bloom, reduce particle density, merge floating text, cap visual effects (spawn but render a subset). These are `QualityTier` presets, selectable and logged in analytics. **QualityTier never changes the sim tick rate or any outcome-affecting value** (determinism, Gauntlet fairness); it only changes view-side options.

Dev machine caveat: the Iris Plus emulator is slower than a real phone for GL; judge performance with `adb shell dumpsys gfxinfo` on a real device when available and with the headless sim benchmarks (CPU-only) otherwise.

---

## 3. Big numbers

- **Decision (resolves GDD Q5; GDD 04 section 5, 03 section 4.6 and 08 section 5 were edited to agree):** implement `BigNum` in **M2** and use it for every persisted currency amount and every cost value. Plain float64 stays inside per-tick combat. Rationale: GDD 03 shows enemy HP near 4.8e15 at wave 1000, Foundry costs reaching 3.8e10 per stat at F=200, about 1e10 cumulative `data` by month 6, and a sector reward multiplier up to 176 with sectors 13-24 post-launch; doubles probably suffice for years, but the decisive reason is the save format: persisting currency as strings (`"1.2345e456"`) from schema v1 means the save never needs a breaking migration, and BigNum lives off the hot path (about 250 lines, fully unit-testable). IEEE float64 holds up to ~1.8e308 with 15-16 significant digits.
- `BigNum` (a `RefCounted` value class; bulk storage as `PackedFloat64Array` pairs) = `mantissa: float` in [1,10) and `exp10: int`. Operations: add, sub (clamped at 0 for currencies), mul, div, pow-by-float, compare, `from_float`, `to_float` (saturating), log10. Serialized as a string.
- **Where each is used**:

| Domain | Type | Why |
|---|---|---|
| `scrap` balance during a run, `data` balance and lifetime totals, every cost (run upgrade `ceil(c0 * g^L)`, Foundry, Lab, weapon-system, companion, module costs), reward payouts (milestones, missions, Standby Patrol), `farm_rate_1x` | `BigNum` | Can exceed 1e308 in long play; exact-ish affordability comparisons; stable save format |
| `flux`, `cipher`, `merit`, levels, wave number, ticks, counts | `int` (64-bit) | Always small; exactness matters (IAP ledger) |
| Enemy hp and damage, per-hit damage, final stat values (`laser_output_final` ...), multipliers, chances, rates | `float64` (native) | Per-tick math; enemy HP follows GDD 03 `G(l)` which stays below ~1e44 even at level 3000; a per-run **numeric ceiling guard** clamps scaling formulas and a NaN/inf assertion runs in tests and balance runs |

- Hot-path rule: per-tick combat math is native float; conversion to `BigNum` happens only at *economy events* (kill rewards summed as float64 within a tick, then added once to the `scrap` and run-`data` BigNums; purchases). Run upgrade costs are evaluated by `Curves` in float64 and wrapped at the boundary.
- **Formatting** follows GDD 04 section 5 exactly: `NumberFormat.format(BigNum, style)`: 0..999 integer; `K`, `M`, `B`, `T`, `Qa`, `Qi`, `Sx`, `Sp`, `Oc`, `No`, `Dc` (to 1e33), scientific above 1e36; always 3 significant digits with trailing zeros trimmed; floor (never round up) for rewards; percentages, multipliers and time formats per GDD 04 rules 5-6; settings toggle Short / Scientific / Engineering. Suffix table is data (`data/number_suffixes.csv`). Keep a formatter cache to avoid string churn (labels update at 10 Hz max).
- Alternatives considered: pure float64 (simplest; rejected above), `Decimal`-style plugin libraries (extra dependency, GDScript speed unknown).

---

## 4. Data-driven content

### 4.1 Authoring pipeline

```
Google Sheet / Excel (designer)  ->  export tabs as CSV  ->  data\*.csv (git-tracked, diff-friendly)
   ->  tools\import_data.gd (headless Godot script)  ->  src\data_gen\*.tres  (typed Resources, git-tracked)
   ->  validated by tests (schema, ranges, referential integrity)
```
- Why CSV-in-git as the source of truth: agents can read, diff and edit CSVs trivially, and the user can still edit in a spreadsheet and re-export. The importer validates (unknown ids, missing columns, non-monotonic cost curves) and fails loudly.
- **Typed `Resource` classes** (`EnemyDef`, `SectorDef`, `RunUpgradeDef`, `FoundryRowDef`, `PatchDef`, `LabDef`, `FirmwareDef`, `WeaponSystemDef`, `CompanionDef`, `ModuleDef`, `CurrencyDef`, `MilestoneDef`, `MissionDef`; hand-written class scripts live in `src/data_defs/`, generated `.tres` in `src/data_gen/`) are the runtime format: type safety, editor inspection, fast load. Generated `.tres` are committed so the project runs without running the importer; CI re-runs the importer and fails on diff to prove CSV and `.tres` agree.
- **Formulas, not tables, for curves.** Per-level costs/effects are defined by parameters (`base_cost`, `growth`, `effect_per_level`, `curve_type`) evaluated by `Curves` (exp, poly, softcap, step), so one CSV row defines 500 levels. Hand-tuned tables are allowed through an optional override column.
- **Behaviour in code, numbers in data.** Weapon systems, modules, companions and enemy special abilities are small script classes keyed by `behavior_id` in the CSV; their parameters come from data. New content that fits an existing behaviour needs no code.

### 4.2 Content domains (initial schema sketch)

| Table | Key columns |
|---|---|
| `sim_constants.csv` | key, value, note (HP0, D0, `k1..k3`, `k1a..k3a`, N(w) parameters, wave ticks, arena radius, alive caps, melee bite, stale rule; GDD 02 section 6 and 03 sections 2-4) |
| `enemies.csv` | id, group, shape, hp_mult, dmg_mult, speed, radius, slots, scrap_mult, data_base, spawn_weight, first_sector, first_wave, behavior_id, tag, flags (GDD 03 section 1) |
| `sectors.csv`, `battle_conditions.csv` | id, name, offset, unlock rule, `R(s)` parameter, boss_interval, elite_step_wave, boss rotation, conditions, tag (GDD 03 section 8) |
| `run_upgrades.csv` | id, tab, type (D/C), base, p or r_inc, L_cap, hard_cap, c0, g, gate_best_wave, tag (GDD 02 section 7) |
| `foundry.csv` | id, type, f or f_inc, F_cap, fc0, fg; Type C rows are derived by the importer from `run_upgrades.csv` using GDD 05 section 1.3, so only Type D rows and overrides are authored |
| `patches.csv` | id, class (standard / gamble / weapon), effect parameters, per_pick, max_picks, tag (GDD 02 section 10) |
| `lab.csv` | id, effect, per_level, max_level, t0_h, rc0, gate (GDD 05 section 2); duration/cost formulas in code |
| `weapon_systems.csv`, `firmware.csv`, `modules.csv`, `companions.csv` | id, rarity, effect parameters, level curves, behavior_id, unlock (GDD 05 sections 3-6) |
| `economy.csv` | ad rewards and caps, `flux` rates, Standby Patrol parameters, milestone ladder, mission formulas, shop packs (ids, not prices), caps (GDD 04, 06) |
| `milestones.csv`, `missions.csv`, `gauntlet_leagues.csv` (P1) | rewards, thresholds, bracket size, promotion/relegation counts, league PR ceilings (GDD 04 section 3, 06 sections 5-6) |
| `targets.csv` | balance target bands per player state (GDD 03 section 6, 05 section 8) |

Currency count: exactly **5 currencies** per GDD 04 (`scrap` in-run, `data`, `flux`, `cipher`, `merit`); the research flags "too many currencies" as the top review complaint (The Tower has about 10) [V: economy_monetization_liveops.md section 7]. Currencies are data (`CurrencyDef`) but adding a sixth requires a GDD change first (CLAUDE.md rule).

### 4.3 Remote config overlay

- Backend (Nakama storage object `config/live`, public-read, versioned) returns a JSON **patch overlay**: `{ "version": 42, "overrides": { "economy.ad_flux_claim_amount": 8, "enemies.skitter.hp_mult": 1.1 }, "flags": { "gauntlet_enabled": true }, "events": [...] }`.
- `Content` applies overlays by dotted path to numeric/bool/string fields only (whitelist of overridable paths in `data/remote_overridable.csv`); structural changes require an app update. Overlay is cached locally, signature-verified (HMAC with a key shipped in the app + server-side signing; this prevents trivial tampering, not determined attackers), has a safe fallback to bundled values, and is fetched at boot and every 15 min in menu only (never mid-run, so a run's balance is stable and replayable: the config version is recorded in the run record).
- Firebase Remote Config is an alternative [A]; we avoid a second backend by using Nakama storage.

---

## 5. Save system

### 5.1 Local format

- File `user://save/profile.sav` + rolling backup `profile.bak` (previous good) + `profile.tmp` for atomic writes (write tmp, flush, rename).
- Payload: JSON (`schema_version`, `profile` dict, `runs_stats`, `labs` with absolute UTC end timestamps, `purchase_ledger`, `last_server_time`, `device_id`, `config_version`) -> `PackedByteArray.compress(COMPRESSION_ZSTD)` -> prefix header (`magic`, `schema_version`, `payload_len`) -> **HMAC-SHA256** footer (`Crypto.hmac_digest`). BigNums as strings. JSON over binary: agents and humans can open a decoded save for debugging via `tools/save_dump.gd`.
- Integrity: HMAC key is embedded and obfuscated (split across constants, assembled at runtime). **Honest threat model**: this stops casual editing (Cheat Engine, file edit), not a reverse engineer. The authoritative defence for anything competitive/monetary is server-side (section 8). Offline single-player progress is allowed to be cheatable; the game does not feed leaderboards from unverified data.
- Tampered/corrupt save: try `.bak`, then cloud copy, then prompt the user; never silently wipe.

### 5.2 Versioning and migrations

- `schema_version: int`. `src/save/migrations/migrate_v{N}_to_v{N+1}.gd`, each a pure function `Dictionary -> Dictionary`, chained on load. A fixture per released version lives in `tests/fixtures/save_v{N}.json`; a test loads every fixture and runs the full chain, asserting invariants. CI fails if `CURRENT_SCHEMA_VERSION` increases without a new fixture + migration. Never delete fields in a migration without keeping the data one version.
- Forward-compat: a save with a newer schema than the app refuses to load and tells the user to update (prevents downgrade corruption).

### 5.3 Autosave cadence

- Profile (meta) saved: on every purchase/lab start/currency-affecting meta event (debounced 2 s), on app pause/focus loss (`NOTIFICATION_APPLICATION_PAUSED`, `WM_GO_BACK_REQUEST`), on run end, and every 60 s while in menu.
- In-run: checkpoint run state every 30 s and on pause, so an Android process kill resumes the run (`run_snapshot.sav`, includes RNG state, store arrays compressed; ~100-300 KB). Resuming is built in M3 (with the save system) and is mandatory before closed testing since phones kill backgrounded apps aggressively.
- Writes are small and off the hot path; serialization of a 300 KB snapshot is spread across frames or done on a `WorkerThreadPool` task.

### 5.4 Cloud save and conflict resolution

- Storage: Nakama storage object `saves/profile` (per user, `permission_read=owner`), holding the same signed blob + metadata (`schema_version`, `device_id`, `playtime`, `total_progress_score`, `updated_at` server time, a monotonically increasing `revision`).
- Sync points: app start (after auth), after run end, on pause (best effort), manual button. Use Nakama's storage **version (OCC) write** (`version` field) to make writes conditional.
- Conflict policy: **not "latest wins"**. Compare `revision` lineage: if the cloud revision equals the revision our local save last synced from, push. Otherwise (divergence), show a **choose dialog** with both profile summaries (best sector/wave, `flux`, playtime, last played) defaulting to the one with the higher `progress_score` (monotonic composite: lifetime `data` earned + Foundry levels + Lab levels completed). Purchased premium currency is tracked in a server-side `purchase_ledger` and re-applied on restore so a "choose older save" cannot lose real-money purchases.
- Identity: anonymous device-id auth on first launch (zero friction), upgrade to Google Play Games sign-in (link) to recover on a new device. Guard against account-link collisions with a clear merge/choose flow.
- Google Play Games saved-games (snapshots) is **not** the primary cloud save (it ties us to Google and gives no server-side validation); we only use PGS for sign-in.

### 5.5 Standby Patrol (offline earnings), timers and trusted time

- **Product decision (user, 2026-11-07; GDD 04 section 4, GDD Q3):** approved. While the app is closed or backgrounded for more than 60 s, Cinder runs a Standby Patrol that pays a capped, partial-efficiency amount of `data` only. (The Tower has no confirmed offline earnings [V: research note section 2]; this is our addition.) It is a **closed-form payout, never a simulation**:
  `standby_data = farm_rate_1x * patrol_minutes * efficiency`, `patrol_minutes = min(minutes_away, cap_minutes)`; base `cap_minutes` 240 and `efficiency` 0.20, raised by Lab `lab_standby_cap` (+30 min per level, 660 max) and `lab_standby_eff` (+0.01 per level, 0.40 max); optional `ad_offline_double` (2/day). Parameters live in `economy.csv` and `lab.csv`. It pays no `scrap`, `flux`, `cipher`, `merit`, caches or milestones and never advances best wave.
- Implementation: `meta/StandbyPatrol.gd` exposes a pure function `compute(farm_rate_1x: BigNum, trusted_away_s: int, cap_minutes: int, efficiency: float) -> BigNum` (unit-tested with fixed inputs). `farm_rate_1x` is the exponential moving average (weight 0.4) of `data_run / run_game_minutes` over recent completed runs of the farm sector, stored in the profile after each run.
- Timer model: every long timer (Lab research, event windows, ad cooldowns, Standby last-active stamp, free-claim timers) stores an **absolute server-corrected UTC `end_time`**, not remaining seconds.
- **Trusted-clock rules** (`Clock` autoload):
  1. `Clock` keeps `server_offset = server_utc - device_utc`, refreshed on every backend call (Nakama returns server time in RPC responses) and by a lightweight `server_time` RPC at app open.
  2. Online claim: away time = `server_now - last_active_server_time` (stored locally and in cloud save); the client computes the payout and the server time bounds the minutes. Never trust the device wall clock when a server time is available.
  3. Offline claim (no server reachable): away time = `min(wall_clock_delta, monotonic_delta)` and the claim is **capped at the base `cap_minutes` (240)** regardless of Lab upgrades (GDD 04 tamper rule). Monotonic time uses Android `elapsedRealtime` via a tiny plugin function [A]; it resets on reboot, so after a detected reboot only the wall-clock delta is available and the same base cap applies.
  4. If the wall clock moved backward, or wall and monotonic deltas disagree by more than 5 minutes without a reboot, flag `clock_tamper`, grant the minimum of the two deltas (possibly 0), **freeze Lab and other timers rather than punish**, and re-sync when online.
  5. The patrol sector is stored in the profile (default: farm sector); claims are idempotent per `last_active` stamp so a double claim after a crash is impossible.
- Anything that grants real value (`flux` rush spending, daily claims, event windows, Gauntlet entry) is validated by the server on claim once online; client timers are UX only. `flux` rush of Lab timers is client-trusted but checked against the server-side shadow profile at cloud sync [A: scope decision, simpler for launch].

---

## 6. Backend

### 6.1 Evaluation

| Option | Fits our needs | Godot 4 support | Cost model | Verdict |
|---|---|---|---|---|
| **Nakama** (Heroic Labs, Apache-2.0) | Auth, storage (cloud save), leaderboards, **tournaments**, groups (guilds), IAP validation, server-side RPCs in Lua/TypeScript/Go, matchmaker-free async brackets | Official GDScript client `heroiclabs/nakama-godot`, Godot 4 on master, latest confirmed release 3.4.0 (2024-03-19) [V: https://github.com/heroiclabs/nakama-godot/releases, https://heroiclabs.com/blog/nakama-godot-4/]; I could not confirm a newer release, so test against 4.7 early [A] | Self-host free; Heroic Cloud starts around $600/month per third-party listings, official page shows no public prices [V: https://heroiclabs.com/pricing, third-party figures unconfirmed] | **Primary** |
| Firebase (Auth, Firestore, Functions, RTDB) | Auth, cloud save, leaderboards via custom Firestore/Functions; no native tournaments/guilds | No official Godot SDK; community plugins (e.g. `godot-x/firebase`: Analytics/Crashlytics/Messaging, targets Godot 4.6) [V: https://github.com/godot-x/firebase]; REST from GDScript possible [A] | Pay-as-you-go; cheap at small scale, read/write bills grow with leaderboards | Use only for Analytics |
| PlayFab | Leaderboards, economy, CloudScript, tournaments partial | Official SDKs: C#/Unity/Unreal; no official Godot SDK; REST from GDScript [A] | Free tier then usage-based | Reject (REST-only, Microsoft-centric) |
| Supabase (Postgres, Auth, Edge Functions) | Auth, storage, SQL leaderboards, Realtime | Community GDScript clients only [A] | $25/month Pro + usage [A] | Good generic backend, but we would hand-build tournaments/guilds |
| Google Play Games Services v2 | Sign-in, leaderboards, saved games, achievements | Community plugins: `godot-sdk-integrations/godot-play-game-services` and `PGSGP` (targets 4.2.x) [V: https://github.com/finepointcgi/PGSGP, https://store.godotengine.org/asset/jacob-ibanez-sanchez/google-play-games-services-for-godot/]; I could not verify a release that targets 4.7 [A] | Free | Sign-in identity only; no brackets, Android-only, no server control |

### 6.2 Recommendation

**Nakama self-hosted** (Docker Compose: `nakama` + `postgres` [A: Nakama supports PostgreSQL in current releases; older ones required CockroachDB, confirm in release notes] behind Caddy/Traefik TLS on one VPS, daily `pg_dump` to object storage), with server logic as **TypeScript runtime modules** in-repo (`backend/`), so agents can write and test them. Features map:

| Feature | Nakama primitive |
|---|---|
| Accounts | Device auth (anonymous) + Google auth link (PGS server auth code or Google ID token) |
| Cloud save | Storage engine, OCC versioned writes |
| Leaderboards (Launch: best wave per sector, weekly and all-time) | Leaderboard API (reset by cron) |
| Gauntlets (P1; 30-player brackets by Power Rating, six leagues, Wed and Sat UTC windows per GDD 06 section 5) | **Tournament API** with one tournament per (league, bracket); our RPC does bracket assignment/promotion (the research's 30-player league design is in [V: research note economy_monetization_liveops.md section 4]); Nakama tournaments support join/size/duration/reset schedule natively [A: confirm in docs] |
| Incursions (P1) and remote config (Launch) | Storage `config/live` + scheduled RPC |
| Cells (P2) | Groups API (max members 30) |
| IAP | Server-side purchase validation (`purchaseValidateGoogle`) [A: exists in Nakama runtime; confirm] |
| Ads (rewarded) | Client callback + server-side verification (AdMob SSV) endpoint later |

Rationale: only option that has tournaments and groups as first-class features, official Godot client, open source (no lock-in, can move to Heroic Cloud without a rewrite), and TypeScript hooks are agent-friendly. Alternative: Heroic Cloud (managed) when ops burden or scale justifies the cost; Firebase + Cloud Functions if we cut tournaments from v1.

**Self-host vs managed**: self-host through soft launch and into the first 10K DAU; revisit managed when (a) monthly revenue comfortably exceeds the managed fee or (b) we are on-call-constrained. Keep backend logic in the TypeScript runtime and storage schemas documented so migration is a deploy, not a rewrite.

### 6.3 Rough monthly cost (estimates [A], infrastructure only, USD; no vendor quote verified)

| DAU | Self-hosted Nakama (VPS + managed Postgres/backups + egress) | Heroic Cloud managed | Firebase-only equivalent |
|---|---|---|---|
| 1K | $10-25 (single 2 vCPU/4 GB VPS) | ~$600+ (third-party quote, minimum) | $0-25 |
| 10K | $60-150 (4 vCPU/8 GB + separate DB + backups) | $600-2,000 | $50-300 |
| 100K | $600-1,500 (2-3 app nodes, DB primary+replica, LB, monitoring) plus ~0.2 FTE ops | $2,000-6,000+ (third-party list of tiers) | $500-3,000 (read-heavy leaderboards dominate) |

Assumptions: ~20 backend calls/DAU/day, saves < 100 KB, leaderboard writes once per run. Third-party source for Heroic tiers: https://toolradar.com/tools/nakama/pricing (unverified against Heroic).

### 6.4 Staged online rollout (user decision 2026-11-07)

| Stage | Server (Nakama VPS) | Client | Notes |
|---|---|---|---|
| **Launch** (M7) | Device auth + Google link; cloud save with OCC versions and `purchase_ledger`; leaderboards (best wave per sector, weekly + all-time) with plausibility checks; `iap_validate` RPC; remote config `config/live`; trusted-time RPC; account-deletion RPC; Play Integrity verification | Sign-in, cloud-save conflict dialog, leaderboard screen, shop, Standby Patrol server-time claim, Ops Board with UTC resets | Gauntlet and Incursion screens are not shipped, but the sim ruleset hooks (`SimConfig.ruleset = standard or gauntlet`: fixed bracket seed, no drafts, 5 firmware slots, lull 90 ticks, pause budget 10 s) and the input log are built in M6/M7 so P1 is mostly server work plus UI |
| **P1** (first post-launch update) | Gauntlet brackets by Power Rating, `run_ticket`, promotion/relegation, rewards granted exactly once; Incursions via remote-config events and `merit` shop; Operation Pass; P1.5: seed + input-log replay verification of top-N and sampled scores | Gauntlet, Incursion and Operation Pass screens | Needs the 300-bot load test and forged-score rejection test from the old M6 exit criteria |
| **P2** | Cells via the Groups API | Cell roster and weekly goals; turncoat protocol N5 (client only) | Chat needs moderation tooling; out of scope for P2 v1 |

---

## 7. Monetization integration

### 7.1 Android plugin system and build

- Godot 4.2+ uses the **Android Gradle build + plugins v2 (`.aar` + `GodotPlugin` registered via `EditorExportPlugin`)** [A: plugin v2 introduced in 4.2; official docs: https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html]. Every plugin below needs **Project > Install Android Build Template** and **Gradle build enabled** in the export preset (`gradle_build/use_gradle_build=true`) [V for billing: https://github.com/godot-sdk-integrations/godot-google-play-billing].
- Godot 4.7 ships the GABE (Godot Android Build Environment) companion app as stable; relevant to on-device builds, not required for us [V: https://godotengine.org/article/gabe-stable-release/].
- Package: provisional applicationId `com.ironstatic.game` (decision 2026-11-07). It is **permanent** once the first build is uploaded to Play Console; confirm it first (open question Q30). The Godot 4.7 export template targets SDK 36 and needs Build-Tools 36.0.0 as well as 35.0.1 (see `docs/setup/DEV_ENVIRONMENT.md`).
- Required Gradle setup (documented in `docs/setup/` by the toolchain agent, summarized here): JDK 17, Android SDK platform 35+ with build tools, `target_sdk` per current Play requirement (verify before each release: Play requires targeting a recent API level yearly [A]), `min_sdk` 24 (Android 7.0; covers ~99% of active devices [A]), arm64-v8a (+ armeabi-v7a if size allows, open question Q35) and x86_64 for the emulator, AAB for Play and APK for emulator/dev, release keystore + Play App Signing, `gradle.properties` heap raised (`org.gradle.jvmargs=-Xmx3g`) for the 16 GB machine. **The Gradle build has not been tested yet** (DEV_ENVIRONMENT.md); task M0-09 does that.

### 7.2 Plugin matrix (all behind interfaces in `src/services/`; desktop/headless builds use stubs)

| Concern | Choice | Status of claim |
|---|---|---|
| In-app purchases | `godot-sdk-integrations/godot-google-play-billing`, master branch supports Godot 4.2+ [V: https://github.com/godot-sdk-integrations/godot-google-play-billing]; listed in Godot docs as the first-party route [V: https://docs.godotengine.org/en/4.x/tutorials/platform/android/android_in_app_purchases.html]. Exact tag/Billing library version for 4.7 not verified [A] | Partly verified |
| Ads (launch) | AdMob via `poingstudios/godot-admob-plugin` v5.1.0 (monorepo; the former `godot-admob-android` repo is archived), uses the Google Next-Gen Mobile Ads SDK 1.4.0 (not `play-services-ads`, so the community-fork Gradle crash does not apply), built-in UMP support, lists Godot 4.7.2 as tested [V: https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0, https://store.godotengine.org/asset/poingstudios/admob/]; verified on 4.7.2 in M0-11 (`docs/setup/plugin_matrix.md`) | Verified in the M0 spike (SDK init and test rewarded ad loaded on 4.7.2), re-verified in M7: a gate before committing |
| Mediation (post-launch) | AppLovin MAX or LevelPlay with their native Android SDK wrapped by our own thin plugin; no maintained Godot 4 plugin verified | **Assumed**; fallback: AdMob mediation adapters, which is what the Poing plugin exposes |
| Consent | Google UMP (via the AdMob plugin) [V: same README] | Partly verified |
| Sign-in | PGS v2 community plugin (godot-play-game-services); fallback: our own ~150-line Kotlin plugin (we are in Gradle anyway) | [A] |
| Integrity | Play Integrity API via small custom Kotlin plugin (`IntegrityManager.requestIntegrityToken(nonce)`), token verified on Nakama RPC using Google's `decodeIntegrityToken` | [A] no Godot plugin verified |
| Analytics | `godot-x/firebase` (Analytics/Crashlytics/Messaging; targets 4.6) [V: https://github.com/godot-x/firebase]; confirm 4.7 | Partly verified |
| Crashes | Sentry Godot SDK 1.x (needs Godot 4.5+; captures GDScript errors, Android native crashes) [V: https://docs.sentry.io/platforms/godot/] | Verified (docs may lag latest) |

Because plugin support for the newest Godot is the biggest external risk, the plan has a **plugin compatibility spike** (M0, tasks M0-09 to M0-12, result in `docs/setup/plugin_matrix.md`) before any feature depends on a plugin, and a rule: if a required plugin does not work on 4.7.x, pin the project to the newest Godot where all work (4.6) rather than fork plugins. Writing our own Kotlin plugins is a viable escape since the plugin v2 API is small.

### 7.3 Behaviour, policy and compliance

- **IAP flow**: client requests purchase -> Billing plugin returns `purchaseToken` -> client calls Nakama RPC `iap_validate` (server verifies with Google Play Developer API / Nakama `purchaseValidateGoogle`, records in `purchase_ledger`, grants entitlement, **then** client `acknowledge`s within 3 days or Google auto-refunds [A]). Consumables: consume after grant. Restore: `queryPurchases` on startup and re-grant from the ledger idempotently by `orderId`. Never grant premium currency locally without server confirmation once online; offline purchase queue allowed with later validation.
- **SKU plan (GDD 06 section 3 is authoritative)**: `flux_pack_xs` to `flux_pack_xxl` (six tiers, $0.99-$99.99), `data_cache_s/m/l` (time-based, max 5 per day), `cipher_pack_s/m/l` (max 3 per account per calendar month), `starter_pack` (one-time), `ad_free_claims` (non-consumable: rewarded-ad rewards are granted instantly without showing an ad; there are no forced ads to remove), `milestone_plus` (one-time), cosmetic `skin_pack_*`; `op_pass_premium` / `op_pass_plus` arrive with the Operation Pass in P1. Prices are set in Play Console, not in code.
- **Rewarded ads**: only user-initiated; reward granted on `onUserEarnedReward`; placements, rewards and caps are GDD 06 section 2 (`ad_flux_claim` 8 `flux` x 6/day with 20 min cooldown, `ad_lab_boost`, `ad_data_surge`, `ad_revive`, `ad_offline_double`, `ad_gauntlet_attempt` (P1), `ad_mission_reroll`; global cap 12 views/day; none in the first ~20 minutes; never mid-run); server-side verification (SSV) is added when ad `flux` has real value; caps and cooldowns are data-driven (`economy.csv`). Interstitials: none, ever (GDD 06 principle 1).
- **Consent**: UMP form on first launch for EEA/UK; "privacy options" entry in settings; ads and analytics initialised only after consent resolution. Analytics events carry no PII; Firebase configured with ad-personalization flags per consent state [A].
- **Target audience: 13+ (GDD rating target Teen; neutral age gate at first launch, under-13 blocks ads/IAP personalization, GDD Q6)** in Play Console, no child-directed treatment (`tag_for_child_directed_treatment=false`), content rating via IARC questionnaire (expect Teen for cartoon-like machine violence, no blood), so the app stays out of the Families Policy program [A: policy details, check Families policy page before submission].
- **Play Console prerequisites**: developer account ($25 one-time [A]) with identity verification, privacy policy URL (hosted page; must mention ads, analytics, accounts, purchases), Data safety form (declare device IDs, purchase history, crash logs, analytics, user-generated nickname if any), content rating, target audience declaration, ads declaration ("contains ads"), app category Game/Strategy, store listing assets (icon 512, feature graphic 1024x500, >= 2 phone screenshots), account deletion mechanism + web link (required for apps with account creation [A]), target API level compliance.

---

## 8. Anti-cheat for leaderboards (Launch) and Gauntlets (P1)

Threat model: a casual cheater edits the save, speed-hacks, or submits fake scores via the API; a determined one decompiles the APK and forges requests. We aim to make cheating **expensive and detectable**, not impossible, scaled to prize value (premium currency rewards give real incentive).

| Layer | Launch (leaderboards) and P1 (Gauntlets) | Later (P1.5+) |
|---|---|---|
| Identity | Authenticated account, Play Integrity token required to submit a leaderboard score (and, from P1, to enter a Gauntlet) (`MEETS_DEVICE_INTEGRITY` + `PLAY_RECOGNIZED`); fail -> can play but score not ranked [A on exact verdict handling] | Per-request integrity (standard API) with nonce bound to run id |
| Run envelope | Server issues `run_ticket` (run_id, seed, config_version, server time) at Gauntlet run start (P1; leaderboards at Launch use the plausibility checks below with a lighter ticket); score accepted only with a valid, unused ticket and within wall-clock plausibility (time between ticket and submit >= ticks/30/max_speed) | Ticket expiry and concurrency limits |
| Submission | Client sends `{run_id, final_wave, kills, damage_stats, build_summary (upgrade levels), sim_version, tick_count}`; server checks plausibility: wave vs tick_count vs speed multiplier, **economy bounds** (max possible `scrap` for those levels, computed by the same sim data), upgrade levels reachable from the player's *server-known* meta profile | Statistical outlier detection (z-score by league), device-fingerprint clustering |
| Replay verification | Not at Launch or P1 launch day; P1.5 | **Seed + input-log replay**: the client records `(tick, command)` (a few KB per run since the game is auto-play and the only inputs are upgrade purchases, patch picks, cache taps, weapon-system toggles and Overdrive activations; speed changes cannot affect outcomes). The server re-runs the same `sim/` in headless Godot (the sim is already headless by design) for top-N and randomly sampled submissions, compares final wave/state hash. Needs bit-stable sim across ARM and x86 (2.3); verify with a cross-arch determinism CI test on the emulator vs host. Fallback: tolerance-based comparison |
| Meta-profile trust | Server stores a **shadow of the player's meta profile** (levels, only deltas validated against sources: each currency source has rate limits and sinks are server-validated for premium) | Full server-authoritative meta |
| Response | Shadow-ban (scores hidden from others, removed from rewards at end), not instant bans | Appeals, auto-flag pipeline |

Design implication that is cheap now: **record the input log and the sim version from M2 onward** and keep the sim deterministic (tests assert that two runs with the same seed+inputs produce the same state hash; GDD 08 FC11). Gauntlets use the same seed for the whole bracket (GDD 06 section 5). That makes replay verification a server deployment task later, not a redesign.

---

## 9. Analytics and crash reporting

- **Analytics**: Firebase Analytics through `godot-x/firebase` [V: https://github.com/godot-x/firebase; targets 4.6, verify on 4.7]. Pairs natively with AdMob, gives free retention/funnel dashboards and BigQuery export. Alternative: GameAnalytics (has a Godot SDK [A], purpose-built for game funnels/resource-flow). Because the research shows The Tower itself runs Firebase + AppsFlyer [V: research note economy_monetization_liveops.md section 3, via AppGoblin], Firebase is the lowest-risk pick; add an MMP (AppsFlyer/Adjust) only when paid UA starts.
- **Crashes**: Sentry Godot SDK (GDScript errors with stack traces, native Android crashes, breadcrumbs from `Log`) [V: https://docs.sentry.io/platforms/godot/]; alternative Firebase Crashlytics (native only; less useful for GDScript errors) [A].
- All analytics go through `Services.analytics.log(event_name, params)` with a typed event catalog in `src/services/analytics_events.gd` (constants + param schema checked in a unit test), batching and consent gating. Desktop/headless uses a stub writing to `user://analytics_debug.jsonl` so agents can assert events in tests.

### Initial event taxonomy (snake_case, <= 40 chars, <= 25 params)

| Group | Events (key params) |
|---|---|
| Lifecycle / retention | `app_open` (session_n, days_since_install, device_tier, quality_tier, build), `session_start`, `session_end` (duration_s, runs_played), `tutorial_step` (step_id) |
| Funnel (FTUE) | `tutorial_step` ids: `first_deployment_start`, `first_kill`, `first_upgrade`, `first_death`, `first_foundry_buy`, `first_lab_start`, `first_firmware_pick`, `first_gauntlet_view` (P1), `first_ad_offer`, `first_purchase` |
| Deployment | `deployment_start` (sector, loadout_hash, config_version, speed), `deployment_end` (sector, wave, duration_s, cause, scrap_earned_log10, data_earned_log10, speed_avg), `wave_milestone` (every 25 waves), `boss_kill`, `death_cause` |
| Economy sources | `currency_earn` (currency, amount_log10 or int, source: kill/wave/mission/ad/gauntlet/iap/incursion/milestone/standby/cache/gift), `standby_claim` (minutes, doubled), `milestone_claim`, `mission_complete` |
| Economy sinks | `currency_spend` (currency, amount, sink: foundry/lab/lab_rush/firmware_pick/firmware_slot/weapon_slot/respec/store), `foundry_buy` (id, level), `lab_start`, `lab_complete`, `lab_rush` (flux), `firmware_pick` |
| Ads | `ad_offer_shown` (placement), `ad_started`, `ad_completed` (placement, reward), `ad_failed` (code), `ad_declined`, `consent_status` |
| IAP | `store_open`, `iap_view` (sku), `iap_start`, `iap_purchase` (sku, price_usd_micros, currency), `iap_fail` (code), `iap_validate_fail`, `ad_free_claims_purchased` |
| Competitive / live ops | `leaderboard_view`; P1: `gauntlet_attempt`, `gauntlet_run_end` (league, wave, rank_at_end), `gauntlet_result` (rank, reward), `incursion_mission_complete` |
| Technical | `perf_sample` (avg_frame_ms, p95_frame_ms, tick_ms, entity_count_p95, speed) every 60 s of run, `sim_throttled`, `save_fail`, `cloud_sync` (result, conflict), `load_time` |
| Cheat/anomalies | `integrity_verdict`, `clock_tamper` |

(Event names overlap deliberately with GDD 06 section 10.1; that list is the KPI minimum.)

Retention itself (D1/D7/D30) comes from Firebase's built-in cohorts keyed on `app_open`; revenue KPIs (ARPDAU, payer conversion) from `iap_success` + AdMob revenue linking.

---

## 10. Testing and CI

### 10.1 Pick: GdUnit4

- **GdUnit4** for unit/integration tests: scene runner, mocking, parameterized tests, a headless CLI (`GdUnitCmdTool.gd`), JUnit XML reports for CI. A forum post indicates GdUnit4 6.2.2 requires Godot 4.5+, i.e. current versions target modern Godot [V: https://forum.godotengine.org/t/things-that-exit-0-in-godot-4-headless-even-though-they-failed-measured-reproducible/145990 (secondary mention)]; explicit 4.7 support not verified, so pin a GdUnit4 release tested in M0 [A]. Typical command: `godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests` [V: secondary sources; confirm flags in docs for the pinned version].
- Alternative GUT: simpler, widely used, but GdUnit4 gives better typed-GDScript ergonomics (typed assertions, fluent API) and richer CI output. The decisive factor for agents is the machine-readable report.
- **Exit-code caveat** [V: same forum post, measured on 4.7.2]: headless Godot can exit 0 even on script load errors. Therefore our `tools/test.ps1` (a) runs the import step, (b) runs the test command, (c) **parses the output/JUnit XML** and fails on any `SCRIPT ERROR`, `Parse Error`, `ERROR:` lines or zero executed tests. Agents must use this wrapper, never raw godot.

### 10.2 Test layers

| Layer | What | Where |
|---|---|---|
| Unit | BigNum arithmetic/format/serialization, Rng determinism, curves, cost formulas, migrations, spatial grid | `tests/unit` |
| Sim scenario | "Laser Cycle vs 50 skitters: all dead by tick N", speed x1 vs x4 produce identical end state (key invariant: **speed-invariance**), swept collision for moving projectiles, wave clock = 720 ticks, pooling doesn't leak, caps, determinism (same seed -> same hash) | `tests/sim` |
| Data | Importer idempotence, referential integrity, monotonic costs, no NaN/inf in 1e3 levels | `tests/unit/data` |
| Save | Round-trip, corruption -> fallback to bak, fixture migrations, HMAC tamper | `tests/unit/save` |
| Contract | Backend facade with in-memory fake; Nakama TS modules tested with its own runner (`backend/tests`) and an integration test against Docker Compose in CI | `tests`, `backend/tests` |
| Smoke (emulator) | install APK, launch, wait 20 s, `adb exec-out screencap -p` screenshot, check `adb logcat` for FATAL/AndroidRuntime/SCRIPT ERROR, compare screenshot non-blank/size heuristics (+ optional pixel check that a red/amber HUD colour exists) | `tools/smoke_android.ps1` (builds on deploy_android.ps1) |

### 10.3 Automated balance runs

`tools/balance_run.gd` (headless): input `--sector N --waves W --profile profile.json --runs R --seed S`; builds a `SimWorld`, a **policy bot** (simple greedy buyer that buys the cheapest-cost-effectiveness upgrade by a configurable rule) plays R seeded runs at uncapped speed and writes CSV/JSON:

- survival: wave reached distribution (p10/p50/p90), time-to-death, cause of death
- economy curves: `scrap`/`data` per wave, cumulative; kill rewards by enemy type
- DPS and effective HP per wave, upgrade purchase timeline
- comparisons against **target curves** in `data/targets.csv` taken from GDD 03 section 6 and 05 section 8 (fresh profile reaches S1 wave 11-13; each doubling of Foundry power on damage and integrity adds 12-14 waves early; GDD 08 FC10 requires the median best wave within +-30%); CI prints a diff and **fails if a data change moves p50 wave by more than a threshold unless the PR updates targets** (change-detection, not absolute pass/fail).
- A nightly job runs a broad matrix (profiles x tiers) and uploads a Markdown report artifact. Agents use `tools/balance_run.ps1 -Profile fresh -Waves 100 -Runs 20` as the standard "did I wreck the economy" check.

### 10.4 Git and GitHub

- No repo exists yet. M0 task M0-01: `git init` in `C:\dev\tower`, `.gitignore` (`.godot/`, `build/`, `*.apk`, `*.aab`, `*.keystore`, `*.idsig`, `android/build/build/`, `android/build/.gradle/` (the Gradle template itself under `android/build/` stays tracked so plugin config is reproducible), `user://` copies, secrets), `.gitattributes` (`* text=auto eol=lf`, `*.png`, `*.ogg`, `*.wav` binary; `*.tres`/`*.tscn` as text, LF), Git LFS only for audio/large art if it exceeds ~50 MB total. Create a **private** GitHub repo via `gh repo create` once the user confirms the account (open question Q25). Branching: trunk-based with short-lived branches `agent/<task>`, squash merge via PR; protected `main` requires CI green.
- Secrets (keystore, `HMAC_KEY`, Nakama server key, AdMob IDs) are **not** committed: GitHub Actions secrets, local `secrets.local.json` ignored by git, templates in `export/`.

### 10.5 GitHub Actions

1. `ci.yml` (on PR): Ubuntu runner, cached Godot 4.7.2 Linux headless binary + export templates [A: download URL pattern from godotengine.org/github releases], steps: import (`--headless --import`), `gdlint`/`gdformat --check`, layer lint, data importer idempotence, GdUnit4 via wrapper, balance regression, backend TS tests. Target < 8 min.
2. `export.yml` (on tag/main): `godot --headless --export-debug "Android" build/ironstatic-debug.apk` (and release AAB signed with keystore from secrets); upload artifacts. Android SDK/JDK 17 set up via `actions/setup-java` and `android-actions/setup-android`.
3. `nightly.yml`: wide balance matrix + cross-arch determinism check [A].
The emulator smoke test is local (Windows dev box has the AVD `tower_phone`); optional CI emulator job via `reactivecircus/android-emulator-runner` later (slow, KVM-dependent, therefore not a PR gate).

---

## 11. Agent workflow

### 11.1 Proposed `CLAUDE.md` outline (short; link out to docs; keep under ~150 lines)

1. **What this is**: one paragraph + links to `docs/TECH_ARCHITECTURE.md`, `docs/design/` (GDD), `docs/setup/`.
2. **Commands** (single source): `tools\test.ps1`, `tools\sim_run.ps1`, `tools\balance_run.ps1`, `tools\import_data.ps1`, `tools\run_emulator.ps1`, `tools\deploy_android.ps1`, `tools\smoke_android.ps1`, `tools\lint.ps1`. Godot path: `C:\dev\tools\godot\4.7.2\...`. Never invoke godot test runs directly.
3. **Architecture rules** (the hard ones): sim is pure and headless; no Node/autoload/time/random-global in `src/sim`, `meta`, `save`; fixed tick; all randomness via `Rng`; BigNum for economy; numbers live in `data/*.csv`; no per-entity nodes; services behind interfaces with stubs.
4. **GDScript style**: static typing, warnings-as-errors, file size cap, naming, one class per file, no `Variant` in hot code.
5. **Data workflow**: edit CSV -> run importer -> commit CSV + generated `.tres`; never hand-edit `src/data_gen`.
6. **Testing rules**: add/adjust tests with every behavioural change; sim changes require a sim scenario test; economy changes require a balance run diff pasted into the PR.
7. **Save rules**: any persisted-shape change bumps schema version, adds migration + fixture.
8. **Do not**: commit secrets/keystores, modify `docs/setup` or `tools` created by others without asking, add dependencies/plugins without a decision note, add currencies, touch export presets casually.
9. **Definition of done** (11.3) and **PR template**.
10. **Gotchas log**: living section (headless exit-code caveat, Gradle/plugin traps, emulator quirks). Agents append findings.
11. **Parallelism rules**: one agent per module directory at a time; shared files (`project.godot`, `Content`, autoload list) are edited by the main agent only.

### 11.2 Task sizing

- A task = one module-level change that an agent can finish in one session: ~1-3 files created/changed, <= 400 changed lines, one verifiable acceptance criterion (a test or a run output). Larger features are split by seam: *data schema -> sim logic + tests -> view -> UI -> analytics event*.
- Every task statement includes: goal, files in scope, interface contract (function signatures), acceptance test, and what *not* to touch. Interfaces are defined first (as typed stubs + tests), then implementations can be parallelised across agents (e.g. targeting system and spawn system independently).
- Agents verify visually only through the emulator screenshot path; the user does feel/balance playtesting. UI/VFX tasks always attach a screenshot.

### 11.3 Definition of done

1. `tools\lint.ps1` clean (format, lint, layer rules, warnings-as-errors build).
2. `tools\test.ps1` passes with the wrapper (non-zero tests executed, no script errors).
3. Headless sim run succeeds: `tools\balance_run.ps1 -Profile fresh -Waves 30 -Runs 5` completes, no NaN/inf, p50 wave within target band (or targets updated deliberately and explained).
4. Debug APK builds, **installs and launches on `tower_phone`**; smoke script passes (no FATAL/SCRIPT ERROR in logcat, non-blank screenshot saved to `build/smoke/`).
5. Save compatibility: fixtures migrate; no schema change without version bump.
6. Docs/changelog line updated if an interface, command or content schema changed; `CLAUDE.md` gotchas appended when something surprising happened.
7. Performance gate for sim/view changes: `tools\perf_bench.gd` stress scenario (600 enemies + 600 projectiles) tick time within budget on the dev machine (relative regression check <= 10% against stored baseline, absolute numbers noted as dev-machine-specific).

---

## 12. Phased technical roadmap

`docs/ROADMAP.md` is the single source for milestone scope, order, exit criteria and task counts (it merges this plan with the GDD MVP scope in `docs/design/08_mvp_scope.md`). This section only lists the technical deliverables and the technical exit tests per milestone. The MVP gate is the end of M5, where GDD fun checks FC1-FC12 are run.

| Milestone | Technical deliverables | Technical exit tests |
|---|---|---|
| **M0 Foundation** | git + CI skeleton; Godot project skeleton with exact settings; GdUnit4 + output-parsing `tools/test.ps1` wrapper; lint (gdformat/gdlint/layer lint/warnings-as-errors); `IronStatic` export preset + `deploy_android.ps1`/`smoke_android.ps1`; plugin spike (Gradle build, Play Billing, AdMob, Sentry, Firebase, Nakama client, PGS) in `docs/setup/plugin_matrix.md`; CLAUDE.md final | Empty project launches on `tower_phone`; deliberate failing test makes the wrapper fail (canary); plugin matrix filled (works / pin to 4.6 / own plugin) |
| **M1 Core combat prototype** | `Rng`, `Curves`, importer v1 (enemies, constants, run upgrades), stores, spatial grid, `SimWorld` (720-tick wave clock), spawn, movement, targeting, hitscan Laser Cycle, damage and intake pipelines (MVP subset), 5 MVP enemies, wave scaling `G(l)`/`N(w)`, wave-end resolution, exposure bands, run end, headless runner, MultiMesh views, `CinderView`, minimal HUD, debug overlay | same seed gives same state hash; speed-invariance test; GDD 03 section 4.5 sample values reproduced; perf bench 600 enemies + 600 projectiles <= 4 ms per tick; emulator runs 3+ minutes without crash |
| **M2 In-run economy and upgrades** | `BigNum`, `NumberFormat`, `StatResolver` (Type D/C), 10 run upgrades with caps, gates and costs, `EconomySystem` (`scrap`, `data`, stale rule), buy x1/x10/x100/Max, input log + sim version recorded, UpgradePanel + theme, results screen v0, policy bot and `balance_run` v1 | BigNum/format tests; cost and stat tables match GDD 02 section 7; replay of a recorded input log reproduces the hash; balance run produces wave distribution |
| **M3 Meta loop and persistence** | `Profile`, `SaveManager` v1 (atomic write, HMAC, backup, migrations framework + fixture v1), run snapshot/resume, Foundry (4 rows), Home, Results, Foundry screens, settings v1, `Clock` stub | save tamper/corruption tests; Foundry purchase persists across app restart; killed app resumes a run |
| **M4 Patches, feel and FTUE** | Patches (9) and draft overlay, `boss_hulk`, Intel (Stats, Wave), damage numbers, VFX/juice, 2x speed, placeholder audio, FTUE per GDD 07 section 3, reduce-motion/colorblind basics | draft opens at wave 10; boss spawns and dies; FTUE script walkthrough on emulator |
| **M5 MVP validation** | Balance pass vs GDD 03 section 6, perf pass on a real device, determinism and 1x-vs-2x checks, fun-check playtests | FC1-FC12 results recorded in `docs/playtests/`; kill/rework rules in GDD 08 section 4 applied |
| **M6 Launch content** | Lab with real-time timers (trusted `Clock`), weapon systems (9), firmware (24), companions (4), N1 adaptive swarm, N3 salvage caches, N4 overdrive, skin-burn modifiers, sectors S2-S12 with battle conditions, elites, support enemies, 3 bosses, Standby Patrol (local), Ops Board (local), remaining Foundry rows and run upgrades, Launch patches, Gauntlet ruleset hooks, localization tables, QualityTier detection, shop UI shell | balance matrix inside GDD 03/05 targets (+-30%); migrations v1->v2 test; Lab timers survive restart and clock-change test |
| **M7 Online, monetization and release** | Nakama deploy (Docker, TLS, backups), device + Google auth, cloud save + conflict dialog, leaderboards, `Clock` server sync, remote config, Play Billing + server validation + restore, AdMob + UMP, Play Integrity, Firebase + Sentry, age gate, privacy policy, store assets, closed test, soft launch | Play license-tester purchase grants `flux` after server validation and survives reinstall via ledger; consent flow verified in EEA test; cloud-save conflict test with two profiles; forced test crash visible in Sentry; remote config changes a value without an update; crash-free users >= 99%, D1 >= 35% and D7 >= 12% floor (GDD 06 section 10 goals 42% and 17%) |
| **P1 Gauntlets and events** | Gauntlet brackets, `run_ticket`, rewards-once, Incursions, Operation Pass, then replay verification (P1.5) | simulated 300-player bracket load test; forged-score rejection; event configured purely by remote config |
| **P2 Cells and extras** | Cells (Groups API), turncoat N5, hardware modules, convoys, sectors 13-24 | per feature |

### 12.1 Google Play closed-testing rule (verified, re-check at submission)

- Personal developer accounts **created after 2023-11-13** must run a closed test with **at least 12 testers opted in for 14 continuous days** before applying for production access; organisation accounts are generally exempt, though they require a D-U-N-S number [V: https://support.google.com/googleplay/android-developer/answer/14151465 (Google Play Console Help), summarised by https://extendsclass.com/blog/google-plays-closed-testing-requirement-what-developers-need-to-know-in-2026 and https://www.choicely.com/blog/google-play-12-tester-rule]. Secondary blogs claim the 14 days reset if testers drop; Google's page does not say so [A: treat as risk, recruit 20+ testers]. One snippet quoted a "20 testers" figure which conflicts with Google's page; treat 12 as official minimum.
- **Plan**: create the developer account at the *start of M3* (identity verification can take days), upload the first closed-test build at the *end of M5* (MVP gate; requires a privacy policy URL and the basic app-content declarations), and recruit 20+ testers during M4-M5 so the 14 days run in parallel with M6. Decide personal vs organisation account (open question Q24); an organisation account removes the tester rule but needs a registered entity and D-U-N-S. The full timeline is in `docs/ROADMAP.md`.
- Budget ~3 weeks for first-launch review latency [V: secondary guides above].

### 12.2 Publishing checklist (owner: user for accounts/legal, agents for assets and text)

Developer account + payments profile (needed to sell IAP; merchant account tax info), privacy policy URL, data safety form, content rating questionnaire, target audience (13+), ads declaration, store listing + graphics, app signing enrollment, release notes, account deletion URL, countries and pricing, testers list, pre-launch report review, target API compliance, 64-bit support, optional "Play Games Services" project setup (OAuth client with release SHA-1), AdMob app + ad units + app-ads.txt on a developer website.

---

## 13. Key risks and mitigations

| # | Risk | Likelihood / impact | Mitigation |
|---|---|---|---|
| R1 | **Godot 4.7 plugin incompatibility** (AdMob/billing/analytics) | High / High | M0 plugin spike; pin to 4.6 if needed; thin interfaces so plugin swap = one file; own Kotlin plugins as escape (v2 plugin API is small) |
| R2 | **GDScript too slow** for thousands of entities on low-end phones | Medium / High | SoA packed arrays, no allocs, spatial grid, strict budgets measured from M1 with a stress bench; QualityTier fallbacks; single-system GDExtension (C++) escape hatch; sim moveable to a worker thread |
| R3 | **Determinism/cross-arch float mismatch** breaks replay verification | Medium / Medium | Plausibility checks first; deterministic design now (tick-counted timers, PRNG, minimal transcendental math); replay verification is P1.5 and tolerant first |
| R4 | **Economy imbalance / dead-end progression** (idle game curves are unforgiving) | High / High | Data-driven curves, balance runner and target bands in CI, remote-config live tuning, soft launch tuning |
| R5 | **Cheating in leaderboards and Gauntlets** damaging trust | Medium / High | Layered plan (section 8); shadow bans; record input logs from M2; limit `flux`/`cipher` rewards in early Gauntlets |
| R6 | **Save corruption / lost purchases** (top review complaint of The Tower: resets after updates [V: research note section 7]) | Medium / Very high | Atomic writes + backup + cloud + purchase ledger; migration fixtures in CI; never wipe silently; staged rollout in Play |
| R7 | **Google Play process delays** (12 testers x 14 days, review) | High / Medium | Open account early (start of M3), run closed test in parallel with M6 |
| R8 | **Policy rejection** (ads, Data safety mismatch, consent) | Medium / Medium | UMP from day one, accurate Data safety from SDK inventory, 13+ audience, no interstitial abuse |
| R9 | **Backend ops burden (self-hosted Nakama)** | Medium / Medium | Docker Compose + scripted backups + uptime monitor, infra as code, clear migration path to Heroic Cloud; client works offline-first so outages degrade gracefully |
| R10 | **Currency sprawl / pay-to-win perception** (top complaints in research) | Medium / Medium | Cap at ~5 currencies; ad-earnable rush currency; sell time/slots/cosmetics not raw power |
| R11 | **AI-agent drift** (inconsistent style, architecture erosion, breaking changes) | High / Medium | CLAUDE.md rules, layer lint, small files, interface-first tasks, definition of done enforced by scripts, one-agent-per-module |
| R12 | **Headless test false positives** (exit 0 on failure) | High / Medium | Wrapper script parsing output + test count check; deliberate-failure canary test in CI |
| R13 | **Dev machine limits** (Iris Plus, 16 GB: slow emulator GL, Gradle memory) | High / Low | Use headless benchmarks for CPU budgets; real-device performance checks (borrow a mid-range phone); emulator with swiftshader/host GPU tuned; Gradle daemon memory limits |
| R14 | **IP/legal similarity to The Tower or to a film franchise** | Low-Medium / High | Original names, art, theme (GDD 00 section 7); mechanics are unprotectable ideas, but do not copy UI layouts, number tables, text or naming; use GDD terms (Foundry, Lab, firmware, patches); trademark search on IRON STATIC (Q31) |
| R15 | **Float overflow / NaN in late game** | Medium / Medium | BigNum for currency and costs; ceiling guards on enemy scaling; NaN/inf assertions in tests and balance runs |
| R16 | **Staged online scope**: Gauntlet normalization hooks missing at Launch force a sim or save change after release | Low-Medium / High | Build `SimConfig.ruleset` hooks, `gauntlet_leagues.csv` schema, Power Rating function and the input log in M6/M7 even though Gauntlet UI ships in P1 |

---

## 14. Open questions

All open questions (design and technical) now live in one list: `docs/design/09_open_questions.md`. The technical ones formerly here are Q23 (quality floor device), Q24 (Play account type), Q25 (GitHub and CI), Q26 (backend hosting), Q27 (pricing aggressiveness) and Q29 (launch regions). Offline earnings, title, and backend staging were resolved by user decisions on 2026-11-07.

---

## Appendix A: Source list

- Godot 4.7 release: https://80.lv/articles/godot-4-7-has-been-released ; https://alternativeto.net/news/2026/6/godot-4-7-adds-arealight3d-asset-store-overhaul-gabe-support-and-hdr-output/ ; GABE: https://godotengine.org/article/gabe-stable-release/
- Nakama Godot client: https://github.com/heroiclabs/nakama-godot ; releases https://github.com/heroiclabs/nakama-godot/releases ; https://heroiclabs.com/blog/nakama-godot-4/
- Heroic pricing: https://heroiclabs.com/pricing ; third-party: https://toolradar.com/tools/nakama/pricing
- Play Billing plugin: https://github.com/godot-sdk-integrations/godot-google-play-billing ; Godot docs https://docs.godotengine.org/en/4.x/tutorials/platform/android/android_in_app_purchases.html
- AdMob plugin: https://github.com/poingstudios/godot-admob-plugin (live; `godot-admob-android` is archived) ; https://store.godotengine.org/asset/poingstudios/admob/
- PGS plugins: https://github.com/finepointcgi/PGSGP ; https://store.godotengine.org/asset/jacob-ibanez-sanchez/google-play-games-services-for-godot/
- Firebase plugin: https://github.com/godot-x/firebase ; Sentry Godot: https://docs.sentry.io/platforms/godot/
- GdUnit4/headless exit codes: https://forum.godotengine.org/t/things-that-exit-0-in-godot-4-headless-even-though-they-failed-measured-reproducible/145990
- Google Play testing requirement: https://support.google.com/googleplay/android-developer/answer/14151465 ; https://extendsclass.com/blog/google-plays-closed-testing-requirement-what-developers-need-to-know-in-2026 ; https://www.choicely.com/blog/google-play-12-tester-rule
- Research notes (local): `research_notes/The Tower game mechanics analysis/economy_monetization_liveops.md`, `meta_progression_systems.md` (combat_and_in_run_systems.md was not present when written).

## Appendix B: Things not verified (summary)

Plugin compatibility with exactly Godot 4.7.2 for billing, AdMob, Firebase, PGS and GdUnit4; any Godot 4 plugin for AppLovin MAX/LevelPlay; Nakama Postgres support and tournament feature details in the current server version; Heroic Cloud real prices; Play Integrity usage from Godot; target-API requirement for 2026; Families-policy specifics; GAMEANALYTICS Godot SDK status; all cost figures in 6.3; all phase durations and retention targets.
