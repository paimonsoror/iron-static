class_name RecordSection
extends RefCounted
## One block of the Service Record screen: a heading and label / value rows (display text, already formatted).

var title: String = ""
var labels: PackedStringArray = PackedStringArray()
var values: PackedStringArray = PackedStringArray()


func _init(heading_text: String = "") -> void:
	title = heading_text


func add(label_text: String, value_text: String) -> void:
	@warning_ignore("return_value_discarded")
	labels.append(label_text)
	@warning_ignore("return_value_discarded")
	values.append(value_text)


func size() -> int:
	return labels.size()
