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
##   is_secured() -> bool   -- whether releasing right now would KEEP her (see below).
##   get_storage() -> Storage -- what has been caught so far.
##
## A CAPTURE IS A CONTEST WITH TWO CLOCKS, which is the shape the first playtest asked
## for. The beam needs SECURE_SECONDS of unbroken hold to subdue a pony; she has
## STRUGGLE_* seconds of fight in her. Let go too early and she slips out; hold too long
## and she wins. Everything between is the window you are aiming for, and how wide it is
## is the whole of what her personality means under the beam. Before this, release()
## stored whatever was in the beam the instant it was called and the struggle timers were
## decorations on a decision already made -- the owner's report was "catching is really
## quick", and it was: point, click, done, in about a third of a second. The full
## reasoning and the numbers are on SECURE_SECONDS.
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
## the bag, node freed, rebuildable through PonyRegistry -> PonyVisuals), broken free --
## either because she out-lasted the struggle timer or because the beam was let go before
## it had secured her, both through _lose() (physics handed back, escaped() reported) --
## or refused by a full bag (set_held(false) and she drops where she was floating,
## unharmed). There is no fourth path, and the
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

## Why the last hold that did not end in a capture ended. Both values report `escaped()`
## -- from the pony's side they are the same event -- but they are two different MISTAKES,
## and a HUD that tells them apart is what makes the capture window learnable instead of
## mysterious. Read through get_last_loss().
enum Loss {
	NONE,       ## Nothing has been lost yet this session.
	SLIPPED,    ## Let go before SECURE_SECONDS: the beam never subdued her.
	STRUGGLED,  ## Held past her struggle time: she won on her own.
}

## Twilight's greeting line, played once on the FIRST successful capture as a placeholder
## for the future voice system (docs/notes-voice.md). Deliberately a plain constant path
## rather than PonyData.voice_bank: this is the player character reacting to her own
## success, not a line belonging to whoever was caught, and there is exactly one take in
## the repo so far. When the voice system lands, this is the one call site to rewrite.
const VOICE_LINE := "res://assets/audio/voice/twilight/greeting_01.wav"

## How far past the player the beam reaches, in metres.
##
## THE COMMENT THAT USED TO BE HERE ARGUED FOR EXACTLY THE WRONG RELATIONSHIP, AND THE
## GAME SHIPPED WITH IT. It read: "sized against the pony's own DETECTION_RADIUS (5 m):
## ... 8.5 m leaves a clear couple of metres of 'spot her, aim, take her' before she has
## even noticed you." That is a description of the bug, written down as if it were the
## design. A beam that out-reaches a pony's own senses means the player can ALWAYS take
## her before she reacts -- so the flee behaviour, which works perfectly, never once
## happens in play. The owner's first session found it immediately: "I could just hold
## click and walk up and catch them -- they should start running away farther than the
## range of the beam."
##
## The relationship is now the other way round and Pony.DETECTION_RADIUS (12 m) is the
## number that moved, not this one: REACH stays at 8.5 m because it is bounded by
## something real and unrelated -- past ~10 m the far end of the beam is a few pixels on
## screen and you cannot tell what you have hit. What the beam gains from here is
## upgrades: Phase 1B's shop sells reach, and every metre it sells eats into the 3.5 m of
## warning a pony currently gets, which is exactly what makes buying it feel like
## something. That is also the reason MIN_DETECTION_MARGIN below is stated as a margin
## rather than the two constants simply being compared: an upgrade path that can raise
## REACH needs a floor under how little warning a pony may be left with.
const REACH := 8.5

## Metres by which Pony.DETECTION_RADIUS must exceed REACH: the head start a pony is
## guaranteed even after every reach upgrade the shop can sell. 3.0 m is about six tenths
## of a second of the player's gallop, which is the least that can still read as "she saw
## me coming" -- and it also has to swallow GRAB_ASSIST_RADIUS, since the forgiveness pass
## makes the beam's EFFECTIVE grab distance half a metre longer than REACH says. Today's
## actual margin is 3.5 m (12.0 - 8.5). Asserted in game/test/test_magic_beam.gd and
## re-checked live in scenes/test/capture_test.gd -- see the note above on why this
## invariant, of all the numbers in this file, gets an explicit gate.
const MIN_DETECTION_MARGIN := 3.0

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
## smoothing. At 6.0 a body closes 90% of the gap in ln(10)/6 = 0.38 s.
##
## Slowed from 8.0 (0.29 s) after the playtest. On its own this is a small change -- the
## reel is a third longer and you get to watch her come -- and it is NOT the fix for
## "catching is really quick"; SECURE_SECONDS below is. It matters because the pull-in
## used to BE the whole capture: she arrived in 0.29 s and was stowable from that instant,
## so the struggle timers underneath were decoration. Now the pull is the first beat of a
## capture rather than the whole of it.
const PULL_RESPONSE := 6.0

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
##
## Raised from 0.75 s once losing a pony became a real outcome (see SECURE_SECONDS). At
## 0.75 s an escapee got back roughly to where she started -- she is set down at the hold
## point, about 3.3 m from the player, and 0.75 s of accelerating from a standstill buys
## her about 1.4 m, still deep inside REACH -- so "she wriggled free" cost the player a
## button press. 1.25 s puts her at her full flee speed and about 3 m further out, so the
## second attempt is a moving target at the edge of the beam and you have to work for it.
const ESCAPE_COOLDOWN := 1.25

## Seconds the beam must have a pony in it before she can be stowed. THE FIX FOR THE
## OWNER'S FIRST COMPLAINT: "catching is really quick -- it took me several tries to get a
## screenshot of one."
##
## Before this constant existed, release() stored whatever was in the beam, unconditionally
## and instantly. The pull-in finishes in ~0.3 s, so the entire mechanic was: point,
## click, done. The per-personality struggle timers below were real, ran correctly, and
## were tuned with care -- and no player would ever have discovered any of it, because
## nobody has a reason to hold a button down when letting go already won. The HUD's
## struggle ring was drawing a countdown on a decision that had already been made.
##
## So a capture is now a two-sided clock. The beam needs SECURE_SECONDS of unbroken hold
## to subdue her; she has STRUGGLE_* seconds of fight in her. Let go inside the first and
## she slips out of the field and drops back into the world -- alive, and now spooked. Hold
## past the second and she wins outright. Between them is a window whose WIDTH is the
## difference of the two numbers, and that window is the mechanic:
##
##   SHY      1.90 - 1.15 = 0.75 s   a real scramble; you must be watching the ring
##   CURIOUS  2.60 - 1.15 = 1.45 s   comfortable if you are paying attention
##   BOLD     4.00 - 1.15 = 2.85 s   effectively a free catch, as the trait says
##
## WHY THE SUBDUE TIME IS THE SAME FOR EVERYONE and only the resistance varies: it keeps
## one number as "what the beam does" and one as "who she is", so the personalities stay
## legible. A player learns "Fluttershy is a handful" from the ring draining fast, not
## from the beam behaving differently.
##
## 1.15 s specifically: comfortably past the 0.38 s pull-in, so the whole of the secure
## phase is spent watching a pony who has actually arrived and is visibly fighting; and
## short enough that the twelfth catch of a session is a second-and-a-bit of commitment
## rather than a chore. The floor on it is the pull-in (a secure time under ~0.5 s would
## complete while she was still in transit and the contest would be invisible again); the
## ceiling is STRUGGLE_SHY, and test_magic_beam.gd asserts a real margin under it, because
## a secure time that met or passed a personality's struggle time would make that
## personality flatly uncatchable.
const SECURE_SECONDS := 1.15

## Seconds a held pony resists before she breaks free, by personality. Together with
## SECURE_SECONDS above these are the whole of the mechanic's tension: how long you have
## to act, and how long it is tells you something about who you caught.
##
## SHY is the short one (the brief's requirement, and the obvious reading of the trait --
## a pony who bolts the moment she sees you is not going to hang about in a magic field),
## BOLD the long one (she was not worried about you on the ground and she is not worried
## now), and CURIOUS sits between them, which matches her behaviour everywhere else: she
## is the one who walks TOWARD the player, so she has the least reason to fight and the
## most reason to stay and see what happens.
##
## Nudged from 1.5 / 2.5 / 4.0 rather than rewritten: SHY up to 1.90 so that subtracting
## the new secure time still leaves a window a human can hit (0.75 s -- three reaction
## times), CURIOUS up to 2.60 to keep the spacing, BOLD left exactly where it was because
## 2.85 s of window is already "free catch" and more would just be waiting.
const STRUGGLE_SHY := 1.9
const STRUGGLE_CURIOUS := 2.6
const STRUGGLE_BOLD := 4.0

## Struggle time for anything that is not a pony, in seconds. Props do not resist; a crate
## stays in the beam until the player lets go.
const STRUGGLE_NEVER := INF

## Secure time for anything that is not a pony, in seconds. A crate is not subdued, it is
## simply carried, so there is nothing to wait out before dropping it -- and a drag-and-
## drop toy with a mandatory 1.15 s arming delay would be a worse toy.
const SECURE_NEVER := 0.0

@export_group("Storage")
## How many ponies the player can carry. Twelve is a placeholder for whatever the barn
## economy decides in a later phase -- it is a data question, not a beam question.
@export var storage_capacity := 12

## Segments in the beam ribbon. Sixteen is enough that the bow reads as a curve rather
## than as a bent stick at any length the beam can reach.
const BEAM_SEGMENTS := 16

## How far the beam bows sideways, as a fraction of its own length, and the absolute
## ceiling on that. 0.30 of a typical 4 m hold is about 1.2 m of clearance -- comfortably
## past the player's 0.42 m capsule from every camera angle.
##
## THE CAP IS THE PLAYTEST FIX for "the curve as well is nice, curved a bit odd". A pure
## fraction keeps growing: at the far end of REACH the control point was 2.55 m out to one
## side, which puts the arc's apex more than a metre off the line between the horn and
## what you are pointing at. Since the bow is always taken toward CAMERA-right, aiming at
## something on your LEFT sent the beam swerving out to the right and back again -- the
## beam visibly went somewhere other than where it was going. The clearance the bow exists
## to buy is a fixed thing (getting past the player's own silhouette), so the sideways
## offset should saturate rather than scale: short beams keep the same clearance they
## always had and long ones straighten out into a clean lob.
const BOW_FRACTION := 0.30
const BOW_SIDE_MAX := 1.2

## How far the beam also lofts upward, as a fraction of its own length. Deliberately NOT
## capped, unlike the sideways bow: the loft is the one part of the arc that is doing
## legible work at range. It puts the apex of a long reach against the SKY rather than
## against the green ground the pony at the far end is also standing on (a pink ribbon on
## grass at 8 m is a lot harder to pick out than the same ribbon on grey) -- and because it
## keeps growing with length, HOW HIGH THE ARC RIDES IS ITSELF A DISTANCE CUE, which is
## exactly what the owner said was missing ("hard to gauge distance of beam"). Raised from
## 0.14 now that the sideways swerve is no longer competing with it for the eye.
const BOW_LIFT_FRACTION := 0.18

## Half-width of the ribbon at the horn and at the far end, in metres. Narrow where it
## leaves her and flared where it lands, so it reads as something being projected rather
## than as a rod -- and so the far end is still legible at REACH.
const BEAM_WIDTH_NEAR := 0.06
const BEAM_WIDTH_FAR := 0.30

## Radius of the glow at the far end, in metres: a bright bead while the beam is sweeping
## for something, and a wider, fainter aura wrapping whatever it has hold of.
const GLOW_TIP_RADIUS := 0.28
const GLOW_HELD_RADIUS := 0.70

# --- the landing marker ----------------------------------------------------------------
# THE OTHER HALF OF "HARD TO GAUGE DISTANCE OF BEAM". An arc hanging in the air has no
# ground reference, and a third-person camera 3.5 m behind the player flattens depth
# further -- so a beam ending 4 m away and a beam ending 8 m away look much the same. The
# fix is the oldest one in 3D games: put a mark ON THE GROUND under where the beam lands.
# The ground is a surface the player is already reading perspective off, so a ring on it
# is unambiguous in a way a floating bead is not, and it moves with the crosshair, which
# makes sweeping for range a thing you can DO rather than guess at.
#
# It doubles as the in-range answer: the ring is one colour over bare ground and another,
# larger one when there is actually something grabbable within reach under the crosshair.
# "Can I take her from here?" stops being a question you answer by trying.
#
# STRICTLY IT IS A LANDING MARK, NOT A GROUND MARK -- it lies on whatever surface the beam
# actually reached, oriented to that surface's normal, and only falls back to a downward
# probe when the beam ran out over open air. Over an empty field that is the grass, which
# is the case this was built for. Over a pony it is HER, and the render showed that reads
# as a target-lock ring around her, which is the right answer for the wrong reason and is
# kept deliberately: the rule stays the simple one ("the mark is where the beam lands"),
# and the picture is better than a ring hidden under her hooves would have been.

## Outer radius of the landing ring in metres, sweeping and locked-on.
##
## SIZED FROM A RENDER, not from what looks reasonable in the source. The first pass used
## 0.45 m and it was invisible in practice: the ring lies FLAT, and the camera sits about
## two metres off the ground, so at the far end of REACH it is foreshortened to roughly a
## twentieth of its width and reads as a couple of pink pixels lost in the grass. That
## foreshortening is not a flaw -- it is exactly the perspective cue that makes a ground
## marker worth drawing at all -- but the ring has to be big enough to survive it. At
## 0.75 m it is about a pony's own footprint, which is also the honest size for something
## that means "this is where the beam lands".
const MARK_RADIUS := 0.75
const MARK_LOCKED_RADIUS := 1.15
## Radial thickness of the ring's band. Wide enough that the near edge of a heavily
## foreshortened ring is still a band rather than a line.
const MARK_THICKNESS := 0.14
## Segments around the ring. 32 is smooth at the near distances where it is biggest.
const MARK_SEGMENTS := 32
## Metres the ring is lifted off the surface it was found on, so it does not z-fight with
## the terrain it is lying on.
const MARK_LIFT := 0.04
## How far above and below the beam's far end the ground is probed for, when the beam is
## pointing at open sky and there is no ray hit to sit the ring on.
const MARK_PROBE_UP := 3.0
const MARK_PROBE_DOWN := 40.0
## Colour of the ring when the crosshair has something grabbable in range. Deliberately
## NOT the beam's pink: this is the one piece of the effect that has to be readable AS a
## different state, and a brighter shade of the same hue reads as "the beam, but more".
## Matches the HUD reticle's own in-range colour so the two are obviously one signal.
const MARK_LOCKED_COLOR := Color(1.0, 0.86, 0.42)

## Half-width of the drop line, in metres: the thin vertical connector from the beam's far
## end down to the ring, drawn only when the beam ends in mid-air rather than on a surface
## (aimed over a hollow, or out at open sky). Without it those two are just a ribbon
## stopping at nothing and an unrelated circle on the grass some way below; with it the
## whole thing reads as one plumb line, which is the same trick every level editor's
## translate gizmo uses for the same reason.
const MARK_DROP_WIDTH := 0.045
## Metres of separation below which the drop line is not worth drawing.
const MARK_DROP_MIN := 0.20

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
var _secure_seconds := SECURE_NEVER
## Offset from the hold point to the held body's ORIGIN -- see PONY_HOLD_LIFT.
var _hold_offset := Vector3.ZERO
## RigidBody3D state borrowed at grab time and handed back on release.
var _prev_freeze := false
var _prev_freeze_mode := RigidBody3D.FREEZE_MODE_STATIC

var _cooldown := 0.0
## Why the most recent lost hold was lost -- see the Loss enum.
var _last_loss := Loss.NONE
## Where the beam visual currently ends when nothing is held: the ray's hit point, or the
## end of its reach.
var _ray_end := Vector3.ZERO
var _elapsed := 0.0

## Whether the last scan found something grabbable inside REACH under the crosshair --
## refreshed every frame the beam is on and empty, INDEPENDENTLY of whether the beam was
## allowed to take it (the post-escape cooldown must not blank the reticle's answer to
## "is she in range", or the readout lies for a second and a quarter at exactly the moment
## the player is re-aiming at an escapee).
var _has_target := false
## Where the landing ring sits and which way it lies, from the last scan.
var _mark_point := Vector3.ZERO
var _mark_normal := Vector3.UP
var _mark_valid := false

var _beam_mesh: MeshInstance3D
var _beam_material: StandardMaterial3D
var _glow_mesh: MeshInstance3D
var _mark_mesh: MeshInstance3D
var _mark_material: StandardMaterial3D
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


## Switch the beam off, and settle whatever was in it.
##
## THE OUTCOME NOW DEPENDS ON HOW LONG YOU HELD HER, which is the whole of the capture
## contest (see SECURE_SECONDS). A pony held at least that long is SECURED: she goes into
## storage if there is room -- her record is stored, `captured()` fires, her node is freed
## -- and otherwise is set down in the world unharmed with `capture_refused()`. A pony let
## go before that has not been subdued at all; the field slips off her and she drops back
## into the world exactly the way she does when she out-lasts the struggle timer, reported
## the same way (`escaped()`), because from her point of view it is the same event: the
## beam let go and she is still free. A held prop was never being subdued and just drops.
func release() -> void:
	_beaming = false
	var body := _held
	var was_secured := is_secured()
	_take_back_physics(body)
	_held = null

	if body != null and is_instance_valid(body):
		if body is PonyScript:
			if was_secured:
				_settle_pony(body)
			else:
				_lose(body, Loss.SLIPPED)
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


## Seconds the beam needs to subdue the currently held body before it can be stowed, or 0
## for something that does not need subduing at all (a prop).
func get_secure_seconds() -> float:
	return _secure_seconds if is_holding() else SECURE_NEVER


## How far the current hold has got toward being secured, 0..1. What the HUD fills its
## capture arc from -- exposed as a fraction rather than as two clocks so there is one
## place that decides what "nearly there" means.
func get_secure_progress() -> float:
	if not is_holding() or _secure_seconds <= 0.0:
		return 1.0
	return clampf(_hold_seconds / _secure_seconds, 0.0, 1.0)


## Whether the current hold has lasted long enough that letting go would STOW her rather
## than lose her. False when nothing is held.
func is_secured() -> bool:
	return is_holding() and _hold_seconds >= _secure_seconds


## Why the most recent `escaped()` happened: Loss.SLIPPED (let go too early) or
## Loss.STRUGGLED (held too long). Loss.NONE until one has.
func get_last_loss() -> int:
	return _last_loss


## Whether the crosshair currently has something grabbable within reach -- a pony or a
## loose prop the beam could take from here. True whether or not the beam is switched on
## (see the scan note in _physics_process: an in-range readout you can only get by pressing
## the button is a readout that arrives after the decision), and true while actually
## holding something. The HUD's in-range reticle reads this; it is the answer to the
## question the owner could not answer by looking ("hard to gauge distance of beam"),
## which no amount of tuning the beam's own geometry can give on its own.
func has_target() -> bool:
	return is_holding() or _has_target


## Where the beam's landing ring is being drawn, in world space, and whether it is being
## drawn at all (false when the beam is off, or aimed at open sky over nothing).
func get_mark_point() -> Vector3:
	return _mark_point


func has_mark() -> bool:
	return _mark_valid and _beaming and not is_holding()


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


## The seconds of slack a player has to let go in, for a pony with this `personality`:
## everything between "the beam has subdued her" and "she has won". This is the number
## that says how hard she is to catch, and it is the difference of two other numbers --
## which is exactly why it gets a name, because neither of them means anything on its own
## and a retune of either silently changes it. Static and pure; pinned by
## game/test/test_magic_beam.gd.
static func capture_window_for(personality: int) -> float:
	return struggle_seconds_for(personality) - SECURE_SECONDS


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

	_update_aim()

	# SCANNED EVERY FRAME, INCLUDING WHEN THE BEAM IS SWITCHED OFF. Three jobs, and the
	# third is why this is not gated on `_beaming` any more:
	#   1. it finds what to grab;
	#   2. it tells the effect where to END (which is why it also runs during the
	#      post-escape cooldown, when it may not grab -- otherwise the beam would be drawn
	#      to a stale point for the whole of it);
	#   3. it answers has_target(), which the HUD reticle uses to say "she is in range".
	# That third answer is worthless if it can only be had while the beam is ON, because
	# switching the beam on with a pony in the crosshair GRABS her on the same frame -- so
	# the in-range state would exist for one frame, after the decision it was supposed to
	# inform. "Am I close enough?" has to be answerable before you commit, or the reticle
	# is telling you something you already know.
	#
	# The cost is one ray cast and one small sphere query per physics frame while idle,
	# which is nothing next to what the rest of the frame is doing; the mark and the ribbon
	# are still only DRAWN while the beam is on (see has_mark(), and _hide_effect below).
	if _held == null:
		_scan(_beaming and _cooldown <= 0.0)

	if not _beaming:
		_hide_effect()
		return

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
	_has_target = false
	_mark_valid = false

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
		# The surface the ray landed on IS the surface to lie the ring on, normal and all
		# -- no second cast needed, and it means the ring hugs a slope rather than floating
		# level over it.
		_mark_at(hit["position"], hit.get("normal", Vector3.UP))
		var body: Object = hit["collider"]
		if _is_grabbable(body):
			# Recorded BEFORE the cooldown gate, deliberately: "there is something in range"
			# stays true through the post-escape cooldown, because that is exactly when the
			# player is re-aiming and needs to know it.
			_has_target = true
			if can_grab:
				_begin_hold(body)
				return

	# Forgiveness pass, centred on whatever the ray actually reached. Runs whether or not
	# the beam may grab, for the same reason as above -- the reticle must answer the same
	# question the grab would.
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
		_has_target = true
		if can_grab:
			_begin_hold(nearest)
			return

	if not _mark_valid:
		# The beam is pointing at open sky, so the ray gave no surface to mark. Probe
		# straight down from the far end instead: the ring then sits on the ground BELOW
		# where the beam runs out, which is still the answer to "how far does this thing
		# go", and is the case a player sweeping across an empty field is in most of the
		# time.
		var probe := PhysicsRayQueryParameters3D.create(
			_ray_end + Vector3.UP * MARK_PROBE_UP, _ray_end + Vector3.DOWN * MARK_PROBE_DOWN)
		probe.exclude = _exclusions()
		var ground := space.intersect_ray(probe)
		if not ground.is_empty():
			_mark_at(ground["position"], ground.get("normal", Vector3.UP))


## Record where the landing ring goes. Degenerate normals (a collider that reports none)
## fall back to straight up rather than producing a ring lying in an undefined plane.
func _mark_at(point: Vector3, normal: Vector3) -> void:
	var up := normal
	if up.length_squared() < 0.000001:
		up = Vector3.UP
	up = up.normalized()
	_mark_point = point + up * MARK_LIFT
	_mark_normal = up
	_mark_valid = true


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
		_secure_seconds = SECURE_SECONDS
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
		_secure_seconds = SECURE_NEVER


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
	_lose(body, Loss.STRUGGLED)


## The one exit from a hold that is not a capture, used by BOTH ways of failing one: she
## out-lasted the struggle timer (_run_struggle above), or she was let go before the beam
## had subdued her (release()). Deliberately one code path -- an escape that set the
## cooldown and a slip that did not would be a mechanic with a hole in it exactly where
## the player is fumbling. Callers hand the physics back first.
##
## Reported as `escaped()` in both cases: from the pony's point of view they are the same
## event -- the beam let go and she is still free. `reason` is recorded rather than
## signalled, so listeners that do not care are unaffected and the HUD, which does care,
## can tell the player WHICH mistake they just made. Teaching "you let go too soon" is the
## difference between a mechanic a player learns and one they think is random.
func _lose(body: Node3D, reason: int) -> void:
	_last_loss = reason
	_cooldown = ESCAPE_COOLDOWN
	if body == null or not is_instance_valid(body):
		return
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

	# The landing ring. Its own material because it needs `no_depth_test`: the ring lies
	# ON the ground it is marking, and MARK_LIFT alone is not enough to keep a 4 cm offset
	# from being eaten by the depth buffer on a slope at 8 m. Drawing it through the
	# terrain is the right trade for a marker whose entire job is to be seen.
	var mark_material: StandardMaterial3D = material.duplicate()
	mark_material.no_depth_test = true
	# Rendered after everything else, so it is not sorted behind the ground it overlays.
	mark_material.render_priority = 1
	_mark_material = mark_material

	_mark_mesh = MeshInstance3D.new()
	_mark_mesh.name = "BeamMark"
	_mark_mesh.mesh = ImmediateMesh.new()
	_mark_mesh.top_level = true
	_mark_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mark_mesh)


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
	# The sideways bow SATURATES (see BOW_SIDE_MAX) and the loft does not. Short beams --
	# the hold, mostly -- keep exactly the clearance they always had; long ones straighten
	# out sideways and gain height instead, which is both a calmer shape and a distance cue.
	var control := from + span * 0.5 \
		+ side * minf(length * BOW_FRACTION, BOW_SIDE_MAX) \
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

	_draw_mark()


## The ring on the ground under where the beam lands -- the distance cue. Hidden while
## something is held (there is nothing left to judge the range of; the pony is in the
## beam) and while the beam has found no surface at all.
func _draw_mark() -> void:
	if not has_mark():
		_mark_mesh.visible = false
		return

	# Two axes spanning the marked surface, so the ring lies flat ON a slope rather than
	# hovering level over it. UP is the natural reference; the fallback covers a wall or
	# an overhang, where the first cross product collapses.
	var right := _mark_normal.cross(Vector3.UP)
	if right.length_squared() < 0.000001:
		right = _mark_normal.cross(Vector3.RIGHT)
	right = right.normalized()
	var forward := right.cross(_mark_normal).normalized()

	var locked := _has_target
	var outer: float = MARK_LOCKED_RADIUS if locked else MARK_RADIUS
	# The same slow pulse the tip glow uses, so the two read as one effect.
	outer *= 1.0 + 0.06 * sin(_elapsed * 9.0)
	var inner: float = maxf(outer - MARK_THICKNESS, 0.01)
	var color: Color = MARK_LOCKED_COLOR if locked else beam_color

	var mesh: ImmediateMesh = _mark_mesh.mesh
	mesh.clear_surfaces()
	_mark_material.albedo_color = Color(color.r, color.g, color.b, 0.9 if locked else 0.55)
	_mark_material.emission = color
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mark_material)
	for i in range(MARK_SEGMENTS + 1):
		var angle := TAU * float(i) / float(MARK_SEGMENTS)
		var dir := right * cos(angle) + forward * sin(angle)
		mesh.surface_add_vertex(_mark_point + dir * inner)
		mesh.surface_add_vertex(_mark_point + dir * outer)
	mesh.surface_end()

	# The drop line, when the beam ran out in mid-air above the ground it marked.
	var drop := _ray_end - _mark_point
	if drop.length() > MARK_DROP_MIN:
		var camera := get_viewport().get_camera_3d() if get_viewport() != null else null
		var eye: Vector3 = camera.global_position if camera != null else _aim_origin
		var across := drop.cross(eye - _mark_point)
		if across.length_squared() < 0.000001:
			across = drop.cross(Vector3.RIGHT)
		across = across.normalized() * MARK_DROP_WIDTH
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mark_material)
		mesh.surface_add_vertex(_mark_point - across)
		mesh.surface_add_vertex(_mark_point + across)
		mesh.surface_add_vertex(_ray_end - across)
		mesh.surface_add_vertex(_ray_end + across)
		mesh.surface_end()

	_mark_mesh.global_transform = Transform3D.IDENTITY
	_mark_mesh.visible = true


## Quadratic Bezier through `control`, used for the beam's bow.
static func _bezier(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	var inv := 1.0 - t
	return a * (inv * inv) + control * (2.0 * inv * t) + b * (t * t)


func _hide_effect() -> void:
	if _beam_mesh != null:
		_beam_mesh.visible = false
	if _glow_mesh != null:
		_glow_mesh.visible = false
	if _mark_mesh != null:
		_mark_mesh.visible = false


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
