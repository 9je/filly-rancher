extends GutTest
## THE COLLECTOR'S WALK BY (PS8, playtest 2026-11-05 items 56a and 56b: "The coat stallion:
## the dialogue says coat but there's no coat on the model"; "should be a mysterious walk-by,
## not a slow shuffle up to you"). He wears the grey coat and carries the clipboard, nothing
## narrates him, he walks at a brisk pace, never comes within 6 m of where the player stands,
## and is gone afterward.

const RanchScene := preload("res://world/ranch.tscn")
const AccessoriesScript := preload("res://systems/accessories.gd")

const NARRATION := ["stranger", "clipboard", "coat", "writes", "pens", "Collector"]


func after_each() -> void:
	Engine.time_scale = 1.0


func _collector(ranch: Node) -> Node:
	for c in ranch.get_children():
		if c is Npc and c.def != null and String(c.def.id) == "collector_visit":
			return c
	return null


func test_he_wears_his_coat_walks_by_unannounced_and_goes() -> void:
	var ranch = RanchScene.instantiate()
	add_child_autofree(ranch)
	# The ranch's own start-up checks probe the camera over its first frames, in real time;
	# the walk is sped up only after they are done.
	await wait_frames(240)
	var hud: Node = ranch.get_node(^"HUD")
	var player: Node3D = ranch.get("player")
	ranch.get("happenings").call("_collector_visit")
	await wait_frames(2)
	var n := _collector(ranch)
	assert_not_null(n, "he comes")
	if n == null:
		return
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	for id in ["collector_coat", "clipboard"]:
		assert_not_null(sk.get_node_or_null(NodePath("Kit_" + id)), "he has his %s" % id)
	assert_gte(float(n.get("walk_speed")), 1.6, "a brisk walk, not a shuffle")
	Engine.time_scale = 6.0
	var nearest := INF
	var gone := false
	for f in 1800:
		await wait_frames(1)
		# What is on screen and what is queued behind it.
		var said := String(hud.call("toast_text")) + " " + " ".join(hud.get("_toast_queue") as Array)
		for w: String in NARRATION:
			assert_false(said.containsn(w), "nothing narrates him: '%s'" % said)
		if not is_instance_valid(n):
			gone = true
			break
		nearest = minf(nearest, (n as Node3D).global_position.distance_to(player.global_position))
	assert_true(gone, "and he walks out of the scene")
	assert_gt(nearest, 6.0, "he passes by, he does not come up to her")
