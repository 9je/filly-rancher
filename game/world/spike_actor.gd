class_name SpikeActor
extends Node3D
## SPIKE (for Damon): the baby dragon minding the mailbox. He is not a pony and has no pony
## rig, so he is his own small actor: a breathing bob, a tail that sways, a look toward the
## player when she is near, and -- the show's own joke -- a burp of green dragonfire every time
## a letter arrives (ranch.gd calls letter_arrived()). Model: game/assets/models/spike.glb,
## built by tools/blender_props/build_props.py.

const MODEL := "res://assets/models/spike.glb"
## THE REAL SPIKE: BeardedDoomGuy's "Spike The Dragon" (PonySFM, 2018), converted by
## tools/convert_mdl.py. Its VTF textures are decoded to PNG beside it (SourceIO could not
## find this pack's material root). The Blender stand-in above is only the fallback for a
## checkout without converted assets.
const REAL_MODEL := "res://assets/converted/spike/spike.glb"
const REAL_TEX := "res://assets/converted/spike/tex/"
## 1.9: 1.31 m, 0.6 PH, up to a pony's neck as in the show (owner playtest 2026-10-25,
## "spike also looks a little small"; at 1.1 he stood 0.76 m, a third of a pony).
const REAL_SCALE := 1.9
## Surface material (without SourceIO's ".001") to texture. The wings are the model's
## optional bodygroup: baby Spike has none, so they are hidden.
const REAL_SKINS := {"body": "body", "acces": "acces", "eyeball_l": "pupil_l",
	"eyeball_r": "pupil_r", "eyebrow": "eyebrow", "tongue": "tongue", "teeth": "tongue"}
## SPIKE, ANIMATED: home-equestria's Spike (assets/models/spike_he/SOURCE.md), the same PonySFM
## family as REAL_MODEL but with 24 keyed clips, so he idles, waves and breathes his fire
## instead of standing frozen in his rig's pose (owner 2026-11-05: "maybe some better models
## if we could use them"). Preferred over both models above when it is there.
const ANIM_MODEL := "res://assets/models/spike_he/spike.glb"
## 1.53: the model stands 0.86 m; this brings him to REAL_SCALE's 1.31 m.
const ANIM_SCALE := 1.53
const SPIKE_EYE := preload("res://shaders/spike_eye.gdshader")
const IRIS_L := preload("res://assets/models/spike_he/spike_iris_l.png")
const IRIS_R := preload("res://assets/models/spike_he/spike_iris_r.png")
const LOOK_RADIUS := 7.0

var player: Node3D
var _body: Node3D
var _anim: AnimationPlayer
## She is within LOOK_RADIUS (he waves once each time she comes up).
var _near := false
var _t := 0.0
var _base_y := 0.0
var _yaw := 0.0


func _ready() -> void:
	if ResourceLoader.exists(ANIM_MODEL):
		_body = (load(ANIM_MODEL) as PackedScene).instantiate()
		add_child(_body)
		_body.scale = Vector3.ONE * ANIM_SCALE
		_dress_animated(_body)
	elif ResourceLoader.exists(REAL_MODEL):
		_body = (load(REAL_MODEL) as PackedScene).instantiate()
		add_child(_body)
		_body.scale = Vector3.ONE * REAL_SCALE
		_dress_real(_body)
	elif ResourceLoader.exists(MODEL):
		_body = (load(MODEL) as PackedScene).instantiate()
		add_child(_body)
		ToonStyler.style(_body, &"pony", {})
	_base_y = position.y
	_yaw = rotation.y


## The animated Spike: the game's toon light, his own iris on his eyes, idling.
func _dress_animated(root: Node) -> void:
	ToonStyler.style(root, &"pony", {})
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := (src.resource_name if src != null else "").get_slice(".", 0)
			if key == "eyeball_l" or key == "eyeball_r":
				var eye := ShaderMaterial.new()
				eye.shader = SPIKE_EYE
				eye.set_shader_parameter(&"iris_texture", IRIS_L if key == "eyeball_l" else IRIS_R)
				mi.set_surface_override_material(i, eye)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var players := root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim = players[0]
	if _anim.has_animation(&"idle"):
		_anim.get_animation(&"idle").loop_mode = Animation.LOOP_LINEAR
	_anim.animation_finished.connect(func(_n: StringName) -> void: _play(&"idle"))
	_play(&"idle")


## His AnimationPlayer (null on the clip-less models).
func animation_player() -> AnimationPlayer:
	return _anim


func _play(clip: StringName) -> void:
	if _anim != null and _anim.has_animation(clip):
		_anim.play(clip, 0.2)


## The model ships in its rig's reference pose, arms straight out; he stands with them down.
func _rest_arms(root: Node) -> void:
	for sk: Skeleton3D in root.find_children("*", "Skeleton3D", true, false):
		for arm: String in ["LeftArm", "RightArm"]:
			var b := sk.find_bone(arm)
			var fore := sk.find_bone(arm.replace("Arm", "Forearm"))
			if b < 0 or fore < 0:
				continue
			var g := sk.get_bone_global_pose(b)
			var side := signf(sk.get_bone_global_pose(fore).origin.x - g.origin.x)
			var turned := Transform3D(Basis(Vector3(0, 0, 1), -side * deg_to_rad(65.0)) * g.basis, g.origin)
			var parent := sk.get_bone_parent(b)
			var local := (sk.get_bone_global_pose(parent).affine_inverse() * turned) if parent >= 0 else turned
			sk.set_bone_pose_rotation(b, local.basis.get_rotation_quaternion())


func _dress_real(root: Node) -> void:
	_rest_arms(root)
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if "wings" in String(mi.name).to_lower():
			mi.visible = false
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := (src.resource_name if src != null else "").get_slice(".", 0)
			if key == "wings":
				mi.set_surface_override_material(i, _clear())
				continue
			var tex_path: String = REAL_TEX + String(REAL_SKINS.get(key, key)) + ".png"
			if key.begins_with("eyeball") and ResourceLoader.exists(tex_path):
				mi.set_surface_override_material(i, _eye(mi.mesh, i, load(tex_path)))
				continue
			var mat := StandardMaterial3D.new()
			mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
			mat.roughness = 0.8
			mat.rim_enabled = true
			mat.rim = 0.25
			if ResourceLoader.exists(tex_path):
				mat.albedo_texture = load(tex_path)
			# The show's toon light, the one every pony wears (ToonStyler): the built-in
			# DIFFUSE_TOON steps the soft shadow term hard and speckled him the way the old
			# toon shader speckled the ponies (docs/playtest_fixes/ponies.md).
			var toon: Material = ToonStyler.to_toon(mat, ToonStyler.PRESETS[&"pony"]) \
				if ToonStyler.shading_enabled else mat
			# A step deeper, so his scales read the show's purple, not lavender (Fable round 7:
			# "Spike is pale lavender-pink, not canon purple").
			if toon is ShaderMaterial:
				ToonStyler._lift(toon as ShaderMaterial, SPIKE_DEEPEN)
			mi.set_surface_override_material(i, toon)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


const SPIKE_DEEPEN := 0.78
const EYE_SHADER := preload("res://shaders/pony_eye.gdshader")


## HIS EYE, PROJECTED THE WAY SOURCE DREW IT (playtest note "weird eyes", 2026-10-24). His
## eyeball's UVs are a sphere unwrap; through them the iris texture (a green slit iris in the
## middle of a white square) came out as a green sliver at the edge of a blank white eye. The
## Source "eyes" shader casts $iris along the eye's axis instead, so this does too
## (shaders/pony_eye.gdshader `planar`, along +Z, the way his face points): centred on the
## eyeball, the texture spanning the eyeball's width and height. Measured from the mesh, so it follows the model rather than a typed-in number.
func _eye(mesh: Mesh, surface: int, tex: Texture2D) -> ShaderMaterial:
	var arrays := mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var box := AABB(verts[0], Vector3.ZERO)
	for k in verts.size():
		box = box.expand(verts[k])
	# The middle of the eyeball as seen from in front (his eyes face +Z): the opening his lids
	# leave is centred there, not on the forward-most vertices, which sit by his nose.
	var origin := box.get_center()
	var m := ShaderMaterial.new()
	m.shader = EYE_SHADER
	m.set_shader_parameter(&"eye_texture", tex)
	m.set_shader_parameter(&"recolor", false)
	m.set_shader_parameter(&"planar", true)
	m.set_shader_parameter(&"eye_origin", origin)
	m.set_shader_parameter(&"eye_size", Vector2(box.size.x, box.size.y) * EYE_SPAN)
	return m


## How much of the eyeball the iris texture spans (1.0: edge to edge, as Source's projection
## does it). Looked at on the turntable (game/scenes/test/pony_turntable.gd), not guessed.
const EYE_SPAN := 1.0


func _clear() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0)
	return m


func _process(delta: float) -> void:
	_fin_scale()
	_t += delta
	if _body == null:
		return
	if _anim == null:
		# Breathing, and a little sway, so he reads as alive from across the yard.
		_body.position.y = sin(_t * 2.1) * 0.02
		_body.rotation.z = sin(_t * 1.3) * 0.04
	# He turns to watch the player when she is close; otherwise back to the lane.
	var want := _yaw
	var near := false
	if player != null and is_instance_valid(player):
		var to := player.global_position - global_position
		to.y = 0.0
		if to.length() < LOOK_RADIUS and to.length() > 0.3:
			want = atan2(to.x, to.z)
			near = true
	if near and not _near and _anim != null and _anim.current_animation == "idle":
		_play(&"wave")
	_near = near
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-3.0 * delta))


## A letter: a burp of green dragonfire and a little hop, the way he sends Twilight's mail.
## Asked for a tip (PT8): a wave, the same one he gives her on arrival.
## HIS EAR FINS AT THE SHOW'S SIZE (Fable round 8, #3: "flat head with no ear fins"): the
## model's fins are little tabs; the show draws them broad. Written after the clip each frame,
## the ear bones scaled about their roots.
const EAR_FIN_SCALE := 1.8
var _ear_bones: Array[int] = []
var _skeleton: Skeleton3D


func _fin_scale() -> void:
	if _skeleton == null:
		if _body == null:
			return
		_skeleton = _body.find_child("Skeleton3D", true, false) as Skeleton3D
		if _skeleton == null:
			return
		for n in ["LeftEar", "RightEar"]:
			var b := _skeleton.find_bone(n)
			if b >= 0:
				_ear_bones.append(b)
	for b in _ear_bones:
		_skeleton.set_bone_pose_scale(b, Vector3.ONE * EAR_FIN_SCALE)


func asked() -> void:
	_play(&"wave")


func letter_arrived() -> void:
	if _body == null:
		return
	_play(&"fire")
	var t := create_tween()
	t.tween_property(_body, "position:y", 0.12, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_body, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var fire := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.6, -1)
	pm.spread = 25.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 2.8
	pm.gravity = Vector3(0, 1.5, 0)
	pm.scale_min = 1.0
	pm.scale_max = 2.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.6, 1.0, 0.5, 1.0))
	grad.set_color(1, Color(0.1, 0.7, 0.3, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	fire.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.32, 0.32)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = BloomCeremony.star_texture()
	quad.material = mat
	fire.draw_pass_1 = quad
	fire.amount = 90
	fire.lifetime = 1.3
	fire.one_shot = true
	fire.explosiveness = 0.85
	add_child(fire)
	# At his mouth: the real model faces +Z (the stand-in faced -Z).
	var real := ResourceLoader.exists(REAL_MODEL) or _anim != null
	fire.position = Vector3(0, 0.66, 0.28) if real else Vector3(0, 0.72, -0.35)
	if real:
		pm.direction = Vector3(0, 0.6, 1)
	fire.emitting = true
	get_tree().create_timer(2.2).timeout.connect(fire.queue_free)
