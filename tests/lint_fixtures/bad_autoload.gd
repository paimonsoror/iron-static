# fixture: path=src/sim/bad_autoload.gd expect=layer-autoload
class_name BadAutoload


func v() -> String:
	return Game.VERSION
