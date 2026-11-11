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
## ANY authored clip can depict with the hooves planted -- is 4.79 m/s (it was 4.29 until
## slice R3's GALLOP_MAX_PLAYBACK retune, see gait.gd), so 5.20 asks the saturated `gallop`
## clip to carry 8.7% more ground than it depicts, down from 21% before the retune.
## Gait.skate_ratio()'s perceptibility ladder starts noticing at ~1.25 and calls 2.0
## unmistakable moonwalking, so 1.087 sits comfortably inside the "not perceptible in
## motion" band rather than at the top of it, and game/test/test_player.gd pins that
## budget at 1.25 so the next "it still feels a bit slow" goes red instead of shipping.
##
##      It buys two things a skate-free 4.79 could not. First, before the retune 4.29 was
##      only 7% up on the ORIGINAL number (4.00) and a player cannot feel 7% -- the retune
##      moved the skate-free ceiling to 20% up on that same original, which is no longer
##      too small to feel, so this half of the argument has weakened; it is reason two that
##      still carries the decision. Second and more important, the skate-free ceiling is
##      exactly what Pony.flee_speed_for() clamps a fleeing pony to -- so running at it
##      TIES the fastest possible bolt and a chase never closes. At 5.20 the player is
##      strictly faster than anything that can run from her, by construction, for any
##      base_speed a future roster invents, with 0.42 m/s of closing speed in the worst
##      case (0.9 m/s before the retune narrowed the ceiling's distance from RUN_SPEED).
##      The honest fix for the whole band is a faster authored gallop cycle
##      (tools/author_anims.py), which is an animation task, not a tuning one.
##
##      Now that running is the DEFAULT, this skate is also what the player sees most of
##      the time rather than only while a button is held. That is a real cost and it was
##      weighed: the alternative is a default travel speed of 4.79 m/s (formerly 4.29),
##      close enough to the 4.00 the owner already called too slow that it still risks the
##      same complaint.
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
const PonyRigScript := preload("res://scripts/pony_rig.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const BodySpaceScript := preload("res://systems/body_space.gd")
const PonyVisualsScript := preload("res://actors/pony/pony_visuals.gd")
const StockPaletteScript := preload("res://systems/stock_palette.gd")
const StockTintScript := preload("res://systems/stock_tint.gd")
const CutieMarkScript := preload("res://systems/cutie_mark.gd")
const PonyPaintScript := preload("res://systems/pony_paint.gd")
const DonorTableScript := preload("res://systems/donor_table.gd")
const TerrainScript := preload("res://world/terrain.gd")
const LayersScript := preload("res://world/collision_layers.gd")

## The input action held to WALK instead of running. Named `sneak` rather than `walk`
## because slowness is not what it is FOR -- see is_sneaking() and Pony.SNEAK_NOTICE_FACTOR.
## It was called `gallop` and meant the opposite until the second playtest.
const SNEAK_ACTION := &"sneak"
## HOLD SHIFT TO SPRINT (owner playtest 2026-10-25, "i dont like that i cant run"): the
## default gait is already a run, so the sprint is half again on top of it. Sneak moved to C.
const SPRINT_ACTION := &"sprint"
const SPRINT_MULT := 1.5

## Ground speed at full stick / any WASD key, with nothing held. THE DEFAULT. Sits 8.7%
## past what the `gallop` clip can honestly depict (Gait.TOP_SKATE_FREE_SPEED is 4.79 m/s,
## down from 21% past 4.29 m/s before slice R3's GALLOP_MAX_PLAYBACK retune) -- a
## deliberate, budgeted amount of foot skate, bought for the reasons the class comment
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

## HOOFSTEPS LAND ON THE ANIMATION'S OWN FOOTFALLS. Not on distance, not on a timer, and
## (since the audit of 2026-10-24) not once per cycle either: every clip's footfalls are read
## out of the clip itself -- the moment each of the four IK hoof targets (IK_FrontHoof.L/R,
## IK_RearHoof.L/R, which tools/author_anims.py keys and the rig plants) comes down onto
## its stance height -- and a hoofstep plays whenever the AnimationPlayer's position crosses
## one. Hooves that land together (the walk's diagonal pairs) are one sound. That gives the
## walk two beats a cycle and the gallop its four, exactly where the hooves hit, at every
## playback rate, through every crossfade.
##
## HISTORY. One sound every 1.1 m travelled lined up with nothing on screen. One per cycle
## (slice R3) landed on ONE hoof of four in the gallop and one pair of two in the walk: the
## other footfalls were silent, so the run read as a single sample looping at the cycle rate
## rather than as hooves -- and that sample was a field recording lifted 16 dB, room tone
## and all (tools/sound_manifest.txt, the hoofsteps block). See
## game/test_input/test_footsteps.gd, which watches the visible hoof bones and the Sound
## pool together, and docs/playtest_fixes/audio.md.
##
## Below this she is shuffling, not walking, and a sound there is a sound with no gesture
## behind it.
const STEP_MIN_SPEED := 0.4
## The five surface sets (Sound.LIBRARY ids). Which one plays is decided per footfall by
## what is under her: see surface_for().
const SURFACE_GRASS := &"hoof_grass"
const SURFACE_DIRT := &"hoof_dirt"
const SURFACE_WOOD := &"hoof_wood"
const SURFACE_STONE := &"hoof_stone"
const SURFACE_METAL := &"hoof_metal"
const SURFACES: Array[StringName] = [SURFACE_GRASS, SURFACE_DIRT, SURFACE_WOOD, SURFACE_STONE,
	SURFACE_METAL]
## A collider (or one of its first few ancestors) carrying this meta names its own surface:
## building.gd tags itself wood, factory_interior.gd tags its floors metal or stone.
const SURFACE_META := &"step_surface"
## The IK hoof targets whose position tracks say when a hoof is down, front pair first.
const HOOF_TARGETS: Array[String] = ["IK_FrontHoof.L", "IK_FrontHoof.R", "IK_RearHoof.L",
	"IK_RearHoof.R"]
## A hoof is down when its target is within this of its lowest height in the clip.
const HOOF_CONTACT_EPS := 0.002
## Touchdowns closer than this (clip seconds) are one sound.
const FOOTFALL_MERGE := 0.012
## A rear hoof lands this much under a front one: the forehand carries the weight, and
## the accent is what makes four beats read as a gait rather than a drum machine.
const REAR_ACCENT_DB := -1.5

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
## Landing faster than this (m/s, a jump comes down at about 4) bounces her hindquarters.
const LAND_BOUNCE_FROM := 3.0
## A STUMBLE ON A HARD LANDING (PS10 gap G4; FS4.3). A normal jump lands at about 4.2 m/s with
## the bounce alone; from this fall speed (about a 1.8 m drop) she also pitches forward and
## back and is slowed for STUMBLE_SECONDS.
const STUMBLE_FROM := 6.0
const STUMBLE_SECONDS := 0.55
const STUMBLE_PITCH := 0.55
const STUMBLE_SLOW := 0.45
var _stumble_left := 0.0


## How hard a landing at `fall_speed` stumbles her, 0 (not at all) to 1.
static func stumble_for(fall_speed: float) -> float:
	if fall_speed < STUMBLE_FROM:
		return 0.0
	return clampf(0.5 + (fall_speed - STUMBLE_FROM) / 8.0, 0.0, 1.0)


## Pitch her forward and back, and slow her for a moment. The pitch is drawn by
## _update_facing() from the stumble's own clock (stumble_pitch()), beside the yaw and lean
## it already sets, so nothing else writing her rotation can flatten it.
var _stumble_strength := 0.0


func stumble(strength: float) -> void:
	if strength <= 0.0 or visuals == null:
		return
	_stumble_left = STUMBLE_SECONDS
	_stumble_strength = strength


## Her forward pitch (radians, negative is nose down) `left` seconds before a stumble of
## `strength` ends: a quick dip, then a wobble back to straight.
static func stumble_pitch(left: float, strength: float) -> float:
	if left <= 0.0 or strength <= 0.0:
		return 0.0
	var u := 1.0 - left / STUMBLE_SECONDS
	var f := sin(u / 0.22 * PI * 0.5) if u < 0.22 else exp(-5.0 * (u - 0.22)) * cos(8.0 * (u - 0.22))
	return -STUMBLE_PITCH * strength * f


## The share of her speed a stumble leaves her (1.0 when she is not stumbling).
func stumble_slow() -> float:
	return STUMBLE_SLOW if _stumble_left > 0.0 else 1.0

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
var _hair: SpringBoneSimulator3D = null
var _visual_yaw := 0.0
var _coyote_left := 0.0
var _jump_buffered := 0.0
var _step_clip: StringName = &""
var _step_position := 0.0
## The surface for open ground (the Terrain off the path): grass, or stone on the Strip.
## Set by ranch.gd, the one thing that knows what a region is.
var _step_surface: StringName = SURFACE_GRASS
## Clip name to its footfalls, [{t: clip seconds, rear: bool}], read once per clip.
var _footfall_cache: Dictionary = {}
## Whether the footfall step_on_clip() last fired was a rear hoof alone.
var _last_footfall_rear := false

## A hoofstep was just played: which set, and whether it was a rear hoof.
signal hoofstep(surface: StringName, rear: bool)

## The mane style the body currently standing in Visuals was built from. apply_look()
## compares against it: a tint can be re-applied to a body that already exists, a different
## mesh cannot, so a change here means a rebuild.
var _mane_style_built := 0
## The donor body standing in Visuals now (v1), so apply_look() rebuilds only on a change.
var _donor_built: StringName = &""
var _worn: PonyLook


## The look she is wearing now (what PonyPaint was last handed), or null before any.
func current_look() -> PonyLook:
	return _worn


func _enter_tree() -> void:
	BodySpaceScript.join(self)


func _exit_tree() -> void:
	BodySpaceScript.leave(self)


## Her footprint for BodySpace (PT4): ponies, townsfolk and Tumble make room for her; she is
## never shoved herself (weight 0), so a road or a doorway always stays hers to walk.
func body_footprint() -> Dictionary:
	return BodySpaceScript.default_footprint(self, 0.0)


func _ready() -> void:
	_visual_yaw = visuals.rotation.y
	_visuals_rest = visuals.position
	BlobShadow.attach(self, 2.1, 1.1)
	_pivot_rest = camera_pivot.position
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
## with sneak (C) held, which is what lets a player stop dead and let a spooked pony settle.
## Keying it off `get_ground_speed() < something` instead would make "am I being quiet"
## unanswerable at a standstill and would flicker across the threshold while accelerating.
func is_sneaking() -> bool:
	return Input.is_action_pressed(SNEAK_ACTION)


## RUN IS A TOGGLE (owner playtest 2026-11-10, item 75: "im holding shift at all times ... i
## like toggle"). She starts running; a press of `sprint` (Shift) drops her to the plain gait
## and the next press brings the run back. Sneak (C, held) still wins while it is held.
var sprint_on := true


func toggle_sprint() -> void:
	sprint_on = not sprint_on


## Running (the toggle is on) and not sneaking.
func is_sprinting() -> bool:
	return sprint_on and not is_sneaking()


## The body's AnimationPlayer, or null if the visuals failed to build. Exposed so
## scenes and tests can assert which clip is playing and at what rate without
## re-deriving PonyVisuals.ANIMATION_PLAYER_PATH against the model tree.
func get_animation_player() -> AnimationPlayer:
	return _anim


## The influence the hair simulator is being held at right now, or 1.0 for a body with no
## hair simulation. Exposed so the suite can assert that the speed rule actually reached the
## node rather than only that the arithmetic is right -- the same seam docs/notes-hair-sim.md
## section 10.2 was caught on.
func hair_influence() -> float:
	return _hair.influence if _hair != null else 1.0


## Wear `look`: the palette tint and the cutie mark, on the body already built. Called by
## ranch.gd at boot and again whenever a load replaces GameState.player, so the pony on
## screen is always the pony the save describes.
##
## THE SAME StockTint THE CROWD GOES THROUGH, deliberately: one pipeline, two users, and no
## second path that could drift.
func apply_look(look: PlayerLook) -> void:
	if look == null:
		return
	# v1: the same PonyPaint path every pony in the game wears (race, two-tone mane, tail,
	# iris, mark), on whichever donor her race and style pick.
	var pony_look: PonyLook = look.to_pony_look(StockPaletteScript.load_player())
	if pony_look.donor != _donor_built:
		_rebuild_visuals(look.mane_style, pony_look.donor)
	_mane_style_built = look.mane_style
	if visuals.get_child_count() == 0:
		return
	var body: Node3D = visuals.get_child(0)
	_worn = pony_look
	PonyPaintScript.apply(body, pony_look)


## Swap the body for one built from a different base model. Freed outright rather than
## queue_free()'d, for game/world/race_runner.gd's reason: a queued node is still among
## get_children() until the end of the frame, so the "body is child 0 of Visuals"
## convention this whole file rests on would be false for a frame.
func _rebuild_visuals(mane_style: int, donor: StringName = &"") -> void:
	if visuals.get_child_count() > 0:
		var old: Node = visuals.get_child(0)
		visuals.remove_child(old)
		old.free()
	_anim = null
	_build_visuals(mane_style, donor)


## The surface for open ground. Set by ranch.gd, which is the only thing that knows what a
## region is; an unknown id is refused so a typo cannot turn every step in the rest of the
## session into a push_error. Anything she stands on that is not open Terrain decides for
## itself (surface_for()).
func set_step_surface(id: StringName) -> void:
	if not SURFACES.has(id):
		push_error("Player.set_step_surface: '%s' is not a surface" % id)
		return
	_step_surface = id


func step_surface() -> StringName:
	return _step_surface


## Where in the current clip the last hoofstep decision was taken, in seconds. For the suite.
func step_phase() -> float:
	return _step_position


## The footfalls of `clip`: [{t, rear}] sorted by t, read from the clip's own IK hoof target
## position tracks. A clip with no such tracks (or no AnimationPlayer at all, as in this
## file's own unit suite) gets one footfall at t = 0, which is the old once-a-cycle rule.
func footfalls_for(clip: StringName) -> Array:
	if _footfall_cache.has(clip):
		return _footfall_cache[clip]
	var out: Array = []
	var anim: Animation = null
	if _anim != null and _anim.has_animation(clip):
		anim = _anim.get_animation(clip)
	if anim != null:
		out = footfalls_in(anim, _hoof_parent_frames())
	if out.is_empty():
		out = [{"t": 0.0, "rear": false}]
	_footfall_cache[clip] = out
	return out


## Each hoof target's PARENT frame in skeleton space (its parent bone's rest), by name.
## A position track is in the parent's space, and on these rigs the parent (CON_Root) carries
## the Blender Z-up to Godot Y-up turn, so a track's own .y is NOT height: read raw, it is
## the hoof's fore and aft travel, whose extremes sit about a tenth of a second off the
## touchdowns in the gallop. Through this frame it is height. CON_Root is never keyed, so
## its rest is its pose.
func _hoof_parent_frames() -> Dictionary:
	var out: Dictionary = {}
	if visuals == null:
		return out
	var found := visuals.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return out
	var sk := found[0] as Skeleton3D
	for name: String in HOOF_TARGETS:
		var bone := sk.find_bone(name)
		if bone < 0:
			continue
		var parent := sk.get_bone_parent(bone)
		out[name] = sk.get_bone_global_rest(parent) if parent >= 0 else Transform3D.IDENTITY
	return out


## Touchdowns in `anim`, from its IK hoof target position tracks: the moment each target
## comes down to its lowest HEIGHT, read through `parent_frames` (bone name to the frame its
## track is expressed in; identity when absent). Static and pure, so the suite can feed it a
## hand built Animation.
static func footfalls_in(anim: Animation, parent_frames: Dictionary = {}) -> Array:
	var raw: Array = []
	var length := anim.length
	if length <= 0.0:
		return raw
	var samples := maxi(8, int(length * 1000.0))
	for track in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		var bone: String = String(anim.track_get_path(track).get_concatenated_subnames())
		var index := HOOF_TARGETS.find(bone)
		if index < 0:
			continue
		var ys := PackedFloat32Array()
		ys.resize(samples)
		var low := INF
		for k in samples:
			var frame: Transform3D = parent_frames.get(bone, Transform3D.IDENTITY)
			var y: float = (frame * anim.position_track_interpolate(track, length * k / samples)).y
			ys[k] = y
			low = minf(low, y)
		for k in samples:
			var down: bool = ys[k] <= low + HOOF_CONTACT_EPS
			var was_down: bool = ys[(k - 1 + samples) % samples] <= low + HOOF_CONTACT_EPS
			if down and not was_down:
				raw.append({"t": length * k / samples, "rear": index >= 2})
	raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	var merged: Array = []
	for f: Dictionary in raw:
		if not merged.is_empty() and float(f.t) - float(merged[-1].t) < FOOTFALL_MERGE:
			# Together with a front hoof, the pair takes the front hoof's accent.
			merged[-1].rear = bool(merged[-1].rear) and bool(f.rear)
			continue
		merged.append(f.duplicate())
	# The same merge across the loop seam.
	if merged.size() > 1 and float(merged[0].t) + length - float(merged[-1].t) < FOOTFALL_MERGE:
		merged[0].rear = bool(merged[0].rear) and bool(merged[-1].rear)
		merged.pop_back()
	return merged


## Roll the clip position forward and answer whether a hoof landed this frame: whether the
## position crossed one of the clip's footfalls since the last call, wrapping at the loop.
## Makes no sound; the suite drives it with numbers.
##
## A CHANGE OF CLIP IS NOT A FOOTFALL. Gait.clip_for_speed() swaps walk for gallop mid stride
## and the position resets to near zero when it does; counting that as a crossing would put
## a stray sound on the exact frame she breaks into a run, every time.
func step_on_clip(clip: StringName, position_seconds: float, speed: float,
		on_floor: bool) -> bool:
	if not on_floor or absf(speed) < STEP_MIN_SPEED or clip == &"idle" or clip.is_empty() \
			or clip != _step_clip:
		_step_clip = clip
		_step_position = position_seconds
		return false
	var from := _step_position
	_step_clip = clip
	_step_position = position_seconds
	if is_equal_approx(from, position_seconds):
		return false
	var wrapped := position_seconds < from
	for f: Dictionary in footfalls_for(clip):
		var t: float = f.t
		var crossed := (t > from and t <= position_seconds) if not wrapped \
			else (t > from or t <= position_seconds)
		if crossed:
			_last_footfall_rear = bool(f.rear)
			return true
	return false


## The set to play for a hoof coming down on `collider` at world `point`. Static and pure:
## a tagged collider (SURFACE_META on it or its first four ancestors) names itself; the
## Terrain is dirt on the painted path and `open_ground` elsewhere; anything else she can
## stand on (a crate, a cart, a step, a fence rail) is timber.
static func surface_for(collider: Object, point: Vector3, open_ground: StringName) -> StringName:
	var node := collider as Node
	var depth := 0
	while node != null and depth < 5:
		if node.has_meta(SURFACE_META):
			var tagged := StringName(node.get_meta(SURFACE_META))
			if SURFACES.has(tagged):
				return tagged
		node = node.get_parent()
		depth += 1
	if collider is TerrainScript:
		if path_distance(Vector2(point.x, point.z)) <= TerrainScript.PATH_HALF_WIDTH \
				+ TerrainScript.PATH_EDGE_SOFTNESS * 0.5:
			return SURFACE_DIRT
		return open_ground
	if collider == null:
		return open_ground
	return SURFACE_WOOD


## Metres from `p` to the Terrain's painted path (its PATH_POINTS polyline).
static func path_distance(p: Vector2) -> float:
	return TerrainScript.path_distance(p)


## The surface under her right now: a short ray straight down from her hips.
func surface_under() -> StringName:
	if not is_inside_tree():
		return _step_surface
	var from := global_position + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.9,
		LayersScript.TERRAIN | LayersScript.PROPS, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return _step_surface
	return surface_for(hit.collider, hit.position, _step_surface)


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


## The Gallop Shoes' burst (world/ranch_tools.gd sets it, and sets it back).
var speed_mult := 1.0


var _rescue_check := 0.5


## HER BODY IS DRAWN BETWEEN PHYSICS TICKS (item 9). She moves on the 60 Hz tick; a 144 Hz
## display draws two or three frames per tick, so drawn at her body she stood still for two
## frames and jumped on the third, and so did the camera that follows her and the springs in
## her tail that ride on her. So each drawn frame her Visuals and the camera's pivot are
## placed where her body was a FRACTION of the way between the last two ticks
## (Engine.get_physics_interpolation_fraction()), her yaw likewise; her collision body, and
## everything gameplay reads from it, stays exactly on the tick. Godot's own physics
## interpolation would do this for the whole scene and would need every teleport and the
## camera rig reworked; this is confined to her and her camera. A teleport (anything that sets
## her position outside her own tick, or a tick step longer than TELEPORT_STEP) is drawn at
## once, never smeared across the gap.
## False draws her on the tick, as before (the measure probe's comparison).
var draw_between_ticks := true
## A tick step longer than this (metres; 120 m/s) is a teleport, not a stride.
const TELEPORT_STEP := 2.0
var _tick_prev := Vector3.ZERO
var _tick_curr := Vector3.ZERO
var _yaw_prev := 0.0
var _yaw_curr := 0.0
## The yaw her Visuals were last left at by this script; anything else found there was put
## there by someone else (a shot script, face()), and is taken as a fresh start.
var _yaw_expected := 0.0
var _visuals_rest := Vector3.ZERO
var _pivot_rest := Vector3.ZERO
var _tick_seeded := false


## Where between two ticks her body is drawn, as an offset from `curr` (world metres):
## `prev` lerped to `curr` by `fraction`, minus `curr`. Zero for a teleport-sized step.
static func drawn_offset(prev: Vector3, curr: Vector3, fraction: float) -> Vector3:
	if prev.distance_to(curr) > TELEPORT_STEP:
		return Vector3.ZERO
	return prev.lerp(curr, clampf(fraction, 0.0, 1.0)) - curr


## Forget the last tick: she is drawn where she is now, with no blend from where she was.
func reset_tick_blend() -> void:
	_tick_prev = global_position
	_tick_curr = global_position
	if visuals != null:
		_yaw_prev = visuals.rotation.y
		_yaw_curr = visuals.rotation.y
		_yaw_expected = visuals.rotation.y
	_tick_seeded = true


## Put her Visuals and the camera pivot back on the tick (start of her tick), noticing a
## position or yaw someone else set since she last looked.
func _restore_tick_pose() -> void:
	if not _tick_seeded:
		reset_tick_blend()
		return
	visuals.position = _visuals_rest
	camera_pivot.position = _pivot_rest
	if absf(angle_difference(visuals.rotation.y, _yaw_expected)) > 1e-5:
		_yaw_prev = visuals.rotation.y
		_yaw_curr = visuals.rotation.y
	else:
		visuals.rotation.y = _yaw_curr
	_yaw_expected = visuals.rotation.y
	if global_position.distance_squared_to(_tick_curr) > 1e-8:
		_tick_prev = global_position
		_tick_curr = global_position


## End of her tick: the step just taken becomes the one drawn frames blend across.
func _record_tick() -> void:
	_tick_prev = _tick_curr
	_tick_curr = global_position
	_yaw_prev = _yaw_curr
	_yaw_curr = visuals.rotation.y
	_yaw_expected = _yaw_curr


func _process(_delta: float) -> void:
	_draw_between_ticks(Engine.get_physics_interpolation_fraction())


## Place her Visuals and the camera pivot `fraction` of the way through the last tick.
func _draw_between_ticks(fraction: float) -> void:
	if not _tick_seeded or visuals == null:
		return
	# Moved since her tick, or turned by someone else: a teleport, drawn where it lands.
	if global_position.distance_squared_to(_tick_curr) > 1e-8 \
			or absf(angle_difference(visuals.rotation.y, _yaw_expected)) > 1e-5:
		reset_tick_blend()
	if not draw_between_ticks:
		fraction = 1.0
	var offset := global_basis.inverse() * drawn_offset(_tick_prev, _tick_curr, fraction)
	visuals.position = _visuals_rest + offset
	camera_pivot.position = _pivot_rest + offset
	var yaw := _yaw_curr
	if _tick_prev.distance_to(_tick_curr) <= TELEPORT_STEP:
		yaw = lerp_angle(_yaw_prev, _yaw_curr, clampf(fraction, 0.0, 1.0))
	visuals.rotation.y = yaw
	_yaw_expected = yaw


func _physics_process(delta: float) -> void:
	_restore_tick_pose()
	# Never trapped in a building (PT2): checked twice a second, see Building.rescue_body.
	_rescue_check -= delta
	if _rescue_check <= 0.0:
		_rescue_check = 0.5
		Building.rescue_body(self)
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
	if InputMap.has_action(SPRINT_ACTION) and Input.is_action_just_pressed(SPRINT_ACTION):
		toggle_sprint()
	var top_speed := (SNEAK_SPEED if is_sneaking() else RUN_SPEED) * speed_mult
	if is_sprinting():
		top_speed *= SPRINT_MULT
	top_speed *= stumble_slow()
	_stumble_left = maxf(0.0, _stumble_left - delta)
	var target_velocity := direction * (top_speed * wish_magnitude)

	var rate := acceleration if wish_magnitude > 0.0 else deceleration
	if not on_floor:
		rate *= air_control
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target_velocity, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var fall_speed := -velocity.y
	move_and_slide()
	# A hard landing is slapstick: her hindquarters bounce (actors/pony/rump_bounce.gd).
	if not on_floor and is_on_floor() and fall_speed > LAND_BOUNCE_FROM:
		RumpBounce.kick_on(visuals, clampf(fall_speed / 7.0, 0.3, 1.2))
		stumble(stumble_for(fall_speed))

	var ground_speed := get_ground_speed()
	_update_facing(direction, delta)
	_update_animation(ground_speed, delta)
	if _hair != null:
		_hair.influence = PonyRigScript.influence_for_speed(ground_speed)
	if _anim != null and step_on_clip(_anim.current_animation,
			_anim.current_animation_position, ground_speed, is_on_floor()) \
			and not (_last_footfall_rear and _anim.current_animation == &"gallop"):
		# At a run only the front hooves sound: four taps a stride at five a second was a
		# drum roll (owner playtest 2026-10-25, "walking sound is AWFUL").
		var surface := surface_under()
		_sound_call(&"play_at", [surface, global_position,
			REAR_ACCENT_DB if _last_footfall_rear else 0.0])
		hoofstep.emit(surface, _last_footfall_rear)
	_record_tick()


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
	var before := visuals.rotation.y
	visuals.rotation.y = lerp_angle(visuals.rotation.y, _visual_yaw, weight)
	# Into a sharp turn she banks (FS4.2, systems/gait_blend.gd).
	if delta > 0.0:
		visuals.rotation.z = _gait_blend.lean(angle_difference(before, visuals.rotation.y) / delta,
			get_ground_speed(), delta)
	# A hard landing's stumble (G4).
	visuals.rotation.x = stumble_pitch(_stumble_left, _stumble_strength)


## Turn her to face world heading `yaw` (radians, -Z forward) at once, with no smoothing: for
## when she is put somewhere rather than walked there (the Palace's doors, ranch.gd).
func face(yaw: float) -> void:
	_visual_yaw = yaw
	visuals.rotation.y = yaw
	visuals.rotation.z = 0.0
	_gait_blend.reset()
	reset_tick_blend()


## Pick `idle` / `walk` / `gallop` and scale playback so the gait matches the ground.
## Both decisions are Gait's -- deliberately not an if-ladder over speed constants here,
## because this is the third scene that would have needed editing when the gallop clip
## was added. All the reasoning about the bands and the resulting skate lives in
## game/systems/gait.gd; this function must not grow its own speed constants.
func _update_animation(speed: float, delta := 1.0 / 60.0) -> void:
	if _anim == null:
		return
	# Her legs show a speed that settles down through the trot and the walk when she stops
	# (FS4.2, systems/gait_blend.gd); Gait still names the clip for it.
	speed = _gait_blend.shown_speed(speed, delta)
	var clip := _gait_blend.clip(speed, _anim.has_animation(&"trot"))
	_play(clip)
	_anim.speed_scale = GaitScript.playback_scale_for_clip(clip, speed)
	# A sprint runs the gallop clip past its usual ceiling, so her hooves keep up with the
	# ground rather than skating.
	if clip == &"gallop" and is_sprinting() and speed > GaitScript.TOP_SKATE_FREE_SPEED:
		_anim.speed_scale = speed / GaitScript.GALLOP_CLIP_SPEED


const GaitBlendScript := preload("res://systems/gait_blend.gd")
var _gait_blend: GaitBlend = GaitBlendScript.new()


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
func _build_visuals(mane_style: int = 0, donor: StringName = &"") -> void:
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

	var path := DonorTableScript.model_path(donor) if donor != &"" \
		else StockPaletteScript.mane_style_path(mane_style)
	var pony: Node3D = PonyVisualsScript.build(data, path)
	if pony == null:
		push_error("Player: PonyVisuals.build failed for '%s'" % pony_id)
		return
	_mane_style_built = mane_style
	_donor_built = donor if donor != &"" else StringName(path.get_file().get_basename())

	visuals.add_child(pony)
	# INDEX 0, ALWAYS. `Visuals` already carries `BeamOrigin` as a scene-authored child
	# (player.tscn), so a plain add_child() would leave the body at index 1 -- unlike
	# game/actors/pony/pony.gd, whose Visuals starts empty. apply_look() below, and the
	# crowd's own `visuals.get_child(0)` convention (pony.gd's _apply_stock_tint()), both
	# read "the body" as the FIRST child of Visuals; this is what keeps that reading true
	# for the player too.
	visuals.move_child(pony, 0)
	_place_beam_origin(pony)
	_mount_scoop(pony)
	_anim = pony.get_node_or_null(PonyVisualsScript.ANIMATION_PLAYER_PATH)
	_footfall_cache.clear()
	if _anim == null:
		# PonyVisuals.build() refuses to return an instance without one, so this is
		# unreachable unless that contract changes -- assert it rather than assume it.
		push_error("Player: no AnimationPlayer at %s" % PonyVisualsScript.ANIMATION_PLAYER_PATH)
		return
	_play("idle")
	# Re-found on every rebuild rather than kept: apply_look() frees the whole body when the
	# mane style changes, and a stale simulator reference would be a freed node.
	_hair = PonyRigScript.hair_simulator(pony)
	# HER POSE AND HER HAIR MOVE ON EVERY DRAWN FRAME (item 9; playtest 2026-11-05: "your tail
	# bugs out as you walk ... it like stutters between frames"). PT11 put both on the physics
	# tick, which stopped the springs being thrown but left the tail moving only 60 times a
	# second: on a 144 Hz display, with the camera holding her still on screen, it was the one
	# thing visibly stepping (2-3-2-3 frames). Her body is now DRAWN between ticks (see
	# _draw_between_ticks()), so the clip and the springs run per drawn frame on smooth motion.
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	for sk: Skeleton3D in pony.find_children("*", "Skeleton3D", true, false):
		sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE


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
## THE SCOOP (v1): Cloudsdale's capture lantern rides on her right shoulder, pointing ahead,
## on a BoneAttachment to the chest so it moves with her stride; the beam leaves from its
## nozzle. Every kind of pony carries one (GDD 4.1), so the horn is no longer the source.
const SCOOP_MODEL := "res://assets/models/scoop.glb"
## Back on her barrel and below the neck, like a saddle lantern (Fable AAA round 3, #5: at
## the shoulder, from the camera behind her, it sat beside her muzzle and "reads as a ball in
## the mouth").
const SCOOP_AT := Vector3(-0.42, 0.98, 0.08)
const SCOOP_NOZZLE := Vector3(-0.42, 1.01, -0.30)
const SCOOP_SCALE := 1.1


func _mount_scoop(pony: Node3D) -> void:
	if not ResourceLoader.exists(SCOOP_MODEL):
		return
	var sks := pony.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0]
	var bone := sk.find_bone("Chest1")
	if bone < 0:
		bone = sk.find_bone("Pelvis")
	if bone < 0:
		return
	var attach := BoneAttachment3D.new()
	attach.name = "ScoopMount"
	attach.bone_idx = bone
	sk.add_child(attach)
	var scoop: Node3D = (load(SCOOP_MODEL) as PackedScene).instantiate()
	scoop.name = "Scoop"
	attach.add_child(scoop)
	ToonStyler.style(scoop, &"prop", {})
	pony.force_update_transform()
	# Pointing ahead (the model faces -Z; the Scoop is modelled along +X).
	var basis := Basis(Vector3.UP, deg_to_rad(90.0)).scaled(Vector3.ONE * SCOOP_SCALE)
	scoop.global_transform = visuals.global_transform * Transform3D(basis, SCOOP_AT)
	beam_origin.position = SCOOP_NOZZLE


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
