# Privacy policy: what each statement rests on (B1-05)

Changelog: 2026-11-09 v1.0 (B1-05, branch `b1-docs`).

Page: `site/docs/privacy.md`, published at `https://paimonsoror.github.io/iron-static/privacy/` after the change reaches `main` and the Pages workflow is green. The text is written for the **B1-04 beta build** (no Billing, no AdMob/UMP, no Sentry, no Nakama, only the VIBRATE permission). **B1-04 must be done and `tools\aab_check.ps1` must PASS before the page is true.** If B1-04 keeps INTERNET (decision still open when this was written), change the "does not request the Android internet permission" sentence and the permissions table.

Placeholder the user fills before the Play submission: `<DEVELOPER NAME>` (exactly as shown on Google Play), plain text in `site/docs/privacy.md`. The contact is the public support address `support@normalexception.net` (Q83, decided 2026-11-09); never commit a personal email.

| Statement on the page | Evidence |
|---|---|
| Collects no data, nothing sent | `grep -rn "HTTPRequest\|HTTPClient\|WebSocket\|StreamPeer\|ENet\|PacketPeer" src` finds no network use (checked 2026-11-09). `src/net/backend.gd` is an interface; `BackendOffline` is the only implementation; Nakama arrives in M7. `src/services/` falls back to `BillingStub`/`AdsStub` when the Android singleton is absent (`services.gd`), which B1-04 guarantees by excluding the plugins. |
| No internet permission | B1-04 spec item 4 (default off) and acceptance (`INTERNET` absent from the merged manifest). Today's `export_presets.cfg` still has `permissions/internet=true` in both presets until B1-04 lands. |
| No accounts, ads, purchases, analytics, crash reporting | B1-04 spec: Billing and AdMob/UMP plugins off, Sentry removed (Q81 default), Nakama excluded; no analytics code exists in `src/`. |
| Only vibration permission | B1-04 acceptance: permission list is exactly `VIBRATE`; `src/core/haptics.gd` (M4-22) uses it; Settings has a haptics toggle (`settings.haptics`). |
| Save (profile, run snapshot, backup, signed) in private storage | `docs/TECH_ARCHITECTURE.md` section 5 and the v1.6 changelog line; `src/core/save_service.gd`; files under `user://save/`. Android `allowBackup` is false (`docs/release/aab_audit.md`), so the files are not copied to Google backups either. |
| Random identifier in the save, never sent | `src/core/game.gd` line 118 creates it with `Crypto.generate_random_bytes(16)` and passes it to `SaveService`; its only consumer outside the save is `Backend.authenticate`, which is the offline stub in the beta. It is not an advertising id. |
| Settings stored locally | `src/meta/settings/player_settings.gd`: settings are part of the profile save; no remote config exists in the beta. The last-run record is `user://runs/` written by `src/core/run_controller.gd` (local file, overwritten per run). |
| Reset in Settings, Clear data, uninstall | `settings.reset` and the double-confirmed profile reset (M3, `docs/design/09_open_questions.md` Q58-Q64 area, `site/docs/status.md`). Clear data and uninstall are standard Android behavior for private app storage. |
| Feedback form is external | B1-08 and Q82 (Google Form linked from the codex and Settings; opened in the browser, no INTERNET permission needed). **If B1-08 does not ship, delete the "Feedback" section.** |
| Website hosting note | The codex is built by `.github/workflows/pages.yml` and hosted on GitHub Pages. No analytics or cookies are configured in `site/mkdocs.yml`. |
| Not for children under 13 | Q80 default (target audience 13+), `docs/release/declarations.md`. |
| Changes announced before an online build | Release rule in `docs/release/RELEASE_CHECKLIST.md` ("re-do when" list). |

Code contradictions found while writing: **none**. Nothing in `src/` makes a network call. Items worth knowing: the debug preset and the current beta preset (before B1-04) still contain INTERNET, AD_ID, BILLING and the Sentry libraries (`docs/release/aab_audit.md`); that is exactly what B1-04 removes. The page is not true for any build made before B1-04.

No franchise names appear in the page. `grep -n "@" site/docs/privacy.md` finds nothing.
