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
## than by hard coding a position: the list is the rarity tiers in enum order and a roster
## edit moves everybody.
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
	# row 0 volume, row 1 sensitivity, row 2 invert
	_menu.adjust(-1)
	assert_almost_eq(_settings.master_volume, 0.9, 0.0001)
	_menu.move_selection(1)
	_menu.adjust(1)
	assert_gt(_settings.mouse_sensitivity, SettingsScript.SENSITIVITY_DEFAULT)
	_menu.move_selection(1)
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


## Both pages, as the name promises. The two have DIFFERENT row counts (six on MAIN,
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
	assert_eq(_menu.selected_index(), PauseMenu.SettingRow.INVERT,
		"up from the first row lands on the last of the THREE settings rows")
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
func test_the_header_counts_match_a_hand_marked_compendium() -> void:
	_wire_book()
	_compendium.mark_caught(&"twilight")
	_compendium.mark_caught(&"carrottop")
	_compendium.mark_seen(&"applejack")
	_menu.open_page(PauseMenu.Page.COMPENDIUM)
	var total := _menu.roster().size()
	assert_eq(total, 43, "the shipped roster")
	assert_eq(_menu.compendium_header(), "2 of %d caught, 1 seen" % total)
	assert_eq(_compendium.count(CompendiumScript.State.CAUGHT, _registry), 2)


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
	assert_true(_menu.footer_text().contains("Finish one to get a new one."),
		"the footer says where the next one comes from")


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
