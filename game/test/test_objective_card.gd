extends GutTest
## THE OBJECTIVE CARD (game/ui/objective_card.gd): the story's next step under the compass,
## its icon in the guide's gold ring, a few words and how far (owner playtest 2026-10-25:
## "idk what to do anymore").

const CardScript := preload("res://ui/objective_card.gd")


func _card() -> Control:
	var c: Control = CardScript.new()
	add_child_autofree(c)
	return c


func test_it_shows_the_words_and_the_distance() -> void:
	var c := _card()
	c.call("show_objective", {"id": &"deliver", "goal": &"depot", "icon": PlaceSign.Icon.CRATE,
		"words": "Deliver ponies 2/6"}, 41.6)
	assert_true(c.visible)
	assert_eq(String(c.call("words")), "Deliver ponies 2/6")
	assert_eq(String(c.call("distance_text")), "42 m")


func test_a_wait_has_no_distance_and_nothing_hides_it() -> void:
	var c := _card()
	c.call("show_objective", {"id": &"wait", "goal": &"", "icon": PlaceSign.Icon.HOUSE,
		"words": "Color Day comes at dawn"}, -1.0)
	assert_eq(String(c.call("distance_text")), "")
	c.call("show_objective", {}, -1.0)
	assert_false(c.visible, "no objective, no card")


func test_close_by_it_says_here() -> void:
	var c := _card()
	c.call("show_objective", {"id": &"pen", "goal": &"pens", "icon": PlaceSign.Icon.FENCE,
		"words": "Pen the ponies you carry"}, 2.0)
	assert_eq(String(c.call("distance_text")), "here")


func test_a_new_objective_slides_in() -> void:
	var c := _card()
	c.call("show_objective", {"id": &"a", "goal": &"", "icon": 0, "words": "One two three"}, -1.0)
	await wait_frames(30)
	c.call("show_objective", {"id": &"b", "goal": &"", "icon": 0, "words": "Four five six"}, -1.0)
	assert_lt(c.modulate.a, 1.0, "fading in")
