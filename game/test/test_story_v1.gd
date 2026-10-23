extends GutTest
## The v1 story layer (game/systems/story_v1.gd): the path is chosen once, the chapter moves
## onto it, the ending input reads the right tallies, and the dread dial moves the way
## STORY.md section 9 says (cozy, creeping, then by path).

const StoryScript := preload("res://systems/story.gd")
const StoryV1Script := preload("res://systems/story_v1.gd")
const BookScript := preload("res://systems/pony_book.gd")
const EndingsScript := preload("res://systems/endings.gd")


func test_the_path_is_chosen_once_and_moves_the_chapter() -> void:
	var s := StoryScript.new()
	assert_false(StoryV1Script.revealed(s))
	StoryV1Script.choose_path(s, "rescue")
	assert_eq(StoryV1Script.path(s), "rescue")
	assert_eq(s.chapter, StoryScript.Chapter.RESISTANCE)
	StoryV1Script.choose_path(s, "factory")
	assert_eq(StoryV1Script.path(s), "rescue", "the fork is once per save")


func test_dread_is_cozy_then_creeps_then_follows_the_path() -> void:
	var s := StoryScript.new()
	var b := BookScript.new()
	assert_eq(StoryV1Script.dread(s, b), 0.0, "Act One is cozy")
	s.chapter = StoryScript.Chapter.WEATHER
	var a2 := StoryV1Script.dread(s, b)
	assert_between(a2, 0.04, 0.25)
	s.deliveries = 6
	assert_gt(StoryV1Script.dread(s, b), a2, "Act Two creeps with deliveries")
	var f := StoryScript.new()
	StoryV1Script.choose_path(f, "factory")
	var f0 := StoryV1Script.dread(f, b)
	for i in 5:
		b.note_delivery("u%d" % i, "P", PonyLook.new(), 1, true)
	assert_gt(StoryV1Script.dread(f, b), f0, "every pony sent up after the reveal greys the valley")
	var r := StoryScript.new()
	StoryV1Script.choose_path(r, "rescue")
	var r0 := StoryV1Script.dread(r, BookScript.new())
	r.set_var("pylons_cut", 2)
	assert_lt(StoryV1Script.dread(r, BookScript.new()), r0, "every pylon cut brings colour back")


func test_the_ending_input_feeds_the_selector() -> void:
	var s := StoryScript.new()
	var b := BookScript.new()
	StoryV1Script.choose_path(s, "rescue")
	s.set_var("rescued", 22)
	for f in StoryV1Script.ALLIES:
		s.set_flag(f)
	s.set_flag("clover_rescued")
	s.set_flag("climax_done")
	assert_eq(EndingsScript.select(StoryV1Script.ending_input(s, b)), EndingsScript.LIGHTS_OUT)
	for i in 3:
		b.note_delivery("u%d" % i, "P", PonyLook.new(), 1, true)
	assert_eq(EndingsScript.select(StoryV1Script.ending_input(s, b)), EndingsScript.HALF_LIGHT,
		"caving three times after the reveal costs the good ending")
