extends GutTest
## PENNING, AND WHAT A REFUSED PRESS SOUNDS LIKE.
##
## The owner, second playtest: "when i place ponies in the paddock i press e several times
## and that sound is terrible". Two defects sat behind that sentence. The first was the
## interact resolver handing E to an empty plot 20 cm further away than the pen she was
## standing at (game/world/interaction.gd's GROUND_TIER). The second is this one: every
## refusal raised a toast and nothing else, on every single frame the key went down, so
## mashing E against a full pen raised the same line over and over into a queue that could
## not drain, and every press that reached a menu instead machine-gunned its open and back
## ticks.
##
## A refusal is now ONE line and ONE soft ui_denied, and a second identical refusal inside
## DENY_DEBOUNCE_SECONDS is swallowed entirely. Not rate-limited to a quieter version: a
## player who mashes a key against a full pen has already been told.

const RanchScene := preload("res://world/ranch.tscn")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")


func _ranch() -> Node:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	await wait_frames(2)
	return ranch


func test_a_full_pen_refuses_once_however_many_times_she_presses() -> void:
	var ranch = await _ranch()
	var slots: Array = ranch.plot_slots()
	assert_gt(slots.size(), 0, "the map has to have a slot for this to mean anything")
	var slot = slots[0]
	var catalogue = ranch.call("_plots_catalogue")
	var plots: Array = catalogue.all()
	assert_gt(plots.size(), 0, "the catalogue has to have a plot for this to mean anything")
	assert_true(slot.build(plots[0]))
	await wait_physics_frames(2)
	var pen = slot.get_built()
	# Fill it, through the pen's own front door.
	while not pen.is_full():
		assert_true(pen.add_pony(PonyInstanceScript.create(&"twilight")),
			"the pen refused a resident before it was full")
	assert_true(pen.is_full(), "the pen has to actually be full for this test to test anything")

	var storage = ranch.player.get_magic_beam().get_storage()
	assert_true(storage.store(PonyInstanceScript.create(&"twilight")),
		"there has to be a pony in the bag for the refusal to be about the pen")

	assert_false(ranch.call("_move_pony_into_pen", slot), "a full pen refuses")
	var first: Dictionary = ranch.last_denial()
	assert_eq(String(first["text"]), "That pen is full. Upgrade it, or build another pen.")
	for i in range(8):
		assert_false(ranch.call("_move_pony_into_pen", slot))
	var after: Dictionary = ranch.last_denial()
	assert_almost_eq(float(after["at"]), float(first["at"]), 0.0001,
		"eight more presses inside the debounce window said nothing new")


func test_a_refused_penning_never_costs_the_player_her_pony() -> void:
	# NO PONY EVER DIES covers bookkeeping. The refusal path must leave the bag exactly as
	# it found it, which is the guarantee _move_pony_into_pen()'s own comment makes.
	var ranch = await _ranch()
	var slot = ranch.plot_slots()[0]
	var catalogue = ranch.call("_plots_catalogue")
	assert_true(slot.build(catalogue.all()[0]))
	await wait_physics_frames(2)
	var pen = slot.get_built()
	while not pen.is_full():
		pen.add_pony(PonyInstanceScript.create(&"twilight"))
	var storage = ranch.player.get_magic_beam().get_storage()
	var mine = PonyInstanceScript.create(&"twilight")
	assert_true(storage.store(mine))
	var before: int = storage.contents().size()
	for i in range(5):
		ranch.call("_move_pony_into_pen", slot)
	assert_eq(storage.contents().size(), before, "she is still in the bag")
	assert_eq(storage.peek().uid, mine.uid, "and she is still the one at the top of it")


func test_a_different_refusal_is_always_heard() -> void:
	# The debounce is per MESSAGE, not a global mute. Being told "that pen is full" must not
	# swallow "your saddlebag is empty" a moment later; those are different facts and the
	# second one is the one she can act on.
	var ranch = await _ranch()
	var slot = ranch.plot_slots()[0]
	var catalogue = ranch.call("_plots_catalogue")
	assert_true(slot.build(catalogue.all()[0]))
	await wait_physics_frames(2)
	var pen = slot.get_built()
	while not pen.is_full():
		pen.add_pony(PonyInstanceScript.create(&"twilight"))
	var storage = ranch.player.get_magic_beam().get_storage()
	assert_true(storage.store(PonyInstanceScript.create(&"twilight")))
	assert_false(ranch.call("_move_pony_into_pen", slot))
	assert_eq(String(ranch.last_denial()["text"]), "That pen is full. Upgrade it, or build another pen.")
	# Empty the bag and ask again: a different refusal, said out loud.
	storage.release()
	assert_false(ranch.call("_move_pony_into_pen", slot))
	assert_eq(String(ranch.last_denial()["text"]), "Your saddlebag is empty.")


func test_the_debounce_window_is_shorter_than_the_toast_hold() -> void:
	# A window longer than the line stays on screen would leave a player who waited, read
	# the line, watched it fade and pressed again with silence. The toast's own hold is the
	# ceiling this has to sit under.
	# The constant lives on the script, so read it off the script: instantiating a whole
	# ranch (twice) to ask a class constant leaked four hundred orphans per run.
	var hud = load("res://ui/hud.gd")
	var ranch_script = load("res://world/ranch.gd")
	var window: float = ranch_script.get_script_constant_map().get("DENY_DEBOUNCE_SECONDS", 0.0)
	assert_gt(window, 0.0, "a zero window is no debounce at all")
	assert_lt(window, hud.get_script_constant_map().get("TOAST_HOLD", 0.0),
		"she must never wait out the line and then be met with silence")


func test_a_legal_penning_still_pens_her_on_the_first_press() -> void:
	var ranch = await _ranch()
	var slot = ranch.plot_slots()[0]
	var catalogue = ranch.call("_plots_catalogue")
	assert_true(slot.build(catalogue.all()[0]))
	await wait_physics_frames(2)
	var pen = slot.get_built()
	assert_false(pen.is_full(), "an empty pen is the point of this test")
	var storage = ranch.player.get_magic_beam().get_storage()
	var mine = PonyInstanceScript.create(&"twilight")
	assert_true(storage.store(mine))
	assert_true(ranch.call("_move_pony_into_pen", slot), "one press, and she is in")
	assert_true(pen.has_pony(mine.uid))
	assert_eq(storage.contents().size(), 0, "and out of the bag")


## PS1 item 65 ([52]): the last pony in read "Saffron Daydream moved into the pen." while the
## prompt already said the pen was full. The toast for the pony that fills it says both.
func test_the_pony_that_fills_the_pen_is_told_it_is_now_full() -> void:
	var ranch = await _ranch()
	var slot = ranch.plot_slots()[0]
	assert_true(slot.build(ranch.call("_plots_catalogue").by_id(&"pen_small")))
	await wait_physics_frames(2)
	var pen = slot.get_built()
	while pen.count() < pen.capacity - 1:
		assert_true(pen.add_pony(PonyInstanceScript.create(&"lyra")))
	var storage = ranch.player.get_magic_beam().get_storage()
	assert_true(storage.store(PonyInstanceScript.create(&"octavia")))
	assert_true(ranch.call("_move_pony_into_pen", slot))
	var hud: Node = ranch.get_node("HUD")
	var said: String = hud.call("toast_text") + " ".join(hud.call("pending_toasts"))
	assert_string_contains(said, "moved into the pen")
	assert_string_contains(said, "now full")
