class_name TestSmoke
extends GdUnitTestSuite
## Smoke suite proving GdUnit4 runs under the project's warnings-as-errors settings.


func test_truth() -> void:
	assert_int(1 + 1).is_equal(2)


func test_game_version_is_non_empty() -> void:
	assert_str(Game.VERSION).is_not_empty()
