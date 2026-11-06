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


func test_the_verb_at_the_mailbox_opens_the_letter_there() -> void:
	var box = _ranch.get_mailbox()
	_ranch.player.global_position = box.global_position + Vector3(1.0, 0.0, 0.0)
	_ranch.player.global_position.y = _ranch.terrain.height_at(
		_ranch.player.global_position.x, _ranch.player.global_position.z) + 0.15
	assert_true(_ranch.is_near_mailbox())
	var action: Dictionary = _ranch.current_interaction()
	assert_eq(int(action.get("kind", -1)),
		preload("res://world/interaction.gd").Kind.MAILBOX)
	assert_true(_ranch.perform_interaction(action))
	assert_true(_ranch.letter_panel.is_open(), "the reader, not the pause menu")
	_ranch.letter_panel.close()


func test_the_requisition_does_nothing_at_all_until_it_has_been_posted() -> void:
	var result: Dictionary = _ranch.serve_requisition()
	assert_false(bool(result["served"]))
	assert_false(_state.story.has_flag("requisition_served"))


func test_a_requisition_for_a_pony_she_no_longer_has_closes_itself_quietly() -> void:
	_state.story.set_flag("requisition_posted")
	_state.story.requisition_cycle = -1
	_state.story.survey_choice = {"uid": "gone", "data_id": "trixie", "name": "Trixie",
		"coat": ""}
	var result: Dictionary = _ranch.serve_requisition()
	assert_false(bool(result["served"]), "there was nobody to walk over")
	assert_true(_state.story.has_flag("requisition_served"),
		"and it does not sit armed forever waiting for a pony who is not coming back")


## CRITICAL 2 OF THE FINAL REVIEW, REPRODUCED. `Ranch._story_params()` used to fall back to
## `survey_choice` for `{pony}` whenever it was non empty, which is forever once she answers
## the Survey; every receipt after that named her Survey pony instead of whoever the receipt
## was actually about. Reproduces the review's own scenario exactly: a named delivery before
## the Survey is answered (sunny_named_thanks, which must never rewrite itself once posted),
## the Survey answered naming a pony who is never delivered, and a second named delivery of
## somebody else entirely (weather_colour_receipt, which must name HER, not the Survey's
## pony).
func test_a_receipt_names_the_pony_delivered_not_the_one_named_on_the_survey() -> void:
	# Fluttershy, delivered and thanked BEFORE the Survey even exists.
	_state.story.note_delivery(true, "Fluttershy", &"fluttershy")
	assert_gt(_ranch.advance_story(), 0)
	assert_true(_state.story.has_mail(&"sunny_named_thanks"))
	var thanks_before: String = _letter_body(&"sunny_named_thanks")
	assert_true(thanks_before.contains("Fluttershy"))

	# The chapter turns, and she names Trixie on the Survey. Trixie is never delivered.
	for i in range(StoryScript.WEATHER_DELIVERIES - 1):
		_state.story.note_delivery(false, "Pony", &"")
	_ranch.advance_story()
	assert_eq(_state.story.chapter, StoryScript.Chapter.WEATHER)
	var trixie = PonyInstanceScript.create(&"trixie")
	_state.add_pony(trixie)
	assert_true(_ranch.answer_mail(&"weather_survey", String(trixie.uid)))
	assert_eq(String(_state.story.survey_choice.get("name", "")), "Trixie")

	# THE OLDER LETTER MUST NOT HAVE MOVED. Re reading it now, with the Survey answered,
	# has to show exactly what it showed the day it arrived.
	assert_eq(_letter_body(&"sunny_named_thanks"), thanks_before,
		"a posted letter's meaning must never change under her")

	# A second named delivery, of Rarity, never of Trixie.
	_state.story.note_delivery(true, "Rarity", &"rarity")
	_ranch.advance_story()
	assert_true(_state.story.has_mail(&"weather_colour_receipt"))
	var receipt_body: String = _letter_body(&"weather_colour_receipt")
	assert_true(receipt_body.contains("Rarity"), "the receipt names who was actually delivered")
	assert_false(receipt_body.contains("Trixie"),
		"the Survey's pony must never be named as processed by a receipt that is not about her")


## MINOR 2 OF THE FINAL REVIEW. `employees_choice` used to be read straight off
## survey_choice.data_id the moment she answered, so it starred her whole CHARACTER, not the
## one instance she named: any other pony of the same species reaching PROCESSED would
## carry the star too. Now it waits on Story's "employees_choice_delivered" flag, which
## deliver_pony() sets only when the uid actually delivered matches the one she named.
func test_the_employees_choice_star_waits_for_the_named_pony_herself_not_just_her_species() -> void:
	for i in range(StoryScript.WEATHER_DELIVERIES):
		_state.story.note_delivery(false, "Pony", &"")
	_ranch.advance_story()
	var fluttershy = PonyInstanceScript.create(&"fluttershy")
	_state.add_pony(fluttershy)
	assert_true(_ranch.answer_mail(&"weather_survey", String(fluttershy.uid)))

	assert_eq(_ranch._employees_choice_id(), &"",
		"answering the Survey names nobody as delivered until somebody actually is")

	# A different instance of the same character, processed some other way: the Compendium
	# is keyed by character, and this must not be mistaken for the one she named.
	_state.compendium.mark_processed(&"fluttershy")
	assert_eq(_ranch._employees_choice_id(), &"",
		"a different instance of the same species reaching PROCESSED is not the pony she chose")

	# Only the flag deliver_pony() sets when the delivered uid matches earns it.
	_state.story.set_flag("employees_choice_delivered")
	assert_eq(_ranch._employees_choice_id(), &"fluttershy")


func _letter_body(id: StringName) -> String:
	for row: Dictionary in _ranch.mail_rows():
		if String(row["id"]) == String(id):
			return "\n".join(row["body"])
	return ""


func test_a_requisition_waits_for_a_pony_who_is_in_the_saddlebag_rather_than_a_pen() -> void:
	var instance = PonyInstanceScript.create(&"trixie")
	_state.add_pony(instance)
	_state.story.set_flag("requisition_posted")
	_state.story.requisition_cycle = -1
	_state.story.survey_choice = {"uid": String(instance.uid), "data_id": "trixie",
		"name": "Trixie", "coat": ""}
	var result: Dictionary = _ranch.serve_requisition()
	assert_false(bool(result["served"]))
	assert_false(_state.story.has_flag("requisition_served"),
		"she is still hers; the collector calls again when she is in a pen")


# --- the mailbox is where mail is read --------------------------------------------------

## THE OWNER, ON HER FIRST FULL PLAYTEST: "it says it's by your house but it's in the pause
## menu". The letter told her where her mailbox was and then the verb at the mailbox opened a
## menu page. The fiction is consistent from here: the mailbox opens the letter, and the pause
## page is the archive of what has already come.

func test_the_mailbox_opens_the_newest_unread_letter_in_the_reader() -> void:
	var row: Dictionary = _ranch.newest_unread_row()
	assert_false(row.is_empty(), "a fresh ranch has a letter waiting")
	assert_true(_ranch.open_mailbox_letter())
	assert_true(_ranch.letter_panel.is_open(), "the reader, not the menu page")
	assert_eq(_ranch.letter_panel.title_text(), String(row["title"]))


func test_reading_at_the_mailbox_marks_the_letter_read() -> void:
	var row: Dictionary = _ranch.newest_unread_row()
	_ranch.open_mailbox_letter()
	assert_true(_state.story.is_read(StringName(String(row["id"]))),
		"she read it; the flag comes down")


func test_a_second_visit_with_nothing_unread_re_reads_the_newest() -> void:
	_ranch.open_mailbox_letter()
	_ranch.letter_panel.close()
	assert_true(_ranch.newest_unread_row().is_empty(), "nothing unread now")
	assert_true(_ranch.open_mailbox_letter(),
		"a mailbox with post in it is never a dead key")
	assert_true(_ranch.letter_panel.is_open())


func test_an_empty_mailbox_says_so_rather_than_doing_nothing() -> void:
	_state.story.mail.clear()
	assert_false(_ranch.open_mailbox_letter())
	assert_false(_ranch.letter_panel.is_open())


func test_a_letter_that_asks_a_question_is_answered_in_the_letter_itself() -> void:
	# PT5 (playtest 2026-11-05 item 51): "idk how i even got into saddlebag menu i clicked
	# mailbox", "also not clear how to respond". The mailbox opens the letter, every time, and
	# a letter with a question carries its answers on the sheet as buttons.
	var instance = PonyInstanceScript.create(&"trixie")
	_state.add_pony(instance)
	_state.story.post(&"weather_survey")
	_ranch.open_mailbox_letter()
	assert_true(_ranch.letter_panel.is_open(), "the letter, not the archive page")
	assert_false(_ranch.get_pause_menu().is_open())
	var buttons: Array = _ranch.letter_panel.reply_buttons()
	assert_eq(buttons.size(), 1, "one button per pony she could name")
	var bits_before: int = _ranch.get_economy().bits
	(buttons[0] as Button).pressed.emit()
	await wait_frames(2)
	assert_true(_state.story.survey_answered(), "pressing a pony answers the survey")
	assert_eq(_ranch.get_economy().bits, bits_before + StoryScript.SURVEY_BONUS_BITS)
	assert_false(_ranch.letter_panel.is_open(), "and the letter is put away")


func test_the_archive_page_says_what_it_is() -> void:
	assert_eq(PauseMenu.MAIN_ROWS[PauseMenu.Row.MAIL], "Saddlebag copies")
	assert_false(PauseMenu.MAIL_ARCHIVE_NOTE.is_empty())
	assert_false(PauseMenu.MAIL_ARCHIVE_NOTE.contains("--"))
	assert_false(PauseMenu.MAIL_ARCHIVE_NOTE.contains(char(0x2014)))


## PS0 (same cause as _owned_named_ids): the roster in GameState is written at a save, so a
## pony caught since the last save was missing from the Survey's "which of your ponies"
## picker, and naming her was refused.
func test_the_survey_can_name_a_pony_caught_since_the_last_save() -> void:
	for i in range(StoryScript.WEATHER_DELIVERIES):
		_state.story.note_delivery(false, "Pony", &"")
	_ranch.advance_story()
	var caught = PonyInstanceScript.create(&"octavia")
	assert_true(_ranch.player.get_magic_beam().get_storage().store(caught))
	var uids: Array = _ranch.owned_rows().map(func(r: Dictionary) -> String: return String(r["uid"]))
	assert_has(uids, String(caught.uid), "the pony in the saddlebag is offered")
	assert_true(_ranch.answer_mail(&"weather_survey", String(caught.uid)), "and can be named")
