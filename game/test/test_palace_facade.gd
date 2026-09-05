extends GutTest
## THE PALACE IS A KIT BASH AND THIS IS THE PROOF THAT IT IS A BUILDING.
##
## scratchpad/ledgers/redesign/palace-sourcing.md searched every no-login source there is and
## found no MLP casino, resort or Las Pegasus facade anywhere. So the Palace is Ponyville
## Environments pieces standing shoulder to shoulder inside the shell's own rectangle. The
## Neon Lights Pack turned out to be a pony skin with no usable meshes at all (see
## tools/prop_manifest.txt's `# NEON IDS:` line), so the neon over the door is DRAWN geometry
## instead of a loaded prop -- an emissive tube, a gold trim frame and bulb accents built in
## the same visual language game/world/strip.gd's marquee already established. What a test
## can say about that is geometric: nothing stands in the doorway, nothing oversails the
## shell by more than a roof would, nothing dips below the plinth the shell is seated on, and
## the drawn neon is real emissive geometry rather than a constant claiming to be one.

const FacadeScript := preload("res://world/palace_facade.gd")
const BuildingScript := preload("res://world/building.gd")
const PropsScript := preload("res://world/props.gd")

const HALF_WIDTH := 7.0
const HALF_DEPTH := 4.5
const DOOR_HALF := 1.6


func _built() -> PalaceFacade:
	var f: PalaceFacade = FacadeScript.new()
	add_child_autofree(f)
	f.build(HALF_WIDTH, HALF_DEPTH, DOOR_HALF, Vector3(0.0, 0.0, 1.0))
	return f


func test_the_composition_table_is_symmetric_about_the_door() -> void:
	var xs: Array[float] = []
	for piece: Dictionary in FacadeScript.PIECES:
		xs.append(float((piece["at"] as Vector2).x))
	for x: float in xs:
		assert_true(xs.has(-x) or absf(x) < 0.01,
			"every piece off the centreline has a mirror: %.2f does not" % x)


func test_the_neon_table_is_symmetric_about_the_door() -> void:
	var xs: Array[float] = []
	for lamp: Dictionary in FacadeScript.NEON:
		xs.append(float((lamp["at"] as Vector2).x))
	for x: float in xs:
		assert_true(xs.has(-x) or absf(x) < 0.01,
			"every neon fixture off the centreline has a mirror: %.2f does not" % x)


func test_no_piece_stands_in_the_doorway() -> void:
	var f := _built()
	if f.piece_count() == 0:
		pass_test("no converted props on this machine")
		return
	for child: Node3D in f.get_children():
		var box: AABB = PropsScript.world_aabb(child)
		if box.size == Vector3.ZERO:
			continue
		var over_door: bool = box.position.x < DOOR_HALF and box.position.x + box.size.x > -DOOR_HALF
		var at_the_front: bool = box.position.z + box.size.z > HALF_DEPTH - 0.5
		assert_false(over_door and at_the_front,
			"%s stands in the door the player walks up to" % child.name)


func test_nothing_oversails_the_shell_by_more_than_a_roof_would() -> void:
	var f := _built()
	if f.piece_count() == 0:
		pass_test("no converted props on this machine")
		return
	for child: Node3D in f.get_children():
		var box: AABB = PropsScript.world_aabb(child)
		if box.size == Vector3.ZERO:
			continue
		assert_lt(maxf(absf(box.position.x), absf(box.position.x + box.size.x)),
			HALF_WIDTH + FacadeScript.OVERSAIL, "%s reaches past the facade in x" % child.name)
		assert_lt(maxf(absf(box.position.z), absf(box.position.z + box.size.z)),
			HALF_DEPTH + FacadeScript.OVERSAIL, "%s reaches past the facade in z" % child.name)


func test_nothing_dips_below_the_plinth_it_stands_on() -> void:
	var f := _built()
	if f.piece_count() == 0:
		pass_test("no converted props on this machine")
		return
	for child: Node3D in f.get_children():
		var box: AABB = PropsScript.world_aabb(child)
		if box.size == Vector3.ZERO:
			continue
		assert_gt(box.position.y, BuildingScript.FLOOR_TOP - 0.02,
			"%s hangs below the plinth and would drag the Palace's own seat down" % child.name)


func test_a_machine_with_no_props_stands_no_facade_and_does_not_error() -> void:
	var f: PalaceFacade = FacadeScript.new()
	add_child_autofree(f)
	var stood: int = f.build(HALF_WIDTH, HALF_DEPTH, DOOR_HALF, Vector3.ZERO)
	assert_between(stood, 0, FacadeScript.PIECES.size(),
		"a degenerate facing is not a reason to error, only a reason to face forward")


## THE NEON IS DRAWN, SO THIS IS WHAT PROVES IT IS THERE. Not a piece_count()-style prop load
## (there is nothing to load -- see the class doc), so the only honest check is the built
## scene tree itself: real MeshInstance3D nodes, with emission actually turned on, standing
## where the NEON table says they should. Independent of neon_count()'s own arithmetic, the
## same reason test_strip.gd's arch test recomputes its peak off the live nodes rather than
## trusting the accessor that reports it.
func test_the_neon_is_real_emissive_geometry_and_not_a_constant() -> void:
	var f := _built()
	var emissive: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		var mat := mesh.get_active_material(0)
		if mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_enabled:
			emissive.append(mesh)
	assert_eq(emissive.size(), f.neon_count(),
		"neon_count() must report exactly the emissive geometry that was actually built")
	assert_gt(emissive.size(), 0, "the neon dressing is drawn geometry, not zero of it")
	for mesh: MeshInstance3D in emissive:
		assert_gt(mesh.global_position.y, BuildingScript.FLOOR_TOP,
			"%s hangs on the wall above the floor, not on the ground" % mesh.name)


func test_neon_fixtures_do_not_stand_in_the_doorway_either() -> void:
	var f := _built()
	for child: Node3D in f.get_children():
		if not child.name.begins_with("Neon"):
			continue
		var box: AABB = PropsScript.world_aabb(child)
		if box.size == Vector3.ZERO:
			continue
		var over_door: bool = box.position.x < DOOR_HALF and box.position.x + box.size.x > -DOOR_HALF
		assert_false(over_door, "%s hangs over the doorway the player walks up to" % child.name)
