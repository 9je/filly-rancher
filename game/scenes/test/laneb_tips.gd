extends SceneTree
## P9 W3 item 33: tips as cards. The player walks to Spike and presses E (an Escape Artist in
## a Paddock makes it his first tip), asks again for a general tip, and the Drifter term's
## first-time explainer is raised the way the objective card raises it.
##   -s res://scenes/test/laneb_tips.gd -- --out=<dir>
const Boot := preload("res://scenes/test/laneb_boot.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	var pens: Array = Boot.pens(ranch)
	for p: Pen in pens:
		if p.capacity <= 3:
			for inst in p.ponies():
				p.remove_pony(inst.uid)
			p.add_pony(PonyInstanceScript.create(&"scootaloo"))
			break
	print("STATE ", ranch.call("spike_state"))
	var spike: Node3D = ranch.get("spike")
	# On Spike's far side from the mailbox, so E is his and not the post's.
	var box: Node3D = ranch.get_node(^"Buildings/Mailbox")
	var away: Vector3 = spike.global_position - box.global_position
	away.y = 0.0
	Boot.stand(ranch, spike.global_position + away.normalized() * 1.6, spike.global_position)
	# Let the boot's own toasts finish first, so the tip is the card on screen.
	for i in 900:
		await process_frame
		if float(ranch.get_node("HUD").get("_toast_left")) <= 0.0 and (ranch.get_node("HUD").get("_toast_queue") as Array).is_empty():
			break
	for i in 20:
		await process_frame
	print("PROMPT ", ranch.get_node("HUD").call("prompt_text"))
	await Boot.press(self, &"interact")
	await Boot.shot(self, out.path_join("tip_spike_escapee.png"), 30)
	print("TOAST ", ranch.get_node("HUD").call("toast_text"))
	for i in 420:
		await process_frame
	var story: Story = ranch.call("get_story")
	story.flags.erase("explained_drifter")
	ranch.call("_explain_once", "Catch and pen a Drifter 0/2")
	await Boot.shot(self, out.path_join("tip_drifter.png"), 30)
	print("TOAST ", ranch.get_node("HUD").call("toast_text"))
	print("LANEB_TIPS_OK")
	quit(0)
