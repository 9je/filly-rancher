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
##                                 sweeps a ball of LENS_RADIUS (its `shape`) and pulls
##                                 the camera in if something is in the way. It only does
##                                 that on physics ticks, so this script repeats the same
##                                 sweep every rendered frame and that is what is drawn
##                                 -- see LENS_RADIUS for the playtest bug that cost.
##       CameraMount           -- a bare Node3D that exists ONLY to be the node the
##                                 spring arm positions. It carries no offset of its
##                                 own; its position IS the arm's answer.
##         Camera3D            -- `current = true`. Carries the SHOULDER OFFSET in its
##                                 local transform (see SHOULDER_SIDE below), and no
##                                 rotation at all -- no fixed flip is needed, see below.
##
## WHY THE MOUNT NODE EXISTS -- checked against the engine, not assumed. SpringArm3D
## OVERWRITES the position of every direct Node3D child every physics frame with
## `(0, 0, current_spring_length)`; a local offset written onto a Camera3D parented
## straight to the arm is silently stomped on the next physics tick. Verified with a
## throwaway scene (a bare SpringArm3D with a Camera3D child at local `(0.65, 0.22, 0)`
## and a Node3D child holding a Camera3D grandchild at the same local offset): the direct
## child came back as `(0, 0, 3.5)`, the grandchild kept `(0.65, 0.22, 0)` and landed at
## `(0.65, 0.22, 3.5)`. So the offset has to live one level below whatever the arm moves.
## If this ever needs re-checking, re-check it that way rather than reasoning about it.
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
## MAX is a wide "establishing" shot that still keeps her recognisable rather than a
## speck.
##
## MIN DOES NOT BOUND HOW CLOSE THE CAMERA CAN ACTUALLY GET. It is used ONLY by
## add_zoom_delta()'s clampf() below, on the arm's REST length (the distance the
## player asked for). SpringArm3D's own collision pull-in -- what actually happens
## when something is in the way -- is a separate mechanism this constant plays no
## part in, and measured against the ranch's barn (game/world/ranch.gd's
## camera-vs-building probe) the arm pulls in to 0.55 m, inside SPRING_MIN and inside
## the pony. A previous version of this comment claimed SPRING_MIN held "even when
## the spring arm is fully pulled in against a wall" -- that was false; do not
## reintroduce it. Do NOT "fix" this by clamping the pull-in to SPRING_MIN either: at
## the barn that would put the camera 0.47 m INSIDE the wall, which is strictly worse
## than the current close-up.
##
## The real fix landed in Phase 1A Task 9 and is the FADE_* block below: the pony's
## mesh dissolves out as the arm shortens, so a hard pull-in reads as the camera
## stepping past her rather than as clipping through her. See _update_subject_fade().
const SPRING_MIN := 1.2
const SPRING_MAX := 6.5
## Default distance: roughly 2.5x her withers height, framing her whole body plus a
## little surrounding space -- a standard third-person "see your character" distance
## scaled down to her size rather than a human's.
const SPRING_DEFAULT := 3.5

## Metres of spring length adjusted per zoom step (scroll notch, keyboard press, or
## gamepad d-pad press -- see `_process()`).
const ZOOM_STEP := 0.5

## SHAKE (feel pass 2026-10-26; GDD feel table: "a trauma-based shake"). A kick adds trauma,
## trauma bleeds away at SHAKE_DECAY a second, and the lens slides by trauma squared times
## SHAKE_METRES through the camera's own h/v offsets, so the arm, the aim ray's direction
## and the terrain guard never see it. Settings > Gameplay > Camera shake turns it off.
const SHAKE_METRES := 0.07
const SHAKE_DECAY := 1.8
var shake_enabled := true
var _trauma := 0.0
var _shake_clock := 0.0

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
## Flip vertical look. The pause menu's settings page toggles this.
@export var invert_look := false

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
@export_flags_3d_physics var probe_mask := CollisionLayersScript.WORLD | CollisionLayersScript.CANOPY

# SUPERSEDED FOR PLACING THE LENS (camera playtest fix, see LENS_RADIUS): the arm now sweeps
# a ball, and the lens is placed every frame by _resolve_arm(), which stops the ball at first
# contact; the ball's radius IS the clearance, so this margin no longer decides where the
# lens is drawn. It is still assigned to the arm for SpringArm3D's own per-tick sweep. The
# history below is kept because it is what the ray version actually did.
#
# SPRINGARM3D.MARGIN IS LIVE, AND IT BECAME LIVE AS A SIDE EFFECT OF THE SHOULDER
# OFFSET. Read this before touching either.
#
# It used to do nothing at all, and this comment used to say so at length: measured
# against the ranch's own camera probe, `margin = 0.01` and `margin = 1.0` -- a value
# that could not possibly be subtle -- both produced `hit=0.73 actual=0.73`. That
# measurement was real. The explanation attached to it ("margin only participates in
# the shape-cast branch, and this arm has no shape") was wrong.
#
# THE ACTUAL RULE, measured directly against the engine with a throwaway scene (one
# wall, five arms, identical geometry, margin and child nesting varied):
#     direct Camera3D child, margin 0.0/0.2/1.0 -> hit = 1.2715, 1.2715, 1.2715
#     Node3D->Camera3D child, margin 0.0        -> hit = 1.2779
#     Node3D->Camera3D child, margin 0.2        -> hit = 1.0779
# So SpringArm3D special-cases a Camera3D that is its DIRECT child and ignores `margin`
# for it entirely (landing ~0.006 m off the surface instead). Nest that camera one level
# deeper -- which the shoulder offset had to do, because the arm overwrites its direct
# children's transforms (see the class comment) -- and the property starts working.
#
# The consequence is the wall clearance the previous version of this comment said would
# need a SphereShape3D to get: the lens now stops 0.2 m short of what the arm hits
# instead of 0.006 m short. It is kept deliberately. It is also why the pull-in numbers
# this file and game/world/ranch.gd quote moved: the barn probe reads 0.55 m where it
# read 0.73 m, and `04_obstacle` in game/scenes/test/camera_test.tscn reads 1.08 m where
# it read 1.27 m. Same wall, same arm, same mask -- 0.2 m of margin that is now applied.
# If a future change ever parents a Camera3D straight to this arm again, expect every one
# of those numbers to jump back up, and expect no warning of any kind.
#
# NOW SCRIPT-OWNED (SPRING_ARM_MARGIN below), NOT LEFT IN camera_rig.tscn, and not just
# for tidiness: it used to be the only collision-relevant property on this rig that
# _ready() did not assign from a script-owned value (collision_mask does, from
# `probe_mask`), which meant it was editable in the scene file with no gate watching it.
# Worse, game/world/ranch.gd's own camera check (`pull_in >= MIN_CAMERA_PULL_IN`) can only
# get GREENER as margin grows -- margin subtracts directly from where the arm leaves the
# mount, so a margin regression (someone shrinking or dropping it) would never fail that
# assertion; it would only ever make the barn shot creep back toward the pre-margin
# close-up with nothing red anywhere. Reread as a constant here at least gives a future
# editor one place that says "this number is load-bearing," even though no gate currently
# asserts its value directly -- see MOUNT_MIN_Z below for the one thing that IS asserted
# about its consequences.
const SPRING_ARM_MARGIN := 0.2

## THE FLIP THIS MARGIN CAN CAUSE, AND THE CLAMP THAT STOPS IT.
##
## SpringArm3D's own math, confirmed against the engine and not just reasoned about: when
## it has a hit, it leaves the mount at local z = (hit distance - margin), not at the hit
## distance itself. That is fine right up until something is nearer than `margin` -- an
## overhang, an eave, a steep bank within SPRING_ARM_MARGIN (0.2 m) of the 1.45 m pivot --
## at which point the subtraction goes NEGATIVE and drives the mount THROUGH the pivot to
## the FRONT of the player, looking back through her own body. Measured directly with a
## throwaway scene (game/scenes/test/_proof_margin.gd, not kept in the tree): hit distances
## of 0.05 / 0.10 / 0.15 m against SPRING_ARM_MARGIN's 0.2 m left the mount at local z
## -0.15 / -0.10 / -0.05 -- exactly the flip, and silent: nothing else in this rig or in
## game/world/ranch.gd's camera probe would have noticed, because get_arm_distance() reads
## a DISTANCE (`global_position.distance_to`), which is the same magnitude whether the
## mount is 0.15 m behind the pivot or 0.15 m in front of it.
##
## It is narrow in every scene this project currently ships (the ranch's barn pulls the arm
## in only to 0.55 m, nowhere near 0.2 m), which is exactly why it is the kind of bug that
## survives review and then goes off in someone's hands months later. Clamped every frame,
## right after the arm's own physics step positions the mount (see _process()) -- the same
## timing _update_shoulder_offset() already depends on, for the same reason.
##
## 0.10 m, not 0.0 m: zero would stop the through-the-pivot flip but would still let the
## near plane straddle or sit behind the pivot at the clamp boundary. 0.10 m is twice the
## camera's default near-plane distance (0.05 m), the same "twice the near plane" reasoning
## the shoulder offset's old SHOULDER_SKIN used for the same reason.
const MOUNT_MIN_Z := 0.10

## THE FIX FOR THE CLOSE-UP-INSIDE-THE-PONY BUG, and the reason SPRING_MIN's comment
## above says not to clamp the pull-in.
##
## What the bug looks like: back the player against the ranch's barn and the arm pulls
## in from its 3.5 m rest to 0.55 m (measured -- game/world/ranch.gd's camera probe
## prints it every run, and its `04a_camera_pressed_to_wall` render is the picture; it
## was 0.73 m before the arm's `margin` came alive, see the note above).
## 0.55 m from a pivot at her withers is INSIDE her body, so the shot is an unreadable
## wall of flank with the world completely hidden behind it. Clamping the arm was
## considered and rejected: SPRING_MIN (1.2 m) against that same wall would put the
## camera 0.47 m inside the BARN instead, which is strictly worse -- you would be
## looking at the inside of a wall rather than at the inside of a pony.
##
## What happens instead: the subject fades out as the arm shortens, and is gone before
## the camera reaches her. FADE_START is the distance at which she begins to dissolve
## and FADE_END the distance at which she is fully hidden.
##
## FADE_END IS SPRING_MIN, DELIBERATELY, and that is the whole design of this ramp. The
## arm can only get closer than the player's tightest chosen zoom by being SHOVED there
## by geometry -- which is exactly the case that has to end with her not drawn. Tying
## the two together means the rule reads as one sentence: she is fully drawn at any
## normal distance, fades out over the last half-metre of zoom, and is gone at maximum
## zoom-in and at anything closer than that. It also gives the zoom a genuinely useful
## bottom end -- maximum zoom-in is now a clean near-first-person aiming view for the
## magic beam instead of a close-up of her mane, which is worth having because the beam
## aims at the SCREEN CENTRE and her body is what normally sits there.
##
## A first cut used 1.5 / 0.85, which left her a 56%-opaque ghost at maximum zoom-in --
## measured, not guessed (game/world/ranch.gd prints the opacity, and the integration
## pass's zoom render showed it). Half-transparent is the one state worth avoiding: you
## can see neither her nor cleanly past her.
##
## APPLIED VIA GeometryInstance3D.transparency, per MeshInstance3D, not by touching
## the materials: the pony's materials come out of the glTF import and are shared
## between every instance built from the same model (the player and any wild pony of
## the same species), so writing `albedo_color.a` on them would fade the whole herd
## whenever the player backed into a wall. `transparency` is a per-instance render
## property and cannot leak that way.
const FADE_START := 1.7
const FADE_END := SPRING_MIN

## THE SHOULDER OFFSET: the camera sits off the pony's centre line, third-person-shooter
## style, instead of directly behind her.
##
## THE BUG IT FIXES. Everything this rig aims with goes through the SCREEN CENTRE:
## get_aim_ray() is projected from there, the HUD reticle is drawn there, and the magic
## beam casts along that ray. With the camera on her centre line, the screen centre is
## exactly where her own body is -- so the crosshair rested on her mane at every zoom the
## player could select, and you aimed THROUGH your own pony. It was the loudest feel
## complaint left in Phase 1A, it is visible in the very first frame of the game, and no
## number in this project could see it (the ray was, and still is, perfectly accurate --
## it was pointed at her back).
##
## WHY A FIXED NUMBER OF METRES AND NOT A FRACTION OF THE ARM LENGTH. The thing the offset
## has to clear is her SILHOUETTE, and that is a fixed size in metres (her capsule radius
## is 0.42 m -- player.gd -- and her mane and barrel sit inside about the same half-width,
## measured off the rendered rest frame: ~67 px of a 1600 px shot at 3.5 m, which back-
## projects to 0.40 m). Displacing the camera sideways by S metres displaces the whole aim
## LINE sideways by S at every depth, so `S > her half-width` clears her at every zoom with
## one number. A distance-proportional offset would instead hold her at a constant place
## ON SCREEN, which sounds tidier and is the wrong invariant: to clear 0.45 m at the
## tightest zoom it would need a ratio that puts the camera 1.7 m off her centre line at
## the widest, and aiming at anything close then means a large yaw for no reason.
##
## 0.70 m clears that ~0.42 m half-width by a comfortable margin at every distance. On
## screen at the default 3.5 m zoom that is ~117 px of an 800 px half-screen, so she sits
## about 15% left of centre -- in the same band third-person shooters use, and enough that
## the reticle is over open world with daylight around it rather than skimming her outline.
##
## IT ALSO MAKES THE BEAM LEGIBLE, which was the second half of the same complaint. The
## beam is drawn from her HORN to whatever the crosshair is on (magic_beam.gd). With the
## camera on her centre line those two points are nearly collinear with the view direction,
## so a beam reaching for a distant pony projected to a few pixels and the target's aura
## carried the whole read. Offset, the horn projects ~137 px left of centre while the far
## end stays at the centre, so the same beam is drawn ACROSS the view as a diagonal.
##
## NO CONVERGENCE / TOE-IN, DELIBERATELY. Offset cameras in shooters normally need the
## camera toed in so the crosshair agrees with a weapon that fires from somewhere else.
## Nothing here fires from somewhere else: the beam is cast along get_aim_ray(), which is
## projected out of THIS camera through the screen centre, so the crosshair and the ray are
## the same line by construction at every distance. Adding a convergence angle would buy
## nothing and would make that guarantee harder to reason about. (The horn is still where
## the beam is DRAWN from, and magic_beam.gd already projects it onto the ray, so range
## stays measured from the player.)
##
## NO SHOULDER SWAP, DELIBERATELY. There is no cover mechanic here for a swap to serve, and
## a swap is not local to this file: magic_beam.gd parks a held pony HOLD_SIDE (2.4 m)
## screen-RIGHT, sized so she is clear of the player's silhouette. With the camera offset
## right, the player sits left of centre and the held pony right of it -- they are as far
## apart as they can be. Swapping the camera to the left shoulder without also swapping the
## beam would move the player back across the frame INTO the held pony. If a later phase
## wants a swap, both constants have to move together, and that is the reason why.
const SHOULDER_SIDE := 0.70
## Metres the camera is also lifted, in the ARM's local frame -- i.e. screen-up, so it
## stays screen-up at any pitch, the same convention magic_beam.gd's HOLD_LIFT uses.
## Small: it is here to look a little more OVER her back than along it (and to show a bit
## more ground ahead of her), not to become a bird's-eye view. 0.22 m at the default zoom
## drops her ~37 px in frame.
const SHOULDER_LIFT := 0.22

# WHY THE SHOULDER OFFSET IS SWEPT (it once had a RayCast3D probe and a SHOULDER_SKIN of its own;
# both were replaced by the lens ball, see LENS_RADIUS below).
#
# THE SWEEP IS NOT BELT-AND-BRACES; IT IS THE FIX FOR A BUG THE FIRST RENDER OF THIS
# FEATURE SHOWED. The spring arm probes BACKWARDS along her centre line, so it cannot see
# anything beside her -- and the shoulder offset moves the lens sideways off the line the
# arm cleared. Stand her flank against a wall (her own capsule stops her 0.42 m from it,
# and the offset wants 0.70 m) and the lens ends up INSIDE the wall: with backface culling
# the wall then disappears from the shot entirely, leaving nothing but its shadow on the
# grass and a clear view through solid geometry. That is exactly what
# game/scenes/test/camera_test.tscn's `06_side_wall` render showed, with every number in
# that gate green -- the offset was applied perfectly, to a place the camera should not be.
#
# So the lateral hop gets a sweep of its own: the lens ball from the mount out along the
# offset, on the same mask as the arm, and the offset is shortened to whatever room it
# finds (_room_for()). Note what the worst case degrades TO -- an offset of zero, i.e. the camera back
# on her centre line, which is precisely the behaviour this rig had before this feature and
# is already the sanctioned answer for a camera with nowhere to go (see FADE_START: she is
# faded out by then anyway). It can never push the lens INTO anything, which is what makes
# this clamp a different animal from the spring-length clamp SPRING_MIN's comment forbids.
#
# KNOWN LIMITATION, DOCUMENTED RATHER THAN FIXED: hugging a wall FLANK-ON collapses the
# offset back to zero, and the "offset of zero" this file's design leans on so heavily
# elsewhere (see the paragraph above, and FADE_START) is not free here the way it is at
# a pull-in. At a pull-in the subject is fading or gone, so a centred camera has nothing
# to aim through. Pressed flank-on against a wall, she is still fully drawn -- so a
# collapsed offset restores exactly the bug this whole feature exists to fix: the
# crosshair rests on her own body again, for as long as the flank-hug lasts. Measured,
# not assumed -- the centre pixel in that pose is her body.
#
# The standard fix is mirroring to the free shoulder (probe the LEFT offset too when the
# right one is blocked, and vice versa) so the camera only ever collapses when BOTH sides
# are obstructed. It is deliberately deferred: it is a second probe and a side-selection
# policy, not a one-line change, and "no shoulder swap" was already a considered decision
# for the beam side (see SHOULDER_SIDE's comment) that a mirror would have to be threaded
# through carefully rather than bolted on.

## THE LENS IS A BALL, AND IT IS PLACED EVERY RENDERED FRAME, NOT EVERY PHYSICS TICK.
## Playtest note: "The camera showed under the terrain in places." Measured by
## game/test_input/test_camera_terrain.gd (walks the map with real keys and sweeps the mouse
## through every yaw, pitch and zoom; docs/playtest_fixes/camera.md has the numbers), there
## were two faults, and the first is the one the owner saw:
##
##  1. THE ARM WAS A TICK LATE. SpringArm3D works out its length in the physics step, 60 times
##     a second. The mouse turns the arm in _unhandled_input on EVERY RENDERED FRAME. On a
##     monitor faster than 60 Hz the frames in between are drawn with this frame's pitch and
##     the last tick's length, so a quick look up swings the lens on its old, long arm straight
##     through the ground (and through a wall on a quick turn) for a frame or two before the
##     arm catches up. A 60 fps test draws exactly one frame per tick, which is why nothing
##     before this caught it; the test runs at 144.
##  2. A RAY HAS NO SIZE. The arm probed with a ray and backed off SPRING_ARM_MARGIN along its
##     own line, and the shoulder probe backed off SHOULDER_SKIN along its own. At a grazing
##     angle -- looking up, the arm meets the ground at 30 degrees -- 0.2 m back along the line
##     is 0.1 m off the surface, and a lens beside a wall the ray ran parallel to had no
##     clearance at all: the near plane cut into the ground and into walls.
##
## So _process() places the lens itself, after this frame's look input and before the frame
## is drawn: a ball of LENS_RADIUS is swept from the pivot out along the arm (_resolve_arm),
## then from the mount out along the shoulder offset (_room_for), and the lens stops where the
## ball first touches anything (_sweep_fraction). SpringArm3D carries the same ball, so its own per-tick answer
## (get_hit_length(), which ranch.gd's camera probe reads) agrees with what is drawn.
##
## 0.25 m: the near plane's corners reach 0.09 m from the lens (near 0.05 m, 75 degree fov,
## 16:9), the playtest test demands 0.2 m of air under the lens, and 0.25 m clears both with
## room for the ground's own 2 m triangles between two samples of a sweep.
const LENS_RADIUS := 0.25
## Smaller balls a sweep falls back to when the full one STARTS touching something. JOLT
## IGNORES WHAT A SWEEP STARTS INSIDE: cast_motion() from a ball already touching a wall
## reports a clear path straight through it -- measured, not assumed: test_camera_rig's wall
## 0.05 m from the pivot left the mount at the full 3.5 m on the other side of it. So
## _sweep_fraction() checks the start first, and with no ball free there it answers 0.
const FALLBACK_RADII: Array[float] = [0.12, 0.05]

@onready var _spring_arm: SpringArm3D = $SpringArm3D
## The node the spring arm actually positions. See the class comment.
@onready var _mount: Node3D = $SpringArm3D/CameraMount
@onready var _camera: Camera3D = $SpringArm3D/CameraMount/Camera3D

## The sweeps of the lens ball (see LENS_RADIUS), built once: one query, and the full ball
## followed by each FALLBACK_RADII ball.
var _sweep_query := PhysicsShapeQueryParameters3D.new()
var _sweep_balls: Array[SphereShape3D] = []
## The collision shape of the body this rig is mounted on (the player's capsule), whose
## centre is where a sweep starts when her head is inside something. See _resolve_arm().
var _body_shape: CollisionShape3D = null
## The ground the last-resort floor in _keep_above_ground() reads, found by group.
var _terrain: Node = null

## WHETHER _keep_above_ground() HOLDS THE LENS OVER THE TERRAIN. True everywhere on the map.
## False while she is inside the Spectra Palace (game/world/palace_interior.gd), a sealed hall
## sixty metres under the grass: there the terrain "under" the lens is the ground overhead, and
## holding the lens above it would throw the camera up through the hall's ceiling. The hall's
## own floor, walls and ceiling are on the layers the arm's sweeps probe, so the lens is kept
## inside by the same sweeps that keep it out of a barn wall.
var ground_guard := true

## Current pitch in the "intuitive" sense described above. Kept as the source of truth
## instead of reading it back out of `rotation.x` so the clamp is applied in exactly
## one place.
var _look_pitch := 0.0

## Every MeshInstance3D belonging to the body this rig is mounted on, collected once in
## _ready(). See FADE_START.
var _subject_meshes: Array[MeshInstance3D] = []

## ANYBODY AT THE LENS STEPS ASIDE IN DITHER (Fable AAA round 1 #5 and the round 2 renders: a
## townspony or a companion standing beside the player filled a third of the frame with one
## giant face, behind every menu). A pony or townspony whose middle is within NEAR_FADE_FAR
## of the lens fades out in the screen-door dither, gone entirely by NEAR_FADE_CLOSE. The
## player is on her own layer (PLAYER) with her own fade, so the query never sees her.
const NEAR_FADE_FAR := 2.6
const NEAR_FADE_CLOSE := 1.2
var _near_faded: Dictionary = {}
## Last fade value written, so _process() does not touch every mesh every frame when
## nothing has moved.
var _subject_fade := -1.0


func _ready() -> void:
	_camera.current = true

	_look_pitch = clampf(default_pitch_deg, PITCH_MIN_DEG, PITCH_MAX_DEG)
	_spring_arm.rotation.x = deg_to_rad(_look_pitch)
	_spring_arm.spring_length = SPRING_DEFAULT
	_spring_arm.collision_mask = probe_mask
	_spring_arm.margin = SPRING_ARM_MARGIN

	# Both sweeps of the lens ball see exactly what the arm sees: one exported mask decides
	# what this whole rig can look through, so a future layer change cannot leave the halves
	# disagreeing about what a wall is. See LENS_RADIUS.
	var lens_ball := SphereShape3D.new()
	lens_ball.radius = LENS_RADIUS
	_spring_arm.shape = lens_ball
	for r: float in [LENS_RADIUS] + FALLBACK_RADII:
		var ball := SphereShape3D.new()
		ball.radius = r
		_sweep_balls.append(ball)
	_sweep_query.collision_mask = probe_mask

	# Exclude whatever body this rig is mounted on from its own collision probe, or a
	# spring arm whose origin ends up inside the player's capsule (it should not --
	# CameraPivot sits at 1.45 m, above the 1.3 m capsule top -- but a shorter subject
	# in a future scene could change that) would immediately pull itself in to zero.
	var body := _find_collision_ancestor()
	if body != null:
		_spring_arm.add_excluded_object(body.get_rid())
		_sweep_query.exclude = [body.get_rid()]
		for child in body.get_children():
			if child is CollisionShape3D:
				_body_shape = child
				break

	# The subject's body is built at runtime (PonyVisuals), so its meshes do not exist
	# during anyone's _ready(). Collect them on the next frame instead of assuming a
	# ready order -- the same lesson magic_beam.gd's _anchor_node() records after the
	# beam spent a task being drawn out of the player's hooves.
	_collect_subject_meshes.call_deferred()

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look_delta(event.relative.x * mouse_sensitivity, event.relative.y * mouse_sensitivity)


func _process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick != Vector2.ZERO:
		add_look_delta(stick.x * stick_sensitivity * delta, stick.y * stick_sensitivity * delta)

	if Input.is_action_just_pressed("zoom_in"):
		add_zoom_delta(-ZOOM_STEP)
	if Input.is_action_just_pressed("zoom_out"):
		add_zoom_delta(ZOOM_STEP)

	# Places the mount for THIS frame's look, not the last physics tick's (see LENS_RADIUS),
	# and clamps it (see MOUNT_MIN_Z), BEFORE anything below reads it.
	_resolve_arm()

	# Both of these read where the mount actually is now. Godot's main loop runs its physics
	# ticks, then _process, then renders, so this is the answer the frame is drawn with.
	_update_shoulder_offset()
	_keep_above_ground()
	_update_subject_fade()
	_update_near_fade()
	_apply_shake(delta)


## Kick the camera by `amount` (0..1; a catch is about 0.3, a rare one 0.55).
func add_trauma(amount: float) -> void:
	if shake_enabled:
		_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _apply_shake(delta: float) -> void:
	if _camera == null:
		return
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY * delta)
	if not shake_enabled or _trauma <= 0.0:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		return
	_shake_clock += delta
	var k := _trauma * _trauma * SHAKE_METRES
	var t := _shake_clock * 38.0
	# Two incommensurate sines an axis: a rattle with no visible period.
	_camera.h_offset = k * (0.6 * sin(t * 1.0) + 0.4 * sin(t * 2.31 + 1.7))
	_camera.v_offset = k * (0.6 * sin(t * 1.37 + 0.4) + 0.4 * sin(t * 2.79 + 2.9))


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
	var pitch := -delta_pitch if invert_look else delta_pitch
	_look_pitch = clampf(_look_pitch - rad_to_deg(pitch), PITCH_MIN_DEG, PITCH_MAX_DEG)
	_spring_arm.rotation.x = deg_to_rad(_look_pitch)


## Look along world heading `yaw` (radians, -Z forward) at the default pitch, at once: for
## when the player is put somewhere rather than walked there (the Spectra Palace's doors,
## game/world/ranch.gd), so she arrives looking where she is facing instead of wherever the
## mouse last left the lens.
func reset_look(yaw: float) -> void:
	global_rotation.y = yaw
	_look_pitch = clampf(default_pitch_deg, PITCH_MIN_DEG, PITCH_MAX_DEG)
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


## This rig's Camera3D. Exposed so callers (gates, the ranch's shot list) stop reaching in
## by node path: the camera moved one level deeper when the shoulder offset landed, and
## four call sites across the project had to be edited to follow it. There should be one.
func get_camera() -> Camera3D:
	return _camera


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
##
## THE SHOULDER OFFSET DOES NOT PUT THIS RAY OUT OF STEP WITH THE CROSSHAIR, and that is
## the whole reason the offset could be a plain translation with no convergence angle: the
## ray is projected out of the camera through the centre of the viewport, which is exactly
## where the HUD draws its reticle, so moving the camera moves both together. Verified
## rather than asserted -- game/scenes/test/camera_test.tscn takes a point along this ray
## and `unproject_position`s it back, and requires it to land within a pixel of the
## viewport centre at several distances, in every pose it renders.
func get_aim_ray() -> AimRay:
	var vp := get_viewport()
	var center := vp.get_visible_rect().size * 0.5
	return AimRay.new(_camera.project_ray_origin(center), _camera.project_ray_normal(center))


## How opaque the subject should be right now, given how far the arm is actually
## sitting from the pivot: 1.0 out at a normal distance, 0.0 once the camera is close
## enough that she would fill the frame. Static and pure so the ramp itself is testable
## without a scene, a spring arm or a rendered frame (game/test/test_camera_rig.gd).
##
## Reads FADE_END <= distance <= FADE_START; outside that range it saturates. Written
## as a smoothstep rather than a hard cut so the transition is not a pop when the arm
## is jittering across the threshold along a wall.
static func subject_opacity_for_distance(distance: float) -> float:
	return smoothstep(FADE_END, FADE_START, distance)


## The shoulder offset to apply at a given arm distance, in the ARM's local frame:
## `x` screen-right, `y` screen-up. Static and pure for the same reason the fade ramp
## above is -- the rule is testable without a spring arm or a rendered frame.
##
## EASED OUT OVER EXACTLY THE FADE BAND, and that is one decision, not two. The offset
## exists to keep the crosshair off the player's body; below FADE_START her body is being
## dissolved out of the shot precisely because the camera is close enough to be inside it,
## so there is nothing left to aim past and the reason for the offset has gone with her.
## Sliding the camera back onto her centre line as she disappears means:
##   * maximum zoom-in stays the clean, CENTRED near-first-person aiming view FADE_START's
##     comment promises, instead of a first-person view mysteriously half a metre to the
##     right of her head;
##   * a camera SHOVED in by geometry (the ranch's barn pulls this arm to 0.55 m) gets no
##     lateral offset at all, so the offset -- which is applied inside the arm and is
##     therefore not itself collision-probed -- cannot push the lens sideways into a wall
##     in the one situation where it is already hard against one. The arm's measured
##     pull-in behaviour is untouched by this whole feature, which is what keeps
##     game/world/ranch.gd's camera-vs-building numbers exactly as they were.
static func shoulder_offset_for_distance(distance: float) -> Vector3:
	# `ramp`, not `ease`: `ease()` is a GDScript global function, and shadowing it here
	# would be a warning in a file that has none.
	var ramp := smoothstep(FADE_END, FADE_START, distance)
	return Vector3(SHOULDER_SIDE * ramp, SHOULDER_LIFT * ramp, 0.0)


## How far from the pivot the spring ARM has put the camera mount, in metres: the arm's
## resolved length, and the number that is 0.55 m with the player's back against the
## ranch's barn. Drives both the subject fade and the shoulder ease.
##
## MEASURED OFF A REAL TRANSFORM, not read from `spring_length` (which is only the
## distance the player ASKED for and says nothing about a wall) and not from
## `get_hit_length()` either. The second is nearly right and was this function's first
## draft; it is avoided because it is the arm's own bookkeeping rather than where the arm
## actually left the mount, and this rig has already been bitten once by trusting a
## spring-arm property that did not mean what it read as -- see the `margin` note above.
##
## THE MOUNT AND NOT THE LENS, deliberately: the lens carries the shoulder offset, and the
## size of that offset is itself a function of this distance, so measuring it off the lens
## would feed the offset back into its own input. (It would also quietly widen the fade
## band by the length of the offset.) The lens's own distance is get_camera_distance().
func get_arm_distance() -> float:
	return _mount.global_position.distance_to(global_position)


## Where the lens really ended up relative to the pivot, in metres -- the arm's distance
## with the shoulder offset added on. Reported by game/world/ranch.gd's camera probe;
## nothing is DRIVEN by it, since driving anything by it would be circular (see above).
func get_camera_distance() -> float:
	return _camera.global_position.distance_to(global_position)


## The shoulder offset currently applied to the lens, in the arm's local frame. Exposed so
## a gate can assert the ease actually fired at a measured pull-in rather than only that a
## screenshot looked right -- the same reason get_subject_opacity() exists.
##
## This is what was APPLIED, which is shoulder_offset_for_distance() shortened by whatever
## the lens ball's sweep found in the way (_room_for()). The two differ only when something
## is actually beside the camera, and a gate wanting to prove the probe fired wants both.
func get_shoulder_offset() -> Vector3:
	return _camera.position


## Stops SpringArm3D's own margin math from driving the mount through the pivot to the
## front of the player. See MOUNT_MIN_Z for the full derivation and the measured numbers.
##
## SpringArm3D writes only `position.z` on its direct Node3D child every physics step (see
## the class comment); `position.x`/`position.y` are never touched, so there is nothing
## else here to clamp.
func _clamp_mount_margin() -> void:
	if _mount.position.z < MOUNT_MIN_Z:
		_mount.position.z = MOUNT_MIN_Z


## Slide the lens off the pony's centre line by however much the current arm distance has
## earned, and by however much room there actually is out there. See SHOULDER_SIDE for the
## framing reasoning and _room_for() for the sweep.
##
## Written every frame rather than once in _ready() because the arm distance moves (zoom,
## and geometry shoving the arm in), and because SpringArm3D would stomp it anyway if this
## were written onto the arm's own child -- see the class comment.
func _update_shoulder_offset() -> void:
	_camera.position = _room_for(shoulder_offset_for_distance(get_arm_distance()))


## `wanted` shortened to whatever fits, keeping its direction: the lens ball is swept from
## the mount out along the offset and stops at the first contact (see LENS_RADIUS). Returns
## `wanted` unchanged when nothing is in the way, which is the normal case.
func _room_for(wanted: Vector3) -> Vector3:
	if wanted.length() < 0.0001 or not is_inside_tree():
		return wanted
	return wanted * _sweep_fraction(_mount.global_position, _mount.global_basis * wanted)


## How much of `motion` the lens ball can travel from `from` before it touches anything: 1.0
## for a clear path, 0.0 for none. Falls back to the FALLBACK_RADII balls when the full one
## starts out touching something (see FALLBACK_RADII for why that check cannot be skipped).
func _sweep_fraction(from: Vector3, motion: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	_sweep_query.transform = Transform3D(Basis(), from)
	for ball in _sweep_balls:
		_sweep_query.shape = ball
		_sweep_query.motion = Vector3.ZERO
		if not space.intersect_shape(_sweep_query, 1).is_empty():
			continue
		_sweep_query.motion = motion
		var fraction := space.cast_motion(_sweep_query)
		return fraction[0] if fraction.size() > 0 else 1.0
	return 0.0


## Where the arm leaves the mount for THIS frame's look: the lens ball swept from the pivot
## out along the arm's own +Z (the way SpringArm3D casts), stopping at the first contact.
## SpringArm3D does the same sweep, but only on physics ticks -- see LENS_RADIUS for why that
## is not enough. Then the MOUNT_MIN_Z clamp, as before.
##
## WHEN HER HEAD IS INSIDE SOMETHING. The pivot is at 1.45 m and her capsule stops at 1.3 m,
## so she can walk under an eave, a balcony or a low bough that the pivot is then INSIDE --
## the playtest test found exactly that against the town row's OGB_1 house and under the
## wide trees. A sweep that starts inside a collider sees nothing (see FALLBACK_RADII), so
## the lens would sit in the eave. So the ball is first swept from the middle of her capsule
## (which the physics keeps clear of everything) up to the pivot; if it cannot get all the
## way, the arm is swept from where it stopped instead. The lens then always sits somewhere
## a ball can reach from her body without passing through anything.
func _resolve_arm() -> void:
	if not is_inside_tree():
		_clamp_mount_margin()
		return
	var length := _spring_arm.spring_length
	var arm := _spring_arm.global_basis.z.normalized() * length
	var pivot := _spring_arm.global_position
	if _body_shape != null and is_instance_valid(_body_shape):
		var centre := _body_shape.global_position
		var reach := _sweep_fraction(centre, pivot - centre)
		if reach < 1.0:
			var origin := centre + (pivot - centre) * reach
			_mount.global_position = origin + arm * _sweep_fraction(origin, arm)
			return
	_mount.position = Vector3(0.0, 0.0, length * _sweep_fraction(pivot, arm))
	_clamp_mount_margin()


## The last guard: the lens never ends up less than LENS_RADIUS above the ground the terrain
## DRAWS under it (Terrain.surface_height_at(), the same triangles its collider is built
## from). The sweeps above already keep it there; this holds even if a sweep ever tunnels
## between two of the ground's triangles. A scene with no terrain (the Factory, a GUT test)
## has nothing to hold it above, and is left alone.
func _keep_above_ground() -> void:
	if not ground_guard:
		return
	if _terrain == null or not is_instance_valid(_terrain):
		_terrain = get_tree().get_first_node_in_group(&"terrain") if is_inside_tree() else null
		if _terrain == null:
			return
	var at := _camera.global_position
	var floor_y: float = float(_terrain.call("surface_height_at", at.x, at.z)) + LENS_RADIUS
	if at.y < floor_y:
		_camera.global_position = Vector3(at.x, floor_y, at.z)


## How opaque the subject is being drawn right now, 1.0 (fully drawn) to 0.0 (hidden).
## Exposed so a gate can assert the fade actually fired at a measured close pull-in,
## rather than only that a screenshot looked right.
func get_subject_opacity() -> float:
	return subject_opacity_for_distance(get_arm_distance())


## Fade the subject in or out to match how close the camera has been pulled. See
## FADE_START for the whole reasoning; this is the three lines that apply it.
##
## `visible` is switched off outright at zero opacity rather than left at
## `transparency = 1.0`: a fully transparent mesh still costs a draw call and still
## writes into the depth prepass on some drivers, and "she is not drawn" is a stronger
## guarantee than "she is drawn with no alpha" for the thing this exists to prevent.
func _update_subject_fade() -> void:
	if _subject_meshes.is_empty():
		_collect_subject_meshes()
		if _subject_meshes.is_empty():
			return

	var opacity := subject_opacity_for_distance(get_arm_distance()) if _lens_live() else 1.0
	if is_equal_approx(opacity, _subject_fade):
		return
	_subject_fade = opacity

	var should_be_visible := opacity > 0.001
	for mesh in _subject_meshes:
		if not is_instance_valid(mesh):
			# A rebuilt body (a different pony wearing this rig) invalidates the cache.
			_subject_meshes.clear()
			_subject_fade = -1.0
			return
		# A screen-door dither, not alpha (P8, item 33; shaders/dither.gdshaderinc): never a
		# half-transparent ghost of her.
		mesh.set_instance_shader_parameter(&"dither_fade", opacity)
		# `visible` is only WRITTEN when the fade actually needs to flip it, not
		# reassigned to the same value on every opacity change (which happens on every
		# tiny camera-distance jitter while the arm sits in the fade band). This rig
		# does not own `visible` the way it owns `transparency` -- see the class comment
		# above on why `transparency` is the per-instance property used instead of the
		# shared material -- so stamping `true` over it every update would silently win
		# a fight with any other system that also wants a say over whether this mesh is
		# drawn (a future capture animation, an invisibility effect, ...), even though
		# this rig only actually cares about the two edges of that boolean.
		if mesh.visible != should_be_visible:
			mesh.visible = should_be_visible


func _update_near_fade() -> void:
	if _camera == null or not is_inside_tree():
		return
	if not _lens_live():
		# Another camera has the screen (a cinematic, a close-up): nobody is at this lens.
		for body: Variant in _near_faded.keys():
			if is_instance_valid(body):
				_fade_body(body as Node3D, 1.0)
		_near_faded.clear()
		return
	var lens := _camera.global_position
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = NEAR_FADE_FAR + 0.6
	q.shape = ball
	q.transform = Transform3D(Basis.IDENTITY, lens)
	q.collision_mask = CollisionLayersScript.PONY
	var seen := {}
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 16):
		var body := hit.collider as Node3D
		if body == null or seen.has(body):
			continue
		seen[body] = true
		var d := lens.distance_to(body.global_position + Vector3.UP * 0.7)
		var opacity := clampf((d - NEAR_FADE_CLOSE) / (NEAR_FADE_FAR - NEAR_FADE_CLOSE), 0.0, 1.0)
		_fade_body(body, opacity)
	for body: Variant in _near_faded.keys():
		if not seen.has(body):
			if is_instance_valid(body):
				_fade_body(body as Node3D, 1.0)
			_near_faded.erase(body)


## True while this rig's camera is the one on screen. The fades are about what stands at
## THIS lens (Fable AAA round 2, #4: a cut-in close-up showed Spike and a follower stippled
## because they stood by the gameplay camera, which was not even drawing).
func _lens_live() -> bool:
	var vp := get_viewport()
	return vp == null or vp.get_camera_3d() == null or vp.get_camera_3d() == _camera


func _fade_body(body: Node3D, opacity: float) -> void:
	var entry: Array = _near_faded.get(body, [-1.0, []])
	if is_equal_approx(float(entry[0]), opacity):
		return
	if (entry[1] as Array).is_empty():
		entry[1] = body.find_children("*", "GeometryInstance3D", true, false)
	for g: Variant in entry[1]:
		if is_instance_valid(g):
			(g as GeometryInstance3D).set_instance_shader_parameter(&"dither_fade", opacity)
	entry[0] = opacity
	_near_faded[body] = entry


## Collect the subject's own meshes -- and ONLY those.
##
## Scoped to the mount's `Visuals` child rather than to the whole body, which is not a
## nicety: the magic beam is also a child of the Player (player.gd explains why it is a
## sibling of `Visuals` and not under it), and it builds its ribbon and glow as
## MeshInstance3Ds of its own. Fading "every mesh under the player" would therefore
## make the beam vanish exactly when the player zooms in to aim with it, and would also
## fight magic_beam.gd for ownership of those nodes' `visible` flag, which it writes
## every frame. Falls back to the whole body only for a mount with no `Visuals` at all.
func _collect_subject_meshes() -> void:
	_subject_meshes.clear()
	var body := _find_collision_ancestor()
	if body == null:
		return
	var root: Node = body.get_node_or_null("Visuals")
	if root == null:
		root = body
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		_subject_meshes.append(mesh)


## The ancestor CollisionObject3D this rig is mounted under (the Player body), or null
## if this rig is used standalone (e.g. a GUT test with no such ancestor).
func _find_collision_ancestor() -> CollisionObject3D:
	var node := get_parent()
	while node != null:
		if node is CollisionObject3D:
			return node
		node = node.get_parent()
	return null
