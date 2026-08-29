extends Node3D
## Offscreen render harness -- the gate that looks at pixels.
##
## Every structural gate in this project has, at least once, been green while something
## was visibly broken on screen: a pony that exported almost entirely invisible
## (docs/pipeline.md section 7), an invisible held pony, a camera inside a wall. This
## scene exists so the next visual defect is caught by looking rather than by the owner
## noticing it in a playtest.
##
## It renders, it does not assert. Read the PNGs.
##
## Usage (windowed/offscreen -- NOT --headless, which renders nothing):
##
##   xvfb-run -a tools/bin/godot --path game --audio-driver Dummy \
##     --resolution 1280x720 scenes/test/visual_review.tscn -- \
##     mode=face character=twilight out=/tmp/shots
##
## Modes:
##   face    close-ups of the head: front, three-quarter, and a tight crop on the left
##           eye. This is what "eyes look funny" gets judged on.
##   motion  the character travelling at the clip's own speed with the mane and tail
##           simulating, captured at several instants far enough apart to see the trail.
##           `clip=walk` or `clip=gallop`.
##   beam    a real Player with the magic beam switched on, viewed side-on at head
##           height, so the beam's origin can be compared against the horn.
##   probe   no pictures: prints measured landmark positions (horn tip, eye centres) in
##           the model's own space. This is where player.tscn's BeamOrigin number comes
##           from -- it is measured from the asset, never eyeballed.
##
## `--audio-driver Dummy` is required, as everywhere else in this project.

const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PlayerScene := preload("res://actors/player/player.tscn")

var _character := "twilight"
var _mode := "face"
var _out := ""
var _clip := "walk"
var _tag := ""

var _camera: Camera3D
var _shots := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var bits := arg.split("=", true, 1)
		if bits.size() != 2:
			continue
		match bits[0].lstrip("-"):
			"character": _character = bits[1]
			"mode": _mode = bits[1]
			"out": _out = bits[1]
			"clip": _clip = bits[1]
			"tag": _tag = bits[1]
	_camera = $Camera3D
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	match _mode:
		"face": await _run_face()
		"motion": await _run_motion()
		"beam": await _run_beam()
		"probe": await _run_probe()
		_:
			push_error("visual_review: unknown mode '%s'" % _mode)
	print("VISUAL_REVIEW_DONE mode=%s character=%s shots=%d" % [_mode, _character, _shots])
	get_tree().quit()


## Spawn through the canonical registry path, never load() -- that is what attaches the
## hair simulation (docs/notes-hair-sim.md section 7).
func _spawn() -> Node3D:
	var registry := PonyRegistryScript.new()
	var ponies: Dictionary = registry.load_all("res://data/ponies")
	var data = ponies.get(StringName(_character))
	if data == null:
		push_error("visual_review: no pony '%s'" % _character)
		return null
	var pony: Node3D = PonyVisualsScript.build(data)
	if pony != null:
		add_child(pony)
	return pony


func _anim(pony: Node3D) -> AnimationPlayer:
	return pony.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH)


## World-space centre of a named MeshInstance3D's geometry, or `fallback`.
##
## Deliberately the AABB centre and NOT `global_position`: these packs model every eye
## part with its object origin at the scene origin and place it entirely through the
## bone-parent transform, so a mesh whose geometry sits at eye height reports a
## `global_position` down by the hooves.
func _node_pos(pony: Node3D, node_name: String, fallback: Vector3) -> Vector3:
	var node := _find(pony, node_name)
	if not (node is MeshInstance3D):
		return fallback
	var mesh := node as MeshInstance3D
	var aabb := mesh.get_aabb()
	return mesh.global_transform * aabb.get_center()


## A rig-family-agnostic guess at where this pony's eyes are, from her world AABB alone.
##
## Used when the tier-a `Base_Iris.*` meshes are absent -- a tier-c SFM pony's eyes are
## part of one head mesh with no node of their own. Deliberately geometric rather than
## skeletal: the SFM rig HAS `LeftEye`/`RightEye` bones, but reading them through
## `get_bone_global_pose()` came back with the two eyes separated along the wrong axis
## (same x, 0.436 m apart in y -- the right SEPARATION, the wrong direction), i.e. the
## skeleton's internal frame is not the one `skeleton.global_transform` maps from on
## these imports. That is worth understanding one day; it is not worth blocking a review
## camera on, and an AABB cannot be wrong about which way is up.
##
## Both fractions are measured, not guessed: eyes sit at 0.72 of total height on the
## tier-a ponies (1.55 m of 2.14) and 0.68 on the SFM ones (1.50 m of 2.19), and the
## model faces -Z, so the face is a little in from the near end of the box.
func _eye_guess(pony: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for node in pony.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var world := mesh.global_transform * mesh.get_aabb()
		box = world if first else box.merge(world)
		first = false
	if first:
		return Vector3(0.0, 1.4, 0.0)
	return Vector3(box.get_center().x,
		box.position.y + 0.70 * box.size.y,
		box.position.z + 0.12 * box.size.z)


## Highest actual VERTEX of a named MeshInstance3D, in world space -- the tip of the
## horn. Deliberately the geometry and not the AABB: the horn is a cone tilted forward,
## so every corner of its box sits somewhere the horn is not.
func _mesh_top(pony: Node3D, node_name: String) -> Vector3:
	var node := _find(pony, node_name)
	if not (node is MeshInstance3D):
		push_warning("visual_review: no MeshInstance3D named '%s'" % node_name)
		return Vector3.ZERO
	var mesh := node as MeshInstance3D
	if mesh.mesh == null:
		return Vector3.ZERO
	var best := Vector3(0.0, -INF, 0.0)
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		for vertex in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var world: Vector3 = mesh.global_transform * vertex
			if world.y > best.y:
				best = world
	return best


## find_child, tolerant of the fact that Godot strips '.' out of imported node names
## ("Base_Iris.L" in the .blend arrives as "Base_Iris_L" or similar).
func _find(root: Node, node_name: String) -> Node:
	var node := root.find_child(node_name, true, false)
	if node != null:
		return node
	return root.find_child(node_name.replace(".", "_"), true, false)


func _look(from: Vector3, at: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)


func _shot(name_suffix: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if _out == "":
		return
	var image := get_viewport().get_texture().get_image()
	var stem := "%s_%s%s" % [_character, name_suffix, ("_" + _tag) if _tag != "" else ""]
	var path: String = _out.path_join(stem + ".png")
	image.save_png(path)
	_shots += 1
	print("SHOT %s" % path)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _run_face() -> void:
	var pony := _spawn()
	if pony == null:
		return
	var player := _anim(pony)
	if player != null:
		player.play("idle")
	await _settle(90)
	_experiment(pony)

	# `Base_Iris.*` is a tier-a (CreatorOfPony) mesh name. A tier-c SFM pony has no such
	# mesh -- her eyes are part of one head mesh -- so the fixed Vector3(0, 1.4, 0)
	# fallback parked the camera inside her mane and every face shot came back as a wall
	# of pink. Fall back to the SKELETON instead, which every rig family has: an eye bone
	# by name if there is one, else the head bone. Both tier-c families name theirs
	# `LeftEye`/`RightEye`.
	var guess := _eye_guess(pony)
	var eye_l := _node_pos(pony, "Base_Iris.L", guess + Vector3(0.11, 0.0, 0.0))
	var eye_r := _node_pos(pony, "Base_Iris.R", guess + Vector3(-0.11, 0.0, 0.0))
	var eyes := (eye_l + eye_r) * 0.5
	print("EYES l=(%.3f, %.3f, %.3f) r=(%.3f, %.3f, %.3f) apart=%.3f m" % [
		eye_l.x, eye_l.y, eye_l.z, eye_r.x, eye_r.y, eye_r.z, eye_l.distance_to(eye_r)])
	# The model faces -Z (export_blend.py --rotate-z 180), so "in front of her" is -Z.
	_camera.fov = 35.0
	_look(eyes + Vector3(0.0, 0.03, -0.90), eyes)
	await _shot("face_front")
	_look(eyes + Vector3(-0.68, 0.10, -0.68), eyes)
	await _shot("face_threequarter")
	# Tight crop on one eye: close enough that the iris fills a good part of frame.
	_camera.fov = 24.0
	_look(eye_l + Vector3(-0.20, 0.03, -0.52), eye_l)
	await _shot("eye_closeup")
	_camera.fov = 40.0
	_look(eyes + Vector3(-1.5, 0.55, -1.5), eyes)
	await _shot("head_wide")


## Isolation knobs used while diagnosing a defect, kept because both of them earned it.
##
## `tag=noiris` / `tag=noeye` hide one layer of the eye. That is how the ragged upper rim
## on every iris was pinned on the sclera intersecting the iris cap rather than on the
## iris texture's alpha: with the iris hidden the white of the eye is a clean oval, and
## with the iris material forced fully opaque the tear was still exactly there.
##
## `tag=rigid` pins the hair to the skull, which is the reference every
## judgement about the springs is made against -- the shape the model and the clip
## actually intend. Motion mode handles it in _run_motion; face mode handles it here,
## which is how "her mane covers her whole face" gets separated into "the springs
## collapsed it" and "the pack modelled it there" without touching the exporter.
##
## Anything else in `tag=` is just a filename suffix, so a sweep can write several
## variants into one directory.
func _experiment(pony: Node3D) -> void:
	if _tag == "rigid":
		var sim := pony.find_child("HairSpring", true, false)
		if sim is SpringBoneSimulator3D:
			(sim as SpringBoneSimulator3D).influence = 0.0
	for group in [["Base_Iris.L", "Base_Iris.R"], ["Base_Eye.L", "Base_Eye.R"]]:
		if _tag != ("noiris" if group[0].begins_with("Base_Iris") else "noeye"):
			continue
		for node_name in group:
			var node := _find(pony, node_name)
			if node is MeshInstance3D:
				(node as MeshInstance3D).visible = false


func _run_motion() -> void:
	var pony := _spawn()
	if pony == null:
		return
	var player := _anim(pony)
	if player == null:
		return
	# Physics-tick animation so the spring modifier and the clip advance in lockstep,
	# the same reason hair_lag_test.gd does it.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	player.play(_clip)
	if _tag == "rigid":
		# The reference shot: hair welded to the skull, i.e. exactly the pose the clip
		# and the model put it in. Whatever the springs do has to stay recognisably
		# this shape, only late and swinging.
		var sim := pony.find_child("HairSpring", true, false)
		if sim is SpringBoneSimulator3D:
			(sim as SpringBoneSimulator3D).influence = 0.0
	# The ground speed the clip depicts, so a planted hoof does not skate in the shot.
	# `idle` depicts standing still and must travel at zero -- before this was spelled
	# out, `clip=idle` fell through to the gallop's 3.30 m/s and slid a standing pony
	# sideways across the frame, which is not a picture of anything.
	var speed := 0.0
	if _clip == "walk":
		speed = 0.66
	elif _clip == "gallop":
		speed = 3.30
	_camera.fov = 45.0

	# Settle on the spot first so the springs are not starting from their rest pose,
	# then travel. Capture during travel and once after the stop, which is where a
	# trailing mane and a flag-in-the-wind mane look most different.
	await _settle(60)
	var elapsed := 0.0
	var shot_at := {40: "move_a", 80: "move_b", 120: "move_c"}
	for tick in 160:
		await get_tree().physics_frame
		if tick < 130:
			elapsed += speed / 60.0
			pony.position.z = -elapsed
		var focus := pony.global_position + Vector3(0.0, 0.9, 0.0)
		_look(focus + Vector3(2.6, 0.35, 0.0), focus)
		if shot_at.has(tick):
			await _shot("%s_%s" % [_clip, shot_at[tick]])
	var focus_end := pony.global_position + Vector3(0.0, 0.9, 0.0)
	_look(focus_end + Vector3(2.6, 0.35, 0.0), focus_end)
	await _shot("%s_settled" % _clip)


func _run_beam() -> void:
	var player: CharacterBody3D = PlayerScene.instantiate()
	add_child(player)
	await _settle(60)
	# The player brings its own camera rig, which makes itself current. Take the view
	# back: the beam still AIMS through the rig, we just want to watch from the side.
	_camera.current = true
	player.get_magic_beam().call("grab")
	for i in 20:
		await get_tree().physics_frame
	await _settle(4)

	var horn := _mesh_top(player, "Base_Horn")
	var origin: Vector3 = player.get_beam_origin().global_position
	print("BEAM horn_tip=(%.3f, %.3f, %.3f) beam_origin=(%.3f, %.3f, %.3f) gap=%.3f m" % [
		horn.x, horn.y, horn.z, origin.x, origin.y, origin.z, horn.distance_to(origin)])

	_camera.fov = 40.0
	var focus := horn + Vector3(0.0, -0.25, -0.35)
	_look(focus + Vector3(-1.9, 0.20, 0.0), focus)
	await _shot("beam_side")
	_look(focus + Vector3(-1.5, 0.45, -1.5), focus)
	await _shot("beam_threequarter")
	_camera.fov = 55.0
	var body := player.global_position + Vector3(0.0, 1.1, -0.4)
	_look(body + Vector3(-3.4, 1.4, -1.7), body)
	await _shot("beam_wide")


func _run_probe() -> void:
	var pony := _spawn()
	if pony == null:
		return
	var player := _anim(pony)
	if player != null:
		player.play("idle")
		player.seek(0.0, true)
	await _settle(5)
	var horn := _mesh_top(pony, "Base_Horn")
	var eye_l := _node_pos(pony, "Base_Iris.L", Vector3.ZERO)
	var eye_r := _node_pos(pony, "Base_Iris.R", Vector3.ZERO)
	var local := pony.global_transform.affine_inverse()
	var horn_local: Vector3 = local * horn
	print("PROBE %s horn_tip_local=(%.4f, %.4f, %.4f) eye_l=(%.4f, %.4f, %.4f) eye_r=(%.4f, %.4f, %.4f)" % [
		_character, horn_local.x, horn_local.y, horn_local.z,
		eye_l.x, eye_l.y, eye_l.z, eye_r.x, eye_r.y, eye_r.z])
	_dump(pony, 0)


## Every MeshInstance3D in the model, with its world placement and materials -- so a
## missing or misplaced part shows up as a number as well as in a picture.
func _dump(node: Node, depth: int) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var mats: Array[String] = []
		for i in maxi(1, mesh.get_surface_override_material_count()):
			var mat := mesh.get_active_material(i)
			if mat == null:
				continue
			var kind := "?"
			if mat is StandardMaterial3D:
				var std := mat as StandardMaterial3D
				kind = "transparency=%d cull=%d albedo=%s tex=%s" % [
					std.transparency, std.cull_mode, std.albedo_color,
					"yes" if std.albedo_texture != null else "no"]
			mats.append("%s[%s]" % [mat.resource_name, kind])
		var pos: Vector3 = mesh.global_position
		print("  MESH %-26s pos=(%.3f, %.3f, %.3f) %s" % [
			mesh.name, pos.x, pos.y, pos.z, ", ".join(mats)])
	for child in node.get_children():
		_dump(child, depth + 1)
