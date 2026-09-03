extends GutTest
## The saved story: a chapter, a flag set, four counters the game already emits, and the
## mail log. No scene, no clock, no RNG, so the whole of it runs in milliseconds.

const StoryScript := preload("res://systems/story.gd")


func test_a_new_story_starts_sunny_with_nothing_read() -> void:
	var story = StoryScript.new()
	assert_eq(story.chapter, StoryScript.Chapter.SUNNY)
	assert_eq(story.deliveries, 0)
	assert_eq(story.named_deliveries, 0)
	assert_eq(story.collection_days, 0)
	assert_eq(story.mail_ids().size(), 0)
	assert_eq(story.unread_count(), 0)
	assert_false(story.survey_answered())


func test_the_counters_are_the_ones_the_game_already_emits() -> void:
	var story = StoryScript.new()
	story.note_delivery(false, "Pony", &"")
	story.note_delivery(true, "Trixie", &"trixie")
	story.note_collection_day()
	assert_eq(story.counter(StoryScript.Trigger.DELIVERIES), 2)
	assert_eq(story.counter(StoryScript.Trigger.NAMED_DELIVERIES), 1)
	assert_eq(story.counter(StoryScript.Trigger.COLLECTION_DAYS), 1)
	assert_eq(story.counter(StoryScript.Trigger.CHAPTER), 0,
		"CHAPTER is the trigger that fires on arrival, so its counter is always met")


func test_a_named_delivery_is_remembered_for_the_receipt_that_names_her() -> void:
	var story = StoryScript.new()
	story.note_delivery(true, "Trixie", &"trixie")
	assert_eq(String(story.last_named.get("name", "")), "Trixie")
	assert_false(String(story.last_named.get("colour", "")).is_empty())


func test_the_spectra_colour_is_a_function_of_the_id_and_never_rolls() -> void:
	var first: String = StoryScript.spectra_colour(&"trixie")
	var again: String = StoryScript.spectra_colour(&"trixie")
	assert_eq(first, again, "the same pony is always the same colour on the receipt")
	assert_true(first in StoryScript.SPECTRA_COLOURS)


func test_the_ladder_climbs_sunny_to_weather_on_deliveries_and_stops_there() -> void:
	var story = StoryScript.new()
	var moved: Array[int] = []
	story.chapter_changed.connect(func(c: int) -> void: moved.append(c))
	for i in range(StoryScript.WEATHER_DELIVERIES - 1):
		story.note_delivery(false, "Pony", &"")
		assert_false(story.advance(), "not yet: %d deliveries" % story.deliveries)
	story.note_delivery(false, "Pony", &"")
	assert_true(story.advance(), "the third delivery turns the chapter")
	assert_eq(story.chapter, StoryScript.Chapter.WEATHER)
	assert_eq(moved, [StoryScript.Chapter.WEATHER] as Array[int])
	for i in range(40):
		story.note_delivery(true, "Trixie", &"trixie")
		story.note_collection_day()
	assert_false(story.advance(), "slice 3's ladder ends at WEATHER")
	assert_eq(story.chapter, StoryScript.Chapter.WEATHER)


func test_mail_is_posted_once_kept_forever_and_read_state_sticks() -> void:
	var story = StoryScript.new()
	assert_true(story.post(&"sunny_mailbox"))
	assert_false(story.post(&"sunny_mailbox"), "a beat is posted exactly once")
	assert_true(story.has_mail(&"sunny_mailbox"))
	assert_eq(story.unread_count(), 1)
	assert_true(story.mark_read(&"sunny_mailbox"))
	assert_false(story.mark_read(&"sunny_mailbox"), "reading twice changes nothing")
	assert_eq(story.unread_count(), 0)
	assert_true(story.is_read(&"sunny_mailbox"))
	assert_true(story.post(&"weather_survey"))
	assert_eq(story.mail_ids(), [&"sunny_mailbox", &"weather_survey"] as Array[StringName],
		"mail is kept forever, in the order it arrived")


func test_answering_the_survey_stamps_the_choice_and_the_period() -> void:
	var story = StoryScript.new()
	story.note_collection_day()
	story.post(&"weather_survey")
	assert_true(story.answer_survey({"uid": "u1", "data_id": "trixie", "name": "Trixie",
		"coat": ""}))
	assert_true(story.survey_answered())
	assert_eq(String(story.survey_choice.get("name", "")), "Trixie")
	assert_eq(story.survey_period, 1)
	assert_eq(story.counter(StoryScript.Trigger.SURVEY_DAYS), 0)
	story.note_collection_day()
	story.note_collection_day()
	assert_eq(story.counter(StoryScript.Trigger.SURVEY_DAYS), 2)
	assert_false(story.answer_survey({"uid": "u2", "data_id": "rarity", "name": "Rarity"}),
		"the survey is answered once")


func test_an_unanswered_survey_never_lets_the_requisition_come_due() -> void:
	var story = StoryScript.new()
	for i in range(20):
		story.note_collection_day()
	assert_eq(story.counter(StoryScript.Trigger.SURVEY_DAYS), -1,
		"SURVEY_DAYS is below every threshold until she answers")


func test_flags_are_plain_and_default_to_false() -> void:
	var story = StoryScript.new()
	assert_false(story.has_flag("requisition_served"))
	story.set_flag("requisition_served")
	assert_true(story.has_flag("requisition_served"))
	story.set_flag("requisition_served", false)
	assert_false(story.has_flag("requisition_served"))


func test_the_whole_story_round_trips_through_a_dictionary() -> void:
	var story = StoryScript.new()
	story.note_delivery(true, "Trixie", &"trixie")
	story.note_collection_day()
	story.advance()
	story.post(&"weather_survey")
	story.mark_read(&"weather_survey")
	story.answer_survey({"uid": "u1", "data_id": "trixie", "name": "Trixie", "coat": ""})
	story.record_reply(&"weather_survey", "u1")
	story.set_flag("requisition_posted")
	story.requisition_cycle = 4

	var back = StoryScript.from_dict(story.to_dict())
	assert_eq(back.chapter, story.chapter)
	assert_eq(back.deliveries, story.deliveries)
	assert_eq(back.named_deliveries, story.named_deliveries)
	assert_eq(back.collection_days, story.collection_days)
	assert_eq(back.survey_period, story.survey_period)
	assert_eq(back.requisition_cycle, 4)
	assert_true(back.has_flag("requisition_posted"))
	assert_true(back.is_read(&"weather_survey"))
	assert_eq(back.replied_to(&"weather_survey"), "u1")
	assert_eq(String(back.survey_choice.get("name", "")), "Trixie")
	assert_eq(String(back.last_named.get("name", "")), "Trixie")


func test_a_hand_edited_file_cannot_fabricate_a_chapter_this_build_does_not_have() -> void:
	var back = StoryScript.from_dict({"chapter": 99, "deliveries": -5, "mail": "not an array"})
	assert_eq(back.chapter, StoryScript.Chapter.RESISTANCE, "clamped, not trusted")
	assert_eq(back.deliveries, 0, "a negative counter is not a counter")
	assert_eq(back.mail_ids().size(), 0, "junk is dropped rather than kept")


func test_an_empty_dictionary_is_a_brand_new_story() -> void:
	var back = StoryScript.from_dict({})
	assert_eq(back.chapter, StoryScript.Chapter.SUNNY)
	assert_eq(back.mail_ids().size(), 0)
	assert_eq(back.survey_period, -1)


func test_the_names_and_the_enums_agree_in_both_directions() -> void:
	assert_eq(StoryScript.CHAPTER_NAMES.size(), StoryScript.Chapter.size())
	assert_eq(StoryScript.TRIGGER_NAMES.size(), StoryScript.Trigger.size())
	assert_eq(StoryScript.chapter_index(&"WEATHER"), StoryScript.Chapter.WEATHER)
	assert_eq(StoryScript.trigger_index(&"SURVEY_DAYS"), StoryScript.Trigger.SURVEY_DAYS)
	assert_eq(StoryScript.chapter_index(&"NOWHERE"), -1, "an unknown chapter is minus one")
	assert_eq(StoryScript.trigger_index(&"NOWHEN"), -1, "an unknown trigger is minus one")


func test_no_line_of_this_system_carries_a_dash() -> void:
	var source: String = FileAccess.get_file_as_string("res://systems/story.gd")
	for line in source.split("\n"):
		var text: String = String(line)
		if text.begins_with("# ---") or text.begins_with("## ---"):
			continue
		assert_false(text.contains("--"), "double hyphen: %s" % text)
		assert_false(text.contains(char(0x2014)), "em dash: %s" % text)
