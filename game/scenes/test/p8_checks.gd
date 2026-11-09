extends SceneTree
## P8 EVIDENCE, one boot for many checks (the software renderer makes each boot cost minutes).
## Takes, in order: the creator at each race (items 38, 39), the beam held aimed low (24), a
## toast with its picture (S5), the race form guide with portraits (61), Spike close (35),
## and the player's flank with a mark close up (40). Writes <name>.png into --out.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/p8_checks.gd -- --out=/abs/dir [--only=creator,beam]
const Boot := preload("res://scenes/test/ps_boot.gd")
const BootIntentScript := preload("res://world/boot_intent.gd")
var out := ""
var only: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = Array(a.substr(7).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _want(name: String) -> bool:
	return only.is_empty() or only.has(name)


func _run() -> void:
	root.get_window().size = Vector2i(1280, 720)
	BootIntentScript.driven = true
	BootIntentScript.request_new_game()
	change_scene_to_file("res://world/ranch.tscn")
	var ranch: Node = null
	for i in 900:
		await process_frame
		ranch = current_scene
		if ranch != null and ranch.get("people") != null and i > 30:
			break
	await Boot.frames(self, 90)
	Boot.mouse_to_corner()
	ranch.call("get_story").call("set_flag", "arrival_flyover")
	var cs: Node = ranch.get("creation_screen")
	if _want("creator") and cs != null and bool(cs.call("is_open")):
		var table: Node3D = cs.get("_turntable")
		for r in 3:
			cs.call("set_race", r)
			# Three-quarter on, held there: the turntable is stopped by a "drag" pause.
			for k in 20:
				cs.set("_drag_rest", 5.0)
				if table != null:
					table.rotation.y = deg_to_rad(-35.0)
				await process_frame
			await Boot.shot(self, out, "creator_race%d" % r)
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	for i in 90:
		await process_frame
		var lp: Node = ranch.get("letter_panel")
		if lp != null and lp.get("visible") and lp.has_method("close_button_node"):
			(lp.call("close_button_node") as Button).pressed.emit()
			break
	paused = false
	await Boot.frames(self, 30)
	var player: Node3D = ranch.get("player")
	var hud: Node = ranch.get_node_or_null(^"HUD")

	if "--talk" in OS.get_cmdline_user_args():
		# Past the creator, the world as a player sees it after the welcome dialogue.
		await Boot.talk_through(self, ranch)
	if _want("toast") and hud != null:
		hud.call("toast", "Lark Wish moved into the pen. It is now full.")
		await Boot.frames(self, 12)
		await Boot.shot(self, out, "toast_pen")

	if _want("beam"):
		# A new game has no Scoop until Marigold hands it over; the check is about the beam.
		ranch.call("get_story").call("set_flag", "has_scoop")
		var beam: Node = player.call("get_magic_beam")
		var rig: Node = player.call("get_camera_pivot").get_node("CameraRig")
		var spawner: Node = ranch.get("spawner")
		var pony: Node3D = null
		var best := INF
		for p: Node3D in spawner.call("get_spawned"):
			var d := p.global_position.distance_to(player.global_position)
			if d < best and not p.is_in_group(&"penned"):
				best = d
				pony = p
		if pony != null:
			var fwd := -player.global_transform.basis.z
			fwd.y = 0.0
			pony.global_position = player.global_position + fwd.normalized() * 3.0
			rig.set("_look_pitch", -35.0)
			await Boot.frames(self, 6)
			Input.action_press(beam.get("BEAM_ACTION"))
			for i in 30:
				await physics_frame
			rig.set("_look_pitch", -60.0)
			for i in 60:
				await physics_frame
			print("BEAM held=%s gap=%.2f" % [beam.get("_held") == pony,
				pony.global_position.y - float(ranch.get("terrain").call("height_at",
				pony.global_position.x, pony.global_position.z))])
			await Boot.shot(self, out, "beam_low")
			for i in 90:
				await physics_frame
			# Item 71: the caught card, if the hold made a catch.
			await Boot.shot(self, out, "catch_card")
			Input.action_release(beam.get("BEAM_ACTION"))
			rig.set("_look_pitch", -10.0)
			await Boot.frames(self, 20)

	if _want("card"):
		# Item 71: the caught card as a real catch shows it, read off a wild named pony.
		var hud2: Node = ranch.get_node_or_null(^"HUD")
		var card: Node = hud2.get("_catch_card") if hud2 != null else null
		for p: Node3D in ranch.get("spawner").call("get_spawned"):
			var d: PonyData = p.call("get_data")
			if card != null and d != null and not String(d.id).begins_with("stock"):
				var inst = p.call("get_instance") if p.has_method("get_instance") else null
				if inst == null:
					inst = load("res://systems/pony_instance.gd").create(d.id)
				card.call("show_catch", inst, p)
				await Boot.frames(self, 50)
				await Boot.shot(self, out, "catch_card_named")
				break
	if _want("spike"):
		var spike: Node3D = ranch.get("spike")
		if spike != null:
			var cam := Camera3D.new()
			ranch.add_child(cam)
			# From the player's side of him, wherever he is facing.
			var to_player := player.global_position - spike.global_position
			to_player.y = 0.0
			to_player = to_player.normalized() if to_player.length() > 0.1 else Vector3.BACK
			cam.global_position = spike.global_position + to_player * 1.8 + Vector3(0, 0.9, 0)
			cam.look_at(spike.global_position + Vector3(0, 0.7, 0))
			cam.current = true
			await Boot.frames(self, 12)
			await Boot.shot(self, out, "spike_close")
			cam.current = false
			cam.queue_free()

	if _want("flank"):
		var vis: Node3D = player.get("visuals")
		# A mark to see where it sits (item 40): a star stamp on her own body.
		var mark: Image = MarkStamps.build(MarkStamps.Stamp.STAR, Color(0.95, 0.4, 0.7))
		CutieMark.apply(vis.get_child(0), mark)
		player.global_rotation.y = 0.0
		var cam2 := Camera3D.new()
		ranch.add_child(cam2)
		var side := vis.global_basis.x
		# Square side-on, the way the show draws a mark.
		cam2.global_position = player.global_position + side * 3.4 + Vector3(0, 1.1, 0)
		cam2.look_at(player.global_position + Vector3(0, 0.95, 0))
		cam2.current = true
		await Boot.frames(self, 12)
		await Boot.shot(self, out, "player_flank")
		cam2.current = false
		cam2.queue_free()

	if _want("race"):
		var rm: Node = ranch.get("race_menu")
		if rm != null:
			# Three wild ponies stand in as runners (a new game has nobody penned), their faces
			# baked by the game's own PortraitBaker; and chips to stake.
			var runners: Array[Dictionary] = []
			var k := 0
			for p: Node3D in ranch.get("spawner").call("get_spawned"):
				if k >= 3:
					break
				var key := "check_%d" % k
				ranch.call("_portrait_of", key, p)
				runners.append({"uid": StringName(key), "name": ["Lark Wish", "Cobble Ribbon",
					"Honey Muffin"][k], "happiness": [0.9, 0.5, 0.3][k], "odds": [3.2, 6.5, 11.4][k],
					"chance": [0.28, 0.14, 0.08][k], "body": p})
				k += 1
			await Boot.frames(self, 30)
			for r: Dictionary in runners:
				r["portrait"] = ranch.call("_portrait_of", String(r.uid), r.body)
			rm.set("entrants_provider", func() -> Array: return runners)
			rm.set("chips_provider", func() -> int: return 400)
			rm.set("can_open", func() -> bool: return true)
			paused = false
			rm.call("open")
			await Boot.frames(self, 40)
			await Boot.shot(self, out, "race_guide")
			rm.call("close")
	for menu_name: String in ["market_menu", "depot_menu"]:
		if not _want(menu_name):
			continue
		var m: Node = ranch.get(menu_name)
		if m != null and bool(m.call("open")):
			await Boot.frames(self, 30)
			await Boot.shot(self, out, menu_name)
			if m.has_method("set_tab"):
				m.call("set_tab", 1)
				await Boot.frames(self, 20)
				await Boot.shot(self, out, menu_name + "_tab2")
			m.call("close")
			paused = false
			await Boot.frames(self, 10)

	if _want("jump"):
		# Item 30: the tail on a jump and its landing, side on, a frame every few ticks.
		var cam3 := Camera3D.new()
		ranch.add_child(cam3)
		var side3: Vector3 = (player.get("visuals") as Node3D).global_basis.x
		cam3.global_position = player.global_position + side3 * 4.0 + Vector3(0, 1.3, 0)
		cam3.look_at(player.global_position + Vector3(0, 1.1, 0))
		cam3.current = true
		await Boot.frames(self, 6)
		Input.action_press(&"jump")
		await physics_frame
		Input.action_release(&"jump")
		for k in 12:
			for j in 4:
				await physics_frame
			await Boot.shot(self, out, "jump_%02d" % k)
		cam3.current = false
		cam3.queue_free()

	if _want("hall"):
		# The casino hall's crowd (item 56): from the door, looking in.
		ranch.call("get_story").call("set_flag", "palace_open")
		var entered: bool = ranch.call("enter_palace", true)
		print("HALL entered=%s" % entered)
		await Boot.frames(self, 40)
		await Boot.shot(self, out, "hall")
		ranch.call("exit_palace", true)
		await Boot.frames(self, 20)

	for ev: String in ["derpy", "rainboom"]:
		if not _want(ev):
			continue
		var sky: Node = ranch.get_node(^"SkyEvents")
		if ev == "derpy":
			sky.call("derpy_crash")
		else:
			sky.call("sonic_rainboom")
		# A strip through the scene: the software renderer draws a few frames a second, so a
		# frame count is the only clock that lands shots inside it.
		for k in 6:
			await Boot.frames(self, 8)
			await Boot.shot(self, out, "%s_%d" % [ev, k])
		while Cinematic.shared(self).playing:
			await process_frame
	print("P8_CHECKS_OK")
	quit(0)
