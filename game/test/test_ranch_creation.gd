extends GutTest
## Regression test for the cursor wiring around the creation screen
## (game/world/ranch.gd's _maybe_open_creation()/_on_creation_confirmed()/
## _set_cursor_captured()).
##
## THE BUG THIS PINS. game/actors/player/camera_rig.gd captures the mouse in its own
## _ready(), which runs before ranch's _maybe_open_creation() ever does, and unlike every
## other menu (build/market/depot/pause, all wired through ranch's own
## _on_menu_opened()/_on_menu_closed()), the creation screen never touched Input.mouse_mode
## at all -- so on a real interactive new game nothing on the screen was clickable: the
## pointer stayed locked to the paused, invisible ranch behind it.
##
## WHY _cursor_captured, NOT Input.mouse_mode. Godot's headless display driver always
## reports Input.mouse_mode as MOUSE_MODE_VISIBLE, whatever was last assigned to it --
## confirmed empirically (a standalone script that sets MOUSE_MODE_CAPTURED and reads it
## straight back gets 0/VISIBLE every time under `--headless`, which is exactly how this
## whole suite and every gate run). Asserting on Input.mouse_mode here would therefore
## either pass vacuously or fail regardless of what ranch.gd actually does. `_cursor_captured`
## is the plain bool _set_cursor_captured() maintains ALONGSIDE the (headless-unobservable)
## Input.mouse_mode assignment, so this file is testing the real decision ranch.gd makes,
## not the one piece of engine state headless cannot see.
##
## WHY A DETACHED RANCH, RATHER THAN world/ranch.tscn. See test_ranch_collection.gd's class
## comment for the reasoning this file borrows -- a full ranch scene boots terrain, a
## spawner and a physics warmup this bug has nothing to do with. Ranch.new() never enters a
## tree, so _ready() never runs and every @onready var stays null except the ones this file
## sets by hand, the same pattern test_ranch_collection.gd's FakePlayer/_ranch() use.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd.

const RanchScript := preload("res://world/ranch.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const CreationScreenScene := preload("res://ui/creation_screen.tscn")
const LetterPanelScene := preload("res://ui/letter_panel.tscn")
const LettersScript := preload("res://systems/letters.gd")

const SCRATCH_DIR := "user://test_scratch/ranch_creation"


func before_each() -> void:
	SaveIOScript.save_dir = SCRATCH_DIR
	_wipe()


func after_each() -> void:
	_wipe()
	# session_save_dir, NOT DEFAULT_SAVE_DIR: on a harness run the process was redirected off
	# the player's slots at class load, and restoring the default would walk every test that
	# runs after this one straight back onto them.
	SaveIOScript.save_dir = SaveIOScript.session_save_dir


func _wipe() -> void:
	var da := DirAccess.open(SCRATCH_DIR)
	if da == null:
		return
	da.list_dir_begin()
	var entry := da.get_next()
	while entry != "":
		if not da.current_is_dir():
			da.remove(entry)
		entry = da.get_next()
	da.list_dir_end()


## A detached Ranch wired to a real, tree-attached CreationScreen and a real GameState --
## enough to drive _maybe_open_creation()/_on_creation_confirmed() without booting the
## whole map, the same shape test_ranch_collection.gd's _ranch() wires a FakePlayer with.
func _ranch_with_screen(interactive: bool) -> Dictionary:
	var ranch: RanchScript = autofree(RanchScript.new())
	ranch._game_state = autofree(GameStateScript.new())
	ranch._interactive = interactive
	var screen: CreationScreen = CreationScreenScene.instantiate()
	add_child_autofree(screen)
	ranch.creation_screen = screen
	# The letter reader the confirm shows (Ruling 25). Wired by hand rather than by
	# _bind_letter_panel(), deliberately: the binding is what connects the panel's `opened`
	# to ranch.gd's pause handler, and this Ranch is detached, so get_tree() is null and
	# pausing would crash. What is under test here is the SHOWING, not the pausing.
	var letters: LetterPanel = LetterPanelScene.instantiate()
	add_child_autofree(letters)
	ranch.letter_panel = letters
	return {"ranch": ranch, "screen": screen, "letters": letters}


func test_a_fresh_ranch_starts_with_the_cursor_captured() -> void:
	var built := _ranch_with_screen(true)
	assert_true(built["ranch"]._cursor_captured,
		"sanity: camera_rig.gd already captured the mouse before any menu ran")


func test_opening_the_creation_screen_frees_the_cursor() -> void:
	var built := _ranch_with_screen(true)
	built["ranch"]._maybe_open_creation()
	assert_true(built["screen"].is_open())
	assert_false(built["ranch"]._cursor_captured,
		"the screen is unusable with the mouse still captured to the ranch behind it")


func test_confirming_recaptures_the_cursor() -> void:
	var built := _ranch_with_screen(true)
	built["ranch"]._maybe_open_creation()
	assert_true(built["screen"].confirm())
	assert_false(built["screen"].is_open())
	assert_true(built["ranch"]._cursor_captured,
		"confirming must hand the mouse back to the game")


func test_a_non_interactive_session_never_touches_the_cursor() -> void:
	# A hosted/headless/screenshot run must not fight whatever the host already set --
	# see _set_cursor_captured()'s _interactive guard.
	var built := _ranch_with_screen(false)
	built["ranch"]._maybe_open_creation()
	assert_false(built["screen"].is_open(),
		"a non-interactive session must never open the screen at all")
	assert_true(built["ranch"]._cursor_captured,
		"...and so must never have released the cursor either")


# --- the welcome letter (Ruling 25, and the quota that was always 0) -----------------------

## THE CALLER'S OWN PARAMS, NOT A HAND BUILT DICTIONARY. game/test/test_letters.gd proves
## the WELCOME template prints whatever quota it is handed; what it could not see, and what
## shipped, is that ranch.gd handed it a name and a balance and NOTHING ELSE, so the number
## fell through to render()'s own default of 0 and every new player was told "We expect 0
## ponies delivered to the Depot each period". A template test cannot catch that. Driving
## _on_creation_confirmed() and reading the page the player actually sees can.
func test_the_welcome_letter_carries_the_ledgers_real_quota_and_balance() -> void:
	var built := _ranch_with_screen(true)
	var ranch: RanchScript = built["ranch"]
	var letters: LetterPanel = built["letters"]
	var ledger = ranch._game_state.ledger
	assert_gt(ledger.quota, 0, "sanity: a fresh ledger expects some ponies")
	ranch._maybe_open_creation()
	assert_true(built["screen"].confirm())

	assert_true(letters.is_open(), "the welcome letter is shown, not thrown away")
	var body: String = "\n".join(letters.drawn_lines())
	assert_true(body.contains("%d ponies" % ledger.quota),
		"the quota the Depot judges her against has to be the quota the letter states: %s"
			% body)
	assert_false(body.contains("0 ponies"),
		"'0 ponies' is what a defaulted quota prints, and it is what shipped")
	assert_true(body.contains(str(ledger.balance)),
		"and the balance is her real one: %s" % body)


## EVERY STEP OF THE LOOP REACHES HER, through the production path rather than a rendered
## dictionary nobody draws. This is the check that Task 7's "the first two minutes say where
## bits come from" is true of the GAME and not only of game/systems/letters.gd.
func test_the_shown_welcome_names_every_step_of_the_money_loop() -> void:
	var built := _ranch_with_screen(true)
	built["ranch"]._maybe_open_creation()
	built["screen"].confirm()
	var body: String = "\n".join(built["letters"].drawn_lines()).to_lower()
	for step: String in ["catch", "pen", "gem", "market", "depot"]:
		assert_true(body.contains(step), "the shown letter must name '%s': %s" % [step, body])


func test_the_welcome_letter_is_shown_exactly_once() -> void:
	var built := _ranch_with_screen(true)
	var letters: LetterPanel = built["letters"]
	watch_signals(letters)
	built["ranch"]._maybe_open_creation()
	built["screen"].confirm()
	assert_signal_emit_count(letters, "opened", 1,
		"one new ranch, one welcome: a second would be a second pause to get out of")


## A LOADED SAVE GETS NO LETTER. _maybe_open_creation() refuses a session that loaded one
## (there is no re-edit screen this phase), so the confirm that shows the letter never
## happens; a returning player being welcomed to the family every boot would be a bug the
## first time and a joke the fifth.
func test_loading_a_save_shows_no_letter_at_all() -> void:
	var built := _ranch_with_screen(true)
	built["ranch"]._save_loaded = true
	built["ranch"]._maybe_open_creation()
	assert_false(built["screen"].is_open(), "sanity: a loaded save opens no creation screen")
	assert_false(built["letters"].is_open(), "and therefore no letter")


## THE PANEL IS ON THE PAUSE PREDICATE. Every panel in this game refuses to open over
## another one, and ranch.gd's _no_menu_but() is the single question all of them ask; a
## reader that was not in that list would let E open the Market underneath a letter.
func test_an_open_letter_counts_as_a_menu_being_up() -> void:
	var built := _ranch_with_screen(true)
	var ranch: RanchScript = built["ranch"]
	assert_true(ranch._no_other_menu_open(), "sanity: nothing is up yet")
	built["letters"].open(LettersScript.render(LettersScript.Id.WELCOME, {"quota": 2}))
	assert_false(ranch._no_other_menu_open(),
		"a letter on the screen is a menu being up, or E opens the Market under it")
	built["letters"].close()
	assert_true(ranch._no_other_menu_open())
