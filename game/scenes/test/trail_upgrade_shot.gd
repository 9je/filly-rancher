extends SceneTree
## The guide trail at the owner's spot for playtest 2026-11-05 item 53 [45]: every plot a
## Grand Pen (Slot1's Paddock upgraded twice), every pen full, the story on the Bloom step
## at 0/2, one Drifter penned in Slot3. The lessons are paid, the mail read and nobody shows
## news, so the guide follows the story as it did for him. Three shots: 8 m past the first
## pen facing the Drifter's pen, and two looking down over all four pens.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/trail_upgrade_shot.gd -- --out=/abs/dir [--night]
const BootIntentScript := preload("res://world/boot_intent.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const RequestBoardScript := preload("res://systems/request_board.gd")
const NAMED: Array[StringName] = [&"twilight", &"rarity", &"fluttershy", &"octavia",
	&"bonbon", &"lotusblossom", &"soarin", &"milkyway", &"carrottop", &"berrypunch",
	&"vinylscratch", &"rainbowdash", &"cocopommel", &"scootaloo", &"sweetiebelle"]
var out := ""
var night := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--night":
			night = true
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and bool(ranch.get("boot_done")) and i > 30:
			break
	for i in 60:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	var away := InputEventMouseMotion.new()
	away.position = Vector2(2, 2)
	away.global_position = Vector2(2, 2)
	root.push_input(away)

	var story: Story = ranch.call("get_story")
	for f in ["has_scoop", "met_fennel", "depot_explained", "met_pip", "met_bramble"]:
		story.set_flag(f)
	story.deliveries = 6
	for m: Dictionary in story.mail:
		m["read"] = true
	var board = ranch.get("_board")
	if board != null:
		for r: Dictionary in board.get("_requests"):
			if String(r.get("id", "")) in RequestBoardScript.TUTORIAL_IDS:
				r["done"] = true
				r["paid"] = true

	var catalogue: PlotRegistry = ranch.call("_plots_catalogue")
	var slots: Array[PlotSlot] = ranch.call("plot_slots")
	for i in slots.size():
		var slot := slots[i]
		if slot.is_overgrown():
			slot.set_overgrown(false)
		if i == 0:
			slot.build(catalogue.by_id(&"pen_small"))
			slot.upgrade(catalogue.by_id(&"pen_large"))
			slot.upgrade(catalogue.by_id(&"pen_grand"))
		else:
			slot.build(catalogue.by_id(&"pen_grand"))
		var pen := slot.get_built() as Pen
		if i == 2:
			var d := PonyInstanceScript.create(&"stock_curious")
			d.stock = GeneratorScript.generate(4102).to_dict()
			pen.add_pony(d)
		var n := 0
		while not pen.is_full():
			pen.add_pony(PonyInstanceScript.create(NAMED[(i * 5 + n) % NAMED.size()]))
			n += 1
	if night:
		ranch.call("advance_world", 120.0 + 540.0 + 120.0 + 30.0)

	var player: Node3D = ranch.get("player")
	var rig: Node = ranch.find_child("CameraRig", true, false)
	var first: Vector3 = slots[0].global_position
	var drifter_pen: Vector3 = slots[2].global_position
	var k := 0
	var along := (first - drifter_pen)
	along.y = 0.0
	along = along.normalized() if along.length() > 0.1 else Vector3.BACK
	var side := along.cross(Vector3.UP)
	var middle := (first + drifter_pen) * 0.5
	# 8 m past the first pen (the owner's "8 m"), then off to the side of the row.
	# [stand, look at, pitch (deg, negative looks down), zoom out (m)]
	var poses: Array = [[first + along * 8.0, drifter_pen, 0.0, 0.0],
		[first + along * 9.0 + side * 9.0, middle, -50.0, 7.0],
		[first + along * 9.0 - side * 9.0, middle, -50.0, 7.0]]
	for pose: Array in poses:
		var at: Vector3 = pose[0]
		var aim: Vector3 = pose[1]
		at.y = float(ranch.get("terrain").call("height_at", at.x, at.z)) + 0.2
		player.global_position = at
		var to: Vector3 = aim - at
		var yaw := atan2(-to.x, -to.z)  # the rig looks down its -Z
		player.call("face", yaw)
		rig.call("reset_look", yaw)
		rig.call("add_zoom_delta", float(pose[3]))
		if float(pose[2]) != 0.0:
			rig.call("add_look_delta", 0.0, deg_to_rad(-float(pose[2]) - float(rig.call("get_look_pitch_degrees"))))
		for i in 150:
			_hush_news(ranch)
			await process_frame
		root.get_texture().get_image().save_png(out.path_join("trail_%d_%s.png" % [k,
			["past_first_pen", "over_the_pens", "over_the_pens_other_side"][k]]))
		rig.call("add_zoom_delta", -float(pose[3]))
		print("TRAIL player at %s, Slot1 at %s, Slot3 at %s" % [player.global_position, first, drifter_pen])
		var goal: Node3D = ranch.call("guide_target")
		var card: Node = ranch.get_node_or_null(^"HUD/ObjectiveCard")
		var trail: Node = ranch.get("_guide_trail")
		print("TRAIL shot %d goal=%s (Slot1 is the old Paddock) card=%s motes=%d" % [k,
			goal.name if goal != null else "none", ranch.call("current_objective").get("words", ""),
			(trail.call("mote_positions") as Array).size() if trail != null else -1])
		k += 1
	# From above, with a free lens: all four pens, the player 8 m past the first, the trail.
	var at: Vector3 = first + along * 8.0
	at.y = float(ranch.get("terrain").call("height_at", at.x, at.z)) + 0.2
	player.global_position = at
	var eye := Camera3D.new()
	ranch.add_child(eye)
	eye.global_position = middle + Vector3(0.0, 24.0, 0.0) + side * 12.0 + along * 4.0
	eye.look_at(middle + along * 4.0, Vector3.UP)
	eye.current = true
	for i in 90:
		_hush_news(ranch)
		await process_frame
	root.get_texture().get_image().save_png(out.path_join("trail_3_from_above.png"))
	print("TRAIL from above: the Drifter is in Slot3 at %s; goal=%s" % [drifter_pen,
		(ranch.call("guide_target") as Node3D).name])
	quit()


func _hush_news(ranch: Node) -> void:
	var people: Node = ranch.get("people")
	if people == null:
		return
	var news: Dictionary = people.get("_news")
	for m in news.values():
		if m != null and is_instance_valid(m):
			m.visible = false
	news.clear()
