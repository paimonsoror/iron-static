# fixture: path=src/sim/bad_node.gd expect=layer-forbidden-api
class_name BadNode


func make() -> void:
	var n := Node.new()
