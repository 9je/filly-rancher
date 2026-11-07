extends GutTest
## SMARTER FLEEING (PS9; playtest 2026-11-05 item 69: "Catching is too easy (all but the
## toughest) and repetitive"). A shy pony notices the player further off than she did
## (16.5 m, was 14), and a fleeing pony with a tree or a prop in her way bends round it
## instead of running into it and stopping there.

const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyScript := preload("res://actors/pony/pony.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const Layers := preload("res://world/collision_layers.gd")
const TEMPLATE := preload("res://data/ponies/pokeypierce.tres")

var _world: Node3D


class Watcher:
	extends CharacterBody3D
	func is_sneaking() -> bool:
		return false


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_world.add_child(_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0), Layers.TERRAIN))


func _box(size: Vector3, at: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	body.collision_layer = layer
	return body


func test_a_shy_pony_notices_from_further_off() -> void:
	assert_eq(PonyScript.notice_radius_for(PonyDataScript.Personality.SHY, false), 16.5)
	assert_gte(PonyScript.DETECTION_AREA_RADIUS, 16.5, "the broad phase still sees that far")


func test_a_fleeing_pony_bends_round_a_prop_in_her_way() -> void:
	# A wide crate 3 m straight ahead of her flight. Running straight she meets it and is
	# pinned; bending, she gets past it.
	_world.add_child(_box(Vector3(3.0, 2.0, 0.6), Vector3(0, 1.0, -3.0), Layers.PROPS))
	var data: PonyData = TEMPLATE.duplicate()
	data.personality = PonyDataScript.Personality.SHY
	data.base_speed = 3.0
	var pony: CharacterBody3D = PonyScene.instantiate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	pony.set_rng(rng)
	_world.add_child(pony)
	pony.setup(data)
	pony.set("race", &"earth")
	pony.set("roam_radius", 40.0)
	# As the spawner sets a wild pony up (world/spawner.gd).
	pony.collision_layer = Layers.PONY
	pony.collision_mask = Layers.PONY_WALKABLE
	var detection: Area3D = pony.get_node(^"DetectionArea")
	detection.collision_layer = Layers.INTERACTION
	detection.collision_mask = Layers.PLAYER
	var player := Watcher.new()
	player.add_to_group(PonyScript.PLAYER_GROUP)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.3
	shape.shape = capsule
	shape.position = Vector3(0, 0.65, 0)
	player.add_child(shape)
	player.collision_layer = Layers.PLAYER
	player.position = Vector3(0, 0, 5.0)
	_world.add_child(player)
	var furthest := 0.0
	for f in 300:
		await wait_physics_frames(1)
		furthest = minf(furthest, pony.global_position.z)
	assert_lt(furthest, -4.5, "she got past the crate (furthest z %.2f, now at %s)" % [
		furthest, str(pony.global_position.snapped(Vector3.ONE * 0.01))])
