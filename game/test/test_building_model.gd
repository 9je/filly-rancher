extends GutTest
## THE SHELL WEARS A MODEL, OR IT DOES NOT AND STILL STANDS.
##
## game/assets/converted/ is gitignored, so CI and a fresh clone have no props at all. A
## building that only renders when its .glb is present would leave the CI runner with a map
## of invisible collision. Both halves are tested here: the modelled path on a machine that
## has run the pipeline, and the fallback path, which is what a missing model_file proves.

const BuildingScript := preload("res://world/building.gd")
const PropsScript := preload("res://world/props.gd")
const TerrainScript := preload("res://world/terrain.gd")

const SHELL_MESHES := ["WallBack", "WallLeft", "WallRight", "RoofLeft", "RoofRight", "Gables"]


func _bare() -> Building:
	var b: Building = BuildingScript.new()
	b.width = 6.0
	b.depth = 4.0
	b.wall_height = 4.6
	b.ridge_height = 5.8
	b.door_width = 2.0
	b.door_height = 3.85
	add_child_autofree(b)
	return b


func test_a_building_with_no_model_file_wears_nothing_and_renders_its_own_shell() -> void:
	var b := _bare()
	b.build()
	assert_false(b.wears_a_model(), "an unnamed model is not a worn one")
	assert_null(b.get_node_or_null(^"Model"), "nothing should have been instanced")
	for part: String in SHELL_MESHES:
		var node := b.get_node_or_null(NodePath(part)) as MeshInstance3D
		assert_not_null(node, "the primitive shell still builds %s" % part)
		assert_true(node.visible, "%s renders when no model stands" % part)


func test_a_model_file_that_is_not_on_this_machine_falls_back_to_the_shell() -> void:
	var b := _bare()
	b.model_file = "there_is_no_such_prop.glb"
	b.build()
	assert_false(b.wears_a_model(), "a named model that does not exist is not worn")
	var wall := b.get_node_or_null(^"WallBack") as MeshInstance3D
	assert_not_null(wall, "the fallback shell built")
	assert_true(wall.visible, "the fallback shell renders")


func test_a_worn_model_hides_the_walls_and_the_roof_and_keeps_the_plinth_and_the_apron() -> void:
	var b := _bare()
	b.model_file = "saa_shed.glb"
	b.build()
	if not b.wears_a_model():
		pass_test("no converted props on this machine; the fallback tests above cover it")
		return
	for part: String in SHELL_MESHES:
		var node := b.get_node_or_null(NodePath(part)) as MeshInstance3D
		assert_not_null(node, "%s is still built, for its collision" % part)
		assert_false(node.visible, "%s must not render behind a model" % part)
	var floor_node := b.get_node_or_null(^"Floor") as MeshInstance3D
	assert_not_null(floor_node, "the plinth is still built")
	assert_true(floor_node.visible, "the plinth still renders: it is what the model stands on")
	var apron := b.get_node_or_null(^"DoorApron") as MeshInstance3D
	assert_not_null(apron, "the apron is still built")
	assert_true(apron.visible, "the apron still renders: it is the threshold")


func test_a_worn_model_stands_on_the_plinth_and_never_below_the_skirt() -> void:
	var b := _bare()
	b.model_file = "saa_shed.glb"
	b.build()
	if not b.wears_a_model():
		pass_test("no converted props on this machine")
		return
	var model := b.get_node_or_null(^"Model") as Node3D
	assert_not_null(model, "the model was instanced")
	var box: AABB = PropsScript.world_aabb(model)
	assert_almost_eq(box.position.y, BuildingScript.FLOOR_TOP, 0.02,
		"the model's own floor meets the top of the plinth")
	assert_almost_eq(box.get_center().x, 0.0, 0.05, "the model is centred on the shell in x")
	assert_almost_eq(box.get_center().z, 0.0, 0.05, "the model is centred on the shell in z")


func test_a_worn_model_lights_nothing_because_hidden_walls_cast_no_shadow() -> void:
	var b := _bare()
	b.model_file = "saa_shed.glb"
	b.build()
	if not b.wears_a_model():
		pass_test("no converted props on this machine")
		return
	assert_null(b.get_node_or_null(^"InteriorFill"),
		"an omni inside invisible walls lights the grass outside them")


func test_a_shell_with_no_model_keeps_its_interior_fill() -> void:
	var b := _bare()
	b.build()
	assert_not_null(b.get_node_or_null(^"InteriorFill"),
		"the primitive shell is a closed box and still needs its light")


func test_the_plinth_under_a_model_is_turned_earth_rather_than_timber() -> void:
	var b := _bare()
	b.model_file = "saa_shed.glb"
	b.build()
	if not b.wears_a_model():
		pass_test("no converted props on this machine")
		return
	var floor_node := b.get_node_or_null(^"Floor") as MeshInstance3D
	var mat: StandardMaterial3D = (floor_node.mesh as BoxMesh).material
	assert_eq(mat.albedo_color, TerrainScript.DIRT,
		"a plinth under an MLP model reads as the terrain's own turned earth, not as "
		+ "props.gd's near-black skirt colour and not as a base in the wrong wood")
	var apron := b.get_node_or_null(^"DoorApron") as MeshInstance3D
	var apron_mat: StandardMaterial3D = (apron.mesh as BoxMesh).material
	assert_eq(apron_mat.albedo_color, TerrainScript.DIRT,
		"the threshold in front of a worn model is the same turned earth as the plinth it "
		+ "leans on")


## THE PLINTH SHRINKS TO WHAT THE MODEL ACTUALLY STANDS ON -- MEASURING REAL GEOMETRY,
## not re-deriving a number from the shell's own width and depth, which is exactly the eave
## rectangle this test exists to prove the plinth no longer matches (whole-branch review,
## 2026-09-05, F1: a PonySFM roof oversails its walls, and the plinth used to be sized to
## the roof line).
##
## COMPARED AGAINST THE MODEL'S OWN FULL-HEIGHT WORLD AABB -- ITS EAVE RECTANGLE -- NOT
## AGAINST _bare()'s ARBITRARY 6 x 4 m SHELL. The re-review of the first version of this test
## caught exactly the gap that comparison left open: `_bare()`'s width and depth are just
## numbers this test file picked, unrelated to what saa_shed.glb actually measures, so a
## regression back to sizing the plinth off the model's WHOLE bounding box (the original
## defect) would still land comfortably under 5.88 x 3.88 and this test would still pass.
## `model_box`, PropsScript.world_aabb() over every mesh in `Model`, is what the plinth would
## equal if that regression happened -- so asserting `box.size` is STRICTLY LESS than
## `model_box.size` is the one comparison a corner-of-AABB regression cannot slip past.
func test_the_plinth_under_a_model_shrinks_to_the_models_own_ground_contact() -> void:
	var b := _bare()
	b.model_file = "saa_shed.glb"
	b.build()
	if not b.wears_a_model():
		pass_test("no converted props on this machine")
		return
	var floor_node := b.get_node_or_null(^"Floor") as MeshInstance3D
	var box: BoxMesh = floor_node.mesh
	var model := b.get_node_or_null(^"Model") as Node3D
	var model_box: AABB = PropsScript.world_aabb(model)
	var margin := 0.05
	assert_lt(box.size.x, model_box.size.x - margin,
		"the plinth must be narrower than the WORN MODEL's own full-height AABB (its eave "
		+ "line), or the ground-contact walk regressed to measuring the whole model again")
	assert_lt(box.size.z, model_box.size.z - margin,
		"the plinth must be shallower than the WORN MODEL's own full-height AABB (its eave "
		+ "line), or the ground-contact walk regressed to measuring the whole model again")
	# The model itself must still stand ON this smaller plinth, not overhang it outright: the
	# ground-contact rectangle was measured off the model's own base, so the model's world
	# AABB (padded by the model's own roof overhang, which the plinth deliberately excludes)
	# has to reach at least as wide as what the plinth was sized to.
	assert_gte(model_box.size.x, box.size.x - 0.01,
		"the plinth must not be wider than the model actually standing on it")
	assert_gte(model_box.size.z, box.size.z - 0.01,
		"the plinth must not be deeper than the model actually standing on it")


const RanchScene := preload("res://world/ranch.tscn")

## The five that wear a model, and the seated footprint each was sized to. The Palace is not
## here: it is a kit bash of several pieces (game/world/palace_facade.gd), not one model.
##
## SCALE.md: each shell is its model's seated footprint at MLP_SCALE TIMES its own model_scale,
## which stands the model several pony heights tall (docs/playtest_fixes/scale.md). `k` is that
## factor; the w / d / ridge here are the MLP_SCALE measurements times k.
const SHIPPED := {
	"Barn": {"file": "saa_barn.glb", "k": 1.0, "w": 4.86, "d": 4.93, "ridge": 7.00},
	"Farmhouse": {"file": "pv_wide_b.glb", "k": 1.25, "w": 7.26 * 1.25, "d": 3.44 * 1.25, "ridge": 5.77 * 1.25},
	"Market": {"file": "pv_general.glb", "k": 1.35, "w": 10.62 * 1.35, "d": 5.07 * 1.35, "ridge": 5.34 * 1.35},
	"Board": {"file": "pv_bridged_b.glb", "k": 1.85, "w": 2.82 * 1.85, "d": 2.14 * 1.85, "ridge": 3.60 * 1.85},
	"Depot": {"file": "pv_tower_b.glb", "k": 1.3, "w": 6.29 * 1.3, "d": 3.05 * 1.3, "ridge": 7.43 * 1.3},
}

## Every building origin the owner's live save was made against. THESE MAY NOT MOVE: the
## interact verb is a flat XZ distance from each of these points (ranch.gd's is_near_*),
## so a moved origin is a Market that opens somewhere else than where the player learned it.
##
## ONE EXCEPTION, THE BOARD, moved 2.2 m from (3, -1) to (5, 0) by the scale fix
## (docs/playtest_fixes/scale.md): at SCALE.md's house size it no longer fits the notch between
## the Market's ramp and the Farmhouse's, and (5, 0) is the nearest spot it does.
##
## RE-LAID 2026-10-25 round a plaza (owner playtest: "the important buildings at the start
## are too close and not easy to navigate between"); DECISIONS.md has the plan.
const ORIGINS := {
	"Barn": Vector2(-17.0, -19.0), "Farmhouse": Vector2(2.0, -16.0),
	"Market": Vector2(18.0, -3.0), "Board": Vector2(-8.0, -13.0),
	"Depot": Vector2(-14.0, -3.0), "Palace": Vector2(-10.0, 61.6),
	"Mailbox": Vector2(8.0, 7.0),
}


func test_the_shipped_map_names_a_model_on_every_building_but_the_palace() -> void:
	var ranch: Node3D = RanchScene.instantiate()
	var buildings: Node3D = ranch.get_node(^"Buildings")
	for who: String in SHIPPED:
		var b := buildings.get_node_or_null(NodePath(who)) as Building
		assert_not_null(b, "%s stands" % who)
		assert_eq(b.model_file, String(SHIPPED[who]["file"]), "%s names its model" % who)
		assert_almost_eq(b.model_scale, float(SHIPPED[who]["k"]), 0.0001,
			"%s stands at its SCALE.md factor" % who)
	# The Palace wears the game's own Blender model (a res:// path, at its own scale), and
	# with it worn ranch.gd stands no kit-bashed facade, so it is never double dressed.
	var palace := buildings.get_node(^"Palace") as Building
	assert_eq(palace.model_file, "res://assets/models/spectra_palace.glb",
		"the palace wears its Blender model")
	ranch.free()


func test_every_shell_is_sized_to_the_model_standing_in_it() -> void:
	var ranch: Node3D = RanchScene.instantiate()
	var buildings: Node3D = ranch.get_node(^"Buildings")
	for who: String in SHIPPED:
		var b := buildings.get_node(NodePath(who)) as Building
		var want: Dictionary = SHIPPED[who]
		assert_almost_eq(b.width, float(want["w"]), 0.05, "%s width" % who)
		assert_almost_eq(b.depth, float(want["d"]), 0.05, "%s depth" % who)
		assert_almost_eq(b.ridge_height, float(want["ridge"]), 0.05, "%s ridge" % who)
		assert_gt(b.ridge_height, b.wall_height, "%s ridge is above its eaves" % who)
		assert_gt(b.width, b.door_width, "%s is wider than its own doorway" % who)
	ranch.free()


func test_no_building_origin_moved_out_from_under_the_owners_save() -> void:
	var ranch: Node3D = RanchScene.instantiate()
	var buildings: Node3D = ranch.get_node(^"Buildings")
	for who: String in ORIGINS:
		var node := buildings.get_node_or_null(NodePath(who)) as Node3D
		assert_not_null(node, "%s stands" % who)
		var at := Vector2(node.position.x, node.position.z)
		assert_almost_eq(at.x, (ORIGINS[who] as Vector2).x, 0.001, "%s x" % who)
		assert_almost_eq(at.y, (ORIGINS[who] as Vector2).y, 0.001, "%s z" % who)
	assert_eq(buildings.get_child_count(), 7, "the census term did not move")
	ranch.free()
