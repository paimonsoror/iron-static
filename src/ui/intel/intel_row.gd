class_name IntelRow
extends RefCounted
## One line of the Intel Stats panel (M4-18): stat name, final value text and the chain text that explains it.

var id: String = ""
var name_text: String = ""
var value_text: String = ""
var chain_text: String = ""


func _init(p_id: String = "", p_name: String = "", p_value: String = "", p_chain: String = "") -> void:
	id = p_id
	name_text = p_name
	value_text = p_value
	chain_text = p_chain
