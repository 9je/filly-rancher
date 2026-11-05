extends GutTest
## THE SHOW'S PUPIL (systems/eye_frame.gd, shaders/pony_eye.gdshader). A PonySFM eye texture
## draws a pupil that fills nearly the whole iris, so on screen a pony looked out through two
## black discs ringed in colour. The show draws a big coloured iris and a pupil about half its
## width; tools/show_pupils.py redraws every eye that way, and EyeFrame measures them.
## (Idea from home-equestria's iris shader; owner 2026-11-05: "i like faces and eye improvements".)

const EyeFrameScript := preload("res://systems/eye_frame.gd")


## White sclera, a coloured disc of `disc` radius and a black pupil of `pupil` radius about
## `at` (UV), plus a white highlight inside the pupil.
func _eye(at: Vector2, disc: Vector2, pupil: Vector2) -> Image:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var uv := Vector2((x + 0.5) / n, (y + 0.5) / n)
			var c := Color.WHITE
			if ((uv - at) / disc).length() <= 1.0:
				c = Color(0.9, 0.5, 0.2)
			if ((uv - at) / pupil).length() <= 1.0:
				c = Color.BLACK
			if (uv - at - pupil * Vector2(0.4, -0.4)).length() < pupil.x * 0.2:
				c = Color.WHITE
			img.set_pixel(x, y, c)
	return img


func test_it_finds_the_pupil_and_the_iris_of_a_drawn_eye() -> void:
	var f: Dictionary = EyeFrameScript.measure(_eye(Vector2(0.55, 0.5), Vector2(0.3, 0.4), Vector2(0.24, 0.33)))
	assert_false(f.is_empty())
	assert_almost_eq((f.pupil_centre as Vector2).x, 0.55, 0.02)
	assert_almost_eq((f.pupil_centre as Vector2).y, 0.5, 0.02)
	assert_almost_eq((f.pupil_radius as Vector2).x, 0.24, 0.02)
	assert_almost_eq((f.pupil_radius as Vector2).y, 0.33, 0.02)
	assert_almost_eq((f.disc_radius as Vector2).x, 0.3, 0.02)
	assert_almost_eq((f.disc_radius as Vector2).y, 0.4, 0.02)


func test_the_highlight_inside_the_pupil_does_not_shrink_it() -> void:
	var f: Dictionary = EyeFrameScript.measure(_eye(Vector2(0.5, 0.5), Vector2(0.3, 0.3), Vector2(0.2, 0.2)))
	assert_almost_eq((f.pupil_radius as Vector2).x, 0.2, 0.02)


func test_an_eye_with_no_pupil_gives_nothing_to_remap() -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.6, 0.9))
	assert_true(EyeFrameScript.measure(img).is_empty())


func test_it_measures_a_drawn_pupil_s_share_of_the_iris() -> void:
	var share := EyeFrameScript.pupil_share(_eye(Vector2(0.5, 0.5), Vector2(0.3, 0.3), Vector2(0.27, 0.27)))
	assert_almost_eq(share, 0.9, 0.05)


func test_every_eye_the_roster_ships_has_the_show_s_pupil() -> void:
	var dir := "res://assets/converted/ponies"
	var checked := 0
	for f in DirAccess.get_files_at(dir):
		if not (f.ends_with("_pupil_l.png") or f.ends_with("_pupil_r.png") or f.ends_with("_Eye.png")
				or f.ends_with("_Eye_R.png")):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s" % [dir, f]))
		var share := EyeFrameScript.pupil_share(img)
		assert_gt(share, 0.0, "%s: no pupil found" % f)
		assert_lte(share, EyeFrameScript.SHOW_PUPIL + 0.06, "%s: the pupil fills the iris" % f)
		checked += 1
	assert_gt(checked, 70, "the roster's eyes were found")
