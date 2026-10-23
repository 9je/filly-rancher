extends GutTest
## One letter, as data, and the directory that loads them. The corpus itself is checked by
## game/test/test_story_corpus.gd (Task 3) and by the story gate; this file is about the
## resource's own behaviour and the library's own contract.

const StoryScript := preload("res://systems/story.gd")
const StoryBeatScript := preload("res://systems/story_beat.gd")
const StoryLibraryScript := preload("res://systems/story_library.gd")


func _beat(id: String, chapter: String, trigger: String, threshold: int) -> StoryBeat:
	var beat: StoryBeat = StoryBeatScript.new()
	beat.id = StringName(id)
	beat.chapter = StringName(chapter)
	beat.trigger = StringName(trigger)
	beat.threshold = threshold
	beat.sender = "Cloudsdale Weather Corporation"
	beat.title = "A letter"
	beat.body = PackedStringArray(["Dear {name},", "", "Your {count} shipments."])
	return beat


func test_a_beat_resolves_its_chapter_trigger_and_reply_to_this_builds_enums() -> void:
	var beat: StoryBeat = _beat("t", "WEATHER", "DELIVERIES", 5)
	assert_eq(beat.chapter_index(), StoryScript.Chapter.WEATHER)
	assert_eq(beat.trigger_index(), StoryScript.Trigger.DELIVERIES)
	assert_eq(beat.reply_index(), StoryBeatScript.Reply.NONE)
	beat.reply = &"PICK_PONY"
	assert_eq(beat.reply_index(), StoryBeatScript.Reply.PICK_PONY)


func test_a_beat_naming_something_this_build_does_not_have_answers_minus_one() -> void:
	var beat: StoryBeat = _beat("t", "NOWHERE", "NOWHEN", 0)
	beat.reply = &"SEMAPHORE"
	assert_eq(beat.chapter_index(), -1)
	assert_eq(beat.trigger_index(), -1)
	assert_eq(beat.reply_index(), -1)


func test_render_fills_the_placeholders_and_answers_the_letter_panel_shape() -> void:
	var beat: StoryBeat = _beat("t", "SUNNY", "CHAPTER", 0)
	var letter: Dictionary = beat.render({"name": "Moonbeam", "count": 12})
	assert_eq(String(letter["sender"]), "Cloudsdale Weather Corporation")
	assert_eq(String(letter["title"]), "A letter")
	var body: Array = letter["body"]
	assert_eq(String(body[0]), "Dear Moonbeam,")
	assert_eq(String(body[2]), "Your 12 shipments.")


func test_a_missing_parameter_renders_a_default_rather_than_a_brace() -> void:
	var beat: StoryBeat = _beat("t", "SUNNY", "CHAPTER", 0)
	var letter: Dictionary = beat.render({})
	var joined: String = "\n".join(letter["body"])
	assert_false(joined.contains("{"), "an unfilled placeholder is a letter she never reads")
	assert_true(joined.contains(String(StoryBeatScript.DEFAULTS["name"])))


func test_the_library_loads_the_shipped_directory_and_indexes_it_by_id() -> void:
	var library = StoryLibraryScript.new()
	library.load_all()
	assert_gt(library.all().size(), 0, "game/data/story is not empty")
	var first: StoryBeat = library.all()[0]
	assert_eq(library.by_id(first.id), first)
	assert_null(library.by_id(&"no_such_beat"), "an unknown id is null, not a crash")


func test_the_library_orders_by_chapter_then_threshold_then_id() -> void:
	var library = StoryLibraryScript.new()
	library.load_all()
	var previous: Vector2i = Vector2i(-1, -1)
	for beat: StoryBeat in library.all():
		var here: Vector2i = Vector2i(beat.chapter_index(), beat.threshold)
		assert_true(here.x > previous.x or (here.x == previous.x and here.y >= previous.y),
			"beats come out in ladder order: %s" % String(beat.id))
		previous = here


func test_due_answers_only_beats_whose_chapter_is_reached_and_threshold_met() -> void:
	var library = StoryLibraryScript.new()
	library.load_all()
	var story = StoryScript.new()
	for beat: StoryBeat in library.due(story):
		assert_eq(beat.chapter_index(), StoryScript.Chapter.SUNNY,
			"a brand new story is only owed SUNNY letters")
		assert_lte(beat.threshold, 0, "and only the ones whose counter is already met")


func test_due_never_answers_a_beat_that_has_already_been_posted() -> void:
	var library = StoryLibraryScript.new()
	library.load_all()
	var story = StoryScript.new()
	var owed: Array[StoryBeat] = library.due(story)
	assert_gt(owed.size(), 0, "a new ranch is owed at least one letter")
	for beat: StoryBeat in owed:
		story.post(beat.id)
	assert_eq(library.due(story).size(), 0, "a posted letter is not owed twice")


func test_a_directory_that_is_not_there_is_reported_and_answers_empty() -> void:
	var library = StoryLibraryScript.new()
	library.load_all("res://data/no_such_directory")
	assert_eq(library.all().size(), 0)
	assert_push_error(1, "a missing story directory is reported loudly, not swallowed")
