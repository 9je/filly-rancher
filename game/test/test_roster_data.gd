extends GutTest
## The roster's SHAPE, pinned. Phase 2 slice 2 took it from 6 to 43 characters, and
## every one of them is a .tres under game/data/ponies/; these tests are what stop a
## typo in one of forty-three files from being a character who never spawns, sells for the
## wrong price, or shows a dash on screen.

const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const FoodRegistryScript := preload("res://systems/food_registry.gd")
const WorldStateScript := preload("res://systems/world_state.gd")

const MIN_ROSTER := 43
const EXPECTED_TIERS := {
	PonyDataScript.Rarity.COMMON: 17,
	PonyDataScript.Rarity.UNCOMMON: 13,
	PonyDataScript.Rarity.RARE: 10,  # P8: Fluttershy and Pinkie Pie joined the rest of the Mane Six
	PonyDataScript.Rarity.LEGENDARY: 3,
}


func _roster() -> Dictionary:
	var registry: PonyRegistry = PonyRegistryScript.new()
	return registry.load_all("res://data/ponies")


func test_the_roster_is_at_least_forty_three() -> void:
	assert_gte(_roster().size(), MIN_ROSTER)


func test_every_id_matches_its_file_name() -> void:
	for file_name in DirAccess.get_files_at("res://data/ponies"):
		if not file_name.ends_with(".tres"):
			continue
		var data: PonyData = load("res://data/ponies/" + file_name)
		assert_eq(String(data.id), file_name.get_basename(),
			"%s must carry id %s" % [file_name, file_name.get_basename()])


func test_every_model_path_points_at_its_own_glb() -> void:
	for id in _roster():
		var data: PonyData = _roster()[id]
		assert_eq(data.model_path, "res://assets/converted/ponies/%s.glb" % id)


func test_display_names_are_unique_and_carry_no_dashes() -> void:
	var seen := {}
	for id in _roster():
		var name: String = _roster()[id].display_name
		assert_false(name.is_empty(), "%s needs a display name" % id)
		assert_false(seen.has(name), "duplicate display name '%s'" % name)
		seen[name] = true
		# Written as escapes rather than as the characters themselves so the rule is
		# legible in a diff: a double hyphen, an em dash (U+2014) and an en dash
		# (U+2013). A display name is drawn in the HUD and spoken about in the docs, and
		# all three of these are banned in this project's prose for the same reason.
		for dash in ["--", "\u2014", "\u2013"]:
			assert_false(name.contains(dash), "'%s' must not contain a dash" % name)


func test_every_rarity_tier_has_members_in_the_expected_numbers() -> void:
	var counts := {}
	for id in _roster():
		var r: int = _roster()[id].rarity
		counts[r] = int(counts.get(r, 0)) + 1
	for tier in EXPECTED_TIERS:
		assert_eq(int(counts.get(tier, 0)), EXPECTED_TIERS[tier],
			"tier %s should have %d members" % [PonyDataScript.Rarity.keys()[tier], EXPECTED_TIERS[tier]])


## Tiers of four or more members must use every personality; smaller ones are exempt.
##
## THE THRESHOLD IS THREE FOR A REASON. LEGENDARY is exactly three characters (Sunset
## Shimmer, Trixie, Shining Armor) and all three are BOLD, because that is who they are;
## a tier whose size equals the personality count could only satisfy a coverage rule by
## having a personality assigned to fit the test rather than the character. The check
## keeps its teeth where it was aimed: COMMON, UNCOMMON and RARE are 17, 15 and 8
## members, and any of them collapsing onto one temperament is a real content bug.
func test_every_personality_is_used_in_every_tier_that_has_more_than_three_members() -> void:
	var by_tier := {}
	for id in _roster():
		var data: PonyData = _roster()[id]
		if not by_tier.has(data.rarity):
			by_tier[data.rarity] = {}
		by_tier[data.rarity][data.personality] = true
	for tier in by_tier:
		if int(EXPECTED_TIERS.get(tier, 0)) <= 3:
			continue
		assert_eq(by_tier[tier].size(), PonyDataScript.Personality.size(),
			"tier %s should use every personality" % PonyDataScript.Rarity.keys()[tier])


## THE ROSTER AND THE MAP HAVE TO NAME THE SAME PLACES, in both directions.
##
## Slice 3 moved 30 of the 43 characters off the ranch and into four regions, and a zone id
## is a StringName typed into a .tres by hand on one side and into ranch.tscn by hand on
## the other. A typo on the roster's side is a character nobody can ever meet: the spawner
## reports the zone as empty, and she is simply not in the game. A marker with no residents
## is the reverse, a place behind a permit with nothing in it. Neither is visible in any
## other test here, because each half is internally consistent on its own.
func test_every_zone_a_character_names_has_a_marker_and_every_marker_has_residents() -> void:
	var scene: PackedScene = load("res://world/ranch.tscn")
	var ranch: Node = scene.instantiate()
	var marker_zones := {}
	for marker in ranch.get_node("Zones").get_children():
		marker_zones[marker.zone_id] = true
	ranch.free()
	assert_gt(marker_zones.size(), 1, "the map has more than one kind of place on it")
	var used := {}
	for id in _roster():
		# An empty list would sail through the loop below without asserting anything, and
		# is the same bug as a typo: a character with nowhere to spawn.
		assert_false(_roster()[id].spawn_zones.is_empty(), "%s must live somewhere" % id)
		for zone in _roster()[id].spawn_zones:
			assert_true(marker_zones.has(zone), "%s spawns in '%s', which has no ZoneMarker"
				% [id, zone])
			used[zone] = true
	for zone in marker_zones:
		assert_true(used.has(zone), "zone '%s' has a marker but nobody lives there" % zone)


func test_every_character_likes_at_least_one_food_the_market_sells() -> void:
	var foods: FoodRegistry = FoodRegistryScript.new()
	foods.load_all("res://data/foods")
	for id in _roster():
		var liked := false
		for food_id in _roster()[id].favorite_foods:
			if foods.by_id(food_id) != null:
				liked = true
		assert_true(liked, "%s must like something the Market can sell, or care items are pointless for her" % id)


func test_stats_are_in_the_range_the_existing_six_established() -> void:
	for id in _roster():
		var data: PonyData = _roster()[id]
		assert_between(data.base_speed, 2.5, 7.0, "%s speed" % id)
		assert_between(data.base_stamina, 3.0, 8.0, "%s stamina" % id)
		assert_between(data.base_spirit, 3.0, 9.5, "%s spirit" % id)


# --- when they appear ----------------------------------------------------------------

func test_conditional_characters_use_valid_phase_and_weather_values() -> void:
	var phase_count := WorldStateScript.Phase.size()
	var weather_count := WorldStateScript.Weather.size()
	for id in _roster():
		var data: PonyData = _roster()[id]
		for phase in data.phases:
			assert_between(phase, 0, phase_count - 1,
				"%s lists phase %d, which is not a WorldState.Phase" % [id, phase])
		for weather in data.weathers:
			assert_between(weather, 0, weather_count - 1,
				"%s lists weather %d, which is not a WorldState.Weather" % [id, weather])
		assert_eq(data.phases.size(), _unique(data.phases).size(),
			"%s lists a phase twice" % id)
		assert_eq(data.weathers.size(), _unique(data.weathers).size(),
			"%s lists a weather twice" % id)


func test_the_roster_actually_uses_conditions() -> void:
	# The feature is data, so the only thing that can prove it shipped is the data. Without
	# this, deleting every phases/weathers line out of the roster would leave the whole
	# suite green and the world with no hours in it.
	var conditional := 0
	for id in _roster():
		var data: PonyData = _roster()[id]
		if not data.phases.is_empty() or not data.weathers.is_empty():
			conditional += 1
	assert_gte(conditional, 15,
		"about a third of the roster is supposed to keep hours of its own")


func test_every_region_has_at_least_two_residents_for_every_hour_and_weather() -> void:
	# THE INVARIANT BEHIND THE CONDITION TABLE. A ZoneMarker whose pool is empty spawns
	# nobody and a region with one resident spawns her three times over, so conditioning a
	# region into emptiness is a content bug that has to fail loudly here rather than be
	# noticed as a quiet patch of empty map at four in the morning in the fog.
	var scene: PackedScene = load("res://world/ranch.tscn")
	var ranch: Node = scene.instantiate()
	var zones := {}
	for marker in ranch.get_node("Zones").get_children():
		zones[marker.zone_id] = true
	ranch.free()

	var roster := _roster()
	for zone in zones:
		for phase in range(WorldStateScript.Phase.size()):
			for weather in range(WorldStateScript.Weather.size()):
				var n := 0
				for id in roster:
					var data: PonyData = roster[id]
					if zone in data.spawn_zones and data.available(phase, weather):
						n += 1
				assert_gte(n, 2, "'%s' has %d resident(s) at %s in %s" % [zone, n,
					WorldStateScript.phase_name(phase), WorldStateScript.weather_name(weather)])


func test_every_zone_can_fill_every_marker_it_owns_at_every_hour_and_weather() -> void:
	# THE INVARIANT BEHIND Spawner.refresh()'s "unfilled". Nobody stands in the field twice,
	# so a zone whose markers ask for more ponies than it has available at some hour leaves
	# slots empty at that hour. That is a legitimate reading of a quiet hour and the spawner
	# reports it rather than drawing a duplicate, but on the shipped map it is not supposed
	# to happen at all, and the only thing that can keep that true as the roster changes is
	# this. Note the sum: the five homestead markers share one zone and therefore share one
	# pool.
	var scene: PackedScene = load("res://world/ranch.tscn")
	var ranch: Node = scene.instantiate()
	var wanted := {}
	for marker in ranch.get_node("Zones").get_children():
		wanted[marker.zone_id] = int(wanted.get(marker.zone_id, 0)) + marker.spawn_count
	ranch.free()

	var roster := _roster()
	for zone in wanted:
		for phase in range(WorldStateScript.Phase.size()):
			for weather in range(WorldStateScript.Weather.size()):
				var n := 0
				for id in roster:
					var data: PonyData = roster[id]
					if zone in data.spawn_zones and data.available(phase, weather):
						n += 1
				assert_gte(n, int(wanted[zone]),
					"'%s' asks for %d ponies and has %d available at %s in %s"
					% [zone, wanted[zone], n, WorldStateScript.phase_name(phase),
					WorldStateScript.weather_name(weather)])


## The distinct members of `values`, so a repeated entry in a phases or weathers list is
## visible as a size mismatch. Godot has no Array.unique().
func _unique(values: Array) -> Array:
	var seen := {}
	for value in values:
		seen[value] = true
	return seen.keys()
