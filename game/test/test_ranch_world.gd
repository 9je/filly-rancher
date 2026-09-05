extends GutTest
## Unit tests for the ranch map's pure logic: the collision-layer scheme
## (game/world/collision_layers.gd), the terrain heightfield, the prop layout as
## DATA, the zone markers' boundary arithmetic, and the buildings' door sizing.
##
## The ranch's real gate is game/world/ranch.gd, which runs the scene and measures a
## live world. These tests cover the parts that do not need one -- so a broken layer
## scheme or a doorway a pony cannot fit through fails in half a second, and fails
## with a sentence rather than with a screenshot.
##
## Preloads by path rather than by class_name, per the convention at the top of
## game/scripts/pony_rig.gd (the global class cache lives in the gitignored
## game/.godot/ and a fresh clone has not built it yet).

const LayersScript := preload("res://world/collision_layers.gd")
const TerrainScript := preload("res://world/terrain.gd")
const PropsScript := preload("res://world/props.gd")
const ZoneMarkerScript := preload("res://world/zone_marker.gd")
const BuildingScript := preload("res://world/building.gd")
const CameraRigScript := preload("res://actors/player/camera_rig.gd")

## The pony's full height, horn tip included (docs/pipeline.md section 3). NOT her
## 1.163 m withers height -- the whole point of the doorway test below.
const PONY_FULL_HEIGHT := 2.138


# --- collision layers -----------------------------------------------------------

func test_every_layer_is_a_distinct_single_bit() -> void:
	var layers := {
		"TERRAIN": LayersScript.TERRAIN,
		"PROPS": LayersScript.PROPS,
		"PLAYER": LayersScript.PLAYER,
		"PONY": LayersScript.PONY,
		"INTERACTION": LayersScript.INTERACTION,
	}
	var seen := {}
	for label in layers:
		var bits: int = layers[label]
		assert_true(bits > 0, "%s must be a positive bitmask" % label)
		assert_eq(bits & (bits - 1), 0, "%s must be exactly one bit, got %d" % [label, bits])
		assert_false(seen.has(bits), "%s collides with another layer (%d)" % [label, bits])
		seen[bits] = label


func test_terrain_stays_on_bit_one() -> void:
	# Load-bearing: every pre-existing test scene builds its ground on Godot's
	# untouched default layer 1 and is not being rewritten. Moving TERRAIN off bit 1
	# silently stops the player and the camera working in playground/camera_test/
	# walk_test, none of which would report a layer problem.
	assert_eq(LayersScript.TERRAIN, 1, "TERRAIN must stay on bit 1 -- see collision_layers.gd")


func test_world_is_terrain_and_props_and_nothing_else() -> void:
	assert_eq(LayersScript.WORLD, LayersScript.TERRAIN | LayersScript.PROPS)
	assert_eq(LayersScript.WORLD & LayersScript.PLAYER, 0,
		"the camera probe mask must not include the player")
	assert_eq(LayersScript.WORLD & LayersScript.PONY, 0,
		"the camera probe mask must not include ponies -- a pony crossing behind the "
		+ "player must not yank the camera in")


func test_a_walking_character_collides_with_the_world_and_with_other_characters() -> void:
	for bit in [LayersScript.TERRAIN, LayersScript.PROPS, LayersScript.PLAYER, LayersScript.PONY]:
		assert_ne(LayersScript.WALKABLE & bit, 0, "WALKABLE is missing bit %d" % bit)


func test_the_camera_rig_probes_the_world_by_default() -> void:
	# The latent bug this map-build task was told to fix: before it, this mask was
	# Godot's untouched default 1, which only worked because every collision object
	# in the project was also on the untouched default layer 1.
	var rig = CameraRigScript.new()
	assert_eq(rig.probe_mask, LayersScript.WORLD,
		"CameraRig.probe_mask must default to WORLD or the camera clips through buildings")
	rig.free()


# --- terrain --------------------------------------------------------------------

func _terrain():
	return TerrainScript.new()


func test_height_is_deterministic() -> void:
	var t = _terrain()
	for p in [Vector2(0.0, 0.0), Vector2(37.5, -12.25), Vector2(-60.0, 60.0)]:
		assert_eq(t.height_at(p.x, p.y), t.height_at(p.x, p.y),
			"height_at must be a pure function -- the map has to be the same map twice")
	t.free()


func test_the_homestead_apron_is_exactly_flat() -> void:
	var t = _terrain()
	var c: Vector2 = TerrainScript.HOMESTEAD_CENTRE
	for offset in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(0.0, -20.0), Vector2(18.0, 18.0)]:
		if offset.length() > TerrainScript.FLAT_RADIUS:
			continue
		assert_almost_eq(t.height_at(c.x + offset.x, c.y + offset.y), 0.0, 0.0001,
			"the ground under the homestead must be dead flat or the buildings tilt")
	t.free()


func test_the_open_country_actually_has_relief() -> void:
	# If this ever goes flat, game/world/spawner.gd's raycast placement becomes
	# indistinguishable from `y = 0` and the ranch gate's ground checks go hollow.
	var t = _terrain()
	var peak := 0.0
	for i in range(0, 60):
		var a := TAU * float(i) / 60.0
		var p := Vector2(cos(a), sin(a)) * (TerrainScript.BLEND_RADIUS + 8.0)
		peak = maxf(peak, absf(t.height_at(p.x, p.y)))
	assert_gt(peak, 0.5, "the ground past the apron must roll, not lie flat")
	t.free()


func test_no_slope_is_too_steep_to_walk_up() -> void:
	# CharacterBody3D's default floor_max_angle is 45 degrees; anything steeper is a
	# wall the player would slide down rather than ground she can climb.
	var t = _terrain()
	var steepest := 0.0
	var step := 2.0
	var x := -TerrainScript.HALF
	while x < TerrainScript.HALF:
		var z := -TerrainScript.HALF
		while z < TerrainScript.HALF:
			var here: float = t.height_at(x, z)
			steepest = maxf(steepest, absf(t.height_at(x + step, z) - here) / step)
			steepest = maxf(steepest, absf(t.height_at(x, z + step) - here) / step)
			z += 6.0
		x += 6.0
	assert_lt(rad_to_deg(atan(steepest)), 40.0,
		"terrain slope exceeds what the player can walk up")
	t.free()


# --- the prop layout, as data ----------------------------------------------------

func test_the_pen_plot_clearing_is_clear_in_the_layout() -> void:
	for entry: Dictionary in PropsScript.LAYOUT:
		var at: Vector2 = entry["at"]
		assert_false(PropsScript.is_in_pen_plots(at.x, at.y),
			"'%s' at %s sits in the ground reserved for the pen plots" % [entry["file"], at])


## THE TWO KITS THE MAP IS DRESSED FROM. Kenney for the yard fixtures and the treeline;
## the converted PonySFM props for Sweet Apple Acres, Ponyville General, the town row, the
## schoolyard and the Strip. Every prefix here is an id prefix in tools/prop_manifest.txt,
## which is the only thing tools/convert_props.sh will produce. A file with any other
## prefix is one nothing converts, so it would never load on any machine: it would quietly
## lower expected_count() instead of failing, and the layout would be one prop short
## everywhere with nothing saying so.
const PROP_PREFIXES := ["kenney_", "saa_", "pv_", "mlp_", "school_", "lp_", "neon_"]


func test_every_layout_entry_names_a_prop_from_the_converted_kit() -> void:
	for entry: Dictionary in PropsScript.LAYOUT:
		var file: String = entry["file"]
		var known := false
		for prefix: String in PROP_PREFIXES:
			if file.begins_with(prefix):
				known = true
				break
		assert_true(known, "unexpected prop source: %s" % file)
		assert_eq(file.get_extension(), "glb", "props are loaded as .glb: %s" % file)


func test_the_undersized_fbx_prop_still_carries_its_scale_correction() -> void:
	# docs/pipeline.md section 4, quirk 4: this one prop came through the FBX branch
	# and is 4x smaller than its own pack's GLB sibling. Dropping the correction makes
	# it a 0.75 m shed nobody would notice was wrong.
	assert_eq(PropsScript.SCALE_FIX.get("kenney_survival_structure.glb", 1.0), 4.0,
		"the FBX unit-conversion correction has gone missing")


func test_the_prop_scale_factor_is_the_one_the_pipeline_validated() -> void:
	assert_almost_eq(PropsScript.BASE_SCALE, 1.5, 0.0001,
		"docs/pipeline.md section 4 derives 1.5x -- changing it needs a doc change too")


func test_the_mlp_family_has_its_own_base_scale_and_it_is_not_the_kenney_one() -> void:
	# The whole point of the family key: a Source model is not a Kenney kit piece and must
	# not be multiplied by a number derived from a Kenney door module. If these two ever
	# come out equal it is a coincidence worth looking at, not a pass.
	assert_gt(PropsScript.MLP_SCALE, 0.0, "MLP_SCALE must be a positive multiplier")
	assert_lt(PropsScript.MLP_SCALE, 100.0,
		"MLP_SCALE above 100 means the measurement was read off the wrong model")


func test_the_sweet_apple_acres_barn_has_a_target_ridge_to_be_scaled_against() -> void:
	# 7.0 m: about two metres over the homestead barn's own 4.9 m ridge (authored in
	# game/world/ranch.tscn), and under Terrain.BOUNDARY_HEIGHT. ranch.gd measures the
	# seated barn against this same constant, so a scale that stopped producing it fails
	# a gate rather than only looking wrong.
	assert_almost_eq(PropsScript.MLP_TARGET_BARN_RIDGE, 7.0, 0.0001,
		"the target ridge is quoted in props.gd's MLP_SCALE derivation and in ranch.gd")


# --- zone markers ----------------------------------------------------------------

func test_a_zones_outer_bound_allows_for_the_flee_overshoot() -> void:
	# roam_radius is where a pony TURNS AROUND, not where she stops: at a full gallop
	# her momentum carries her ~1.15 m past it. A boundary drawn at spawn + roam is a
	# boundary ponies clip through.
	var marker = ZoneMarkerScript.new()
	marker.spawn_radius = 11.0
	marker.roam_radius = 6.0
	assert_almost_eq(marker.outer_bound(), 11.0 + 6.0 + ZoneMarkerScript.ROAM_OVERSHOOT, 0.0001)
	assert_gt(marker.outer_bound(), marker.spawn_radius + marker.roam_radius,
		"outer_bound must exceed spawn+roam or the overshoot is unaccounted for")
	marker.free()


func test_a_zone_marker_is_zoned_for_a_pony_the_roster_actually_has() -> void:
	var marker = ZoneMarkerScript.new()
	var zone: StringName = marker.zone_id
	marker.free()

	var registry = preload("res://systems/pony_registry.gd").new()
	registry.load_all("res://data/ponies")
	assert_gt(registry.by_zone(zone).size(), 0,
		"the default zone_id '%s' matches no pony in game/data/ponies" % zone)


# --- buildings --------------------------------------------------------------------

func test_a_doorway_clears_the_horn_and_not_merely_the_withers() -> void:
	var b = BuildingScript.new()
	assert_gt(BuildingScript.MIN_DOOR_CLEARANCE, PONY_FULL_HEIGHT,
		"the door clearance floor must be above the pony's full 2.138 m height")
	assert_gte(b.door_height, BuildingScript.MIN_DOOR_CLEARANCE,
		"the default doorway is too low for a pony to walk through")
	# The classic way to get this wrong is to size the door off the withers figure,
	# which would land somewhere near 1.2-1.5 m and still "look pony sized".
	assert_gt(b.door_height, 1.163 * 1.5, "this door was sized off the withers, not the horn")
	b.free()


func test_a_building_is_taller_at_the_ridge_than_at_the_eaves() -> void:
	var b = BuildingScript.new()
	assert_gt(b.ridge_height, b.wall_height, "an inside-out roof")
	assert_gt(b.width, b.door_width, "the doorway is wider than the wall it is cut into")
	b.free()


func test_the_request_board_is_a_board_and_not_only_a_building() -> void:
	var ranch: Node3D = preload("res://world/ranch.tscn").instantiate()
	var board := ranch.get_node_or_null(^"Buildings/Board") as Building
	assert_not_null(board, "the request board building stands")
	assert_eq(board.door_width, 0.0, "a notice board has no doorway and stands no ramp")
	ranch.free()
