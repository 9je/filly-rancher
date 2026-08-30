extends GutTest
## Tests for the individual pony record (game/systems/pony_instance.gd) -- the keystone of
## Phase 1B.
##
## WHAT BUG THIS FILE EXISTS TO STOP COMING BACK. Until now, capturing a pony put her
## PonyData -- the shared, static, one-per-CHARACTER resource -- into the saddlebag. Catch
## two Twilights and the bag held `[twilight, twilight]`: two pointers to the SAME record.
## There was no per-individual anything, so happiness, hunger and a production timer had
## nowhere to live, and "feed the one on the left" was not expressible. Every test below
## is about that distinction: an INSTANCE is one pony you actually own; a PonyData is the
## species entry she was built from, shared by every copy of her.
##
## WHY THE UID SCHEME IS TESTED AND NOT JUST THE UNIQUENESS. Two footguns this project has
## already been bitten by are deliberately designed out of pony_instance.gd, and a test
## that only checked "the two uids differ" would not notice either coming back:
##
##   * NOT FROM THE CLOCK. A uid seeded from Time.get_ticks_msec() is different on every
##     run, so a seeded/reproducible world stops being reproducible and no gate can pin an
##     expected uid. uid_for() below is a pure function of (id, serial) with a literal
##     expected value, so a clock creeping back into it fails immediately.
##   * NOT BY SORTING StringNames. Godot compares StringName with `<` by INTERNED POINTER,
##     not by text -- stable within one process, different between processes. That exact
##     bug shipped once already (game/world/spawner.gd and game/scenes/test/wild_ponies.gd
##     both carry the scar tissue), so the serial is an integer counter and any ordering
##     question is answered on String(uid), never on the StringName.
##
## Preloads by path rather than by the global class_name, matching the convention
## documented at the top of game/scripts/pony_rig.gd.

const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")

## A character that really is on the roster (game/data/ponies/twilight.tres), so the
## resolve tests are about the lookup rather than about a fixture.
const KNOWN_ID := &"twilight"
## ...and one that deliberately is not.
const UNKNOWN_ID := &"not_a_pony_at_all"


func after_each() -> void:
	# The shared registry is a process-wide static (see pony_instance.gd), so a test that
	# swapped it must not leak that into the next one.
	PonyInstanceScript.set_registry(null)


# --- identity ----------------------------------------------------------------------

func test_two_instances_of_one_character_have_different_uids() -> void:
	# THE bug this whole task exists to fix, stated as a test.
	var a = PonyInstanceScript.create(KNOWN_ID)
	var b = PonyInstanceScript.create(KNOWN_ID)
	assert_ne(a, b, "two catches must be two objects, not one shared record")
	assert_eq(a.data_id, b.data_id, "...of the same character")
	assert_ne(String(a.uid), String(b.uid),
		"...with different uids -- compared as String, never as StringName")
	assert_false(String(a.uid).is_empty(), "a uid must not be empty")


func test_two_instances_of_one_character_have_independent_state() -> void:
	var a = PonyInstanceScript.create(KNOWN_ID)
	var b = PonyInstanceScript.create(KNOWN_ID)
	a.happiness = 0.9
	a.hunger = 0.1
	a.nickname = "Sparkle"
	assert_almost_eq(b.happiness, PonyInstanceScript.HAPPINESS_DEFAULT, 0.0001,
		"feeding one pony must not feed the other")
	assert_almost_eq(b.hunger, PonyInstanceScript.HUNGER_DEFAULT, 0.0001)
	assert_eq(b.nickname, "", "naming one pony must not name the other")


func test_the_uid_is_a_pure_function_of_the_character_and_a_serial() -> void:
	# Pinned to a LITERAL, so a uid that started coming from Time (or from a hash of one)
	# fails here rather than quietly making every seeded world irreproducible.
	assert_eq(String(PonyInstanceScript.uid_for(KNOWN_ID, 7)), "twilight#000007",
		"a uid is the character id plus a zero-padded serial, and nothing else")
	assert_eq(String(PonyInstanceScript.uid_for(&"fluttershy", 1)), "fluttershy#000001")
	assert_eq(PonyInstanceScript.uid_for(KNOWN_ID, 7), PonyInstanceScript.uid_for(KNOWN_ID, 7),
		"the same inputs must give the same uid every time, in every process")


func test_minting_advances_the_serial_by_exactly_one() -> void:
	var a = PonyInstanceScript.create(KNOWN_ID)
	var b = PonyInstanceScript.create(&"fluttershy")
	assert_eq(PonyInstanceScript.serial_of(b.uid), PonyInstanceScript.serial_of(a.uid) + 1,
		"the counter is monotonic across the whole roster, not per character")


func test_a_uid_survives_a_round_trip_and_cannot_be_minted_again() -> void:
	# The save/load hazard (Task 2 depends on this): reloading a saved pony must keep her
	# uid, AND must push the counter past it, or the next capture mints a colliding uid
	# and two different ponies answer to one name.
	var restored = PonyInstanceScript.from_dict({
		"uid": "twilight#009999", "data_id": "twilight",
	})
	assert_eq(String(restored.uid), "twilight#009999", "a restored uid is kept verbatim")
	var minted = PonyInstanceScript.create(KNOWN_ID)
	assert_gt(PonyInstanceScript.serial_of(minted.uid), 9999,
		"a mint after a restore must not collide with the restored serial")


# --- serialisation -----------------------------------------------------------------

func test_to_dict_and_from_dict_round_trip_every_field() -> void:
	var original = PonyInstanceScript.create(KNOWN_ID)
	original.nickname = "Sparkle"
	original.happiness = 0.625
	original.hunger = 0.375
	original.caught_at_ms = 1772150400000

	var copy = PonyInstanceScript.from_dict(original.to_dict())
	assert_not_null(copy, "a dict this class produced must load back")
	assert_eq(copy.uid, original.uid, "uid survives")
	assert_eq(copy.data_id, original.data_id, "data_id survives")
	assert_eq(copy.nickname, original.nickname, "nickname survives")
	assert_almost_eq(copy.happiness, original.happiness, 0.0001, "happiness survives")
	assert_almost_eq(copy.hunger, original.hunger, 0.0001, "hunger survives")
	assert_eq(copy.caught_at_ms, original.caught_at_ms, "caught_at_ms survives")
	assert_ne(copy, original, "from_dict builds a new instance, it does not alias the old")


func test_to_dict_is_json_safe_so_a_save_file_stays_human_readable() -> void:
	# The spec wants two players able to trade a pony by sending each other a blob, and
	# Task 2 writes JSON. JSON has no StringName, so these must come out as String.
	var dict: Dictionary = PonyInstanceScript.create(KNOWN_ID).to_dict()
	assert_typeof(dict["uid"], TYPE_STRING, "uid must serialise as a String, not a StringName")
	assert_typeof(dict["data_id"], TYPE_STRING, "...and so must data_id")
	var reloaded: Variant = JSON.parse_string(JSON.stringify(dict))
	assert_typeof(reloaded, TYPE_DICTIONARY, "the dict must survive a real JSON round trip")
	var copy = PonyInstanceScript.from_dict(reloaded)
	assert_eq(String(copy.uid), String(dict["uid"]), "...and load back from the parsed JSON")


func test_from_dict_restores_stringname_typed_fields_as_stringnames() -> void:
	var copy = PonyInstanceScript.from_dict({"uid": "twilight#000042", "data_id": "twilight"})
	assert_typeof(copy.uid, TYPE_STRING_NAME, "uid is a StringName in memory")
	assert_typeof(copy.data_id, TYPE_STRING_NAME, "...and so is data_id")


func test_from_dict_fills_in_missing_fields_rather_than_crashing() -> void:
	# An older save, or a hand-edited traded blob, will be missing fields. It must load as
	# a usable pony with defaults, not take the game down.
	var copy = PonyInstanceScript.from_dict({"data_id": "twilight"})
	assert_not_null(copy, "a partial dict still loads")
	assert_eq(copy.data_id, KNOWN_ID)
	assert_false(String(copy.uid).is_empty(), "a missing uid is minted rather than left blank")
	assert_almost_eq(copy.happiness, PonyInstanceScript.HAPPINESS_DEFAULT, 0.0001)


func test_from_dict_clamps_state_that_is_out_of_range() -> void:
	var copy = PonyInstanceScript.from_dict({
		"data_id": "twilight", "happiness": 40.0, "hunger": -3.0,
	})
	assert_almost_eq(copy.happiness, PonyInstanceScript.STATE_MAX, 0.0001,
		"a corrupt save must not produce a pony who is 4000% happy")
	assert_almost_eq(copy.hunger, PonyInstanceScript.STATE_MIN, 0.0001,
		"...nor one with negative hunger")


func test_from_dict_refuses_something_that_is_not_a_pony() -> void:
	assert_null(PonyInstanceScript.from_dict({}),
		"a dict with no data_id is not a pony record")
	assert_null(PonyInstanceScript.from_dict({"data_id": ""}),
		"...and neither is one with an empty one")


# --- resolving back to the character -------------------------------------------------

func test_a_known_data_id_resolves_to_its_ponydata() -> void:
	var inst = PonyInstanceScript.create(KNOWN_ID)
	var data: PonyData = inst.data()
	assert_not_null(data, "a roster character must resolve")
	assert_eq(data.id, KNOWN_ID, "...to her own record")
	assert_eq(data.rarity, PonyDataScript.Rarity.RARE,
		"...the real one from data/ponies, not a blank stand-in")


func test_an_unknown_data_id_resolves_to_null_without_crashing() -> void:
	# Reachable for real: a save file from a build that had a pony this build does not,
	# or a traded blob naming a character the receiver has not got. It must be a null the
	# caller can check, never a crash and never a silently substituted stranger.
	var inst = PonyInstanceScript.create(UNKNOWN_ID)
	assert_null(inst.data(), "an unknown character resolves to null")
	assert_eq(inst.data_id, UNKNOWN_ID, "...and the instance keeps the id it was given")
	assert_null(PonyInstanceScript.resolve_data(UNKNOWN_ID))


func test_the_registry_can_be_injected_so_a_caller_is_not_forced_to_hit_the_disk() -> void:
	var registry = PonyRegistryScript.new()
	registry.load_all("res://data/ponies")
	PonyInstanceScript.set_registry(registry)
	assert_eq(PonyInstanceScript.get_registry(), registry,
		"an injected registry is the one that gets used")
	assert_eq(PonyInstanceScript.resolve_data(KNOWN_ID).id, KNOWN_ID)


func test_the_display_name_falls_back_all_the_way_down() -> void:
	# The HUD's toast and the future Ponypedia both need SOMETHING to call her, including
	# for a pony whose character record is missing on this machine.
	var named = PonyInstanceScript.create(KNOWN_ID)
	named.nickname = "Sparkle"
	assert_eq(named.display_name(), "Sparkle", "a nickname wins")

	var unnamed = PonyInstanceScript.create(KNOWN_ID)
	assert_eq(unnamed.display_name(), "Twilight Sparkle",
		"...otherwise the character's own display name")

	var orphan = PonyInstanceScript.create(UNKNOWN_ID)
	assert_eq(orphan.display_name(), String(UNKNOWN_ID),
		"...and with no record at all, the raw id rather than an empty label")


# --- stock ---------------------------------------------------------------------------

func test_a_new_instance_is_not_stock() -> void:
	var inst := PonyInstanceScript.create(&"twilight")
	assert_eq(inst.stock, {})
	assert_false(inst.is_stock())


func test_a_palette_triple_round_trips_through_the_dictionary() -> void:
	var inst := PonyInstanceScript.create(&"stock_shy")
	inst.stock = {"coat": 3, "mane": 6, "eyes": 2}
	var back := PonyInstanceScript.from_dict(inst.to_dict())
	assert_eq(back.stock, {"coat": 3, "mane": 6, "eyes": 2})
	assert_true(back.is_stock())


func test_a_record_written_before_phase_three_loads_as_a_named_pony() -> void:
	var old := {"uid": "twilight#000004", "data_id": "twilight", "nickname": "",
		"happiness": 0.5, "hunger": 0.0, "caught_at_ms": 0, "home_slot": ""}
	var inst := PonyInstanceScript.from_dict(old)
	assert_eq(inst.stock, {}, "a missing stock key is a named pony, not a broken one")
	assert_false(inst.is_stock())


func test_a_junk_stock_value_is_dropped_rather_than_stored() -> void:
	var inst := PonyInstanceScript.from_dict({"data_id": "stock_bold", "stock": "purple"})
	assert_eq(inst.stock, {}, "a hand edited blob must not fabricate a look")


func test_stock_indices_are_coerced_to_ints() -> void:
	# JSON has no integer type: every number comes back off disk as a float.
	var inst := PonyInstanceScript.from_dict({"data_id": "stock_bold",
		"stock": {"coat": 2.0, "mane": 4.0, "eyes": 1.0}})
	assert_eq(inst.stock, {"coat": 2, "mane": 4, "eyes": 1})
	assert_eq(typeof(inst.stock["coat"]), TYPE_INT)
