class_name SpikeActor
extends Node3D
## SPIKE (for Damon): the baby dragon minding the mailbox. He is not a pony and has no pony
## rig, so he is his own small actor: a breathing bob, a tail that sways, a look toward the
## player when she is near, and -- the show's own joke -- a burp of green dragonfire every time
## a letter arrives (ranch.gd calls letter_arrived()). Model: game/assets/models/spike.glb,
## built by tools/blender_props/build_props.py.

const MODEL := "res://assets/models/spike.glb"
const LOOK_RADIUS := 7.0

var player: Node3D
var _body: Node3D
var _t := 0.0
var _base_y := 0.0
var _yaw := 0.0


func _ready() -> void:
	if ResourceLoader.exists(MODEL):
		_body = (load(MODEL) as PackedScene).instantiate()
		add_child(_body)
		ToonStyler.style(_body, &"pony", {})
	_base_y = position.y
	_yaw = rotation.y


func _process(delta: float) -> void:
	_t += delta
	if _body == null:
		return
	# Breathing, and a little sway, so he reads as alive from across the yard.
	_body.position.y = sin(_t * 2.1) * 0.02
	_body.rotation.z = sin(_t * 1.3) * 0.04
	# He turns to watch the player when she is close; otherwise back to the lane.
	var want := _yaw
	if player != null and is_instance_valid(player):
		var to := player.global_position - global_position
		to.y = 0.0
		if to.length() < LOOK_RADIUS and to.length() > 0.3:
			want = atan2(to.x, to.z)
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-3.0 * delta))


## A letter: a burp of green dragonfire and a little hop, the way he sends Twilight's mail.
func letter_arrived() -> void:
	if _body == null:
		return
	var t := create_tween()
	t.tween_property(_body, "position:y", 0.12, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_body, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var fire := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.6, -1)
	pm.spread = 25.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, 1.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var grad := Gradient.new()
	grad.set_color(0, Color(0.6, 1.0, 0.5, 1.0))
	grad.set_color(1, Color(0.1, 0.7, 0.3, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	fire.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = BloomCeremony.star_texture()
	quad.material = mat
	fire.draw_pass_1 = quad
	fire.amount = 40
	fire.lifetime = 0.8
	fire.one_shot = true
	fire.explosiveness = 0.85
	add_child(fire)
	fire.position = Vector3(0, 0.72, -0.35)
	fire.emitting = true
	get_tree().create_timer(1.6).timeout.connect(fire.queue_free)
