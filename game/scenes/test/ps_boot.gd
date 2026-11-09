extends RefCounted
## The PS evidence probes' shared start (ps_spike_shot, ps_toast_shot, ps_bounce_shot,
## ps_hay_shot): a new game booted as the player boots it, the creator confirmed, the welcome
## letter closed by its own button, the tree unpaused, xvfb's mouse pushed to a corner; and
## Marigold's welcome talked through line by line when asked.
const BootIntentScript := preload("res://world/boot_intent.gd")


## `n` frames, and never less than `n` frames took on the software renderer these probes were
## written for (about six a second). On the GPU sixty frames pass in a second, so a strip
## timed in frames caught a cinematic's flash at its peak and cameras mid-move (Fable round 4,
## the first GPU showcase); this keeps every probe's moments where they were authored.
const AUTHORED_FPS := 6.0


static func frames(tree: SceneTree, n: int) -> void:
	var until := Time.get_ticks_msec() + int(float(n) / AUTHORED_FPS * 1000.0)
	for i in n:
		await tree.process_frame
	while Time.get_ticks_msec() < until:
		await tree.process_frame


static func shot(tree: SceneTree, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


static func mouse_to_corner() -> void:
	var m := InputEventMouseMotion.new()
	m.position = Vector2(4, 4)
	m.global_position = Vector2(4, 4)
	Input.parse_input_event(m)
	Input.warp_mouse(Vector2(4, 4))


static func boot(tree: SceneTree) -> Node:
	tree.root.get_window().size = Vector2i(1600, 900)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	tree.change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await tree.process_frame
		ranch = tree.current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	await frames(tree, 120)
	mouse_to_corner()
	# A probe looks at the world, not at the new game's valley flyover (idea F1), which would
	# take the camera and freeze her.
	var story: Object = ranch.call("get_story")
	if story != null:
		story.call("set_flag", "arrival_flyover")
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	for i in 90:
		await tree.process_frame
		var lp: Node = ranch.get("letter_panel")
		if lp != null and lp.get("visible") and lp.has_method("close_button_node"):
			(lp.call("close_button_node") as Button).pressed.emit()
			print("LETTER closed by its button")
			break
	tree.paused = false
	mouse_to_corner()
	return ranch


static func talk_through(tree: SceneTree, ranch: Node) -> void:
	var people: Node = ranch.get("people")
	for i in 400:
		if bool(people.call("is_talking")):
			print("TALK opened after %.1f s" % (i * 0.1))
			break
		await frames(tree, 6)
	var talks := 0
	var idle := 0.0
	while idle < 6.0 and talks < 6:
		if bool(people.call("is_talking")):
			talks += 1
			idle = 0.0
			var runner: Object = people.get("runner")
			var lines := 0
			while bool(people.call("is_talking")) and lines < 60:
				var cur: Dictionary = runner.call("current")
				print("TALK ", cur.get("who", ""), ": ", String(cur.get("text", "")).left(120))
				await frames(tree, 20)
				if bool(runner.call("has_choices")):
					people.call("_on_chose", 0)
				else:
					people.call("_on_advanced")
				lines += 1
			await frames(tree, 10)
		else:
			await frames(tree, 6)
			idle += 0.1
	print("TALKS ", talks, " has_scoop ", ranch.call("get_story").call("has_flag", "has_scoop"))
