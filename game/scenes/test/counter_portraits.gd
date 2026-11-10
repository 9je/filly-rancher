extends SceneTree
## THE FACES BEHIND THE COUNTERS, BAKED ONCE (Fable AAA round 4: "the Depot reads as an admin
## panel"). A new game is booted, and Marigold (the Depot) and Bramble (the Market) are each
## photographed from their live bodies in a little studio of this probe's own (a warm key, a
## cool fill, a transparent ground), framed on the head bone the way the catch card frames a
## catch, then written to game/assets/ui/portraits/<id>.png for the counters to show. Rerun
## after a model change.
##   godot --display-driver wayland --path game -s res://scenes/test/counter_portraits.gd -- --out=/abs/dir
const Boot := preload("res://scenes/test/ps_boot.gd")
const CatchCardScript := preload("res://ui/catch_card.gd")
const CAST: Array[StringName] = [&"marigold", &"bramble"]
const SIZE := Vector2i(384, 384)
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


static func _studio_in(parent: Node) -> Array:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(vp)
	var stage := Node3D.new()
	vp.add_child(stage)
	var cam := Camera3D.new()
	cam.fov = 28.0
	cam.current = true
	vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, 150.0, 0.0)
	key.light_color = Color(1.0, 0.96, 0.9)
	key.light_energy = 1.0
	vp.add_child(key)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 1.0)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	vp.add_child(env)
	return [vp, stage, cam]


func _run() -> void:
	var ranch: Node = await Boot.boot(self)
	await Boot.frames(self, 30)
	var people: Node = ranch.get("people")
	var dest := ProjectSettings.globalize_path("res://assets/ui/portraits")
	DirAccess.make_dir_recursive_absolute(dest)
	var studio := _studio_in(root)
	var vp: SubViewport = studio[0]
	var stage: Node3D = studio[1]
	var cam: Camera3D = studio[2]
	for id: StringName in CAST:
		var npc: Node3D = people.call("npc", id) as Node3D
		var vis: Node3D = npc.get_node_or_null(^"Visuals") as Node3D if npc != null else null
		if vis == null or vis.get_child_count() == 0:
			print("PORTRAIT no body for ", id)
			continue
		for c in stage.get_children():
			c.queue_free()
		var copy := (vis.get_child(0) as Node3D).duplicate(0) as Node3D
		copy.transform = Transform3D.IDENTITY
		stage.add_child(copy)
		await frame_and_shoot(self, copy, cam)
		var img := vp.get_texture().get_image()
		img.save_png(dest.path_join(String(id) + ".png"))
		img.save_png(out.path_join(String(id) + ".png"))
		print("PORTRAIT ", id, " ", img.get_size())
	print("COUNTER_PORTRAITS_OK")
	quit()


## Pose `copy` (idle, eyes open), frame the camera on her head the way the catch card frames a
## catch, and wait for the picture to be drawn. Shared with scenes/test/casino_portraits.gd.
static func frame_and_shoot(tree: SceneTree, copy: Node3D, cam: Camera3D) -> void:
	for sk in copy.find_children("*", "Skeleton3D", true, false):
		(sk as Skeleton3D).reset_bone_poses()
	var anim := copy.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if anim != null and anim.has_animation(&"idle"):
		anim.play(&"idle")
		anim.seek(0.4, true)
		anim.pause()
	# Eyes open for the picture.
	for f in copy.find_children("*", "", true, false):
		if f is PonyFace:
			f.set("blink_interval", Vector2(999.0, 999.0))
			f.set("_blink_phase", -1.0)
			f.set("_blink_next", 999.0)
	for i in 3:
		await tree.process_frame
	var box := AABB()
	var first := true
	for n in copy.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = copy.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var height := box.size.y
	var head: Vector3 = CatchCardScript.head_point(copy)
	if head == Vector3.INF:
		head = Vector3(box.get_center().x, box.position.y + height * 0.72, box.position.z)
	# Which way she faces: from her body's middle to her head, on the ground plane.
	var front := head - box.get_center()
	front.y = 0.0
	front = front.normalized() if front.length() > 0.01 else Vector3(0, 0, -1)
	var side := front.cross(Vector3.UP).normalized()
	var aim := head + Vector3.UP * height * 0.09
	var from := aim + (front * 0.86 + side * 0.5 + Vector3.UP * 0.1).normalized() * height * 1.55
	cam.look_at_from_position(from, aim, Vector3.UP)
	for i in 4:
		await RenderingServer.frame_post_draw
