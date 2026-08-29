extends GutTest
## THE RING AROUND A LOCKED REGION, asserted with physics rather than arithmetic.
##
## The claim RegionFence exists to make is a claim about where a body can GET to, so every
## test here drives a capsule at the ring with move_and_slide() the way game/test/
## test_pen_gate.gd drives one at a paddock, and measures how far from the region's centre
## she ended up. A body placed inside the ring and found inside it would prove nothing.
##
## THE TWO CAPSULES ARE IDENTICAL EXCEPT FOR THEIR MASK, which is the same experiment
## test_pen_gate.gd runs and for the same reason: game/actors/player/player.tscn and
## game/actors/pony/pony.tscn carry the same 0.42 m radius, 1.30 m capsule, so nothing about
## geometry can tell a farmer from a pony. Here the answer is deliberately the OPPOSITE of a
## paddock's, though. A paddock's gate is a one-way valve, open to the player and shut to a
## pony forever. A region's gate is a LOCK: shut to everybody until the permit is bought,
## then open to everybody. Residents of a region stay in it by their leash, not by this
## fence, so an open gate that still turned ponies back would be a fence pretending to be a
## leash.
##
## Preloads by path rather than by the global class_name, per the convention documented at
## the top of game/scripts/pony_rig.gd.

const RegionFenceScene := preload("res://world/region_fence.tscn")
const RegionFenceScript := preload("res://world/region_fence.gd")
const RegionDataScript := preload("res://systems/region_data.gd")
const LayersScript := preload("res://world/collision_layers.gd")

## The capsule both the player and a pony carry, from their two .tscn files. Restated here
## because the walkers below are built in code: a test that instantiated pony.tscn would
## need converted .glb models and would not run on a CI checkout (docs/ci.md section 4).
const BODY_RADIUS := 0.42
const BODY_HEIGHT := 1.30

## How hard a walker is driven at the ring and for how long. 6 m/s for 90 frames is 9 m at
## the project's 60 Hz tick, comfortably more than the 8 m she is asked to cover, so "she did
## not get in" can never quietly mean "she ran out of frames".
const WALK_SPEED := 6.0
const WALK_FRAMES := 90

## Where a walker starts and where she is aimed, in metres either side of the fence line.
const APPROACH := 4.0

var _world: Node3D
var _fence: RegionFence
var _region: RegionData


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	# A CharacterBody3D driven with move_and_slide() wants a floor under it; without one the
	# first depenetration step of the fence's buried posts can shove a walker downward and
	# the run stops meaning what it looks like.
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = LayersScript.TERRAIN
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(200.0, 1.0, 200.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_shape)
	_world.add_child(floor_body)

	_region = RegionDataScript.new()
	_region.id = &"test"
	_region.centre = Vector2.ZERO
	_region.radius = 12.0
	_region.gate_yaw_degrees = 0.0
	_fence = RegionFenceScene.instantiate()
	_world.add_child(_fence)
	_fence.configure(_region, func(_x: float, _z: float) -> float: return 0.0)
	_fence.build()


## A capsule identical to the player's and to a pony's, differing only in its layers.
func _walker(layer: int, mask: int, from: Vector3) -> CharacterBody3D:
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
	_world.add_child(body)
	body.global_position = from
	return body


## Drive `body` at `target` for WALK_FRAMES physics frames. Returns how far from the region's
## centre it ended up, measured flat: that is the question the ring is about.
func _drive(body: CharacterBody3D, target: Vector3) -> float:
	for i in range(WALK_FRAMES):
		var dir := target - body.global_position
		dir.y = 0.0
		body.velocity = dir.normalized() * WALK_SPEED
		body.move_and_slide()
		await wait_physics_frames(1)
	return _flat(body.global_position).length()


## Distance from the region's centre, ignoring height.
func _flat(at: Vector3) -> Vector3:
	return Vector3(at.x - _region.centre.x, 0.0, at.z - _region.centre.y)


func test_a_closed_gate_stops_the_player() -> void:
	# THE POINT OF THE WHOLE FILE. Until she has bought the permit, the gateway is a wall to
	# her, and it is a wall on PROPS as well as PEN_GATE precisely because her mask does not
	# contain PEN_GATE: a leaf that was only on PEN_GATE would be a paddock gate, which she
	# would stroll straight through.
	var gate := _fence.gate_position()
	var outward := _flat(gate).normalized()
	var line: float = _flat(gate).length()
	var player := _walker(LayersScript.PLAYER, LayersScript.WALKABLE, gate + outward * APPROACH)
	var start := player.global_position
	var reached: float = await _drive(player, gate - outward * APPROACH)
	assert_gt(reached, line,
		"a closed gate must hold her outside the fence line (%.2f m); she reached %.2f m"
			% [line, reached])
	# ANTI-VACUITY: "she did not get in" is trivially true of a body that never moved, which
	# is what a failed shape, a missing floor or an unparented walker would all look like.
	assert_gt(start.distance_to(player.global_position), 2.5,
		"...having actually walked at it")


func test_an_open_gate_lets_the_player_through_and_a_pony_too() -> void:
	_fence.set_open(true)
	assert_true(_fence.is_open(), "set_open(true) must be readable back")
	var gate := _fence.gate_position()
	var outward := _flat(gate).normalized()
	var line: float = _flat(gate).length()
	var outside := gate + outward * APPROACH
	var inside := gate - outward * APPROACH

	var player := _walker(LayersScript.PLAYER, LayersScript.WALKABLE, outside)
	var reached: float = await _drive(player, inside)
	assert_lt(reached, line - 3.0,
		"the permit is bought, so the gateway must let her walk well in (past %.2f m); "
			% (line - 3.0) + "she got to %.2f m" % reached)
	# She is on the PLAYER layer and a pony's mask contains it, so leaving her standing in
	# the gateway would make the next run a test of two capsules bumping into each other.
	player.queue_free()
	await wait_physics_frames(1)

	# AN OPEN GATE IS OPEN TO PONIES TOO. A region's fence is a lock, not a leash: the ponies
	# who live inside are kept there by pony_leash.gd, and a ring that turned them back after
	# the permit was bought would be doing the leash's job badly and invisibly.
	var pony := _walker(LayersScript.PONY, LayersScript.PONY_WALKABLE, outside)
	var pony_reached: float = await _drive(pony, inside)
	assert_lt(pony_reached, line - 3.0,
		"an open gate is open to a pony as well; she got to %.2f m" % pony_reached)


func test_the_rails_stop_the_player_away_from_the_gate() -> void:
	# THE GUARD ON THE TEST ABOVE, which would also pass if the ring were nothing but a gate
	# post in an empty field. Same walker, same mask, opened gate, driven at the panel on the
	# far side of the ring: she has to be stopped cold there whether the permit is bought or
	# not, because a border you can walk around is not a border.
	_fence.set_open(true)
	var opposite := -_flat(_fence.gate_position())
	var outward := opposite.normalized()
	var line: float = opposite.length()
	var player := _walker(LayersScript.PLAYER, LayersScript.WALKABLE,
		opposite + outward * APPROACH)
	var start := player.global_position
	var reached: float = await _drive(player, opposite - outward * APPROACH)
	assert_gt(reached, line,
		"a plain segment is a fence, open gate or not (line %.2f m); she reached %.2f m"
			% [line, reached])
	assert_gt(start.distance_to(player.global_position), 2.5,
		"...having actually walked at it")


func test_opening_and_closing_toggles_the_leafs_layer() -> void:
	# The state the two physics tests above are really about, read off the node, so a failure
	# there can be told apart from a failure here. The closed layer carries PROPS as well as
	# PEN_GATE: PROPS is the half the player's mask sees.
	var gate: StaticBody3D = _fence.gate_body()
	assert_not_null(gate, "the ring must build a separate body for its leaf")
	assert_eq(gate.collision_mask, 0, "a fence collides with nothing; it is collided WITH")
	assert_gt(gate.find_children("*", "CollisionShape3D", true, false).size(), 0,
		"a leaf body with no shape on it is an open gateway with extra steps")
	_fence.set_open(true)
	assert_eq(gate.collision_layer, 0, "an opened gate stops nobody at all")
	assert_true(_fence.is_open(), "...and says so")
	_fence.set_open(false)
	assert_false(_fence.is_open(), "a gate that has been shut again reports itself shut")
	assert_eq(gate.collision_layer, LayersScript.PEN_GATE | LayersScript.PROPS,
		"a shut gate is back on both layers, so it stops the player and the ponies alike")
	assert_eq(_fence.region(), _region, "the fence remembers which region it rings")
	# The ring stands clear of the region proper, so a fence post never lands in the grass a
	# ZoneMarker is spawning ponies onto.
	assert_gt(RegionFenceScript.RING_MARGIN, 0.0,
		"the ring must stand outside the region's own radius, not on it")
