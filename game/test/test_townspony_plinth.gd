extends GutTest
## PLAYTEST 2026-11-05 ITEM 43: "A townspony stuck half inside the Palace plinth wall [37]."
##
## The townspony in the owner's shot is the Teller, the grey stallion beside the Palace door
## (ranch.gd _stand_attendants()). These claims are made against the plinth and the ramp AS
## BUILT -- the `Floor` and `DoorApron` slabs Building.build() actually stands, read off the
## live nodes -- and against his drawn body, not his origin. test_attendant.gd measured the
## same placement against the shell's own `depth`, which is not where the plinth's face is
## for a building wearing a model (its plinth is sized to the model's ground contact), so it
## passed while his hindquarters stood in the brickwork.

const RanchScene := preload("res://world/ranch.tscn")
const PeopleScript := preload("res://world/people.gd")

## Daylight a body has to keep from the brick, in metres. A hair, not a standoff: the claim
## is "not inside", and the staging tests in test_attendant.gd own "how far beside".
const TOUCH := 0.02


func _shipped_ranch() -> Node3D:
	var ranch: Node3D = RanchScene.instantiate()
	add_child_autofree(ranch)
	await get_tree().process_frame
	return ranch


## A slab's XZ rectangle in its building's own frame (slabs are only ever pitched about X,
## so the apron's XZ shadow is its size along Z times cos(pitch) -- taken from the mesh's
## transformed AABB rather than re-derived).
func _slab_rect(b: Building, slab: String) -> Rect2:
	var m := b.get_node_or_null(NodePath(slab)) as MeshInstance3D
	if m == null:
		return Rect2()
	var box: AABB = m.transform * m.get_aabb()
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)


## Everything drawn of `who`, in `b`'s own frame, flattened to XZ.
func _body_rect(who: Node3D, b: Building) -> Rect2:
	var to_b: Transform3D = b.global_transform.affine_inverse()
	var out := Rect2()
	var first := true
	for m: MeshInstance3D in who.find_children("*", "MeshInstance3D", true, false):
		if not m.visible:
			continue
		var box: AABB = (to_b * m.global_transform) * m.get_aabb()
		var r := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		out = r if first else out.merge(r)
		first = false
	return out


func _overlap(a: Rect2, b: Rect2) -> bool:
	return a.grow(-TOUCH).intersects(b)


func test_the_teller_stands_clear_of_the_palace_plinth_as_built() -> void:
	var ranch: Node3D = await _shipped_ranch()
	var teller := ranch.get_node_or_null(^"Attendants/Teller") as Node3D
	var palace := ranch.get_node_or_null(^"Buildings/Palace") as Building
	assert_not_null(teller, "the Teller is standing")
	assert_not_null(palace)
	if teller == null or palace == null:
		return
	var plinth := _slab_rect(palace, "Floor")
	assert_gt(plinth.get_area(), 1.0, "the Palace has a plinth to measure")
	var body := _body_rect(teller, palace)
	if body.get_area() <= 0.0:
		pass_test("no converted pony bodies on this machine")
		return
	assert_false(_overlap(body, plinth),
		"the Teller's body (local x %.2f..%.2f, z %.2f..%.2f) is inside the Palace plinth (z to %.2f)"
			% [body.position.x, body.end.x, body.position.y, body.end.y, plinth.end.y])
	assert_false(_overlap(body, _slab_rect(palace, "DoorApron")),
		"the Teller is standing in the Palace's ramp")


## Every attendant against every building's real plinth and ramp, so the Vendor and any
## building that grows a worn model later are held to the same claim.
func test_no_attendant_body_is_inside_any_plinth_or_ramp_on_the_map() -> void:
	var ranch: Node3D = await _shipped_ranch()
	var attendants := ranch.get_node_or_null(^"Attendants") as Node3D
	assert_not_null(attendants)
	for who: Node in attendants.get_children():
		for child: Node in ranch.get_node(^"Buildings").get_children():
			var b := child as Building
			if b == null:
				continue
			var body := _body_rect(who as Node3D, b)
			if body.get_area() <= 0.0:
				continue
			for slab: String in ["Floor", "DoorApron"]:
				var r := _slab_rect(b, slab)
				if r.get_area() <= 0.0:
					continue
				assert_false(_overlap(body, r),
					"%s is inside %s's %s" % [who.name, b.name, slab])


## The story cast's stand points (people.gd SPOTS) are on open ground, not in any plinth.
func test_no_townspony_spot_is_inside_a_plinth() -> void:
	var ranch: Node3D = await _shipped_ranch()
	for id: StringName in PeopleScript.SPOTS:
		var at: Vector3 = PeopleScript.SPOTS[id][0]
		for child: Node in ranch.get_node(^"Buildings").get_children():
			var b := child as Building
			if b == null:
				continue
			var l: Vector3 = b.to_local(Vector3(at.x, b.global_position.y, at.z))
			var p := Vector2(l.x, l.z)
			for slab: String in ["Floor", "DoorApron"]:
				var r := _slab_rect(b, slab)
				assert_false(r.get_area() > 0.0 and r.grow(0.4).has_point(p),
					"%s's spot is inside %s's %s" % [id, b.name, slab])
