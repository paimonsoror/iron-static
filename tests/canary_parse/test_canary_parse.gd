class_name TestCanaryParse
extends GdUnitTestSuite
## Deliberate syntax error: proves tools/test_runner.py reports parse errors (exit 2).
## This folder has a .gdignore so Godot never loads it in the live project; `test.ps1 -Canary`
## materialises it inside a temporary project copy under build/canary/.


func test_never_runs() -> void:
	var broken: int = = 1
