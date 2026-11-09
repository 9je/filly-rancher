extends SceneTree
## P8 S10: THE LOADING SCREEN'S KEY ART, captured from the game itself (ui/loading_screen.gd ART).
## A new game, the HUD hidden, the valley at the end of the day (DUSK, early, so the sun is still
## up and low and warm), from a lens on the rise above the plaza looking over the town to the
## hills, a few of the herd in the near field. Writes the 1920x1080 PNG to --out.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/key_art_shot.gd -- --out=/abs/loading_ranch.png [--from=x,y,z --at=x,y,z]
const Boot := preload("res://scenes/test/ps_boot.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
var out := ""
var from := Vector3(-34.0, 16.0, 46.0)
var at := Vector3(2.0, 2.0, -12.0)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--from="):
			var p := a.substr(7).split(",")
			from = Vector3(float(p[0]), float(p[1]), float(p[2]))
		elif a.begins_with("--at="):
			var q := a.substr(5).split(",")
			at = Vector3(float(q[0]), float(q[1]), float(q[2]))
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	root.get_window().size = Vector2i(1920, 1080)
	await Boot.frames(self, 60)
	var w: Object = ranch.get("_world")
	# The end of the day: DUSK, its warm low sun and long shadows (the rig owns the sun, so the
	# phase is what is pinned, not the light).
	w.call("pin", WorldStateScript.Phase.DUSK, WorldStateScript.Weather.CLEAR)
	var sky: Node = ranch.get("sky_rig")
	sky.call("apply_immediately", w)
	var player: Node3D = ranch.get("player")
	player.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	ranch.add_child(cam)
	cam.global_position = from
	cam.look_at(at)
	cam.current = true
	await Boot.frames(self, 60)
	# Every screen layer off at the last moment (a talk box opens after boot).
	for layer: Node in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await Boot.frames(self, 4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("KEY_ART_OK ", out)
	quit(0)
