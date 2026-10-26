extends SceneTree
## THE SPECTRA PALACE, OUTSIDE AND IN, FOR LOOKING AT (playtest 2026-10-25: "spectra palace not
## real yet?"). Boots the ranch at noon, walks the player in through the Palace's own door
## (Ranch.enter_palace(), the same call E at the door makes), and saves one PNG per view.
## Invisible display only:
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/palace_shot.gd -- --out=/abs/dir [--views=a,b] [--night]
## Each view is a camera pose in the interior's own space (PalaceInterior.view_pose()), or
## "front" (the facade from the Strip) or "player" (the third-person camera, as she sees it).
const BootIntentScript := preload("res://world/boot_intent.gd")
const WorldStateScript := preload("res://systems/world_state.gd")

var out := ""
var views: PackedStringArray = ["front", "player", "hall", "slots", "wheel", "tables", "cage",
	"door"]
var night := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--views="):
			views = a.substr(8).split(",")
		elif a == "--night":
			night = true
	_run.call_deferred()


func _run() -> void:
	root.get_window().size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(out)
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
	# A capture is not a player waiting for the grand opening: the house is open.
	(ranch.get("_game_state").get("story") as Object).call("set_flag", "palace_open")
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("PALACE_SHOT_TIMEOUT")
		quit(1))
	var w: Object = ranch.get("_world")
	if w != null:
		w.call("pin", WorldStateScript.Phase.NIGHT if night else WorldStateScript.Phase.DAY,
			WorldStateScript.Weather.CLEAR)
		var sky: Node = ranch.get("sky_rig")
		if sky != null and sky.has_method("apply_immediately"):
			sky.call("apply_immediately", w)
	var hud := ranch.get_node_or_null(^"HUD") as CanvasLayer
	var player: Node3D = ranch.get("player")
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 400.0
	ranch.add_child(cam)
	var inside := false
	for v: String in views:
		if hud != null:
			hud.visible = v == "player"
		if v == "front":
			var palace: Node3D = ranch.get_node(^"Buildings/Palace")
			var out_dir: Vector3 = palace.global_basis.z
			var door: Vector3 = palace.global_position + out_dir * 4.5
			cam.global_position = door + out_dir * 8.0 + Vector3(2.5, 2.4, 0.0)
			cam.look_at(door + Vector3(0, 3.0, 0), Vector3.UP)
			cam.make_current()
		else:
			if not inside:
				ranch.call("enter_palace", true)
				inside = true
				for i in 20:
					await physics_frame
			var interior: Node3D = ranch.get("palace_interior")
			if v == "player":
				player.call("get_camera_pivot").get_node("CameraRig").call("get_camera").make_current()
			else:
				var pose: Array = interior.call("view_pose", StringName(v))
				cam.global_position = interior.to_global(pose[0])
				cam.look_at(interior.to_global(pose[1]), Vector3.UP)
				cam.make_current()
		for i in 40:
			await process_frame
		var file := out.path_join("palace_%s%s.png" % [v, "_night" if night else ""])
		root.get_texture().get_image().save_png(file)
		print("SHOT ", file)
	print("PALACE_SHOT_OK")
	quit()
