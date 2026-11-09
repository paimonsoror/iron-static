# Content rating questionnaire: answer record (B1-09)

Changelog: 2026-11-09 v1.0 (B1-09, branch `b1-docs`).

Where: Play Console > Policy and programs > App content > Content rating > Start. Email: the public support email `[SUPPORT EMAIL]`. Category: **Game**. The answers come from `docs/release/PLAY_BETA_GUIDE.md` phase 5. The console's wording can change: read each question and map it to the closest row here.

## Answers

| Question | Answer | Reason and repo evidence |
|---|---|---|
| Violence | **Yes**, cartoon / fantasy violence only | A cyborg shoots robotic enemies with a laser. Enemies are machines (`enemy.name.*`: skitter, dart, walker, lancer, boss hulk). No blood, no gore, no human or animal victims, no realistic weapons. Cinder's "synthetic skin burns away" is a visual state, not injury to a person. |
| Sexual content, nudity | **No** | Nothing in `data/strings_en.csv`, the art bible or the codex. |
| Profanity / crude humor | **No** | String scan below: no hits. |
| Controlled substances (drugs, alcohol, tobacco) | **No** | Scan below. |
| Gambling, simulated gambling, loot boxes | **No** | No random paid rewards; no purchases at all. The draft card tag `draft.gamble` (GAMBLE) labels a patch that carries a stated cost (`patch.t_*.cost`); nothing is wagered and no real or virtual money is staked. |
| User-generated content, chat, user interaction | **No** | No multiplayer, chat or sharing; the beta has no network code. |
| Shares user location | **No** | No location permission; permission list is `VIBRATE` only. |
| Allows purchases of digital goods | **No** | No Billing in the beta build. Redo the questionnaire in M7. |
| Unrestricted web access | **No** | No webview or in-app browser. The feedback button (B1-08) hands a link to the system browser, which is not in-app web access. |

**Expected result:** Teen class (ESRB Teen, PEGI 12 or similar, IARC generic 12+). If the summary shows Mature, 18+ or an unexpected descriptor, an answer is wrong: stop and tell the agents. Record the calculated ratings after submitting:

| System | Result (fill in) |
|---|---|
| IARC generic | |
| ESRB | |
| PEGI | |
| USK | |
| ClassInd | |
| ACB | |
| GRAC | |
| Submitted on | |

## String scan (2026-11-09)

Scope: every line of `data/strings_en.csv` (298 lines, the only UI text source), plus the privacy page and the listing texts.

- Profanity and slurs: a case-insensitive scan for common profanity and slur stems: **0 real hits**. Substring matches such as "ass" inside CHASSIS and PASSIVE were reviewed and are ordinary words.
- Violence words: "kill" (KILLS counters, `results.kills`, `results.stat_kills`) and "DESTROYED BY" (`results.killed_by`). All refer to machines. No blood, gore or human-death wording.
- Substances, sexual terms, gambling terms: 0 hits except `draft.gamble` (GAMBLE), explained above.
- Franchise and real-world brand names (the CLAUDE.md IP guardrail list, The Tower's words, platform and company names): **0 hits** in `data/strings_en.csv`, `site/docs/privacy.md` and `docs/release/store_listing.md`.

Re-run the scan whenever strings change (M5/M6 add content) and paste the result into the release checklist.
