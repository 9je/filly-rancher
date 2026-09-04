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
##   `get_magic_beam()`      -- Task 8's beam, and through it the capture storage.
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
## There are two locomotion clips, `walk` (0.66 m/s) and `gallop` (3.30 m/s), and Gait
## owns the whole ladder: which one to play at a given ground speed, and what playback
## rate keeps its hooves planted. This script must not re-derive any of that. The two
## speeds below are the only gameplay choices:
##   RUN_SPEED   = 5.20 m/s = the `gallop` clip saturated at Gait.GALLOP_MAX_PLAYBACK and
##      then some. Skate ratio 1.21 -- a BUDGETED deviation, see below. THE DEFAULT.
##   SNEAK_SPEED = 1.32 m/s = 2.0x playback of `walk`. Zero skate. Held modifier.
##
## RUNNING IS NOW THE DEFAULT AND `sneak` (Shift/LB) IS A HOLD-TO-WALK MODIFIER. That is
## the inversion the SECOND playtest asked for, in the owner's own words: "walk speed is
## painfully slow still; running feels good, maybe a tad too slow" plus "make running the
## default and Shift a hold-to-walk-slowly modifier, framed as a stealth option". Both
## halves of that are one change, and the second half is what makes it more than a
## convenience: Pony.notice_radius_for() halves a pony's notice radius against a SNEAKING
## player, so the slow gait BUYS something (see the sneak section in pony.gd). A modifier
## that only ever costs you speed is a modifier nobody holds; a modifier that trades speed
## for not being seen is a decision.
##
## The history, since two rounds of retuning have now passed over these numbers:
##   walk   1.32 -> 1.65 (playtest 1: "move speed a bit slow") -> 1.32 as the SNEAK speed
##          (playtest 2: it is no longer the speed you travel at, it is the speed you
##          creep at, and creeping is supposed to be slow). Exactly 2.0x of the `walk`
##          clip, so it still costs nothing at all.
##   gallop 4.00 -> 4.80 (playtest 1) -> 5.20 as RUN_SPEED (playtest 2: "running feels
##          good, maybe a tad too slow still").
##
## THE RUN SPENDS FOOT SKATE, ON PURPOSE. Gait.TOP_SKATE_FREE_SPEED -- the fastest speed
## ANY authored clip can depict with the hooves planted -- is 4.29 m/s, so 5.20 asks the
## saturated `gallop` clip to carry 21% more ground than it depicts. Gait.skate_ratio()'s
## perceptibility ladder starts noticing at ~1.25 and calls 2.0 unmistakable moonwalking,
## so 1.21 is at the top of the "not perceptible in motion" band rather than past it, and
## game/test/test_player.gd pins that budget at 1.25 so the next "it still feels a bit
## slow" goes red instead of shipping.
##
##      It buys two things a skate-free 4.29 could not. First, 4.29 is only 7% up on the
##      ORIGINAL number and a player cannot feel 7%. Second and more important, 4.29 is
##      exactly the ceiling Pony.flee_speed_for() clamps a fleeing pony to -- so at 4.29
##      the fastest possible bolt TIES the player and a chase never closes. At 5.20 the
##      player is strictly faster than anything that can run from her, by construction,
##      for any base_speed a future roster invents, with 0.9 m/s of closing speed even in
##      the worst case. The honest fix for the whole band is a faster authored gallop
##      cycle (tools/author_anims.py), which is an animation task, not a tuning one.
##
##      Now that running is the DEFAULT, this skate is also what the player sees most of
##      the time rather than only while a button is held. That is a real cost and it was
##      weighed: the alternative is a default travel speed of 4.29 m/s, which is the exact
##      speed the owner has already called too slow twice.
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
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const CutieMarkScript := preload("res://systems/cutie_mark.gd")
const SoundScript := preload("res://systems/sound.gd")

## The input action held to WALK instead of running. Named `sneak` rather than `walk`
## because slowness is not what it is FOR -- see is_sneaking() and Pony.SNEAK_NOTICE_FACTOR.
## It was called `gallop` and meant the opposite until the second playtest.
const SNEAK_ACTION := &"sneak"

## Ground speed at full stick / any WASD key, with nothing held. THE DEFAULT. Sits 21%
## past what the `gallop` clip can honestly depict (Gait.TOP_SKATE_FREE_SPEED is 4.29 m/s)
## -- a deliberate, budgeted amount of foot skate, bought for the reasons the class comment
## sets out. game/test/test_player.gd pins the size of that budget, so it is a number
## somebody chose and not a number that drifted.
##
## Deliberately NOT read from PonyData.base_speed (Twilight's is 3.4). That field is
## documented as a race stat used from Phase 3 (docs/.../design.md), so its numbers
## exist to balance races against each other, not to be metres per second. Wiring the
## player's feel to it would mean a Phase 3 balance pass silently retuning how the
## game handles -- and would make Rainbow Dash's 6.5 a 6.5 m/s player character the
## moment anyone made her playable. If a later phase decides base_speed really is
## m/s, this is a one-line change with a test to update, which is the cheap direction
## for that decision to go.
const RUN_SPEED := 5.2

## Ground speed with `sneak` held: a slow, quiet walk. Exactly 2.0x Gait.WALK_CLIP_SPEED,
## so the walk clip plays at 2.0x with the hooves planted and this costs nothing at all.
## Written as a multiple of the clip speed rather than as 1.32 so it cannot drift out of
## the walk band if the clip is ever re-authored; the band's ceiling is Gait.MAX_PLAYBACK
## (3.0x), and staying strictly under it is what keeps clip_for_speed() answering `walk`
## rather than handing a sneaking player over to the gallop clip.
##
## SLOWER THAN THE OLD DEFAULT WALK (1.65 m/s), WHICH IS NOT AN OVERSIGHT. The owner called
## 1.65 "painfully slow" as a TRAVEL speed and he was right -- so it stopped being the
## travel speed. What is left here is a creep you choose, and a creep that moved at three
## quarters of a running pace would not read as quiet. The price is the point: at 1.32 m/s
## you cannot close on a fleeing pony at all (Fluttershy bolts at 2.48), so sneaking is
## strictly a way of not making her flee in the first place.
const SNEAK_SPEED := 2.0 * GaitScript.WALK_CLIP_SPEED

## HOOFSTEPS ARE A FUNCTION OF DISTANCE, NOT OF TIME. One step every STEP_STRIDE metres
## actually travelled, so sneaking gives a walk and running gives a gallop out of one
## constant instead of two that would drift apart. At RUN_SPEED this is roughly five steps
## a second across four hooves.
const STEP_STRIDE := 1.1
## Below this she is shuffling, not walking, and a sound there is a sound with no gesture
## behind it.
const STEP_MIN_SPEED := 0.4
const SURFACE_GRASS := &"hoofsteps_grass"
const SURFACE_HARD := &"hoofsteps_hard"

## Peak of a standing jump, in metres. 0.9 m is about three quarters of her withers
## height (1.163 m) -- a pony-sized hop rather than a platformer leap.
const JUMP_HEIGHT := 0.9

## Crossfade seconds between locomotion clips. One value for every transition: the
## walk/gallop handover happens at a speed both clips depict exactly (Gait.
## GALLOP_HANDOVER_SPEED), so there is nothing to hide and no reason for it to be
## faster or slower than the idle/walk one.
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
## The base record the player's body is built from. A HIDDEN record
## (game/systems/pony_registry.gd HIDDEN_DIR), because the player is not a collectible and
## must not appear in the Compendium; and the same record the crowd is built from, because
## the recolour is one pipeline with two users. Twilight Sparkle has left the player slot
## and may join the catchable roster in a later phase's authoring.
@export var pony_id: StringName = &"stock_shy"
@export_dir var pony_dir := "res://data/ponies"

@onready var camera_pivot: Node3D = $CameraPivot
@onready var visuals: Node3D = $Visuals
@onready var beam_origin: Node3D = $Visuals/BeamOrigin
@onready var magic_beam: Node3D = $MagicBeam

var _anim: AnimationPlayer
var _visual_yaw := 0.0
var _coyote_left := 0.0
var _jump_buffered := 0.0
var _step_distance := 0.0
var _step_surface: StringName = SURFACE_GRASS

## The mane style the body currently standing in Visuals was built from. apply_look()
## compares against it: a tint can be re-applied to a body that already exists, a different
## mesh cannot, so a change here means a rebuild.
var _mane_style_built := 0


func _ready() -> void:
	_visual_yaw = visuals.rotation.y
	_build_visuals()


## The node the magic beam originates from (Task 8). Sits at the horn tip and follows her
## facing, since it hangs off `Visuals` rather than off the body. Its position is MEASURED
## from the model at spawn -- see `_place_beam_origin`.
func get_beam_origin() -> Node3D:
	return beam_origin


## Where a camera rig should be mounted (Task 5). Deliberately does NOT inherit the
## character's facing -- see the class comment.
func get_camera_pivot() -> Node3D:
	return camera_pivot


## The magic beam (Task 8), and through `get_storage()` on it, everything the player has
## caught. A sibling of `Visuals` rather than a child of it: the beam AIMS along the
## camera's crosshair, never along her facing (see magic_beam.gd), so hanging it off the
## yawing node would be actively misleading about where it points. Only `BeamOrigin` --
## the horn the effect is DRAWN from -- lives under `Visuals`.
func get_magic_beam() -> Node3D:
	return magic_beam


## Ground speed right now, in m/s, ignoring vertical motion.
func get_ground_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Whether the player is choosing to move quietly -- i.e. holding `sneak`.
##
## READ BY THE PONIES, not just by this controller. Pony._sees_player() calls this through
## a has_method() check (a test stand-in in the `player` group is not a Player and does not
## have to grow one), and Pony.notice_radius_for() halves her notice radius when it is
## true. So this is a gameplay interface, not an input detail, and it deliberately answers
## the question about INTENT rather than about velocity: it is true while standing still
## with Shift held, which is what lets a player stop dead and let a spooked pony settle.
## Keying it off `get_ground_speed() < something` instead would make "am I being quiet"
## unanswerable at a standstill and would flicker across the threshold while accelerating.
func is_sneaking() -> bool:
	return Input.is_action_pressed(SNEAK_ACTION)


## The body's AnimationPlayer, or null if the visuals failed to build. Exposed so
## scenes and tests can assert which clip is playing and at what rate without
## re-deriving PonyVisuals.ANIMATION_PLAYER_PATH against the model tree.
func get_animation_player() -> AnimationPlayer:
	return _anim


## Wear `look`: the palette tint and the cutie mark, on the body already built. Called by
## ranch.gd at boot and again whenever a load replaces GameState.player, so the pony on
## screen is always the pony the save describes.
##
## THE SAME StockTint THE CROWD GOES THROUGH, deliberately: one pipeline, two users, and no
## second path that could drift.
func apply_look(look: PlayerLook) -> void:
	if look == null:
		return
	if look.mane_style != _mane_style_built:
		_rebuild_visuals(look.mane_style)
	if visuals.get_child_count() == 0:
		return
	var body: Node3D = visuals.get_child(0)
	StockTintScript.apply(body, StockPaletteScript.load_player(),
		{"coat": look.coat, "mane": look.mane, "eyes": look.eyes})
	CutieMarkScript.apply(body, look.mark())


## Swap the body for one built from a different base model. Freed outright rather than
## queue_free()'d, for game/world/race_runner.gd's reason: a queued node is still among
## get_children() until the end of the frame, so the "body is child 0 of Visuals"
## convention this whole file rests on would be false for a frame.
func _rebuild_visuals(mane_style: int) -> void:
	if visuals.get_child_count() > 0:
		var old: Node = visuals.get_child(0)
		visuals.remove_child(old)
		old.free()
	_anim = null
	_build_visuals(mane_style)


## Which surface she is walking on. Set by ranch.gd, which is the only thing that knows
## what a region is; an unknown id is refused so a typo cannot turn every step in the rest
## of the session into a push_error.
func set_step_surface(id: StringName) -> void:
	if id != SURFACE_GRASS and id != SURFACE_HARD:
		push_error("Player.set_step_surface: '%s' is not a surface" % id)
		return
	_step_surface = id


func step_surface() -> StringName:
	return _step_surface


func step_distance() -> float:
	return _step_distance


## Roll the accumulator forward and answer whether a hoof landed this frame. Pure: it makes
## no sound and reads no node, which is what lets the suite drive it with numbers.
func accumulate_step(speed: float, delta: float, on_floor: bool) -> bool:
	if not on_floor or speed < STEP_MIN_SPEED or delta <= 0.0:
		_step_distance = 0.0
		return false
	_step_distance += speed * delta
	if _step_distance < STEP_STRIDE:
		return false
	_step_distance -= STEP_STRIDE
	return true


## get_node(), not the bare `Sound` identifier: tools/run_tests.sh's parse sweep runs every
## .gd file through `--check-only --script`, and that pass never boots the scene tree, so
## an autoload's name is never registered as a resolvable global identifier there, even
## though it resolves fine in a real run (the game, or GUT's own actual test pass). See
## magic_beam.gd's own copy of this same dispatcher.
##
## is_inside_tree() first, so a player built with `.new()` and never added anywhere (this
## file's own suite) gets a silent no-op rather than the engine error get_node() prints on
## a treeless node.
func _sound_call(method: StringName, args: Array) -> void:
	if not is_inside_tree():
		return
	var node: Node = get_node_or_null(^"/root/Sound")
	if node != null:
		node.callv(method, args)


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
	var top_speed := SNEAK_SPEED if is_sneaking() else RUN_SPEED
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
	if accumulate_step(get_ground_speed(), delta, is_on_floor()):
		_sound_call(&"play_at", [_step_surface, global_position])


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


## Pick `idle` / `walk` / `gallop` and scale playback so the gait matches the ground.
## Both decisions are Gait's -- deliberately not an if-ladder over speed constants here,
## because this is the third scene that would have needed editing when the gallop clip
## was added. All the reasoning about the bands and the resulting skate lives in
## game/systems/gait.gd; this function must not grow its own speed constants.
func _update_animation(speed: float) -> void:
	if _anim == null:
		return
	var clip := GaitScript.clip_for_speed(speed)
	_play(clip)
	_anim.speed_scale = GaitScript.playback_scale_for_clip(clip, speed)


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
func _build_visuals(mane_style: int = 0) -> void:
	var registry := PonyRegistryScript.new()
	registry.load_all(pony_dir)
	# by_id() rather than the dictionary load_all() returns: the player's own record is a
	# HIDDEN one (game/systems/pony_registry.gd HIDDEN_DIR), resolvable by id and absent
	# from every listing, and the returned dictionary is the listing.
	var data: PonyData = registry.by_id(pony_id)
	if data == null:
		push_error("Player: no PonyData with id '%s' in '%s' or in the hidden records"
			% [pony_id, pony_dir])
		return

	var pony: Node3D = PonyVisualsScript.build(data,
		StockPaletteScript.mane_style_path(mane_style))
	if pony == null:
		push_error("Player: PonyVisuals.build failed for '%s'" % pony_id)
		return
	_mane_style_built = mane_style

	visuals.add_child(pony)
	# INDEX 0, ALWAYS. `Visuals` already carries `BeamOrigin` as a scene-authored child
	# (player.tscn), so a plain add_child() would leave the body at index 1 -- unlike
	# game/actors/pony/pony.gd, whose Visuals starts empty. apply_look() below, and the
	# crowd's own `visuals.get_child(0)` convention (pony.gd's _apply_stock_tint()), both
	# read "the body" as the FIRST child of Visuals; this is what keeps that reading true
	# for the player too.
	visuals.move_child(pony, 0)
	_place_beam_origin(pony)
	_anim = pony.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH)
	if _anim == null:
		# PonyVisuals.build() refuses to return an instance without one, so this is
		# unreachable unless that contract changes -- assert it rather than assume it.
		push_error("Player: no AnimationPlayer at %s" % PonyVisualsScript.ANIMATION_PLAYER_PATH)
		return
	_play("idle")


## Move `BeamOrigin` onto the actual tip of the actual horn of the actual model.
##
## The owner, first playtest: "beam doesn't come from horn". It did not: the marker sat
## hand-placed at (0, 2.00, -0.30) in `player.tscn`, while Twilight's horn tip is at
## (0.00, 2.13, -0.85) -- 0.55 m short along her forward axis, which puts the emitter
## inside her skull, level with the cheek. It reads as a beam sprouting from her muzzle.
##
## Measured rather than hand-tuned, and measured PER MODEL rather than hardcoded for
## Twilight: `pony_id` is an exported field, so the day someone plays a different unicorn
## a literal here would be wrong again and nothing would catch it. The horn ships as its
## own mesh object in every CreatorOfPony pack (`Base_Horn`, bone-parented to DEF_Head),
## so the tip is just its highest vertex -- deliberately the geometry and not the bounding
## box, because the horn is a cone RAKED FORWARD and every corner of its box is somewhere
## the horn is not: measured, the box's highest corner sits 0.31 m behind the real tip and
## 0.08 m off the centre line, which is over half the error this function exists to fix.
##
## Falls back silently to whatever `player.tscn` holds for a model with no horn mesh --
## an earth pony or a pegasus has no horn to fire from, and that is a design question,
## not a crash. The value in the scene is Twilight's measured tip, so the fallback is at
## least a sane place rather than a guess.
func _place_beam_origin(pony: Node3D) -> void:
	var horn := pony.find_child("Base_Horn", true, false)
	if not (horn is MeshInstance3D):
		return
	var mesh := horn as MeshInstance3D
	if mesh.mesh == null:
		return
	# Bone-parented parts hang off a BoneAttachment3D that has not resolved its pose yet
	# this early in _ready; without this the horn still reads at the skeleton's origin.
	pony.force_update_transform()
	var to_visuals := visuals.global_transform.affine_inverse() * mesh.global_transform
	var tip := Vector3(0.0, -INF, 0.0)
	for surface in mesh.mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var local: Vector3 = to_visuals * vertex
			if local.y > tip.y:
				tip = local
	if is_finite(tip.y):
		beam_origin.position = tip
