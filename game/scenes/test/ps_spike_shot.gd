extends SceneTree
## PS EVIDENCE, item 35 (playtest 2026-11-05: "Spike just sits there with no clear purpose").
## A new game, Marigold's welcome talked through; she walks up to Spike at the mailbox, the
## prompt shows, E is pressed (the interact action), and his tip is on screen. Asked three
## times, each tip read out to the end before the next ask.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/ps_spike_shot.gd -- --out=/abs/dir
const Boot := preload("res://scenes/test/ps_boot.gd")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _prompt(hud: Node) -> String:
	for l: Node in hud.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text.begins_with("E:"):
			return (l as Label).text
	return ""


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	await Boot.talk_through(self, ranch)
	var player: CharacterBody3D = ranch.get("player")
	var spike: Node3D = ranch.get("spike")
	var rig: Node = ranch.find_child("CameraRig", true, false)
	var mailbox := ranch.get_node_or_null(^"Buildings/Mailbox") as Node3D
	# On Spike's far side from the mailbox, 1.3 m out, facing him, the lens behind her.
	var away := Vector3(1, 0, 0)
	if mailbox != null:
		away = spike.global_position - mailbox.global_position
		away.y = 0
		away = away.normalized()
	var at := spike.global_position + away * 1.3
	at.y = float(ranch.get("terrain").call("height_at", at.x, at.z)) + 0.1
	player.global_position = at
	player.velocity = Vector3.ZERO
	var yaw := atan2(away.x, away.z)
	player.call("face", yaw + PI)
	rig.call("reset_look", yaw + deg_to_rad(25.0))
	await Boot.frames(self, 60)
	var hud: Node = ranch.get_node("HUD")
	var cands: Array = ranch.call("interaction_candidates")
	print("ITEM35 offered: ", cands.map(func(c: Dictionary) -> String: return str(c.get("kind"))))
	await Boot.shot(self, out, "item35_prompt")
	for ask in 3:
		# A talk that opened in between (Tumble at her heel) is talked through first, and she
		# is stood by Spike again: the shot shows the prompt she pressed E on.
		if bool(ranch.get("people").call("is_talking")):
			print("ITEM35 a talk opened before ask %d; talked through" % (ask + 1))
			await Boot.talk_through(self, ranch)
		player.global_position = at
		player.velocity = Vector3.ZERO
		player.call("face", yaw + PI)
		await Boot.frames(self, 20)
		var c2: Array = ranch.call("interaction_candidates")
		print("ITEM35 before ask %d offered: %s, prompt '%s'" % [ask + 1,
			c2.map(func(c: Dictionary) -> String: return str(c.get("kind"))), _prompt(hud)])
		Input.action_press(&"interact")
		await Boot.frames(self, 2)
		Input.action_release(&"interact")
		await Boot.frames(self, 30)
		print("ITEM35 ask %d TOAST: %s" % [ask + 1, hud.call("toast_text")])
		print("ITEM35 ask %d queued: %s, Spike asked %s times, talking %s" % [ask + 1, hud.call("pending_toasts"), ranch.get("_spike_asks"), ranch.get("people").call("is_talking")])
		await Boot.shot(self, out, "item35_ask_%d" % (ask + 1))
		# Read to the end before asking again.
		for i in 900:
			if float(hud.call("toast_seconds_left")) <= 0.0 and (hud.call("pending_toasts") as Array).is_empty():
				break
			await process_frame
		await Boot.frames(self, 40)
	print("PS_SPIKE_SHOT_OK")
	quit(0)
