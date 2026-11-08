class_name TresWriter
extends RefCounted
## Writes Godot text resources (.tres, format 3) by hand so the importer output is byte-identical on
## every run: fixed property order, fixed float formatting, no uid lines (ResourceSaver would mint a
## new uid for each fresh file), no absolute paths, no timestamps. Godot loads such files by path.

const FLOAT_DECIMALS: int = 12


## Float text with up to 12 decimals, trailing zeros trimmed, always containing a ".": 1.063, 52.0.
static func fmt_float(v: float) -> String:
	var s: String = ("%." + str(FLOAT_DECIMALS) + "f") % v
	if s.contains("."):
		s = s.rstrip("0")
		if s.ends_with("."):
			s += "0"
	if s == "-0.0":
		s = "0.0"
	return s


static func fmt_string(v: String) -> String:
	return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


static func fmt_value(v: Variant) -> String:
	match typeof(v):
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			var as_float: float = v
			return fmt_float(as_float)
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_STRING:
			var as_string: String = v
			return fmt_string(as_string)
	push_error("TresWriter: unsupported value type %d" % typeof(v))
	return "null"


## A resource whose script is `script_path` with the given properties (Dictionary keeps order).
static func resource_text(class_name_text: String, script_path: String, props: Dictionary) -> String:
	var out: String = '[gd_resource type="Resource" script_class="%s" format=3]\n\n' % class_name_text
	out += '[ext_resource type="Script" path="%s" id="1_script"]\n\n' % script_path
	out += '[resource]\nscript = ExtResource("1_script")\n'
	for key: String in props:
		out += "%s = %s\n" % [key, fmt_value(props[key])]
	return out


## An ordered table resource: `array_prop` is a typed array of `item_class` resources loaded from
## `item_paths` (in order).
static func table_text(
	class_name_text: String,
	script_path: String,
	array_prop: String,
	item_script_path: String,
	item_paths: PackedStringArray
) -> String:
	var out: String = '[gd_resource type="Resource" script_class="%s" format=3]\n\n' % class_name_text
	out += '[ext_resource type="Script" path="%s" id="1_script"]\n' % script_path
	out += '[ext_resource type="Script" path="%s" id="2_item"]\n' % item_script_path
	var refs: PackedStringArray = PackedStringArray()
	for i: int in item_paths.size():
		var rid: String = "item_%d" % i
		out += '[ext_resource type="Resource" path="%s" id="%s"]\n' % [item_paths[i], rid]
		refs.append_array(PackedStringArray(['ExtResource("%s")' % rid]))
	out += '\n[resource]\nscript = ExtResource("1_script")\n'
	out += '%s = Array[ExtResource("2_item")]([%s])\n' % [array_prop, ", ".join(refs)]
	return out
