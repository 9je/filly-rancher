extends GutTest
## Tests for the save file reader/writer (game/systems/save_io.gd).
##
## WHAT THIS FILE IS DEFENDING. A save file is the one artefact in this project the
## player can LOSE. Every other failure mode here costs a run; a bad write costs the
## ranch. So the tests below are weighted toward the ways a save system destroys data
## rather than toward the happy path:
##
##   * an interrupted write must not corrupt the previous save (the write is staged to a
##     temp file and published by rename -- see test_a_staged_write_that_never_commits...);
##   * a corrupt or truncated file must fail LOUDLY and must not be deleted, rewritten or
##     "repaired" by the loader -- a player whose file went bad can still hand it to
##     somebody who knows JSON, but not if the game silently overwrote it on the next boot;
##   * a save written by a NEWER build must be refused rather than half-read. Reading a
##     future version with today's field meanings is how a save gets silently downgraded
##     and then written back with everything the newer build added stripped out;
##   * a missing slot is NOT an error -- it is a new game -- so it comes back as an empty
##     dictionary, not a crash and not a push_error.
##
## THE FILES ARE HUMAN-READABLE JSON ON PURPOSE. The design spec wants two players able to
## trade a pony by sending each other a blob, so "is this still text a human can read and
## a human can paste" is an actual requirement and is asserted here, not an implementation
## detail that may drift.
##
## Every test writes into its own scratch directory under user:// (see SCRATCH_DIR) rather
## than into the real user://saves, so running the suite can never clobber the developer's
## own game. Preloads by path rather than by the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.

const SaveIOScript := preload("res://systems/save_io.gd")
const GameStateScript := preload("res://systems/game_state.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const CompendiumScript := preload("res://systems/compendium.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const LedgerScript := preload("res://systems/ledger.gd")

## Where these tests write. Deliberately NOT SaveIO's default directory.
const SCRATCH_DIR := "user://test_scratch/save_io"

## A payload with one of every JSON-representable shape the real save uses: nested
## dictionaries (the wallet/plots), arrays of dictionaries (the roster), ints, floats,
## bools and strings -- so "round-trips every field" means something wider than a flat
## bag of strings.
const PAYLOAD := {
	"world_seed": 20260839,
	"bits": 1234,
	"unlocks": ["barn", "beam_range_1"],
	"roster": [
		{"uid": "twilight#000001", "data_id": "twilight", "nickname": "Sparkle",
			"happiness": 0.625, "hunger": 0.375, "caught_at_ms": 1772150400000},
		{"uid": "fluttershy#000002", "data_id": "fluttershy", "nickname": "",
			"happiness": 0.5, "hunger": 0.0, "caught_at_ms": 0},
	],
	"plots": {"0": "pen", "3": "garden"},
	"tutorial_done": true,
}

const SLOT := 1


func before_each() -> void:
	SaveIOScript.save_dir = SCRATCH_DIR
	_wipe()


func after_each() -> void:
	_wipe()
	SaveIOScript.save_dir = SaveIOScript.DEFAULT_SAVE_DIR


## Remove the whole scratch directory between tests -- the directory itself as well as its
## contents, so "saving creates the directory it needs" is testable -- and so no test can
## pass because of a file another test left behind.
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
	DirAccess.remove_absolute(SCRATCH_DIR)


func _read_raw(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


func _write_raw(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH_DIR)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# --- the happy path, stated precisely ------------------------------------------------

func test_a_round_trip_preserves_every_field() -> void:
	assert_true(SaveIOScript.save(SLOT, PAYLOAD), "the save must report success")
	var loaded := SaveIOScript.load(SLOT)
	for key in PAYLOAD:
		assert_true(loaded.has(key), "'%s' survived the round trip" % key)
	assert_eq(int(loaded["world_seed"]), PAYLOAD["world_seed"], "the world seed survives")
	assert_eq(int(loaded["bits"]), PAYLOAD["bits"])
	assert_eq(loaded["tutorial_done"], true, "a bool comes back a bool")
	assert_eq_deep(loaded["unlocks"], PAYLOAD["unlocks"])
	assert_eq_deep(loaded["plots"], PAYLOAD["plots"])
	var roster: Array = loaded["roster"]
	assert_eq(roster.size(), 2, "both ponies came back")
	assert_eq(roster[0]["uid"], "twilight#000001", "...with their uids intact")
	assert_almost_eq(float(roster[0]["happiness"]), 0.625, 0.0001,
		"...and their state, to the precision the file was written with")


func test_a_whole_number_comes_back_as_a_json_number_and_int_recovers_it_exactly() -> void:
	# JSON HAS NO INTEGER TYPE, and pretending otherwise is how a save system starts
	# silently rounding. Every number in a loaded save is a FLOAT, and callers are
	# expected to int() the ones that are counts -- GameState.from_dict does exactly that.
	# What this pins is that the recovery is EXACT for the magnitudes this game uses: a
	# double holds every integer below 2^53, and the biggest number in a save is
	# caught_at_ms, a millisecond Unix time of about 1.8e12.
	SaveIOScript.save(SLOT, PAYLOAD)
	var loaded := SaveIOScript.load(SLOT)
	assert_typeof(loaded["bits"], TYPE_FLOAT,
		"a whole number reloads as a JSON number, not as an int -- callers must int() it")
	assert_eq(int(loaded["bits"]), 1234, "...and int() gets the exact value back")
	var caught: float = loaded["roster"][0]["caught_at_ms"]
	assert_eq(int(caught), 1772150400000,
		"a millisecond Unix time survives the double exactly (it is far below 2^53)")


func test_the_file_is_human_readable_json_with_a_version_in_it() -> void:
	# Not a style preference: the spec wants two players able to trade a pony by sending
	# each other a blob, which only works if the blob is text a person can open.
	SaveIOScript.save(SLOT, PAYLOAD)
	var raw := _read_raw(SaveIOScript.slot_path(SLOT))
	assert_false(raw.is_empty(), "the file has content")
	assert_string_contains(raw, "\n", "it is indented across lines, not one long line")
	assert_string_contains(raw, "twilight#000001", "a pony's uid is readable in it")
	assert_string_contains(raw, "\"version\"", "every save carries its format version")
	var parsed: Variant = JSON.parse_string(raw)
	assert_typeof(parsed, TYPE_DICTIONARY, "and it is valid JSON to anything else too")
	assert_eq(int((parsed as Dictionary)["version"]), SaveIOScript.FORMAT_VERSION)


func test_the_slot_path_is_the_documented_one() -> void:
	SaveIOScript.save_dir = SaveIOScript.DEFAULT_SAVE_DIR
	assert_eq(SaveIOScript.slot_path(0), "user://saves/slot_0.json",
		"the layout other tooling and bug reports refer to")
	assert_eq(SaveIOScript.slot_path(12), "user://saves/slot_12.json")


func test_saving_creates_the_directory_it_needs() -> void:
	# A fresh install has no user://saves at all -- and on Windows user:// itself may not
	# exist until something writes there (docs/windows-testing.md).
	assert_false(DirAccess.dir_exists_absolute(SCRATCH_DIR),
		"precondition: the scratch dir is gone")
	assert_true(SaveIOScript.save(SLOT, PAYLOAD), "the first save must create its directory")
	assert_true(SaveIOScript.has_slot(SLOT))


func test_saving_does_not_mutate_the_callers_dictionary() -> void:
	var payload := {"bits": 5}
	SaveIOScript.save(SLOT, payload)
	assert_false(payload.has("version"),
		"the version stamp belongs in the FILE, not in the live game state")


func test_has_slot_and_delete_slot_agree_with_the_filesystem() -> void:
	assert_false(SaveIOScript.has_slot(SLOT), "nothing saved yet")
	SaveIOScript.save(SLOT, PAYLOAD)
	assert_true(SaveIOScript.has_slot(SLOT))
	assert_true(SaveIOScript.delete_slot(SLOT))
	assert_false(SaveIOScript.has_slot(SLOT), "a deleted slot is gone")
	assert_eq(SaveIOScript.load(SLOT), {}, "...and reads back as a new game")


# --- a missing slot is a new game, not a failure -------------------------------------

func test_loading_a_missing_slot_returns_an_empty_dict_rather_than_crashing() -> void:
	var loaded := SaveIOScript.load(7)
	assert_typeof(loaded, TYPE_DICTIONARY, "a missing slot still answers with a dictionary")
	assert_true(loaded.is_empty(), "...an empty one")


func test_loading_a_missing_slot_is_silent() -> void:
	# "No save yet" is the state EVERY first run is in. If it push_error'd, every new
	# game would open with an error in the log and the real errors would be noise.
	SaveIOScript.load(7)
	assert_push_error(0, "a first run must not report an error just for having no save")


# --- corruption: loud, and non-destructive -------------------------------------------

func test_a_truncated_file_fails_loudly_and_is_left_on_disk_untouched() -> void:
	SaveIOScript.save(SLOT, PAYLOAD)
	var path := SaveIOScript.slot_path(SLOT)
	var good := _read_raw(path)
	var truncated := good.substr(0, good.length() / 2)
	_write_raw(path, truncated)

	var loaded := SaveIOScript.load(SLOT)
	assert_true(loaded.is_empty(), "a truncated save loads as nothing, not as half a ranch")
	assert_push_error(1, "...and says so loudly rather than failing silently")
	assert_eq(_read_raw(path), truncated,
		"the loader must not delete, rewrite or 'repair' the file it could not read")


func test_a_file_that_is_not_json_at_all_fails_the_same_way() -> void:
	_write_raw(SaveIOScript.slot_path(SLOT), "this is not a save file")
	assert_true(SaveIOScript.load(SLOT).is_empty())
	assert_push_error(1)


func test_a_json_file_that_is_not_a_dictionary_is_refused() -> void:
	# Valid JSON, wrong shape -- e.g. somebody pasted just the roster array in.
	_write_raw(SaveIOScript.slot_path(SLOT), "[1, 2, 3]")
	assert_true(SaveIOScript.load(SLOT).is_empty())
	assert_push_error(1)


func test_a_file_with_no_version_field_is_refused() -> void:
	# Not one of ours: nothing can be said about what its fields mean.
	_write_raw(SaveIOScript.slot_path(SLOT), "{\"bits\": 10}")
	assert_true(SaveIOScript.load(SLOT).is_empty())
	assert_push_error(1)


# --- the version policy ----------------------------------------------------------------

func test_a_save_from_a_newer_build_refuses_to_load_rather_than_be_misread() -> void:
	# The failure this prevents: the newer build changed what a field MEANS, this build
	# reads it with the old meaning, the player plays on, and the next save writes the
	# misread state back over the good one. Refusing leaves the file untouched, so
	# reinstalling the newer build recovers it.
	var future := PAYLOAD.duplicate(true)
	future["version"] = SaveIOScript.FORMAT_VERSION + 1
	_write_raw(SaveIOScript.slot_path(SLOT), JSON.stringify(future, "  ", true))

	var loaded := SaveIOScript.load(SLOT)
	assert_true(loaded.is_empty(), "a future save must not load at all")
	assert_push_error(1, "...and must say why")
	var raw := _read_raw(SaveIOScript.slot_path(SLOT))
	assert_string_contains(raw, "twilight#000001",
		"...and must leave the file intact so the newer build can still read it")


func test_the_version_policy_is_stated_and_pinned() -> void:
	assert_eq(SaveIOScript.FORMAT_VERSION, 5, "the current format version")
	assert_true(SaveIOScript.can_load_version(SaveIOScript.FORMAT_VERSION),
		"this build's own version loads")
	assert_false(SaveIOScript.can_load_version(SaveIOScript.FORMAT_VERSION + 1),
		"a newer version does not")
	assert_false(SaveIOScript.can_load_version(0), "and neither does a nonsense one")
	for v in range(1, SaveIOScript.FORMAT_VERSION + 1):
		assert_true(SaveIOScript.can_load_version(v),
			"every version this build has ever written stays loadable (v%d)" % v)


func test_a_version_1_file_loads_and_gains_empty_gems_and_inventory() -> void:
	var v1 := {"version": 1, "bits": 12, "ponies": [], "plots": {}, "unlocks": [], "world_seed": 5}
	var migrated := SaveIOScript.migrate(v1, 1)
	assert_eq(migrated.get("bits"), 12, "existing fields survive")
	assert_true(migrated.has("gems"), "migration adds the gems key")
	assert_true(migrated.has("inventory"), "migration adds the inventory key")
	assert_eq(migrated["gems"], {})
	assert_eq(migrated["inventory"], {})
	assert_true(migrated.has("world_time"), "migration adds the world_time key")
	assert_eq(migrated["world_time"], 0.0)
	assert_true(migrated.has("compendium"), "migration adds the compendium key")
	assert_eq(migrated["compendium"], {})
	assert_true(migrated.has("requests"), "migration adds the requests key")
	assert_eq(migrated["requests"], [])


## A dedicated direct-migrate test for the branch THIS task adds, mirroring the v1 one
## above but starting one version later (gems, inventory and world_time already present)
## so it proves the new branch on its own rather than only as a side effect of the older
## one's cumulative `from_version < 4` check.
func test_a_version_3_file_gains_empty_compendium_and_requests() -> void:
	var v3 := {
		"version": 3, "bits": 12, "ponies": [], "plots": {}, "unlocks": [],
		"world_seed": 5, "gems": {}, "inventory": {}, "world_time": 0.0,
	}
	var migrated := SaveIOScript.migrate(v3, 3)
	assert_eq(migrated.get("bits"), 12, "existing fields survive")
	assert_true(migrated.has("compendium"), "migration adds the compendium key")
	assert_eq(migrated["compendium"], {})
	assert_true(migrated.has("requests"), "migration adds the requests key")
	assert_eq(migrated["requests"], [])


func test_the_format_version_is_five() -> void:
	assert_eq(SaveIOScript.FORMAT_VERSION, 5)
	assert_true(SaveIOScript.can_load_version(1))
	assert_true(SaveIOScript.can_load_version(4))
	assert_true(SaveIOScript.can_load_version(5))
	assert_false(SaveIOScript.can_load_version(6))


## A dedicated direct-migrate test for the branch THIS task adds, mirroring the v1 and v3
## ones above but starting one version later still, so it proves the new branch on its own.
func test_migrating_a_version_four_save_gives_it_a_ledger() -> void:
	var migrated: Dictionary = SaveIOScript.migrate(
		{"bits": 40, "compendium": {}, "requests": []}, 4)
	assert_eq(migrated["ledger"], {})
	var ledger: Ledger = LedgerScript.from_dict(migrated["ledger"])
	assert_eq(ledger.balance, LedgerScript.STARTING_BALANCE,
		"a ranch from before the Company opens its account at the sponsorship balance")


func test_a_version_four_file_on_disk_loads_in_this_build() -> void:
	var path: String = SaveIOScript.slot_path(SLOT)
	_write_raw(path, JSON.stringify({"version": 4, "bits": 77,
		"compendium": {"twilight": 2}, "requests": []}, "  ", true))
	var loaded: Dictionary = SaveIOScript.load(SLOT)
	assert_eq(int(loaded["version"]), 5, "it is brought up to today's shape")
	assert_eq(int(loaded["bits"]), 77, "and nothing it did say is lost")
	assert_eq(loaded["ledger"], {})


## THE WHOLE PATH, NOT THE MIGRATION ON ITS OWN. The test above calls migrate() directly,
## which proves the transform and nothing about the two ends of it. This one is the composed
## route a player on an older save actually takes: a version-1 file on disk, written by a
## build that had never heard of gems or of an inventory, read through SaveIO.load() and
## poured into a GameState. It is the only test that would catch a load() that forgot to
## call migrate(), or a from_dict() that choked on the keys migration adds.
##
## The fixture is hand-written rather than produced by this build, on purpose: a v1 file is
## exactly what this build can no longer write.
func test_a_version_1_file_on_disk_loads_all_the_way_into_a_game_state() -> void:
	var v1 := {
		"version": 1,
		"bits": 640,
		"ponies": [
			{"uid": "twilight#000001", "data_id": "twilight", "nickname": "Sparkle",
				"happiness": 0.75, "hunger": 0.25, "caught_at_ms": 1772150400000},
			{"uid": "fluttershy#000002", "data_id": "fluttershy", "nickname": "",
				"happiness": 0.5, "hunger": 0.0, "caught_at_ms": 0},
		],
		"plots": {"0": "pen"},
		"unlocks": ["bigger_saddlebag"],
		"world_seed": 20260839,
	}
	_write_raw(SaveIOScript.slot_path(SLOT), JSON.stringify(v1, "  ", true))

	var loaded := SaveIOScript.load(SLOT)
	assert_false(loaded.is_empty(), "a version-1 save still loads on this build")
	assert_eq(int(loaded["version"]), 5,
		"...and arrives stamped with the version it was migrated to, not the one on disk")

	var state = GameStateScript.new()
	autofree(state)
	state.from_dict(loaded)

	assert_eq(state.bits, 640, "the wallet survived the trip")
	assert_eq(state.world_seed, 20260839, "so did the world it was generated from")
	assert_eq(state.pony_count(), 2, "both ponies came back")
	assert_eq(String(state.get_ponies()[0].uid), "twilight#000001", "...with their uids")
	assert_almost_eq(state.get_ponies()[0].happiness, 0.75, 0.0001, "...and their state")
	assert_eq(String(state.plots.get("0", "")), "pen", "the plot she built is still built")
	assert_true(state.unlocks.has("bigger_saddlebag"), "the gear she bought is still bought")

	assert_true(state.gems.is_empty(),
		"a save from before gems existed comes back with an empty pouch, not a broken one")
	assert_true(state.inventory.ids().is_empty(), "and with an empty pantry")
	assert_eq(state.world_time, 0.0,
		"a save from before the clock existed comes back at dawn, not broken")
	assert_eq(state.compendium.state_of(&"twilight"), CompendiumScript.State.UNSEEN,
		"a save from before the compendium existed comes back with nobody marked, " +
		"even for a pony she owns; a later task's ranch code backfills owned ponies on load")
	assert_true(state.requests.is_empty(), "and with no requests pending")
	assert_eq(state.ledger.balance, Ledger.STARTING_BALANCE,
		"a save from before the Company opens its account at the sponsorship balance")


## The same composed proof, one version later: a version-2 file (gems and inventory exist,
## the world clock does not) read through SaveIO.load() and poured into a GameState. Written
## by hand for the same reason the v1 fixture is: a v2 file is exactly what this build can no
## longer write on its own.
func test_a_version_2_file_on_disk_loads_all_the_way_into_a_game_state() -> void:
	var v2 := {
		"version": 2,
		"bits": 640,
		"ponies": [
			{"uid": "twilight#000001", "data_id": "twilight", "nickname": "Sparkle",
				"happiness": 0.75, "hunger": 0.25, "caught_at_ms": 1772150400000},
		],
		"plots": {"0": "pen"},
		"unlocks": ["bigger_saddlebag"],
		"world_seed": 20260839,
		"gems": {"2": 3},
		"inventory": {"hay": 4},
	}
	_write_raw(SaveIOScript.slot_path(SLOT), JSON.stringify(v2, "  ", true))

	var loaded := SaveIOScript.load(SLOT)
	assert_false(loaded.is_empty(), "a version-2 save still loads on this build")
	assert_eq(int(loaded["version"]), 5,
		"...and arrives stamped with the version it was migrated to, not the one on disk")

	var state = GameStateScript.new()
	autofree(state)
	state.from_dict(loaded)

	assert_eq(state.bits, 640, "the wallet survived the trip")
	assert_eq(state.pony_count(), 1, "the pony came back")
	assert_eq(state.gems.count(PonyDataScript.Rarity.RARE), 3, "the gems survive")
	assert_eq(state.inventory.count(&"hay"), 4, "so did the pantry")
	assert_eq(state.world_time, 0.0,
		"a save from before the clock existed comes back at dawn, not broken")
	assert_eq(state.compendium.state_of(&"twilight"), CompendiumScript.State.UNSEEN,
		"a save from before the compendium existed comes back with nobody marked")
	assert_true(state.requests.is_empty(), "and with no requests pending")
	assert_eq(state.ledger.balance, Ledger.STARTING_BALANCE,
		"a save from before the Company opens its account at the sponsorship balance")


## The same composed proof, one version later still: a version-3 file (gems, inventory and
## the world clock all exist; the compendium and requests do not) read through
## SaveIO.load() and poured into a GameState. Hand-written for the same reason the v1 and v2
## fixtures are: a v3 file is exactly what this build can no longer write on its own.
func test_a_version_3_file_on_disk_loads_all_the_way_into_a_game_state() -> void:
	var v3 := {
		"version": 3,
		"bits": 640,
		"ponies": [
			{"uid": "twilight#000001", "data_id": "twilight", "nickname": "Sparkle",
				"happiness": 0.75, "hunger": 0.25, "caught_at_ms": 1772150400000},
		],
		"plots": {"0": "pen"},
		"unlocks": ["bigger_saddlebag"],
		"world_seed": 20260839,
		"gems": {"2": 3},
		"inventory": {"hay": 4},
		"world_time": 733.5,
	}
	_write_raw(SaveIOScript.slot_path(SLOT), JSON.stringify(v3, "  ", true))

	var loaded := SaveIOScript.load(SLOT)
	assert_false(loaded.is_empty(), "a version-3 save still loads on this build")
	assert_eq(int(loaded["version"]), 5,
		"...and arrives stamped with the version it was migrated to, not the one on disk")

	var state = GameStateScript.new()
	autofree(state)
	state.from_dict(loaded)

	assert_eq(state.bits, 640, "the wallet survived the trip")
	assert_eq(state.pony_count(), 1, "the pony came back")
	assert_eq(state.gems.count(PonyDataScript.Rarity.RARE), 3, "the gems survive")
	assert_eq(state.inventory.count(&"hay"), 4, "so did the pantry")
	assert_almost_eq(state.world_time, 733.5, 0.001, "the world clock survives")
	assert_eq(state.compendium.state_of(&"twilight"), CompendiumScript.State.UNSEEN,
		"a save from before the compendium existed comes back with nobody marked, " +
		"even for a pony she owns; a later task's ranch code backfills owned ponies on load")
	assert_true(state.requests.is_empty(), "and with no requests pending")
	assert_eq(state.ledger.balance, Ledger.STARTING_BALANCE,
		"a save from before the Company opens its account at the sponsorship balance")


# --- atomicity: an interrupted write must not cost the previous save ------------------

func test_a_staged_write_that_never_commits_leaves_the_previous_save_intact() -> void:
	# This is the unit-test half of the atomic-write proof. The other half kills a real
	# process between stage() and commit() -- see the report for that run. save() is
	# stage() followed by commit() precisely so the interruption point is reachable and
	# provable rather than only reasoned about.
	SaveIOScript.save(SLOT, PAYLOAD)
	var before := _read_raw(SaveIOScript.slot_path(SLOT))

	var doomed := {"bits": 999999, "roster": []}
	assert_true(SaveIOScript.stage(SLOT, doomed), "the temp file is written first")
	assert_true(FileAccess.file_exists(SaveIOScript.temp_path(SLOT)),
		"...to a temp path, not over the live save")

	assert_eq(_read_raw(SaveIOScript.slot_path(SLOT)), before,
		"the live save is byte-identical while a write is in flight")
	var loaded := SaveIOScript.load(SLOT)
	assert_eq(loaded["bits"], PAYLOAD["bits"],
		"...and an interrupted write leaves the OLD ranch loadable, not a half-written one")


func test_committing_publishes_the_staged_write_and_clears_the_temp_file() -> void:
	SaveIOScript.save(SLOT, PAYLOAD)
	SaveIOScript.stage(SLOT, {"bits": 42})
	assert_true(SaveIOScript.commit(SLOT), "commit publishes it")
	assert_eq(SaveIOScript.load(SLOT)["bits"], 42, "the new state is live")
	assert_false(FileAccess.file_exists(SaveIOScript.temp_path(SLOT)),
		"the temp file is consumed by the rename, not left lying around")


func test_committing_nothing_fails_loudly_and_changes_nothing() -> void:
	SaveIOScript.save(SLOT, PAYLOAD)
	assert_false(SaveIOScript.commit(SLOT), "there is no staged write to publish")
	assert_push_error(1)
	assert_eq(SaveIOScript.load(SLOT)["bits"], PAYLOAD["bits"], "the save is untouched")


func test_the_previous_save_is_kept_as_a_backup() -> void:
	# On Linux the rename alone is atomic. On Windows Godot's DirAccess.rename REMOVES an
	# existing destination and then renames, so there is a (tiny) window where the live
	# file is gone -- see save_io.gd. The backup is what covers that window, and it is
	# also the thing a player can hand back to themselves after a bad save.
	SaveIOScript.save(SLOT, PAYLOAD)
	SaveIOScript.save(SLOT, {"bits": 42})
	var backup := _read_raw(SaveIOScript.backup_path(SLOT))
	assert_string_contains(backup, "twilight#000001",
		"the PREVIOUS save is preserved beside the new one")
	assert_eq(SaveIOScript.load(SLOT)["bits"], 42, "and the new one is what loads")


func test_a_leftover_temp_file_from_a_crash_does_not_affect_a_load() -> void:
	SaveIOScript.save(SLOT, PAYLOAD)
	_write_raw(SaveIOScript.temp_path(SLOT), "{\"version\": 1, \"bits\": 7}")
	assert_eq(SaveIOScript.load(SLOT)["bits"], PAYLOAD["bits"],
		"an abandoned temp file is not a save and is never read as one")


# --- refusals --------------------------------------------------------------------------

func test_a_negative_slot_is_refused_rather_than_written_somewhere_odd() -> void:
	assert_false(SaveIOScript.save(-1, PAYLOAD))
	assert_true(SaveIOScript.load(-1).is_empty())
	assert_push_error(2,
		"both the refused write and the refused read say so -- a negative slot is a caller bug, not a new game")


func test_a_payload_that_is_not_json_representable_is_refused_before_anything_is_written() -> void:
	# JSON.stringify turns an Object into `null` without complaint, which would write a
	# perfectly valid file with the roster silently replaced by nulls. Catch it at the
	# door instead, and -- critically -- do not touch the existing save on the way out.
	SaveIOScript.save(SLOT, PAYLOAD)
	var bad := {"roster": [RefCounted.new()]}
	assert_false(SaveIOScript.save(SLOT, bad), "a payload that cannot be represented is refused")
	assert_push_error(1)
	assert_eq(SaveIOScript.load(SLOT)["bits"], PAYLOAD["bits"],
		"...and the previous save is still there")


# --- a stock pony's colours in the save file ---------------------------------------------

func test_a_stock_pony_survives_a_whole_save_round_trip() -> void:
	var inst := PonyInstanceScript.create(&"stock_shy")
	inst.stock = {"coat": 5, "mane": 2, "eyes": 4}
	inst.home_slot = &"plot_a"
	assert_true(SaveIOScript.save(SLOT, {"ponies": [inst.to_dict()]}))
	var loaded := SaveIOScript.load(SLOT)
	var back := PonyInstanceScript.from_dict(loaded["ponies"][0])
	assert_eq(back.stock, {"coat": 5, "mane": 2, "eyes": 4, "mane_style": 0},
		"a stock save with no mane_style key defaults to 0, the shipped base")
	assert_eq(back.data_id, &"stock_shy")
	assert_eq(back.home_slot, &"plot_a")


# --- the player's own look in the save file -----------------------------------------------

func test_a_version_four_save_gets_twilight_with_a_blank_mark() -> void:
	var migrated: Dictionary = SaveIOScript.migrate({"bits": 40}, 4)
	assert_eq(migrated["player"], {})
	var look: PlayerLook = PlayerLook.from_dict(migrated["player"])
	assert_eq(look.player_name, PlayerLook.DEFAULT_NAME)
	assert_false(look.has_mark())


func test_a_drawn_mark_survives_the_file_on_disk() -> void:
	var look: PlayerLook = PlayerLook.default_look()
	var drawn: Image = MarkStamps.build(MarkStamps.Stamp.FLOWER, Color(0.4, 0.8, 0.3))
	look.set_mark(drawn)
	assert_true(SaveIOScript.save(SLOT, {"player": look.to_dict()}))
	var loaded: Dictionary = SaveIOScript.load(SLOT)
	assert_true(MarkPaint.equal(PlayerLook.from_dict(loaded["player"]).mark(), drawn),
		"the save is one self contained JSON blob and the drawing comes back exactly")


# --- the chip purse in the save file -------------------------------------------------------

func test_a_version_5_save_carries_the_casino_key_back_intact() -> void:
	var written := {"bits": 10, "casino": {"chips": 321}}
	assert_true(SaveIOScript.save(SLOT, written))
	var back := SaveIOScript.load(SLOT)
	assert_eq(int((back["casino"] as Dictionary)["chips"]), 321)


func test_a_version_5_save_written_before_the_palace_opened_loads_with_no_chips() -> void:
	var written := {"bits": 10}
	assert_true(SaveIOScript.save(SLOT, written))
	var back := SaveIOScript.load(SLOT)
	assert_false(back.has("casino"),
		"version 5 is loaded as it stands; GameState.from_dict supplies the default")


func test_migrating_a_version_4_save_states_the_casino_key() -> void:
	var migrated := SaveIOScript.migrate({"bits": 10}, 4)
	assert_true(migrated.has("casino"), "migrate's output states the whole version 5 shape")
	assert_eq(migrated["casino"], {})
