# App content declarations: answer record (B1-09)

Changelog: 2026-11-09 v1.0 (B1-09, branch `b1-docs`).

Where: Play Console > Policy and programs > App content (the console moves items around: find each by name). All answers are for the **B1-04 beta build** (no ads, purchases, accounts, network or data collection); they are true only after B1-04 is done and `tools\aab_check.ps1` passes. The user enters them; this file is the record. Data safety and content rating have their own files: `data_safety_answers.md`, `content_rating_answers.md`.

| Declaration | Answer | Reason | Repo evidence |
|---|---|---|---|
| Privacy policy | `https://paimonsoror.github.io/iron-static/privacy/` | Required for every app. | `site/docs/privacy.md` (B1-05); live only after merge to `main` and a green Pages run. |
| App access | "All functionality is available without special access" | No login, no gated area. | No account or gate code in `src/`; unlocks are in-game progression only. |
| Ads | **No, my app does not contain ads** | No ad SDK in the beta bundle; house ads count too and there are none. Misstating this can suspend the app. | `docs/setup/plugin_matrix.md` B1-04 lines; `ads.APPLICATION_ID` absent from the merged manifest. |
| Content rating | see `content_rating_answers.md` | | |
| Target audience and content | Age groups **13-15, 16-17 and 18+**. Nothing under 13. "Might the app appeal to children?": **No** | Sci-fi combat against machines, dark industrial art, no mascots or cartoon characters. Under-13 groups would pull the app into the Families policy. Alternative: 16+ only (Q80). | Q80 default in `docs/design/09_open_questions.md`; `docs/design/10_art_bible.md`. |
| Data safety | see `data_safety_answers.md` | | |
| Government apps | **No** | Not made by or for a government. | |
| Financial features | **None** (no banking, loans, crypto, payments) | | |
| Health | **None** (no health features, not a medical app) | | |
| News | **Not a news app** | | |
| Advertising ID | **No** | No `AD_ID` permission after B1-04. | Data safety evidence table. |
| Account deletion / data deletion | "My app does not allow users to create an account" | No accounts. A web deletion link is only required for apps with accounts (`research_2026-11.md` 2.8). Local data is removed by Clear data or uninstall. | |
| Other special declarations (health apps, contact tracing, etc.) | Not applicable | | |
| EU trader status (DSA) | **Not a trader** while the beta earns nothing (Q83 default). Read the prompt Play shows; revisit before M7 (purchases, ads). | A free game from an individual with no income. Uncertain: Google's prompt decides the exact wording. | `research_2026-11.md` section 2.13 |
| Developer details shown publicly (personal account) | Legal name and address from the payments profile; public support email `[SUPPORT EMAIL]` | Play requires and shows them (Q83). | Nothing personal is committed to the repo. |
| App signing | Play App Signing (automatic on first upload); we keep only the upload key | | `research_2026-11.md` 2.6 |
| Countries for the test | US, CA, UK, IE, AU, NZ and the Nordics at first | Q85 | |
| Default store language | English (United States) | | `store_listing.md` |

## Re-do when

Adding any of these requires redoing **Data safety, content rating, the ads and target-audience declarations and the privacy page before that build is uploaded**: an SDK or plugin that touches the network, any new permission (INTERNET included), any network call, ads, purchases, accounts or sign-in, analytics or crash reporting, user-generated content or chat, leaderboards, cloud save, an age gate. These arrive in M7; the beta must not carry them. `RELEASE_CHECKLIST.md` repeats the list at upload time.
