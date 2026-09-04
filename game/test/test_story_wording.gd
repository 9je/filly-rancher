extends GutTest
## THE WORDS THAT CHANGE WITH THE CHAPTER. One state in the Compendium (PROCESSED) and one
## board, read differently as the player learns what she has been doing. The spec: "The same
## state; only the words change with the chapter."

const StoryScript := preload("res://systems/story.gd")
const WordingScript := preload("res://systems/story_wording.gd")


func test_every_chapter_has_a_word_for_a_delivered_pony() -> void:
	assert_eq(WordingScript.PROCESSED_LABELS.size(), StoryScript.Chapter.size())
	for chapter in range(StoryScript.Chapter.size()):
		assert_false(WordingScript.processed_label(chapter).is_empty(),
			"chapter %d has no word for it" % chapter)


func test_the_early_chapters_are_cheerful_and_never_grim() -> void:
	var early: String = WordingScript.processed_label(StoryScript.Chapter.SUNNY)
	assert_true(early.contains("Delivered"), "before she knows, it is a delivery")
	for chapter in range(StoryScript.Chapter.size()):
		var label: String = WordingScript.processed_label(chapter).to_lower()
		assert_false(label.contains("kill"))
		assert_false(label.contains("dead"))


func test_a_chapter_this_build_does_not_have_falls_back_rather_than_crashing() -> void:
	assert_eq(WordingScript.processed_label(-1),
		WordingScript.processed_label(StoryScript.Chapter.SUNNY))
	assert_eq(WordingScript.processed_label(99),
		WordingScript.processed_label(StoryScript.Chapter.RESISTANCE))


func test_the_pony_she_named_carries_her_star() -> void:
	var plain: String = WordingScript.processed_value(StoryScript.Chapter.WEATHER, false)
	var starred: String = WordingScript.processed_value(StoryScript.Chapter.WEATHER, true)
	assert_false(plain.contains(WordingScript.EMPLOYEES_CHOICE))
	assert_true(starred.contains(WordingScript.EMPLOYEES_CHOICE))
	assert_true(starred.begins_with(plain), "the star is added, never a replacement")


func test_no_wording_carries_a_dash() -> void:
	for chapter in range(StoryScript.Chapter.size()):
		for starred: bool in [false, true]:
			var line: String = WordingScript.processed_value(chapter, starred)
			assert_false(line.contains("--"))
			assert_false(line.contains(char(0x2014)))


func test_the_sunny_board_says_exactly_what_it_has_always_said() -> void:
	var board = preload("res://systems/request_board.gd")
	var story = preload("res://systems/story.gd")
	assert_eq(WordingScript.board_text(board.Kind.CATCH_ANY, story.Chapter.SUNNY, "", 1),
		"Catch a pony with your magic beam.")
	assert_eq(WordingScript.board_text(board.Kind.PEN_ANY, story.Chapter.SUNNY, "", 1),
		"Move a pony into a pen.")
	assert_eq(WordingScript.board_text(board.Kind.SELL_ANY, story.Chapter.SUNNY, "", 1),
		"Sell a gem at the market.")
	assert_eq(WordingScript.board_text(board.Kind.BRING_PERSONALITY_FROM_ZONE,
		story.Chapter.SUNNY, "shy pony from The Orchard", 1),
		"Bring a shy pony from The Orchard.")
	assert_eq(WordingScript.board_text(board.Kind.SELL_GEMS_OF_RARITY,
		story.Chapter.SUNNY, "common gems", 4), "Sell 4 common gems.")
	assert_eq(WordingScript.board_text(board.Kind.SEE_CHARACTER, story.Chapter.SUNNY,
		"Trixie", 1), "Find Trixie and get a good look at her.")


func test_every_kind_has_a_line_in_every_chapter_and_none_of_them_carries_a_dash() -> void:
	var board = preload("res://systems/request_board.gd")
	var story = preload("res://systems/story.gd")
	for kind in board.Kind.values():
		for chapter in range(story.Chapter.size()):
			var line: String = WordingScript.board_text(kind, chapter, "a shy pony", 3)
			assert_false(line.is_empty(), "kind %d has nothing to say in chapter %d"
				% [kind, chapter])
			assert_false(line.contains("{"), "an unfilled placeholder: %s" % line)
			assert_false(line.contains("--"))
			assert_false(line.contains(char(0x2014)))
			assert_false(line.to_lower().contains("kill"))


func test_the_same_request_reads_differently_once_the_weather_turns() -> void:
	var board = preload("res://systems/request_board.gd")
	var story = preload("res://systems/story.gd")
	var sunny: String = WordingScript.board_text(board.Kind.SEE_CHARACTER,
		story.Chapter.SUNNY, "Trixie", 1)
	var weather: String = WordingScript.board_text(board.Kind.SEE_CHARACTER,
		story.Chapter.WEATHER, "Trixie", 1)
	assert_ne(sunny, weather, "the board is chapter keyed or it is not")


func test_every_chapter_has_a_note_at_the_top_of_the_board() -> void:
	var story = preload("res://systems/story.gd")
	assert_eq(WordingScript.BOARD_NOTES.size(), story.Chapter.size())
	for chapter in range(story.Chapter.size()):
		assert_false(WordingScript.board_note(chapter).is_empty())
		assert_false(WordingScript.board_note(chapter).contains("--"))
