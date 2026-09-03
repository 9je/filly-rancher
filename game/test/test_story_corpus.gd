extends GutTest
## THE SHIPPED LETTERS THEMSELVES. Everything in game/data/story/ is checked here as a body
## of writing: it fits the panel, it names a chapter and a trigger this build has, it never
## says the word this project does not use, and it never carries a dash. The gate
## (game/scenes/test/story_test.gd) repeats the structural half against the real ranch; this
## is the fast one that runs on every commit.

const StoryScript := preload("res://systems/story.gd")
const StoryBeatScript := preload("res://systems/story_beat.gd")
const StoryLibraryScript := preload("res://systems/story_library.gd")
const LettersScript := preload("res://systems/letters.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")

const PONY_DIR := "res://data/ponies"

var _library: StoryLibrary


func before_each() -> void:
	_library = StoryLibraryScript.new()
	_library.load_all()


## The widest name the creation screen accepts, in the widest glyph, and the longest pony
## name a receipt can carry. Every letter has to fit with both in it.
func _worst_params() -> Dictionary:
	return {
		"name": "W".repeat(LettersScript.MAX_NAME_LENGTH),
		"pony": "Wwwwwwwwwwwwwwww",
		"colour": "viridian",
		"count": 999,
		"quota": 12,
		"balance": 40000,
	}


func test_the_corpus_is_not_empty_and_every_id_is_unique() -> void:
	var beats: Array[StoryBeat] = _library.all()
	assert_gt(beats.size(), 12, "SUNNY, WEATHER and the Company ladder are all authored")
	var seen := {}
	for beat: StoryBeat in beats:
		assert_false(seen.has(beat.id), "duplicate id %s" % String(beat.id))
		seen[beat.id] = true


func test_every_beat_names_a_chapter_a_trigger_and_a_reply_this_build_has() -> void:
	for beat: StoryBeat in _library.all():
		assert_gte(beat.chapter_index(), 0, "%s: unknown chapter %s" % [beat.id, beat.chapter])
		assert_gte(beat.trigger_index(), 0, "%s: unknown trigger %s" % [beat.id, beat.trigger])
		assert_gte(beat.reply_index(), 0, "%s: unknown reply %s" % [beat.id, beat.reply])
		assert_gte(beat.threshold, 0, "%s: a negative threshold can never be met" % beat.id)


func test_every_beat_has_a_sender_a_title_and_a_body() -> void:
	for beat: StoryBeat in _library.all():
		assert_false(beat.sender.is_empty(), "%s has no sender" % beat.id)
		assert_false(beat.title.is_empty(), "%s has no title" % beat.id)
		assert_gt(beat.body_lines().size(), 2, "%s is not a letter" % beat.id)


func test_no_beat_carries_an_em_dash_or_a_double_hyphen() -> void:
	for beat: StoryBeat in _library.all():
		var letter: Dictionary = beat.render(_worst_params())
		var joined: String = String(letter["title"]) + "\n" + "\n".join(letter["body"])
		assert_false(joined.contains("--"), "%s carries a double hyphen" % beat.id)
		assert_false(joined.contains(char(0x2014)), "%s carries an em dash" % beat.id)


func test_no_beat_uses_the_word_this_project_does_not_use() -> void:
	for beat: StoryBeat in _library.all():
		var letter: Dictionary = beat.render(_worst_params())
		var joined: String = (String(letter["title"]) + "\n"
			+ "\n".join(letter["body"])).to_lower()
		assert_false(joined.contains("killed"), "%s says it out loud" % beat.id)
		assert_false(joined.contains("kill"), "%s says it out loud" % beat.id)
		assert_false(joined.contains("dead"), "%s says it out loud" % beat.id)


func test_every_letter_fits_the_panel_with_the_longest_legal_name_in_it() -> void:
	for beat: StoryBeat in _library.all():
		var letter: Dictionary = beat.render(_worst_params())
		for line in letter["body"]:
			assert_lte(String(line).length(), LettersScript.LINE_WIDTH,
				"%s overflows on '%s'" % [beat.id, line])


func test_no_letter_renders_an_unfilled_placeholder() -> void:
	for beat: StoryBeat in _library.all():
		var letter: Dictionary = beat.render({})
		var joined: String = String(letter["title"]) + "\n" + "\n".join(letter["body"])
		assert_false(joined.contains("{"), "%s has a placeholder nothing fills" % beat.id)


func test_every_revealed_id_is_a_character_this_build_carries() -> void:
	var registry = PonyRegistryScript.new()
	registry.load_all(PONY_DIR)
	for beat: StoryBeat in _library.all():
		for revealed in beat.reveals:
			assert_not_null(registry.by_id(StringName(String(revealed))),
				"%s reveals '%s', who is not on the roster" % [beat.id, revealed])


func test_each_chapter_opens_with_something_to_read() -> void:
	var openers := {}
	for beat: StoryBeat in _library.all():
		if beat.trigger_index() == StoryScript.Trigger.CHAPTER and beat.threshold == 0:
			openers[beat.chapter_index()] = true
	assert_true(openers.has(StoryScript.Chapter.SUNNY), "SUNNY opens with a letter")
	assert_true(openers.has(StoryScript.Chapter.WEATHER), "WEATHER opens with a letter")


func test_a_fresh_ranch_is_owed_exactly_the_opening_letter() -> void:
	var story = StoryScript.new()
	var owed: Array[StoryBeat] = _library.due(story)
	assert_eq(owed.size(), 1, "one letter on the doormat, not five")
	assert_eq(owed[0].id, &"sunny_mailbox")


func test_the_first_five_sessions_each_bring_at_least_one_letter() -> void:
	# A session, per the spec's Pacing section: three cycles, one collection day, a handful
	# of deliveries, one of them named every other session.
	var story = StoryScript.new()
	for beat: StoryBeat in _library.due(story):
		story.post(beat.id)
	for session in range(1, 6):
		story.note_delivery(false, "Pony", &"")
		story.note_delivery(session % 2 == 1, "Trixie", &"trixie")
		story.note_collection_day()
		story.advance()
		var owed: Array[StoryBeat] = _library.due(story)
		assert_gt(owed.size(), 0, "session %d brought no post at all" % session)
		for beat: StoryBeat in owed:
			story.post(beat.id)


func test_the_survey_is_the_first_thing_weather_puts_in_the_mailbox() -> void:
	var story = StoryScript.new()
	for i in range(StoryScript.WEATHER_DELIVERIES):
		story.note_delivery(false, "Pony", &"")
	assert_true(story.advance())
	var owed: Array[StoryBeat] = _library.due(story)
	var ids: Array[StringName] = []
	for beat: StoryBeat in owed:
		ids.append(beat.id)
	assert_true(&"weather_survey" in ids, "the chapter that starts the crack starts it")


func test_the_requisition_never_comes_due_until_the_survey_is_answered() -> void:
	var story = StoryScript.new()
	for i in range(StoryScript.WEATHER_DELIVERIES):
		story.note_delivery(false, "Pony", &"")
	story.advance()
	for i in range(20):
		story.note_collection_day()
		for beat: StoryBeat in _library.due(story):
			assert_ne(beat.id, &"weather_requisition",
				"an unanswered Survey never fires the beat")
			story.post(beat.id)


func test_answering_the_survey_brings_the_requisition_two_collection_days_later() -> void:
	var story = StoryScript.new()
	for i in range(StoryScript.WEATHER_DELIVERIES):
		story.note_delivery(false, "Pony", &"")
	story.advance()
	for beat: StoryBeat in _library.due(story):
		story.post(beat.id)
	story.answer_survey({"uid": "u1", "data_id": "trixie", "name": "Trixie", "coat": ""})
	story.note_collection_day()
	var ids_after_one: Array[StringName] = []
	for beat: StoryBeat in _library.due(story):
		ids_after_one.append(beat.id)
	assert_false(&"weather_requisition" in ids_after_one, "not the very next morning")
	story.note_collection_day()
	var ids_after_two: Array[StringName] = []
	for beat: StoryBeat in _library.due(story):
		ids_after_two.append(beat.id)
	assert_true(&"weather_requisition" in ids_after_two, "some collection days later")


func test_the_survey_is_the_only_letter_in_this_slice_that_asks_for_an_answer() -> void:
	for beat: StoryBeat in _library.all():
		if beat.chapter_index() > StoryScript.Chapter.WEATHER:
			continue
		if beat.reply_index() == StoryBeatScript.Reply.NONE:
			continue
		assert_eq(beat.id, &"weather_survey",
			"%s asks a question nothing in this slice can answer" % beat.id)
		assert_eq(beat.reply_index(), StoryBeatScript.Reply.PICK_PONY)


func test_the_requisition_and_the_colour_receipt_name_the_pony_they_are_about() -> void:
	var requisition: StoryBeat = _library.by_id(&"weather_requisition")
	assert_not_null(requisition)
	assert_true("\n".join(requisition.body_lines()).contains("{pony}"))
	var receipt: StoryBeat = _library.by_id(&"weather_colour_receipt")
	assert_not_null(receipt)
	var receipt_body: String = "\n".join(receipt.body_lines())
	assert_true(receipt_body.contains("{pony}"))
	assert_true(receipt_body.contains("{colour}"),
		"the receipt that lists her beside a colour")


func test_the_company_ladder_is_authored_and_unreachable_in_this_slice() -> void:
	var story = StoryScript.new()
	for i in range(200):
		story.note_delivery(true, "Trixie", &"trixie")
		story.note_collection_day()
		story.advance()
	assert_eq(story.chapter, StoryScript.Chapter.WEATHER, "the ladder stops here for now")
	for beat: StoryBeat in _library.due(story):
		assert_lte(beat.chapter_index(), StoryScript.Chapter.WEATHER)
	var ladder := 0
	for beat: StoryBeat in _library.all():
		if beat.chapter_index() == StoryScript.Chapter.COMPANY:
			ladder += 1
	assert_gte(ladder, 4, "the Company's letters are written and waiting for slice 4")
