extends GutTest
## Tests for game/systems/compendium.gd: what the player knows of the 43-character roster.
## Pure logic, no scene, same discipline as test_gem_pouch.gd and test_inventory.gd.

const CompendiumScript := preload("res://systems/compendium.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")

const PONY_DIR := "res://data/ponies"

## Loaded once per test from the real roster on disk, so the counting tests below are
## measured against the actual game, not a hand-rolled fixture that could drift from it.
var registry: PonyRegistry


func before_each() -> void:
	registry = PonyRegistryScript.new()
	registry.load_all(PONY_DIR)


# --- state transitions ------------------------------------------------------------------

func test_a_character_nobody_has_heard_of_is_unseen() -> void:
	var c = CompendiumScript.new()
	assert_eq(c.state_of(&"twilight"), CompendiumScript.State.UNSEEN)


func test_mark_seen_raises_an_unseen_character_and_reports_the_change() -> void:
	var c = CompendiumScript.new()
	watch_signals(c)
	assert_true(c.mark_seen(&"twilight"), "unseen -> seen is a real change")
	assert_eq(c.state_of(&"twilight"), CompendiumScript.State.SEEN)
	assert_signal_emitted_with_parameters(c, "changed", [&"twilight", CompendiumScript.State.SEEN])


func test_mark_seen_a_second_time_changes_nothing() -> void:
	var c = CompendiumScript.new()
	c.mark_seen(&"twilight")
	watch_signals(c)
	assert_false(c.mark_seen(&"twilight"), "already seen; nothing moved")
	assert_signal_not_emitted(c, "changed")


func test_mark_caught_raises_an_unseen_character_directly() -> void:
	var c = CompendiumScript.new()
	assert_true(c.mark_caught(&"twilight"))
	assert_eq(c.state_of(&"twilight"), CompendiumScript.State.CAUGHT)


func test_mark_caught_raises_a_seen_character() -> void:
	var c = CompendiumScript.new()
	c.mark_seen(&"twilight")
	assert_true(c.mark_caught(&"twilight"), "seen -> caught is a real change")
	assert_eq(c.state_of(&"twilight"), CompendiumScript.State.CAUGHT)


func test_mark_seen_never_downgrades_a_caught_character() -> void:
	var c = CompendiumScript.new()
	c.mark_caught(&"twilight")
	watch_signals(c)
	assert_false(c.mark_seen(&"twilight"), "caught -> seen must be refused, not applied")
	assert_eq(c.state_of(&"twilight"), CompendiumScript.State.CAUGHT, "still caught")
	assert_signal_not_emitted(c, "changed")


func test_mark_caught_a_second_time_changes_nothing() -> void:
	var c = CompendiumScript.new()
	c.mark_caught(&"twilight")
	watch_signals(c)
	assert_false(c.mark_caught(&"twilight"))
	assert_signal_not_emitted(c, "changed")


func test_different_characters_are_tracked_independently() -> void:
	var c = CompendiumScript.new()
	c.mark_caught(&"twilight")
	assert_eq(c.state_of(&"twilight"), CompendiumScript.State.CAUGHT)
	assert_eq(c.state_of(&"rainbowdash"), CompendiumScript.State.UNSEEN, "untouched")


# --- counts, against the real registry ---------------------------------------------------

func test_total_is_the_whole_roster() -> void:
	var c = CompendiumScript.new()
	assert_eq(c.total(registry), 43, "the shipped roster")


func test_a_fresh_compendium_counts_the_whole_roster_as_unseen() -> void:
	var c = CompendiumScript.new()
	assert_eq(c.count(CompendiumScript.State.UNSEEN, registry), 43)
	assert_eq(c.count(CompendiumScript.State.SEEN, registry), 0)
	assert_eq(c.count(CompendiumScript.State.CAUGHT, registry), 0)


func test_counts_reflect_a_hand_marked_set() -> void:
	var c = CompendiumScript.new()
	c.mark_seen(&"twilight")
	c.mark_seen(&"rainbowdash")
	c.mark_caught(&"fluttershy")
	c.mark_caught(&"pinkiepie")
	c.mark_caught(&"applejack")

	assert_eq(c.count(CompendiumScript.State.CAUGHT, registry), 3)
	assert_eq(c.count(CompendiumScript.State.SEEN, registry), 2)
	assert_eq(c.count(CompendiumScript.State.UNSEEN, registry), 43 - 5)
	assert_eq(
		c.count(CompendiumScript.State.CAUGHT, registry)
			+ c.count(CompendiumScript.State.SEEN, registry)
			+ c.count(CompendiumScript.State.UNSEEN, registry),
		c.total(registry),
		"every character lands in exactly one bucket")


func test_count_in_zone_filters_to_that_zones_characters() -> void:
	# twilight and rainbowdash both spawn in "ranch" (13 ponies do); a lake pony is marked
	# too, and must not show up in the ranch tally.
	var c = CompendiumScript.new()
	c.mark_caught(&"twilight")
	c.mark_seen(&"rainbowdash")
	c.mark_caught(&"bonbon")  # a "lake" pony, per the authored roster

	assert_eq(c.count_in_zone(&"ranch", CompendiumScript.State.CAUGHT, registry), 1)
	assert_eq(c.count_in_zone(&"ranch", CompendiumScript.State.SEEN, registry), 1)
	assert_eq(c.count_in_zone(&"ranch", CompendiumScript.State.UNSEEN, registry), 13 - 2,
		"the rest of the ranch zone's ponies are untouched")
	assert_eq(c.count_in_zone(&"lake", CompendiumScript.State.CAUGHT, registry), 1,
		"the lake mark does not leak into the ranch tally")


func test_count_in_zone_of_an_unknown_zone_is_zero() -> void:
	var c = CompendiumScript.new()
	c.mark_caught(&"twilight")
	assert_eq(c.count_in_zone(&"nowhere", CompendiumScript.State.CAUGHT, registry), 0)


# --- serialisation ------------------------------------------------------------------------

func test_to_dict_has_string_keys_int_values_and_omits_unseen() -> void:
	var c = CompendiumScript.new()
	c.mark_seen(&"twilight")
	c.mark_caught(&"rainbowdash")
	var d := c.to_dict()
	assert_eq(d.size(), 2, "only the two marked characters are written")
	for key in d.keys():
		assert_typeof(key, TYPE_STRING, "JSON has no StringName or integer keys")
	assert_eq(d["twilight"], CompendiumScript.State.SEEN)
	assert_eq(d["rainbowdash"], CompendiumScript.State.CAUGHT)
	assert_false(d.has("fluttershy"), "an untouched character is not written at all")


func test_round_trips_through_a_json_safe_dictionary() -> void:
	var c = CompendiumScript.new()
	c.mark_seen(&"twilight")
	c.mark_caught(&"rainbowdash")
	var back = CompendiumScript.from_dict(c.to_dict())
	assert_eq(back.state_of(&"twilight"), CompendiumScript.State.SEEN)
	assert_eq(back.state_of(&"rainbowdash"), CompendiumScript.State.CAUGHT)
	assert_eq(back.state_of(&"fluttershy"), CompendiumScript.State.UNSEEN)
	assert_eq(back.total(registry), c.total(registry))


func test_from_dict_of_an_empty_dictionary_is_a_fresh_compendium() -> void:
	var c = CompendiumScript.from_dict({})
	assert_eq(c.count(CompendiumScript.State.UNSEEN, registry), 43)


func test_from_dict_drops_junk() -> void:
	var c = CompendiumScript.from_dict({
		"twilight": 99,       # out of range; not a real State
		"rainbowdash": "seen",  # not a number at all
		"fluttershy": 0,       # explicit UNSEEN; must not fabricate an entry
		"pinkiepie": 2,        # the only well-formed entry
	})
	assert_eq(c.state_of(&"twilight"), CompendiumScript.State.UNSEEN, "out-of-range dropped")
	assert_eq(c.state_of(&"rainbowdash"), CompendiumScript.State.UNSEEN, "non-numeric dropped")
	assert_eq(c.state_of(&"fluttershy"), CompendiumScript.State.UNSEEN, "explicit 0 dropped")
	assert_eq(c.state_of(&"pinkiepie"), CompendiumScript.State.CAUGHT, "...but the good one survives")
	assert_false(c.to_dict().has("fluttershy"),
		"a dropped explicit-zero entry must not round trip back out either")


## JSON HAS NO INTEGER TYPE: a state this class itself wrote as the int 2 comes back through
## a real SaveIO round trip as the float 2.0, so from_dict() must accept a WHOLE-number float
## exactly the way it accepts an int. What it must NOT do is silently truncate a fractional
## float into a state that was never actually written; 1.5 is not SEEN, and 2.7 is not
## CAUGHT, and treating either as one would be fabricating an entry from noise.
func test_from_dict_accepts_whole_number_floats_and_rejects_fractional_ones() -> void:
	var c = CompendiumScript.from_dict({
		"twilight": 2.0,        # CAUGHT, arrived as a JSON float
		"rarity": 1.0,          # SEEN, same story
		"rainbowdash": 1.5,     # fractional; must be rejected, not truncated to SEEN
		"fluttershy": 2.7,      # fractional; must be rejected, not truncated to CAUGHT
	})
	assert_eq(c.state_of(&"twilight"), CompendiumScript.State.CAUGHT,
		"a whole-number float is accepted exactly like the int it represents")
	assert_eq(c.state_of(&"rarity"), CompendiumScript.State.SEEN)
	assert_eq(c.state_of(&"rainbowdash"), CompendiumScript.State.UNSEEN,
		"a fractional value is rejected outright, not truncated into a state")
	assert_eq(c.state_of(&"fluttershy"), CompendiumScript.State.UNSEEN,
		"...same for a fractional value that would truncate into CAUGHT")
