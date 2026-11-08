class_name NumberSuffixTable
extends Resource
## Number suffix ladder generated from data/number_suffixes.csv by the importer: `suffixes[i]` is the suffix of
## 10^`exps[i]`. Shipped in the export because data/ is `.gdignore`d and its CSVs never reach the APK.

@export var exps: PackedInt32Array = PackedInt32Array()
@export var suffixes: PackedStringArray = PackedStringArray()
