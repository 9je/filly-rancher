extends GutTest
## THE BOUNCE IS SEEN (PS1, playtest 2026-11-05 items 19/23: "The rump bounce is barely
## seen: it only fires on a pen flop or a hard landing, and ponies land facing you in the
## paddock"). A happy, fed pony in her pen hops for joy now and then as she idles, and every
## hop bounces her rump as she lands; a wild or a hungry one does not. (Landing side on to the
## camera after a pen flop is PT11's; the render shows both.)

const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyScript := preload("res://actors/pony/pony.gd")
const Layers := preload("res://world/collision_layers.gd")
const TEMPLATE := preload("res://data/ponies/pokeypierce.tres")


func test_only_a_happy_fed_penned_pony_hops_for_joy() -> void:
	var hops := 0
	for i in 1000:
		if PonyScript.wants_joy_hop(true, false, float(i) / 1000.0):
			hops += 1
	assert_between(hops, 20, 100, "now and then, not every time she idles: %d in 1000" % hops)
	for i in 1000:
		assert_false(PonyScript.wants_joy_hop(false, false, float(i) / 1000.0), "a wild pony does not")
		assert_false(PonyScript.wants_joy_hop(true, true, float(i) / 1000.0), "a hungry one does not")


func test_a_hop_bounces_her_rump_as_she_lands() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.collision_layer = Layers.TERRAIN
	world.add_child(floor_body)
	var pony: CharacterBody3D = PonyScene.instantiate()
	world.add_child(pony)
	pony.setup(TEMPLATE.duplicate())
	pony.collision_layer = Layers.PONY
	pony.collision_mask = Layers.PONY_WALKABLE
	await wait_physics_frames(10)
	var bounce := pony.find_children("RumpBounce", "", true, false)
	assert_false(bounce.is_empty(), "she has a rump spring")
	if bounce.is_empty():
		return
	assert_true(bool(pony.call("play_action", &"hop")), "she has a hop")
	var most := 0.0
	for i in 120:
		await wait_physics_frames(1)
		most = maxf(most, absf(float(bounce[0].call("amount"))))
	assert_gt(most, 0.02, "the hop's landing bounced her rump")
