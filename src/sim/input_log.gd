class_name InputLog
extends RefCounted
## Player commands of one run as parallel packed arrays: (tick, kind, a, b). Appended by
## `SimWorld.command_buy`. A command logged at tick T is applied before `step()` runs tick T, in live play
## and in replay alike (`world.tick` is the tick about to run, so recording `world.tick` is the rule).
## (impl) Only accepted commands are logged: a rejected buy changes no state, so replay is unaffected.

const CMD_BUY: int = 0  ## a = upgrade row index, b = count requested (1, 10, 100, -1)

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
