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
const PaperPaintScript := preload("res://ui/paper_paint.gd")
const PaintScript := preload("res://ui/casino_paint.gd")
# THE RESOURCE'S OWN ENUM, so reply_rows() matches on a name rather than on the numbers 1
# and 2. This is a data resource, not game state: the page still never learns what a Story
# is, exactly as it preloads CompendiumScript for State without ever owning a Compendium.
const StoryBeatScript := preload("res://systems/story_beat.gd")
const StoryWordingScript := preload("res://systems/story_wording.gd")
const SoundScript := preload("res://systems/sound.gd")

enum Page { MAIN, SETTINGS, COMPENDIUM, REQUESTS, MAIL, LEDGER }
enum Row { RESUME, COMPENDIUM, REQUESTS, MAIL, LEDGER, SAVE, SETTINGS, QUIT }
enum SettingRow { VOLUME, AMBIENT, EFFECTS, SENSITIVITY, INVERT }

const MAIN_ROWS := ["Resume", "Compendium", "Requests", "Mail", "The ledger",
	"Save the ranch", "Settings", "Quit to desktop"]

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

## THE MAIL PAGE IS DRAWN, NOT PRINTED. The stage is 660 wide: the Panel's 720 minus the
## Margin node's 30 either side, the same arithmetic TableMenu.STAGE_WIDTH does for the
## casino's 1180 wide panels. Every rect on this page is laid out against these numbers.
const MAIL_STAGE_WIDTH := 660.0
const ENVELOPE_HEIGHT := 68.0
const ENVELOPE_GAP := 10.0
const ENVELOPES_ON_SCREEN := 5
const LETTER_LINE_HEIGHT := 26.0
const REPLY_ROW_HEIGHT := 34.0
const REPLY_ROW_GAP := 6.0

## What the Mail page says with nothing in the mailbox yet.
const MAIL_EMPTY_TEXT := "Nothing in the mailbox yet."

## Both halves of a character's "when" line when she has no restriction on that half.
## PonyData carries an EMPTY array to mean "any" in each of `phases` and `weathers`
## independently (game/systems/pony_data.gd), so the two are answered separately.
const ANY_TEXT := "any"


@onready var _title: Label = $Centre/Panel/Margin/Column/Title
@onready var _rows: VBoxContainer = $Centre/Panel/Margin/Column/Rows
@onready var _footer: Label = $Centre/Panel/Margin/Column/Footer
@onready var _stage: Control = get_node_or_null(^"Centre/Panel/Margin/Column/Stage")

signal opened()
signal closed()
signal save_requested()
signal quit_requested()
signal settings_changed()

## THE MAIL PAGE'S TWO PROVIDERS, injected by ranch.gd exactly as the five above are. This
## menu never loads a StoryBeat, never renders one and never learns what a Story is: it is
## handed rendered rows and the ponies she owns, and it hands back "she opened this" and
## "she answered this". Same split as every other panel in the game.
var mail_provider := Callable()
var mail_ponies_provider := Callable()

signal mail_opened(id: StringName)
signal mail_reply(id: StringName, choice: String)

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

## WHICH CHAPTER THE BOOK IS BEING READ IN, and who the player named on the Survey. Both are
## pushed by ranch.gd exactly as the five sources above are, and both are allowed to stay at
## their defaults forever: a menu with no ranch behind it reads the book in SUNNY's words,
## which is the state a new game is in anyway.
var story_chapter: int = 0
var employees_choice: StringName = &""

var _page: int = Page.MAIN
var _selected := 0
## First roster index drawn on the COMPENDIUM page. Follows `_selected`; see _sync_scroll().
var _scroll := 0
var _open := false

## The letter currently open on the MAIL page, or &"" while the list is showing.
var _letter_id: StringName = &""

## mail_rows()'s answer, taken once per _refresh() rather than once per call. The Mail
## page's stage redraws every frame it is up (_process()), and every draw call used to walk
## the provider and duplicate(true) every letter ever posted -- O(letters) allocation every
## frame, growing with playtime, for a page nothing had touched since the last _refresh()
## (final review, MINOR 3). _refresh() is the one place anything that could change what
## mail_rows() answers already runs through (open, close, cursor move, a letter arriving),
## so recomputing there and reading the cache everywhere else costs nothing correctness can
## notice.
var _mail_rows_cache: Array[Dictionary] = []
var _mail_rows_dirty := true

## Seconds since this menu opened, advanced in _process while it is up. Read by the stage
## for the focus ring's breath, the same field and the same purpose as TableMenu._anim_t.
var _anim_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MenuStyleScript.apply_panel($Centre/Panel as PanelContainer)
	MenuStyleScript.style_label(_title, MenuStyleScript.TITLE_SIZE, MenuStyleScript.COLOR_TITLE)
	_title.text = "PAUSED"
	visible = false
	if _stage != null:
		_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.draw.connect(_paint_stage)
	set_process(false)


## get_node_or_null(), not the bare `Sound` identifier: see game/ui/menu_style.gd's own
## comment, and game/actors/player/magic_beam.gd's _sound_call, on why an autoload's name
## does not resolve under the parse sweep's check-only, script-only pass. This is for the
## two sites that play a world sound directly (open_letter's mail_open, confirm()'s
## mail_stamp) rather than through a MenuStyle tick, exactly as magic_beam.gd's own
## capture sounds do. is_inside_tree() first, so a menu built with .new() and never added
## anywhere (this file's own tests construct it that way) gets a silent no-op rather than
## the engine error get_node() prints on a treeless node.
func _sound_call(method: StringName, args: Array) -> void:
	if not is_inside_tree():
		return
	var node: Node = get_node_or_null(^"/root/Sound")
	if node != null:
		node.callv(method, args)


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
	_letter_id = &""
	_anim_t = 0.0
	set_process(true)
	_open = true
	visible = true
	_refresh()
	opened.emit()
	MenuStyleScript.tick_open()
	return true


## Open (if it is not open already) and land straight on `page`. This is how the request
## board's E prompt reaches the REQUESTS page without walking the player through the main
## menu: ranch.gd looks the page number up out of this script's own constant map and calls
## here (game/world/ranch.gd, _open_request_page).
##
## Returns false, and changes nothing, if `can_open` refuses or `page` is not a real Page;
## an unknown page number must not leave the menu on a blank it cannot draw.
##
## THE TICK IS EARNED ONE OF TWO WAYS, NEVER BOTH. When the panel was closed, `open()`
## below already fires tick_open() on its own success path, so this function only adds
## tick_page() for the other case, a page switch inside a panel that was already open. A
## caller reaching this from confirm() (the panel is always open there, by construction)
## always takes the tick_page() branch; ranch.gd's request board shortcut is the one
## caller that can take either branch, depending on whether the panel was already up.
func open_page(page: int) -> bool:
	if not (page in Page.values()):
		return false
	var was_open: bool = _open
	if not _open and not open():
		return false
	_page = page
	_selected = 0
	_scroll = 0
	_letter_id = &""
	_refresh()
	if was_open:
		MenuStyleScript.tick_page()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	set_process(false)
	closed.emit()


func is_open() -> bool:
	return _open


func page() -> int:
	return _page


func selected_index() -> int:
	return _selected


## THE BREATH ON THE FOCUS RING, and nothing else. The stage is redrawn only while the MAIL
## page is actually up, so a paused ranch with the compendium open costs nothing.
func _process(delta: float) -> void:
	_anim_t += delta
	if _open and _page == Page.MAIL and _stage != null:
		_stage.queue_redraw()


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
		Page.MAIL:
			# On the list, one row per envelope. Inside a letter, one row per reply option,
			# and a letter with no reply control has exactly one cursor position: nowhere.
			if _letter_id.is_empty():
				return maxi(1, mail_rows().size())
			return maxi(1, reply_rows().size())
		Page.LEDGER:
			# The ledger page draws only notes (_draw_ledger(), _add_note()), never a
			# selectable row, so there is exactly one cursor position on it: nowhere.
			return 1
	return MAIN_ROWS.size()


func move_selection(step: int) -> void:
	_selected = posmod(_selected + step, _row_count())
	_sync_scroll()
	_refresh()
	MenuStyleScript.tick_move()


## Left or right on a settings row. Nothing on any other page: the compendium and the
## request board have no adjustable anything, and this is the one place that decides so.
func adjust(direction: int) -> void:
	if _page != Page.SETTINGS or settings == null:
		return
	match _selected:
		SettingRow.VOLUME:
			settings.step_volume(direction)
		SettingRow.AMBIENT:
			settings.step_ambient(direction)
		SettingRow.EFFECTS:
			settings.step_effects(direction)
		SettingRow.SENSITIVITY:
			settings.step_sensitivity(direction)
		SettingRow.INVERT:
			settings.toggle_invert()
	MenuStyleScript.tick_move()
	settings_changed.emit()
	_refresh()


func confirm() -> bool:
	if _page == Page.MAIL:
		if _letter_id.is_empty():
			var rows: Array[Dictionary] = mail_rows()
			if _selected < 0 or _selected >= rows.size():
				MenuStyleScript.tick_denied()
				return false
			var opened_ok: bool = open_letter(StringName(String(rows[_selected].get("id", ""))))
			if opened_ok:
				MenuStyleScript.tick_confirm()
			else:
				MenuStyleScript.tick_denied()
			return opened_ok
		var replies: Array[Dictionary] = reply_rows()
		if _selected < 0 or _selected >= replies.size():
			MenuStyleScript.tick_denied()
			return false
		var answered: StringName = _letter_id
		var choice: String = String(replies[_selected]["choice"])
		close_letter()
		mail_reply.emit(answered, choice)
		# THE ANSWERED STAMP COMING DOWN: a world sound on the Effects bus, not a UI tick,
		# for the same reason open_letter() plays mail_open directly; see _sound_call.
		_sound_call(&"play", [&"mail_stamp"])
		# REFRESH AGAIN, AFTER THE EMIT: close_letter()'s own _refresh() ran BEFORE
		# ranch.gd's answer_mail() had a chance to mark the letter read, so the mail_rows()
		# cache it primed would otherwise hold the pre-reply snapshot (stale wax dot, no
		# "ANSWERED" stamp) until some unrelated interaction happened to refresh the page.
		_refresh()
		return true
	if _page == Page.SETTINGS:
		if _selected == SettingRow.INVERT:
			adjust(1)
			MenuStyleScript.tick_confirm()
			return true
		MenuStyleScript.tick_denied()
		return false
	if _page == Page.COMPENDIUM or _page == Page.REQUESTS or _page == Page.LEDGER:
		# Read only pages; see the class comment.
		MenuStyleScript.tick_denied()
		return false
	match _selected:
		Row.RESUME:
			close()
			MenuStyleScript.tick_confirm()
		Row.COMPENDIUM:
			# open_page() is always taking its "already open" branch here (confirm() only
			# runs while the panel is open), so it fires tick_page() on its own; see its
			# own comment.
			open_page(Page.COMPENDIUM)
		Row.REQUESTS:
			open_page(Page.REQUESTS)
		Row.MAIL:
			open_page(Page.MAIL)
		Row.LEDGER:
			open_page(Page.LEDGER)
		Row.SAVE:
			save_requested.emit()
			MenuStyleScript.tick_confirm()
		Row.SETTINGS:
			_page = Page.SETTINGS
			_selected = 0
			_refresh()
			MenuStyleScript.tick_page()
		Row.QUIT:
			quit_requested.emit()
			MenuStyleScript.tick_confirm()
	return true


## Cancel: a sub page goes back to main WITH ITS OWN ROW SELECTED, so cancelling out of the
## compendium leaves the cursor on "Compendium" rather than back at the top; main closes.
func back() -> void:
	MenuStyleScript.tick_back()
	match _page:
		Page.SETTINGS:
			_return_to_main(Row.SETTINGS)
		Page.COMPENDIUM:
			_return_to_main(Row.COMPENDIUM)
		Page.REQUESTS:
			_return_to_main(Row.REQUESTS)
		Page.MAIL:
			if not _letter_id.is_empty():
				close_letter()
			else:
				_return_to_main(Row.MAIL)
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
		# The Company's word for it, in the Company's tone, and the tone moves with the
		# chapter. See game/systems/story_wording.gd; game/systems/compendium.gd's class
		# comment has said this is how it would read since the state was added.
		return StoryWordingScript.processed_value(story_chapter,
			data.id == employees_choice)
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

## The line at the top of the board, in the chapter it is being read in. Empty when no board
## was injected, which is the state a bare menu is in.
func board_note() -> String:
	return board.note() if board != null else ""


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


# --- the mailbox ---------------------------------------------------------------------------

## Every letter she has been sent, NEWEST FIRST. The provider hands them over oldest first
## (Story.mail is a log), and the list shows the new one at the top, because that is the one
## she came to read. Nothing is ever removed: re-reading old mail is the whole point of the
## paper channel.
func mail_rows() -> Array[Dictionary]:
	if _mail_rows_dirty:
		_mail_rows_cache = _fetch_mail_rows()
		_mail_rows_dirty = false
	var out: Array[Dictionary] = []
	for row: Dictionary in _mail_rows_cache:
		out.append(row.duplicate(true))
	return out


func _fetch_mail_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not mail_provider.is_valid():
		return out
	for entry in mail_provider.call():
		out.append((entry as Dictionary).duplicate(true))
	out.reverse()
	return out


func open_letter_id() -> StringName:
	return _letter_id


## Open the letter with this id. Says so with `mail_opened`, which is how ranch.gd marks it
## read; the menu does not own read state any more than it owns bits.
func open_letter(id: StringName) -> bool:
	for row: Dictionary in mail_rows():
		if StringName(String(row.get("id", ""))) == id:
			_letter_id = id
			_selected = 0
			mail_opened.emit(id)
			# THE ENVELOPE ITSELF: a world sound on the Effects bus, not a UI tick; see
			# _sound_call.
			_sound_call(&"play", [&"mail_open"])
			_refresh()
			return true
	return false


func close_letter() -> void:
	_letter_id = &""
	_selected = 0
	_refresh()


## The open letter's row, or an empty dictionary.
func _open_row() -> Dictionary:
	for row: Dictionary in mail_rows():
		if StringName(String(row.get("id", ""))) == _letter_id:
			return row
	return {}


## The body of the open letter, line by line. Empty when the list is showing.
func letter_lines() -> Array[String]:
	var row: Dictionary = _open_row()
	if row.is_empty():
		return []
	var out: Array[String] = []
	for line in row.get("body", []):
		out.append(String(line))
	return out


## The rows a reply control offers: {"label": String, "choice": String}. Empty for a letter
## with no reply control, and empty for one already answered, so a bonus cannot be claimed
## twice from the menu side either.
func reply_rows() -> Array[Dictionary]:
	var row: Dictionary = _open_row()
	if row.is_empty():
		return []
	if not String(row.get("replied", "")).is_empty():
		return []
	var out: Array[Dictionary] = []
	match int(row.get("reply", 0)):
		StoryBeatScript.Reply.PICK_PONY:
			if not mail_ponies_provider.is_valid():
				return out
			for entry in mail_ponies_provider.call():
				var pony: Dictionary = entry
				var coat: String = String(pony.get("coat", ""))
				var who: String = String(pony.get("name", ""))
				out.append({
					"label": "%s %s" % [coat, who] if not coat.is_empty() else who,
					"choice": String(pony.get("uid", "")),
				})
		StoryBeatScript.Reply.YES_NO:
			out.append({"label": "Yes", "choice": "yes"})
			out.append({"label": "No", "choice": "no"})
	return out


## THE PAGE'S SEMANTIC MODEL, which survives the drawing rather than being replaced by it.
## The stage paints; this says what is on the page, so a test can sweep it for a dash and a
## stage that failed to instantiate still has something to print. Same rule the casino's
## drawn_lines() follows.
func mail_lines() -> Array[String]:
	if not _letter_id.is_empty():
		var row: Dictionary = _open_row()
		var out: Array[String] = [String(row.get("sender", "")), String(row.get("title", ""))]
		out.append_array(letter_lines())
		for reply: Dictionary in reply_rows():
			out.append(String(reply["label"]))
		return out
	var rows: Array[Dictionary] = mail_rows()
	if rows.is_empty():
		return [EMPTY_TEXT, MAIL_EMPTY_TEXT]
	var lines: Array[String] = []
	for row: Dictionary in rows:
		lines.append("%s   %s" % [String(row.get("title", "")),
			"new" if not bool(row.get("read", false)) else ""])
	return lines


# --- drawing -------------------------------------------------------------------------------

func _refresh() -> void:
	# Every state change that could move what mail_rows() answers runs through here (open,
	# close, cursor move, ranch.gd's refresh_page() when a letter arrives), so this is the
	# one place the cache needs invalidating; see _mail_rows_cache's own comment.
	_mail_rows_dirty = true
	# remove_child BEFORE queue_free: a queued node is still a child until the end of the
	# frame, so freeing alone would leave the old rows laid out underneath the new ones for
	# one frame every time the cursor moves. Same fix as market_menu.gd's refresh().
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	# THE STAGE IS THE MAIL PAGE'S AND NOBODY ELSE'S. A Control left visible with a minimum
	# size on the compendium would be a blank band above the roster.
	if _stage != null:
		_stage.visible = _page == Page.MAIL
		if _page != Page.MAIL:
			_stage.custom_minimum_size = Vector2.ZERO
	match _page:
		Page.SETTINGS:
			_draw_settings()
		Page.COMPENDIUM:
			_draw_compendium()
		Page.REQUESTS:
			_draw_requests()
		Page.MAIL:
			_draw_mail()
		Page.LEDGER:
			_draw_ledger()
		_:
			_draw_main()


## Redraw whatever page is up. ranch.gd calls this when something the open page is drawing
## has changed under it (a letter arriving while the Mail page is open), which is the same
## push the Depot's refresh() takes.
func refresh_page() -> void:
	if _open:
		_refresh()


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
	_add_row(SettingRow.VOLUME, "Master volume",
		"%d%%" % int(round(settings.master_volume * 100.0)))
	_add_row(SettingRow.AMBIENT, "Ambience",
		"%d%%" % int(round(settings.ambient_volume * 100.0)))
	_add_row(SettingRow.EFFECTS, "Effects and menus",
		"%d%%" % int(round(settings.effects_volume * 100.0)))
	_add_row(SettingRow.SENSITIVITY, "Mouse sensitivity",
		"%.1f" % (settings.mouse_sensitivity * 1000.0))
	_add_row(SettingRow.INVERT, "Invert look", "On" if settings.invert_look else "Off")


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
	_footer.text = MenuStyleScript.footer_reading("back")
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	var note: String = board_note()
	if not note.is_empty():
		_add_note(note)
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


## THE MAIL PAGE IS THE STAGE. The Rows column prints nothing while a stage is present: the
## page IS the drawing, the way the casino's tables are. A menu instantiated without the
## Stage node (an older scene, a test tree built by hand) falls back to printing
## mail_lines(), so the page is never blank and never a lie about what is in the mailbox.
func _draw_mail() -> void:
	_title.text = "MAIL"
	MenuStyleScript.apply_title(_title)
	_footer.text = _mail_footer()
	MenuStyleScript.style_label(_footer, MenuStyleScript.FOOTER_SIZE, MenuStyleScript.COLOR_DIM)
	if _stage == null:
		for line in mail_lines():
			_add_note(line)
		return
	_stage.custom_minimum_size = Vector2(MAIL_STAGE_WIDTH, _mail_stage_height())
	_stage.queue_redraw()


func _mail_footer() -> String:
	if _letter_id.is_empty():
		return MenuStyleScript.footer([[&"menu_rows", "choose"], [&"ui_accept", "read"],
			[&"ui_cancel", "back"]])
	if reply_rows().is_empty():
		return MenuStyleScript.footer_reading("back")
	return MenuStyleScript.footer([[&"menu_rows", "choose"], [&"ui_accept", "answer"],
		[&"ui_cancel", "back"]])


func _mail_stage_height() -> float:
	if _letter_id.is_empty():
		var count: int = maxi(1, mini(mail_rows().size(), ENVELOPES_ON_SCREEN))
		return float(count) * (ENVELOPE_HEIGHT + ENVELOPE_GAP) + 12.0
	var lines: int = letter_lines().size()
	var replies: int = reply_rows().size()
	return 96.0 + float(lines) * LETTER_LINE_HEIGHT \
		+ float(replies) * (REPLY_ROW_HEIGHT + REPLY_ROW_GAP) + 40.0


## THE ONLY draw_* CONTEXT IN THIS FILE. Connected to the Stage Control's `draw` signal in
## _ready(), which is what makes these calls legal at all.
func _paint_stage() -> void:
	if _stage == null or _page != Page.MAIL:
		return
	var font: Font = MenuStyleScript.title_font()
	var box := Rect2(Vector2.ZERO, _stage.size)
	if _letter_id.is_empty():
		_paint_envelopes(font, box)
	else:
		_paint_letter(font, box)


func _paint_envelopes(font: Font, box: Rect2) -> void:
	var rows: Array[Dictionary] = mail_rows()
	if rows.is_empty():
		PaperPaintScript.sheet(_stage, Rect2(box.position, Vector2(box.size.x, 84.0)))
		PaintScript.text(_stage, font, box.position + Vector2(24.0, 50.0), MAIL_EMPTY_TEXT,
			MenuStyleScript.ROW_SIZE, PaperPaintScript.INK_DIM, HORIZONTAL_ALIGNMENT_LEFT,
			box.size.x - 48.0)
		return
	# A WINDOW OVER THE LIST, not the whole of it: the mailbox fills up forever and the panel
	# does not. Follows the cursor exactly as the compendium's window does.
	var first: int = clampi(_selected - ENVELOPES_ON_SCREEN + 1, 0,
		maxi(0, rows.size() - ENVELOPES_ON_SCREEN))
	if _selected < first:
		first = _selected
	var y: float = box.position.y + 6.0
	for i in range(first, mini(rows.size(), first + ENVELOPES_ON_SCREEN)):
		var row: Dictionary = rows[i]
		PaperPaintScript.envelope(_stage,
			Rect2(Vector2(box.position.x, y), Vector2(box.size.x, ENVELOPE_HEIGHT)), font,
			String(row.get("sender", "")), String(row.get("title", "")),
			not bool(row.get("read", false)), i == _selected, _anim_t)
		y += ENVELOPE_HEIGHT + ENVELOPE_GAP


func _paint_letter(font: Font, box: Rect2) -> void:
	var row: Dictionary = _open_row()
	PaperPaintScript.sheet(_stage, box)
	PaperPaintScript.letterhead(_stage, box, font, String(row.get("sender", "")))
	var x: float = box.position.x + 28.0
	var width: float = box.size.x - 56.0
	var y: float = box.position.y + 88.0
	PaintScript.text(_stage, font, Vector2(x, y), String(row.get("title", "")),
		MenuStyleScript.TITLE_SIZE, PaperPaintScript.INK, HORIZONTAL_ALIGNMENT_LEFT, width)
	# 20 px below a TITLE_SIZE (30) baseline clears its descender box; 12 sat inside it and
	# the gold rule cut the tails of letters like "p" and "y" (final review, MINOR 1).
	y += 20.0
	MenuStyleScript.rule(_stage, Vector2(x, y), Vector2(x + width, y))
	y += 30.0
	for line: String in letter_lines():
		PaintScript.text(_stage, font, Vector2(x, y), line, MenuStyleScript.ROW_SIZE,
			PaperPaintScript.INK, HORIZONTAL_ALIGNMENT_LEFT, width)
		y += LETTER_LINE_HEIGHT
	var replies: Array[Dictionary] = reply_rows()
	if not replies.is_empty():
		y += 8.0
		# Where the picker starts, kept so the coupon can sit BESIDE it rather than at a
		# typed in height that would slide under a long title.
		var reply_top: float = y
		for i in replies.size():
			var pick := Rect2(Vector2(x, y), Vector2(width * 0.62, REPLY_ROW_HEIGHT))
			PaintScript.rounded(_stage, pick, 6.0, Color(PaperPaintScript.STAMP_INK, 0.08),
				Color(PaperPaintScript.STAMP_INK, 0.55), 1.0)
			PaintScript.text(_stage, font, pick.position + Vector2(14.0, 24.0),
				String(replies[i]["label"]), MenuStyleScript.ROW_SIZE, PaperPaintScript.INK,
				HORIZONTAL_ALIGNMENT_LEFT, pick.size.x - 28.0)
			if i == _selected:
				PaintScript.focus_ring(_stage, pick, 6.0, _anim_t)
			y += REPLY_ROW_HEIGHT + REPLY_ROW_GAP
		# The coupon, drawn on the paper beside the picker, so the thing she is being paid
		# is a thing on the page rather than a sentence about a thing.
		PaperPaintScript.coupon(_stage,
			Rect2(Vector2(x + width * 0.66, reply_top),
				Vector2(width * 0.34, 46.0)), font, "HAY COUPON", PaperPaintScript.PAPER)
	elif not String(row.get("replied", "")).is_empty():
		PaperPaintScript.stamp(_stage,
			Rect2(Vector2(x + width * 0.60, y + 6.0), Vector2(width * 0.36, 44.0)), font,
			"ANSWERED")
