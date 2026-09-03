extends GutTest
## THE WIRE BETWEEN THE STORY AND THE RANCH, tested against a real Ranch node in a bare
## tree: the story advances on the events the game already emits, the post lands in the
## mailbox, the flag goes up, and answering the Survey pays exactly once. The gate
## (game/scenes/test/story_test.gd) does the same against the whole world with a real pen
## and a real walk; this is the fast half.

const RanchScene := preload("res://world/ranch.tscn")
const StoryScript := preload("res://systems/story.gd")
const StoryBeatScript := preload("res://systems/story_beat.gd")
const PauseMenuScript := preload("res://ui/pause_menu.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")

var _ranch: Ranch
var _state: Node


func before_each() -> void:
	_state = get_node("/root/GameState")
	_state.reset()
	_ranch = RanchScene.instantiate()
	add_child_autofree(_ranch)
	await wait_for_signal(_ranch.gate_report_finished, 120.0)


func test_a_fresh_ranch_puts_the_opening_letter_in_the_mailbox_and_raises_the_flag() -> void:
	assert_true(_state.story.has_mail(&"sunny_mailbox"))
	assert_eq(_state.story.unread_count(), 1)
	assert_true(_ranch.get_mailbox().is_flag_up())


func test_reading_a_letter_lowers_the_flag_and_the_letter_stays_forever() -> void:
	_ranch._on_mail_opened(&"sunny_mailbox")
	assert_true(_state.story.is_read(&"sunny_mailbox"))
	assert_false(_ranch.get_mailbox().is_flag_up())
	assert_true(_state.story.has_mail(&"sunny_mailbox"), "nothing is ever thrown away")


func test_a_delivery_is_counted_by_the_story_and_brings_the_receipt() -> void:
	_state.story.note_delivery(false, "Pony", &"")
	assert_gt(_ranch.advance_story(), 0, "the first shipment brings a letter")
	assert_true(_state.story.has_mail(&"sunny_first_receipt"))


func test_three_deliveries_turn_the_chapter_and_the_survey_lands_the_same_moment() -> void:
	for i in range(StoryScript.WEATHER_DELIVERIES):
		_state.story.note_delivery(false, "Pony", &"")
	_ranch.advance_story()
	assert_eq(_state.story.chapter, StoryScript.Chapter.WEATHER)
	assert_true(_state.story.has_mail(&"weather_survey"),
		"a chapter never turns with nothing to read")


func test_the_rendered_rows_carry_the_players_name_and_the_letter_panel_shape() -> void:
	var rows: Array[Dictionary] = _ranch.mail_rows()
	assert_eq(rows.size(), 1)
	var row: Dictionary = rows[0]
	assert_eq(String(row["id"]), "sunny_mailbox")
	assert_false(String(row["sender"]).is_empty())
	assert_false(String(row["title"]).is_empty())
	assert_gt((row["body"] as Array).size(), 2)
	assert_eq(int(row["reply"]), StoryBeatScript.Reply.NONE)
	assert_true("\n".join(row["body"]).contains(_ranch._player_name()))


func test_answering_the_survey_pays_the_bonus_and_the_coupon_exactly_once() -> void:
	for i in range(StoryScript.WEATHER_DELIVERIES):
		_state.story.note_delivery(false, "Pony", &"")
	_ranch.advance_story()
	var owned: Array[Dictionary] = _ranch.owned_rows()
	assert_eq(owned.size(), 0, "a ranch with no ponies has nobody to name")

	# create(), not new(): PonyInstance.create() is what mints the uid, and every other
	# system in the game addresses her by it.
	var instance = PonyInstanceScript.create(&"trixie")
	_state.add_pony(instance)
	owned = _ranch.owned_rows()
	assert_eq(owned.size(), 1)
	var uid: String = String(owned[0]["uid"])

	var bits_before: int = _ranch.get_economy().bits
	var hay_before: int = _ranch._current_inventory().count(StoryScript.SURVEY_COUPON_ITEM)
	assert_true(_ranch.answer_mail(&"weather_survey", uid))
	assert_eq(_ranch.get_economy().bits, bits_before + StoryScript.SURVEY_BONUS_BITS)
	assert_eq(_ranch._current_inventory().count(StoryScript.SURVEY_COUPON_ITEM),
		hay_before + StoryScript.SURVEY_COUPON_COUNT)
	assert_true(_state.story.survey_answered())
	assert_eq(String(_state.story.survey_choice["uid"]), uid)

	assert_false(_ranch.answer_mail(&"weather_survey", uid), "answered once, paid once")
	assert_eq(_ranch.get_economy().bits, bits_before + StoryScript.SURVEY_BONUS_BITS)


func test_an_answer_naming_a_pony_she_does_not_own_is_refused_and_pays_nothing() -> void:
	for i in range(StoryScript.WEATHER_DELIVERIES):
		_state.story.note_delivery(false, "Pony", &"")
	_ranch.advance_story()
	var bits_before: int = _ranch.get_economy().bits
	assert_false(_ranch.answer_mail(&"weather_survey", "not_a_uid"))
	assert_eq(_ranch.get_economy().bits, bits_before)
	assert_false(_state.story.survey_answered())


func test_a_letter_with_no_reply_control_cannot_be_answered_at_all() -> void:
	var bits_before: int = _ranch.get_economy().bits
	assert_false(_ranch.answer_mail(&"sunny_mailbox", "anything"))
	assert_eq(_ranch.get_economy().bits, bits_before)


func test_the_pause_menu_is_handed_the_mail_and_the_picker() -> void:
	var menu = _ranch.get_pause_menu()
	assert_true(menu.mail_provider.is_valid(), "ranch.gd injects the rows")
	assert_true(menu.mail_ponies_provider.is_valid(), "and the ponies she owns")
	assert_eq((menu.mail_provider.call() as Array).size(), 1)


func test_the_mail_page_is_reachable_by_the_verb_at_the_mailbox() -> void:
	var box = _ranch.get_mailbox()
	_ranch.player.global_position = box.global_position + Vector3(1.0, 0.0, 0.0)
	_ranch.player.global_position.y = _ranch.terrain.height_at(
		_ranch.player.global_position.x, _ranch.player.global_position.z) + 0.15
	assert_true(_ranch.is_near_mailbox())
	var action: Dictionary = _ranch.current_interaction()
	assert_eq(int(action.get("kind", -1)),
		preload("res://world/interaction.gd").Kind.MAILBOX)
	assert_true(_ranch.perform_interaction(action))
	var menu = _ranch.get_pause_menu()
	assert_true(menu.is_open())
	assert_eq(menu.page(), PauseMenuScript.Page.MAIL)
	menu.close()
