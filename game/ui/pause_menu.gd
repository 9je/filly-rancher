class_name PauseMenu
extends CanvasLayer
## ESCAPE OPENS THIS. It used to free the cursor and nothing else; the owner: "i also
## want pause menu instead of losing mouse control with escape". Phase 2 slice 1.
##
## Resume, Compendium, Requests, The ledger, Save, Settings, Quit. The rules are
## game/ui/build_menu.gd's: navigable without a mouse on ui_*, PROCESS_MODE_ALWAYS while
## ranch.gd pauses the tree, and it only emits. ranch.gd saves, quits, applies settings, and
## pauses or unpauses.
##
## `can_open` is how the ranch says "another menu is up": the build and market menus
## close on ui_cancel and this opens on `pause`, both of which are Escape, so without the
## guard one keypress would close one menu and open this one in the same frame.
##
## THE THREE READING PAGES (phase 2 slice 5, and LEDGER in phase 3 slice 1). COMPENDIUM is
## what the player knows of the roster; REQUESTS is what the board is asking for; LEDGER is
## the Company's own statement, repeated rather than re-derived (see ledger_rows()). All
## three are READ ONLY: ui_accept does nothing on any of them, because none is a
## transaction. A request is paid by ranch.gd the moment its progress completes
## (game/world/ranch.gd's _pay_out), never by hand from here, so a "claim" row would be a
## button for something that has already happened; the balance is paid down at the Depot,
## never from this page.
##
## EVERYTHING THESE PAGES DRAW IS INJECTED AND MAY BE NULL. ranch.gd sets `compendium`,
## `registry`, `regions`, `board`, `world_state` and `statement_provider` when it binds this
## menu (game/world/ranch.gd, _bind_pause_menu).
## Nothing here ever loads a registry or reaches for GameState itself: this menu is
## instantiated bare by its own tests and by the boot shutter, neither of which has a ranch
## behind it, and a page that loaded the roster off disk to draw itself would make those two
## pay for a ranch they do not have. A page whose sources are missing says EMPTY_TEXT and
## nothing else.
##
## THE ROSTER ORDER IS PonyRegistry.all()'s, which is the roster sorted by id text. It is
## the registry's one stated total order, and it is the same walk Compendium makes to count
## the book (game/systems/compendium.gd, _all_data), which is what makes the header's counts
## and the list below it agree row for row. It used to be the rarity tiers in enum order,
## unioned by hand here and again in two other files; the tier a character belongs to is
## still on screen, in the colour of her row.

const SettingsScript := preload("res://systems/settings.gd")
const CompendiumScript := preload("res://systems/compendium.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const HudScript := preload("res://ui/hud.gd")
const MenuStyleScript := preload("res://ui/menu_style.gd")

enum Page { MAIN, SETTINGS, COMPENDIUM, REQUESTS, LEDGER }
enum Row { RESUME, COMPENDIUM, REQUESTS, LEDGER, SAVE, SETTINGS, QUIT }
enum SettingRow { VOLUME, SENSITIVITY, INVERT }

const MAIN_ROWS := ["Resume", "Compendium", "Requests", "The ledger", "Save the ranch",
	"Settings", "Quit to desktop"]

## How many character rows of the compendium are on screen at once. The roster is 43 long
## and the panel is not, so the list is a window over it rather than the whole thing.
const PAGE_ROWS := 10

## The homestead is a zone every bit as much as the catalogued regions are, but it is not a
## RegionData at all, so its row is built by hand and goes first: it is where the player
## starts and where she spends most of her time. See game/systems/region_registry.gd.
##
## THE STRIP IS NOT AN EXCEPTION TO THAT, and its row is deliberate. RegionRegistry used to
## carry only the places you buy a permit for; since phase 3 slice 2 it also carries the
## free paved Strip (permit_cost 0), which is a RegionData like any other and therefore gets
## its zone row here like any other. Nobody is caught there (its spawn list is empty on
## purpose: it is a casino, not a meadow), so the row reads "0 of 0", which is the truth and
## is what a zone with nobody in it should say.
const RANCH_ZONE := &"ranch"
const RANCH_NAME := "Ranch"

## What a page says when the thing it draws was never injected, or is empty. Not an error:
## this menu is instantiated without a ranch by its own tests and by the boot shutter.
const EMPTY_TEXT := "Nothing to show yet."

## Both halves of a character's "when" line when she has no restriction on that half.
## PonyData carries an EMPTY array to mean "any" in each of `phases` and `weathers`
## independently (game/systems/pony_data.gd), so the two are answered separately.
const ANY_TEXT := "any"


@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer

signal opened()
signal closed()
signal save_requested()
signal quit_requested()
signal settings_changed()

var settings: Settings = null
## `func() -> bool`. Invalid means "always allowed".
var can_open := Callable()

## The five things the two reading pages draw, all injected by ranch.gd and all allowed to
## stay null forever. See the class comment.
var compendium: Compendium = null
var registry: PonyRegistry = null
var regions: RegionRegistry = null
var board: RequestBoard = null
var world_state: WorldState = null

## THE LEDGER PAGE (task 9). `statement_provider` is a `func() -> Array[String]` that
## repeats the Depot's own statement rather than re-deriving it here, so the pause menu and
## the Depot counter can never disagree about what she owes. It is injected the same way the
## five above are, and it is the WHOLE of what this page needs: a Ledger and a PlayerLook
## were injected alongside it for a while and never read, because the statement they would
## have been read for arrives already rendered. See ledger_rows().
var statement_provider := Callable()

var _page: int = Page.MAIN
var _selected := 0
## First roster index drawn on the COMPENDIUM page. Follows `_selected`; see _sync_scroll().
var _scroll := 0
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)
	MenuStyleScript.style_label(_title, MenuStyleScript.TITLE_SIZE, MenuStyleScript.COLOR_TITLE)
	_title.text = "PAUSED"
	visible = false


func open() -> bool:
	if _open:
		return false
	if can_open.is_valid() and not bool(can_open.call()):
		return false
	if settings == null:
		settings = SettingsScript.new()
	_page = Page.MAIN
	_selected = Row.RESUME
	_scroll = 0
	_open = true
	visible = true
	_refresh()
	opened.emit()
	return true


## Open (if it is not open already) and land straight on `page`. This is how the request
## board's E prompt reaches the REQUESTS page without walking the player through the main
## menu: ranch.gd looks the page number up out of this script's own constant map and calls
## here (game/world/ranch.gd, _open_request_page).
##
## Returns false, and changes nothing, if `can_open` refuses or `page` is not a real Page;
## an unknown page number must not leave the menu on a blank it cannot draw.
func open_page(page: int) -> bool:
	if not (page in Page.values()):
		return false
	if not _open and not open():
		return false
	_page = page
	_selected = 0
	_scroll = 0
	_refresh()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


func page() -> int:
	return _page


func selected_index() -> int:
	return _selected


func _row_count() -> int:
	match _page:
		Page.SETTINGS:
			return SettingRow.size()
		Page.COMPENDIUM:
			# compendium_rows(), not roster(): a page that cannot draw shows one line of
			# EMPTY_TEXT, and the cursor has to have exactly that one row to sit on. The two
			# were separately derived and could disagree the moment a registry arrived
			# without a compendium behind it.
			return maxi(1, compendium_rows().size())
		Page.REQUESTS:
			return maxi(1, request_rows().size())
		Page.LEDGER:
			# The ledger page draws only notes (_draw_ledger(), _add_note()), never a
			# selectable row, so there is exactly one cursor position on it: nowhere.
			return 1
	return MAIN_ROWS.size()


func move_selection(step: int) -> void:
	_selected = posmod(_selected + step, _row_count())
	_sync_scroll()
	_refresh()


## Left or right on a settings row. Nothing on any other page: the compendium and the
## request board have no adjustable anything, and this is the one place that decides so.
func adjust(direction: int) -> void:
	if _page != Page.SETTINGS or settings == null:
		return
	match _selected:
		SettingRow.VOLUME:
			settings.step_volume(direction)
		SettingRow.SENSITIVITY:
			settings.step_sensitivity(direction)
		SettingRow.INVERT:
			settings.toggle_invert()
	settings_changed.emit()
	_refresh()


func confirm() -> bool:
	if _page == Page.SETTINGS:
		if _selected == SettingRow.INVERT:
			adjust(1)
			return true
		return false
	if _page == Page.COMPENDIUM or _page == Page.REQUESTS or _page == Page.LEDGER:
		# Read only pages; see the class comment.
		return false
	match _selected:
		Row.RESUME:
			close()
		Row.COMPENDIUM:
			open_page(Page.COMPENDIUM)
		Row.REQUESTS:
			open_page(Page.REQUESTS)
		Row.LEDGER:
			open_page(Page.LEDGER)
		Row.SAVE:
			save_requested.emit()
		Row.SETTINGS:
			_page = Page.SETTINGS
			_selected = 0
			_refresh()
		Row.QUIT:
			quit_requested.emit()
	return true


## Cancel: a sub page goes back to main WITH ITS OWN ROW SELECTED, so cancelling out of the
## compendium leaves the cursor on "Compendium" rather than back at the top; main closes.
func back() -> void:
	match _page:
		Page.SETTINGS:
			_return_to_main(Row.SETTINGS)
		Page.COMPENDIUM:
			_return_to_main(Row.COMPENDIUM)
		Page.REQUESTS:
			_return_to_main(Row.REQUESTS)
		Page.LEDGER:
			_return_to_main(Row.LEDGER)
		_:
			close()


func _return_to_main(row: int) -> void:
	_page = Page.MAIN
	_selected = row
	_scroll = 0
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed(&"pause"):
			if open():
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down"):
		move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_up"):
		move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left"):
		adjust(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right"):
		adjust(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		confirm()
		get_viewport().set_input_as_handled()


# --- the compendium ------------------------------------------------------------------------

## Every character in `registry`, in roster order. Empty (never null) when no registry was
## injected, so every caller can iterate the result unconditionally. See the class comment
## on what that order is.
##
## THE ORDER IS DELIBERATE, NOT INHERITED: it is PonyRegistry.ids()' own (the roster sorted
## by id text, which for this roster reads as the characters' names alphabetically), and
## test_pause_menu.gd pins it so it cannot change again without somebody saying so.
func roster() -> Array[PonyData]:
	if registry == null:
		return [] as Array[PonyData]
	return registry.all()


## Whether the COMPENDIUM page has enough injected to draw anything at all.
func has_book() -> bool:
	return compendium != null and registry != null and not roster().is_empty()


## "12 of 43 caught, 17 seen". Empty when there is nothing to count.
##
## SEEN COUNTS THE CAUGHT ONES TOO, because that is what the word means to the player: she
## has laid eyes on every pony she has ever caught, and a header whose "seen" fell as she
## caught more of them read as the book forgetting. Compendium.State is a ladder, not a set
## of labels (UNSEEN, then SEEN, then CAUGHT), so `count(SEEN)` alone is the number of
## characters seen AND NOT YET CAUGHT, which is a useful number for nothing on this page.
## game/world/ranch.gd's RANCH collection line adds the two the same way.
func compendium_header() -> String:
	if not has_book():
		return ""
	# A delivered pony still counts as caught, since she was, on her way to the Depot,
	# so PROCESSED is folded into the same tally rather than kept as a fourth number
	# nobody reads.
	var caught: int = compendium.count(CompendiumScript.State.CAUGHT, registry) \
		+ compendium.count(CompendiumScript.State.PROCESSED, registry)
	return "%d of %d caught, %d seen" % [
		caught,
		compendium.total(registry),
		compendium.count(CompendiumScript.State.SEEN, registry) + caught,
	]


## The header's second line: which conditions hold right now, so the "when:" lines below it
## can be read against something. Empty string when no clock was injected.
func compendium_now() -> String:
	if world_state == null:
		return ""
	return "Now: %s" % world_state.describe()


## One "%s: %d of %d" line per zone, the homestead first and then the regions in
## RegionRegistry order (cheapest permit first). Counts are CAUGHT of the zone's whole
## spawn list, which is what makes a region worth going back to.
func compendium_region_rows() -> Array[String]:
	var out: Array[String] = []
	if not has_book():
		return out
	out.append(_zone_row(RANCH_NAME, RANCH_ZONE))
	if regions != null:
		for region: RegionData in regions.all():
			out.append(_zone_row(region.display_name, region.id))
	return out


func _zone_row(zone_name: String, zone: StringName) -> String:
	return "%s: %d of %d" % [
		zone_name,
		compendium.count_in_zone(zone, CompendiumScript.State.CAUGHT, registry),
		registry.by_zone(zone).size(),
	]


## The whole character list, roster order, one string per character: "???" while she is
## UNSEEN, her name once SEEN, and her name plus her conditions once CAUGHT. What is drawn
## splits each of these into a name column and a dim value column; the string here is the
## two joined, which is the row as the player reads it.
##
## EMPTY UNLESS has_book(), which is what _draw_compendium() already decides by: with a
## registry injected but no compendium, every row here would read "???" and the page would
## be claiming the player has seen nobody rather than admitting it cannot say.
func compendium_rows() -> Array[String]:
	var out: Array[String] = []
	if not has_book():
		return out
	for data: PonyData in roster():
		var value := _entry_value(data)
		if value.is_empty():
			out.append(_entry_name(data))
		else:
			out.append("%s  %s" % [_entry_name(data), value])
	return out


## The roster indices currently on screen, in order. At most PAGE_ROWS of them.
func compendium_window() -> Array[int]:
	var out: Array[int] = []
	var n := roster().size()
	if n == 0:
		return out
	var start := clampi(_scroll, 0, maxi(0, n - PAGE_ROWS))
	for i in range(start, mini(n, start + PAGE_ROWS)):
		out.append(i)
	return out


## Keep the window under the cursor. Wrapping from the last row to the first snaps it back
## to the top rather than scrolling all the way there, which is the whole point of a wrap.
func _sync_scroll() -> void:
	var n := roster().size()
	if _page != Page.COMPENDIUM or n <= PAGE_ROWS:
		_scroll = 0
		return
	if _selected < _scroll:
		_scroll = _selected
	elif _selected >= _scroll + PAGE_ROWS:
		_scroll = _selected - PAGE_ROWS + 1
	_scroll = clampi(_scroll, 0, n - PAGE_ROWS)


## A character you have never laid eyes on is a blank with a rarity colour: the tier is the
## one thing the book tells you for free, because it is what makes an empty slot worth
## chasing.
func _entry_name(data: PonyData) -> String:
	if compendium == null or compendium.state_of(data.id) == CompendiumScript.State.UNSEEN:
		return "???"
	return data.display_name


## "when: dawn/day, any" once she is CAUGHT, and nothing before that. Catching her is what
## buys the schedule; seeing her once only proves she exists.
func _entry_value(data: PonyData) -> String:
	if compendium == null:
		return ""
	if compendium.state_of(data.id) == CompendiumScript.State.PROCESSED:
		# The Company's word for it, in the Company's tone, until the story teaches the
		# player what it means. See game/systems/compendium.gd.
		return "Delivered :)"
	if compendium.state_of(data.id) != CompendiumScript.State.CAUGHT:
		return ""
	return "when: %s, %s" % [_phases_text(data), _weathers_text(data)]


func _phases_text(data: PonyData) -> String:
	if data.phases.is_empty():
		return ANY_TEXT
	var parts: Array[String] = []
	for p: int in data.phases:
		parts.append(WorldStateScript.phase_name(p).to_lower())
	return "/".join(parts)


func _weathers_text(data: PonyData) -> String:
	if data.weathers.is_empty():
		return ANY_TEXT
	var parts: Array[String] = []
	for w: int in data.weathers:
		parts.append(WorldStateScript.weather_name(w).to_lower())
	return "/".join(parts)


func _rarity_color(rarity: int) -> Color:
	var fallback: Color = HudScript.RARITY_COLORS[PonyDataScript.Rarity.COMMON]
	var picked: Color = HudScript.RARITY_COLORS.get(rarity, fallback)
	return picked


# --- the request board ---------------------------------------------------------------------

## One entry per ACTIVE request, in board order, as {"text": String, "value": String}: the
## request as the board words it (with its progress appended when it takes more than one of
## anything) and what finishing it pays. Empty when no board was injected.
##
## active() rather than requests(): a finished request has already been paid by ranch.gd and
## is on its way off the board, so showing it would be asking for something twice.
func request_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if board == null:
		return out
	for entry in board.active():
		var req: Dictionary = entry
		var text: String = String(req.get("text", ""))
		var count: int = int(req.get("count", 1))
		if count > 1:
			text = "%s  %d / %d" % [text, int(req.get("progress", 0)), count]
		out.append({"text": text, "value": _reward_text(req)})
	return out


## "80 bits", or "40 bits and 2 hay" for the one kind that pays food as well. Both numbers
## come off the request itself, which carries reward_food_count now; the page and the toast
## ranch.gd shows on payout therefore read the same two fields and cannot drift apart.
func _reward_text(req: Dictionary) -> String:
	var bits: int = int(req.get("reward_bits", 0))
	var food: String = String(req.get("reward_food", ""))
	var count: int = int(req.get("reward_food_count", 0))
	if food.is_empty() or count <= 0:
		return "%d bits" % bits
	return "%d bits and %d %s" % [bits, count, food]


func footer_text() -> String:
	return _footer.text if _footer != null else ""


# --- the ledger ------------------------------------------------------------------------

## The Company's account, repeated from the Ledger's own statement rather than re-derived
## here, so the pause menu and the Depot counter can never disagree about what she owes.
func ledger_rows() -> Array[String]:
	if not statement_provider.is_valid():
		return [EMPTY_TEXT]
	var lines: Array[String] = []
	for line in statement_provider.call():
		lines.append(String(line))
	return lines if not lines.is_empty() else [EMPTY_TEXT]


# --- drawing -------------------------------------------------------------------------------

func _refresh() -> void:
	# remove_child BEFORE queue_free: a queued node is still a child until the end of the
	# frame, so freeing alone would leave the old rows laid out underneath the new ones for
	# one frame every time the cursor moves. Same fix as market_menu.gd's refresh().
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	match _page:
		Page.SETTINGS:
			_draw_settings()
		Page.COMPENDIUM:
			_draw_compendium()
		Page.REQUESTS:
			_draw_requests()
		Page.LEDGER:
			_draw_ledger()
		_:
			_draw_main()


func _draw_main() -> void:
	_title.text = "PAUSED"
	_footer.text = MenuStyleScript.footer_rows("select", "resume")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	for i in range(MAIN_ROWS.size()):
		_add_row(i, MAIN_ROWS[i], "")


func _draw_settings() -> void:
	_title.text = "SETTINGS"
	_footer.text = MenuStyleScript.footer([[&"menu_rows", "choose"],
		[&"menu_tabs", "adjust"], [&"ui_cancel", "back"]])
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	_add_row(0, "Master volume", "%d%%" % int(round(settings.master_volume * 100.0)))
	_add_row(1, "Mouse sensitivity", "%.1f" % (settings.mouse_sensitivity * 1000.0))
	_add_row(2, "Invert look", "On" if settings.invert_look else "Off")


func _draw_compendium() -> void:
	_title.text = "COMPENDIUM"
	_footer.text = MenuStyleScript.footer_reading("back")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	if not has_book():
		_add_note(EMPTY_TEXT)
		return
	_add_note(compendium_header())
	var now := compendium_now()
	if not now.is_empty():
		_add_note(now)
	for line in compendium_region_rows():
		_add_note(line)
	var entries := roster()
	for i in compendium_window():
		var data: PonyData = entries[i]
		_add_row(i, _entry_name(data), _entry_value(data), _rarity_color(data.rarity),
			MenuStyleScript.COLOR_DIM, true)


func _draw_requests() -> void:
	_title.text = "REQUESTS"
	_footer.text = MenuStyleScript.footer_reading("back") + "      Finish one to get a new one."
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	var rows := request_rows()
	if rows.is_empty():
		_add_note(EMPTY_TEXT)
		return
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		_add_row(i, String(row.get("text", "")), String(row.get("value", "")))


func _draw_ledger() -> void:
	_title.text = "THE LEDGER"
	_footer.text = MenuStyleScript.footer_reading("back")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	for line in ledger_rows():
		_add_note(line)


## A line of text that is not a row: no panel, no border, never selected. The compendium's
## header and its per zone tallies are these.
func _add_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyleScript.style_label(label, 22, MenuStyleScript.COLOR_DIM)
	_rows.add_child(label)


func _add_row(index: int, row_name: String, value: String,
		name_color: Color = MenuStyleScript.COLOR_NAME,
		value_color: Color = MenuStyleScript.COLOR_VALUE, compact: bool = false) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override(&"panel", _row_style(index == _selected))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 18)
	margin.add_theme_constant_override(&"margin_right", 18)
	margin.add_theme_constant_override(&"margin_top", 4 if compact else 10)
	margin.add_theme_constant_override(&"margin_bottom", 4 if compact else 10)
	row.add_child(margin)
	var head := HBoxContainer.new()
	margin.add_child(head)
	var title := Label.new()
	title.text = row_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyleScript.style_label(title, 22 if compact else 26, name_color)
	head.add_child(title)
	if not value.is_empty():
		var val := Label.new()
		val.text = value
		MenuStyleScript.style_label(val, 20 if compact else 24, value_color)
		head.add_child(val)
	_rows.add_child(row)


func _row_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = MenuStyleScript.ROW_SELECTED_BG if selected else MenuStyleScript.ROW_IDLE_BG
	box.border_color = MenuStyleScript.ROW_SELECTED_BORDER if selected \
		else MenuStyleScript.ROW_IDLE_BORDER
	box.set_border_width_all(2 if selected else 1)
	box.set_corner_radius_all(8)
	return box
