class_name Player
extends CharacterBody3D
## The player character: Twilight Sparkle, driven by camera-relative WASD/left-stick
## input, with her body built at runtime through the canonical
## PonyRegistry -> PonyVisuals path (never by loading a .glb directly -- that is what
## attaches the mane/tail spring simulation, see docs/notes-hair-sim.md).
##
## Scene contract other tasks depend on -- do not rename these:
##   `CameraPivot` (Node3D)  -- Task 5 mounts the SpringArm3D camera rig here.
##   `get_beam_origin()`     -- Task 8 anchors the magic beam at the returned node.
##   `Player` / `player.tscn` -- instanced by the ranch map in Task 7.
##
## WHY THE BODY NEVER ROTATES AND THE VISUALS DO.
## `Player` itself keeps a fixed orientation; only the `Visuals` child yaws toward the
## movement direction. Two reasons, both load-bearing:
##   1. `CameraPivot` is a child of this body. If the body yawed, the camera rig would
##      yaw with it, which would change the camera basis this script reads its input
##      against, which would yaw the body further -- a feedback spin. Keeping the body
##      still means Task 5 owns camera yaw outright and gets a stable mount point.
##   2. The collision shape is a vertical capsule, which is rotationally symmetric
##      about Y. Rotating the body would change nothing about collision, so the
##      rotation only ever had visual meaning in the first place.
## `BeamOrigin` therefore lives UNDER `Visuals`, so it tracks the horn's real position
## as she turns.
##
## GAIT, SPEED AND FOOT SKATE -- read game/systems/gait.gd before changing any speed.
## There is exactly one locomotion clip, `walk`, and it depicts 0.66 m/s (Gait.
## WALK_CLIP_SPEED). Playback speed is scaled with ground speed so the hooves stay
## planted, but that only works up to Gait.MAX_PLAYBACK. The two speeds below are
## chosen against that ceiling:
##   WALK_SPEED  = 1.32 m/s = 2.0x playback. Fully honest, zero skate; a brisk amble.
##   GALLOP_SPEED = 4.0 m/s. Crosses the 60 m ranch in 15 s, which is the speed the
##      map actually needs. The clip saturates at Gait.MAX_PLAYBACK (3.0x, i.e.
##      1.98 m/s of honest ground speed), so top gallop skates by ~2.02x -- visible
##      moonwalking, and a deliberate, documented trade rather than an oversight.
##      Everything up to 1.98 m/s is skate-free.
## The real fix is a `gallop` clip authored as its own faster cycle; see this task's
## report. When one exists, add it to the `[importer_defaults]` loop list in
## project.godot, give Gait a GALLOP_CLIP_SPEED, and branch in _update_animation().
##
## COLLISION CAPSULE (numbers live in player.tscn, which cannot carry comments).
## Twilight measures 1.163 m at the withers and 2.138 m to the tip of her horn --
## cartoon proportions make the model 1.84x taller than the animal it depicts
## (docs/pipeline.md section 3). The capsule is sized to the BODY, not the horn:
##   radius 0.42 m  -- exactly half her measured 0.839 m shoulder width, so the
##                     capsule contains the barrel's cross-section at any facing.
##   height 1.30 m  -- total, including both hemispherical caps, centred at y=0.65 so
##                     the bottom sits exactly on the hoof plane at y=0. The top
##                     clears the 1.163 m withers with a little neck to spare, and
##                     deliberately excludes the head (bone at 1.37 m), the ears
##                     (1.85 m) and the horn (2.09 m).
## Consequence, accepted knowingly: her muzzle and tail overhang the capsule
## front-to-back (the body is ~1.41 m long but the capsule is 0.84 m across), so they
## can visually clip thin geometry. That is the standard trade for giving a quadruped
## an upright, rotationally symmetric capsule; a capsule fat enough to contain her
## nose-to-tail length would make her bump into everything from 0.7 m away.
## World geometry still has to clear 2.14 m, not 1.30 m -- the capsule is what she
## collides with, not what she looks like.
## `CameraPivot` sits at y=1.45 m: just above the head bone, below the ear tips.

const GaitScript := preload("res://systems/gait.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")

## Ground speed at full stick / any WASD key with `gallop` released. Exactly
## 2.0x Gait.WALK_CLIP_SPEED, so the walk clip plays at 2.0x with the hooves planted.
const WALK_SPEED := 2.0 * GaitScript.WALK_CLIP_SPEED

## Ground speed with `gallop` held. Chosen for the 60x60 m ranch, not for the clip --
## see the class comment for the skate this buys.
##
## Deliberately NOT read from PonyData.base_speed (Twilight's is 3.4). That field is
## documented as a race stat used from Phase 3 (docs/.../design.md), so its numbers
## exist to balance races against each other, not to be metres per second. Wiring the
## player's feel to it would mean a Phase 3 balance pass silently retuning how the
## game handles -- and would make Rainbow Dash's 6.5 a 6.5 m/s player character the
## moment anyone made her playable. If a later phase decides base_speed really is
## m/s, this is a one-line change with a test to update, which is the cheap direction
## for that decision to go.
const GALLOP_SPEED := 4.0

## Peak of a standing jump, in metres. 0.9 m is about three quarters of her withers
## height (1.163 m) -- a pony-sized hop rather than a platformer leap.
const JUMP_HEIGHT := 0.9

## Crossfade seconds between `idle` and `walk`.
const ANIM_BLEND := 0.2

@export_group("Movement")
## Metres per second per second while accelerating from a standstill.
@export var acceleration := 12.0
## Metres per second per second while braking (higher than acceleration, so letting
## go of the stick stops her promptly instead of coasting like a vehicle).
@export var deceleration := 18.0
## Fraction of the above rates that applies while airborne.
@export_range(0.0, 1.0) var air_control := 0.35
## Exponential turn rate for the visual yaw, in 1/seconds. Higher turns faster.
@export var turn_response := 12.0
## Downward speed cap, so a long fall cannot accumulate absurd velocity.
@export var terminal_velocity := 25.0

@export_group("Jump feel")
## Seconds after walking off a ledge during which `jump` still works. Standard
## platformer forgiveness -- without it, jumping off the lip of anything feels broken.
@export var coyote_time := 0.12
## Seconds a `jump` press is remembered for, so a press made just before landing
## fires on touchdown instead of being swallowed.
@export var jump_buffer := 0.12

@export_group("Character")
## Which PonyData to wear. The player is Twilight in Phase 1A, but this is data, not
## a hardcoded model path -- swapping her is editing this field, never editing code.
@export var pony_id: StringName = &"twilight"
@export_dir var pony_dir := "res://data/ponies"

@onready var camera_pivot: Node3D = $CameraPivot
@onready var visuals: Node3D = $Visuals
@onready var beam_origin: Node3D = $Visuals/BeamOrigin

var _anim: AnimationPlayer
var _visual_yaw := 0.0
var _coyote_left := 0.0
var _jump_buffered := 0.0


func _ready() -> void:
	_visual_yaw = visuals.rotation.y
	_build_visuals()


## The node the magic beam originates from (Task 8). Sits at Twilight's horn tip and
## follows her facing, since it hangs off `Visuals` rather than off the body.
func get_beam_origin() -> Node3D:
	return beam_origin


## Where a camera rig should be mounted (Task 5). Deliberately does NOT inherit the
## character's facing -- see the class comment.
func get_camera_pivot() -> Node3D:
	return camera_pivot


## Ground speed right now, in m/s, ignoring vertical motion.
func get_ground_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## The body's AnimationPlayer, or null if the visuals failed to build. Exposed so
## scenes and tests can assert which clip is playing and at what rate without
## re-deriving PonyVisuals.ANIMATION_PLAYER_PATH against the model tree.
func get_animation_player() -> AnimationPlayer:
	return _anim


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	# --- timers -----------------------------------------------------------------
	_coyote_left = coyote_time if on_floor else maxf(0.0, _coyote_left - delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buffered = jump_buffer
	else:
		_jump_buffered = maxf(0.0, _jump_buffered - delta)

	# --- gravity ----------------------------------------------------------------
	if not on_floor:
		velocity += get_gravity() * delta
		velocity.y = maxf(velocity.y, -terminal_velocity)

	# --- jump -------------------------------------------------------------------
	if _jump_buffered > 0.0 and _coyote_left > 0.0:
		velocity.y = sqrt(2.0 * absf(get_gravity().y) * JUMP_HEIGHT)
		_jump_buffered = 0.0
		_coyote_left = 0.0

	# --- horizontal movement, relative to wherever the camera is looking ---------
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_basis := _movement_basis()
	var forward := -move_basis.z
	var right := move_basis.x
	# Input.get_vector's +Y is "back", so pressing forward gives input.y == -1.
	var wish := right * input.x - forward * input.y
	var wish_magnitude := minf(wish.length(), 1.0)
	var direction := wish.normalized() if wish_magnitude > 0.0 else Vector3.ZERO

	# Analog magnitude scales the target speed, so a gamepad gets the whole range
	# between a standstill and the top speed rather than an on/off dash.
	var top_speed := GALLOP_SPEED if Input.is_action_pressed("gallop") else WALK_SPEED
	var target_velocity := direction * (top_speed * wish_magnitude)

	var rate := acceleration if wish_magnitude > 0.0 else deceleration
	if not on_floor:
		rate *= air_control
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target_velocity, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()

	_update_facing(direction, delta)
	_update_animation(get_ground_speed())


## Basis whose -Z is "forward" for input purposes: the current camera's facing,
## flattened onto the ground plane. Reads whatever camera is current rather than
## assuming a particular rig, so the playground's fixed camera and Task 5's spring-arm
## rig both work with no change here.
func _movement_basis() -> Basis:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return global_transform.basis

	var camera_basis := camera.global_transform.basis
	var forward := -camera_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		# Camera is looking straight down or straight up, so its -Z carries no useful
		# heading. Its up vector projected onto the ground does: when you pitch a
		# camera fully down, "up the screen" is the direction you were facing.
		forward = camera_basis.y
		forward.y = 0.0
		if forward.length_squared() < 0.0001:
			return global_transform.basis
	forward = forward.normalized()
	var right := Vector3.UP.cross(forward) * -1.0
	return Basis(right, Vector3.UP, -forward)


## Yaw the model toward where she is actually travelling. Keeps the last heading while
## standing still, so she does not snap back to a default facing when you let go.
func _update_facing(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.0:
		# The asset's forward is -Z (baked in by export_blend.py --rotate-z 180,
		# verified by rendering an offscreen side view in Task 4), which is also
		# Godot's own forward convention -- so no per-model fudge rotation is needed
		# here, the same way docs/pipeline.md section 6 intends.
		_visual_yaw = atan2(-direction.x, -direction.z)
	# Framerate-independent exponential smoothing toward the target yaw.
	var weight := 1.0 - exp(-turn_response * delta)
	visuals.rotation.y = lerp_angle(visuals.rotation.y, _visual_yaw, weight)


## Pick `idle` vs `walk` and, for `walk`, scale playback so the gait matches the
## ground. All the reasoning about the ceiling and the resulting skate lives in
## game/systems/gait.gd; this function must not grow its own speed constants.
func _update_animation(speed: float) -> void:
	if _anim == null:
		return
	if speed < GaitScript.IDLE_SPEED:
		_play("idle")
		_anim.speed_scale = 1.0
	else:
		_play("walk")
		_anim.speed_scale = GaitScript.playback_scale_for_speed(speed)


## play() only when the clip actually changes -- calling it every frame would restart
## the crossfade continuously and the blend would never finish.
func _play(clip: StringName) -> void:
	if _anim.current_animation == clip:
		return
	if not _anim.has_animation(clip):
		push_error("Player: pony '%s' has no '%s' animation" % [pony_id, clip])
		return
	_anim.play(clip, ANIM_BLEND)


## Build the body through the canonical registry -> PonyVisuals path. A failure here
## is reported loudly but is not fatal: an invisible player that still walks around is
## a far better headless-test and debugging experience than a crash, and PonyVisuals
## already push_errors the specific reason.
func _build_visuals() -> void:
	var registry := PonyRegistryScript.new()
	var ponies := registry.load_all(pony_dir)
	if not ponies.has(pony_id):
		push_error("Player: no PonyData with id '%s' in '%s'" % [pony_id, pony_dir])
		return

	var pony: Node3D = PonyVisualsScript.build(ponies[pony_id])
	if pony == null:
		push_error("Player: PonyVisuals.build failed for '%s'" % pony_id)
		return

	visuals.add_child(pony)
	_anim = pony.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH)
	if _anim == null:
		# PonyVisuals.build() refuses to return an instance without one, so this is
		# unreachable unless that contract changes -- assert it rather than assume it.
		push_error("Player: no AnimationPlayer at %s" % PonyVisualsScript.ANIMATION_PLAYER_PATH)
		return
	_play("idle")
