class_name SimVersion
extends RefCounted
## Version of the simulation rules, recorded in every RunRecord (TECH_ARCHITECTURE section 8).
## BUMP RULE: increase CURRENT whenever a change alters simulation outcomes for the same inputs
## (same seed, config and commands): tick order, formulas, RNG use, stat resolution, costs, hashing.
## Pure refactors and additions that leave every hash unchanged do not bump.
## `tests/sim/test_replay.gd` holds a golden hash of a scripted run and fails when it changes.

const CURRENT: int = 1
