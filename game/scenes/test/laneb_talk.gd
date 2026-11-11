extends SceneTree
## P9 W3 item 39: talking to a townspony, the box placed on screen and clear of the objective
## banner. The player walks up to each of the first NPCs, looks at her and presses E; then the
## camera is swung so the speaker stands at the screen's left edge, and again so her head is
## high in the frame.
##   -s res://scenes/test/laneb_talk.gd -- --out=<dir>
const Boot := preload("res://scenes/test/laneb_boot.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var people: Node = ranch.get("people")
	var ids: Array = (people.get("npcs") as Dictionary).keys()
	print("NPCS ", ids)
	var shots := 0
	for id in ids:
		if shots >= 2:
			break
		var n: Node3D = people.call("npc", id)
		if n == null or not n.is_visible_in_tree():
			continue
		var fwd := -n.global_transform.basis.z
		fwd.y = 0.0
		var at := n.global_position + fwd.normalized() * 2.4
		Boot.stand(ranch, at, n.global_position)
		for i in 30:
			await process_frame
		print("PROMPT ", id, " ", ranch.get_node("HUD").call("prompt_text"))
		await Boot.press(self, &"interact")
		for i in 40:
			await process_frame
		if not bool(people.call("is_talking")):
			print("NOT TALKING ", id)
			continue
		await Boot.shot(self, out.path_join("talk_%s.png" % id), 5)
		# Swing the lens so she stands at the left edge, then low so her head is high.
		var rig: Node3D = ranch.get("player").get_node(^"CameraPivot/CameraRig")
		rig.call("add_look_delta", -0.75, 0.0)
		await Boot.shot(self, out.path_join("talk_%s_left.png" % id), 20)
		rig.call("add_look_delta", 0.75, -0.5)
		await Boot.shot(self, out.path_join("talk_%s_high.png" % id), 20)
		print("TALK_SHOT ", id)
		shots += 1
		for k in 12:
			await Boot.press(self, &"interact")
			for i in 10:
				await process_frame
			if not bool(people.call("is_talking")):
				break
	print("LANEB_TALK_OK")
	quit(0)
