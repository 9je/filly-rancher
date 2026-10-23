class_name Npc
extends CharacterBody3D
## A STORY CHARACTER IN THE WORLD: her body built from her CharacterDef through the same
## generator and PonyPaint path as every Drifter, a PonyFace on her skeleton, and three
## ways to be: STAND at a spot (turning to face whoever comes close), FOLLOW a target at a
## distance (Tumble), or WALK_TO a point and stand there.
##
## She talks through game/world/people.gd, which owns the conversations; this node only
## acts them out: `act(mood, anim)` sets her face and plays a one-shot or loop clip.

const PonyRigScript := preload("res://scripts/pony_rig.gd")
const PonyPaintScript := preload("res://systems/pony_paint.gd")
const DonorTableScript := preload("res://systems/donor_table.gd")
const GaitScript := preload("res://systems/gait.gd")
const PonyFaceScript := preload("res://actors/pony/pony_face.gd")
const LayersScript := preload("res://world/collision_layers.gd")

enum Mode { STAND, FOLLOW, WALK_TO }

## Clips that play once and hand back to standing.
const ONE_SHOTS: Array[StringName] = [&"nod", &"shake", &"rear", &"startle", &"look", &"jump"]
const MOODS := {&"neutral": 0, &"happy": 1, &"sad": 2, &"scared": 3, &"angry": 4, &"blank": 5}

@export var character_id: StringName = &""
@export var face_player_radius := 6.0
@export var follow_distance := 2.6
@export var walk_speed := 1.1
@export var run_speed := 3.4

var def: CharacterDef
var mode: int = Mode.STAND
var follow_target: Node3D
var walk_target := Vector3.ZERO
## Where she stands when STANDing (her spawn point unless moved).
var home := Vector3.ZERO
## Something to look at (the player, usually); null for nothing.
var watch: Node3D
## A clip she holds while standing (sit, sleep, graze, sad): her "pose" for a scene.
var standing_clip: StringName = &"idle"

var _visuals: Node3D
var _anim: AnimationPlayer
var _face: PonyFace
var _one_shot := false
var _yaw := 0.0


func _ready() -> void:
	collision_layer = LayersScript.PONY
	collision_mask = LayersScript.PONY_WALKABLE
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.6
	shape.shape = capsule
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)
	_visuals = Node3D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	home = global_position
	# Her facing lives on the body (Visuals), never on this node: a spot's facing arrives as
	# this node's rotation and is moved onto the body, so the watch yaw does not stack on it.
	_yaw = rotation.y
	rotation.y = 0.0
	if character_id != &"":
		setup(load("res://data/characters/%s.tres" % character_id) as CharacterDef)


func setup(d: CharacterDef) -> void:
	def = d
	if def == null or not is_inside_tree():
		return
	for c in _visuals.get_children():
		c.free()
	var look := def.build_look()
	var path := DonorTableScript.model_path(look.donor)
	if not ResourceLoader.exists(path):
		return
	var body: Node3D = (load(path) as PackedScene).instantiate()
	PonyRigScript.attach_hair_simulation(body)
	_visuals.add_child(body)
	PonyPaintScript.apply(body, look)
	_visuals.scale = Vector3.ONE * PonyPaintScript.body_scale(look)
	_anim = body.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if _anim != null:
		_anim.animation_finished.connect(_on_clip_finished)
	var sks := body.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		_face = PonyFaceScript.new()
		_face.name = "Face"
		(sks[0] as Skeleton3D).add_child(_face)
		if def.never_blinks:
			_face.blink_interval = Vector2(9999.0, 9999.0)
	_play(&"idle")


func face() -> PonyFace:
	return _face


func get_animation_player() -> AnimationPlayer:
	return _anim


## Act a line: set her mood and play `anim` (a one-shot returns to standing).
func act(mood: StringName, anim: StringName = &"") -> void:
	if _face != null:
		_face.mood = MOODS.get(mood, 0)
	if anim != &"" and _anim != null and _anim.has_animation(anim):
		_one_shot = anim in ONE_SHOTS
		_anim.play(anim, 0.2)
		_anim.speed_scale = 1.0


## Talking: the jaw follows `amount` (0..1) from the babble voice.
func set_talking(on: bool, amount: float = 0.0) -> void:
	if _face != null:
		_face.talking = on
		_face.talk_amount = amount if on else 0.0
	if _anim != null and not _one_shot and velocity.length() < 0.2:
		if on and _anim.has_animation(&"talk"):
			_play(&"talk")
		elif not on and _anim.current_animation == &"talk":
			_play(standing_clip)


func set_mode_stand(at: Vector3 = Vector3.INF) -> void:
	mode = Mode.STAND
	if at != Vector3.INF:
		home = at


func set_mode_follow(target: Node3D) -> void:
	mode = Mode.FOLLOW
	follow_target = target


func set_mode_walk_to(at: Vector3) -> void:
	mode = Mode.WALK_TO
	walk_target = at


func _physics_process(delta: float) -> void:
	var desired := Vector3.ZERO
	match mode:
		Mode.FOLLOW:
			if follow_target != null and is_instance_valid(follow_target):
				var to := follow_target.global_position - global_position
				to.y = 0.0
				var d := to.length()
				if d > follow_distance:
					var speed := run_speed if d > follow_distance * 3.0 else walk_speed * 1.4
					desired = to.normalized() * minf(speed, (d - follow_distance) * 2.0 + 0.4)
		Mode.WALK_TO:
			var to2 := walk_target - global_position
			to2.y = 0.0
			if to2.length() > 0.3:
				desired = to2.normalized() * walk_speed
			else:
				set_mode_stand(walk_target)
		Mode.STAND:
			var back := home - global_position
			back.y = 0.0
			if back.length() > 0.6:
				desired = back.normalized() * walk_speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	var h := Vector3(velocity.x, 0, velocity.z).move_toward(desired, 6.0 * delta)
	velocity.x = h.x
	velocity.z = h.z
	move_and_slide()
	_turn(desired, delta)
	_animate()


func _turn(desired: Vector3, delta: float) -> void:
	var want := _yaw
	if desired.length() > 0.1:
		want = atan2(-desired.x, -desired.z)
	elif watch != null and is_instance_valid(watch):
		var to := watch.global_position - global_position
		to.y = 0.0
		if to.length() < face_player_radius and to.length() > 0.2:
			want = atan2(-to.x, -to.z)
	_yaw = lerp_angle(_yaw, want, 1.0 - exp(-5.0 * delta))
	_visuals.rotation.y = _yaw
	if _face != null:
		if watch != null and is_instance_valid(watch) \
				and global_position.distance_to(watch.global_position) < face_player_radius:
			_face.look_target = watch.global_position + Vector3(0, 1.3, 0)
			_face.look_weight = 1.0
		else:
			_face.look_weight = 0.0


func _animate() -> void:
	if _anim == null or _one_shot:
		return
	var speed := Vector3(velocity.x, 0, velocity.z).length()
	if speed > GaitScript.IDLE_SPEED:
		var clip := GaitScript.clip_for_speed(speed, _anim.has_animation(&"trot"))
		_play(clip)
		_anim.speed_scale = GaitScript.playback_scale_for_clip(clip, speed)
	elif _anim.current_animation != &"talk":
		_play(standing_clip)
		_anim.speed_scale = 1.0


func _play(clip: StringName) -> void:
	if _anim == null or _anim.current_animation == clip or not _anim.has_animation(clip):
		return
	_anim.play(clip, 0.25)


func _on_clip_finished(_name: StringName) -> void:
	if _one_shot:
		_one_shot = false
		_play(standing_clip)
