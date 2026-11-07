# fixture: path=src/meta/bad_random.gd expect=layer-forbidden-api
class_name BadRandom


func roll() -> float:
	return randf()
