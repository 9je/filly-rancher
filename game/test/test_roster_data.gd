extends GutTest
## The roster's SHAPE, pinned. Phase 2 slice 2 took it from 6 to 43 characters, and
## every one of them is a .tres under game/data/ponies/; these tests are what stop a
## typo in one of forty-three files from being a character who never spawns, sells for the
## wrong price, or shows a dash on screen.

const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const FoodRegistryScript := preload("res://systems/food_registry.gd")

const MIN_ROSTER := 43
const EXPECTED_TIERS := {
	PonyDataScript.Rarity.COMMON: 17,
	PonyDataScript.Rarity.UNCOMMON: 15,
	PonyDataScript.Rarity.RARE: 8,
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


func test_every_character_is_zoned_ranch_for_now() -> void:
	# Slice 3 splits the map into regions; until then every character must be reachable.
	for id in _roster():
		assert_true(_roster()[id].spawn_zones.has(&"ranch"), "%s must spawn on the ranch" % id)


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
