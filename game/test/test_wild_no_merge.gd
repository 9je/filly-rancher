extends GutTest
## PONIES DO NOT MERGE (playtest 2026-11-05 item 17b: "ponies merge into each other (wild vs
## wild, a brown pony inside a purple one)" [19][54]). Ten wild ponies in one clearing with the
## player walking through them for a minute: no two bodies, as DRAWN, go into each other.
##
## Judged by the bodies as drawn, not by BodySpace's own footprint (that would test the model
## against itself): the Mane Six measure 0.88 m from their middle to the nose and 0.41 to 0.44
## m from the centre line to the widest of the head (PS1 item 17b, mesh vertices along their
## facing), the PonySFM cast less; a barrel is about 0.3 across from its middle. A drawn body
## here is 0.36 round (between barrel and head) and 0.86 to the nose.

const PonyScene := preload("res://actors/pony/pony.tscn")
const DRAWN_HALF := 0.5
const DRAWN_RADIUS := 0.36
## Deeper than this for LASTING checks running (a quarter second apart), two bodies have merged:
## the owner's "a brown pony inside a purple one" is a state that lasts, not a head brushing past
## another as she turns (a turn swings the nose over a metre, and the push undoes it in a frame
## or two). No overlap at all, however brief, may reach DEEP.
const MERGED := 0.15
const LASTING := 3
const DEEP := 0.2
const TEN := [&"twilight", &"rarity", &"applejack", &"fluttershy", &"lyra", &"bonbon",
	&"derpyhooves", &"octavia", &"minuette", &"carrottop"]


class Walker:
	extends CharacterBody3D
	func is_sneaking() -> bool:
		return false


func _drawn(p: Node3D) -> Dictionary:
	var fp := BodySpace.footprint_of(p)
	if fp.is_empty():
		return fp
	fp.half = DRAWN_HALF
	fp.radius = DRAWN_RADIUS
	return fp


func test_ten_wild_ponies_never_go_into_each_other() -> void:
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor.add_child(shape)
	floor.collision_layer = 0xFFFF
	add_child_autofree(floor)
	var reg: PonyRegistry = GameState.get_registry()
	var ponies: Array[Node3D] = []
	for i in TEN.size():
		var p: Node3D = PonyScene.instantiate()
		p.position = Vector3((i % 5) * 1.6 - 3.2, 0.1, (i / 5) * 1.8 - 0.9)
		add_child_autofree(p)
		p.call("setup", reg.by_id(TEN[i]))
		ponies.append(p)
	var walker := Walker.new()
	walker.add_to_group(&"player")
	walker.collision_layer = preload("res://world/collision_layers.gd").PLAYER
	var cap := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.3
	cap.shape = capsule
	cap.position = Vector3(0, 0.65, 0)
	walker.add_child(cap)
	add_child_autofree(walker)
	walker.global_position = Vector3(-12, 0, 0)
	var worst := 0.0
	var who := ""
	var streak := {}
	var merged := []
	for f in 3600:
		# The player strolls through the clearing and back.
		walker.global_position.x = -12.0 + 24.0 * pingpong(f / 1200.0, 1.0)
		await wait_physics_frames(1)
		if f < 120 or f % 15 != 0:
			continue
		var now := {}
		for i in ponies.size():
			var a := _drawn(ponies[i])
			for j in range(i + 1, ponies.size()):
				var o := BodySpace.overlap(a, _drawn(ponies[j]))
				if o > MERGED:
					var key := "%s and %s" % [TEN[i], TEN[j]]
					now[key] = int(streak.get(key, 0)) + 1
					if int(now[key]) == LASTING:
						merged.append("%s at %.1f s" % [key, f / 60.0])
				if o > worst:
					worst = o
					who = "%s (state %d, %.2f m/s) and %s (state %d, %.2f m/s) at %.1f s, player %.1f m away" % [TEN[i], ponies[i].state, ponies[i].velocity.length(), TEN[j], ponies[j].state, ponies[j].velocity.length(), f / 60.0, ponies[i].global_position.distance_to(walker.global_position)]
		streak = now
	assert_eq(merged, [], "bodies inside each other for %d checks running" % LASTING)
	assert_lt(worst, DEEP, "the deepest momentary overlap: %.2f m (%s)" % [worst, who])
