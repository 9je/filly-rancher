extends SceneTree
## Ground-level shots of the homestead from fixed eyes (playtest 2026-10-25 layout work).
## --weather=rain|storm|clear pins the sky (PT7: the rain), and --player adds three frames
## from the player's own camera.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/eye_shot.gd -- --out=/abs/dir
const BootIntentScript := preload("res://world/boot_intent.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const EYES := [
	["spawn", Vector3(2, 2.6, 13), Vector3(2, 1.5, -4)],
	["plaza_east", Vector3(-2, 2.6, -1), Vector3(18, 2.5, -3)],
	["plaza_west", Vector3(6, 2.6, -1), Vector3(-14, 2.5, -3)],
	["yard", Vector3(4, 3.0, 8), Vector3(-14, 0.5, 15)],
	["high", Vector3(14, 22, 30), Vector3(0, 0, -4)],
	["palace", Vector3(1.5, 2.6, 46), Vector3(-10, 3, 61)],
	["palace_door", Vector3(-6, 3.4, 51.5), Vector3(-10, 3.4, 58)],
	["palace_far", Vector3(2, 3.0, 30), Vector3(-10, 5, 61)],
	["barn_yard", Vector3(-2, 3.4, -6), Vector3(-17, 1.5, -19)],
	["plots", Vector3(-2, 3.6, 4), Vector3(-15, 0.5, 17)],
	["market_front", Vector3(17, 3.0, 12), Vector3(18, 2.5, -3)],
	["depot_front", Vector3(-12, 3.0, 9), Vector3(-14, 2.5, -3)],
]
var out := ""
var weather := "clear"
var from_player := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--weather="):
			weather = a.substr(10)
		elif a == "--player":
			from_player = true
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


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
	for i in 60:
		await process_frame
	var cs: Node = ranch.get("creation_screen")
	if cs != null and bool(cs.call("is_open")):
		cs.call("confirm")
	var lp: Node = ranch.get("letter_panel")
	if lp != null and bool(lp.call("is_open")):
		lp.call("close")
	paused = false
	var w: Object = ranch.get("_world")
	if w != null:
		var wx: int = {"clear": WorldStateScript.Weather.CLEAR, "rain": WorldStateScript.Weather.RAIN,
			"storm": WorldStateScript.Weather.STORM}.get(weather, WorldStateScript.Weather.CLEAR)
		w.call("pin", WorldStateScript.Phase.DAY, wx)
		var sky: Node = ranch.get("sky_rig")
		if sky != null and sky.has_method("apply_immediately"):
			sky.call("apply_immediately", w)
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 70.0
	ranch.add_child(cam)
	for e in EYES:
		cam.global_position = e[1]
		cam.look_at(e[2], Vector3.UP)
		cam.make_current()
		for i in 20:
			await process_frame
		root.get_texture().get_image().save_png(out.path_join("%s.png" % e[0]))
	if from_player:
		var pc: Camera3D = ranch.find_child("Camera3D", true, false) as Camera3D
		if pc != null:
			pc.make_current()
			var rig: Node = ranch.find_child("CameraRig", true, false)
			for k in 3:
				for i in 60:
					await process_frame
				root.get_texture().get_image().save_png(out.path_join("player_%d.png" % k))
				if rig != null:
					rig.call("add_look_delta", 2.0, 0.0)
	print("EYES_OK")
	quit()
