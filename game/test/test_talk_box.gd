extends GutTest
## THE SPEECH BUBBLE FITS ITS LINE (bot frames 2026-11-05: Tumble's "Yay!" sat in a bubble
## built for a paragraph). A short line gets a bubble as wide as it needs, never narrower
## than SHORT_MIN_WIDTH; a long line, or one with choices, keeps the full width.

const TalkBoxScript := preload("res://ui/talk_box.gd")


func _box() -> CanvasLayer:
	var b: CanvasLayer = TalkBoxScript.new()
	add_child_autofree(b)
	return b


func _width(b: CanvasLayer) -> float:
	return (b.get("_panel") as Control).custom_minimum_size.x


func test_a_one_word_line_gets_a_small_bubble() -> void:
	var b := _box()
	b.call("show_line", {"who_name": "Tumble", "text": "Yay!"}, null, Color.WHITE)
	assert_lt(_width(b), TalkBoxScript.MIN_WIDTH)
	assert_gte(_width(b), TalkBoxScript.SHORT_MIN_WIDTH)


func test_a_long_line_keeps_the_full_bubble() -> void:
	var b := _box()
	b.call("show_line", {"who_name": "Marigold", "text": "Welcome, welcome! You must be Twilight. I'm Marigold Mayfair, Cloudsdale Weather Corporation, Regional Liaison."}, null, Color.WHITE)
	assert_eq(_width(b), TalkBoxScript.MIN_WIDTH)


func test_a_line_with_choices_keeps_the_full_bubble() -> void:
	var b := _box()
	b.call("show_line", {"who_name": "Tumble", "text": "Ready?", "choices": ["Yes", "Not yet"]}, null, Color.WHITE)
	assert_eq(_width(b), TalkBoxScript.MIN_WIDTH)
