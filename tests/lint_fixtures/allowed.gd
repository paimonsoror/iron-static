# fixture: path=src/sim/allowed.gd expect=clean
class_name Allowed
# Mentions Node in a comment only and "Game" in a string.


func s() -> String:
	var n: Object = Node.new() # lint-allow: layer test-only reason
	return "Game"
