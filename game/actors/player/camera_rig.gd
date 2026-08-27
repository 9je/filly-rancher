class_name CameraRig
extends Node3D
## Task 5: the third-person camera. Mounted as a child of `Player`'s `CameraPivot`
## (head height, y=1.45 m -- see player.gd's class comment for why that node exists
## and why it never rotates). This node owns everything about how the player actually
## SEES the world: orbit (mouse + right-stick), collision-aware distance (SpringArm3D),
## zoom, and the crosshair-accurate aim ray Task 8's magic beam fires along.
##
## NODE STRUCTURE (see camera_rig.tscn):
##   CameraRig (this script)   -- owns YAW. `rotation.y` is the only thing this node's
##                                 own transform ever carries.
##     SpringArm3D             -- owns PITCH (`rotation.x`) and DISTANCE
##                                 (`spring_length`, adjusted by zoom). Collision-aware:
##                                 casts a ray each physics frame (no `shape` is
##                                 assigned, so it probes with a ray rather than a
##                                 volume) and pulls the camera in if something is in
##                                 the way, so the rig never clips through a wall.
##       Camera3D               -- `current = true`, identity local transform. No fixed
##                                 flip is needed here -- see below.
##
## NO 180-DEGREE FLIP ANYWHERE IN THIS RIG, ON PURPOSE.
## It is tempting to assume a Camera3D child of a SpringArm3D needs a local yaw flip so
## it "looks back" at the arm's origin instead of past it -- that was this file's first
## draft, reasoned out on paper, and it was wrong. Checked directly against the running
## engine (a throwaway script instancing a bare Node3D -> SpringArm3D -> Camera3D and
## printing `Camera3D.global_position`/`global_transform.basis` with zero rotations
## applied anywhere): a plain, unrotated SpringArm3D with an identity-transform
## Camera3D child already places the camera BEHIND the arm's origin (positive local Z)
## and pointed back through it (looking toward -Z) with `spring_length` alone -- no
## flip required, on the arm or the camera. Since `Player`'s forward is -Z (the body
## never rotates, see player.gd), that unflipped rig is already correctly oriented:
## `CameraRig` at yaw 0 sits behind the pony looking at her back and beyond, matching
## her own forward. Paper derivation said otherwise (assumed the arm casts toward -Z
## AND assumed offset direction and look direction must always be parallel for an
## identity child) and both assumptions were wrong in ways that happened to cancel out
## algebraically before but not after adding the arm's own baseline offset -- this
## comment exists so nobody "fixes" this rig back into that broken state. If this ever
## needs re-deriving, re-verify against the engine the same way rather than on paper.
##
## YAW/PITCH SIGN CONVENTIONS (see `add_look_delta()`'s own doc for the exact
## sign of its parameters; this is the mapping onto the two rotated nodes):
##   `rotation.y` (this node)      -- decreasing turns the view right, increasing left
##                                    (standard Godot: +Y rotation turns -Z toward -X,
##                                    i.e. left, when the rig starts at yaw 0 facing the
##                                    Player's forward, -Z).
##   SpringArm3D.rotation.x        -- driven from `_look_pitch` DIRECTLY (no sign flip):
##                                    positive `_look_pitch` ("look up") needs positive
##                                    `rotation.x`, which -- verified the same
##                                    engine-checked way as the paragraph above -- swings
##                                    the camera BELOW eye level looking up. Also
##                                    engine-verified, not re-derived on paper.
##
## `get_aim_ray()` is Task 8's contract (see its own doc comment) -- do not rename it.

const CollisionLayersScript := preload("res://world/collision_layers.gd")

## Pitch clamp, in the "intuitive" sense: positive = looking up, negative = looking
## down. The task brief suggests roughly -60/+70; DOWN uses that suggestion as-is, but
## UP is deliberately tighter -- see the reasoning below, confirmed against actual
## rendered frames (the task report's screenshots), not just asserted.
##
## WHY +70 DOESN'T FIT THIS CHARACTER. `CameraPivot` sits at 1.45 m. At SPRING_DEFAULT
## (3.5 m) a +70 degree pitch asks the spring arm for a camera position roughly
## `1.45 - sin(70deg) * 3.5 =~ -1.84 m` -- almost two metres UNDERGROUND. SpringArm3D
## does exactly its job there (it pulls the camera in against the ground rather than
## clipping through it), but that pull-in lands the camera only ~0.5 m from the pivot,
## producing an unreadable, near-macro close-up on her back at rest zoom -- confirmed
## visually, not just by this arithmetic (see the task report's "02_pitch_up" render at
## +70, kept in the report as the "before" for this decision). +30 keeps that same
## trade honest at default zoom (the arm still pulls in a little -- `sin(30deg) * 3.5
## =~ 1.75 m` still dips slightly below the 1.45 m pivot -- but the result reads as a
## normal low-angle shot, not a clipping artefact) while still gaining substantially
## more headroom whenever the player zooms in (at SPRING_MIN, 1.2 m, even the original
## +70 clears the ground with room to spare: `1.45 - sin(70deg) * 1.2 =~ 0.32 m`) --
## the collision-aware zoom is what actually earns the player a steeper look-up angle,
## not a wider pitch clamp fighting the arm's own collision probe.
const PITCH_MIN_DEG := -60.0
const PITCH_MAX_DEG := 30.0

## Spring-arm length limits, in metres, sized against Twilight's own scale rather than
## a generic human-sized default (docs/pipeline.md section 3: she is 1.163 m at the
## withers, 2.138 m to the horn tip; her body is ~1.41 m nose-to-tail per player.gd).
## MIN keeps the camera outside her ~0.84 m shoulder width with margin even when the
## spring arm is fully pulled in against a wall; MAX is a wide "establishing" shot that
## still keeps her recognisable rather than a speck.
const SPRING_MIN := 1.2
const SPRING_MAX := 6.5
## Default distance: roughly 2.5x her withers height, framing her whole body plus a
## little surrounding space -- a standard third-person "see your character" distance
## scaled down to her size rather than a human's.
const SPRING_DEFAULT := 3.5

## Metres of spring length adjusted per zoom step (scroll notch, keyboard press, or
## gamepad d-pad press -- see `_process()`).
const ZOOM_STEP := 0.5

@export_group("Look")
## Radians of yaw/pitch per pixel of mouse motion. Configurable per the task brief;
## 0.0035 rad/px (~0.2 deg/px) is a comfortable, not-too-twitchy default.
@export var mouse_sensitivity := 0.0035
## Radians/second of yaw/pitch at full right-stick deflection (~126 deg/s -- brisk
## enough to spin a full turn in under 3 s, gentle enough to hold a target).
@export var stick_sensitivity := 2.2
## Starting pitch, in degrees. A slight default downward tilt reads better than dead
## level: it shows more of the ground ahead of her instead of framing empty sky at the
## top of the shot. Confirmed against the "at rest" screenshot in the task report.
@export var default_pitch_deg := -12.0

@export_group("Collision")
## What the spring arm's pull-in probe collides with. Applied to the SpringArm3D in
## _ready(), so this is the one place that decides what the camera can see through.
##
## THIS EXISTS BECAUSE LEAVING IT AT THE DEFAULT WAS A LATENT BUG. Until Phase 1A
## Task 7 every collision object in the project sat on Godot's untouched
## `collision_layer = 1`, and this arm probed with the untouched `collision_mask = 1`,
## so the pull-in appeared to work -- by coincidence, not by design. The moment the
## world got deliberately layered geometry (game/world/collision_layers.gd: buildings
## on their own layer so a wall is distinguishable from a pony), a mask of 1 would
## have stopped seeing buildings entirely and the camera would have clipped straight
## through the barn, silently: no error, no warning, and nothing a numeric assertion
## in this project could detect. game/world/ranch.gd asserts both this mask and an
## actual measured pull-in against a real building for exactly that reason.
##
## WORLD is terrain plus props and deliberately NOT the player or the ponies: a
## camera that yanks itself in every time a pony crosses behind the player is worse
## than one that lets her pass through frame, and the rig already excludes the body
## it is mounted on by RID below. TERRAIN is still bit 1, so every scene that
## predates the ranch and builds its ground on the default layer still works.
@export_flags_3d_physics var probe_mask := CollisionLayersScript.WORLD

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D

## Current pitch in the "intuitive" sense described above. Kept as the source of truth
## instead of reading it back out of `rotation.x` so the clamp is applied in exactly
## one place.
var _look_pitch := 0.0


func _ready() -> void:
	_camera.current = true

	_look_pitch = clampf(default_pitch_deg, PITCH_MIN_DEG, PITCH_MAX_DEG)
	_spring_arm.rotation.x = deg_to_rad(_look_pitch)
	_spring_arm.spring_length = SPRING_DEFAULT
	_spring_arm.collision_mask = probe_mask

	# Exclude whatever body this rig is mounted on from its own collision probe, or a
	# spring arm whose origin ends up inside the player's capsule (it should not --
	# CameraPivot sits at 1.45 m, above the 1.3 m capsule top -- but a shorter subject
	# in a future scene could change that) would immediately pull itself in to zero.
	var body := _find_collision_ancestor()
	if body != null:
		_spring_arm.add_excluded_object(body.get_rid())

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look_delta(event.relative.x * mouse_sensitivity, event.relative.y * mouse_sensitivity)
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		# Toggle rather than release-only: makes Escape double as "give me my cursor
		# back" AND "I'm done, let me look around again", with no separate recapture
		# input needed.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick != Vector2.ZERO:
		add_look_delta(stick.x * stick_sensitivity * delta, stick.y * stick_sensitivity * delta)

	if Input.is_action_just_pressed("zoom_in"):
		add_zoom_delta(-ZOOM_STEP)
	if Input.is_action_just_pressed("zoom_out"):
		add_zoom_delta(ZOOM_STEP)


## Applies a yaw/pitch input in radians. `delta_yaw` positive turns the view right.
## `delta_pitch` positive looks DOWN -- matching screen/stick-down convention directly
## (mouse motion's `relative.y` and `Input.get_vector`'s y axis are both positive
## toward "down", the same convention `Player._movement_basis()`'s own comment notes
## for `move_forward`/`move_back`), so both the mouse and stick handlers below can feed
## it their raw axis values unmodified and still land on the "not inverted" default
## most players expect (mouse/stick UP looks up).
##
## Exposed as its own method (rather than being inlined into the input handlers) so
## tests can drive the clamp and the yaw/pitch math directly without constructing
## InputEventMouseMotion objects or a live viewport.
func add_look_delta(delta_yaw: float, delta_pitch: float) -> void:
	rotation.y -= delta_yaw
	_look_pitch = clampf(_look_pitch - rad_to_deg(delta_pitch), PITCH_MIN_DEG, PITCH_MAX_DEG)
	_spring_arm.rotation.x = deg_to_rad(_look_pitch)


## Current look pitch in degrees, positive = looking up. Exposed for tests and for any
## HUD/debug overlay that wants to show it.
func get_look_pitch_degrees() -> float:
	return _look_pitch


## Adjusts spring-arm distance by `delta_metres` (positive = zoom out), clamped to
## [SPRING_MIN, SPRING_MAX].
func add_zoom_delta(delta_metres: float) -> void:
	_spring_arm.spring_length = clampf(_spring_arm.spring_length + delta_metres, SPRING_MIN, SPRING_MAX)


## Current spring-arm rest length in metres (the commanded distance -- the arm may sit
## closer than this right now if something is in the way; that live distance is
## `_spring_arm.get_hit_length()` if a collision probe ever needs it).
func get_zoom_distance() -> float:
	return _spring_arm.spring_length


## True once this rig's Camera3D is the viewport's actual active camera -- not just
## that its own `current` flag is set, which another camera entering the tree later
## could still override.
func is_camera_current() -> bool:
	var vp := get_viewport()
	return vp != null and vp.get_camera_3d() == _camera


## A small, explicitly-typed pair rather than a Dictionary or two out-params: Task 8
## consumes this by name (`ray.origin`, `ray.direction`), which reads better at the
## call site than dictionary keys and catches a typo at parse time instead of at
## runtime. `direction` is always unit length.
class AimRay:
	var origin: Vector3
	var direction: Vector3

	func _init(p_origin: Vector3, p_direction: Vector3) -> void:
		origin = p_origin
		direction = p_direction


## A ray from the camera through the SCREEN CENTRE: `origin` is the camera's eye point,
## `direction` is a normalized world-space vector toward whatever the crosshair is
## resting on. THIS IS DELIBERATELY NOT THE PLAYER'S FACING -- Task 8's magic beam
## fires along this ray precisely so the beam goes where the player is looking, not
## where the pony's body happens to be pointed (those two only agree by coincidence).
## Uses `Camera3D.project_ray_origin`/`project_ray_normal` rather than hand-deriving
## the ray from `global_transform`, so it stays correct if the camera's projection
## (FOV, near-plane offset, or a future switch to orthographic) ever changes -- those
## methods already account for the camera's actual projection matrix and viewport
## size, a plain `-global_transform.basis.z` would not for anything but a dead-centre
## default projection.
func get_aim_ray() -> AimRay:
	var vp := get_viewport()
	var center := vp.get_visible_rect().size * 0.5
	return AimRay.new(_camera.project_ray_origin(center), _camera.project_ray_normal(center))


## The ancestor CollisionObject3D this rig is mounted under (the Player body), or null
## if this rig is used standalone (e.g. a GUT test with no such ancestor).
func _find_collision_ancestor() -> CollisionObject3D:
	var node := get_parent()
	while node != null:
		if node is CollisionObject3D:
			return node
		node = node.get_parent()
	return null
