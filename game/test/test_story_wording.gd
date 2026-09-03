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
