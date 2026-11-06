class_name PonyFace
extends SkeletonModifier3D
## A PONY'S FACE, LAYERED OVER WHATEVER HER BODY IS DOING. Runs after the AnimationPlayer
## (it is a SkeletonModifier3D, like the hair springs), so blinks, ear flicks, brow moods,
## a talking jaw and a head turned toward the player sit on top of idle, walk, graze or
## sleep without a single extra clip being exported.
##
## Bone names are the SFM ReVAmped face rig shared by every donor (AUDIT.md section 5.2):
## LeftEyeLidUpper/RightEyeLidUpper, LeftEar/RightEar, LeftEyeBrow/RightEyeBrow, Javv (the
## jaw; the Source rig's spelling), and the neck and head chain for looking. A donor missing
## a bone simply skips that channel.
##
## Rotations are offsets applied to the bone's current (animated) pose around an axis in the
## bone's local space; the axes below were measured on the donor rig (see the face sheet in
## tools/capture_shots.sh).

enum Mood { NEUTRAL, HAPPY, SAD, SCARED, ANGRY, BLANK, COY }

## Measured with the rigprobe set in game/scenes/test/shots.gd: +X brings the upper lid down
## over the eye; +Y swings the left ear out and down (the right ear mirrors it).
const LID_AXIS := Vector3(1, 0, 0)
## The bone only squints: the donors' eyeballs are a separate mesh the lid's weights do not
## reach, so the full blink is drawn by the eye shader's `lid` (game/shaders/pony_eye.gdshader).
const LID_CLOSED := deg_to_rad(30.0)
const EYE_SHADER := preload("res://shaders/pony_eye.gdshader")
const EAR_AXIS := Vector3(0, 1, 0)
const BROW_AXIS := Vector3(0, 0, 1)
const JAW_AXIS := Vector3(0, 0, 1)
const JAW_OPEN := deg_to_rad(11.0)

## Per mood: [ear droop (rad, + is back/down), brow tilt (rad), lid rest (0..1 closed)].
const MOODS := {
	Mood.NEUTRAL: [0.0, 0.0, 0.0],
	Mood.HAPPY: [-0.12, 0.10, 0.12],
	Mood.SAD: [0.55, -0.18, 0.35],
	Mood.SCARED: [0.75, 0.24, 0.0],
	Mood.ANGRY: [0.35, -0.3, 0.25],
	Mood.BLANK: [0.0, 0.0, 0.0],
	## THE LOOK THE OWNER LIKED (playtest 2026-11-05: "she was also looking at me with lidded
	## eyes at first it was funny and i liked it"): half lidded, a little sly. A calm pony who
	## has noticed the player gives her this (Pony._update_mood).
	Mood.COY: [-0.05, 0.08, 0.42],
}

## Seconds between blinks, min and max. A BLANK face never blinks (Marigold's tell).
@export var blink_interval := Vector2(2.2, 5.5)
@export var mood: Mood = Mood.NEUTRAL
## World point to look at, or Vector3.INF for none.
var look_target: Vector3 = Vector3.INF
## 0..1, how much of the head turn toward look_target is applied.
@export var look_weight: float = 0.0
## Max head yaw toward a look target.
@export var look_max := deg_to_rad(55.0)
## Held shut (sleeping, a contented sigh, the Bloom's eyes-closed beat). Blinks pause.
var eyes_closed: bool = false
## True while a talk line is revealing: the jaw flaps with `talk_amount`.
var talking: bool = false
## 0..1 syllable envelope from the babble voice; the jaw opens with it.
var talk_amount: float = 0.0

var _rng := RandomNumberGenerator.new()
var _blink_t := 0.0
var _blink_next := 3.0
var _blink_phase := -1.0
var _ear_flick := -1.0
var _ear_side := 0
var _ear_next := 4.0
var _mood_ears := 0.0
var _mood_brow := 0.0
var _mood_lid := 0.0
var _look_yaw := 0.0
var _last_usec := 0
var _bones := {}
var _closed := 0.0
var _eyes: Array[ShaderMaterial] = []
var _lid_written := -1.0
var _delta_last := 0.016


func _ready() -> void:
	_rng.randomize()
	_blink_next = _rng.randf_range(blink_interval.x, blink_interval.y)
	_ear_next = _rng.randf_range(3.0, 9.0)


## HER EYES FOLLOW SOMEONE CLOSE (FS3.2). A world point to look at, or Vector3.INF; the
## pony sets it to the player when she is near and calm. The iris slides at most GAZE_MAX
## (iris texture UV) on top of any gaze the eye already has (Derpy's, ToonStyler.CROSS_EYED).
var gaze_at: Vector3 = Vector3.INF
const GAZE_MAX := 0.08
const GAZE_PER_RAD := 0.09
var _eye_base: Dictionary = {}


## The Mane Six's rig names the same bones its own way (DEF_ and CON_, FS3.1).
const ALIASES := {
	"LeftEyeLidUpper": "CON_UpperEyelid.L", "RightEyeLidUpper": "CON_UpperEyelid.R",
	"LeftEar": "DEF_Ear1.L", "RightEar": "DEF_Ear1.R", "Javv": "CON_Jaw",
	"Neck1": "DEF_Neck1", "Head": "DEF_Head",
}


func _find(name: String) -> int:
	if _bones.has(name):
		return _bones[name]
	var sk := get_skeleton()
	var i := sk.find_bone(name) if sk != null else -1
	if i < 0 and sk != null and ALIASES.has(name):
		i = sk.find_bone(ALIASES[name])
	_bones[name] = i
	return i


## Which face channels this skeleton has bones for, by either rig's names.
func channels_found() -> Dictionary:
	return {"lid_l": _find("LeftEyeLidUpper") >= 0, "lid_r": _find("RightEyeLidUpper") >= 0,
		"ear_l": _find("LeftEar") >= 0, "ear_r": _find("RightEar") >= 0, "jaw": _find("Javv") >= 0}


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var now := Time.get_ticks_usec()
	var delta := 0.016 if _last_usec == 0 else clampf((now - _last_usec) / 1_000_000.0, 0.0, 0.1)
	_last_usec = now
	_delta_last = delta
	_tick(delta)
	var lid := clampf(_mood_lid + _blink_amount(), 0.0, 1.0)
	_closed = move_toward(_closed, 1.0 if eyes_closed else 0.0, _delta_last * 6.0)
	lid = maxf(lid, _closed)
	_rotate(sk, "LeftEyeLidUpper", LID_AXIS, minf(lid, 0.5) * LID_CLOSED)
	_rotate(sk, "RightEyeLidUpper", LID_AXIS, minf(lid, 0.5) * LID_CLOSED)
	_set_eye_lid(sk, lid)
	_update_gaze()
	var flick := _ear_flick_amount()
	_rotate(sk, "LeftEar", EAR_AXIS, _mood_ears + (flick if _ear_side == 0 else 0.0))
	_rotate(sk, "RightEar", EAR_AXIS, -(_mood_ears + (flick if _ear_side == 1 else 0.0)))
	# The donors' brows are drawn lines with almost no deformation (rigprobe), so the brow
	# channel stays a whisper; the mood reads through lids and ears.
	_rotate(sk, "LeftEyeBrow", BROW_AXIS, _mood_brow * 0.3)
	_rotate(sk, "RightEyeBrow", BROW_AXIS, -_mood_brow * 0.3)
	if talking or talk_amount > 0.001:
		_rotate(sk, "Javv", JAW_AXIS, -JAW_OPEN * clampf(talk_amount, 0.0, 1.0))
	if absf(_look_yaw) > 0.001:
		_rotate_world_up(sk, "Neck1", _look_yaw * 0.4)
		_rotate_world_up(sk, "Head", _look_yaw * 0.6)


## AT REST, THE EYES ARE HER MOOD'S, NEVER A FROZEN BLINK (PT11; playtest 2026-11-05: a far
## pony "didnt have eyes" until the player came close). A far pony's face does not process
## (Pony._set_detail), and it used to stop wherever it was: mid blink, the lids stayed shut.
## This writes the lids and the gaze for `mood` at rest, once, for a face that is resting.
func settle() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_blink_phase = -1.0
	var m: Array = MOODS.get(mood, MOODS[Mood.NEUTRAL])
	_mood_lid = float(m[2])
	_lid_written = -1.0
	_set_eye_lid(sk, maxf(_mood_lid, 1.0 if eyes_closed else 0.0))


## Push the lid amount into every eye material on this pony (cached on first use).
func _set_eye_lid(sk: Skeleton3D, lid: float) -> void:
	if absf(lid - _lid_written) < 0.002:
		return
	_lid_written = lid
	_collect_eyes(sk)
	for m: ShaderMaterial in _eyes:
		m.set_shader_parameter(&"lid", lid)


## Every eye material on this pony (cached on first use), and the gaze each started with.
func _collect_eyes(sk: Skeleton3D) -> void:
	if not _eyes.is_empty() or sk == null:
		return
	var root: Node = sk.get_parent() if sk.get_parent() != null else sk
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var m := mi.get_active_material(i)
			if m is ShaderMaterial and (m as ShaderMaterial).shader == EYE_SHADER:
				_eyes.append(m)
				var g: Variant = (m as ShaderMaterial).get_shader_parameter(&"gaze")
				_eye_base[m.get_instance_id()] = g if g is Vector2 else Vector2.ZERO


func _update_gaze() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_collect_eyes(sk)
	if _eyes.is_empty():
		return
	var look := Vector2.ZERO
	var head := _find("Head")
	if gaze_at != Vector3.INF and head >= 0:
		# Her own frame: the rigs face +Z.
		var d := sk.global_transform.affine_inverse() * gaze_at - sk.get_bone_global_pose(head).origin
		var yaw := atan2(d.x, d.z)
		var pitch := atan2(d.y, Vector2(d.x, d.z).length())
		look = Vector2(clampf(yaw * GAZE_PER_RAD, -GAZE_MAX, GAZE_MAX),
			clampf(-pitch * GAZE_PER_RAD, -GAZE_MAX, GAZE_MAX))
	for m: ShaderMaterial in _eyes:
		m.set_shader_parameter(&"gaze", (_eye_base.get(m.get_instance_id(), Vector2.ZERO) as Vector2) + look)


func _tick(delta: float) -> void:
	var m: Array = MOODS.get(mood, MOODS[Mood.NEUTRAL])
	_mood_ears = move_toward(_mood_ears, float(m[0]), delta * 2.5)
	_mood_brow = move_toward(_mood_brow, float(m[1]), delta * 2.0)
	_mood_lid = move_toward(_mood_lid, float(m[2]), delta * 2.0)
	if mood != Mood.BLANK:
		_blink_t += delta
		if _blink_phase < 0.0 and _blink_t >= _blink_next:
			_blink_phase = 0.0
			_blink_t = 0.0
			_blink_next = _rng.randf_range(blink_interval.x, blink_interval.y)
	if _blink_phase >= 0.0:
		_blink_phase += delta / 0.16
		if _blink_phase >= 1.0:
			_blink_phase = -1.0
	_ear_next -= delta
	if _ear_next <= 0.0 and _ear_flick < 0.0:
		_ear_flick = 0.0
		_ear_side = _rng.randi_range(0, 1)
		_ear_next = _rng.randf_range(3.0, 9.0)
	if _ear_flick >= 0.0:
		_ear_flick += delta / 0.28
		if _ear_flick >= 1.0:
			_ear_flick = -1.0
	var want := 0.0
	if look_target != Vector3.INF and look_weight > 0.0:
		var sk := get_skeleton()
		var local := sk.global_transform.affine_inverse() * look_target
		# Donor rigs face -Z (export_blend.py --rotate-z 180, the convention pony.gd and
		# player.gd use); yaw toward the target from there.
		want = clampf(atan2(-local.x, -local.z), -look_max, look_max) * look_weight
	_look_yaw = lerpf(_look_yaw, want, clampf(delta * 6.0, 0.0, 1.0))


func _blink_amount() -> float:
	if _blink_phase < 0.0:
		return 0.0
	# Close fast, open a touch slower.
	return sin(clampf(_blink_phase, 0.0, 1.0) * PI)


func _ear_flick_amount() -> float:
	if _ear_flick < 0.0:
		return 0.0
	return sin(_ear_flick * PI) * 0.45


func _rotate(sk: Skeleton3D, bone: String, axis: Vector3, angle: float) -> void:
	if absf(angle) < 0.0001:
		return
	var i := _find(bone)
	if i < 0:
		return
	var q := sk.get_bone_pose_rotation(i)
	sk.set_bone_pose_rotation(i, q * Quaternion(axis, angle))


func _rotate_world_up(sk: Skeleton3D, bone: String, angle: float) -> void:
	var i := _find(bone)
	if i < 0:
		return
	var parent := sk.get_bone_parent(i)
	var up_local := Vector3.UP
	if parent >= 0:
		up_local = (sk.get_bone_global_pose(parent).basis.inverse() * Vector3.UP).normalized()
	var q := sk.get_bone_pose_rotation(i)
	sk.set_bone_pose_rotation(i, Quaternion(up_local, angle) * q)
