class_name SimVersion
extends RefCounted
## Version of the simulation rules, recorded in every RunRecord (TECH_ARCHITECTURE section 8).
## BUMP RULE: increase CURRENT whenever a change alters simulation outcomes for the same inputs
## (same seed, config and commands): tick order, formulas, RNG use, stat resolution, costs, hashing.
## Pure refactors and additions that leave every hash unchanged do not bump.
## `tests/sim/test_replay.gd` holds a golden hash of a scripted run and fails when it changes.

## 6 = R1 Phase A (burn hardening, Foundry soft cap and constants as data, draft rework), 2026-11-10;
## 5 = Foundry milestone x1.75 every 25 levels (FO-3), 2026-11-09; 4 = patches and the draft (M4-15), 2026-11-09;
## 3 = wave modes (TIMED/PURGE); 2 = M3 retune (Q54); 1 = M2/M3 launch rules.
const CURRENT: int = 6
