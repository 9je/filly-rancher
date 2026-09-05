extends GutTest
## THE SHELL WEARS A MODEL, OR IT DOES NOT AND STILL STANDS.
##
## game/assets/converted/ is gitignored, so CI and a fresh clone have no props at all. A
## building that only renders when its .glb is present would leave the CI runner with a map
## of invisible collision. Both halves are tested here: the modelled path on a machine that
## has run the pipeline, and the fallback path, which is what a missing model_file proves.

const BuildingScript := preload("res://world/building.gd")
const PropsScript := preload("res://world/props.gd")

const SHELL_MESHES := ["WallBack", "WallLeft", "WallRight", "RoofLeft", "RoofRight", "Gables"]


func _bare() -> Building:
	var b: Building = BuildingScript.new()
	b.width = 6.0
	b.depth = 4.0
	b.wall_height = 3.0
	b.ridge_height = 4.2
	b.door_width = 2.0
	b.door_height = 2.6
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
	assert_eq(mat.albedo_color, PropsScript.SKIRT_COLOUR,
		"a plinth under an MLP model reads as ground, not as a base in the wrong wood")
