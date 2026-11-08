---
name: playtest-report
description: Prepare or write up an IRON STATIC playtest - a question sheet for a milestone's user playtest, or turning the user's (or testers') notes into a structured report with findings, severities and follow-ups. Use at each milestone's "User playtest" step (docs/ROADMAP.md section 3) and for the MVP fun checks FC1-FC12.
argument-hint: "new <milestone, e.g. m1> | analyze <milestone> [path to notes]"
---

# Playtest report (IRON STATIC)

Adapted from the playtest-report idea in Claude-Code-Game-Studios (MIT), rewritten for this repo.
The user judges feel; the agent's job is to ask the right questions, record answers faithfully,
and turn them into actionable follow-ups.

## Rules

- **Quote, don't paraphrase into stronger claims.** Record what the user/tester said in their words;
  mark anything you infer as *(inference)*.
- **No data, no verdict.** A question nobody answered is `NO ANSWER`; a fun check without its
  measurement is `NOT MEASURED`. Never fill gaps with your own guess about how it felt.
- **Do not change the GDD or numbers from a playtest on your own.** Propose changes as follow-ups;
  the user decides. Balance changes go through `data/*.csv` + the importer + `tools\balance_run.ps1`
  once that exists (M2-14).

## Mode `new <milestone>`: the question sheet

1. Read the milestone's "User playtest" line in `docs/ROADMAP.md` section 3 and the fun checks it
   previews in `docs/design/08_mvp_scope.md` (table FC1-FC12).
2. Write `docs/playtests/<milestone>_playtest.md` with:
   - Session header to fill: date, build commit (`git log -1 --oneline`), device (emulator
     `tower_phone` or phone model), speed setting, how many runs, tester (user or tester id).
   - How to run it: `.\tools\run_emulator.ps1`, then
     `.\tools\deploy_android.ps1 -ProjectPath C:\dev\tower -Package com.ironstatic.game -Preset IronStatic`
     (or tell the user it is already running); debug overlay = double tap the top-left corner.
   - The milestone's questions, one per heading, each with a blank answer line and, where useful,
     a 1-5 scale. Add the matching FC preview's pass bar (from 08) so the user sees the target.
   - A free-notes section and a "bugs seen" list (what, when, screenshot if any).
3. Keep it short enough to fill in 5 minutes. Tell the user where the file is.

If the user prefers to answer in chat, ask the sheet's questions with AskUserQuestion (at most
4 per call, only the ones not yet answered) instead of making them edit the file.

## Mode `analyze <milestone> [notes]`: the report

Input: the filled sheet, a notes file, chat answers, or a mix. Append to (or create)
`docs/playtests/<milestone>_playtest.md` a **Report** section:

1. **Session**: header facts (fill unknowns as `UNKNOWN`, don't guess).
2. **Answers**: each question with the quoted answer or `NO ANSWER`; scales as numbers.
3. **Fun-check previews**: each previewed FC with the measurement, the pass bar from 08, and
   PASS / FAIL / NOT MEASURED. Formal FC runs (M5) need per-tester rows: record each tester, then
   the aggregate against the "x/10 testers" bar.
4. **Findings** table: id (`PT-<milestone>-NN`), category (Readability, Feel, Clarity/UX,
   Balance, Performance, Bug, Look), severity (blocker / major / minor / polish), evidence (quote,
   screenshot path, timestamp), proposed follow-up (task, GDD question, tuning experiment).
5. **Follow-ups**: for each major/blocker finding, either add an entry to
   `docs/design/09_open_questions.md` (with a recommendation) or draft a task for the next
   milestone's task file; list what you added. Ask the user before changing scope.
6. A three-line summary for the chat: what worked, the top problem, the proposed next step.

Commit the report (and any screenshots the user provided under `docs/playtests/<milestone>/`).
