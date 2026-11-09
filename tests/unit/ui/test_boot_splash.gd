class_name TestBootSplash
extends GdUnitTestSuite
## Custom boot splash: the project points at the logo image on the game's void black, unscaled, under 400 KB.


func test_boot_splash_settings() -> void:
	var path: String = ProjectSettings.get_setting("application/boot_splash/image", "")
	assert_str(path).is_equal("res://assets/splash/splash.png")
	assert_bool(ResourceLoader.exists(path)).is_true()
	var bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.WHITE)
	assert_bool(bg.is_equal_approx(Palette.VOID)).is_true()
	assert_int(ProjectSettings.get_setting("application/boot_splash/stretch_mode", -1)).is_equal(0)
	var tex: Texture2D = load(path) as Texture2D
	assert_int(tex.get_width()).is_less_equal(1080)


func test_splash_image_is_small_and_matches_the_background() -> void:
	var f: FileAccess = FileAccess.open("res://assets/splash/splash.png", FileAccess.READ)
	assert_int(f.get_length()).is_less(400 * 1024)
	var img: Image = (load("res://assets/splash/splash.png") as Texture2D).get_image()
	assert_bool(img.get_pixel(2, 2).is_equal_approx(Palette.VOID)).is_true()
