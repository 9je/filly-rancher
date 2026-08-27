class_name MagicBeam
extends Node3D
## THE core mechanic: Twilight's horn beam. Point at a pony, hold the `beam` button, she
## is lifted out of the world and reeled in to float in front of you; let go before she
## wriggles out and she goes in the bag (game/systems/storage.gd). This is the pony
## equivalent of Slime Rancher's vacpack, and everything else in Phase 1A exists to make
## this moment work.
##
## Interface other tasks depend on -- do not rename:
##   grab() / release()     -- start and stop beaming.
##   is_holding() -> bool   -- whether something is currently in the beam.
##   get_storage() -> Storage -- what has been caught so far.
##
## WHO OWNS A CAPTURE. This node does, outright. pony.gd used to run a beam-hold timer of
## its own and fire captured() off an exported capture_seconds -- a second capture state
## machine underneath this one, with a default (0 s) that fired a capture on the first
## held frame. That is gone (see pony.gd's SIGNALS section): a pony now only REPORTS that
## she is held and for how long, and this file decides what the hold meant and says so
## through Pony.notify_captured() / Pony.break_free(). One rule, one place.
##
## AIM COMES FROM THE CROSSHAIR, NOT FROM HER FACING. Every cast below runs along
## CameraRig.get_aim_ray(), which is a ray from the camera through the SCREEN CENTRE.
## The horn is where the beam is DRAWN from, never what it is aimed along -- those two
## agree only by coincidence (the body yaws toward movement, the camera yaws with the
## mouse), and aiming along the horn would mean the beam misses whatever the crosshair is
## sitting on. camera_rig.gd's own comment on get_aim_ray() says the same thing from the
## other end.
##
## RANGE IS MEASURED FROM THE PLAYER, NOT FROM THE CAMERA, even though the ray starts at
## the camera. The camera sits CameraRig.SPRING_DEFAULT (3.5 m) behind her head and the
## player can zoom that between 1.2 m and 6.5 m; a range measured along the raw ray would
## quietly hand a zoomed-in player two metres less reach than a zoomed-out one, for no
## reason a player could ever discover. So the anchor (the horn) is projected onto the
## ray and REACH is added past that point -- the same projection the hold point uses, so
## both are zoom-invariant.
##
## NO PONY EVER DIES. Project-wide rule, and this is the file with the most opportunity
## to break it: every exit from a hold puts a live pony back somewhere. Stored (record in
## the bag, node freed, rebuildable through PonyRegistry -> PonyVisuals), broken free
## (physics handed back, escaped() reported), or refused by a full bag (set_held(false)
## and she drops where she was floating, unharmed). There is no fourth path, and the
## verification scene asserts the refused one specifically, because "the bag was full" is
## exactly the branch where a careless implementation would drop a pony on the floor in
## the other sense.
##
## Preloads by path rather than by the global class_name, per the convention at the top of
## game/scripts/pony_rig.gd: the class cache lives in the gitignored game/.godot/ and a
## fresh clone has not built it yet.

const PonyScript := preload("res://actors/pony/pony.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const StorageScript := preload("res://systems/storage.gd")

## Emitted after a pony's record has gone into storage and her node has been freed.
signal captured(data: PonyData)
## Emitted when a held body wins its struggle and is handed back to the world. The body
## is still alive and still in the scene -- that is the point.
signal escaped(body: Node3D)
## Emitted when a hold ended over a full bag (or over a pony with no record to store), so
## she was set down instead. A HUD hangs its "storage full!" nag off this.
signal capture_refused(body: Node3D)

## The input action, bound in project.godot to right mouse / right trigger.
const BEAM_ACTION := &"beam"

## Twilight's greeting line, played once on the FIRST successful capture as a placeholder
## for the future voice system (docs/notes-voice.md). Deliberately a plain constant path
## rather than PonyData.voice_bank: this is the player character reacting to her own
## success, not a line belonging to whoever was caught, and there is exactly one take in
## the repo so far. When the voice system lands, this is the one call site to rewrite.
const VOICE_LINE := "res://assets/audio/voice/twilight/greeting_01.wav"

## How far past the player the beam reaches, in metres. Sized against the pony's own
## DETECTION_RADIUS (5 m, pony.gd): inside that radius a SHY pony is already bolting, so a
## beam that only reached 5 m would mean every shy pony had a head start by the time she
## was grabbable, and catching one would be a foot race rather than an aim. 8.5 m leaves a
## clear couple of metres of "spot her, aim, take her" before she has even noticed you.
## The ceiling is the 60 x 60 m ranch and the readability of the beam itself -- past ~10 m
## the far end of the beam is a few pixels and you cannot tell what you have hit.
const REACH := 8.5

## Metres past the player, along the aim ray, that a held body floats. 2.2 m puts a pony
## (about 1.4 m nose to tail, 1.16 m at the withers) clearly in front of the player and
## clearly in front of the camera -- with the camera at its 3.5 m default she is roughly
## 5.9 m from the lens, which frames her whole body without her filling the shot. It is
## also comfortably outside her own 0.42 m capsule plus the player's, so a held pony does
## not visually intersect the pony holding her.
const HOLD_LEAD := 2.2

## Metres the hold point is pushed sideways (screen right) and up, PERPENDICULAR to the
## aim ray.
##
## THIS IS NOT DECORATION -- it is the fix for a bug the first offscreen render caught and
## no assertion in this task could have. The hold point started dead on the aim ray, which
## is the obviously right answer in a first-person game and the obviously wrong one here:
## the aim ray goes from the camera through the SCREEN CENTRE, and in a third-person rig
## with no shoulder offset (camera_rig.gd mounts the arm directly behind her) the player's
## own body is what sits at the screen centre. So a captured pony was reeled in and parked
## exactly, perfectly behind the player from the camera's point of view -- fully occluded,
## with the beam foreshortened into a couple of pixels behind her head. Every number in
## the gate was green: she was at the hold point, at a sensible distance, not clipping the
## near plane. The picture showed a pony holding still and nothing else happening.
##
## THE FIRST SIZING OF THESE OFFSETS WAS DERIVED FROM THE COLLISION CAPSULE AND WAS TOO
## SMALL. It reasoned: the player's 0.42 m capsule at 3.5 m subtends about 6 degrees, so
## 1.4 m across at the hold point's ~5.6 m clears it. Phase 1A Task 9's integration pass
## rendered an actual capture in the actual ranch and the picture disagreed -- a held
## Fluttershy sat with only her ears and mane showing above Twilight's head, and a held
## Rainbow Dash was a coloured smudge behind Twilight's neck. Two things the capsule
## arithmetic left out: the capsule is not the SILHOUETTE (the mane, the ears and the
## horn are all outside it, and her head is what the offset has to clear, not her
## barrel), and the vertical lift was small enough that the held pony landed ON her head
## rather than above it.
##
## The numbers below are sized off the RENDERED frame instead. At the default zoom the
## hold point sits ~5.6 m from the lens, and with a 16:9 viewport (half-width
## tan(hfov/2) = 1.34) 2.4 m across projects to ~256 px of a 800 px half-screen -- about
## two and a half times the player's own on-screen half-width, so the held pony is fully
## in the clear at every zoom the player can select (at SPRING_MIN she is 428 px out,
## still well inside the frame; at SPRING_MAX, 167 px, still clear). The 1.0 m lift puts
## her above the player's back rather than on her head.
##
## Both are perpendicular to the RAY, not to the world, so they stay screen-right and
## screen-up at any pitch. And a bigger offset makes the BEAM more legible too, for free:
## the ribbon from the horn to the held body is longer on screen and less foreshortened.
const HOLD_SIDE := 2.4
const HOLD_LIFT := 1.0

## Floor on the hold distance measured from the CAMERA, in metres. Only bites when the
## player has zoomed all the way in (CameraRig.SPRING_MIN is 1.2 m): without it, a fully
## zoomed-in hold would put a pony 1.2 + 2.2 m away -- fine -- but a future shorter spring
## or a rig mounted somewhere else could push the hold point through the near plane and
## turn a captured pony into a screenful of nostril. Cheap insurance against a number in
## another file changing.
const MIN_HOLD_DISTANCE := 1.6

## Exponential rate at which a held body is reeled toward the hold point, in 1/seconds.
## Framerate-independent (1 - exp(-k*dt)), same idiom as the player's and the pony's turn
## smoothing. At 8.0 a body closes 90% of the gap in ln(10)/8 = 0.29 s, so a pony grabbed
## at the far end of REACH is floating in front of you in about a third of a second: fast
## enough to read as a yank rather than a tow, slow enough that you see her come.
const PULL_RESPONSE := 8.0

## Radius, in metres, of the forgiveness pass -- see _try_acquire(). Half a metre is about
## one pony-capsule diameter, so "I was aiming at the grass just under her hooves" works
## and "I was aiming at the next pony along" does not.
const GRAB_ASSIST_RADIUS := 0.5

## Height above a pony's origin that the hold point should line up with, in metres.
## Exactly the centre of her collision capsule (pony.tscn: height 1.30, centred at 0.65),
## so the crosshair ends up on her barrel rather than on her hooves. Without this she
## floats with her feet where her chest should be and reads as sinking.
const PONY_HOLD_LIFT := 0.65

## Radians per second a held body turns while suspended. Purely feel: a held pony that
## keeps a fixed yaw looks like a bug (a mesh nailed to a point in space), and a slow
## rotation reads as "something else is moving her". ~52 deg/s is one turn every 7 s.
const HELD_SPIN_RATE := 0.9

## Seconds after a body wins its struggle during which the beam refuses to acquire
## anything. Without it, the beam is still on when she breaks free, so it re-grabs her on
## the very next frame and the escape means nothing at all.
const ESCAPE_COOLDOWN := 0.75

## Seconds a held pony resists before she breaks free, by personality. This is the whole
## of the mechanic's tension: you have this long to decide, and how long it is tells you
## something about who you caught.
##
## SHY is the short one (the brief's requirement, and the obvious reading of the trait --
## a pony who runs from you at 5 m is not going to hang about in a magic field), BOLD the
## long one (she was not worried about you on the ground and she is not worried now), and
## CURIOUS sits between them, which matches her behaviour everywhere else: she is the one
## who walks TOWARD the player, so she has the least reason to fight and the most reason
## to stay and see what happens.
##
## The floor on all three is the pull-in: PULL_RESPONSE reels a body to the hold point in
## about 0.3 s, so anything under ~0.8 s would let a pony escape before she had even
## arrived and the player would never see what they caught. 1.5 s leaves a SHY pony about
## 1.2 s of actual float time -- enough to register and release, tight enough to feel like
## a scramble -- and 4.0 s makes a BOLD pony effectively a free catch.
const STRUGGLE_SHY := 1.5
const STRUGGLE_CURIOUS := 2.5
const STRUGGLE_BOLD := 4.0

## Struggle time for anything that is not a pony, in seconds. Props do not resist; a crate
## stays in the beam until the player lets go.
const STRUGGLE_NEVER := INF

@export_group("Storage")
## How many ponies the player can carry. Twelve is a placeholder for whatever the barn
## economy decides in a later phase -- it is a data question, not a beam question.
@export var storage_capacity := 12

## Segments in the beam ribbon. Sixteen is enough that the bow reads as a curve rather
## than as a bent stick at any length the beam can reach.
const BEAM_SEGMENTS := 16

## How far the beam bows sideways, as a fraction of its own length. 0.30 of a typical 4 m
## hold is about 1.2 m of clearance -- comfortably past the player's 0.42 m capsule from
## every camera angle, without the arc looking like it is going somewhere else.
const BOW_FRACTION := 0.30

## How far the beam also lofts upward, as a fraction of its own length. Small, but it is
## what puts the apex of a long reach against the SKY rather than against the green ground
## the pony at the far end is also standing on -- a pink ribbon on grass at 8 m is a lot
## harder to pick out than the same ribbon on grey.
const BOW_LIFT_FRACTION := 0.14

## Half-width of the ribbon at the horn and at the far end, in metres. Narrow where it
## leaves her and flared where it lands, so it reads as something being projected rather
## than as a rod -- and so the far end is still legible at REACH.
const BEAM_WIDTH_NEAR := 0.06
const BEAM_WIDTH_FAR := 0.30

## Radius of the glow at the far end, in metres: a bright bead while the beam is sweeping
## for something, and a wider, fainter aura wrapping whatever it has hold of.
const GLOW_TIP_RADIUS := 0.28
const GLOW_HELD_RADIUS := 0.70

@export_group("Look")
## The beam's colour: Twilight's magic aura. Exported so a future second caster (or a
## debug build) can be told apart at a glance without editing this file.
@export var beam_color := Color(0.98, 0.55, 0.95)

## Optional explicit override for the node providing get_aim_ray() (the CameraRig). Left
## empty, the beam finds it under the Player it is mounted on -- see _resolve_mount().
@export var aim_source_path: NodePath

var _storage: Storage

## The Player this beam is mounted under, and the Marker3D at her horn. Both may be null
## if the beam is used standalone, in which case the beam draws from its own origin.
var _player: Node3D
var _beam_anchor: Node3D
## Whatever answers get_aim_ray() -- normally the CameraRig.
var _aim_source: Node

## The live aim ray, refreshed once per physics frame. Kept as two plain Vectors rather
## than CameraRig.AimRay so the fallback path (no rig at all, just the viewport camera)
## does not have to construct a type that belongs to another file.
var _aim_origin := Vector3.ZERO
var _aim_direction := Vector3.FORWARD

## Is the button down? (Not the same as is_holding(): the beam can be on and empty, which
## is exactly the state you sweep across a field in.)
var _beaming := false

var _held: Node3D
var _hold_seconds := 0.0
var _struggle_seconds := STRUGGLE_NEVER
## Offset from the hold point to the held body's ORIGIN -- see PONY_HOLD_LIFT.
var _hold_offset := Vector3.ZERO
## RigidBody3D state borrowed at grab time and handed back on release.
var _prev_freeze := false
var _prev_freeze_mode := RigidBody3D.FREEZE_MODE_STATIC

var _cooldown := 0.0
## Where the beam visual currently ends when nothing is held: the ray's hit point, or the
## end of its reach.
var _ray_end := Vector3.ZERO
var _elapsed := 0.0

var _beam_mesh: MeshInstance3D
var _beam_material: StandardMaterial3D
var _glow_mesh: MeshInstance3D
var _voice: AudioStreamPlayer
var _voice_played := false
var _assist_shape: SphereShape3D


func _ready() -> void:
	_storage = StorageScript.new(storage_capacity)
	_assist_shape = SphereShape3D.new()
	_assist_shape.radius = GRAB_ASSIST_RADIUS
	_resolve_mount()
	_build_effect()
	_build_voice()
	_hide_effect()


## Hand back anything still in the beam when the beam itself goes away.
##
## THE ONE HOLD-EXIT NOTHING ELSE COVERED. A pony in State.HELD runs no gravity, no
## steering and no move_and_slide -- pony.gd's HELD branch returns before all of it,
## deliberately, so the beam can own her transform. If the beam (or the Player it hangs
## off) is freed mid-hold -- a scene change, a despawn, a level reload -- nothing is left
## to let go of her and she hangs in the air in HELD forever. She does not die, so the
## project rule holds, but "stranded mid-air until the process ends" is not a state any
## pony should be able to reach.
##
## Deliberately NOT release(): a tree being torn down is not the player deciding to
## capture something, and quietly storing a record into a Storage that is about to be
## collected would be a capture nobody asked for and nobody could see. She is simply
## handed back to herself, wherever she was floating.
func _exit_tree() -> void:
	var body := _held
	_held = null
	_beaming = false
	if body == null or not is_instance_valid(body):
		return
	_take_back_physics(body)
	if body is PonyScript:
		body.set_held(false)


# --- public interface -----------------------------------------------------------------

## Switch the beam on. Acquisition happens on the next physics frame (the space-state
## query has to run inside the physics step), so is_holding() is still false immediately
## after this returns -- wait a frame.
func grab() -> void:
	_beaming = true


## Switch the beam off, and settle whatever was in it. A held pony goes into storage if
## there is room -- her record is stored, `captured()` fires, her node is freed -- and
## otherwise is set down in the world unharmed with `capture_refused()`. A held prop just
## drops.
func release() -> void:
	_beaming = false
	var body := _held
	_take_back_physics(body)
	_held = null

	if body != null and is_instance_valid(body):
		if body is PonyScript:
			_settle_pony(body)
	_hide_effect()


## Whether something is in the beam right now.
func is_holding() -> bool:
	return _held != null and is_instance_valid(_held)


## Whether the beam is switched on at all (holding or sweeping for something to hold).
func is_active() -> bool:
	return _beaming


## What is currently in the beam, or null.
func get_held_body() -> Node3D:
	return _held if is_holding() else null


## The player's capture storage. The beam owns it because the beam is what fills it; a
## later inventory/barn system should read it from here rather than making a second one.
func get_storage() -> Storage:
	return _storage


## Seconds the current hold has lasted (0 when nothing is held).
func get_hold_seconds() -> float:
	return _hold_seconds if is_holding() else 0.0


## Seconds the currently held body will resist before breaking free, or INF for something
## that never does.
func get_struggle_seconds() -> float:
	return _struggle_seconds if is_holding() else STRUGGLE_NEVER


## Where a held body is being pulled to right now, in world space.
func get_hold_point() -> Vector3:
	return hold_point(_aim_origin, _aim_direction, _anchor_position())


## How long a pony with this `personality` resists the beam, in seconds. Static and pure,
## so the one rule that makes the three personalities feel different under the beam is
## pinned by a unit test rather than only by a scene (game/test/test_magic_beam.gd).
static func struggle_seconds_for(personality: int) -> float:
	match personality:
		PonyDataScript.Personality.SHY:
			return STRUGGLE_SHY
		PonyDataScript.Personality.CURIOUS:
			return STRUGGLE_CURIOUS
		_:
			# BOLD, and anything a future roster adds without a struggle time of its own.
			return STRUGGLE_BOLD


## The point a held body floats at: `anchor` projected onto the aim ray, plus HOLD_LEAD
## along it (floored at MIN_HOLD_DISTANCE from the ray's origin), then pushed HOLD_SIDE
## screen-right and HOLD_LIFT screen-up so the held body is not hidden behind the player.
## Static and pure so both the zoom invariance and the offset are testable without a
## camera.
static func hold_point(origin: Vector3, direction: Vector3, anchor: Vector3) -> Vector3:
	var along := (anchor - origin).dot(direction)
	var forward := origin + direction * maxf(along + HOLD_LEAD, MIN_HOLD_DISTANCE)

	# Screen-right and screen-up for this ray. UP is the natural reference; RIGHT covers
	# the degenerate case of aiming straight up or straight down, where the first cross
	# product collapses.
	var right := direction.cross(Vector3.UP)
	if right.length_squared() < 0.000001:
		right = direction.cross(Vector3.RIGHT)
	right = right.normalized()
	var up := right.cross(direction).normalized()
	return forward + right * HOLD_SIDE + up * HOLD_LIFT


## How far along the aim ray the beam can reach, given where the player sits on it. Same
## projection as hold_point(), for the same zoom-invariance reason.
static func reach_distance(origin: Vector3, direction: Vector3, anchor: Vector3) -> float:
	return maxf((anchor - origin).dot(direction), 0.0) + REACH


# --- frame ----------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_elapsed += delta
	_cooldown = maxf(0.0, _cooldown - delta)

	if Input.is_action_just_pressed(BEAM_ACTION):
		grab()
	elif Input.is_action_just_released(BEAM_ACTION):
		release()

	# A held body can be freed out from under us by something else entirely (a despawn, a
	# scene change). Notice it here rather than dereferencing a dead node below.
	if _held != null and not is_instance_valid(_held):
		_held = null

	if not _beaming:
		_hide_effect()
		return

	_update_aim()

	# Scanned every frame the beam is on and empty, even during the post-escape cooldown:
	# the scan is also what tells the effect where to END, and skipping it would leave the
	# beam drawn to a stale point for the three quarters of a second after an escape.
	if _held == null:
		_scan(_cooldown <= 0.0)

	if _held != null:
		_pull(delta)
		_run_struggle(delta)

	_draw_effect()


# --- aiming and acquisition -----------------------------------------------------------

## Refresh `_aim_origin`/`_aim_direction` from the camera rig -- or, if this beam is used
## without one, from whatever camera the viewport is actually rendering, projected through
## the screen centre exactly the way CameraRig.get_aim_ray() does it. The fallback exists
## so a test scene can use the beam without dragging a whole rig in, not because the rig
## is optional in the game.
func _update_aim() -> void:
	if _aim_source != null and is_instance_valid(_aim_source):
		var ray = _aim_source.get_aim_ray()
		_aim_origin = ray.origin
		_aim_direction = ray.direction
		return

	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera != null:
		var center: Vector2 = viewport.get_visible_rect().size * 0.5
		_aim_origin = camera.project_ray_origin(center)
		_aim_direction = camera.project_ray_normal(center)
		return

	# No camera at all (a headless unit test): aim straight out of the horn.
	var anchor := _anchor_node()
	_aim_origin = anchor.global_position
	_aim_direction = -anchor.global_transform.basis.z


## Look along the aim ray: record where the beam ends (`_ray_end`, which the effect draws
## to) and, if `can_grab`, take the first grabbable thing found. The two jobs share one
## cast because they are the same cast.
##
## TWO PASSES, and the second one is not padding. A bare ray is unforgiving in exactly the
## situation the mechanic is used in: the camera looks slightly DOWN by default
## (CameraRig.default_pitch_deg is -12), so a crosshair resting on a pony standing on the
## ground reaches her capsule at a very shallow angle and grazes past its bottom into the
## grass -- verified by arithmetic against the actual capsule (radius 0.42, centre 0.65)
## before it was written. So: cast the ray; if it did not land on something grabbable,
## sweep a GRAB_ASSIST_RADIUS sphere at wherever it DID land and take the nearest
## grabbable thing overlapping it. That forgives "I was aiming at the grass under her" and
## nothing wider.
func _scan(can_grab: bool) -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return

	var distance := reach_distance(_aim_origin, _aim_direction, _anchor_position())
	var end := _aim_origin + _aim_direction * distance
	_ray_end = end

	var query := PhysicsRayQueryParameters3D.create(_aim_origin, end)
	query.exclude = _exclusions()
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		_ray_end = hit["position"]
		var body: Object = hit["collider"]
		if can_grab and _is_grabbable(body):
			_begin_hold(body)
			return

	if not can_grab:
		return

	# Forgiveness pass, centred on whatever the ray actually reached.
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _assist_shape
	params.transform = Transform3D(Basis(), _ray_end)
	params.exclude = _exclusions()
	var nearest: Node3D = null
	var nearest_distance := INF
	for result in space.intersect_shape(params, 8):
		var body: Object = result["collider"]
		if not _is_grabbable(body):
			continue
		var candidate := body as Node3D
		var gap: float = candidate.global_position.distance_to(_ray_end)
		if gap < nearest_distance:
			nearest = candidate
			nearest_distance = gap
	if nearest != null:
		_begin_hold(nearest)


## A wild pony, or any loose rigid body. The rigid bodies cost almost nothing to support
## and are the part of the mechanic people play with for its own sake -- a beam that can
## only pick up quest objects is a menu, not a toy.
func _is_grabbable(body: Object) -> bool:
	if body is PonyScript:
		return true
	return body is RigidBody3D


## RIDs the casts must ignore: the player's own body, which the ray starts inside of
## (the camera sits behind her, so a ray from the lens passes straight through her).
func _exclusions() -> Array[RID]:
	var rids: Array[RID] = []
	if _player is CollisionObject3D:
		rids.append((_player as CollisionObject3D).get_rid())
	return rids


# --- holding --------------------------------------------------------------------------

func _begin_hold(body: Node3D) -> void:
	_held = body
	_hold_seconds = 0.0
	_hold_offset = Vector3.ZERO

	if body is PonyScript:
		body.set_held(true)
		_hold_offset = Vector3(0.0, -PONY_HOLD_LIFT, 0.0)
		var data: PonyData = body.get_data()
		_struggle_seconds = struggle_seconds_for(
			data.personality if data != null else PonyDataScript.Personality.BOLD)
		return

	if body is RigidBody3D:
		var rigid := body as RigidBody3D
		_prev_freeze = rigid.freeze
		_prev_freeze_mode = rigid.freeze_mode
		# KINEMATIC rather than STATIC so writing the transform actually moves it (and so
		# it sweeps other bodies out of the way on the trip in) instead of teleporting a
		# static obstacle around the world.
		rigid.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rigid.freeze = true
		_struggle_seconds = STRUGGLE_NEVER


## Reel the held body toward the hold point and turn it slowly while it floats.
func _pull(delta: float) -> void:
	var target := get_hold_point() + _hold_offset
	var weight := 1.0 - exp(-PULL_RESPONSE * delta)
	_held.global_position = _held.global_position.lerp(target, weight)
	_held.rotation.y += HELD_SPIN_RATE * delta


## Count the hold, and hand the body back if it outlasts its struggle time. This is the
## decision pony.gd used to make for itself; it is here now, so there is exactly one clock
## that says what a hold means.
func _run_struggle(delta: float) -> void:
	_hold_seconds += delta
	if _hold_seconds < _struggle_seconds:
		return

	var body := _held
	_take_back_physics(body)
	_held = null
	_cooldown = ESCAPE_COOLDOWN
	if body is PonyScript:
		# break_free() is what releases the hold AND reports escaped() -- the pony still
		# owns the announcement, this file only owns the decision.
		body.break_free()
	escaped.emit(body)


## Undo whatever _begin_hold() borrowed, WITHOUT deciding what the hold meant. Two callers
## want different outcomes afterwards (a release settles the pony, a lost struggle frees
## her), and both want the borrowing undone first.
##
## The yaw reset is not cosmetic: pony.gd documents that a pony's BODY never rotates (only
## her `Visuals` child does, and _update_facing writes that in world terms), so a body left
## spinning by the beam would offset every facing she computes for the rest of her life.
## The beam borrows that yaw for the float and hands it back at zero.
func _take_back_physics(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body is PonyScript:
		body.rotation.y = 0.0
		return
	if body is RigidBody3D:
		var rigid := body as RigidBody3D
		rigid.freeze_mode = _prev_freeze_mode
		rigid.freeze = _prev_freeze


## A released pony: into the bag if there is room, back onto the grass if there is not.
func _settle_pony(pony: Node3D) -> void:
	var data: PonyData = pony.get_data()
	if data != null and _storage.store(data):
		pony.notify_captured()
		pony.queue_free()
		_play_first_capture_voice()
		captured.emit(data)
		return

	# Full bag (or a pony with no record behind her, which is a setup bug rather than a
	# gameplay state). She is set down exactly where she was floating and falls the last
	# couple of metres on her own -- nothing here is allowed to remove her from the world.
	pony.set_held(false)
	capture_refused.emit(pony)


# --- presentation ---------------------------------------------------------------------

## Build the beam effect: a camera-facing ribbon rebuilt from an ImmediateMesh each frame,
## plus a glow at the far end. Built in code rather than in player.tscn so the geometry
## stays next to the maths that shapes it, and so anything that mounts a beam gets the
## effect without having to copy nodes into its own scene.
##
## Both nodes are `top_level`, which is load-bearing: their geometry is written in WORLD
## space every frame (from the horn to a point derived from the camera's aim ray), and
## inheriting the player's transform on top of that would apply her position twice.
func _build_effect() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(beam_color.r, beam_color.g, beam_color.b, 0.85)
	material.emission_enabled = true
	material.emission = beam_color
	material.emission_energy_multiplier = 2.0
	material.disable_receive_shadows = true
	_beam_material = material

	_beam_mesh = MeshInstance3D.new()
	_beam_mesh.name = "BeamMesh"
	_beam_mesh.mesh = ImmediateMesh.new()
	_beam_mesh.top_level = true
	_beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam_mesh)

	# The glow doubles as the aura around a held body, which is why it gets its own,
	# fainter material: at the beam's own opacity a sphere big enough to wrap a pony
	# washes her out to a pink blob.
	var glow_material: StandardMaterial3D = material.duplicate()
	glow_material.albedo_color = Color(beam_color.r, beam_color.g, beam_color.b, 0.4)

	var sphere := SphereMesh.new()
	# Radius 1.0 so the node's scale IS the glow's radius in metres.
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	sphere.material = glow_material

	_glow_mesh = MeshInstance3D.new()
	_glow_mesh.name = "BeamGlow"
	_glow_mesh.mesh = sphere
	_glow_mesh.top_level = true
	_glow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow_mesh)


## Placeholder voice playback. AudioStreamPlayer (not ...3D) because this is the player
## character's own voice, not a sound happening somewhere in the world.
func _build_voice() -> void:
	_voice = AudioStreamPlayer.new()
	_voice.name = "CaptureVoice"
	# load() rather than preload(): a missing take must not be a parse error that takes
	# the whole beam -- and with it the core mechanic -- down with it.
	var stream := load(VOICE_LINE)
	if stream is AudioStream:
		_voice.stream = stream
	else:
		push_warning("MagicBeam: no voice line at '%s'; captures will be silent" % VOICE_LINE)
	add_child(_voice)


func _play_first_capture_voice() -> void:
	if _voice_played or _voice == null or _voice.stream == null:
		return
	_voice_played = true
	_voice.play()


## Draw the beam from the horn to its far end and park the glow at that end.
##
## WHY THE BEAM IS AN ARC AND NOT A STRAIGHT LINE. A straight beam from the horn to
## whatever the crosshair is on points almost directly AWAY from the camera in this rig
## (the camera sits behind the player and the crosshair is the screen centre), so it
## projects to a few pixels -- and those few pixels land behind the player's own body.
## The first offscreen render of this task showed a capture happening with no visible beam
## at all. Bowing the beam sideways, out past the player's silhouette, is what makes it
## read: the arc is longer on screen than the straight line was, and none of it is hidden.
## The bow is taken toward the CAMERA's right so it stays clear whatever direction the
## player is facing, which is the same reasoning HOLD_SIDE is built on.
func _draw_effect() -> void:
	var from := _anchor_position()
	var to := _ray_end
	if is_holding():
		# Connect to the held body's CENTRE, not its origin, or the beam visibly ends at
		# a floating pony's hooves.
		to = _held.global_position - _hold_offset

	var span := to - from
	var length := span.length()
	if length < 0.05:
		_hide_effect()
		return

	var camera := get_viewport().get_camera_3d() if get_viewport() != null else null
	var eye: Vector3 = camera.global_position if camera != null else _aim_origin

	# Horizontal perpendicular to the beam, flipped to whichever side is camera-right.
	var side := span.cross(Vector3.UP)
	if side.length_squared() < 0.000001:
		side = span.cross(Vector3.RIGHT)
	side = side.normalized()
	if camera != null and side.dot(camera.global_transform.basis.x) < 0.0:
		side = -side
	var control := from + span * 0.5 + side * (length * BOW_FRACTION) \
		+ Vector3.UP * (length * BOW_LIFT_FRACTION)

	# ONE ribbon plane for the whole beam, perpendicular to both the beam and the line of
	# sight to its middle. Deriving the strip's width direction PER SEGMENT (from each
	# point's own line of sight) is the obvious thing to do and it is wrong: when the beam
	# points nearly at or away from the eye, that direction sweeps through 180 degrees
	# along the beam, the strip twists through itself, and the whole effect renders as a
	# row of bow ties -- which is exactly what the offscreen render of a held crate showed.
	# A single plane cannot twist. The arc's bow is small enough that facing the eye at the
	# midpoint is right for the whole length.
	var across_dir := span.cross(eye - (from + to) * 0.5)
	if across_dir.length_squared() < 0.000001:
		# Beam pointing straight at the eye: any perpendicular will do.
		across_dir = span.cross(Vector3.UP)
		if across_dir.length_squared() < 0.000001:
			across_dir = span.cross(Vector3.RIGHT)
	across_dir = across_dir.normalized()

	var mesh: ImmediateMesh = _beam_mesh.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _beam_material)
	for i in range(BEAM_SEGMENTS + 1):
		var t := float(i) / float(BEAM_SEGMENTS)
		var point := _bezier(from, control, to, t)
		var across := across_dir * lerpf(BEAM_WIDTH_NEAR, BEAM_WIDTH_FAR, t)
		mesh.surface_add_vertex(point - across)
		mesh.surface_add_vertex(point + across)
	mesh.surface_end()

	_beam_mesh.global_transform = Transform3D.IDENTITY
	_beam_mesh.visible = true

	# At the far end: a bright bead when the beam is sweeping for something, and a wider,
	# fainter aura once it has hold of a body (a bead would simply be buried inside her).
	# The slow pulse keeps the effect visibly alive in a still frame as well as in motion.
	var radius := GLOW_HELD_RADIUS if is_holding() else GLOW_TIP_RADIUS
	var pulse := radius * (1.0 + 0.1 * sin(_elapsed * 9.0))
	_glow_mesh.global_transform = Transform3D(Basis().scaled(Vector3.ONE * pulse), to)
	_glow_mesh.visible = true


## Quadratic Bezier through `control`, used for the beam's bow.
static func _bezier(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	var inv := 1.0 - t
	return a * (inv * inv) + control * (2.0 * inv * t) + b * (t * t)


func _hide_effect() -> void:
	if _beam_mesh != null:
		_beam_mesh.visible = false
	if _glow_mesh != null:
		_glow_mesh.visible = false


# --- mounting -------------------------------------------------------------------------

## Find the Player this beam hangs off, her horn marker, and the camera rig that answers
## get_aim_ray(). All three are optional: a beam with none of them still works, drawing
## from its own origin along the viewport camera's crosshair, which is what lets a test
## scene exercise it without assembling a whole character.
func _resolve_mount() -> void:
	var node := get_parent()
	while node != null:
		if node.has_method("get_beam_origin"):
			_player = node
			break
		node = node.get_parent()

	# The horn marker is deliberately NOT fetched here -- see _anchor_node().

	if not aim_source_path.is_empty():
		_aim_source = get_node_or_null(aim_source_path)
	if _aim_source == null and _player != null:
		for child in _player.find_children("*", "", true, false):
			if child.has_method("get_aim_ray"):
				_aim_source = child
				break


## The horn the beam is drawn from, resolved LAZILY and cached -- which is not a style
## choice, it is a bug fix. Godot runs a child's _ready() before its parent's, and
## Player.get_beam_origin() hands back an `@onready` var that the Player has not assigned
## yet at that point. Asking for it during this node's _ready() therefore returns null,
## silently falls through to `self`, and the beam draws out of the player's HOOVES
## instead of her horn -- which is exactly what the second offscreen render of this task
## showed, with every numeric check still green. Resolving on first use instead means the
## answer is asked for after the whole tree is ready.
func _anchor_node() -> Node3D:
	if (_beam_anchor == null or not is_instance_valid(_beam_anchor)) and _player != null:
		_beam_anchor = _player.get_beam_origin()
	if _beam_anchor != null and is_instance_valid(_beam_anchor):
		return _beam_anchor
	return self


## The node the beam is drawn from -- the player's horn marker when mounted on her.
## Exposed so a gate can assert it really is the horn (see above).
func get_beam_anchor() -> Node3D:
	return _anchor_node()


func _anchor_position() -> Vector3:
	return _anchor_node().global_position
