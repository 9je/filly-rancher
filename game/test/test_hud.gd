extends GutTest
## Tests for the ranch HUD (game/ui/hud.gd).
##
## WHAT IS WORTH TESTING HERE AND WHAT IS NOT. Whether the crosshair is legible over
## grass, whether the saddlebag is unobtrusive, whether the capture rings read at a
## glance -- none of that is a number, and all of it was judged from rendered frames
## during Phase 1A Task 9's integration pass instead. What IS a number, and what a
## rendered frame is actively bad at showing, is whether the HUD is displaying the
## PLAYER'S ACTUAL STATE or a plausible-looking default: an unbound HUD draws "0 / 12"
## and twelve empty pips, perfectly, forever, and looks exactly like a bound one over an
## empty bag. So these tests are about the binding and the data, and game/world/ranch.gd
## asserts the same thing again against the real Player in the real scene.
##
## Preloads by path rather than by the global class_name, per the convention at the top
## of game/scripts/pony_rig.gd.

const HudScene := preload("res://ui/hud.tscn")
const HudScript := preload("res://ui/hud.gd")
const StorageScript := preload("res://systems/storage.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const MagicBeamScript := preload("res://actors/player/magic_beam.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const RequestBoardScript := preload("res://systems/request_board.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")

var _hud: CanvasLayer
## The HUD's own parent. It looks for a sibling named "Player" (that is how it is
## mounted in ranch.tscn), so the tests that exercise the binding drop a stand-in Player
## in here alongside it rather than re-parenting the HUD, which would leave it running
## with a stale parent for a frame.
var _world: Node


func before_each() -> void:
	_world = Node.new()
	add_child_autofree(_world)
	_hud = HudScene.instantiate()
	_world.add_child(_hud)


## One caught pony of the named ROSTER character. Real roster ids on purpose: the pip
## colour now comes from `instance.data().rarity`, resolved through PonyRegistry, so a
## made-up id would resolve to null and every pip would draw as the COMMON fallback --
## which would make this file pass whether or not the resolution worked at all.
func _instance(id: String) -> PonyInstance:
	return PonyInstanceScript.create(StringName(id))


func test_the_hud_scene_loads_and_carries_its_script() -> void:
	assert_true(_hud.has_method("get_beam"),
		"hud.tscn must have hud.gd attached -- a parse error leaves a bare CanvasLayer")


## NOTHING ELSE IN THE PROJECT GATES THIS. The magic beam aims along
## CameraRig.get_aim_ray() (game/actors/player/camera_rig.gd), which is projected
## through the camera's SCREEN CENTRE -- and hud.gd draws the reticle at
## `_crosshair.size * 0.5` (its `_draw_crosshair()`), the centre of the "Crosshair"
## Control. Those two only agree because that Control is anchored to fill the whole
## viewport (hud.tscn: anchors_preset=15, offsets zero) so ITS centre lands on the
## viewport's. Nothing ties the two centres together at runtime; a single anchor/offset
## edit on that one node would silently move the reticle off the aim ray while
## game/scenes/test/camera_test.gd's own crosshair round-trip -- which only ever checks
## the camera/projection half of that agreement, never the HUD's node layout -- stayed
## green throughout. This is the other half.
func test_a_toast_is_readable_back_after_it_is_shown() -> void:
	# game/world/ranch.gd says everything it says to the player through HUD.toast(), and
	# what it says is a requirement in its own right (the market gate reads the sale line
	# back to check that one gem is called a gem). A toast nothing can read again is a
	# requirement nothing can check.
	await wait_process_frames(1)
	_hud.toast("Sold 1 gem for 5 bits.")
	assert_eq(_hud.toast_text(), "Sold 1 gem for 5 bits.")


func test_two_toasts_in_one_frame_are_both_shown_in_the_order_they_were_raised() -> void:
	# ONE ACTION, TWO THINGS TO SAY. Selling a gem that finishes a favour raises "Sold ..."
	# and "Request done: ..." in the same frame, and the second used to overwrite the first
	# before a single word of it could be read. Both are the player's, so both are shown,
	# oldest first.
	await wait_process_frames(1)
	_hud.toast("Sold 1 gem for 5 bits.")
	_hud.toast("Request done: Catch a pony (+20 bits)")

	assert_eq(_hud.toast_text(), "Sold 1 gem for 5 bits.",
		"the line already on screen is not written over")
	assert_eq(_hud.pending_toasts(), ["Request done: Catch a pony (+20 bits)"],
		"and the second one is waiting its turn rather than lost")

	# The whole life of the first toast handed over in one step, rather than sat through:
	# what is being measured is the handover, not the frame rate it happens at.
	_hud._process(_hud.TOAST_HOLD + _hud.TOAST_FADE)

	assert_eq(_hud.toast_text(), "Request done: Catch a pony (+20 bits)",
		"the queued toast takes the screen the moment the first is finished")
	assert_true(_hud.pending_toasts().is_empty(), "and nothing is left waiting")
	assert_almost_eq(_hud.get_node("Toast").modulate.a, 1.0, 0.001,
		"...at full opacity, not part way through the first toast's fade")


func test_the_crosshair_control_is_centred_on_the_viewport() -> void:
	var crosshair: Control = _hud.get_node("Crosshair")
	await wait_process_frames(1)
	var viewport_centre: Vector2 = _hud.get_viewport().get_visible_rect().size * 0.5
	var crosshair_centre: Vector2 = crosshair.global_position + crosshair.size * 0.5
	assert_almost_eq(crosshair_centre.x, viewport_centre.x, 0.5,
		"the crosshair control's centre must land on the viewport's horizontal centre")
	assert_almost_eq(crosshair_centre.y, viewport_centre.y, 0.5,
		"the crosshair control's centre must land on the viewport's vertical centre")


func test_an_unbound_hud_reports_that_it_is_unbound() -> void:
	# The important one. Standalone -- no Player anywhere -- the HUD must not pretend.
	assert_null(_hud.get_beam(), "a HUD that found no beam must say so, not show a default")
	assert_eq(_hud.get_capacity(), 0, "capacity must be 0 until a real Storage is found")
	assert_eq(_hud.get_shown_rarities(), [] as Array[int])


func test_the_hints_action_is_bound_for_both_keyboard_and_gamepad() -> void:
	assert_true(InputMap.has_action("toggle_hints"),
		"project.godot must define 'toggle_hints'")
	var has_desktop := false
	var has_pad := false
	for event in InputMap.action_get_events("toggle_hints"):
		if event is InputEventKey or event is InputEventMouseButton:
			has_desktop = true
		elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
			has_pad = true
	assert_true(has_desktop, "'toggle_hints' needs a keyboard binding")
	assert_true(has_pad, "'toggle_hints' needs a gamepad binding -- the build is played "
		+ "on a pad too, and a keyboard-only toggle strands that player with the card up")


func test_every_rarity_tier_has_a_pip_colour() -> void:
	# A tier with no colour falls back to COMMON, so a new rarity would silently draw as
	# the most common thing in the game -- exactly backwards for a collection HUD.
	for tier in [PonyDataScript.Rarity.COMMON, PonyDataScript.Rarity.UNCOMMON,
			PonyDataScript.Rarity.RARE, PonyDataScript.Rarity.LEGENDARY]:
		assert_true(_hud.RARITY_COLORS.has(tier),
			"HUD.RARITY_COLORS is missing rarity tier %d" % tier)


func test_the_control_hints_cover_every_action_the_player_needs() -> void:
	var listed := ""
	for row: Array in _hud.HINTS:
		listed += String(row[0]).to_lower() + " "
	# "sneak" rather than "gallop" since the second playtest turned the modifier round --
	# running is the default now and Shift is the hold-to-walk stealth option.
	for needed in ["move", "sneak", "jump", "interact", "look", "zoom", "magic beam"]:
		assert_true(listed.find(needed) >= 0,
			"the hints card must mention '%s'" % needed)


# --- the binding, against a real Storage ------------------------------------------
# A stand-in for the Player: the one thing the HUD needs of her is get_magic_beam(),
# and the one thing it needs of the beam is get_storage() plus the three signals. Built
# here rather than instancing player.tscn so the test does not drag in a pony model, a
# camera rig and a capture of the mouse.

class FakeBeam:
	extends Node3D
	signal captured(data: PonyData)
	signal escaped(body: Node3D)
	signal capture_refused(body: Node3D)

	var storage: Storage

	func get_storage() -> Storage:
		return storage

	func is_active() -> bool:
		return false

	func is_holding() -> bool:
		return false

	# The rest of the reading surface the HUD's crosshair uses. Unreachable while
	# is_active() and is_holding() both answer false (the draw code short-circuits on
	# them), and declared anyway: a stand-in missing half the interface it stands in for
	# is one refactor away from turning a HUD change into a null-method crash in a test
	# that is nominally about the saddlebag.
	func has_target() -> bool:
		return false

	func is_secured() -> bool:
		return false

	func get_secure_progress() -> float:
		return 0.0

	func get_secure_seconds() -> float:
		return 0.0

	func get_struggle_seconds() -> float:
		return INF

	func get_hold_seconds() -> float:
		return 0.0

	func get_last_loss() -> int:
		return MagicBeamScript.Loss.NONE

	func is_wrenching() -> bool:
		return false


class FakePlayer:
	extends Node3D
	var beam: Node3D

	func get_magic_beam() -> Node3D:
		return beam


func _bind_to_a_fake_player(capacity: int) -> FakeBeam:
	var beam := FakeBeam.new()
	beam.storage = StorageScript.new(capacity)
	var player := FakePlayer.new()
	player.name = "Player"
	player.beam = beam
	player.add_child(beam)

	# The HUD looks for a sibling named "Player", so both go under one parent.
	_world.add_child(player)
	return beam


func test_the_hud_binds_to_a_sibling_players_beam_and_shows_its_capacity() -> void:
	var beam := _bind_to_a_fake_player(7)
	# Binding is retried from _process() rather than done in _ready(), because sibling
	# ready order is not something to depend on -- so give it a frame.
	await wait_process_frames(3)
	assert_eq(_hud.get_beam(), beam, "the HUD must find the Player's beam")
	assert_eq(_hud.get_capacity(), 7, "the HUD must show the beam's real capacity")


func test_storing_a_pony_updates_the_pips_without_the_hud_polling() -> void:
	var beam := _bind_to_a_fake_player(4)
	await wait_process_frames(3)
	assert_eq(_hud.get_shown_rarities().size(), 0, "the bag starts empty")

	# store() emits Storage.changed; nothing else is called, so if the pips update it is
	# because the HUD is connected to that signal and not because it re-reads every frame.
	beam.storage.store(_instance("fluttershy"))
	beam.storage.store(_instance("twilight"))
	assert_eq(_hud.get_shown_rarities(),
		[PonyDataScript.Rarity.UNCOMMON, PonyDataScript.Rarity.RARE] as Array[int],
		"the pips must show what is in the bag, oldest first, by rarity tier -- resolved "
		+ "from each individual's data_id, since rarity lives on the character not the pony")

	beam.storage.release()
	assert_eq(_hud.get_shown_rarities(),
		[PonyDataScript.Rarity.UNCOMMON] as Array[int],
		"letting one out must take a pip back off")


func test_a_refused_store_does_not_change_what_the_hud_shows() -> void:
	var beam := _bind_to_a_fake_player(1)
	await wait_process_frames(3)
	beam.storage.store(_instance("twilight"))
	var before: Array[int] = _hud.get_shown_rarities()
	assert_false(beam.storage.store(_instance("fluttershy")),
		"the bag is full, so this store must be refused")
	assert_eq(_hud.get_shown_rarities(), before,
		"a refused capture must leave the pips exactly as they were")


## THE BUG THIS PINS IS A LIE ON SCREEN, NOT A CRASH. The HUD caches its capacity at bind
## time and rebuilds only on Storage.changed, and until the shop existed nothing could ever
## change a bag's capacity after binding, so the cache was correct by construction. Buying
## the saddlebag (MagicBeam.apply_unlocks) breaks that assumption: it grows the very
## Storage this HUD is already holding. A HUD that kept the bound value would print
## "n / 12" and draw twelve pips over an eighteen-slot bag, and game/world/ranch.gd's own
## self check that the HUD shows the beam's real capacity would fail with it.
func test_the_hud_follows_a_saddlebag_that_grew_after_binding() -> void:
	var beam := _bind_to_a_fake_player(12)
	await wait_process_frames(3)
	assert_eq(_hud.get_capacity(), 12, "the HUD starts on the capacity it bound to")

	# Exactly what buying the gear does to this object, and nothing else. No frame is
	# awaited on purpose: set_capacity emits Storage.changed synchronously, so if the HUD
	# has caught up by the next line it is because it is listening.
	beam.storage.set_capacity(MagicBeamScript.BIGGER_SADDLEBAG_CAPACITY)
	assert_eq(_hud.get_capacity(), MagicBeamScript.BIGGER_SADDLEBAG_CAPACITY,
		"the HUD must follow a bag that grew, or ranch.gd's capacity self check fails")

	var count: Label = _hud.get_node("Bag/Count")
	assert_true(count.text.ends_with("/ %d" % MagicBeamScript.BIGGER_SADDLEBAG_CAPACITY),
		"the readout must say the new capacity, not the bound one (it says '%s')" % count.text)


func test_the_bits_line_shows_the_wallet() -> void:
	_hud.set_bits(0)
	assert_eq(_hud.get_bits_text(), "0 bits")
	_hud.set_bits(1234)
	assert_eq(_hud.get_bits_text(), "1234 bits")


## THE COMPANY'S BALANCE, beside the wallet on purpose (game/systems/ledger.gd's class
## comment): the two numbers together are the whole of the game's tension.
func test_the_hud_shows_the_company_balance() -> void:
	_hud.set_balance(25000)
	assert_eq(_hud.get_balance_text(), "CWC balance: 25000 bits")
	assert_false(_hud.get_balance_text().contains("--"))


## A NEGATIVE BALANCE IS CREDIT, AND SAYS SO -- see hud.gd's _balance_text().
func test_a_negative_balance_reads_as_credit_rather_than_as_a_minus_sign() -> void:
	_hud.set_balance(-400)
	assert_eq(_hud.get_balance_text(), "CWC balance: 400 bits in credit")


## THE WORLD LINE IS THE ONLY PLACE THE HOUR IS EVER STATED. game/world/ranch.gd sets it
## from WorldState.describe() at boot and again on every phase or weather change; a HUD that
## accepted the line and dropped it would leave the player reading the hour off the light,
## which is exactly what a barn interior or a screen with the brightness down takes away.
func test_the_world_line_says_the_hour_and_the_weather() -> void:
	assert_eq(_hud.get_world_line(), "", "the line starts empty until the ranch sets it")
	_hud.set_world_line("Dusk, rain")
	assert_eq(_hud.get_world_line(), "Dusk, rain")
	var label: Label = _hud.get_node("Bag/World")
	assert_eq(label.text, "Dusk, rain",
		"the readable-back value must be the label's own text, not a private copy")


## NO DASH OF ANY KIND, in either direction: the house style forbids an em dash and a
## double hyphen in player-facing text, and this line is assembled from two words and a
## comma precisely so it cannot acquire one. Every phase against every weather, because a
## separator would most likely be added to describe() itself and would then appear in all
## sixteen at once.
func test_the_world_line_never_carries_a_dash() -> void:
	for phase in range(WorldStateScript.PHASE_NAMES.size()):
		for weather in range(WorldStateScript.WEATHER_NAMES.size()):
			var state: WorldState = WorldStateScript.new(20260839, 0.0)
			state.pin(phase, weather)
			_hud.set_world_line(state.describe())
			var line: String = _hud.get_world_line()
			assert_false(line.contains("--"), "no double hyphen on the world line: '%s'" % line)
			assert_false(line.contains("\u2014"), "no em dash on the world line: '%s'" % line)
			assert_true(line.length() > 0, "every phase and weather pair must say something")


## THE BOX HAS TO GROW WITH THE LINES IN IT. The Bag is a VBoxContainer with a hand-set
## height, and slice 1 already had to raise it by a label once (the Bits line, which
## otherwise hung 31 px below the box). A fifth line does it again, and a box that is too
## short does not clip visibly in the editor; the labels simply overflow past the bottom
## anchor and off the screen, which is a thing a rendered frame shows and nothing else does.
func test_the_bag_box_is_tall_enough_for_every_line_in_it() -> void:
	await wait_process_frames(2)
	var bag: VBoxContainer = _hud.get_node("Bag")
	assert_true(bag.size.y >= bag.get_combined_minimum_size().y,
		"the Bag box is %.0f px tall and its contents need %.0f px"
			% [bag.size.y, bag.get_combined_minimum_size().y])


## RENAMED (Task 4): "and trade" -> "and sell gems", the row's own new name (HUD.HINTS'
## TRADE row became SELL GEMS when the card went device aware).
func test_the_hints_card_names_pause_and_sell_gems_and_never_free_cursor() -> void:
	var joined := ""
	for row in _hud.HINTS:
		joined += " ".join(row) + "\n"
	assert_string_contains(joined, "PAUSE")
	assert_string_contains(joined, "SELL GEMS")
	assert_false(joined.contains("FREE CURSOR"), "Escape pauses now; it does not free the cursor")
	assert_false(joined.contains("--"), "no double hyphen on the card")
	assert_false(joined.contains("—"), "no em dash on the card")


## A menu handler can fire a toast (for example the Market's "Sold 12 gems for 60
## bits.") and then pause the tree. If the HUD stopped processing along with everything
## else, that toast would freeze at full alpha instead of fading, and stay frozen until
## the menu closed. PROCESS_MODE_ALWAYS is what keeps the HUD's own _process ticking
## while the world is paused, so this pins the mode rather than the paused behaviour
## itself, since a GUT test should not pause the shared scene tree.
func test_the_hud_keeps_processing_while_the_tree_is_paused() -> void:
	assert_eq(_hud.process_mode, Node.PROCESS_MODE_ALWAYS,
		"the HUD must keep processing while the world is paused, or toasts freeze")


func test_the_prompt_starts_empty_and_holds_what_it_is_given() -> void:
	assert_eq(_hud.prompt_text(), "", "nothing is in range at boot")
	_hud.set_prompt("E: build here")
	assert_eq(_hud.prompt_text(), "E: build here")


func test_clearing_the_prompt_leaves_nothing_on_the_screen() -> void:
	_hud.set_prompt("E: Market, sell gems")
	_hud.clear_prompt()
	assert_eq(_hud.prompt_text(), "")


## THE PROMPT IS NOT THE TOAST, and the two must not be able to overwrite each other: a
## toast is something that happened, a prompt is something you can do, and the whole reason
## the prompt exists is that the toast fades.
func test_the_prompt_and_the_toast_are_two_different_lines() -> void:
	_hud.set_prompt("E: build here")
	_hud.toast("Ranch saved")
	assert_eq(_hud.prompt_text(), "E: build here")
	assert_eq(_hud.toast_text(), "Ranch saved")


# --- the starter checklist --------------------------------------------------------------

func test_the_task_list_is_empty_until_it_is_given_rows() -> void:
	assert_eq(_hud.task_lines().size(), 0)


func test_the_task_list_ticks_what_is_done_and_leaves_the_rest_open() -> void:
	_hud.set_tasks([
		{"id": "tutorial_catch", "text": "Catch a pony with your magic beam.",
			"done": true, "paid": false, "reward_bits": 20},
		{"id": "tutorial_pen", "text": "Move a pony into a pen.",
			"done": false, "paid": false, "reward_bits": 30},
	])
	var lines: Array[String] = _hud.task_lines()
	assert_eq(lines.size(), 3, "a title and two rows")
	assert_eq(lines[0], HudScript.TASK_TITLE)
	assert_true(lines[1].contains("Catch a pony"))
	assert_true(lines[1].contains("20"), "the reward is the reason to do it")
	assert_ne(lines[1].substr(0, 2), lines[2].substr(0, 2),
		"a finished row and an open one must not look the same")


func test_an_empty_task_list_draws_no_title_either() -> void:
	_hud.set_tasks([{"id": "a", "text": "t", "done": false, "paid": false,
		"reward_bits": 1}])
	_hud.set_tasks([])
	assert_eq(_hud.task_lines().size(), 0,
		"once the three are claimed the checklist goes away entirely")


func test_nothing_the_task_list_draws_carries_a_dash() -> void:
	_hud.set_tasks([{"id": "tutorial_sell", "text": "Sell a gem at the market.",
		"done": false, "paid": false, "reward_bits": 50}])
	for line in _hud.task_lines():
		assert_false(line.contains("--") or line.contains("—"), line)


## GUARDED, NOT TRUSTED (review round 1 finding 2). `rows` is a plain Array now (see
## set_tasks()'s own comment for why it cannot be Array[Dictionary]), so nothing at the
## call boundary refuses a junk element the way a real typed array would. A typed
## `for row: Dictionary in rows` loop over an untyped Array crashes the instant one element
## is not a Dictionary; set_tasks() skips it instead, so one bad row loses itself rather
## than the whole checklist.
func test_a_junk_element_is_skipped_rather_than_crashing_the_whole_checklist() -> void:
	_hud.set_tasks([
		{"id": "tutorial_catch", "text": "Catch a pony with your magic beam.",
			"done": false, "paid": false, "reward_bits": 20},
		7,
		"junk",
	])
	var lines: Array[String] = _hud.task_lines()
	assert_eq(lines.size(), 2, "the title and the one valid row; the two junk entries are gone")
	assert_eq(lines[0], HudScript.TASK_TITLE)
	assert_true(lines[1].contains("Catch a pony"))


## THE TRAP REVIEW ROUND 1 CAUGHT IN game/world/ranch.gd's _refresh_tasks(), AND THE ONE
## ITS FIRST-PASS FIX MISSED TOO. An inline ternary passed straight into a dynamically
## dispatched call (this HUD is always reached through get_node_or_null() / has_method(),
## never a statically HUD-typed var -- see set_tasks()'s own comment) throws exactly the
## review's SCRIPT ERROR when the callee wants a strict `Array[Dictionary]` -- confirmed
## directly against a throwaway RefCounted whose own set_tasks() kept that stricter
## signature. Hoisting the SAME ternary into a typed local first -- the fix review round 1
## prescribed -- turned out NOT to be enough on its own: `var rows: Array[Dictionary] =
## x if cond else []` STILL throws "Trying to assign an array of type Array to a variable
## of type Array[Dictionary]" the moment the bare `[]` branch is the one actually taken,
## confirmed the same way. Every one of our gates and the full suite always has a real
## GameState autoload, so `_board` is never actually null when _refresh_tasks() runs in
## any of them -- the false branch was never once exercised by anything green, ternary or
## not. What is actually reliable, confirmed against that same strict RefCounted sink on
## BOTH branches, is a plain if/else statement: each assignment to the typed local is
## independent, with no ternary type-merging step to go wrong. _refresh_tasks() now reads
## that way, and this pins both of its branches through this HUD's own dynamic call.
func test_the_if_else_hoisted_local_pattern_survives_the_dynamic_call_on_both_branches() -> void:
	# THE NULL BOARD BRANCH: what _refresh_tasks() builds when _board is null.
	var board: RequestBoard = null
	var rows_when_null: Array[Dictionary] = []
	if board != null:
		rows_when_null = board.tutorial_rows()
	_hud.set_tasks(rows_when_null)
	assert_eq(_hud.task_lines().size(), 0, "an empty hoisted local clears the checklist")

	# THE REAL BOARD BRANCH: what it builds once a board with rows on it exists.
	var registry := PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	board = RequestBoardScript.new(1, registry, [] as Array[StringName], {})
	board.seed_tutorial()
	var rows_when_present: Array[Dictionary] = []
	if board != null:
		rows_when_present = board.tutorial_rows()
	_hud.set_tasks(rows_when_present)
	assert_eq(_hud.task_lines().size(), 4, "a title and the three seeded rows")


# --- the card, and the queue ------------------------------------------------------------

## THE BLEED THROUGH. The owner, on her first full playtest: the H control card showed
## through the letter she was reading. It is a PanelContainer on the HUD's own CanvasLayer,
## so anything drawn over the world is drawn over it too, and the fix is that the card is not
## on screen while an overlay is.
##
## HER TOGGLE IS REMEMBERED. A player who had the card up before opening a menu gets it back
## when she closes the menu; a player who had it down does not suddenly get it.

## I7, final-review.md I5: THE CARD IS UP THE MOMENT THE HUD ENTERS THE TREE, WITH NO
## OVERLAY AND NO KEYPRESS. Before this fix `_hints_wanted` initialised false and the card
## never appeared unless a player who was never told the key happened to press it anyway.
func test_the_control_card_is_visible_by_default_on_a_fresh_hud() -> void:
	assert_true(_hud.hints_visible())


func test_pressing_h_dismisses_the_default_visible_card() -> void:
	_hud._unhandled_input(_hints_key())
	assert_false(_hud.hints_visible(), "H toggles it, whichever state it starts in")


## I7, final-review.md I5: THE CARD IS THE PRE-BRANCH DEFAULT -- visible on a fresh
## interactive game (`_hints_wanted` starts true, hud.gd's own _ready()) until dismissed
## with H, and it still hides under an overlay per Task 7's bleed-through fix.
func test_an_overlay_hides_the_card_and_closing_the_overlay_gives_it_back() -> void:
	_hud.set_overlay_open(false)
	assert_true(_hud.hints_visible(), "visible by default; nothing has dismissed it")
	_hud.set_overlay_open(true)
	assert_false(_hud.hints_visible(), "and it is gone while she reads a letter")
	assert_true(_hud.overlay_open())
	_hud.set_overlay_open(false)
	assert_true(_hud.hints_visible(), "and it comes back once the overlay closes")


func test_an_overlay_does_not_conjure_a_card_she_dismissed() -> void:
	_hud.set_overlay_open(false)
	_hud._unhandled_input(_hints_key())
	assert_false(_hud.hints_visible(), "she pressed H once and dismissed the default card")
	_hud.set_overlay_open(true)
	_hud.set_overlay_open(false)
	assert_false(_hud.hints_visible(), "an overlay opening and closing must not bring it back")


func test_the_card_key_does_nothing_while_an_overlay_is_up() -> void:
	_hud.set_overlay_open(true)
	_hud._unhandled_input(_hints_key())
	assert_false(_hud.hints_visible(),
		"H under a letter would put the card straight back over it")


func _hints_key() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = HudScript.HINTS_ACTION
	event.pressed = true
	return event


## THE TOAST LAG. The owner: "text on top lags behind". Three quick actions used to queue
## three full TOAST_HOLDs, so the third line arrived nine seconds after the thing it was
## about. A backed up queue now runs short.

func test_a_single_toast_gets_its_full_time() -> void:
	_hud.toast("Caught somebody!")
	_hud._process(0.0)
	assert_almost_eq(_hud.toast_seconds_left(), HudScript.TOAST_HOLD + HudScript.TOAST_FADE, 0.001)


func test_a_backed_up_toast_runs_short_so_the_queue_keeps_up() -> void:
	_hud.toast("one")
	_hud.toast("two")
	_hud._process(0.0)
	assert_lte(_hud.toast_seconds_left(), HudScript.TOAST_HOLD_BUSY + HudScript.TOAST_FADE,
		"a toast with somebody waiting behind it does not hold the full time")
	assert_eq(_hud.pending_toasts(), ["two"] as Array[String])


func test_the_queue_never_grows_past_its_cap_and_keeps_the_newest() -> void:
	for i in range(HudScript.TOAST_QUEUE_MAX + 4):
		_hud.toast("line %d" % i)
	assert_lte(_hud.pending_toasts().size(), HudScript.TOAST_QUEUE_MAX,
		"rapid play must not build a backlog nobody will read")
	assert_eq(_hud.pending_toasts().back(),
		"line %d" % (HudScript.TOAST_QUEUE_MAX + 3),
		"the newest line is the one that matters")


func test_the_queue_drains_and_the_last_line_still_gets_shown() -> void:
	_hud.toast("one")
	_hud.toast("two")
	for i in range(200):
		_hud._process(0.05)
	assert_eq(_hud.pending_toasts(), [] as Array[String], "the queue emptied")
	assert_eq(_hud.toast_text(), "two", "and the last line was actually shown")
