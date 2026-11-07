# 06 - Monetization and Live Operations

Changelog: 2026-11-07 - online rollout staged (section 0): Gauntlets, Incursions and the Operation Pass move to the first post-launch update (P1), Cells to P2; Launch has accounts, cloud save and leaderboards on a self-hosted Nakama VPS.

Citations: `[ECON n]` = economy_monetization_liveops.md. The Tower monetizes time and slots, not exclusive stats, but is widely perceived as "pay to win" with heavy ads [ECON 3, 7]. We keep the F2P shape (rewarded ads, premium-currency IAP, starter pack, ad removal, milestone/season pass, tournaments, events, guilds later) and fix the complaints with explicit fairness rules. All prices and numbers are first-pass and tunable; store prices are USD anchors (localized tiers).

---

## 0. Rollout stages (user decision 2026-11-07)

| Stage | Online and monetization content |
|---|---|
| **Launch** | Rewarded ads (all placements except `ad_gauntlet_attempt`), IAP (`flux` packs, `data` caches, `cipher` packs, `starter_pack`, `ad_free_claims`, `milestone_plus`, cosmetics), Standby Patrol, Ops Board (section 6, UTC resets via server time), accounts (device + Google link), cloud save, leaderboards (best wave per sector), remote config |
| **P1** (first post-launch update) | Gauntlets (section 5), Incursions (section 7), Operation Pass (section 3.3 and `op_pass_*`, `event_boost`), `ad_gauntlet_attempt`, Gauntlet/Incursion screens |
| **P2** | Cells (section 8), turncoat protocol N5, hardware modules, convoys |

Sections 3.3, 5, 7 and 8 below describe designs that ship in P1/P2 but must be technically anticipated at Launch (see TECH_ARCHITECTURE 6.4: ruleset hooks, Power Rating function, input log). Reward currencies and caps in those sections are unchanged.

## 1. Principles
1. **Opt-in ads only.** Rewarded ads only. No interstitials, no banners, no forced ads, nothing during a run.
2. **Sell time, convenience and cosmetics.** `flux` buys rush, slots and firmware picks. No direct purchase of stats.
3. **Disclosed odds.** Any randomized purchase shows its odds before purchase (Google Play policy).
4. **Fair competition.** Tournaments bracket by power rating and cannot be bought into (section 5).
5. **Clear limits.** Every cap is displayed in-game. Daily ad caps and monthly cipher caps prevent runaway sessions.

## 2. Rewarded ad placements

All ads are user-initiated, preceded by a button showing the reward (e.g. "Watch ad: +8 flux"). If no ad is available, the button is hidden (never shown disabled). The game never auto-plays ads. Ads respect consent (GDPR/UMP; non-personalized if declined). The player may disable ad buttons in Settings. Players with `ad_free_claims` (section 3.2) get the same reward instantly with no ad shown.

| id | Where | Reward | Per-day cap | Cooldown | Notes |
|---|---|---|---|---|---|
| `ad_flux_claim` | Shop > "Salvage drop" | 8 `flux` | 6 | 20 min | [ECON 1: 6 gems, up to 60 claims/day; ours 6 claims] |
| `ad_lab_boost` | Lab slot card | -30 min remaining time | 6 | none (one per slot per hour) | Only on active research |
| `ad_data_surge` | Home, before DEPLOY | +50% `data` from kills this run | 4 | none | Not available in Gauntlets |
| `ad_revive` | Death screen | Revive at 50% integrity, 8 s invulnerable (once per run) | 3 | once per run | Not in Gauntlets |
| `ad_offline_double` | Standby Patrol return modal | x2 `data` of that Standby claim | 2 | per claim | |
| `ad_gauntlet_attempt` (P1) | Gauntlet screen | +1 attempt (max 2 per Gauntlet) | 2 per Gauntlet | none | See section 5 |
| `ad_mission_reroll` | Ops Board | Free reroll of one mission (instead of 5 `flux`) | 2 | none | |
Global cap: **12 rewarded views per day** (excluding `ad_gauntlet_attempt`). Typical engaged free player: 5-8 views/day. A first-time player sees no ad button until the tutorial is done and `best_s1` >= 8 (about 20 minutes into the game), and is limited to 3 views on day 1. [ECON 3: "prepare to watch many ads"; ours capped and never mid-run.]
Ad mediation (SDK choice, waterfalls) is a tech decision; GDD requirement is only placement, reward and caps.

## 3. IAP catalog (Google Play; USD anchors)

### 3.1 Consumables
| id | Price | Contents | Notes |
|---|---|---|---|
| `flux_pack_xs` | $0.99 | 80 `flux` (+10 first-purchase bonus) | |
| `flux_pack_s` | $4.99 | 450 `flux` | |
| `flux_pack_m` | $9.99 | 1,000 `flux` | |
| `flux_pack_l` | $19.99 | 2,200 `flux` | |
| `flux_pack_xl` | $49.99 | 6,000 `flux` | |
| `flux_pack_xxl` | $99.99 | 13,000 `flux` | best value, 0.77 cents/flux |
| `data_cache_s` | $1.99 | `data` = 4 h of the player's `farm_rate_1x` x 60 | up to 5 cache purchases/day total |
| `data_cache_m` | $4.99 | 12 h | |
| `data_cache_l` | $9.99 | 28 h | |
| `cipher_pack_s` | $4.99 | 60 `cipher` | max 3 cipher packs per account per calendar month |
| `cipher_pack_m` | $9.99 | 130 `cipher` | |
| `cipher_pack_l` | $19.99 | 280 `cipher` | |
Value check: `flux_pack_m` ($9.99, 1,000 flux) = 333 hours of lab rush or 22 firmware picks (22 x 45 = 990). A free player earns ~60 `flux`/day, so the pack equals ~17 days. Cipher: total weapon-system set = 3,603 `cipher` (04); max purchasable cipher per month ~ 3 x 280 = 840 ($60); free path ~150-2,500 per period; intent: spenders unlock systems in ~2-3 months, free players in ~8-10, tournaments still decide the premium-looking cipher pools (rewards are not exclusive).

### 3.2 One-time and recurring
| id | Price | Contents | Notes |
|---|---|---|---|
| `starter_pack` | $2.99 once (offer shows after tutorial for 7 days) | 300 `flux`; 1 firmware pick-1-of-3 with at least one Epic offered; `data_cache` of 24 h; cosmetic livery `skin_ashen` | highest value-per-dollar item; no stat advantage beyond the above |
| `ad_free_claims` | $7.99 permanent | Every rewarded-ad reward is granted instantly without watching an ad (caps unchanged) | "Ad removal" equivalent: there are no forced ads to remove [ECON 3: Disable Ads $9.99] |
| `milestone_plus` | $7.99 one-time | Premium column of sector milestones: x2 `data` and `flux`, x1.5 `cipher` for all current and future sectors | [ECON 3 Milestone Premium $9.99] |
| `op_pass_premium` | $7.99 per season (8 weeks) | Premium track of the Operation Pass | see 3.3 |
| `op_pass_plus` | $14.99 per season | Premium track + 10 tiers skipped | |
| `skin_pack_*` | $1.99-$4.99 | Cosmetic Cinder liveries, drone skins, beam colors | no stats; 6 at launch |
| `monthly_standby` (Post-launch, open question) | $4.99 / month sub | +10 `flux`/day claimable, Standby cap +2 h, ad-free claims | |

### 3.3 Operation Pass (season pass) [ECON 3, 4: event pass/milestones] - tag: P1
- Season length 8 weeks; 40 tiers; XP per tier 100; XP sources: daily mission (30 XP), weekly mission (60 XP), Gauntlet participation (40), Incursion mission tiers (20), first deployment of the day (10), sector milestone (20). Engaged player earns ~120-150 XP/day -> tier 40 in ~28-33 days; casual ~40 XP/day -> tier ~22 at season end.
- **Free track** (every 5th tier highlighted): 220 `flux` total, 4 `data_cache_s`-equivalents, 2 firmware picks, 40 `merit`, 10 `cipher`, 3 cosmetic items (common).
- **Premium track:** 650 `flux`, 3 firmware picks (one Epic-guaranteed offer at tier 20 and 40), 40 `cipher`, 120 `merit`, 4 `data_cache_m`-equivalents, season livery (`skin_season_N`), drone skin, profile frame/title, 1 module (Post-launch).
- **Fairness:** pass rewards convert to the same currencies as free play; no stat is exclusive to the pass; premium cosmetics from past seasons return in the shop for `flux` (or `merit`) after the season (no permanent FOMO). [ECON 7 inference: FOMO via limited cosmetics]
- Tier skip: 20 `flux` per tier.

## 4. Fairness rules (HARD design requirements)
1. **Tournament fairness.** Brackets are made by Power Rating, not by spending. Entry cannot be purchased with `flux` or cash. Maximum 3 attempts per Gauntlet window, 1 free and 2 ad-granted. Paid cosmetics and passes grant no Gauntlet stats. Rewards per rank are identical for payers and non-payers.
2. **Disclosed odds.** All randomized offers show odds on the offer screen and in Settings > Odds. Firmware pick: Common 62%, Rare 30%, Epic 8% per offered slot, with a pity guarantee of at least one Epic offered every 20 picks. No loot boxes of other kinds in the game. [Google Play paid random items policy]
3. **No paywall on progression.** Every in-game power source (Foundry, Lab, weapon systems, firmware, drones, modules) is obtainable free; paid items accelerate (time/convenience) not exclusive power. Only exception: purchasable `cipher` is limited (3 packs/month) to keep free-to-paid gap bounded.
4. **Timers.** No research exceeds 48 h; rush costs are linear (3 `flux`/h), free under 10 minutes, no hidden exponential rush price. [META: lab timers of days]
5. **No dark patterns.** No countdown pressure on essential items, no fake scarcity (limited cosmetics return), no confirm-shaming text, no pre-checked purchase boxes, no spending without a confirmation dialog, no ads that auto-start.
6. **Spending limits.** Optional monthly spend reminder and a purchase confirmation with real-money amount; parental guidance notice in Settings; rating Teen; no targeted ads to minors (age gate at first launch: under-13 blocks ads/IAP personalization; see 09 open question on age policy).
7. **Refund-safe design.** Purchased currency is spent from separate tracking (`flux_paid`, `flux_free`) for support/audits; not shown to the user.
8. **Transparent odds and caps.** Any cap (ads, cipher packs) is shown next to the button ("2/6 left today").

## 5. Gauntlets (tournaments) [ECON 4 tournaments, CIS 5-6 battle conditions] - tag: P1 (first post-launch update)

Design intent: fair, asynchronous, small brackets, protected low leagues, skill/build-driven, not spend-driven.

- **Unlock:** best S1 wave 60 (about day 4). [ECON 4: tier 1 wave 60]
- **Cadence:** two per week. Gauntlet A opens Wednesday 00:00 UTC, closes Friday 00:00 UTC (48 h). Gauntlet B opens Saturday 00:00 UTC, closes Monday 00:00 UTC (48 h). [ECON 4: Wed and Sat]
- **Bracket:** 30 players. Leagues: `lg_rivet` (1), `lg_alloy` (2), `lg_carbon` (3), `lg_titanium` (4), `lg_iridium` (5), `lg_singularity` (6). New players start in Rivet. Within a league players are grouped into brackets of 30 by **Power Rating** (nearest PR together). [ECON 4: 30 per bracket, six leagues]
- **Promotion/relegation:** top 6 promote (The Tower: top 4 [ECON 4]; ours 6 so progress feels faster). Bottom 6 relegate from Titanium and above. Rivet, Alloy and Carbon are protected (no relegation). A player whose PR exceeds the league ceiling is auto-promoted at next window (prevents sandbagging).
- **Power Rating:** `PR = 10 * log10(ref_dmg * ref_eHP)`, with `ref_dmg = laser_output_final * cycle_rate_final * (1 + crit_chance_final * (crit_mult_final - 1))` and `ref_eHP = (hull_integrity_final + 60 * nano_repair_final + plating_flat_final) / (1 - plating_pct_final)`. All "final" values evaluated at run level 0 with permanent sources only (Foundry, Lab, firmware, modules, companions). League ceilings (PR): Rivet 60, Alloy 80, Carbon 100, Titanium 120, Iridium 145, Singularity none (a new account is about PR 32; a x1,000/x1,000 account about PR 92; month-6 free accounts about PR 130-140; tunable after simulation).
- **Rule set (normalization):**
  - Same seed for the whole bracket (identical spawn sequence), so score comparisons are about build and play.
  - No patches/drafts. Max 5 firmware slots (even if the player owns more). Companion drones allowed. Weapon systems allowed. Overdrive allowed. No ad revive, no `ad_data_surge`, no pause beyond 10 s per run.
  - Lull is 3 s (halved) as in The Tower [CIS 1].
  - Sector/conditions: Rivet = S1 rules, Alloy S3, Carbon S5, Titanium S7, Iridium S9, Singularity S11 (their battle conditions), plus 0 / 1 / 1 / 2 / 3 / 4 rotating "heat" conditions chosen weekly from the list in 03 (scaled by that sector). [CIS 5: tournaments reuse battle conditions]
  - Permanent multiplier soft cap per league: damage and integrity multipliers from permanent sources above the league cap count at square root (cap = 10^(PR/10 ceiling)). Effect: overpowered accounts do not trivialize lower brackets.
- **Attempts:** 3 per window: 1 free + up to 2 via `ad_gauntlet_attempt` (or auto-granted with `ad_free_claims`). Best score counts. No `flux` or cash entry. [ECON 4: tickets via ad or 10+ gems; changed to eliminate paid entries.]
- **Score:** highest wave reached. Tie-breaks: lowest game time to reach it, then lower PR (rewards efficiency). Results must be verifiable: seeded deterministic runs with a replay hash; server may re-simulate suspicious scores (tech to confirm).
- **Rewards (per window; `flux` / `cipher`):** ranks 1 / 2-3 / 4-6 / 7-12 / 13-24 / 25-30.
| League | Rank 1 | 2-3 | 4-6 | 7-12 | 13-24 | 25-30 |
|---|---|---|---|---|---|---|
| Rivet | 40 / 10 | 30 / 8 | 22 / 6 | 16 / 5 | 10 / 3 | 5 / 2 |
| Alloy | 60 / 16 | 45 / 13 | 33 / 10 | 24 / 8 | 15 / 6 | 8 / 4 |
| Carbon | 90 / 28 | 68 / 22 | 50 / 17 | 36 / 13 | 22 / 9 | 12 / 6 |
| Titanium | 140 / 45 | 105 / 36 | 76 / 28 | 54 / 21 | 34 / 15 | 18 / 10 |
| Iridium | 210 / 75 | 158 / 60 | 115 / 45 | 82 / 34 | 52 / 24 | 28 / 16 |
| Singularity | 300 / 120 | 225 / 95 | 165 / 72 | 118 / 54 | 75 / 38 | 40 / 24 |
Plus participation: 20 Operation Pass XP; 2 `merit` for top 12. [ECON 4: Copper 100/20 down to Legend 800/425; ours lower in flux, scaled in cipher]
- **Anti-cheat requirements for tech:** deterministic simulation, signed run summaries, server-side plausibility bounds (wave vs PR), device clock independence. Staging: Launch leaderboards use plausibility checks only; Gauntlets (P1) add `run_ticket` and the shared bracket seed; replay verification follows in P1.5 (TECH_ARCHITECTURE sections 6.4 and 8).

## 6. Ops Board (daily/weekly missions) [ECON 4] - tag: Launch
- **Daily:** 3 missions, refresh at 00:00 UTC; rewards per 04 section 3.2; one free reroll per day (second via `ad_mission_reroll`, then 5 `flux`). [ECON 4: 6/day every 8 h; changed to 3/day because mission chores were not cited as positive and we want fewer sessions-by-obligation.] Unused missions do not accumulate beyond 3.
- **Weekly:** 5 missions, one chest on completing all 5: `data` = 240 farm-minutes, 70 `flux`, 10 `merit`, 1 firmware pick-1-of-3.
- Example mission templates (ids): `m_reach_wave` (reach wave X in sector S), `m_kill_type` (kill N of enemy type), `m_use_patches` (pick N patches), `m_spend_scrap`, `m_overdrive` (trigger Overdrive N times), `m_cache` (open N salvage caches), `m_no_upgrade_wave` (reach wave X buying only Chassis upgrades). Mission targets scale from `best_s1` (target = 60-75% of current best wave for the selected sector) so they stay achievable.
- Login streak (day 1-7): flux 5, data cache (30 farm-min), 5, firmware pick on day 7... Not mandatory: missing a day pauses (does not reset) the streak (kinder than The Tower's none found [ECON 4 gap]).

## 7. Incursions (events) [ECON 4] - tag: P1
- **Cycle:** 2 weeks. Unlock at best S1 wave 70.
- Missions released: 7 live on day 1 then +2/day for 7 days, 3 tiers each paying 10 / 15 / 20 `merit` [ECON 4]. Total per event ~ 270 `merit` free. A one-time `event_boost` ($4.99) doubles `merit` of that event's missions (not stats) - optional, shown with total.
- Event modifiers: each Incursion rotates one themed rule (e.g. "Static Storm: shade count x2, `sensor_reach` +10 m free", "Foundry Fire: kinetic -25% enemy resistance") that applies to Incursion deployments only (not standard runs); Incursion deployments are normal runs in the player's chosen sector that count for mission progress.
- Event shop (`merit`): `flux` packs (60 flux at 40, 65, 90, 130, 175 merit, rising, resets per event), `cipher` (10 cipher at 60, 100, 160, 240, 340), cosmetics (limited, re-buyable), companion drones (the four unlock prices 150/300/600/900 `merit`), data caches. [ECON 1 event shop price ladder]
- Cosmetic rewards return later via shop; no permanent power exclusive to events.
- Season rhythm: Incursion every 2 weeks (alternating with 1-week "Open Season" breaks in weeks 7-8 of the Operation Pass).

## 8. Cells (guilds) - tag: P2 (post-launch, after P1) [ECON 4]
- Unlock best S1 wave 70. 30 members, create for 50 `flux`, 8-week seasons aligned with Operation Pass.
- Contribution: each member's best wave per day adds Cell points. Weekly chest tiers at 100 / 250 / 500 / 750 total points (merit and flux; larger tiers pay more). Cell shop (`merit`) with rotating cosmetics, up to 3 purchases per currency per season. [ECON 4 guilds]
- Social: chat is Post-launch and requires moderation/report tooling; v1 has Cell roster, weekly goals, shared "Cell banner" cosmetic. No guild-only power systems (changed: The Tower's Guardian is a separate power layer [META]).

## 9. Compliance notes (design-level)
- Google Play: disclosure of odds; clear rewarded-ad labeling ("Watch an ad to receive..."); no misleading buttons; Teen audience, not designed for children; data safety form; ads consent flow; no gambling-like casino mechanics; no real-money currency-for-currency exchange.
- Store text: never mention Terminator or The Tower; keep screenshots original.

## 10. KPI targets (first-pass, all tunable)
| KPI | Soft launch target | Notes |
|---|---|---|
| D1 retention | 42% | genre benchmark for idle strategy; first 10 minutes designed (07) |
| D7 | 17% | habits: missions, lab timers, Gauntlet |
| D30 | 7% | long goals: sectors, firmware stars |
| Sessions per DAU per day | 4.5 | check-ins around runs and timers |
| Avg session length | 8-10 min | median deployment 5-8 min |
| Rewarded ad views per DAU | 3.5 | cap 12/day |
| Ad ARPDAU | $0.030 | ~3.5 views x eCPM $8 |
| IAP ARPDAU | $0.060 | |
| Total ARPDAU | $0.09 | |
| Payer conversion (D30 cumulative) | 3% | starter pack as first purchase |
| ARPPU (monthly) | $18 | |
| Starter pack attach (of payers) | 55% | |
| Gauntlet participation (of eligible DAU, from P1) | 35% | |
| Standby claims per DAU | 1.2 | |
| Crash-free sessions | >= 99.5% | |
Reference: The Tower reached >$65M cumulative with 4 full-time staff, 10M+ installs, peak ~$200K/day (third-party estimates) [ECON 6]. Our targets assume far smaller scale at launch.

### 10.1 Telemetry events needed to measure KPIs (names)
`session_start`, `deployment_start`, `deployment_end` (wave, sector, time, data, cause), `foundry_buy`, `lab_start`, `lab_rush`, `ad_offer_shown`, `ad_complete`, `iap_purchase`, `firmware_pick`, `gauntlet_attempt`, `mission_complete`, `milestone_claim`, `standby_claim`, `tutorial_step`, `death_cause`.
