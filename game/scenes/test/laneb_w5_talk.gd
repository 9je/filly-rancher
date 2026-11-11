extends SceneTree
## P9 items 39 and 71, round 3: real conversations on the ranch. For Marigold, Tumble and
## Fennel the player walks up square in front of her (the lens, the player and the speaker on
## one line: the "hidden behind your pony" case), the prompt is shot, E is pressed, and the
## talk is shot as it opens and after a second; then the lens is tipped so her head is high in
## the frame (the Factory offer's case). Then Spike's prompt, standing in front of him.
##   -s res://scenes/test/laneb_w5_talk.gd -- --out=<dir> [--w=2560 --h=1440]
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""
var size := Vector2i(1600, 900)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--w="):
			size.x = int(a.substr(4))
		elif a.begins_with("--h="):
			size.y = int(a.substr(4))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self, Boot.FIXTURE, size)
	var people: Node = ranch.get("people")
	var hud: Node = ranch.get_node("HUD")
	# Let the boot's toasts pass so the frames show the talk, not the news.
	for i in 600:
		await process_frame
		if float(hud.get("_toast_left")) <= 0.0 and (hud.get("_toast_queue") as Array).is_empty():
			break
	for id: StringName in [&"marigold", &"tumble", &"fennel"]:
		var n: Node3D = people.call("npc", id)
		if n == null or not n.is_visible_in_tree():
			print("NO NPC ", id)
			continue
		if n.has_method("set_mode_idle"):
			n.call("set_mode_idle")
		var fwd := -n.global_transform.basis.z
		fwd.y = 0.0
		var at := n.global_position + fwd.normalized() * 3.0
		Boot.stand(ranch, at, n.global_position)
		await _walk_in()
		print("PROMPT ", id, " ", hud.call("prompt_text"))
		await Boot.shot(self, out.path_join("%s_0prompt.png" % id), 5)
		await Boot.press(self, &"interact")
		if not bool(people.call("is_talking")):
			print("NOT TALKING ", id)
			continue
		await Boot.shot(self, out.path_join("%s_1open.png" % id), 3)
		await Boot.shot(self, out.path_join("%s_2settled.png" % id), 60)
		var rig: Node3D = ranch.get("player").get_node(^"CameraPivot/CameraRig")
		rig.call("add_look_delta", 0.0, 0.45)
		await Boot.shot(self, out.path_join("%s_3high.png" % id), 30)
		rig.call("add_look_delta", 0.0, -0.45)
		print("TALK_SHOT ", id)
		for k in 16:
			await Boot.press(self, &"interact")
			for i in 10:
				await process_frame
			if not bool(people.call("is_talking")):
				break
		for i in 30:
			await process_frame
	var spike: Node3D = ranch.get("spike")
	var box: Node3D = ranch.get_node(^"Buildings/Mailbox")
	var away: Vector3 = spike.global_position - box.global_position
	away.y = 0.0
	Boot.stand(ranch, spike.global_position + away.normalized() * 3.0, spike.global_position)
	await _walk_in()
	print("PROMPT spike ", hud.call("prompt_text"))
	await Boot.shot(self, out.path_join("spike_0prompt.png"), 5)
	# And close, the way the owner's shot had it.
	Input.action_press(&"move_forward")
	for i in 5:
		await process_frame
	Input.action_release(&"move_forward")
	await Boot.shot(self, out.path_join("spike_1close.png"), 30)
	print("PROMPT spike ", hud.call("prompt_text"))
	print("LANEB_TALK_OK")
	quit(0)


## A few real steps toward whoever she faces (so she turns her back to the lens as a player's
## pony does), then still.
func _walk_in() -> void:
	for i in 10:
		await process_frame
	Input.action_press(&"move_forward")
	for i in 9:
		await process_frame
	Input.action_release(&"move_forward")
	for i in 45:
		await process_frame
