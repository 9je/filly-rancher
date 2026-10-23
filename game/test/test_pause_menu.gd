extends GutTest
## Tests for game/ui/pause_menu.gd. Same rules as the other menus: keyboard and gamepad
## through the methods ui_* route into, and the menu only emits; ranch.gd pauses, saves
## and quits.

const PauseMenuScene := preload("res://ui/pause_menu.tscn")
const SettingsScript := preload("res://systems/settings.gd")
const CompendiumScript := preload("res://systems/compendium.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const RegionRegistryScript := preload("res://systems/region_registry.gd")
const RequestBoardScript := preload("res://systems/request_board.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const LedgerScript := preload("res://systems/ledger.gd")

const PONY_DIR := "res://data/ponies"

var _menu: PauseMenu
var _settings: Settings

## The five things ranch.gd injects, built from the SHIPPED data by _wire_book() below and
## left null by the tests that check a bare menu still draws. See _wire_book().
var _compendium: Compendium
var _registry: PonyRegistry
var _regions: RegionRegistry
var _board: RequestBoard
var _world: WorldState


func before_each() -> void:
	_settings = SettingsScript.new()
	_menu = PauseMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu.settings = _settings


## Everything the two reading pages draw, wired the way ranch.gd wires it
## (game/world/ranch.gd, _bind_pause_menu). THE REGISTRY AND THE REGIONS ARE THE REAL ONES
## OFF DISK, not a fixture: the counting and ordering tests below are about this game's
## roster, and a hand-rolled stand in would go on passing after the roster changed under it.
## test_compendium.gd loads the roster the same way and for the same reason.
##
## The compendium starts EMPTY and each test marks what it needs by hand; the board is the
## tutorial three, which are fixed text and fixed rewards rather than a seeded draw.
## The clock is PINNED, so "Now:" cannot move between the assertion and the draw.
func _wire_book() -> void:
	_registry = PonyRegistryScript.new()
	_registry.load_all(PONY_DIR)
	_compendium = CompendiumScript.new()
	_regions = RegionRegistryScript.new()
	_regions.load_all(RegionRegistryScript.REGION_DIR)
	_board = RequestBoardScript.new(7, _registry, _region_ids())
	_board.seed_tutorial()
	_world = WorldStateScript.new(7)
	_world.pin(WorldStateScript.Phase.DAY, WorldStateScript.Weather.CLEAR)
	_menu.compendium = _compendium
	_menu.registry = _registry
	_menu.regions = _regions
	_menu.board = _board
	_menu.world_state = _world


func _region_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for region: RegionData in _regions.all():
		out.append(region.id)
	return out


## The compendium row for `id`, found by walking the roster the menu itself reports rather
## than by hard coding a position: the list is PonyRegistry.all()'s order and a roster edit
## moves everybody.
func _row_for(id: StringName) -> String:
	var entries: Array[PonyData] = _menu.roster()
	var rows: Array[String] = _menu.compendium_rows()
	for i in range(entries.size()):
		if entries[i].id == id:
			return rows[i]
	return "<%s is not in the roster>" % id


func test_opens_on_main_with_resume_selected() -> void:
	watch_signals(_menu)
	assert_true(_menu.open())
	assert_true(_menu.is_open())
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)
	assert_eq(_menu.selected_index(), PauseMenu.Row.RESUME)
	assert_signal_emitted(_menu, "opened")


func test_can_open_callable_can_refuse() -> void:
	_menu.can_open = func() -> bool: return false
	assert_false(_menu.open())
	assert_false(_menu.is_open())


func test_resume_closes() -> void:
	_menu.open()
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_false(_menu.is_open())
	assert_signal_emitted(_menu, "closed")


func test_save_and_quit_emit_requests() -> void:
	_menu.open()
	watch_signals(_menu)
	_menu.move_selection(PauseMenu.Row.SAVE)
	_menu.confirm()
	assert_signal_emitted(_menu, "save_requested")
	assert_true(_menu.is_open(), "saving does not close the menu")
	_menu.move_selection(PauseMenu.Row.QUIT - PauseMenu.Row.SAVE)
	_menu.confirm()
	assert_signal_emitted(_menu, "quit_requested")


func test_settings_page_adjusts_the_settings_object() -> void:
	_menu.open()
	_menu.move_selection(PauseMenu.Row.SETTINGS)
	assert_true(_menu.confirm())
	assert_eq(_menu.page(), PauseMenu.Page.SETTINGS)
	watch_signals(_menu)
	# row 0 volume, row 1 ambient, row 2 effects, row 3 sensitivity, row 4 invert
	_menu.adjust(-1)
	assert_almost_eq(_settings.master_volume, 0.9, 0.0001)
	_menu.move_selection(PauseMenu.SettingRow.SENSITIVITY)
	_menu.adjust(1)
	assert_gt(_settings.mouse_sensitivity, SettingsScript.SENSITIVITY_DEFAULT)
	_menu.move_selection(PauseMenu.SettingRow.INVERT - PauseMenu.SettingRow.SENSITIVITY)
	_menu.adjust(1)
	assert_true(_settings.invert_look)
	assert_signal_emitted(_menu, "settings_changed")


func test_cancel_on_settings_returns_to_main_and_on_main_closes() -> void:
	_menu.open()
	_menu.move_selection(PauseMenu.Row.SETTINGS)
	_menu.confirm()
	_menu.back()
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)
	assert_true(_menu.is_open())
	_menu.back()
	assert_false(_menu.is_open())


## Both pages, as the name promises. The two have DIFFERENT row counts (eight on MAIN,
## three on SETTINGS) and _row_count() is the one thing that knows which, so a wrap that is
## only exercised on MAIN would let the settings page wrap past its last row into a fourth
## that is not drawn.
func test_selection_wraps_on_both_pages() -> void:
	_menu.open()
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), PauseMenu.Row.QUIT,
		"up from the first row lands on the last one on MAIN")
	_menu.move_selection(1)
	assert_eq(_menu.selected_index(), PauseMenu.Row.RESUME, "...and down comes back round")

	_menu.move_selection(PauseMenu.Row.SETTINGS)
	assert_true(_menu.confirm(), "the settings page opens")
	assert_eq(_menu.page(), PauseMenu.Page.SETTINGS)
	assert_eq(_menu.selected_index(), 0, "on its first row")
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), _menu.settings_row_count() - 1,
		"up from the first row lands on the last settings row (the last key)")
	_menu.move_selection(1)
	assert_eq(_menu.selected_index(), PauseMenu.SettingRow.VOLUME,
		"...and down comes back round to the first")


# --- the compendium page ---------------------------------------------------------------

func test_open_page_lands_straight_on_the_compendium() -> void:
	_wire_book()
	watch_signals(_menu)
	assert_true(_menu.open_page(PauseMenu.Page.COMPENDIUM))
	assert_true(_menu.is_open())
	assert_eq(_menu.page(), PauseMenu.Page.COMPENDIUM)
	assert_eq(_menu.selected_index(), 0, "on the first character")
	assert_signal_emitted(_menu, "opened")


func test_open_page_refuses_a_page_number_this_menu_does_not_have() -> void:
	_wire_book()
	assert_false(_menu.open_page(99), "an unknown page must not leave the menu on a blank")
	assert_false(_menu.is_open())


func test_open_page_obeys_can_open() -> void:
	_wire_book()
	_menu.can_open = func() -> bool: return false
	assert_false(_menu.open_page(PauseMenu.Page.REQUESTS))
	assert_false(_menu.is_open())


func test_the_compendium_row_on_main_opens_the_page() -> void:
	_wire_book()
	_menu.open()
	_menu.move_selection(PauseMenu.Row.COMPENDIUM)
	assert_true(_menu.confirm())
	assert_eq(_menu.page(), PauseMenu.Page.COMPENDIUM)
	_menu.back()
	_menu.move_selection(PauseMenu.Row.REQUESTS - PauseMenu.Row.COMPENDIUM)
	assert_true(_menu.confirm())
	assert_eq(_menu.page(), PauseMenu.Page.REQUESTS)


## The header is measured against the REAL roster, so the total is whatever ships; what this
## pins is that the three numbers are caught, total and seen, in that order, and that they
## are the same numbers Compendium itself reports.
##
## AND THAT "seen" COUNTS THE CAUGHT ONES. Two caught and one seen is THREE seen: the player
## has laid eyes on every pony she has ever caught, and a header whose seen count fell as
## she caught more of them read as the book forgetting. Compendium.count(SEEN) on its own is
## "seen and not yet caught", which is why the sum is done here rather than left to it.
func test_the_header_counts_match_a_hand_marked_compendium() -> void:
	_wire_book()
	_compendium.mark_caught(&"twilight")
	_compendium.mark_caught(&"carrottop")
	_compendium.mark_seen(&"applejack")
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	var total := _menu.roster().size()
	assert_eq(total, 43, "the shipped roster")
	assert_eq(_menu.compendium_header(), "2 of %d caught, 3 seen" % total)
	assert_eq(_compendium.count(CompendiumScript.State.CAUGHT, _registry), 2)
	assert_eq(_compendium.count(CompendiumScript.State.SEEN, _registry), 1,
		"the book itself still counts SEEN as the rung of the ladder she is on")


func test_the_header_second_line_is_the_hour_and_the_weather() -> void:
	_wire_book()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	assert_eq(_menu.compendium_now(), "Now: Day, clear")
	_menu.world_state = null
	assert_eq(_menu.compendium_now(), "", "no clock, no line")


## The homestead is not a RegionData, so its row is built by hand and has to come first.
func test_the_zone_tallies_put_the_ranch_before_the_regions() -> void:
	_wire_book()
	_compendium.mark_caught(&"twilight")
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	var rows: Array[String] = _menu.compendium_region_rows()
	assert_eq(rows.size(), 1 + _regions.all().size(), "the ranch plus every region")
	assert_eq(rows[0], "Ranch: 1 of %d" % _registry.by_zone(&"ranch").size())
	assert_eq(rows[1], "%s: 0 of %d" % [
		_regions.all()[0].display_name, _registry.by_zone(_regions.all()[0].id).size(),
	])


## The Strip is a region with nobody living on it, so its tally reads as a real zero rather
## than being hidden. Pinned rather than left to chance: a paved strip with no wild ponies on
## it is a true thing for the Compendium to say.
func test_the_free_region_tallies_as_a_zone_with_nobody_in_it() -> void:
	_wire_book()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	var rows: Array[String] = _menu.compendium_region_rows()
	assert_true(rows.has("The Strip: 0 of 0"), "rows were: %s" % ", ".join(rows))


func test_the_character_list_scrolls_a_window_and_wraps_round_the_whole_roster() -> void:
	_wire_book()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	var last := _menu.roster().size() - 1
	assert_eq(last, 42, "43 characters, indices 0 to 42")

	var window: Array[int] = _menu.compendium_window()
	assert_eq(window.size(), PauseMenu.PAGE_ROWS)
	assert_eq(window[0], 0)
	assert_eq(window[window.size() - 1], PauseMenu.PAGE_ROWS - 1)

	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), last, "up from the top wraps to the last character")
	window = _menu.compendium_window()
	assert_eq(window.size(), PauseMenu.PAGE_ROWS)
	assert_eq(window[window.size() - 1], last, "and the window followed her down")

	_menu.move_selection(1)
	assert_eq(_menu.selected_index(), 0, "...and back round to the first")
	assert_eq(_menu.compendium_window()[0], 0, "the window snapped back to the top")


func test_an_unseen_row_is_hidden_a_seen_row_is_a_name_and_a_caught_row_carries_her_hours() -> void:
	_wire_book()
	_compendium.mark_seen(&"twilight")
	_compendium.mark_caught(&"carrottop")
	_compendium.mark_caught(&"cloudchaser")
	_menu.open_page(PauseMenu.Page.COMPENDIUM)

	assert_eq(_row_for(&"applejack"), "???", "nobody has ever laid eyes on her")
	assert_eq(_row_for(&"twilight"), "Twilight Sparkle", "seen buys the name and nothing else")
	assert_eq(_row_for(&"carrottop"), "Carrot Top  when: dawn/day, any",
		"listed phases joined by a slash; an empty weather list is any")
	assert_eq(_row_for(&"cloudchaser"), "Cloudchaser  when: any, clear/fog",
		"and the other way round")


func test_left_and_right_do_nothing_on_the_compendium() -> void:
	_wire_book()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	watch_signals(_menu)
	_menu.adjust(1)
	_menu.adjust(-1)
	assert_eq(_menu.selected_index(), 0)
	assert_signal_not_emitted(_menu, "settings_changed")


# --- the requests page -----------------------------------------------------------------

func test_the_requests_page_lists_exactly_the_active_requests() -> void:
	_wire_book()
	_menu.open_page(PauseMenu.Page.REQUESTS)
	var rows: Array[Dictionary] = _menu.request_rows()
	var active: Array = _board.active()
	assert_eq(active.size(), 3, "the tutorial three")
	assert_eq(rows.size(), active.size())
	for i in range(active.size()):
		var request: Dictionary = active[i]
		assert_eq(String(rows[i]["text"]), String(request["text"]),
			"a request that only needs one of anything carries no progress")
		assert_eq(String(rows[i]["value"]), "%d bits" % int(request["reward_bits"]))
	assert_eq(_menu.board_note(), "Finish one to get a new one.",
		"the note at the top of the board says where the next one comes from")


## A finished request has already been paid by ranch.gd, so it drops off the page the moment
## its progress completes rather than sitting there as something still to do.
func test_a_finished_request_leaves_the_page() -> void:
	_wire_book()
	_menu.open_page(PauseMenu.Page.REQUESTS)
	assert_eq(_menu.request_rows().size(), 3)
	_board.on_sold(PonyData.Rarity.COMMON, 1)
	assert_eq(_menu.request_rows().size(), 2, "Sell a gem is done and gone")


## A board with an EMPTY registry and no regions can only draw SELL_GEMS_OF_RARITY, whose
## count is always at least three (RequestBoard.SELL_GEMS_COUNT_MIN), which is the only way
## to get a multi count request deterministically out of a seeded draw.
func test_a_request_that_takes_several_shows_its_progress() -> void:
	_wire_book()
	var no_regions: Array[StringName] = []
	var gems: RequestBoard = RequestBoardScript.new(11, PonyRegistryScript.new(), no_regions)
	gems.fill([])
	_menu.board = gems
	_menu.open_page(PauseMenu.Page.REQUESTS)

	var active: Array = gems.active()
	assert_eq(active.size(), 3)
	var rows: Array[Dictionary] = _menu.request_rows()
	for i in range(active.size()):
		var request: Dictionary = active[i]
		assert_gt(int(request["count"]), 1, "every draw here is a sell several gems request")
		assert_eq(String(rows[i]["text"]), "%s  %d / %d" % [
			String(request["text"]), int(request["progress"]), int(request["count"]),
		])


func test_a_food_reward_is_spelled_out_with_its_amount() -> void:
	_wire_book()
	var one: Array[StringName] = []
	var finder: RequestBoard = RequestBoardScript.new(5, _registry, one)
	finder.fill([])
	_menu.board = finder
	_menu.open_page(PauseMenu.Page.REQUESTS)
	var rows: Array[Dictionary] = _menu.request_rows()
	var active: Array = finder.active()
	var checked := 0
	for i in range(active.size()):
		var request: Dictionary = active[i]
		if String(request["reward_food"]).is_empty():
			continue
		checked += 1
		assert_eq(String(rows[i]["value"]), "%d bits and %d %s" % [
			int(request["reward_bits"]), RequestBoardScript.SEE_CHARACTER_FOOD_COUNT,
			String(request["reward_food"]),
		])
	assert_gt(checked, 0, "this seed draws at least one request that pays food")


func test_accept_does_nothing_on_either_reading_page() -> void:
	_wire_book()
	for page in [PauseMenu.Page.COMPENDIUM, PauseMenu.Page.REQUESTS]:
		_menu.open_page(page)
		watch_signals(_menu)
		assert_false(_menu.confirm(), "neither page is a transaction")
		assert_eq(_menu.page(), page, "and it stays where it was")
		assert_true(_menu.is_open())
		assert_signal_not_emitted(_menu, "closed")
		assert_signal_not_emitted(_menu, "save_requested")


# --- the ledger page --------------------------------------------------------------------

func test_the_ledger_page_repeats_the_statement() -> void:
	_menu.statement_provider = func() -> Array[String]:
		return LedgerScript.new().statement_lines("Moonbeam", 1, 0, 2)
	assert_true(_menu.open_page(PauseMenu.Page.LEDGER))
	assert_eq(_menu.page(), PauseMenu.Page.LEDGER)
	var joined: String = "\n".join(_menu.ledger_rows())
	assert_true(joined.contains("Sponsorship balance"))
	assert_true(joined.contains("Moonbeam"))
	assert_false(joined.contains("--"))


func test_the_ledger_page_says_so_when_there_is_no_ledger_to_show() -> void:
	_menu.statement_provider = Callable()
	assert_eq(_menu.ledger_rows(), [PauseMenu.EMPTY_TEXT])


# --- back, and a menu with nothing behind it --------------------------------------------

func test_cancel_from_each_reading_page_returns_to_its_own_row_on_main() -> void:
	_wire_book()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	_menu.back()
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)
	assert_true(_menu.is_open(), "back off a sub page does not close the menu")
	assert_eq(_menu.selected_index(), PauseMenu.Row.COMPENDIUM)

	_menu.open_page(PauseMenu.Page.REQUESTS)
	_menu.back()
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)
	assert_eq(_menu.selected_index(), PauseMenu.Row.REQUESTS)
	_menu.back()
	assert_false(_menu.is_open(), "and main still closes")


## THE ROW ORDER IS PINNED, and this is the test that pins it. It used to be the four rarity
## tiers in enum order, unioned by hand here and in two other files; it is PonyRegistry's own
## ids() order now (the roster sorted by id TEXT, which for this roster reads as the
## characters' names alphabetically). Either is a defensible page; what is not defensible is
## the order changing under the player because somebody rewired a helper, which is exactly
## what happened once already. Asserted against registry.ids() rather than against a written
## out list, so a roster edit needs no edit here and a re-ordering still fails.
func test_the_character_list_is_in_the_registrys_own_order() -> void:
	_wire_book()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)

	var ids: Array[StringName] = _registry.ids()
	var drawn: Array[StringName] = []
	for data: PonyData in _menu.roster():
		drawn.append(data.id)
	assert_eq(drawn, ids, "the page draws the roster in registry.ids() order")
	assert_eq(_menu.compendium_rows().size(), ids.size(),
		"one row per character, so a row index IS a roster index")

	# The rows themselves, not just the array behind them: compendium_rows() and the roster
	# are read by index against each other (see _row_for() and _draw_compendium()), so a row
	# list in some other order would put every name against somebody else's hours.
	var rows: Array[String] = _menu.compendium_rows()
	_compendium.mark_caught(ids[0])
	_compendium.mark_caught(ids[ids.size() - 1])
	rows = _menu.compendium_rows()
	assert_true(rows[0].begins_with(_registry.by_id(ids[0]).display_name),
		"the first row is the first id's character")
	assert_true(rows[ids.size() - 1].begins_with(
		_registry.by_id(ids[ids.size() - 1]).display_name),
		"and the last row is the last id's")


## HALF WIRED IS NOT WIRED. A registry with no compendium behind it is the shape a partial
## injection leaves (ranch.gd sets all five, but the boot shutter and these tests set what
## they need), and it is the one arrangement where the page could draw a full roster of
## "???" and look like a player who had seen nobody. has_book() already decides what is
## drawn; the row list and the cursor now follow the same decision instead of counting the
## roster on their own.
func test_a_registry_with_no_book_behind_it_draws_nothing_rather_than_a_page_of_blanks()\
		-> void:
	_wire_book()
	_menu.compendium = null
	_menu.open_page(PauseMenu.Page.COMPENDIUM)

	assert_false(_menu.has_book(), "no compendium, no book")
	assert_false(_menu.roster().is_empty(), "the registry is still there to be counted")
	assert_true(_menu.compendium_rows().is_empty(),
		"43 rows of ??? would be a claim about the player rather than an empty page")
	assert_eq(_menu.compendium_header(), "")

	_menu.move_selection(1)
	assert_eq(_menu.selected_index(), 0,
		"one line of EMPTY_TEXT is one row, and the cursor stays on it")


## The menu is instantiated bare by these tests and by the boot shutter, neither of which
## has a ranch to inject anything. Both pages have to draw, and both have to survive being
## scrolled, with all five sources null.
func test_both_pages_draw_with_nothing_injected() -> void:
	assert_true(_menu.open_page(PauseMenu.Page.COMPENDIUM))
	assert_false(_menu.has_book())
	assert_eq(_menu.compendium_header(), "")
	assert_eq(_menu.compendium_now(), "")
	assert_true(_menu.compendium_region_rows().is_empty())
	assert_true(_menu.compendium_rows().is_empty())
	assert_true(_menu.compendium_window().is_empty())
	_menu.move_selection(1)
	assert_eq(_menu.selected_index(), 0, "one empty row, and it does not divide by zero")

	assert_true(_menu.open_page(PauseMenu.Page.REQUESTS))
	assert_true(_menu.request_rows().is_empty())
	_menu.move_selection(-1)
	assert_eq(_menu.selected_index(), 0)
	_menu.back()
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)


## A registry with no compendium behind it (or the other way round) is the half wired case,
## and it must read as empty rather than as a roster of question marks.
func test_a_half_wired_compendium_reads_as_empty() -> void:
	_registry = PonyRegistryScript.new()
	_registry.load_all(PONY_DIR)
	_menu.registry = _registry
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	assert_false(_menu.has_book(), "a roster with no book is not a book")
	assert_eq(_menu.compendium_header(), "")
	assert_true(_menu.compendium_region_rows().is_empty())


func test_a_delivered_character_reads_as_delivered_and_still_counts_as_caught() -> void:
	_wire_book()
	# THROUGH StoryWording.processed_label(), not the literal string: this used to pass
	# only because story_chapter defaults to 0 and PROCESSED_LABELS[0] happens to be
	# "Delivered :)", so a reword of the SUNNY label would have failed this test and the two
	# below it in two different ways (final review, MINOR 5).
	var wording = preload("res://systems/story_wording.gd")
	var first: PonyData = _registry.all()[0]
	_compendium.mark_processed(first.id)
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	assert_true(_menu.compendium_header().contains("1 of"))
	assert_true(_row_for(first.id).contains(wording.processed_label(_menu.story_chapter)))


# --- the Mail page ---------------------------------------------------------------------

## The rows ranch.gd hands the page, in exactly the shape it builds them in (Task 6's
## Ranch.mail_rows()), so this file tests the page against the contract rather than against
## a story it built for itself.
func _wire_mail() -> void:
	var rows: Array[Dictionary] = [
		{"id": "sunny_mailbox", "sender": "Cloudsdale Weather Corporation",
			"title": "Your mailbox is installed",
			"body": ["Dear Moonbeam,", "", "The flag goes up when something is waiting."],
			"read": true, "replied": "", "reply": 0},
		{"id": "weather_survey", "sender": "Cloudsdale Weather Corporation",
			"title": "Employee Appreciation Survey",
			"body": ["Dear Moonbeam,", "", "Which of your ponies is most special to you?"],
			"read": false, "replied": "", "reply": 1},
	]
	_menu.mail_provider = func() -> Array[Dictionary]: return rows
	_menu.mail_ponies_provider = func() -> Array[Dictionary]:
		return [{"uid": "u1", "name": "Trixie", "coat": ""},
			{"uid": "u2", "name": "Pony", "coat": "Butter"}]


## `count` LETTERS, IDS "letter_0".."letter_(count-1)" IN POSTING ORDER, so mail_rows()'s
## newest-first reversal hands them back as "letter_(count-1)" down to "letter_0" -- built for
## the windowing regression below, which needs more than ENVELOPES_ON_SCREEN of them.
func _wire_many_mail(count: int) -> void:
	var rows: Array[Dictionary] = []
	for i in count:
		rows.append({"id": "letter_%d" % i, "sender": "Cloudsdale Weather Corporation",
			"title": "Letter %d" % i, "body": ["Dear Moonbeam,"],
			"read": true, "replied": "", "reply": 0})
	_menu.mail_provider = func() -> Array[Dictionary]: return rows
	_menu.mail_ponies_provider = func() -> Array[Dictionary]: return []


func test_the_mail_page_lists_the_newest_letter_first() -> void:
	_wire_mail()
	_menu.open()
	assert_true(_menu.open_page(PauseMenu.Page.MAIL))
	var rows: Array[Dictionary] = _menu.mail_rows()
	assert_eq(rows.size(), 2)
	assert_eq(String(rows[0]["id"]), "weather_survey", "newest first")
	assert_false(bool(rows[0]["read"]))


func test_a_bare_mail_page_says_so_rather_than_drawing_nothing() -> void:
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	assert_eq(_menu.mail_rows().size(), 0)
	assert_true(PauseMenu.EMPTY_TEXT in _menu.mail_lines())


func test_confirming_on_an_envelope_opens_it_and_says_it_was_opened() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	watch_signals(_menu)
	assert_true(_menu.confirm())
	assert_eq(_menu.open_letter_id(), &"weather_survey")
	assert_signal_emitted_with_parameters(_menu, "mail_opened", [&"weather_survey"])
	var lines: Array[String] = _menu.letter_lines()
	assert_true("Which of your ponies is most special to you?" in lines)


func test_cancel_walks_back_out_of_a_letter_and_then_out_of_the_page() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	_menu.confirm()
	assert_eq(_menu.open_letter_id(), &"weather_survey")
	_menu.back()
	assert_eq(_menu.open_letter_id(), &"", "back closes the letter, not the page")
	assert_eq(_menu.page(), PauseMenu.Page.MAIL)
	_menu.back()
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)
	assert_eq(_menu.selected_index(), PauseMenu.Row.MAIL, "the cursor lands on its own row")


func test_a_letter_with_a_picker_offers_every_pony_she_owns() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	_menu.confirm()
	var rows: Array[Dictionary] = _menu.reply_rows()
	assert_eq(rows.size(), 2)
	assert_eq(String(rows[0]["label"]), "Trixie")
	assert_eq(String(rows[1]["label"]), "Butter Pony", "the crowd share a name; the coat sorts them")
	assert_eq(String(rows[1]["choice"]), "u2")


func test_answering_the_picker_emits_the_choice_once_and_leaves_the_letter() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	_menu.confirm()
	watch_signals(_menu)
	_menu.move_selection(1)
	assert_true(_menu.confirm())
	assert_signal_emitted_with_parameters(_menu, "mail_reply", [&"weather_survey", "u2"])
	assert_eq(_menu.open_letter_id(), &"", "answering hands the page back to the list")


func test_a_letter_with_no_reply_control_has_no_rows_to_sit_on() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	_menu.move_selection(1)
	assert_true(_menu.confirm())
	assert_eq(_menu.open_letter_id(), &"sunny_mailbox")
	assert_eq(_menu.reply_rows().size(), 0)
	assert_false(_menu.confirm(), "there is nothing on this page to confirm")


func test_the_mail_row_on_main_opens_the_page() -> void:
	_wire_mail()
	_menu.open()
	for i in range(PauseMenu.Row.MAIL):
		_menu.move_selection(1)
	assert_eq(_menu.selected_index(), PauseMenu.Row.MAIL)
	assert_true(_menu.confirm())
	assert_eq(_menu.page(), PauseMenu.Page.MAIL)


func test_nothing_the_mail_page_draws_carries_a_dash() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	var lines: Array[String] = _menu.mail_lines()
	_menu.confirm()
	lines.append_array(_menu.letter_lines())
	for row: Dictionary in _menu.reply_rows():
		lines.append(String(row["label"]))
	for line: String in lines:
		assert_false(line.contains("--"), "double hyphen: %s" % line)
		assert_false(line.contains(char(0x2014)), "em dash: %s" % line)


func test_a_delivered_pony_reads_in_the_words_of_the_chapter_she_was_delivered_in() -> void:
	_wire_book()
	var wording = preload("res://systems/story_wording.gd")
	var story = preload("res://systems/story.gd")
	var first: PonyData = _menu.roster()[0]
	_compendium.mark_processed(first.id)
	_menu.story_chapter = story.Chapter.SUNNY
	_menu.open()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	var rows: Array[String] = _menu.compendium_rows()
	assert_true(rows[0].contains(wording.processed_label(story.Chapter.SUNNY)))


func test_the_pony_she_named_on_the_survey_carries_her_star_in_the_book() -> void:
	_wire_book()
	var wording = preload("res://systems/story_wording.gd")
	var first: PonyData = _menu.roster()[0]
	_compendium.mark_processed(first.id)
	_menu.employees_choice = first.id
	_menu.open()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	assert_true(_menu.compendium_rows()[0].contains(wording.EMPLOYEES_CHOICE))


func test_the_requests_page_carries_the_boards_note_for_this_chapter() -> void:
	_wire_book()
	var wording = preload("res://systems/story_wording.gd")
	var story = preload("res://systems/story.gd")
	_board.set_chapter(story.Chapter.WEATHER)
	_menu.open()
	_menu.open_page(PauseMenu.Page.REQUESTS)
	assert_eq(_menu.board_note(), wording.board_note(story.Chapter.WEATHER))


## v1: one row per audio bus (Master, Music, Ambient, Effects, Menus, Voices), the look
## controls, the picture, then one row per rebindable key.
func test_the_settings_page_has_a_row_per_bus_the_picture_and_the_keys() -> void:
	assert_eq(PauseMenu.SettingRow.VOLUME, 0)
	assert_eq(PauseMenu.SettingRow.KEYS, 11)
	_menu.open_page(PauseMenu.Page.SETTINGS)
	assert_eq(_menu.settings_row_count(), 11 + SettingsScript.REBINDABLE.size())
	var names: Array = _menu.settings_rows().map(func(r: Array) -> String: return str(r[0]))
	for want in ["Master volume", "Music", "Ambience", "Effects", "Menus", "Voices",
			"Picture quality", "Fullscreen", "Vsync", "Jump", "Interact"]:
		assert_has(names, want)


func test_adjusting_the_ambient_row_moves_the_ambient_volume_and_nothing_else() -> void:
	_menu.open_page(PauseMenu.Page.SETTINGS)
	_menu.move_selection(PauseMenu.SettingRow.AMBIENT)
	var master_before: float = _settings.master_volume
	_menu.adjust(-1)
	assert_lt(_settings.ambient_volume, 1.0)
	assert_almost_eq(_settings.master_volume, master_before, 0.0001)
	assert_almost_eq(_settings.effects_volume, 1.0, 0.0001)
	assert_almost_eq(_settings.music_volume, 0.8, 0.0001, "the music is its own slider")


# --- the pointer, and the copy ---------------------------------------------------------

## THE OWNER MISREAD "Save the ranch" AS SOMETHING THAT HAPPENED TO THE RANCH rather than as
## a file operation. This is the copy fix, pinned so it cannot drift back.
func test_the_main_page_says_save_game_and_load_game() -> void:
	assert_eq(PauseMenu.MAIN_ROWS[PauseMenu.Row.SAVE], "Save game")
	assert_eq(PauseMenu.MAIN_ROWS[PauseMenu.Row.LOAD], "Load game")
	assert_eq(PauseMenu.MAIN_ROWS[PauseMenu.Row.MAIL], "Saddlebag copies")
	assert_eq(PauseMenu.MAIN_ROWS.size(), PauseMenu.Row.size())


func test_no_row_or_footer_on_this_menu_carries_a_dash() -> void:
	var checked := 0
	for text: String in PauseMenu.MAIN_ROWS:
		assert_false(text.contains("--"), text)
		assert_false(text.contains(char(0x2014)), text)
		checked += 1
	assert_gt(checked, 0, "the row list was actually walked")


func test_load_game_asks_the_ranch_to_load_and_only_when_there_is_a_save() -> void:
	_menu.has_save_provider = func() -> bool: return true
	_menu.open()
	watch_signals(_menu)
	_menu.take_row(PauseMenu.Row.LOAD)
	assert_signal_emitted(_menu, "load_requested")


func test_load_game_refuses_when_no_save_exists() -> void:
	_menu.has_save_provider = func() -> bool: return false
	_menu.open()
	watch_signals(_menu)
	_menu.take_row(PauseMenu.Row.LOAD)
	assert_signal_not_emitted(_menu, "load_requested",
		"a Load row on a machine with no save is a row that must refuse")


func test_pointing_moves_the_cursor_and_the_keys_still_work() -> void:
	_menu.open()
	_menu.point_at_row(PauseMenu.Row.SETTINGS)
	assert_eq(_menu.selected_index(), PauseMenu.Row.SETTINGS)
	assert_eq(_menu.hovered_index(), PauseMenu.Row.SETTINGS)
	_menu.move_selection(1)
	assert_eq(_menu.selected_index(), PauseMenu.Row.QUIT,
		"the mouse must never take the keyboard away")


func test_the_pause_menu_offers_the_pointer_a_way_out() -> void:
	var button: Button = _menu.close_button_node()
	assert_not_null(button)
	assert_eq(button.text, preload("res://ui/mouse_rows.gd").CLOSE_TEXT)
	assert_eq(button.focus_mode, Control.FOCUS_NONE)


func test_the_mail_envelopes_are_clickable_and_open_the_letter_they_name() -> void:
	_wire_mail()
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	var rects: Array[Rect2] = _menu.stage_hit_rects()
	assert_eq(rects.size(), _menu.mail_rows().size(),
		"one hit rect per envelope on the page")
	_menu.on_stage_hit(0)
	assert_eq(_menu.open_letter_id(), &"weather_survey", "the newest envelope is the top one")


## FIX ROUND 1, THE REGRESSION THIS PINS: _paint_envelopes() windows the stack on `first`,
## which follows the keyboard cursor past the first screenful; on_stage_hit() used to map a
## click through `_scroll`, which _sync_scroll() holds at 0 on every page but the compendium
## -- so a click after scrolling opened whatever was at the UNSCROLLED position instead of
## what was actually drawn under the pointer. Seven letters is two past ENVELOPES_ON_SCREEN
## (5), enough to force the window to shift.
func test_a_scrolled_mail_page_opens_the_envelope_the_click_actually_landed_on() -> void:
	_wire_many_mail(7)
	_menu.open()
	_menu.open_page(PauseMenu.Page.MAIL)
	for i in 6:
		_menu.move_selection(1)
	assert_eq(_menu.selected_index(), 6, "the keyboard walked to the last row")
	# The window is now [2..6] of mail_rows(); screen row 0 is mail_rows()[2] == "letter_4".
	_menu.on_stage_hit(0)
	assert_eq(_menu.open_letter_id(), &"letter_4",
		"row 0 on screen is whichever envelope the scrolled window actually put there")


func _wheel(button_index: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	return event


# --- M9: the Close button mirrors Escape -----------------------------------------------

func test_the_close_button_goes_back_one_layer_on_a_sub_page() -> void:
	_menu.open()
	_menu.move_selection(PauseMenu.Row.SETTINGS)
	_menu.confirm()
	assert_eq(_menu.page(), PauseMenu.Page.SETTINGS)
	_menu.close_button_node().pressed.emit()
	assert_eq(_menu.page(), PauseMenu.Page.MAIN,
		"Close on a sub-page must match Escape: one layer back, not the whole menu")
	assert_true(_menu.is_open())


func test_the_close_button_closes_the_whole_menu_on_the_main_page() -> void:
	_menu.open()
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)
	_menu.close_button_node().pressed.emit()
	assert_false(_menu.is_open(), "Close on MAIN must match Escape there too: close")


# --- M11: hover does not survive a page switch ---------------------------------------------

func test_hover_is_cleared_on_a_page_switch() -> void:
	_wire_book()
	_menu.open()
	_menu.point_at_row(PauseMenu.Row.COMPENDIUM)
	assert_eq(_menu.hovered_index(), PauseMenu.Row.COMPENDIUM)
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	assert_eq(_menu.hovered_index(), -1,
		"a roster row must not be drawn hovered under a pointer nowhere near it")


func test_hover_is_cleared_returning_to_main() -> void:
	_wire_book()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	_menu.point_at_row(0)
	assert_eq(_menu.hovered_index(), 0)
	_menu.back()
	assert_eq(_menu.page(), PauseMenu.Page.MAIN)
	assert_eq(_menu.hovered_index(), -1)


# --- I4: a click on a settings row adjusts it, it does not confirm/leave ------------------

func test_clicking_a_settings_row_adjusts_it_and_stays_on_the_page() -> void:
	_menu.open()
	_menu.move_selection(PauseMenu.Row.SETTINGS)
	_menu.confirm()
	assert_eq(_menu.page(), PauseMenu.Page.SETTINGS)
	# Ambience defaults to 0.5 (Settings.AMBIENT_DEFAULT), mid range, so a click's default
	# "increment" resolution (no laid out holder yet in this test) is never a clamped no-op --
	# master volume, at its 1.0 ceiling by default, would be.
	var before: float = _settings.ambient_volume
	watch_signals(_menu)
	_menu.take_row(PauseMenu.SettingRow.AMBIENT)
	assert_eq(_menu.page(), PauseMenu.Page.SETTINGS,
		"a settings row click must not leave the page (I2, final-review.md)")
	assert_ne(_settings.ambient_volume, before, "the click must have changed the value")
	assert_signal_emitted(_menu, "settings_changed")


func test_clicking_the_invert_row_toggles_it() -> void:
	_menu.open()
	_menu.move_selection(PauseMenu.Row.SETTINGS)
	_menu.confirm()
	var before: bool = _settings.invert_look
	_menu.take_row(PauseMenu.SettingRow.INVERT)
	assert_ne(_settings.invert_look, before)


# --- I6: the wheel scrolls the compendium and the mail archive ---------------------------

func test_the_wheel_moves_the_compendium_selection() -> void:
	_wire_book()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	assert_eq(_menu.selected_index(), 0)
	_menu._on_rows_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	assert_eq(_menu.selected_index(), 1, "wheel down must step the selection forward")
	_menu._on_rows_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert_eq(_menu.selected_index(), 0, "and wheel up must step it back")


func test_the_row_holder_can_actually_hear_the_wheel() -> void:
	# The re-review's one blocker: the scene bakes Rows at MOUSE_FILTER_IGNORE, and an
	# IGNORE control never receives gui_input at all, so the two wheel tests beside this
	# one passed by calling the handler directly while a real pointer could reach nothing.
	# _ready() must lift the holder to PASS -- this pins the wiring, not the handler.
	assert_eq(_menu._rows.mouse_filter, Control.MOUSE_FILTER_PASS,
		"an IGNORE row holder silently disconnects every wheel in the pause menu")


func test_the_wheel_follows_the_same_window_the_keyboard_does() -> void:
	_wire_book()
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	for i in PauseMenu.PAGE_ROWS:
		_menu._on_rows_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	assert_eq(_menu.selected_index(), PauseMenu.PAGE_ROWS,
		"PAGE_ROWS wheel ticks must land exactly where PAGE_ROWS move_selection(1) calls would")
	assert_true(_menu.compendium_window().has(PauseMenu.PAGE_ROWS),
		"the window must have followed the wheel past the first screenful")


func test_the_wheel_moves_the_mail_archive_selection() -> void:
	_wire_many_mail(7)
	_menu.open_page(PauseMenu.Page.MAIL)
	assert_eq(_menu.selected_index(), 0)
	_menu._on_stage_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	assert_eq(_menu.selected_index(), 1, "the stage's own wheel branch must move it too")



## v1: a key row waits for a key, binds it, and shows it; Escape cancels.
func test_a_key_row_rebinds_its_action() -> void:
	_menu.open()
	_menu.move_selection(PauseMenu.Row.SETTINGS)
	_menu.confirm()
	var jump_row: int = PauseMenu.SettingRow.KEYS + SettingsScript.REBINDABLE.find(&"jump")
	_menu.move_selection(jump_row)
	assert_true(_menu.confirm())
	assert_true(_menu.is_capturing())
	var k := InputEventKey.new()
	k.pressed = true
	k.physical_keycode = KEY_J
	assert_true(_menu.capture_key(k))
	assert_false(_menu.is_capturing())
	assert_eq(int(_menu.settings.bindings.get(&"jump", 0)), KEY_J)
	assert_eq(_menu.settings_rows().size(), _menu.settings_row_count())


func test_the_picture_and_sound_rows_adjust() -> void:
	_menu.open()
	_menu.move_selection(PauseMenu.Row.SETTINGS)
	_menu.confirm()
	_menu.move_selection(PauseMenu.SettingRow.QUALITY)
	var q: int = _menu.settings.quality
	_menu.adjust(-1)
	assert_eq(_menu.settings.quality, q - 1)
	_menu.move_selection(PauseMenu.SettingRow.MUSIC - PauseMenu.SettingRow.QUALITY)
	var m: float = _menu.settings.music_volume
	_menu.adjust(-1)
	assert_lt(_menu.settings.music_volume, m)
