extends SceneTree
## PS EVIDENCE, items 16 and 38 (playtest 2026-11-05): where the guide points.
## 16: a new game, the creator confirmed, the welcome letter closed by its button, Marigold's
##     welcome talked through line by line (first choice at each fork). Then whatever the
##     guide asks first is done as a player would (the mail read: the mailbox's own
##     open_mailbox_letter, the letter closed by its button; a "!" talked to), photographing
##     each step, until the guide points at a wild pony (at most ten steps). Each step: the
##     player's view as she stands, turned to the goal, and from above.
## 38: the three lessons marked done in the probe, Tumble's sighting (Happenings._sighting);
##     the same three shots.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/ps_guide_shot.gd -- --out=/abs/dir
const Boot := preload("res://scenes/test/ps_boot.gd")
var out := ""
var ranch: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _report(tag: String) -> Node3D:
	var target: Node3D = ranch.call("guide_target")
	var player: Node3D = ranch.get("player")
	var goal: StringName = ranch.get("_guide_goal")
	var who := "none"
	if target != null:
		who = String(target.name)
		if target.has_method("get_data") and target.call("get_data") != null:
			who += " (" + String((target.call("get_data") as PonyData).display_name) + ")"
	var trail: Node = ranch.get("_guide_trail")
	print("%s GUIDE goal=%s target=%s dist=%.1f m motes=%d" % [tag, goal, who,
		player.global_position.distance_to(target.global_position) if target != null else -1.0,
		(trail.call("mote_positions") as Array).size() if trail != null else -1])
	return target


func _three_shots(prefix: String, target: Node3D) -> void:
	var player: Node3D = ranch.get("player")
	var rig: Node = ranch.find_child("CameraRig", true, false)
	await Boot.shot(self, out, prefix + "_as_she_stands")
	if target == null:
		return
	var d := player.global_position - target.global_position
	var yaw := atan2(d.x, d.z)
	player.call("face", yaw)
	rig.call("reset_look", yaw)
	await Boot.frames(self, 40)
	await Boot.shot(self, out, prefix + "_turned_to_goal")
	var cam := Camera3D.new()
	cam.fov = 60.0
	ranch.add_child(cam)
	var mid := (player.global_position + target.global_position) * 0.5
	var span := maxf(12.0, Vector2(d.x, d.z).length())
	var back := Vector3(d.x, 0, d.z).normalized()
	cam.global_position = mid + back * span * 0.55 + Vector3(0, span * 0.85, 0)
	cam.look_at(mid)
	cam.make_current()
	await Boot.frames(self, 4)
	await Boot.shot(self, out, prefix + "_from_above")
	(rig.call("get_camera") as Camera3D).make_current()
	cam.queue_free()
	await Boot.frames(self, 4)


func _close_letter() -> void:
	for i in 30:
		await process_frame
		var lp: Node = ranch.get("letter_panel")
		if lp != null and lp.get("visible") and lp.has_method("close_button_node"):
			(lp.call("close_button_node") as Button).pressed.emit()
			print("LETTER closed by its button")
			return


func _run() -> void:
	ranch = await Boot.boot(self)
	await Boot.talk_through(self, ranch)
	await Boot.frames(self, 90)
	var step := 0
	var target: Node3D = null
	while step < 10:
		target = await _report("ITEM16 step %d" % step)
		await _three_shots("item16_step%d_%s" % [step, ranch.get("_guide_goal")], target)
		var goal: StringName = ranch.get("_guide_goal")
		if goal == &"catch" or target == null:
			break
		if goal == &"mail":
			print("ITEM16 step %d: reading the mail: %s" % [step, ranch.call("open_mailbox_letter")])
			await Boot.frames(self, 30)
			await Boot.shot(self, out, "item16_step%d_letter" % step)
			await _close_letter()
			ranch.get_tree().paused = false
		elif goal == &"talk" and target is Npc:
			var id := String((target as Npc).def.id)
			print("ITEM16 step %d: talking to %s: %s" % [step, id, ranch.get("people").call("talk", id)])
			await Boot.talk_through(self, ranch)
		else:
			print("ITEM16 step %d: no player action scripted for goal %s" % [step, goal])
			break
		await Boot.frames(self, 90)
		step += 1

	# --- 38: past the lessons, Tumble's sighting --------------------------------------------
	var board: Object = ranch.get("_board")
	for r: Dictionary in board.get("_requests"):
		if String(r.get("id", "")).begins_with("tutorial_"):
			r["done"] = true
			r["paid"] = true
	var happenings: Node = ranch.get("happenings")
	var ok := false
	# Its pick is one of the four least rare not yet caught; spawn_guest refuses one already
	# standing in the valley, so the game's own call is simply made again (up to ten times).
	for i in 10:
		ok = happenings.call("_sighting")
		print("ITEM38 _sighting try ", i + 1, ": ", ok)
		if ok:
			break
	var seen: Node3D = happenings.get("sighting")
	print("ITEM38 sighting pony=", (seen.call("get_data") as PonyData).display_name if seen != null else "none",
		" at ", seen.global_position if seen != null else Vector3.INF)
	await Boot.frames(self, 40)
	print("ITEM38 TOAST ", ranch.get_node("HUD").call("toast_text"))
	var t38 := await _report("ITEM38")
	print("ITEM38 trail goes to the sighting: ", t38 == seen)
	await _three_shots("item38_sighting", t38)
	print("PS_GUIDE_SHOT_OK")
	quit(0)
