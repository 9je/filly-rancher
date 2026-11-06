extends GutTest
## THE PEN MUST NOT BE A CAGE. Tests for the two halves of one playtest report from the
## owner: "i also trapped myself inside the pen and couldnt leave". He built a paddock while
## standing on the plot, the finished fence closed around him, and there was no way out --
## the gate leaf was one more slab on the pen's own StaticBody3D, on CollisionLayers.PROPS,
## and the player's mask contains PROPS.
##
## SO THERE ARE TWO RULES HERE, AND BOTH ARE ASSERTED WITH PHYSICS RATHER THAN ARITHMETIC:
##
##   1. A FARM GATE IS A GATE. A player-sized body walks out through the gateway; a
##      pony-sized body on a pony's mask does not. The fence itself stops BOTH of them
##      everywhere else.
##   2. YOU CANNOT SEAL YOURSELF IN BY BUILDING. A plot refuses to be built on while the
##      person ordering it is standing inside the square it is about to fence.
##
## WHY THE FIRST ONE CANNOT BE DONE WITH GEOMETRY, which is the fact this whole file exists
## to protect: the player and a pony are the SAME collision object. game/actors/player/
## player.tscn and game/actors/pony/pony.tscn both carry a CapsuleShape3D of radius 0.42 and
## height 1.30, centred at y = 0.65. No gap, no clearance, no header height can admit one and
## refuse the other. The only thing that can tell them apart is which layer each one's mask
## contains -- so the tests below drive two capsules that are identical in every respect
## EXCEPT their mask through the same hole, and the difference in where they end up is the
## layer policy, measured.
##
## THE ANTI-VACUITY GUARDS ARE THE POINT of half of these tests. "The pony did not get out"
## is trivially true of a pony who never moved, and "the player got out" is trivially true of
## a fence with a hole in it. So every containment assertion is paired with one that would
## fail if the fix had gone too far: the walker must be shown to have MOVED, and the same
## player-masked capsule that walks out of the gateway must be shown to be stopped dead by an
## ordinary side of the same fence.
##
## Preloads by path rather than by the global class_name, per the convention documented at
## the top of game/scripts/pony_rig.gd.

const PenScript := preload("res://world/pen.gd")
const PlotSlotScript := preload("res://world/plot_slot.gd")
const LayersScript := preload("res://world/collision_layers.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const ProductionScript := preload("res://systems/production.gd")

## The capsule both the player and a pony carry, from their two .tscn files. Restated here
## because the walkers below are built in code: a test that instantiated pony.tscn would need
## converted .glb models and would not run on a CI checkout (docs/ci.md section 4).
const BODY_RADIUS := 0.42
const BODY_HEIGHT := 1.30

## How hard a walker is driven at the fence, and for how many physics frames. 6 m/s for 90
## frames is 9 m at the project's 60 Hz tick -- twice the 4.32 m it takes to get a whole
## capsule from the middle of the pen to outside the fence line, so "she did not get out" can
## never quietly mean "she ran out of frames".
const WALK_SPEED := 6.0
const WALK_FRAMES := 90


func after_each() -> void:
	# Production keeps a process-wide fractional-gem ledger keyed by uid, exactly as
	# game/test/test_pen.gd's after_each says: left alone, one test's leftover progress
	# decides another test's first gem.
	ProductionScript.clear_all_progress()


func _pen(gate_yaw := 0.0) -> Pen:
	var pen: Pen = PenScript.new()
	pen.capacity = 1
	pen.slot_id = &"slot_gate_test"
	pen.gate_yaw_degrees = gate_yaw
	add_child_autofree(pen)
	return pen


## A capsule identical to the player's and to a pony's, differing only in its layers. THAT is
## the experiment: everything about these two bodies is the same except the answer to "what do
## you collide with".
func _walker(layer: int, mask: int) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = layer
	body.collision_mask = mask
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = capsule
	shape.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	body.add_child(shape)
	add_child_autofree(body)
	return body


## Put `walker` in the middle of `pen` and drive her at `direction` (in PEN-LOCAL space) until
## she stops moving or runs out of frames. Returns how far out she got, in pen-local metres
## along that axis.
##
## move_and_slide() rather than a teleport, because the question is whether she can GET there.
## A body placed outside the fence and found outside the fence proves nothing.
func _drive_out(walker: CharacterBody3D, pen: Pen, direction: Vector3) -> float:
	walker.global_position = pen.to_global(Vector3.ZERO)
	walker.velocity = Vector3.ZERO
	await wait_physics_frames(1)
	for i in range(WALK_FRAMES):
		walker.velocity = pen.global_transform.basis * (direction * WALK_SPEED)
		walker.move_and_slide()
		await wait_physics_frames(1)
	var local: Vector3 = pen.to_local(walker.global_position)
	return local.dot(direction)


# --- the layer policy ---------------------------------------------------------------------

func test_the_gate_leaf_is_the_only_part_of_a_fence_that_is_not_props() -> void:
	# The shape of the fix, asserted on the nodes rather than on the idea of them. The pen is
	# still one PROPS body -- everything the camera probes and everybody bumps into -- plus
	# exactly one extra body carrying the gate leaf on PEN_GATE.
	var pen := _pen()
	assert_eq(pen.collision_layer, LayersScript.PROPS,
		"the fence proper stays on PROPS: it must stop the player, the ponies and the camera")
	var gate: StaticBody3D = pen.gate_body()
	assert_not_null(gate, "a pen must build a separate body for its gate leaf")
	assert_eq(gate.collision_layer, LayersScript.PEN_GATE,
		"the gate leaf is the one piece on PEN_GATE -- that is what makes it a gate")
	assert_eq(gate.collision_mask, 0,
		"a fence collides with nothing; it is collided WITH")
	assert_gt(gate.find_children("*", "CollisionShape3D", true, false).size(), 0,
		"a gate leaf body with no shape on it is an open gateway with extra steps")


func test_a_ponys_mask_holds_the_gate_shut_and_the_players_does_not() -> void:
	# The whole policy in four lines. If any one of these flips, one of the two failures this
	# file is about comes straight back: WALKABLE gaining PEN_GATE re-cages the player,
	# PONY_WALKABLE losing it opens every paddock on the map.
	assert_eq(LayersScript.PEN_GATE & (LayersScript.PEN_GATE - 1), 0,
		"PEN_GATE must be exactly one bit")
	for other in [LayersScript.TERRAIN, LayersScript.PROPS, LayersScript.PLAYER,
			LayersScript.PONY, LayersScript.INTERACTION]:
		assert_eq(LayersScript.PEN_GATE & other, 0,
			"PEN_GATE must not share a bit with an existing layer (%d)" % other)
	assert_ne(LayersScript.PONY_WALKABLE & LayersScript.PEN_GATE, 0,
		"a pony must collide with the gate leaf, or she walks out of her own paddock")
	assert_eq(LayersScript.WALKABLE & LayersScript.PEN_GATE, 0,
		"the player must NOT collide with it -- that is the bug that trapped the owner")
	assert_eq(LayersScript.PONY_WALKABLE & LayersScript.WALKABLE, LayersScript.WALKABLE,
		"a pony still collides with everything a walking character did before")
	assert_eq(LayersScript.PONY_BARRIER, LayersScript.PROPS | LayersScript.PEN_GATE,
		"the containment probe's ray mask must be the fence AND the gate, or it reports a "
		+ "gateway that is solid to a pony as a hole")


func test_a_resident_is_spawned_with_the_mask_that_keeps_her_in() -> void:
	# The policy above has to actually reach the bodies standing in the paddock. This is the
	# unit-sized version of the ranch gate's "a penned pony's mask does include a pen's gate
	# leaf" check -- it needs a pony model, so it is skipped on an assetless checkout rather
	# than failing there (docs/ci.md section 4).
	var pen := _pen()
	var inst: PonyInstance = PonyInstanceScript.create(&"twilight")
	if not pen.add_pony(inst):
		return
	var body: Node3D = pen.body_for(inst.uid)
	if body == null:
		return
	assert_eq(body.collision_layer, LayersScript.PONY, "she is on the PONY layer")
	assert_ne(body.collision_mask & LayersScript.PEN_GATE, 0,
		"...and her mask includes the gate leaf, or the paddock is open on the gate side")
	# PT checkpoint review: nothing put a resident in this group, so Pony._react_to_player's
	# "a resident never bolts" (which the walk-only leash depends on) never held in play.
	assert_true(body.is_in_group(&"penned"), "she is known to be a resident")
	var out: Node3D = pen.release_body(inst.uid, self)
	assert_false(out.is_in_group(&"penned"), "and is not one once she is let out")
	out.queue_free()


# --- the gateway, measured -------------------------------------------------------------------

func test_a_player_sized_body_walks_out_through_the_gateway() -> void:
	# THE REPORTED BUG, as a test. Before the fix this capsule stopped dead at 3.4 m -- the
	# inside face of a gate leaf that was on PROPS like every other slab -- and the only way
	# out of a pen you built around yourself was to quit.
	var pen := _pen()
	var walker := _walker(LayersScript.PLAYER, LayersScript.WALKABLE)
	var reached: float = await _drive_out(walker, pen, Vector3.RIGHT)
	assert_gt(reached, PenScript.HALF_EXTENT + BODY_RADIUS,
		"a player-masked body must get her whole capsule out through the gateway "
		+ "(past %.2f m); she reached %.2f m" % [PenScript.HALF_EXTENT + BODY_RADIUS, reached])


func test_a_pony_sized_body_is_stopped_by_the_same_gateway() -> void:
	# The other half, through the SAME hole with the SAME capsule. Only the mask differs, so
	# a difference in the outcome can only be the layer policy.
	var pen := _pen()
	var walker := _walker(LayersScript.PONY, LayersScript.PONY_WALKABLE)
	var reached: float = await _drive_out(walker, pen, Vector3.RIGHT)
	assert_lt(reached, PenScript.HALF_EXTENT - BODY_RADIUS,
		"a pony-masked body must be held inside the fence line; she reached %.2f m" % reached)
	# ANTI-VACUITY: she has to have been driven at it. "She did not get out" is trivially
	# true of a body that never moved, which is what a broken physics step, a shape that
	# failed to build, or a walker that was never added to the tree would all look like.
	assert_gt(reached, 1.0,
		"...having actually walked at the gate: she only got %.2f m from the centre" % reached)


func test_the_fence_itself_still_stops_the_player_everywhere_but_the_gateway() -> void:
	# THE GUARD ON THE FIX. Everything above would also pass if the gate had been "fixed" by
	# deleting the pen's colliders, or by taking the whole fence off PROPS. Same walker, same
	# mask, same pen, driven at a side that is NOT the gate: she has to be stopped cold.
	var pen := _pen()
	var walker := _walker(LayersScript.PLAYER, LayersScript.WALKABLE)
	var reached: float = await _drive_out(walker, pen, Vector3.LEFT)
	assert_lt(reached, PenScript.HALF_EXTENT - BODY_RADIUS,
		"the player must NOT be able to walk through a plain side of the fence; "
		+ "she reached %.2f m" % reached)
	assert_gt(reached, 1.0, "...having actually walked at it (%.2f m)" % reached)


func test_a_pony_is_stopped_by_a_plain_side_of_the_fence_too() -> void:
	# The pen was already a pen on its three solid sides and must stay one. This is the check
	# that would go red if PONY_WALKABLE were ever "simplified" back to something that dropped
	# PROPS along with the rest.
	var pen := _pen()
	var walker := _walker(LayersScript.PONY, LayersScript.PONY_WALKABLE)
	var reached: float = await _drive_out(walker, pen, Vector3.FORWARD)
	assert_lt(reached, PenScript.HALF_EXTENT - BODY_RADIUS,
		"a pony must be held by an ordinary fence side; she reached %.2f m" % reached)
	assert_gt(reached, 1.0, "...having actually walked at it (%.2f m)" % reached)


func test_the_gateway_follows_the_gate_yaw_rather_than_being_a_hole_in_plus_x() -> void:
	# A pen built with its gate on another side has to be passable THERE and solid where the
	# gateway used to be. Without this, "the player can get out" could be satisfied by a hole
	# that happens to sit at +X on every pen regardless of what gate_yaw_degrees says -- and
	# two of ranch.tscn's four slots are turned 180 degrees, so that would ship.
	var pen := _pen(180.0)
	var out_walker := _walker(LayersScript.PLAYER, LayersScript.WALKABLE)
	var out_reached: float = await _drive_out(out_walker, pen, Vector3.LEFT)
	assert_gt(out_reached, PenScript.HALF_EXTENT + BODY_RADIUS,
		"the gateway must be on the side gate_yaw_degrees names; she reached %.2f m"
			% out_reached)
	var blocked := _walker(LayersScript.PLAYER, LayersScript.WALKABLE)
	var blocked_reached: float = await _drive_out(blocked, pen, Vector3.RIGHT)
	assert_lt(blocked_reached, PenScript.HALF_EXTENT - BODY_RADIUS,
		"...and the side it is NOT on must be solid; she reached %.2f m" % blocked_reached)


func test_the_swing_cannot_move_what_holds_a_pony_in() -> void:
	# THE INVARIANT THAT LETS THE LEAF BE ANIMATED AT ALL. The mesh swings open when the
	# player walks up to it -- otherwise she walks through a visibly shut gate, which is the
	# reading of "that's a bug" the report came from -- but the collider is a child of the PEN
	# and not of the hinge. If somebody ever "tidies" that by parenting the collider to the
	# thing it is drawn on, every open frame becomes a hole in the fence and the ranch's
	# containment probe only catches it if the player happens to be standing there.
	var pen := _pen()
	var gate: StaticBody3D = pen.gate_body()
	var before: Transform3D = gate.global_transform
	var hinge: Node3D = pen.get_node_or_null(^"Side0GateHinge")
	assert_not_null(hinge, "the leaf must hang on a hinge, or it cannot swing at all")
	hinge.rotation.y = deg_to_rad(-PenScript.GATE_OPEN_DEGREES)
	await wait_physics_frames(2)
	assert_true(hinge.get_child_count() > 0,
		"the hinge must actually carry the leaf's bars, or nothing visibly opens")
	assert_almost_eq(gate.global_transform.origin.distance_to(before.origin), 0.0, 0.0001,
		"swinging the leaf must not move its collider")
	assert_almost_eq((gate.global_transform.basis.x - before.basis.x).length(), 0.0, 0.0001,
		"...or rotate it")


func test_a_pony_is_still_stopped_while_the_gate_is_drawn_wide_open() -> void:
	# The same claim as above, but end to end: with the leaf swung fully open, a pony-masked
	# capsule driven at the gateway still does not get out. This is what makes the animation
	# safe to add to a file whose whole job is containment.
	var pen := _pen()
	var hinge: Node3D = pen.get_node_or_null(^"Side0GateHinge")
	assert_not_null(hinge, "precondition: the leaf hangs on a hinge")
	hinge.rotation.y = deg_to_rad(-PenScript.GATE_OPEN_DEGREES)
	var walker := _walker(LayersScript.PONY, LayersScript.PONY_WALKABLE)
	var reached: float = await _drive_out(walker, pen, Vector3.RIGHT)
	assert_lt(reached, PenScript.HALF_EXTENT - BODY_RADIUS,
		"an open-looking gate is still shut to a pony; she reached %.2f m" % reached)


# --- you cannot seal yourself in by building ---------------------------------------------------

func test_the_marked_footprint_is_exactly_the_fence_line() -> void:
	# The two numbers that make the refusal below actionable instead of mysterious. The slot
	# paints its boundary boards at STAKE_INSET and the pen stands its fence at HALF_EXTENT;
	# if those ever drift apart, "step outside the plot markers" starts naming a line that is
	# not where the fence goes, and a player who obeys it still gets fenced in.
	assert_almost_eq(PlotSlotScript.STAKE_INSET, PenScript.HALF_EXTENT, 0.0001,
		"the marked square must be the square the fence is built on")


func test_a_slot_knows_when_somebody_is_standing_where_the_fence_goes() -> void:
	# THE SECOND HALF OF THE PLAYTEST REPORT. game/world/ranch.gd asks this before it opens
	# the build menu AND again before it builds, and refuses with a reason both times --
	# rather than moving the player, which is the one outcome that can surprise somebody who
	# is looking at a menu when it happens.
	# IN THE TREE, because is_on_footprint() works in the slot's own frame and a Node3D that
	# is not in a tree has no global transform to convert against -- Godot returns an identity
	# and logs an error rather than answering.
	var slot: PlotSlot = PlotSlotScript.new()
	slot.slot_id = &"slot_footprint"
	add_child_autofree(slot)
	var edge: float = PlotSlotScript.STAKE_INSET

	assert_true(slot.is_on_footprint(Vector3.ZERO, BODY_RADIUS),
		"the middle of the plot is inside the fence that is about to go up")
	assert_true(slot.is_on_footprint(Vector3(edge - 0.05, 0.0, 0.0), BODY_RADIUS),
		"...and so is standing on the marked line")
	# HER RADIUS COUNTS. Standing 0.2 m outside the markers still puts 0.22 m of her inside
	# them, and a fence built through that leaves her overlapping a slab to be shoved out of.
	assert_true(slot.is_on_footprint(Vector3(edge + 0.2, 0.0, 0.0), BODY_RADIUS),
		"a body whose capsule reaches over the line is still in the way")
	assert_false(slot.is_on_footprint(Vector3(edge + BODY_RADIUS + 0.05, 0.0, 0.0),
			BODY_RADIUS),
		"a body entirely clear of the markers is not in the way -- there has to be somewhere "
		+ "legal to stand, or the plot becomes unbuildable")
	# THE CORNER. A square footprint is not a circle: standing off one corner is inside it on
	# both axes at once, and a distance-from-centre test would call that safe.
	assert_true(slot.is_on_footprint(Vector3(edge - 0.1, 0.0, edge - 0.1), BODY_RADIUS),
		"the footprint is a square, so its corners are inside it too")


func test_the_refusal_is_measured_in_the_slots_own_frame() -> void:
	# Two of ranch.tscn's four slots are turned 180 degrees so their gates face open ground.
	# A world-space comparison would be measuring the wrong axis for those two -- the same
	# trap the ranch's containment probe documents -- and it would fail open, which is the
	# direction that traps somebody.
	var slot: PlotSlot = PlotSlotScript.new()
	slot.slot_id = &"slot_turned"
	add_child_autofree(slot)
	slot.position = Vector3(-18.5, 0.0, 8.5)
	slot.rotation.y = PI
	var inside: Vector3 = slot.to_global(Vector3(1.0, 0.0, 1.0))
	assert_true(slot.is_on_footprint(inside, BODY_RADIUS),
		"a point inside a turned slot's footprint is still inside it")
	var outside: Vector3 = slot.to_global(
		Vector3(PlotSlotScript.STAKE_INSET + BODY_RADIUS + 0.5, 0.0, 0.0))
	assert_false(slot.is_on_footprint(outside, BODY_RADIUS),
		"...and a point clear of it is still clear of it")


func test_there_is_room_to_stand_between_the_footprint_and_the_edge_of_the_trigger() -> void:
	# A refusal you cannot satisfy is a plot nobody can build on. The build menu only opens
	# while the player's capsule overlaps the slot's trigger (TRIGGER_HALF), and it only
	# builds while she is clear of the footprint -- so those two limits have to leave a band
	# of ground between them. This is the check that goes red if somebody shrinks the trigger
	# or grows the pen and quietly makes every plot unbuildable.
	var must_be_clear_of: float = PlotSlotScript.STAKE_INSET + BODY_RADIUS
	var still_inside_trigger: float = PlotSlotScript.TRIGGER_HALF + BODY_RADIUS
	assert_gt(still_inside_trigger - must_be_clear_of, 0.25,
		"there must be a usable band of ground where a player is both outside the fence "
		+ "footprint (%.2f m) and inside the build trigger (%.2f m)"
			% [must_be_clear_of, still_inside_trigger])
