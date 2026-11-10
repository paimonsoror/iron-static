class_name InputLog
extends RefCounted
## Player commands of one run as parallel packed arrays: (tick, kind, a, b). Appended by
## `SimWorld.command_buy`, `command_pick` and `command_reroll`. A command logged at tick T is applied
## before `step()` runs tick T, in live play
## and in replay alike (`world.tick` is the tick about to run, so recording `world.tick` is the rule).
## (impl) Only accepted commands are logged: a rejected buy changes no state, so replay is unaffected.

const CMD_BUY: int = 0  ## a = upgrade row index, b = count requested (1, 10, 100, -1)
const CMD_PICK: int = 1  ## a = draft offer slot, b = 0 (M4-15); logged by `SimWorld.command_pick`
const CMD_REROLL: int = 2  ## a = 0, b = 0 (R1-04); rerolls the open draft, logged by `SimWorld.command_reroll`

var ticks: PackedInt32Array = PackedInt32Array()
var kinds: PackedByteArray = PackedByteArray()
var arg_a: PackedInt32Array = PackedInt32Array()
var arg_b: PackedInt32Array = PackedInt32Array()


func size() -> int:
	return ticks.size()


func append(tick: int, kind: int, a: int, b: int) -> void:
	var failed: bool = ticks.append(tick)
	failed = kinds.append(kind) or failed
	failed = arg_a.append(a) or failed
	failed = arg_b.append(b) or failed
	if failed:
		push_error("InputLog: append failed")
