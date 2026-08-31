extends GutTest

const PlayerLookScript := preload("res://systems/player_look.gd")
const MarkPaintScript := preload("res://systems/mark_paint.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")


func test_the_default_look_is_twilight_with_a_blank_mark() -> void:
	var look: PlayerLook = PlayerLookScript.default_look()
	assert_eq(look.player_name, PlayerLookScript.DEFAULT_NAME)
	assert_false(look.has_mark())
	assert_true(MarkPaintScript.is_blank(look.mark()))


func test_a_name_is_trimmed_collapsed_and_capped() -> void:
	assert_eq(PlayerLookScript.sanitize_name("  Moon   beam  "), "Moon beam")
	assert_eq(PlayerLookScript.sanitize_name("W".repeat(80)).length(),
		PlayerLookScript.MAX_NAME_LENGTH)
	assert_eq(PlayerLookScript.sanitize_name(""), PlayerLookScript.DEFAULT_NAME)
	assert_eq(PlayerLookScript.sanitize_name("   "), PlayerLookScript.DEFAULT_NAME)


func test_a_name_may_not_carry_a_dash_of_any_kind() -> void:
	# It is interpolated into every Company letter, so the project's copy rule reaches it.
	assert_false(PlayerLookScript.sanitize_name("Moon--beam").contains("-"))
	assert_false(PlayerLookScript.sanitize_name("Moon" + char(0x2014) + "beam")
		.contains(char(0x2014)))
	assert_eq(PlayerLookScript.sanitize_name("Moon-beam"), "Moonbeam")


func test_a_name_drops_control_characters() -> void:
	assert_eq(PlayerLookScript.sanitize_name("Moon\nbeam\t"), "Moon beam")


func test_a_drawn_mark_round_trips_pixel_identical_through_base64_png() -> void:
	var look: PlayerLook = PlayerLookScript.default_look()
	var drawn: Image = MarkStampsScript.build(MarkStampsScript.Stamp.APPLE, Color(0.9, 0.2, 0.2))
	MarkPaintScript.stroke(drawn, Vector2i(2, 60), Vector2i(60, 2), Color(0.1, 0.3, 0.8), 2)
	look.set_mark(drawn)
	assert_true(look.has_mark())
	var back: PlayerLook = PlayerLookScript.from_dict(look.to_dict())
	assert_true(MarkPaintScript.equal(back.mark(), drawn),
		"every pixel she drew comes back exactly as she drew it")


func test_a_blank_mark_is_stored_as_nothing_rather_than_as_a_blank_png() -> void:
	var look: PlayerLook = PlayerLookScript.default_look()
	assert_eq(String(look.to_dict()["mark_png"]), "",
		"a save should not carry four kilobytes of transparent pixels")


func test_the_whole_look_round_trips() -> void:
	var look: PlayerLook = PlayerLookScript.default_look()
	look.player_name = "Moonbeam"
	look.coat = 7
	look.mane = 11
	look.eyes = 2
	look.mane_style = 1
	var back: PlayerLook = PlayerLookScript.from_dict(look.to_dict())
	assert_eq(back.player_name, "Moonbeam")
	assert_eq(back.coat, 7)
	assert_eq(back.mane, 11)
	assert_eq(back.eyes, 2)
	assert_eq(back.mane_style, 1)


func test_an_empty_dictionary_is_the_default_look() -> void:
	var back: PlayerLook = PlayerLookScript.from_dict({})
	assert_eq(back.player_name, PlayerLookScript.DEFAULT_NAME)
	assert_eq(back.coat, PlayerLookScript.DEFAULT_COAT)


func test_a_corrupt_mark_loads_as_a_blank_one_rather_than_failing_the_save() -> void:
	var back: PlayerLook = PlayerLookScript.from_dict({"mark_png": "not base64 at all"})
	# The one push_warning from_dict() is documented to raise for exactly this case -- see
	# player_look.gd's class comment ("A MARK THAT WILL NOT DECODE IS DROPPED, not fatal").
	# Acknowledged rather than left unexpected, the way test_request_board.gd's from_array
	# drop warning is.
	assert_engine_error(1, "a corrupt mark must be reported with push_warning, not silently")
	assert_false(back.has_mark())
	assert_true(MarkPaintScript.is_blank(back.mark()))
	assert_eq(back.player_name, PlayerLookScript.DEFAULT_NAME,
		"one bad field must not cost her the rest of her pony")


func test_the_mark_is_handed_out_as_a_copy() -> void:
	var look: PlayerLook = PlayerLookScript.default_look()
	var taken: Image = look.mark()
	MarkPaintScript.dot(taken, Vector2i(1, 1), Color.RED, 0)
	assert_true(MarkPaintScript.is_blank(look.mark()))
