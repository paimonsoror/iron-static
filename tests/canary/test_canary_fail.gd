class_name TestCanaryFail
extends GdUnitTestSuite
## Always fails: proves tools/test_runner.py reports test failures (exit 1). Run via `test.ps1 -Canary`.


func test_always_fails() -> void:
	assert_bool(true).is_false()
