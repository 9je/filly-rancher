extends SceneTree
## P9 RENDER (playtest 2026-11-10 items 7, 14, 17, 85): the Rainbow Factory at its real pace,
## loaded the way the cloud-lift loads it, through the player's own camera with the HUD up.
##   <mode>_open      the first frame of the visit (the opening camera, item 7)
##   <mode>_goal      the first talk run through: the objective card, compass and floor beacon
##   lights_out_hatch (lights_out only) in the gallery: the hatch's hold goal lit
## Run: gpu weston, -s res://scenes/test/factory_guide_shot.gd -- --out=<dir> [--factory-mode=lights_out]
const FACTORY := "res://world/factory.tscn"
var out := ""
var mode := "reveal"
var choice_shot := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--factory-mode="):
			mode = a.substr(15)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(shot_name: String, frames: int = 20) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)


var pick := 0


func _talk_through(scene: Node) -> void:
	var people: Node = scene.get("people")
	var guard := 0
	while bool(people.call("is_talking")) and guard < 80:
		var runner = people.get("runner")
		if runner != null and bool(runner.call("has_choices")):
			if choice_shot:
				choice_shot = false
				await _shot(mode + "_choice", 30)
			people.get("talk_box").chose.emit(pick)
		else:
			people.get("talk_box").advanced.emit()
		guard += 1
		for i in 3:
			await process_frame


func _run() -> void:
	root.get_window().size = Vector2i(1280, 720)
	change_scene_to_file(FACTORY)
	var scene: Node = null
	var shot_cine := false
	for i in 1200:
		await process_frame
		scene = current_scene
		if scene != null and scene.get("people") != null:
			if bool(scene.get("people").call("is_talking")):
				break
		if Cinematic.is_playing() and not shot_cine:
			shot_cine = true
			await _shot(mode + "_establish", 90)
	await _shot(mode + "_open", 10)
	await _talk_through(scene)
	await _shot(mode + "_goal", 40)
	print("GOAL ", scene.get("goal"))
	if mode == "reveal":
		# ON THROUGH THE TOUR TO THE WINDOW, THE CHOICE AND THE SCOOP (items 15, 16): each wait
		# walked by setting her down where it waits, every talk run through.
		var player: Node3D = scene.get("player")
		pick = 1
		for k in 4000:
			var people: Node = scene.get("people")
			if bool(people.call("is_talking")):
				var runner = people.get("runner")
				if runner != null and bool(runner.call("has_choices")):
					choice_shot = true
				await _talk_through(scene)
			var g: Dictionary = scene.get("goal")
			if String(g.get("kind", "")) == "hold":
				player.global_position = (g["at"] as Vector3) + Vector3(-1.2, 0.3, 1.2)
				await _shot("reveal_scoop_goal", 40)
				Input.action_press(&"interact")
				for f in 260:
					await process_frame
				Input.action_release(&"interact")
				await _shot("reveal_scoop_up", 30)
				break
			if String(g.get("kind", "")) == "area":
				player.global_position = (g["at"] as Vector3) + Vector3(0, 0.3, 0)
			await process_frame
		print("GOAL ", scene.get("goal"))
	if mode == "lights_out":
		var interior: Node = scene.get("interior")
		var player: Node3D = scene.get("player")
		# THE GUARDS SEE HER (item 11): stand her in a Collector's lantern, Tumble at her heels.
		var patrols: Array = scene.get("_patrols")
		var caught := [0]
		if not patrols.is_empty():
			var pat: Node3D = patrols[0]
			pat.spotted.connect(func(_t: Node3D) -> void: caught[0] += 1)
			pat.enabled = false
			for k in 30:
				await process_frame
			var fwd: Vector3 = pat.call("forward")
			player.global_position = pat.global_position + fwd * 4.0 + Vector3(0, 0.3, 0)
			await _shot("lights_out_guard", 4)
			pat.enabled = true
			for k in 40:
				await process_frame
			print("GUARD caught=", caught[0])
		var gallery: Vector3 = interior.call("room_origin", &"gallery")
		for k in 300:
			var g: Dictionary = scene.get("goal")
			if String(g.get("kind", "")) == "hold":
				break
			if String(g.get("kind", "")) == "area":
				player.global_position = (g["at"] as Vector3) + Vector3(0, 0.3, 0)
			await process_frame
		player.global_position = gallery + Vector3(-1.0, 0.3, 0.5)
		await _shot("lights_out_hatch", 60)
		print("GOAL ", scene.get("goal"))
	print("FACTORY_SHOT_OK")
	quit(0)
