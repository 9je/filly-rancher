extends SceneTree
## P8 S10: THE LOADING SCREEN'S KEY ART, captured from the game itself (ui/loading_screen.gd ART).
## A new game, the HUD hidden, the valley at the end of the day (DUSK, early, so the sun is still
## up and low and warm), from a lens on the rise above the plaza looking over the town to the
## hills, a few of the herd in the near field. Writes the 1920x1080 PNG to --out.
##
## THE TITLE HAS A HERO (Fable AAA round 6: "the ponies are 40-60 px dots"): with --hero=<pony
## id> she stands in the near grass at the right third of the frame, a third of its height,
## turned three quarters to the lens with the town behind her; the menu has the left.
##   xvfb-run ... godot --display-driver x11 --path game -s res://scenes/test/key_art_shot.gd -- --out=/abs/loading_ranch.png [--from=x,y,z --at=x,y,z] [--eye=m]
##     [--hero=fluttershy --hero_at=fwd,side --hero_turn=deg]
const Boot := preload("res://scenes/test/ps_boot.gd")
const WorldStateScript := preload("res://systems/world_state.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
var out := ""
var from := Vector3(-34.0, 16.0, 46.0)
var at := Vector3(2.0, 2.0, -12.0)
var hero := ""
## Where she stands from the lens: metres ahead along its view, metres to its right.
var hero_at := Vector2(4.6, 1.5)
## How far she is turned from facing the lens, degrees (positive: her head to frame left).
var hero_turn := 35.0
## With --eye=<metres>, the lens stands that high over the ground at --from's x and z.
var eye := -1.0


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
		elif a.begins_with("--hero="):
			hero = a.substr(7)
		elif a.begins_with("--hero_at="):
			var h := a.substr(10).split(",")
			hero_at = Vector2(float(h[0]), float(h[1]))
		elif a.begins_with("--hero_turn="):
			hero_turn = float(a.substr(12))
		elif a.begins_with("--eye="):
			eye = float(a.substr(6))
	_run.call_deferred()


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	await Boot.frames(self, 60)
	var w: Object = ranch.get("_world")
	# The end of the day: DUSK, its warm low sun and long shadows (the rig owns the sun, so the
	# phase is what is pinned, not the light).
	w.call("pin", WorldStateScript.Phase.DUSK, WorldStateScript.Weather.CLEAR)
	var sky: Node = ranch.get("sky_rig")
	sky.call("apply_immediately", w)
	var player: Node3D = ranch.get("player")
	player.visible = false
	# THE PICTURE IS 1920 x 1080 WHATEVER THE WINDOW IS: a headless compositor's output is
	# fixed (resizing the window past it is a protocol error), so the lens looks at the ranch's
	# own world through a viewport of the art's size.
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.world_3d = root.world_3d
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	if eye >= 0.0:
		from.y = float(ranch.get("terrain").call("surface_height_at", from.x, from.z)) + eye
	cam.global_position = from
	cam.look_at(at)
	cam.current = true
	if not hero.is_empty():
		_stand_hero(ranch, cam)
	await Boot.frames(self, 60)
	# Every screen layer off at the last moment (a talk box opens after boot).
	for layer: Node in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	await Boot.frames(self, 4)
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("KEY_ART_OK ", out)
	quit(0)


## Her body, on the ground hero_at from the lens, idling, turned hero_turn from facing it.
func _stand_hero(ranch: Node, cam: Camera3D) -> void:
	var data := load("res://data/ponies/%s.tres" % hero) as PonyData
	var body: Node3D = PonyVisualsScript.build(data)
	if body == null:
		push_error("key_art_shot: no hero body for %s" % hero)
		return
	# Shaded like every pony in the valley (sky_events.gd builds its guests the same way).
	ToonStyler.style(body, &"pony", {})
	var holder := Node3D.new()
	holder.add_child(body)
	ranch.add_child(holder)
	for sim: SkeletonModifier3D in body.find_children("*", "SpringBoneSimulator3D", true, false):
		sim.active = true
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var spot := cam.global_position + fwd * hero_at.x + right * hero_at.y
	var terrain: Node = ranch.get("terrain")
	spot.y = float(terrain.call("surface_height_at", spot.x, spot.z)) if terrain != null else 0.0
	holder.global_position = spot
	# Unturned in her holder she faces along its -Z: point that at the lens, then turn her
	# hero_turn degrees so she stands three quarters on.
	var to_lens := cam.global_position - spot
	to_lens.y = 0.0
	holder.global_basis = Basis.looking_at(to_lens.normalized().rotated(Vector3.UP,
		deg_to_rad(hero_turn)), Vector3.UP)
	# The near field is hers: any of the herd or the townsfolk wandering within a few metres
	# of her or of the lens steps out of the picture.
	for n: Node in ranch.find_children("*", "CharacterBody3D", true, false):
		var b := n as Node3D
		if b == null or b == ranch.get("player"):
			continue
		var flat := Vector2(b.global_position.x, b.global_position.z)
		if flat.distance_to(Vector2(spot.x, spot.z)) < 7.0 \
				or flat.distance_to(Vector2(cam.global_position.x, cam.global_position.z)) < 9.0:
			b.visible = false
			b.process_mode = Node.PROCESS_MODE_DISABLED
	var anim := body.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH) as AnimationPlayer
	if anim != null and anim.has_animation(&"idle"):
		anim.play(&"idle")
	print("KEY_ART hero %s at %s" % [hero, spot])
