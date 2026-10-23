extends Node3D
## THE SHOT STAGE: renders the frames a person reviews against GDD.md section 8, without
## booting the whole ranch. Run windowed (xvfb in automation), never headless: the headless
## dummy renderer draws nothing and skips the toon swap.
##
##   xvfb-run -a tools/bin/godot --path game --audio-driver Dummy scenes/test/shots.tscn \
##       -- --out=<dir> [--set=lineup,face,dread] [--seed=1]
##
## Sets:
##   lineup  a grid of generated ponies (races, foals, rare variants, a few Bloomed)
##   face    one pony close up, neutral then with PonyFace lids, ears and jaw driven hard,
##           so the face rig's axes can be checked by eye
##   dread   the same small herd at dread 0, 0.3, 0.8 and the free grade
## Prints SHOTS_OK <count> after the last file is written, SHOTS_FAILED otherwise.

const PonyScene := preload("res://actors/pony/pony.tscn")
const StockShy := preload("res://data/hidden/stock_shy.tres")
const GeneratorScript := preload("res://systems/pony_generator.gd")
const WorldToneScript := preload("res://world/world_tone.gd")
const PonyFaceScript := preload("res://actors/pony/pony_face.gd")
const ToonStylerScript := preload("res://systems/toon_styler.gd")

var _out := "user://shots"
var _sets: PackedStringArray = ["lineup", "face", "dread"]
var _seed := 1
var _written := 0
var _cam: Camera3D
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _tone: WorldTone
var _ponies: Array[Node] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--set="):
			_sets = arg.substr(6).split(",")
		elif arg.begins_with("--seed="):
			_seed = int(arg.substr(7))
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1600, 900)
	_build_stage()
	await _run()
	print("SHOTS_OK %d" % _written)
	get_tree().quit(0)


func _build_stage() -> void:
	_env = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.56, 0.83, 1.0)
	mat.sky_horizon_color = Color(0.9, 0.96, 1.0)
	mat.ground_horizon_color = Color(0.72, 0.84, 0.66)
	mat.ground_bottom_color = Color(0.4, 0.6, 0.35)
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_density = 0.002
	_env.environment = env
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, 35, 0)
	_sun.light_color = Color(1.0, 0.96, 0.88)
	_sun.light_energy = 1.25
	_sun.shadow_enabled = true
	add_child(_sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.49, 0.8, 0.36)
	ground.material_override = gm
	add_child(ground)
	ToonStylerScript.style(ground, &"flat", {})
	_cam = Camera3D.new()
	_cam.fov = 40
	add_child(_cam)
	_tone = WorldToneScript.new()
	add_child(_tone)
	_tone._env = env


func _run() -> void:
	for s in _sets:
		match s:
			"lineup":
				await _lineup()
			"face":
				await _face()
			"dread":
				await _dread()
			"rigprobe":
				await _rigprobe()
			"cast":
				await _cast()
			"factory":
				await _factory()


func _clear() -> void:
	for p in _ponies:
		p.queue_free()
	_ponies.clear()
	await get_tree().process_frame


func _stand(look: PonyLook, at: Vector3, yaw: float) -> Node:
	var p: CharacterBody3D = PonyScene.instantiate()
	p.position = at
	add_child(p)
	p.set_stock(look.to_dict())
	p.setup(StockShy)
	p.set_physics_process(false)
	p.rotation.y = yaw
	_ponies.append(p)
	return p


func _shoot(name: String) -> void:
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join(name + ".png")
	if img.save_png(path) == OK:
		_written += 1
		print("SHOT ", path)
	else:
		push_error("shots: could not write %s" % path)


func _lineup() -> void:
	await _clear()
	var cols := 6
	var i := 0
	for row in range(3):
		for col in range(cols):
			var opts := {}
			if i % 7 == 3:
				opts["foal"] = true
			if i == 5:
				opts["variant"] = &"pearl"
			if i == 11:
				opts["variant"] = &"starry"
			if i == 16:
				opts["variant"] = &"ember"
			if i % 4 == 1:
				opts["marked"] = true
			var look := GeneratorScript.generate(_seed * 1000 + i, opts)
			_stand(look, Vector3((col - (cols - 1) * 0.5) * 2.6, 0, row * 3.2), deg_to_rad(90 + (i % 3 - 1) * 20))
			i += 1
	_cam.position = Vector3(0, 4.2, 16.5)
	_cam.look_at(Vector3(0, 0.9, 3.2))
	await _shoot("lineup")


func _face() -> void:
	await _clear()
	var look := GeneratorScript.generate(_seed * 77, {"race": &"unicorn", "marked": true})
	var p := _stand(look, Vector3.ZERO, deg_to_rad(90))
	# A yaw of 90 degrees faces the donor down -X; frame her face from the front quarter.
	_cam.position = Vector3(-3.4, 1.8, 1.7)
	_cam.look_at(Vector3(-1.0, 1.55, 0.0))
	await _shoot("face_neutral")
	var sk: Skeleton3D = p.find_children("*", "Skeleton3D", true, false)[0] if not p.find_children("*", "Skeleton3D", true, false).is_empty() else null
	if sk == null:
		return
	var face: PonyFace = PonyFaceScript.new()
	sk.add_child(face)
	face.blink_interval = Vector2(999, 999)
	face.mood = PonyFace.Mood.SAD
	face.talk_amount = 1.0
	face.talking = true
	for i in range(40):
		await get_tree().process_frame
	await _shoot("face_sad_talk")
	face.mood = PonyFace.Mood.SCARED
	face.talk_amount = 0.0
	face._blink_phase = 0.5
	await _shoot("face_scared_blink")
	# Straight on, so both eyes and both ears are in frame.
	_cam.position = Vector3(-3.6, 1.7, 0.0)
	_cam.look_at(Vector3(0.0, 1.55, 0.0))
	face.eyes_closed = true
	await _shoot("face_front_blink")
	face.eyes_closed = false
	face.mood = PonyFace.Mood.NEUTRAL
	face._blink_phase = -1.0
	for i in range(60):
		await get_tree().process_frame
	await _shoot("face_front_neutral")


func _dread() -> void:
	await _clear()
	for i in range(5):
		_stand(GeneratorScript.generate(_seed * 31 + i, {"marked": i % 2 == 0}),
			Vector3((i - 2) * 2.4, 0, 0), deg_to_rad(90 + (i - 2) * 15))
	_cam.position = Vector3(0, 3.0, 11.0)
	_cam.look_at(Vector3(0, 0.9, 0))
	for d in [0.0, 0.3, 0.8]:
		_tone.free_grade = false
		_tone.snap(d)
		await _shoot("dread_%d" % int(d * 10))
	_tone.free_grade = true
	_tone.snap(0.0)
	await _shoot("dread_free")


## Rotates one face bone pair about each local axis in turn and shoots it, so the face
## rig's axes can be read off the pictures (PonyFace's LID_AXIS, EAR_AXIS, BROW_AXIS).
func _rigprobe() -> void:
	await _clear()
	var look := GeneratorScript.generate(_seed * 77, {"race": &"earth"})
	var p := _stand(look, Vector3.ZERO, deg_to_rad(90))
	_cam.position = Vector3(-3.4, 1.8, 1.7)
	_cam.look_at(Vector3(-1.0, 1.55, 0.0))
	var sks := p.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0]
	var anim: AnimationPlayer = p.get_animation_player()
	anim.pause()
	for pair in [["LeftEyeLidUpper", "RightEyeLidUpper"], ["LeftEar", "RightEar"], ["LeftEyeBrow", "RightEyeBrow"]]:
		for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			for sgn in [1.0, -1.0]:
				var rest := {}
				for b in pair:
					var i := sk.find_bone(b)
					if i < 0:
						continue
					rest[i] = sk.get_bone_pose_rotation(i)
					sk.set_bone_pose_rotation(i, rest[i] * Quaternion(axis, deg_to_rad(40) * sgn))
				await _shoot("probe_%s_%s%s" % [pair[0], "xyz"[[Vector3.RIGHT, Vector3.UP, Vector3.BACK].find(axis)], "p" if sgn > 0 else "n"])
				for i in rest:
					sk.set_bone_pose_rotation(i, rest[i])


## The story cast (game/data/characters), in a row, each with her look built exactly as the
## game builds it.
func _cast() -> void:
	await _clear()
	var ids := ["tumble", "marigold", "fennel", "pip", "bramble", "static", "clover"]
	var x := -float(ids.size() - 1) * 1.3
	for id in ids:
		var def: Resource = load("res://data/characters/%s.tres" % id)
		if def == null:
			continue
		_stand(def.call("build_look"), Vector3(x, 0, 0), deg_to_rad(65))
		x += 2.6
	_cam.position = Vector3(0, 2.6, 13.0)
	_cam.look_at(Vector3(0, 1.0, 0))
	await _shoot("cast")


## Each room of the Rainbow Factory interior from its entry, at the room's own dread.
func _factory() -> void:
	await _clear()
	var fi: Node3D = load("res://world/factory_interior.gd").new()
	add_child(fi)
	_sun.light_energy = 0.25
	for spec: Dictionary in fi.ROOMS:
		var origin: Vector3 = fi.room_origin(spec.name)
		_cam.position = origin + Vector3(-1.5, 2.2, -0.8)
		_cam.look_at(origin + Vector3(0.5, 1.6, -8.0))
		_tone.snap(float(spec.dread))
		await _shoot("factory_%s" % spec.name)
	_tone.snap(0.0)
	_sun.light_energy = 1.25
	fi.queue_free()
