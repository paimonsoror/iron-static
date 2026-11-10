class_name JourneySpend
extends RefCounted
## Between-deployment Foundry spending policies for the journey tool (FO-2). Every policy spends through the real
## `FoundryService` (costs, caps, `FoundryRules.recommended`), one level at a time, until the policy's pick is not
## affordable (it then saves the Data) or nothing is left to buy.
##   cheapest     the row with the cheapest next level (ties: first row)
##   laser        all-in `laser_output`; only at its level cap (Option C prototype) the Data goes to the cheapest row
##   recommended  mirrors the Foundry glow (`FoundryRules.recommended`, FoundryRowView.recommended): a Type D row at
##                most 3 levels from its x1.25 milestone, else the cheapest affordable row. Buys only the glowing row;
##                when it glows on a row the player cannot afford yet, the player waits (no fallback purchase).
##   roundrobin   rows in Foundry order, one level each, skipping maxed rows; waits when the next row is unaffordable
##   none         never spends

var policy: String = "cheapest"
var _next_row: int = 0


func _init(policy_name: String = "cheapest") -> void:
	policy = policy_name


## Spends `profile.data` as far as the policy goes. Returns the number of levels bought.
func spend(profile: PlayerProfile, service: FoundryService) -> int:
	var bought: int = 0
	for _guard: int in range(100000):
		var rows: Array[FoundryRowView] = service.rows(profile)
		var pick: int = _pick(rows)
		if pick < 0:
			break
		var row: FoundryRowView = rows[pick]
		if row.maxed or not row.affordable:
			break
		if service.buy(profile, row.id, 1) == 0:
			break
		bought += 1
		_next_row = (pick + 1) % rows.size()
	return bought


func _pick(rows: Array[FoundryRowView]) -> int:
	match policy:
		"laser":
			return _laser(rows)
		"recommended":
			return _recommended(rows)
		"roundrobin":
			return _round_robin(rows)
		"cheapest":
			return _cheapest(rows)
	return -1


## `laser_output` while it is below its level cap; at the cap (Option C prototype) the cheapest other row.
func _laser(rows: Array[FoundryRowView]) -> int:
	for i: int in rows.size():
		if rows[i].id == "laser_output" and not rows[i].maxed:
			return i
	return _cheapest(rows)


func _recommended(rows: Array[FoundryRowView]) -> int:
	for i: int in rows.size():
		if rows[i].recommended:
			return i
	return -1


func _round_robin(rows: Array[FoundryRowView]) -> int:
	for k: int in rows.size():
		var i: int = (_next_row + k) % rows.size()
		if not rows[i].maxed:
			return i
	return -1


func _cheapest(rows: Array[FoundryRowView]) -> int:
	var best: int = -1
	for i: int in rows.size():
		if rows[i].maxed:
			continue
		if best < 0 or rows[i].cost.lt(rows[best].cost):
			best = i
	return best
