extends Node
## THE STORY GATE. The spec's story_test bullet, minus the halves that belong to slices 4
## and 5: the Survey chain fires only if answered, the Requisition takes EXACTLY the named
## pony and takes her by the departure path, every StoryBeat has a chapter that exists, a
## trigger the game can emit and no dash of either kind in its text, and the chapter ladder
## is walkable end to end by firing triggers (SUNNY to WEATHER, which is the whole of the
## ladder this slice ships).
##
## THE RANCH IS HOSTED HERE, not launched, the same way scenes/test/depot_test.gd's is; see
## that file's class comment for what _hosted changes and why this gate waits on
## gate_report_finished rather than polling for a symptom of it.
##
## THE REQUISITIONED PONY IS BUILT DIRECTLY INTO THE PEN with Pen.add_pony(), the way
## scenes/test/ledger_test.gd's resident is, and registered with GameState in the same
## breath, because that is what the ranch owns her by. She is not drawn from the roaming
## herd, so the census claim at the bottom of this file ("the world lost exactly the one
## pony who walked to the crate") has nothing to explain away.
##
## THE SERVE PATH'S THREE EDGES ARE EACH PROVED, not just the happy one: she is not served
## while she is out of a pen (Ranch.serve_requisition()'s own "owned but not penned" ending,
## the third of the three its class comment names), she is served exactly once she is
## penned and the Requisition is armed, and calling the seam again afterwards pays nothing
## and takes nobody: the same "answering twice pays nothing twice" discipline the Survey
## above it is held to.
##
## NOBODY DIES HERE. The one pony who leaves does it by Pony.leave_toward(), the same
## departure path a runaway and a Depot delivery use, and frees herself on arrival in
## Pony._state_leaving. There is no other exit from this world and this gate proves it by
## counting.
##
## Marker after verdict, exit code is the verdict. See docs/testing.md.

const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")
const StoryScript := preload("res://systems/story.gd")
const StoryBeatScript := preload("res://systems/story_beat.gd")
const StoryLibraryScript := preload("res://systems/story_library.gd")
const StoryWordingScript := preload("res://systems/story_wording.gd")
const LettersScript := preload("res://systems/letters.gd")
const CompendiumScript := preload("res://systems/compendium.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const InteractionScript := preload("res://world/interaction.gd")
const PauseMenuScript := preload("res://ui/pause_menu.gd")
const PonyScript := preload("res://actors/pony/pony.gd")
const SaveIOScript := preload("res://systems/save_io.gd")

const SLOT := 8  # a scratch slot; distinct from collection_test 5, ledger_test 6, depot_test 7

## The named pony the Survey is answered with. On the shipped roster
## (game/data/ponies/trixie.tres) and rare enough that delivering her is a real event.
const CHOSEN := &"trixie"

const SETTLE_FRAMES := 10

## Longest a requisition walk is given before it counts as a pony who never arrived. Taken
## from scenes/test/depot_test.gd's LEAVE_WAIT_FRAMES: the ceiling Pony.leave_toward()
## guarantees, plus a margin for the frame the timer is read on.
const LEAVE_WAIT_FRAMES := int(PonyScript.LEAVE_SECONDS * 60.0) + 60

var _checks: Dictionary = {}
var _duplicates: Array[String] = []


func _set_check(label: String, ok: bool) -> void:
	if _checks.has(label):
		_duplicates.append(label)
		var suffix := 2
		while _checks.has("%s [dup %d]" % [label, suffix]):
			suffix += 1
		_checks["%s [dup %d]" % [label, suffix]] = ok
		return
	_checks[label] = ok


func _ready() -> void:
	GateWatchdogScript.arm(self, "STORY", 180.0)
	var ranch := $Ranch as Ranch

	var ranch_ok: bool = await ranch.gate_report_finished
	_set_check("the ranch is hosted", ranch.is_hosted())
	_set_check("the ranch's own report passed", ranch_ok)

	var state = get_node("/root/GameState")
	var boot_population: int = ranch.spawner.get_spawned().size()

	# --- the corpus, structurally ----------------------------------------------------------
	var library = StoryLibraryScript.new()
	library.load_all()
	var beats: Array[StoryBeat] = library.all()
	_set_check("there are letters to read", beats.size() > 12)

	var registry = PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	var params := {"name": "W".repeat(LettersScript.MAX_NAME_LENGTH),
		"pony": "Wwwwwwwwwwwwwwww", "chosen": "Wwwwwwwwwwwwwwww", "colour": "viridian",
		"count": 999, "quota": 12, "balance": 40000}
	var chapters_ok := true
	var triggers_ok := true
	var dashes_ok := true
	var width_ok := true
	var reveals_ok := true
	for beat: StoryBeat in beats:
		if beat.chapter_index() < 0:
			chapters_ok = false
			push_error("story_test: %s names chapter '%s', which does not exist"
				% [beat.id, beat.chapter])
		if beat.trigger_index() < 0:
			triggers_ok = false
			push_error("story_test: %s names trigger '%s', which the game cannot emit"
				% [beat.id, beat.trigger])
		var letter: Dictionary = beat.render(params)
		var joined: String = String(letter["title"]) + "\n" + "\n".join(letter["body"])
		if joined.contains("--") or joined.contains(char(0x2014)):
			dashes_ok = false
			push_error("story_test: %s carries a dash" % beat.id)
		for line in letter["body"]:
			if String(line).length() > LettersScript.LINE_WIDTH:
				width_ok = false
				push_error("story_test: %s overflows on '%s'" % [beat.id, line])
		for revealed in beat.reveals:
			if registry.by_id(StringName(String(revealed))) == null:
				reveals_ok = false
				push_error("story_test: %s reveals '%s', who is not on the roster"
					% [beat.id, revealed])
	_set_check("every beat has a chapter that exists", chapters_ok)
	_set_check("every beat has a trigger the game can emit", triggers_ok)
	_set_check("no beat carries an em dash or a double hyphen", dashes_ok)
	_set_check("every letter fits the panel with the longest legal name in it", width_ok)
	_set_check("every revealed id is a character this build carries", reveals_ok)

	# --- the ladder, walked by firing triggers ----------------------------------------------
	var walked = StoryScript.new()
	var reached: Array[int] = [walked.chapter]
	for i in range(StoryScript.WEATHER_DELIVERIES):
		walked.note_delivery(false, "Pony", &"")
		if walked.advance():
			reached.append(walked.chapter)
	_set_check("the ladder walks SUNNY to WEATHER on deliveries alone",
		reached == ([StoryScript.Chapter.SUNNY, StoryScript.Chapter.WEATHER] as Array[int]))
	var opened_with := {}
	for beat: StoryBeat in library.due(walked):
		opened_with[beat.chapter_index()] = true
	_set_check("arriving in WEATHER puts something in the mailbox",
		opened_with.has(StoryScript.Chapter.WEATHER))

	# --- the Survey chain fires only if answered ---------------------------------------------
	var ignored = StoryScript.new()
	for i in range(StoryScript.WEATHER_DELIVERIES):
		ignored.note_delivery(false, "Pony", &"")
	ignored.advance()
	for beat: StoryBeat in library.due(ignored):
		ignored.post(beat.id)
	var requisitioned := false
	for i in range(30):
		ignored.note_collection_day()
		ignored.note_delivery(true, "Trixie", CHOSEN)
		ignored.advance()
		for beat: StoryBeat in library.due(ignored):
			ignored.post(beat.id)
			if beat.id == &"weather_requisition":
				requisitioned = true
	_set_check("an unanswered Survey never fires the Requisition, ever", not requisitioned)
	_set_check("and the letter is still sitting there unanswered",
		ignored.has_mail(&"weather_survey") and ignored.replied_to(&"weather_survey").is_empty())

	# --- the real ranch: a pen, a named pony, and the Survey answered ------------------------
	var slots: Array[PlotSlot] = ranch.plot_slots()
	var free_plot: PlotData = null
	for plot: PlotData in ranch.plots_catalogue().all():
		if plot.cost == 0:
			free_plot = plot
			break
	_set_check("there is an empty plot and a pen that costs nothing to put on it",
		slots.size() > 0 and slots[0].is_empty() and free_plot != null)
	if slots.is_empty() or free_plot == null:
		_finish()
		return
	_set_check("the pen goes up", slots[0].build(free_plot))
	var pen := slots[0].get_built() as Pen
	_set_check("the built slot is a real pen", pen != null)
	if pen == null:
		_finish()
		return

	var resident := PonyInstanceScript.create(CHOSEN)
	resident.happiness = 1.0
	_set_check("a named pony moves into the pen, off the roaming herd", pen.add_pony(resident))
	# AND THE RANCH OWNS HER. The pen holds her body; GameState holds the record every other
	# system addresses her by, and serve_requisition() refuses a pony the ranch does not own.
	_set_check("and the ranch owns her record", state.add_pony(resident))
	var chosen_uid: StringName = resident.uid

	await _frames(SETTLE_FRAMES)

	# The chapter, the letters, and the picker, all through the ranch's own seams.
	for i in range(StoryScript.WEATHER_DELIVERIES):
		state.story.note_delivery(false, "Pony", &"")
	ranch.advance_story()
	_set_check("the ranch is in WEATHER", state.story.chapter == StoryScript.Chapter.WEATHER)
	_set_check("the Survey is in the mailbox", state.story.has_mail(&"weather_survey"))
	_set_check("the flag is up while something is unread", ranch.get_mailbox().is_flag_up())

	var picker: Array[Dictionary] = ranch.owned_rows()
	var offered := false
	for row: Dictionary in picker:
		if StringName(String(row["uid"])) == chosen_uid:
			offered = true
	_set_check("the picker offers the pony she owns", offered)

	var bits_before: int = ranch.get_economy().bits
	var hay_before: int = ranch._current_inventory().count(StoryScript.SURVEY_COUPON_ITEM)
	_set_check("she answers the Survey", ranch.answer_mail(&"weather_survey",
		String(chosen_uid)))
	_set_check("the bonus is exactly 50 bits",
		ranch.get_economy().bits == bits_before + StoryScript.SURVEY_BONUS_BITS)
	_set_check("and the coupon is hay",
		ranch._current_inventory().count(StoryScript.SURVEY_COUPON_ITEM)
			== hay_before + StoryScript.SURVEY_COUPON_COUNT)
	_set_check("answering twice pays nothing twice",
		not ranch.answer_mail(&"weather_survey", String(chosen_uid)))
	_set_check("the choice is saved for the slices that pay it off",
		String(state.story.survey_choice.get("data_id", "")) == String(CHOSEN))

	# --- the Requisition arrives, and the collector calls at dawn ----------------------------
	state.story.note_collection_day()
	state.story.note_collection_day()
	ranch.advance_story()
	_set_check("the Requisition arrives some collection days later",
		state.story.has_mail(&"weather_requisition"))
	_set_check("and it is armed rather than served on the spot",
		state.story.has_flag("requisition_posted")
			and not state.story.has_flag("requisition_served"))

	# --- edge (a): the collector does not serve a pony who is not in a pen -------------------
	# Ranch.serve_requisition()'s own class comment names three endings; this is the third
	# ("she is owned but not penned  nothing happens and it stays armed"). Pen.remove_pony()
	# takes her body and her address off the pen's own books WITHOUT touching GameState's
	# record of her, which is exactly the "owned but not penned" shape: had it also dropped
	# her from GameState this would exercise the "not owned at all" ending instead, which
	# closes the Requisition rather than leaving it armed.
	var evicted: PonyInstance = pen.remove_pony(chosen_uid)
	_set_check("she is pulled from the pen for this one check", evicted != null)
	var pocket_result: Dictionary = ranch.serve_requisition()
	_set_check("the collector will not take her out of a pocket",
		not bool(pocket_result["served"]))
	_set_check("the requisition stays armed while she is not penned",
		state.story.has_flag("requisition_posted")
			and not state.story.has_flag("requisition_served"))
	_set_check("she goes back in the pen for the real call", pen.add_pony(resident))

	await _frames(SETTLE_FRAMES)
	var before: Dictionary = _whole_world_refs(ranch, pen)
	_set_check("there is a census for the requisition to be measured against",
		before.size() > 1)

	# HER BODY, HELD AS A WEAK REFERENCE BEFORE ANYTHING TOUCHES HER. Pen.body_for() answers
	# null the moment release_body() clears her from the pen's books, which happens at the
	# START of the walk; so "did she walk" cannot be asked of the pen afterwards. It is asked
	# of the body itself: still alive right after the counter takes her (she is walking), gone
	# some seconds later (she freed herself on arrival, in Pony._state_leaving).
	var chosen_body: Node3D = pen.body_for(chosen_uid)
	_set_check("she has a body standing in the pen", chosen_body != null)
	var chosen_ref: WeakRef = weakref(chosen_body)

	# --- edge (b): she is served exactly once she is penned and the Requisition is armed -----
	var quota_before: int = state.ledger.delivered_this_period
	var served: Dictionary = ranch.serve_requisition()
	_set_check("the collector takes her", bool(served["served"]))
	_set_check("and takes exactly the pony she named",
		String(served.get("name", "")) == resident.display_name())
	_set_check("she is out of the pen's own books", pen.find_pony(chosen_uid) == null)
	_set_check("and out of the ranch's", state.find_pony(chosen_uid) == null)
	_set_check("the delivery was counted like any other",
		state.ledger.delivered_this_period == quota_before + 1)
	_set_check("her entry reads PROCESSED",
		state.compendium.state_of(CHOSEN) == CompendiumScript.State.PROCESSED)
	_set_check("with the Employee's Choice star",
		StoryWordingScript.processed_value(state.story.chapter, true)
			.contains(StoryWordingScript.EMPLOYEES_CHOICE))

	# --- edge (c): it never serves twice -------------------------------------------------------
	_set_check("and it is served exactly once",
		not bool(ranch.serve_requisition()["served"]))
	_set_check("the flag holds after a successful serve",
		state.story.has_flag("requisition_served"))

	# SHE LEAVES BY THE DEPARTURE PATH, which is two facts and not one: she is STILL THERE
	# when the counter has finished with her (nothing removed her; she is walking), and she is
	# gone some seconds later (she freed herself on arrival). Waited on as a STATE with a hard
	# frame cap, never as a fixed number of frames.
	_set_check("nothing removed her; she is on her hooves and walking",
		chosen_ref.get_ref() != null)
	var walking: Node3D = chosen_ref.get_ref() as Node3D
	_set_check("and the pony walking is the one the letter named",
		walking != null and walking.is_being_delivered())
	var arrived := false
	for i in range(LEAVE_WAIT_FRAMES):
		await get_tree().physics_frame
		if chosen_ref.get_ref() == null:
			arrived = true
			break
	_set_check("she walks to the crate and frees herself there", arrived)

	# --- nothing else in the world moved -------------------------------------------------------
	var survivors := 0
	for id in before:
		if before[id].get_ref() != null:
			survivors += 1
	_set_check("the world lost exactly the one pony who walked to the crate",
		survivors == before.size() - 1)
	var final_population: int = ranch.spawner.get_spawned().size()
	print("STORY population boot=%d final=%d" % [boot_population, final_population])
	_set_check("the roaming herd was never touched at all",
		final_population == boot_population)

	# --- the page she reads it all on ------------------------------------------------------
	var menu = ranch.get_pause_menu()
	var box: Node3D = ranch.get_mailbox()
	ranch.player.global_position = box.global_position + Vector3(1.2, 0.0, 0.0)
	ranch.player.global_position.y = ranch.terrain.height_at(
		ranch.player.global_position.x, ranch.player.global_position.z) + 0.15
	await _frames(SETTLE_FRAMES)
	_set_check("the player can stand at the mailbox", ranch.is_near_mailbox())
	var action: Dictionary = ranch.current_interaction()
	_set_check("the verb at the mailbox is the mail",
		int(action.get("kind", -1)) == InteractionScript.Kind.MAILBOX)
	var unread: Dictionary = ranch.newest_unread_row()
	_set_check("pressing it opens something", ranch.perform_interaction(action))
	# THE LETTER OPENS AT THE MAILBOX, NOT IN A MENU. The owner read "it says it's by my
	# house but it's in the pause menu" as a bug, and it was one.
	_set_check("and what opened is the reader",
		ranch.letter_panel != null and bool(ranch.letter_panel.call("is_open")))
	_set_check("holding the newest letter she had not read",
		unread.is_empty()
			or String(ranch.letter_panel.call("title_text")) == String(unread["title"]))
	_set_check("and reading it took the flag down",
		unread.is_empty() or state.story.is_read(StringName(String(unread["id"]))))
	ranch.letter_panel.call("close")
	# THE ARCHIVE IS STILL THERE AND STILL HOLDS EVERYTHING.
	ranch.open_mail_page()
	_set_check("the archive page is the pause menu's own",
		menu.is_open() and menu.page() == PauseMenuScript.Page.MAIL)
	var rows: Array[Dictionary] = menu.mail_rows()
	_set_check("the mailbox holds every letter she has ever been sent",
		rows.size() == state.story.mail_ids().size())
	_set_check("newest first", rows.size() > 1
		and String(rows[0]["id"]) == String(state.story.mail_ids()[rows.size() - 1]))
	var page_lines: Array[String] = menu.mail_lines()
	var page_clean := true
	for line: String in page_lines:
		if line.contains("--") or line.contains(char(0x2014)):
			page_clean = false
	_set_check("and nothing on the page carries a dash", page_clean)
	menu.close()

	var path: String = ProjectSettings.globalize_path(SaveIOScript.slot_path(SLOT))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_finish()


## A WeakRef to every pony body standing in the world right now: the roaming herd and every
## resident of every built pen. Copied from scenes/test/depot_test.gd's own census.
func _whole_world_refs(ranch: Ranch, pen: Pen) -> Dictionary:
	var out := {}
	for pony: Pony in ranch.spawner.get_spawned():
		out[pony.get_instance_id()] = weakref(pony)
	for slot: PlotSlot in ranch.plot_slots():
		var built := slot.get_built() as Pen
		if built == null:
			continue
		for inst: PonyInstance in built.ponies():
			var body: Node3D = built.body_for(inst.uid)
			if body != null:
				out[body.get_instance_id()] = weakref(body)
	return out


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _finish() -> void:
	var all_ok := _duplicates.is_empty()
	for label in _checks:
		if not _checks[label]:
			push_error("story_test: FAILED check: %s" % label)
			all_ok = false
	for label in _duplicates:
		push_error("story_test: DUPLICATE CHECK LABEL: %s" % label)
	print(("STORY_OK " if all_ok else "STORY_FAILED ") + "checks=%d" % _checks.size())
	get_tree().quit(0 if all_ok else 1)
