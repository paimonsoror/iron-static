class_name PowerRating
extends RefCounted
## Power Rating helpers (GDD 06 section 5). `PR = 10 * log10(ref_dmg * ref_ehp)`; level-0 stats give about 32.


## laser_output * cycle_rate * (1 + crit_chance * (crit_mult - 1)).
static func ref_dmg(s: StatBlock) -> float:
	return s.laser_output * s.cycle_rate * (1.0 + s.crit_chance * (s.crit_mult - 1.0))


## (hull_integrity + 60 * nano_repair + plating_flat) / (1 - plating_pct).
static func ref_ehp(s: StatBlock) -> float:
	return (s.hull_integrity + 60.0 * s.nano_repair + s.plating_flat) / (1.0 - s.plating_pct)


## ref_dmg * ref_ehp, the quantity the PolicyBot maximizes per scrap.
static func score(s: StatBlock) -> float:
	return ref_dmg(s) * ref_ehp(s)


static func power_rating(s: StatBlock) -> float:
	var product: float = score(s)
	if product <= 0.0:
		return 0.0
	return 10.0 * log(product) / log(10.0)
