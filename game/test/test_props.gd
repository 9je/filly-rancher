extends GutTest
## The prop layout and the seating rules as DATA and as PURE FUNCTIONS: family scales,
## the footprint sampler, the skirt rule, and the clearance invariants the whole shipped
## LAYOUT has to satisfy.
##
## The live half of this lives in game/world/ranch.gd, which builds the map and measures
## it. These are the parts that need no scene, so a family scale that stopped applying or
## a prop planted inside a region fence fails in half a second with a sentence.
##
## Preloads by path rather than by class_name, per the convention at the top of
## game/scripts/pony_rig.gd (the global class cache lives in the gitignored game/.godot/
## and a fresh clone has not built it yet).

const PropsScript := preload("res://world/props.gd")
const RegionFenceScript := preload("res://world/region_fence.gd")

const REGION_DIR := "res://data/regions/"

## Metres a prop must stand past a region's fence ring, from props.gd's own comment: the
## ring is at radius + RegionFence.RING_MARGIN, and every planted tree clears it by 4 m.
const REGION_PROP_MARGIN := 4.0


# --- families and scales ----------------------------------------------------------------

func test_an_entry_with_no_family_is_a_kenney_kit_piece() -> void:
	var entry := {"file": "kenney_market_stall.glb", "at": Vector2.ZERO, "yaw": 0.0}
	assert_eq(PropsScript.family_of(entry), PropsScript.FAMILY_KENNEY)
	assert_almost_eq(PropsScript.scale_for(entry), PropsScript.BASE_SCALE, 0.0001)


func test_a_kenney_tree_falls_into_the_tree_family_without_being_told() -> void:
	# 50 of the 54 shipped entries are trees and none of them names a family. The prefix
	# rule is what keeps this task from being a 50 line diff to the layout.
	var entry := {"file": "kenney_tree_oak.glb", "at": Vector2.ZERO, "yaw": 0.0}
	assert_eq(PropsScript.family_of(entry), PropsScript.FAMILY_TREE)
	assert_almost_eq(PropsScript.scale_for(entry),
		PropsScript.BASE_SCALE * PropsScript.TREE_SCALE, 0.0001)


func test_an_explicit_family_beats_the_filename_rule() -> void:
	var entry := {"file": "kenney_tree_oak.glb", "at": Vector2.ZERO, "yaw": 0.0,
		"family": PropsScript.FAMILY_KENNEY}
	assert_eq(PropsScript.family_of(entry), PropsScript.FAMILY_KENNEY)


func test_the_mlp_family_is_scaled_by_its_own_number_and_not_by_the_kenney_base() -> void:
	var entry := {"file": "saa_barn.glb", "at": Vector2.ZERO, "yaw": 0.0,
		"family": PropsScript.FAMILY_MLP}
	assert_almost_eq(PropsScript.scale_for(entry), PropsScript.MLP_SCALE, 0.0001,
		"an MLP prop must not be multiplied by BASE_SCALE as well")


func test_the_per_entry_jitter_and_the_scale_fix_still_multiply_on_top() -> void:
	var jittered := {"file": "kenney_tree_oak.glb", "at": Vector2.ZERO, "yaw": 0.0, "s": 1.2}
	assert_almost_eq(PropsScript.scale_for(jittered),
		PropsScript.BASE_SCALE * PropsScript.TREE_SCALE * 1.2, 0.0001)
	var fixed := {"file": "kenney_survival_structure.glb", "at": Vector2.ZERO, "yaw": 0.0}
	assert_almost_eq(PropsScript.scale_for(fixed), PropsScript.BASE_SCALE * 4.0, 0.0001,
		"the FBX unit-conversion correction still applies, family or no family")


func test_every_family_the_layout_names_has_a_scale() -> void:
	for entry: Dictionary in PropsScript.LAYOUT:
		var family: StringName = PropsScript.family_of(entry)
		assert_true(PropsScript.FAMILY_SCALE.has(family),
			"'%s' names family '%s', which has no scale" % [entry["file"], family])


# --- the footprint sampler --------------------------------------------------------------

func test_the_footprint_sampler_reports_the_lowest_and_highest_of_nine_points() -> void:
	# A ramp running with x: the lowest sample is the west edge, the highest the east one,
	# and the centre column is what a single origin sample would have seen instead.
	var ramp := func(x: float, _z: float) -> float: return x * 0.1
	var relief: Vector2 = PropsScript.footprint_relief(
		Vector2(10.0, 4.0), Vector2(5.0, 3.0), ramp)
	assert_almost_eq(relief.x, 0.5, 0.0001, "lowest is the west edge at x = 5")
	assert_almost_eq(relief.y, 1.5, 0.0001, "highest is the east edge at x = 15")


func test_a_flat_footprint_has_no_relief_across_it() -> void:
	var flat := func(_x: float, _z: float) -> float: return 2.5
	var relief: Vector2 = PropsScript.footprint_relief(
		Vector2.ZERO, Vector2(6.0, 5.0), flat)
	assert_almost_eq(relief.x, 2.5, 0.0001)
	assert_almost_eq(relief.y, 2.5, 0.0001)


# --- the skirt rule ---------------------------------------------------------------------

func test_a_wide_prop_off_the_flat_apron_needs_a_skirt() -> void:
	var wide := AABB(Vector3.ZERO, Vector3(13.0, 7.0, 10.0))
	assert_true(PropsScript.needs_skirt(wide, false))


func test_the_same_prop_inside_the_flat_apron_does_not() -> void:
	# Terrain.is_flat_at() is true within FLAT_RADIUS of the homestead centre, where the
	# ground is exactly y = 0 by construction, so there is no relief for a skirt to bridge.
	var wide := AABB(Vector3.ZERO, Vector3(13.0, 7.0, 10.0))
	assert_false(PropsScript.needs_skirt(wide, true))


func test_a_narrow_prop_never_needs_one() -> void:
	var narrow := AABB(Vector3.ZERO, Vector3(1.2, 2.0, 1.2))
	assert_false(PropsScript.needs_skirt(narrow, false))


func test_the_wide_threshold_takes_the_longer_of_the_two_sides() -> void:
	var slab := AABB(Vector3.ZERO, Vector3(1.0, 2.0, 9.0))
	assert_true(PropsScript.needs_skirt(slab, false),
		"a nine metre fence line is as wide a footprint as a nine metre barn")


func test_the_skirt_constants_are_the_ones_the_relief_survey_argued_for() -> void:
	# 0.06 is Building.PLINTH_INSET's number and is here for the same reason: a skirt whose
	# outer face is coplanar with the model's own side is two surfaces fighting for one
	# pixel. 0.90 clears the 0.643 m of relief measured under the barn's own site and the
	# 0.366 m floor found anywhere on the map outside the flat apron.
	assert_almost_eq(PropsScript.SKIRT_INSET, 0.06, 0.0001)
	assert_almost_eq(PropsScript.SKIRT_MIN_DEPTH, 0.90, 0.0001)
	assert_almost_eq(PropsScript.WIDE_FOOTPRINT, 4.0, 0.0001)


# --- foliage --------------------------------------------------------------------------

func test_both_tree_families_read_as_foliage() -> void:
	# ranch.gd frames its camera shots off "the tallest building", which is every prop that
	# is not a tree. A canopy is a bad thing to prove a camera against, and the apple trees
	# are as much a canopy as the Kenney ones.
	assert_true(PropsScript.is_foliage("kenney_tree_oak_12"))
	assert_true(PropsScript.is_foliage("mlp_apple_tree_31"))
	assert_true(PropsScript.is_foliage("mlp_apple_tree_bare_33"))
	assert_false(PropsScript.is_foliage("saa_barn_54"))
	assert_false(PropsScript.is_foliage("kenney_windmill_0"))


# --- the shipped layout, as data --------------------------------------------------------

func test_every_layout_entry_carries_the_keys_build_reads() -> void:
	for entry: Dictionary in PropsScript.LAYOUT:
		assert_true(entry.has("file"), "an entry with no file cannot be loaded")
		assert_true(entry.has("at"), "%s has no position" % entry["file"])
		assert_true(entry.has("yaw"), "%s has no yaw" % entry["file"])
		assert_true(entry["at"] is Vector2, "%s's position is not a Vector2" % entry["file"])


func test_nothing_in_the_layout_stands_in_the_pen_plot_clearing() -> void:
	for entry: Dictionary in PropsScript.LAYOUT:
		var at: Vector2 = entry["at"]
		assert_false(PropsScript.is_in_pen_plots(at.x, at.y),
			"%s at %s is inside the reserved pen plot clearing" % [entry["file"], at])


func test_every_prop_stands_clear_of_every_priced_region_fence_ring() -> void:
	# props.gd's own rule: at least 4 m past the ring, which RegionFence puts at
	# radius + RING_MARGIN. A trunk ON the ring is a tree growing through a fence rail, and
	# a prop INSIDE it is something a resident can spawn on top of.
	for region: RegionData in _priced_regions():
		var ring: float = region.radius + RegionFenceScript.RING_MARGIN + REGION_PROP_MARGIN
		for entry: Dictionary in PropsScript.LAYOUT:
			var at: Vector2 = entry["at"]
			assert_gt(at.distance_to(region.centre), ring,
				"%s at %s stands inside region '%s'" % [entry["file"], at, region.id])


func _priced_regions() -> Array[RegionData]:
	var result: Array[RegionData] = []
	var dir := DirAccess.open(REGION_DIR)
	assert_not_null(dir, "no %s on this machine" % REGION_DIR)
	if dir == null:
		return result
	for file: String in dir.get_files():
		if file.get_extension() != "tres":
			continue
		var region: RegionData = load(REGION_DIR + file)
		if region != null and region.permit_cost > 0:
			result.append(region)
	return result
