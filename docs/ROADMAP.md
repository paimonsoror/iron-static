# IRON STATIC - Roadmap

Changelog: 2026-11-07 v1.0 - first version. Merges the technical plan (`docs/TECH_ARCHITECTURE.md` section 12) with the GDD MVP scope (`docs/design/08_mvp_scope.md`) and applies the user decisions of 2026-11-07 (title, novel mechanics N1-N4 approved and N5 deferred, Standby Patrol approved, staged online rollout, BigNum). This file is the single source for milestone scope, order, exit criteria and sizing. Agent-ready task files: `docs/tasks/M0.md`, `M1.md`, `M2.md`; later milestones get their task files when the previous milestone closes.

## 1. How to read this

- **GDD feature ids** (stat ids, enemy ids, system ids, section numbers such as "02 s7") come from `docs/design/`; the GDD is the source of truth for rules, terms and numbers. TECH_ARCHITECTURE is the source of truth for technology.
- **Size** is the rough number of agent tasks (one task = one agent session, at most about 400 changed lines, one objectively checkable acceptance criterion). Counts are planning estimates and will drift by +-30%.
- **Weeks** are calendar guesses for user-directed AI development at one to three tasks per session, with the user playtesting between milestones. They order the work; they are not commitments.
- **MVP = end of M5**, the milestone where the GDD fun checks FC1-FC12 are run (08 s4). **Launch = end of M7.** P1 and P2 are post-launch.
- Mechanics: N1 adaptive swarm, N3 salvage caches, N4 overdrive are Launch (M6); N2 skin burn visuals are MVP (M1/M4), modifiers Launch (M6); N5 turncoat is P2.

## 2. Milestone overview

| M | Name | One-line goal | Tasks | Weeks | Depends on |
|---|---|---|---|---|---|
| M0 | Foundation | Repo, project skeleton, tests, lint, export preset and plugin spike so every later task runs through gates | 14 | 1-2 | toolchain (done) |
| M1 | Core combat prototype | Deterministic headless sim plus on-screen auto-battle: Cinder, hitscan laser, 5 MVP enemies, waves, death, skin-burn bands | 26 | 3-4 | M0 |
| M2 | In-run economy and upgrades | `scrap`, 10 run upgrades, BigNum, upgrade panel, results, input log, first balance runner | 16 | 2-3 | M1 |
| M3 | Meta loop and persistence | `data` banking, Foundry (4 rows), Home/Results/Foundry, versioned HMAC save, run resume | 16 | 2-3 | M2 |
| M4 | Patches, feel and FTUE | 9 patches and draft, Intel, VFX/juice, damage numbers, 2x speed, audio, FTUE | 26 | 3-4 | M3 |
| M5 | MVP validation (MVP gate) | Balance pass, perf pass on a real device, determinism, fun checks FC1-FC12 | 12 | 2-3 | M4 |
| M6 | Launch content | Lab, weapon systems, firmware, companions, N1/N3/N4, sectors S2-S12, Standby Patrol, Ops Board | about 75 | 14-20 | M5 |
| M7 | Online, monetization and release | Nakama accounts/cloud save/leaderboards, billing, ads, compliance, closed test, soft launch, Launch | about 45 | 10-14 | M6 (backend track starts earlier) |
| P1 | Gauntlets and events | Gauntlets, Incursions, Operation Pass, replay verification | about 40 | 8-10 | Launch |
| P2 | Cells and extras | Cells, turncoat N5, hardware modules, convoys, sectors 13-24 | about 30 | open | P1 |

Totals: MVP (M0-M5) about 110 tasks; Launch (M0-M7) about 230 tasks. About 9-12 calendar months to Launch if sessions stay steady and the Play closed test runs in parallel (section 5).

## 3. Milestones in detail

### M0 Foundation (about 14 tasks, 1-2 weeks)
- **Goal:** every later task can be verified by scripts: git, project skeleton, GdUnit4 through an output-parsing wrapper, lint, export preset, emulator smoke test, and a verdict on plugin compatibility with Godot 4.7.2.
- **Scope:** no GDD features. Git init and ignore rules; project skeleton with the exact settings (TECH_ARCHITECTURE 1.1-1.2); GdUnit4; `tools/test.ps1`; `tools/lint.ps1`; export preset `IronStatic` (applicationId `com.ironstatic.game`); `tools/smoke_android.ps1`; plugin spike for Gradle, Play Billing, AdMob, Sentry, Firebase, Nakama client and Play Games sign-in; CI skeleton; CLAUDE.md finalization.
- **Exit criteria:** `deploy_android.ps1 -Preset IronStatic` shows the skeleton on `tower_phone`; one trivial test passes through the wrapper and a canary failure makes it fail; lint passes on the skeleton; `docs/setup/plugin_matrix.md` says per plugin: works on 4.7.2 / needs 4.6 pin / needs own plugin, and the Godot version is pinned; Gradle debug build installs and runs; CI green (needs Q25).
- **Dependencies:** none beyond the finished toolchain (`docs/setup/DEV_ENVIRONMENT.md`).
- **User playtest:** none. Open the emulator, launch the app, confirm a dark portrait screen with the title text and no crash (note the one-time "Viewing full screen" dialog).
- **Decision gate G0:** if a required plugin fails on 4.7.2, pin the project to Godot 4.6 (rule in TECH_ARCHITECTURE 7.2) before M1 starts.

### M1 Core combat prototype (26 tasks, 3-4 weeks)
- **Goal:** a deterministic simulation in pure `RefCounted` classes, playable headless and rendered with MultiMesh on the emulator, that already behaves like the GDD combat.
- **Scope:** 02 s1 (loop without spend), s2 (arena, caps), s3 (nearest targeting), s4 (Laser Cycle, base stats), s6 (24 s wave = 720 ticks, `N(w)`, spawn times and angles, boss wave rule), s8 steps 1-3, 5, 9 (global multiplier step = 1), s9 steps 6-7 and stale marking, s11 (death only), s12 steps 2-4 and 6, s12.1 exposure bands with hysteresis (N2 logic); 03 s1.1 `skitter`, `dart`, `walker`, `lancer`, s1.3 `boss_hulk` without plates, s2-s5 (HP/damage/reward formulas, `G(l)` phases 1-3, type weights and slot filling), s7 boss cadence; 07 s5.1-5.2 palette, s5.6 Cinder rendering (wedges and bands, simple), minimal HUD (wave, timer bar, integrity ring, speed button, pause), debug overlay; importer v1 for `sim_constants`, `enemies`, `run_upgrades`.
- **Exit criteria:** same seed gives the same state hash; 1x/2x/4x tick driver gives identical outcomes; GDD 03 s4.5 sample values (HP, atk, `N(w)`, scrap per kill) reproduced within 0.5%; perf bench 600 enemies + 600 projectiles at most 4 ms per tick on the dev machine; a no-upgrade headless run dies between waves 3 and 12; emulator runs 3+ minutes without crash at 30+ fps with 160 enemies; screenshots of band 0-3 Cinder saved.
- **Dependencies:** M0.
- **User playtest:** watch a run on the emulator. Questions: is the swarm readable, does the beam read as a laser, do skin-burn bands read at a glance (FC8 preview), does the machine-vision look feel right. Expect death around waves 5-10 with no upgrades.

### M2 In-run economy and upgrades (16 tasks, 2-3 weeks)
- **Goal:** the in-run loop works: kills pay `scrap`, the player buys the 10 MVP upgrades, numbers are big-number safe, and the headless balance runner exists.
- **Scope:** 02 s5 (type D/C resolution), s7 rows `laser_output`, `cycle_rate`, `crit_chance`, `crit_mult`, `optic_range`, `hull_integrity`, `nano_repair`, `plating_pct`, `scrap_yield`, `reinvest` (costs `ceil(c0 * g^L)`, caps, gates, x1/x10/x100/Max, milestone x1.5 ring every 25 levels), s7.4 starting values, s9 steps 1-2 (wave bonus, interest); 03 s3 rewards and the stale 50% rule; 04 s1-s2.1 (`scrap`), `data` per kill banked per run, s5 number format; 07 s2.1-s2.2 battle screen and upgrade panel, theme; BigNum from this milestone; input log plus sim version recorded per run; policy bot (greedy buyer) and `balance_run`.
- **Exit criteria:** BigNum and NumberFormat unit tests (GDD 04 s5 rules); every stat and cost table row matches GDD 02 s7 (data test); replaying a recorded input log reproduces the final hash; balance run prints p10/p50/p90 best wave for a fresh profile; emulator screenshot of the upgrade panel with correct amber/gray affordability colors.
- **Dependencies:** M1.
- **User playtest:** play runs buying upgrades by hand. Questions: do first purchases feel immediate (FC2 preview), is the difference between buying and not buying visible in kill speed, is the panel one-thumb usable. Report the wave reached by hand vs the bot.

### M3 Meta loop and persistence (about 16 tasks, 2-3 weeks)
- **Goal:** the redeploy loop with permanence: `data` banked at death, Foundry upgrades persist, the app survives kill and restart.
- **Scope:** 05 s1 Foundry with 4 rows (`laser_output`, `hull_integrity`, `nano_repair` Type D; `cycle_rate` Type C) incl. cost, multiplier and "Recommended" glow; 05 s7 unlock rows 1-2; 04 s2.2 `data` banking; 07 s2.3 Home, s2.4 Foundry, s2.10 Results; save system (TECH_ARCHITECTURE 5.1-5.3: atomic write, HMAC, backup, migrations framework, fixture v1, run snapshot and resume); settings v1 (sound, music, reduce motion, number format); `Clock` stub; best-wave tracking.
- **Exit criteria:** tamper and corruption tests pass (bad HMAC falls back to backup; never silent wipe); Foundry purchase persists across an app restart on the emulator; a run killed mid-wave resumes from the snapshot with an identical hash path; run 2 after a Foundry purchase is measurably stronger in the headless runner.
- **Dependencies:** M2. **Start the Google Play developer account here** (section 5).
- **User playtest:** three runs with Foundry in between; kill the app mid-run and reopen. Questions: do you understand permanent vs temporary (FC3 preview), does redeploy take under 10 s (FC4 preview).

### M4 Patches, feel and FTUE (about 26 tasks, 3-4 weeks)
- **Goal:** the MVP feature list is complete and polished enough to judge fun.
- **Scope:** 02 s10 patch draft (9 patches: `patch_overcharge`, `patch_plating`, `patch_rate`, `patch_extraction`, `patch_regen`, `patch_ceramic`, `patch_t_glass`, `patch_t_greed`, `patch_t_hardhide`) and 07 s2.9 overlay; `boss_hulk` warning ring and boss banner (02 s15); Intel tab Stats and Wave panels; skin-burn polish (embers, heartbeat, red vignette, band transitions, 07 s5.6); damage numbers (07 s5.5); VFX subset (`vfx_beam` merge, `vfx_hit_spark`, `vfx_kill_shatter`, `vfx_crit_flare`, `vfx_milestone_ring`, `vfx_wave_banner_glitch`, `vfx_boss_warning`, `vfx_draft_open`, `vfx_death_unravel`); 2x speed; placeholder SFX and one ambient loop (07 s7); FTUE per 07 s3 minutes 0-10; settings and accessibility basics (reduce motion, colorblind palette data); haptics.
- **Exit criteria:** wave-10 draft opens and each patch applies exactly per its table (unit tests); boss at wave 10 spawns and can be killed; FTUE script walkthrough on the emulator matches 07 s3 beats (screenshots at 6 timestamps); late-game stress scene holds the budget in TECH_ARCHITECTURE 2.7 or documents a QualityTier fallback; trademark search (Q31) and a real mid-range device (Q23) done.
- **Dependencies:** M3. Art lock for the icon and logo waits for Q31.
- **User playtest:** a fresh-install first 10 minutes, as a new player. Questions: FC2 (understanding without text), FC7 (patch choice), FC8 (skin burn legibility), overall feel.

### M5 MVP validation, the MVP gate (about 12 tasks, 2-3 weeks)
- **Goal:** prove the core loop is fun and the numbers match the GDD before building any more meta.
- **Scope:** balance pass of 03 s6 and 05 s8 targets with the headless simulator (policy bot, Foundry multipliers x1/x2/x4/x10); performance pass on the real device (FC6); determinism checks (same seed, 1x vs 2x, FC11); crash-free and soak run; closed-test build prepared (privacy policy URL live, Q34).
- **Exit criteria:** FC1-FC12 executed and recorded in `docs/playtests/mvp_fun_checks.md`; FC10 median best wave within +-30% of 03 s6 for x1, x2, x4, x10; FC6 numbers on the reference device; GDD 08 s4 kill/rework criteria applied (if FC1, FC3 or FC4 fail, adjust base numbers, early curves and FTUE and re-run before M6); first closed-test AAB uploaded to Play Console.
- **Dependencies:** M4, a real device, 10 playtesters (mixed idle-game experience).
- **User playtest:** the formal fun checks with testers; plus the user's own sign-off on look and feel.
- **Decision gate G2:** meta layers (firmware, Lab, weapons) start only after FC1-FC4, FC6 and FC10 pass (08 s4).

### M6 Launch content (about 75 tasks, 14-20 weeks; four sub-phases, 6B/6C can run in parallel)
- **Goal:** every Launch-tagged system in the GDD works and is balanced inside +-30% of the progression targets.
- **6A Data and run content (about 12):** all remaining run-upgrade rows (02 s7.1-7.3), Foundry all rows (05 s1), all unlock gates (05 s7), remaining Launch patches (02 s10.1-10.3), full `G(l)` phase 3 and Overrun (03 s4.3), `signal_lag`, free upgrade rolls, repair pods.
- **6B Arsenal and Lab (about 25):** R&D Lab with real-time timers and trusted `Clock` (05 s2, 07 s2.5); 9 weapon systems and levelling (05 s3); 24 firmware chips, pick-1-of-3, disclosed odds and pity, presets (05 s4); 4 companion drones (05 s6); Arsenal screen (07 s2.6).
- **6C Swarm and sectors (about 28):** N1 adaptive swarm (02 s8.1) with HUD bars; N3 salvage caches (02 s13); N4 overdrive (02 s13); skin-burn modifiers (02 s12.1); `aegis_node`, `shade`, `jammer`, `mender`; elites `siege_lance`, `siphon`, `brood`; bosses `boss_hive`, `boss_lance`, `boss_null`; sectors S2-S12 and battle conditions (03 s8); sector milestones (04 s3.1).
- **6D Live-ready systems (about 10):** Standby Patrol local implementation with trusted-clock rules (04 s4, TECH_ARCHITECTURE 5.5); Ops Board missions (06 s6); shop UI shell with stub services (07 s2.7); localization tables (Q15); QualityTier detection; Gauntlet ruleset hooks and Power Rating function (not the Gauntlet UI); `flux` earn paths.
- **Exit criteria:** balance matrix (policy bot per sector and Foundry state) inside +-30% of 03 s6 and 05 s8 targets; save migration v1 to v2 test; Lab timers survive restart and clock-change test; Standby Patrol caps tested; no NaN/inf in 1,000-run matrix; perf bench within budget with all systems on.
- **Dependencies:** M5 (G2). **Decision gate G3 (mid-M6):** if throughput is low, ship S1-S8 and add S9-S12 as an update (Q10).
- **User playtest:** after each sub-phase: 6A a long run to wave 30+ with the new rows; 6B a Lab/firmware/weapon session (is the first pick exciting, are odds clear); 6C sectors, adaptation HUD, overdrive and caches (does N1 frustrate or teach, is N4 optional); 6D a day of real use with Standby and missions.

### M7 Online, monetization and release (about 45 tasks, 10-14 weeks)
- **Goal:** the Launch build is online, monetized, compliant and through Play review.
- **7A Backend (about 12):** Nakama Docker deploy with TLS and backups on a VPS (Q26); device auth plus Google link; cloud save with OCC and conflict dialog; `purchase_ledger`; leaderboards (best wave per sector; Q33); trusted-time RPC; remote config overlay; account deletion; Play Integrity verification. The backend track may start during M6 once the save format is frozen (after M3) and Q26 is answered.
- **7B Services (about 12):** Play Billing client, server validation, restore; AdMob rewarded ads and UMP consent with the placements and caps in 06 s2; Firebase Analytics events (TECH_ARCHITECTURE 9); Sentry; Play Games sign-in link.
- **7C Compliance and store (about 10):** age gate (Q6), privacy policy, Data safety form from the SDK inventory, IARC content rating, ads declaration, store listing text and assets (icon, feature graphic, screenshots), odds screens, account-deletion page, target API compliance, release AAB and Play App Signing.
- **7D Closed test, soft launch, Launch (about 11):** closed test already running since the end of M5 (14 continuous days); fix crash and ANR findings; production access application; soft launch in 2-3 countries (Q29) with the 06 s10 KPI dashboard; tuning from live data; Launch.
- **Exit criteria:** Play license-tester purchase grants `flux` after server validation and survives reinstall via the ledger; ad flow works with test ads and consent verified for an EEA profile; cloud-save conflict test with two profiles; a forced exception shows up in Sentry; remote config changes a value without an app update; closed test requirement met and production access granted; crash-free users at least 99%; soft launch D1 at least 35% and D7 at least 12% as the go/no-go floor (GDD 06 s10 goals are 42% and 17%), no P0 bugs.
- **Dependencies:** M6 (7A can start earlier), Q24, Q26, Q30, Q34.
- **User playtest:** real purchases with a license-tester account, consent flow, two-device cloud-save test, and the soft-launch dashboards.

### P1 Gauntlets and events (about 40 tasks, 8-10 weeks; the first post-launch update, v1.1)
- Gauntlets (06 s5): bracket assignment by Power Rating, six leagues, `run_ticket`, shared bracket seed, promotion and relegation, rewards granted exactly once, `ad_gauntlet_attempt`; Incursions (06 s7) via remote-config events and the `merit` shop; Operation Pass (06 s3.3, `op_pass_premium`, `op_pass_plus`, `event_boost`; Q28); Gauntlet screen (07 s2.8). P1.5: seed + input-log replay verification of top-N and sampled scores.
- Exit: simulated 300-player bracket load test forms brackets and promotes correctly across a full cycle; a forged score is rejected; an Incursion is configured purely by remote config.
- Needs from earlier milestones (built in M6/M7): ruleset hooks, Power Rating function, input log, `gauntlet_leagues.csv` schema.

### P2 Cells and extras (about 30 tasks, open-ended)
- Cells (06 s8) via the Groups API, turncoat protocol N5 with `patch_turncoat` and `fw_turncoat`, hardware modules (05 s5), convoys and sectors 13-24 (03 s1.4, s8), UW+ and companion Plus abilities.

## 4. Critical path

```
M0 -> M1 -> M2 -> M3 -> M4 -> M5 (MVP gate) -> M6 (6A -> 6B || 6C -> 6D) -> M7 (7D) -> Launch -> P1 -> P2
```

Parallel tracks that must not slip, because they gate the critical path:

| Track | Starts | Must finish by | Why it matters |
|---|---|---|---|
| Plugin verdict (G0) | M0 | end of M0 | A 4.6 pin after M1 would mean redoing the toolchain and re-verifying everything |
| Perf validation | M1 (bench) | M5 (real device) | FC6 is an MVP gate; GDScript speed is the largest technical risk (R2) |
| Google Play account and testers | start of M3 (account), M4 (testers) | closed-test upload at end of M5, 14 days during M6 | The 12 testers x 14 days rule would otherwise add 3-5 weeks after M7 |
| Trademark, domain, package ID (Q30, Q31, Q34) | before M4 art lock | before first Play upload (end of M5) | Package ID is permanent; privacy-policy URL is required for a closed test |
| Backend track (7A) | after M3 (save format frozen) and Q26 | M7 | Cloud save needs the final save schema; parallelizable with M6 content |
| Audio and art commission (Q19, Q14) | M5 | M7 | Placeholders must be replaced before the closed test is public-facing |

Gates: G0 plugins (end M0), G1 perf bench (end M1), G2 fun checks (end M5), G3 sector scope (mid M6), G4 closed test passed (M7), G5 soft-launch KPIs (before global launch).

## 5. Google Play prerequisites timeline

Target state at Launch: personal account assumed (Q24); if an organisation account is used, the 12-tester rule does not apply but a D-U-N-S number and registered entity are needed.

| When | Item | Owner | Notes |
|---|---|---|---|
| Before M3 | Decide personal vs organisation account (Q24) | user | Drives the whole timeline |
| Start of M3 | Create the developer account (one-time fee about 25 USD), identity verification, payments profile | user | Verification can take days; needed for IAP later |
| Before M4 art lock | Trademark and store-name search on IRON STATIC (Google Play, USPTO, EUIPO, domain, handles); optional lawyer review (Q31) | user | Fallback title EMBER CHASSIS |
| Before M4 ends | Register a domain; host privacy policy and account-deletion page (Q34); confirm the final package ID (Q30) | user, agent drafts text | Privacy policy must cover ads, analytics, accounts, purchases |
| M4 | Recruit 12 minimum, 20+ recommended testers, collect Google account emails (Q36) | user | The 14-day clock needs testers to stay opted in; recruit extras |
| End of M5 | Fill app-content declarations needed for any track: ads declaration, target audience (13+ with age gate), content rating (IARC, expect Teen), Data safety draft from the SDK inventory | agent drafts, user submits | Re-verify after M7 adds SDKs (billing, Firebase, Sentry) |
| End of M5 | Upload first closed-test AAB (release-signed, Play App Signing), create the closed track, add testers, start the 14-day clock | agent builds, user uploads | The build may be updated during the test; do not let opted-in testers drop below 12 |
| M6 (14 days later) | Closed test period completes; review feedback | user | Re-start the count if opted-in testers fall below 12 (risk per TECH_ARCHITECTURE 12.1) |
| Start of M7 | Apply for production access; AdMob account and app, `app-ads.txt`; Play Games Services OAuth client with release SHA-1 | user | Review latency about 3 weeks for first release [secondary sources] |
| M7 (7C) | Final Data safety form, store listing text and graphics (icon 512, feature graphic 1024x500, at least 2 phone screenshots), pre-launch report review, target API level compliance, 64-bit | agent assets, user submits | No Terminator or The Tower references in listing text |
| M7 (7D) | Soft launch: production release with country targeting (Q29) or open testing; staged rollout percentage | user | Watch crash-free users and ANR thresholds |
| After soft-launch KPIs | Global rollout; keep staged rollout at 20% then 50% then 100% | user | |

## 6. Per-milestone user checklist (what only the user can do)

- M0: answer Q25 (GitHub). M1-M2: playtest on the emulator; decide whether the look is right.
- M3: Q24, create Play account. M4: Q23 (real device), Q31 (trademark), Q34/Q30 (domain, package ID), Q36 (testers).
- M5: run the formal fun checks with testers; upload the closed-test build.
- M6: Q26 (backend hosting), Q10 (sector count gate), Q15 (languages), Q19 and Q14 (audio/art sources); playtest each sub-phase.
- M7: Play, AdMob and legal paperwork, license testers, soft-launch decisions (Q29).
