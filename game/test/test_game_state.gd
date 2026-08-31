extends GutTest
## Tests for the savable world (game/systems/game_state.gd) -- the autoload that knows
## everything about a ranch that has to survive quitting the game.
##
## WHAT IS BEING PROTECTED HERE. GameState is the only object in the project whose
## contents a player can lose permanently, and the two ways to lose them are (a) a field
## that quietly does not serialise and (b) a bad load that overwrites good live state with
## nothing. Both are asserted below: every field is round-tripped through an actual file on
## disk, and a corrupt/missing file is required to leave the live state exactly as it was.
##
## WHY THE TESTS BUILD THEIR OWN INSTANCE. `GameState` is registered as an autoload
## (game/project.godot), so there is already one alive while this suite runs. Mutating THAT
## one would leak between tests and, worse, between this suite and whatever else reads it.
## Every test below constructs its own with .new() and calls the same public methods the
## autoload does. `_ready()` is not run for a node that was never added to the tree, so
## anything _ready() does is factored into a method the tests call explicitly
## (ensure_registry()) rather than hidden in the callback.
##
## Saves go to a scratch directory under user:// (SaveIO.save_dir is redirected in
## before_each), so running the suite can never overwrite the developer's real game.
##
## Preloads by path rather than by the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.

const GameStateScript := preload("res://systems/game_state.gd")
const SaveIOScript := preload("res://systems/save_io.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const GemPouchScript := preload("res://systems/gem_pouch.gd")
const InventoryScript := preload("res://systems/inventory.gd")
const CompendiumScript := preload("res://systems/compendium.gd")
const PlayerLookScript := preload("res://systems/player_look.gd")
const MarkStampsScript := preload("res://systems/mark_stamps.gd")

const SCRATCH_DIR := "user://test_scratch/game_state"
const SLOT := 3


func before_each() -> void:
	SaveIOScript.save_dir = SCRATCH_DIR
	_wipe()


func after_each() -> void:
	_wipe()
	SaveIOScript.save_dir = SaveIOScript.DEFAULT_SAVE_DIR
	# The resolver registry is a process-wide static (game/systems/pony_instance.gd), so a
	# test that injected one must not leak it into the next test or the next file.
	PonyInstanceScript.set_registry(null)


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


## A fresh, un-_ready()'d GameState, freed automatically when the test ends.
func _state():
	var state = GameStateScript.new()
	autofree(state)
	return state


## A populated world: two ponies (one of them a duplicate character, which is the whole
## point of PonyInstance), a wallet, two built plots and an unlock.
func _populated():
	var state = _state()
	var a = PonyInstanceScript.create(&"twilight", 1772150400000)
	a.nickname = "Sparkle"
	a.happiness = 0.75
	a.hunger = 0.25
	var b = PonyInstanceScript.create(&"twilight", 1772150401000)
	b.happiness = 0.25
	state.add_pony(a)
	state.add_pony(b)
	state.bits = 4321
	state.plots = {"0": "pen", "2": "garden"}
	state.unlocks = ["beam_range_1"]
	state.world_seed = 12345
	state.gems.add(PonyDataScript.Rarity.RARE, 3)
	state.inventory.add(&"hay", 4)
	state.compendium.mark_seen(&"rainbowdash")
	state.compendium.mark_caught(&"twilight")
	state.requests = [{"id": "sample_request", "done": false}]
	return state


# --- serialisation --------------------------------------------------------------------

func test_to_dict_and_from_dict_round_trip_every_field() -> void:
	var original = _populated()
	original.world_time = 733.5
	var copy = _state()
	copy.from_dict(original.to_dict())

	assert_eq(copy.bits, 4321, "the wallet survives")
	assert_eq(copy.world_seed, 12345, "the world seed survives")
	assert_almost_eq(copy.world_time, 733.5, 0.001, "the world clock survives")
	assert_eq_deep(copy.plots, {"0": "pen", "2": "garden"})
	assert_eq_deep(copy.unlocks, ["beam_range_1"])
	assert_eq(copy.pony_count(), 2, "both ponies came back")

	var first = copy.get_ponies()[0]
	assert_eq(String(first.uid), String(original.get_ponies()[0].uid), "uid survives")
	assert_eq(String(first.data_id), "twilight", "data_id survives")
	assert_eq(first.nickname, "Sparkle", "nickname survives")
	assert_almost_eq(first.happiness, 0.75, 0.0001, "happiness survives")
	assert_almost_eq(first.hunger, 0.25, 0.0001, "hunger survives")
	assert_eq(first.caught_at_ms, 1772150400000, "caught_at_ms survives")
	assert_eq(copy.gems.count(PonyDataScript.Rarity.RARE), 3, "gems survive")
	assert_eq(copy.inventory.count(&"hay"), 4, "inventory survives")
	assert_eq(copy.compendium.state_of(&"twilight"), CompendiumScript.State.CAUGHT,
		"the compendium survives")
	assert_eq(copy.compendium.state_of(&"rainbowdash"), CompendiumScript.State.SEEN)
	assert_eq_deep(copy.requests, [{"id": "sample_request", "done": false}])


func test_two_ponies_of_the_same_character_stay_two_ponies_across_a_round_trip() -> void:
	# The bug PonyInstance exists to fix, restated for the save file: if serialisation
	# collapsed on data_id, catching two Twilights and reloading would give you one.
	var copy = _state()
	copy.from_dict(_populated().to_dict())
	var ponies: Array = copy.get_ponies()
	assert_eq(ponies.size(), 2)
	assert_ne(String(ponies[0].uid), String(ponies[1].uid), "...with distinct uids")
	assert_almost_eq(ponies[0].happiness, 0.75, 0.0001, "...and independent state")
	assert_almost_eq(ponies[1].happiness, 0.25, 0.0001)


func test_to_dict_is_json_safe_so_the_save_file_stays_a_tradeable_blob() -> void:
	var dict: Dictionary = _populated().to_dict()
	var text := JSON.stringify(dict, "  ", true)
	var parsed: Variant = JSON.parse_string(text)
	assert_typeof(parsed, TYPE_DICTIONARY, "the whole state must survive real JSON")
	var copy = _state()
	copy.from_dict(parsed)
	assert_eq(copy.pony_count(), 2, "...and load back from the parsed JSON")
	assert_eq(copy.bits, 4321)


func test_from_dict_fills_in_a_missing_field_rather_than_crashing() -> void:
	var state = _state()
	state.from_dict({})
	assert_eq(state.pony_count(), 0, "an empty dict is an empty ranch, not a crash")
	assert_eq(state.bits, GameStateScript.STARTING_BITS)
	assert_eq(state.world_seed, GameStateScript.DEFAULT_WORLD_SEED)


func test_a_save_without_world_time_starts_at_dawn() -> void:
	var state = _state()
	state.from_dict({"bits": 1})
	assert_eq(state.world_time, 0.0, "a save from before the clock existed opens at dawn")


func test_from_dict_clamps_a_negative_world_time_to_zero() -> void:
	var state = _state()
	state.from_dict({"world_time": -5.0})
	assert_eq(state.world_time, 0.0, "a hand-edited negative clock cannot go below dawn")


func test_from_dict_skips_a_junk_pony_entry_and_keeps_the_good_ones() -> void:
	# Reachable for real: a hand-edited traded blob. One bad record must not cost the
	# player the rest of her ranch.
	var state = _state()
	state.from_dict({
		"ponies": [
			{"uid": "twilight#000001", "data_id": "twilight"},
			{"not": "a pony"},
			{"uid": "fluttershy#000002", "data_id": "fluttershy"},
		],
	})
	assert_eq(state.pony_count(), 2, "the two real records loaded")
	assert_eq(String(state.get_ponies()[1].uid), "fluttershy#000002",
		"...and the junk one was skipped, not substituted")


func test_a_pony_whose_character_this_build_does_not_have_still_loads() -> void:
	# A save from a build with a pony this one has not got (or a traded blob naming a
	# character the receiver lacks). She must survive the load as a record -- deleting her
	# would be the save system killing a pony, which this project does not do.
	var state = _state()
	state.from_dict({"ponies": [{"uid": "nopony#000001", "data_id": "nopony"}]})
	assert_eq(state.pony_count(), 1, "she is kept")
	assert_null(state.get_ponies()[0].data(), "...even though nothing resolves her")


func test_gems_and_inventory_round_trip() -> void:
	var state = _state()
	state.gems.add(PonyDataScript.Rarity.RARE, 3)
	state.inventory.add(&"hay", 4)
	var d := state.to_dict()
	assert_true(d.has("gems"))
	assert_true(d.has("inventory"))
	var back = _state()
	back.from_dict(d)
	assert_eq(back.gems.count(PonyDataScript.Rarity.RARE), 3)
	assert_eq(back.inventory.count(&"hay"), 4)


func test_a_save_without_gems_or_inventory_loads_with_empty_ones() -> void:
	var state = _state()
	state.gems.add(PonyDataScript.Rarity.COMMON, 1)
	state.from_dict({"bits": 7})
	assert_eq(state.bits, 7)
	assert_true(state.gems.is_empty(), "a version 1 save has no gems key")
	assert_eq(state.inventory.ids().size(), 0)


func test_reset_empties_gems_and_inventory() -> void:
	var state = _state()
	state.gems.add(PonyDataScript.Rarity.COMMON, 2)
	state.inventory.add(&"hay", 1)
	state.reset()
	assert_true(state.gems.is_empty())
	assert_eq(state.inventory.ids().size(), 0)


func test_compendium_and_requests_round_trip() -> void:
	var state = _state()
	state.compendium.mark_seen(&"fluttershy")
	state.requests = [{"id": "req_1", "reward_bits": 10}]
	var d := state.to_dict()
	assert_true(d.has("compendium"))
	assert_true(d.has("requests"))
	var back = _state()
	back.from_dict(d)
	assert_eq(back.compendium.state_of(&"fluttershy"), CompendiumScript.State.SEEN)
	assert_eq_deep(back.requests, [{"id": "req_1", "reward_bits": 10}])


func test_a_save_without_compendium_or_requests_loads_with_empty_ones() -> void:
	var state = _state()
	state.compendium.mark_caught(&"twilight")
	state.requests = [{"id": "leftover"}]
	state.from_dict({"bits": 7})
	assert_eq(state.bits, 7)
	assert_eq(state.compendium.state_of(&"twilight"), CompendiumScript.State.UNSEEN,
		"a version 3 save has no compendium key")
	assert_true(state.requests.is_empty(), "...nor a requests key")


func test_reset_gives_a_fresh_compendium_and_empty_requests() -> void:
	var state = _state()
	state.compendium.mark_caught(&"twilight")
	state.requests = [{"id": "leftover"}]
	state.reset()
	assert_eq(state.compendium.state_of(&"twilight"), CompendiumScript.State.UNSEEN)
	assert_true(state.requests.is_empty())


func test_the_ledger_round_trips_through_the_state() -> void:
	var state = _state()
	state.ledger.balance = 31000
	state.ledger.quota = 4
	var data: Dictionary = state.to_dict()
	var back = _state()
	back.from_dict(data)
	assert_eq(back.ledger.balance, 31000)
	assert_eq(back.ledger.quota, 4)


func test_a_load_replaces_the_ledger_rather_than_mutating_it() -> void:
	var state = _state()
	var old: Ledger = state.ledger
	state.from_dict({})
	assert_ne(state.ledger, old, "a listener holding the old account must be told to re-read")


## THE LIVE AUTOLOAD IS NOT TOUCHED HERE, for the reason the class comment gives: this
## suite builds its own GameState with .new() rather than mutating the registered one.
## `state.player`/`state.reset()`/`state.to_dict()`/`state.from_dict()` are the same methods
## an autoload-driven round trip would go through.
func test_the_player_look_round_trips_through_the_state() -> void:
	var state = _state()
	state.player.player_name = "Moonbeam"
	state.player.coat = 9
	state.player.set_mark(MarkStampsScript.build(MarkStampsScript.Stamp.STAR, Color.RED))
	var data: Dictionary = state.to_dict()
	state.reset()
	assert_eq(state.player.player_name, PlayerLookScript.DEFAULT_NAME)
	state.from_dict(data)
	assert_eq(state.player.player_name, "Moonbeam")
	assert_eq(state.player.coat, 9)
	assert_true(state.player.has_mark())


# --- the disk round trip ----------------------------------------------------------------

## THE REAL FILE, NOT JUST to_dict()/from_dict(). This is the path that actually round-trips
## through JSON.stringify() and JSON.parse() (SaveIO.save()/load()), which is where a whole
## number turns into a JSON float on the way back; to_dict()/from_dict() alone would pass
## even if from_dict() only ever saw real ints. The compendium and requests assertions below
## are what prove marks and requests survive THAT path, not just an in-memory copy.
func test_a_full_save_and_load_through_a_real_file_preserves_the_ranch() -> void:
	var original = _populated()
	assert_true(original.save_to_slot(SLOT), "the save reports success")
	assert_true(SaveIOScript.has_slot(SLOT), "...and there is a file to show for it")

	var reloaded = _state()
	assert_true(reloaded.load_from_slot(SLOT), "the load reports success")
	assert_eq(reloaded.bits, 4321)
	assert_eq(reloaded.pony_count(), 2)
	assert_eq(String(reloaded.get_ponies()[0].uid), String(original.get_ponies()[0].uid))
	assert_almost_eq(reloaded.get_ponies()[0].happiness, 0.75, 0.0001)
	assert_eq(reloaded.compendium.state_of(&"twilight"), CompendiumScript.State.CAUGHT,
		"a caught mark survives a real save file, JSON float and all")
	assert_eq(reloaded.compendium.state_of(&"rainbowdash"), CompendiumScript.State.SEEN,
		"...and so does a seen mark")
	assert_eq_deep(reloaded.requests, [{"id": "sample_request", "done": false}])


func test_a_uid_reloaded_from_disk_cannot_be_minted_again() -> void:
	# The save/load hazard PonyInstance documents: the mint counter has to clear every
	# restored serial, or the next capture after a load hands out a uid somebody owns.
	var state = _state()
	state.from_dict({"ponies": [{"uid": "twilight#009999", "data_id": "twilight"}]})
	state.save_to_slot(SLOT)
	var reloaded = _state()
	reloaded.load_from_slot(SLOT)
	var minted = PonyInstanceScript.create(&"twilight")
	assert_gt(PonyInstanceScript.serial_of(minted.uid), 9999,
		"a capture after a load must not collide with a loaded pony's uid")


func test_loading_a_slot_that_does_not_exist_leaves_the_live_state_alone() -> void:
	var state = _populated()
	assert_false(state.load_from_slot(SLOT), "there is nothing to load")
	assert_eq(state.pony_count(), 2, "...and the ranch in memory is untouched")
	assert_eq(state.bits, 4321)


func test_loading_a_corrupt_slot_fails_loudly_and_does_not_wipe_the_live_state() -> void:
	# THE nightmare: boot the game, the file is bad, and the act of failing to read it
	# replaces a hundred hours of ranch with an empty one.
	var state = _populated()
	state.save_to_slot(SLOT)
	var f := FileAccess.open(SaveIOScript.slot_path(SLOT), FileAccess.WRITE)
	f.store_string("{\"version\": 1, \"ponies\": [ truncated")
	f.close()

	assert_false(state.load_from_slot(SLOT), "the load fails")
	assert_push_error(1, "...loudly")
	assert_eq(state.pony_count(), 2, "...and the live ranch is still there")
	assert_eq(state.bits, 4321)


func test_has_save_reports_what_is_actually_on_disk() -> void:
	var state = _state()
	assert_false(state.has_save(SLOT))
	state.save_to_slot(SLOT)
	assert_true(state.has_save(SLOT))


# --- the roster of owned ponies ----------------------------------------------------------

func test_add_find_and_remove_address_individuals_not_characters() -> void:
	var state = _state()
	var a = PonyInstanceScript.create(&"twilight")
	var b = PonyInstanceScript.create(&"twilight")
	state.add_pony(a)
	state.add_pony(b)

	assert_eq(state.pony_count(), 2, "two Twilights are two ponies")
	assert_eq(state.find_pony(b.uid), b, "find addresses the individual")
	var removed = state.remove_pony(b.uid)
	assert_eq(removed, b, "...and so does remove")
	assert_eq(state.pony_count(), 1)
	assert_eq(state.find_pony(a.uid), a, "the other one is untouched")
	assert_null(state.find_pony(b.uid), "the removed one is gone")


func test_adding_null_is_refused_rather_than_stored() -> void:
	var state = _state()
	assert_false(state.add_pony(null))
	assert_eq(state.pony_count(), 0)


func test_removing_a_uid_that_is_not_there_returns_null() -> void:
	var state = _state()
	assert_null(state.remove_pony(&"twilight#000404"))


func test_reset_returns_the_world_to_a_new_game() -> void:
	var state = _populated()
	state.reset()
	assert_eq(state.pony_count(), 0)
	assert_eq(state.bits, GameStateScript.STARTING_BITS)
	assert_eq(state.world_seed, GameStateScript.DEFAULT_WORLD_SEED)
	assert_true(state.plots.is_empty())
	assert_true(state.unlocks.is_empty())


# --- the registry, loaded once ------------------------------------------------------------

func test_ensure_registry_hands_its_roster_to_pony_instance_instead_of_a_second_copy() -> void:
	# PonyInstance.get_registry() lazily loads res://data/ponies into a static the first
	# time anything resolves a data_id. GameState has already loaded that roster, so it
	# injects its own rather than letting a second copy load behind it (flagged during
	# Task 1's review as exactly the kind of duplicate that drifts).
	PonyInstanceScript.set_registry(null)
	var state = _state()
	var registry = state.ensure_registry()
	assert_not_null(registry, "GameState owns a registry")
	assert_eq(PonyInstanceScript.get_registry(), registry,
		"...and it is the one PonyInstance resolves through -- not a second load")
	assert_eq(registry.by_id(&"twilight").id, &"twilight", "...and it really has the roster")


func test_ensure_registry_is_idempotent() -> void:
	var state = _state()
	assert_eq(state.ensure_registry(), state.ensure_registry(),
		"the roster is loaded once per process, not once per call")


# --- quitting ------------------------------------------------------------------------------

func test_autosave_is_off_by_default_so_an_automated_run_cannot_clobber_a_save() -> void:
	# Every gate, export smoke run and GUT suite in this project boots the real main scene
	# with the real autoloads. If quitting saved unconditionally, `bash tools/run_tests.sh`
	# would overwrite the developer's ranch with an empty one.
	var state = _state()
	assert_false(state.autosave_enabled, "off unless a scene deliberately turns it on")
	state.bits = 99
	assert_false(state.save_on_quit(), "...and quitting writes nothing")
	assert_false(state.has_save(GameStateScript.DEFAULT_SLOT), "no file appeared")


func test_every_write_pulls_the_live_world_in_first() -> void:
	# The ponies the player is carrying live in the beam's Storage, not in here. A save
	# that did not copy them across first would write an empty roster for any session that
	# had not already saved -- and the save-on-QUIT path runs from a notification, with no
	# scene code in the call stack to do the copying. So the sync hangs off the WRITE.
	var state = _state()
	var synced := [0]
	state.world_sync = func() -> void:
		synced[0] += 1
		state.bits = 555
	assert_true(state.save_to_slot(SLOT))
	assert_eq(synced[0], 1, "the sync ran exactly once, before the write")

	var reloaded = _state()
	reloaded.load_from_slot(SLOT)
	assert_eq(reloaded.bits, 555, "...and what it produced is what landed in the file")


func test_a_stale_sync_callable_is_skipped_rather_than_crashing() -> void:
	# Reachable during teardown: the scene that registered the callback can be freed before
	# the autoload's own quit save runs.
	var state = _state()
	var owner := Node.new()
	state.world_sync = Callable(owner, "queue_free")
	owner.free()
	assert_true(state.save_to_slot(SLOT), "a dead callback must not take the save down")


func test_leaving_the_tree_is_what_actually_triggers_the_quit_save() -> void:
	# The WIRING, not just the method. save_on_quit() being correct is worth nothing if
	# nothing calls it: `get_tree().quit()` -- which is how the game and every gate end --
	# does NOT send NOTIFICATION_WM_CLOSE_REQUEST, only the tree teardown, so the handler
	# has to cover both. This test drives the real notification by taking a node out of a
	# real tree, which is the closest a headless suite can get to closing the window.
	var state = GameStateScript.new()
	add_child(state)
	state.autosave_enabled = true
	state.bits = 8080
	remove_child(state)
	state.free()

	var reloaded = _state()
	assert_true(reloaded.load_from_slot(GameStateScript.DEFAULT_SLOT),
		"leaving the tree wrote a save")
	assert_eq(reloaded.bits, 8080, "...of the state as it was on the way out")


func test_leaving_the_tree_writes_nothing_when_autosave_is_off() -> void:
	# The other half, and the one that protects the developer's ranch: every automated run
	# in this project tears this same autoload down at the end.
	var state = GameStateScript.new()
	add_child(state)
	state.bits = 9090
	remove_child(state)
	state.free()
	assert_false(SaveIOScript.has_slot(GameStateScript.DEFAULT_SLOT),
		"an automated run must not leave a save behind just by exiting")


func test_save_on_quit_writes_when_a_scene_has_enabled_it() -> void:
	var state = _populated()
	state.autosave_enabled = true
	assert_true(state.save_on_quit(), "an interactive session saves on the way out")
	var reloaded = _state()
	assert_true(reloaded.load_from_slot(GameStateScript.DEFAULT_SLOT))
	assert_eq(reloaded.pony_count(), 2, "...and it is the ranch that was on screen")


# --- the chip purse in the save file -----------------------------------------------------

func test_the_chip_purse_round_trips_through_the_state() -> void:
	var state = _state()
	state.casino.add_chips(750)
	var data: Dictionary = state.to_dict()
	var back = _state()
	back.from_dict(data)
	assert_eq(back.casino.chips, 750)


func test_a_state_with_no_casino_key_loads_with_an_empty_purse() -> void:
	var state = _state()
	state.casino.add_chips(500)
	state.from_dict({"bits": 10})
	assert_eq(state.casino.chips, 0, "a save from before the Palace opened holds no chips")


func test_reset_empties_the_purse_and_replaces_it() -> void:
	var state = _state()
	var before: Casino = state.casino
	state.casino.add_chips(90)
	state.reset()
	assert_eq(state.casino.chips, 0)
	assert_ne(state.casino, before, "replaced, not mutated; a listener on the old one is stale")
