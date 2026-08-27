extends Node3D
## Task 8 verification scene for the magic beam and capture storage
## (game/actors/player/magic_beam.gd, game/systems/storage.gd).
##
## A ground plane, a real Player (real camera rig, real horn marker, real beam), one
## pony at a time at a KNOWN spot, and a crate. Eight phases, each of which is a separate
## claim about the mechanic and each of which is failed by a different bug:
##
##   WARNING  the invariant the first playtest was lost to, plus the one sanctioned way
##            round it that the second playtest added. A pony must out-see the beam
##            against a RUNNING player, so she is already going before she can be taken --
##            checked as arithmetic (Pony.notice_radius_for(p, false) >= MagicBeam.REACH +
##            MIN_DETECTION_MARGIN, over every personality) AND behaviourally, with a SHY
##            pony stood BEYOND the beam's reach who must bolt anyway, and a BOLD one
##            stood at the same distance whom the beam, aimed straight at her, must fail
##            to pick up. Then the sneak: the notice distance is MEASURED, by walking the
##            real player in from 20 m in 0.25 m steps and recording the gap at which she
##            actually bolts, once creeping and once running. Two numbers that must differ
##            by half, from the same pony, on the same ground.
##   CONTEST  what a capture is now WORTH, per personality, measured rather than asserted
##            from constants. For each of SHY / CURIOUS / BOLD: hold on and let her win,
##            timing when the beam secured her and when she broke free (that difference IS
##            her window); then take a fresh one and let go on the green ring, which must
##            store her. The second playtest inverted which personality is hard to hold --
##            SHY freezes, BOLD fights -- so the MEASURED windows are checked for that
##            ordering too, and an accidental re-inversion fails here as well as in the
##            unit tests.
##   GRAB     aim the rig at the pony through the same get_aim_ray() the beam uses, switch
##            the beam on, and check she enters HELD and is REELED IN -- her distance to
##            the hold point must collapse, not merely be small at the end (a beam that
##            teleported her would pass a "she is near the hold point" check on its own).
##   CAPTURE  hold her until the beam has SECURED her, then let go: her record must be in
##            Storage (count 1) and her NODE must be gone. Checked through a WeakRef, not
##            through is_instance_valid on a variable we are still holding -- the second
##            would keep the reference alive.
##   DISTINCT catch a second pony of the SAME CHARACTER and prove the bag holds two
##            INDIVIDUALS with different uids and independently movable state, not two
##            pointers to one shared PonyData record. Then let one back out through
##            MagicBeam.release_stored() and catch her again, and check she comes back as
##            the very same individual, with the state she went in with -- a recapture
##            that quietly reset her would be exactly the amnesia PonyInstance exists to
##            prevent.
##   SLIP     the other half of the capture contest: let go of a pony BEFORE the beam has
##            secured her and she must NOT go in the bag -- she is reported as escaped(),
##            with Loss.SLIPPED, and left alive in the world. This is the check with the
##            teeth for the fix to "catching is really quick": on the old build, where
##            release() stored whatever it was holding, this phase fails outright.
##   FULL     fill the bag, then hold and release another pony: store() must refuse, the
##            count must NOT grow, and she must still be in the world. NO PONY EVER DIES
##            is a project-wide rule and this is the branch where a careless
##            implementation drops one.
##   PROP     a loose RigidBody3D must be draggable too, and must get its physics back
##            (freeze cleared) when it is let go.
##
## THE MECHANICS PHASES SWITCH THE PONY'S OWN DETECTION OFF, and that is a consequence of
## the fix rather than a convenience. Detection now EXCEEDS reach by construction, so any
## pony the beam can touch is by definition a pony who has already noticed the player --
## there is no longer a distance at which a stationary, unreacting target exists. A gate
## that wants to measure the beam rather than the chase therefore has to say so out loud
## (see _spawn_pony's `reacts` argument), instead of relying on a gap in the design that
## no longer exists and should not. The WARNING phase is where reacting ponies are used.
##
## WHY THIS GATE CAN FAIL -- the part worth writing down, because this project has
## repeatedly shipped gates that passed while measuring nothing (a harness that passed
## with zero tests; a hair metric reading a search-window boundary; a probe inert to the
## parameter it swept; a "seeded" spawn that differed between processes):
##
##   * The aim is not faked. The camera is driven by add_look_delta() until
##     get_aim_ray() points at the pony, and the ANGLE is asserted before the grab -- so
##     "the beam found her" cannot be true because the gate handed the beam a target.
##     If get_aim_ray() regressed, the aim check goes red before any capture is attempted.
##   * Reeling in is checked as a RATIO (final gap < a quarter of the gap at acquisition)
##     as well as an absolute, so a beam that dropped the lerp and simply snapped her
##     into place, or one that never moved her at all, both fail.
##   * The capture check is "the node is gone AND the record is in the bag". Freeing her
##     without storing her, or storing her without freeing her, each fail one half.
##   * The full-bag check asserts a NON-event (the count did not grow) plus a live pony
##     afterwards; a store() that returned false after already appending fails the first,
##     and a beam that deleted the refused pony fails the second.
##   * The CONTEST phase's escape windows are narrow enough to fail on the wrong
##     personality's number -- swapping any two struggle times fails it -- and the phase
##     additionally checks the MEASURED windows against each other, so a build where every
##     individual number looked plausible but the ordering had flipped still goes red.
##   * The sneak is measured as a DISTANCE, not asserted from the constant it is computed
##     from: a build that read Pony.SNEAK_NOTICE_FACTOR but never asked the player whether
##     he was sneaking would still print two identical numbers here.
##   * The SECURE checks are two-sided. "The reel finishing is not by itself a capture"
##     goes red if SECURE_SECONDS is removed, zeroed, or set under the pull-in; "holding
##     her long enough secures her" goes red if it is set impossibly high. A one-sided
##     check would have been satisfied by the broken build in one direction or by an
##     uncatchable one in the other.
##   * The out-of-reach grab is measured on a BOLD pony with her routine pinned, so "the
##     beam did not take her" cannot be an artefact of a target that wandered aside.
##   * Every phase re-checks that the pony it just finished with is still a valid
##     instance, except the captured one, which is asserted to be gone.
##
## Verified against a deliberately broken build before it was trusted -- see the failure
## proof in the task report.
##
## OFFSCREEN RENDERING (`xvfb-run -a tools/bin/godot --path game --audio-driver Dummy
## scenes/test/capture_test.tscn -- --screenshot-dir=<path>`, NOT `--headless`): runs the
## same eight phases and additionally saves PNGs THROUGH THE PLAYER'S OWN CAMERA, which is
## the only way to answer the questions no number here can: is the beam legible, and does
## a held pony sit at a sensible distance in front of the camera rather than clipping into
## it? Structural gates in this project have been green through an invisible character
## before (docs/pipeline.md section 7).
##
## `--audio-driver Dummy` is REQUIRED here, explicitly, and not merely implied by
## `--headless` the way it is on every other gate: this scene is windowed/offscreen, not
## headless (headless renders nothing to screenshot), so Godot's own
## `--headless`->dummy-audio-driver mapping does not apply, and without this flag a run
## opens a real audio device. This is the exact scene whose CAPTURE phase fires
## game/actors/player/magic_beam.gd's first-capture voice line
## (assets/audio/voice/twilight/greeting_01.wav) -- an automated Proton verification run
## of this same mechanic once played that line out loud through real speakers/
## headphones before this flag existed. game/systems/audio_safety.gd (an autoload) mutes
## the Master bus on its own as a backstop whenever it sees a `--screenshot...` arg, in
## case a future invocation forgets this flag.

const PonyScene := preload("res://actors/pony/pony.tscn")
const PonyScript := preload("res://actors/pony/pony.gd")
const PonyDataScript := preload("res://systems/pony_data.gd")
const PonyInstanceScript := preload("res://systems/pony_instance.gd")
const PonyRegistryScript := preload("res://systems/pony_registry.gd")
const MagicBeamScript := preload("res://actors/player/magic_beam.gd")
const PlayerScript := preload("res://actors/player/player.gd")
const GateWatchdogScript := preload("res://scripts/gate_watchdog.gd")

## Physics frames to let the player settle onto the ground and the spring arm's collision
## probe run before anything is aimed or grabbed.
const SETTLE_FRAMES := 12

## How many correction steps the aim loop takes. The camera hangs off a SPRING ARM, so
## changing the pitch MOVES the eye point the ray starts from -- one analytic step would
## overshoot. Twelve is far more than the three or four it actually converges in.
const AIM_ITERATIONS := 12

## Maximum angle, in degrees, between the aim ray and the line to the pony's chest that
## still counts as "aimed at her". Tight: the point of the check is that the beam is
## following the crosshair, not that it eventually found something.
const AIM_TOLERANCE_DEG := 1.0

## Frames to let the pull-in finish. PULL_RESPONSE reels 90% of the gap in ~0.38 s, so 45
## frames (0.75 s) is well past settled -- and still under every struggle time, so this
## wait cannot itself cause an escape.
##
## Deliberately still SHORTER than MagicBeam.SECURE_SECONDS (1.15 s): the reel finishing
## before the beam has secured her is exactly the property the capture contest is built on,
## and the GRAB phase asserts it at this frame rather than assuming it.
const PULL_FRAMES := 45

## Longest a phase will wait for the beam to report the hold secured, in frames. Derived
## from the constant rather than typed, so a retune of SECURE_SECONDS cannot leave this
## gate timing out on a build that is behaving perfectly.
const SECURE_WAIT_FRAMES := int(MagicBeamScript.SECURE_SECONDS * 60.0) + 30

## Where the WARNING phase stands its ponies, as metres in front of the player.
##
## SIZED INTO A BAND, not picked. The floor is the beam's EFFECTIVE grab distance, which
## is not REACH: the horn sits ~0.3 m ahead of the player's origin and the forgiveness
## pass (MagicBeam.GRAB_ASSIST_RADIUS) adds another 0.5 m, so a pony is takeable out to
## about REACH + 0.8 m from where the player stands. The ceiling is
## MagicBeam.MIN_DETECTION_MARGIN past REACH -- the least detection radius the invariant
## permits -- because a spot outside THAT would stop the SHY pony reacting on a build that
## is still legal, and this gate would fail for the wrong reason. REACH + 1.75 sits in the
## middle of that band with about a metre of clearance either side.
const OUT_OF_REACH_DISTANCE := MagicBeamScript.REACH + 1.75
const OUT_OF_REACH_SPOT := Vector3(0.0, 0.0, -OUT_OF_REACH_DISTANCE)

## Frames the WARNING phase gives a SHY pony to notice the player and bolt. She reacts on
## the first physics frame her DetectionArea reports him, so this is generous; it is a
## bound on a hang, not a tolerance.
const REACT_FRAMES := 30

## Metres from the hold point at which a held body counts as arrived.
const ARRIVE_TOLERANCE := 0.25

## The gap at the end must be no more than this fraction of the gap at acquisition. This
## is the check that the pony was actually TRANSPORTED rather than grabbed where she
## already stood.
const ARRIVE_RATIO := 0.25

## Minimum metres between the camera and a held body. The eyeball question ("does she
## clip into the camera?") gets a number as well as a screenshot.
const MIN_CAMERA_CLEARANCE := 2.5

## Where each phase's pony is placed, relative to the player at the origin. 6.2 m out:
## comfortably inside MagicBeam.REACH and comfortably outside Pony.DETECTION_RADIUS, so
## she is not already reacting to the player when the beam reaches her.
const PONY_SPOT := Vector3(1.5, 0.0, -6.0)

## Where a finished pony is parked. Scene housekeeping, not a gameplay path: a released
## pony wanders (or flees), and one drifting through the next phase's line of fire would
## make this gate flaky for a reason that has nothing to do with the beam. She is moved,
## never freed -- the phase that cares has already asserted she is alive.
const PARK_SPOT := Vector3(0.0, 0.0, -40.0)

## Seconds of slack on top of a personality's own struggle time before a contest gives up
## waiting for her to break free. DERIVED PER PERSONALITY at the call site rather than
## typed as one number: the struggle times now span 2.3 s to 4.6 s, and a single typed
## timeout sized for the short one would report a hang for the long one on a build that was
## behaving perfectly. (It was 3.5 s, and STRUGGLE_SHY passing it is exactly the trap.)
const STRUGGLE_SLACK := 1.5

## Acceptance window around a personality's struggle time, in seconds. Wide enough for
## frame quantisation, narrow enough that handing a pony a NEIGHBOURING personality's
## number would fail it -- the closest pair is BOLD's 2.30 and CURIOUS's 3.00, 0.7 s apart.
const STRUGGLE_WINDOW := 0.4

## Acceptance window around MagicBeam.SECURE_SECONDS for the moment the beam reports the
## hold secured. Tighter than the struggle window because there is only one number to hit
## and every personality shares it.
const SECURE_WINDOW := 0.25

## ...and around the window a personality's two clocks are supposed to leave between them.
## Both endpoints are timed off the same clock in the same loop, so the error here is
## quantisation only.
const WINDOW_TOLERANCE := 0.2

## The sneak measurement: where the pony stands (metres in front of the player, comfortably
## past the widest notice radius there is), how big a step the player takes toward her, and
## how many physics frames he stands still after each one before her state is read.
##
## 0.25 m is the resolution of the answer, and it has to be finer than the tolerance the
## result is checked against (SNEAK_MEASURE_TOLERANCE) or the measurement could not fail.
## Two frames per step because a pony reacts on the first physics frame her detection area
## reports him -- the second is slack, not a tolerance.
const SNEAK_MEASURE_START := 20.0
const SNEAK_MEASURE_STEP := 0.25
const SNEAK_MEASURE_SETTLE := 2
## How far the measured notice distance may sit from Pony.notice_radius_for()'s answer.
## One step of the walk-in, plus the pony's own drift while she is being approached.
const SNEAK_MEASURE_TOLERANCE := 0.6

@onready var player: Node3D = $Player
@onready var crate: RigidBody3D = $Crate

var _rig: Node3D
var _beam: Node3D
var _storage: Storage
var _roster: Dictionary = {}
var _screenshot_dir := ""
var _checks: Dictionary = {}
## Labels recorded more than once. Any entry here fails the whole gate -- see _record().
var _duplicate_labels: Array[String] = []
var _shot_index := 0


func _ready() -> void:
	# 60 -> 90 s with the CONTEST phase. That phase spends real seconds on purpose: it lets
	# each personality run her struggle timer out (up to MagicBeam.STRUGGLE_SHY, 4.6 s) and
	# then waits out an ESCAPE_COOLDOWN before the second attempt, six times over. Measured
	# runtime is ~35 s headless, so this is still a hang guard with well over the run's own
	# length in slack, not a budget the gate is up against.
	GateWatchdogScript.arm(self, "CAPTURE", 90.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-dir="):
			_screenshot_dir = arg.split("=")[1]

	_roster = PonyRegistryScript.new().load_all("res://data/ponies")

	_rig = player.get_camera_pivot().get_node("CameraRig")
	_beam = player.get_magic_beam()
	_storage = _beam.get_storage()

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	_record("the beam is mounted on the player", _beam != null)
	_record("the beam owns a storage", _storage != null and _storage.capacity > 0)
	_record("the beam starts switched off and empty", not _beam.is_active()
		and not _beam.is_holding() and _storage.count() == 0)
	# Not a triviality: MagicBeam resolves this through Player.get_beam_origin(), which is
	# an @onready var the Player has not assigned yet while its children are readying. The
	# first version asked for it too early, got null, and quietly drew the beam out of the
	# player's HOOVES -- green everywhere, wrong in every frame.
	print("CAPTURE anchor=%s at=(%.2f, %.2f, %.2f)" % [
		_beam.get_beam_anchor().name, _beam.get_beam_anchor().global_position.x,
		_beam.get_beam_anchor().global_position.y, _beam.get_beam_anchor().global_position.z])
	_record("the beam is drawn from the player's horn, not from her origin",
		_beam.get_beam_anchor() == player.get_beam_origin()
		and _beam.get_beam_anchor().global_position.y > 1.5)
	# The personality rule, asserted here as well as in game/test/test_magic_beam.gd, so a
	# reader of this gate's output can see the numbers the CONTEST phase is checked against.
	# INVERTED BY THE SECOND PLAYTEST: the BOLD pony is the one who fights now, and the SHY
	# one freezes. See the STRUGGLE_* block in magic_beam.gd.
	_record("a bold pony struggles sooner than a shy one",
		MagicBeamScript.struggle_seconds_for(PonyDataScript.Personality.BOLD)
		< MagicBeamScript.struggle_seconds_for(PonyDataScript.Personality.SHY))

	await _phase_warning()
	await _phase_grab_and_capture()
	await _phase_distinct_and_release()
	await _phase_slip()
	await _phase_contest()
	await _phase_full_storage()
	await _phase_prop()
	await _phase_teardown()

	_finish()


# --- phases ---------------------------------------------------------------------------

## WARNING. The invariant the first playtest was lost to, gated three ways.
##
## The bug: Pony.DETECTION_RADIUS was 5 m while MagicBeam.REACH was 8.5, so a pony could
## not notice the player until long after he could already take her. Every grab in that
## build happened before its target had reacted to anything -- "I could just hold click
## and walk up and catch them" -- and the whole of the flee behaviour, which works, was
## unreachable in play. Nothing went red: both numbers were individually sensible, there
## was no assertion anywhere about the RELATIONSHIP between them, and the comment beside
## REACH actively argued for the wrong one.
##
## So: the arithmetic is asserted (that is what catches an inversion instantly, in every
## run, including headless CI), and then it is demonstrated -- a SHY pony stood beyond the
## beam's reach must bolt anyway, and a BOLD one stood at the same distance, with the
## crosshair on her and the beam switched on, must NOT be takeable. The arithmetic check
## alone would pass on a build where DetectionArea had stopped detecting; the behavioural
## checks alone would pass on a build where the radii had crept back together.
func _phase_warning() -> void:
	# The arithmetic, over EVERY personality rather than over one shared constant: since
	# the second playtest a SHY pony notices from further out than the others
	# (Pony.SHY_NOTICE_BONUS), so "the base radius clears the beam" would stop being the
	# same claim as "every pony clears the beam" the moment a future personality took a
	# bonus the other way.
	var worst := INF
	for personality in PonyDataScript.Personality.values():
		var radius: float = PonyScript.notice_radius_for(personality, false)
		var margin: float = radius - MagicBeamScript.REACH
		worst = minf(worst, margin)
		print("CAPTURE warning personality=%s notice_running=%.2f notice_sneaking=%.2f reach=%.2f margin=%.2f required=%.2f" % [
			PonyDataScript.Personality.keys()[personality], radius,
			PonyScript.notice_radius_for(personality, true), MagicBeamScript.REACH,
			margin, MagicBeamScript.MIN_DETECTION_MARGIN])
	print("CAPTURE warning worst_margin=%.2f required=%.2f spot=%.2f" % [
		worst, MagicBeamScript.MIN_DETECTION_MARGIN, OUT_OF_REACH_DISTANCE])
	_record("every pony notices a RUNNING player from further out than the beam reaches",
		worst >= MagicBeamScript.MIN_DETECTION_MARGIN)
	# ...and the sneak is allowed to break exactly that, which is the whole of what it buys.
	# Asserted rather than merely permitted: a sneak that left the notice radius outside the
	# beam's reach would be a stealth option with nothing at the end of it.
	var sneak_worst := -INF
	for personality in PonyDataScript.Personality.values():
		sneak_worst = maxf(sneak_worst, PonyScript.notice_radius_for(personality, true))
	_record("...and sneaking brings every one of them inside it", sneak_worst < MagicBeamScript.REACH)

	# She reacts, so her DetectionArea is left ON -- this is the one phase that is about it.
	# The SAME pony answers both halves: creeping at OUT_OF_REACH_DISTANCE must not spook
	# her, and running at the identical spot must. Two points on one pony, so neither
	# verdict can be an artefact of where she happened to be standing.
	Input.action_press(PlayerScript.SNEAK_ACTION)
	var shy := _spawn_pony(&"fluttershy", OUT_OF_REACH_SPOT, true)
	await _frames(REACT_FRAMES)
	var sneak_gap: float = shy.global_position.distance_to(player.global_position)
	var sneak_state: int = shy.state
	print("CAPTURE warning sneaking=%s shy_state=%s distance=%.2f notice_sneaking=%.2f" % [
		player.is_sneaking(), PonyScript.state_name(sneak_state), sneak_gap,
		PonyScript.notice_radius_for(PonyDataScript.Personality.SHY, true)])
	_record("the player really is sneaking for that half of the check", player.is_sneaking())
	_record("a creeping player can stand past the beam's reach without spooking her",
		sneak_state != PonyScript.State.FLEE)

	Input.action_release(PlayerScript.SNEAK_ACTION)
	var bolted := false
	for i in range(REACT_FRAMES):
		await get_tree().physics_frame
		if shy.state == PonyScript.State.FLEE:
			bolted = true
			break
	print("CAPTURE warning shy_state=%s distance=%.2f bolted=%s" % [
		PonyScript.state_name(shy.state),
		shy.global_position.distance_to(player.global_position), bolted])
	_record("a shy pony beyond the beam's reach bolts at a RUNNING player anyway", bolted)
	_park(shy)
	await _frames(4)

	await _measure_the_sneak()

	# PARKING HER IS NOT INSTANT AS FAR AS THE PHYSICS SERVER IS CONCERNED, and the next
	# pony goes on the exact same spot. Without these frames she is still occupying it when
	# the BOLD pony is added, the depenetration pass shoves the new arrival three quarters
	# of a metre TOWARD the player, and she lands inside the beam's reach after all -- which
	# is precisely how this check first went red on a build that was behaving correctly.
	# Cost: four frames. Value: the difference between measuring the beam's reach and
	# measuring a collision resolution.
	await _frames(4)

	# ...and the same distance really is out of reach. A BOLD pony, so nothing moves while
	# the rig aims at her and "the beam did not take her" cannot be an artefact of a target
	# that walked out of the crosshair.
	var bold := _spawn_pony(&"rainbowdash", OUT_OF_REACH_SPOT)
	await _frames(4)
	await _aim_at_pony(bold, "out-of-reach")
	_beam.grab()
	var acquired := await _wait_until_holding()
	var held: Node3D = _beam.get_held_body()
	print("CAPTURE warning out_of_reach_grab acquired=%s held=%s bold_at=(%.2f,%.2f,%.2f) distance=%.2f" % [
		acquired, held.name if held != null else "-",
		bold.global_position.x, bold.global_position.y, bold.global_position.z,
		bold.global_position.distance_to(player.global_position)])
	_record("the beam cannot take a pony standing past its reach", not acquired)
	_beam.release()
	_park(bold)
	# Unconditional, and not dead code on a passing run: if the check above has just gone
	# RED the beam did acquire her, and releasing an unsecured pony arms ESCAPE_COOLDOWN.
	# Without this wait the next phase's grab would then fail too, and one bug would print
	# as three unrelated ones.
	await _frames(int(MagicBeamScript.ESCAPE_COOLDOWN * 60.0) + 6)


## THE SNEAK, AS A MEASURED DISTANCE. Everything above is a pair of yes/no answers at one
## chosen spot; this walks the real player in from SNEAK_MEASURE_START in
## SNEAK_MEASURE_STEP increments and records the gap at which a SHY pony actually enters
## FLEE, once creeping and once running. Two numbers off the same behaviour, on the same
## ground, with nothing between them but what is_sneaking() answers.
##
## WHY MEASURE RATHER THAN ASSERT THE CONSTANT. Pony.notice_radius_for() is a pure function
## and its arithmetic is already pinned by unit tests; what no unit test can see is whether
## the running game ever ASKS it about the player's gait. A build that computed the sneaking
## radius perfectly and then never consulted it would pass every arithmetic check in the
## project and print two identical distances here.
func _measure_the_sneak() -> void:
	var home: Vector3 = player.global_position
	var measured := {}
	for sneaking in [true, false]:
		measured[sneaking] = await _notice_distance_for(sneaking)
	player.global_position = home
	Input.action_release(PlayerScript.SNEAK_ACTION)
	await _frames(SETTLE_FRAMES)

	var creeping: float = measured[true]
	var running: float = measured[false]
	var want_creeping: float = PonyScript.notice_radius_for(PonyDataScript.Personality.SHY, true)
	var want_running: float = PonyScript.notice_radius_for(PonyDataScript.Personality.SHY, false)
	print("CAPTURE sneak measured_running=%.2f expected=%.2f measured_creeping=%.2f expected=%.2f reduction=%.2f reach=%.2f" % [
		running, want_running, creeping, want_creeping, running - creeping,
		MagicBeamScript.REACH])

	_record("a running player is noticed at the distance the rule says he is",
		absf(running - want_running) <= SNEAK_MEASURE_TOLERANCE)
	_record("a creeping player is noticed at the distance the rule says he is",
		absf(creeping - want_creeping) <= SNEAK_MEASURE_TOLERANCE)
	_record("creeping measurably shortens the range a pony notices you at",
		creeping < running - 1.0)
	# The payoff, measured rather than argued: creeping gets the player inside beam range
	# of a pony who has not reacted to him at all. This is the one check that says the
	# stealth option is worth using.
	_record("...far enough that a creeping player is inside beam range before she reacts",
		creeping < MagicBeamScript.REACH)


## Walk the player toward a stationary SHY pony until she bolts, and return the gap at
## which she did (or 0.0 if she never did). The pony is spawned with her routine pinned so
## she stays put, and the gap is read from the two live positions rather than from how far
## the player has walked -- so any drift she does have is accounted for rather than assumed
## away.
func _notice_distance_for(sneaking: bool) -> float:
	var home: Vector3 = player.global_position
	if sneaking:
		Input.action_press(PlayerScript.SNEAK_ACTION)
	else:
		Input.action_release(PlayerScript.SNEAK_ACTION)

	var spot := Vector3(0.0, 0.0, -SNEAK_MEASURE_START)
	player.global_position = home
	var pony := _spawn_pony(&"fluttershy", spot, true)
	# reacts=true leaves her routine free, which would have her ambling about mid-measurement.
	# Pinning the roam radius keeps every wander target on her own feet, the same trick
	# _spawn_pony uses for its non-reacting ponies and for the same reason.
	pony.roam_radius = 0.0
	await _frames(SETTLE_FRAMES)

	var found := 0.0
	var steps := int(SNEAK_MEASURE_START / SNEAK_MEASURE_STEP)
	for i in range(steps):
		player.global_position = home + Vector3(0.0, 0.0, -SNEAK_MEASURE_STEP * float(i))
		await _frames(SNEAK_MEASURE_SETTLE)
		if pony.state == PonyScript.State.FLEE:
			found = pony.global_position.distance_to(player.global_position)
			break
	_park(pony)
	player.global_position = home
	await _frames(4)
	return found


## GRAB + CAPTURE. A BOLD pony (rainbowdash: 2.3 s struggle, no reaction to the player, so
## nothing in this phase is racing her state machine) is aimed at, grabbed, reeled in,
## held until the beam has SECURED her, then released into an empty bag.
func _phase_grab_and_capture() -> void:
	var pony := _spawn_pony(&"rainbowdash", PONY_SPOT)
	var spawn_position: Vector3 = pony.global_position
	print("CAPTURE spawn id=rainbowdash at=(%.2f, %.2f, %.2f) personality=%s struggle=%.2fs" % [
		spawn_position.x, spawn_position.y, spawn_position.z,
		PonyDataScript.Personality.keys()[pony.get_data().personality],
		MagicBeamScript.struggle_seconds_for(pony.get_data().personality)])

	await _aim_at_pony(pony, "grab")

	_beam.grab()
	var acquired := await _wait_until_holding()
	_record("the beam picks up the pony the crosshair is on", acquired)
	_record("a grabbed pony is in HELD", pony.state == PonyScript.State.HELD)

	var gap_at_grab: float = _chest(pony).distance_to(_beam.get_hold_point())
	await _frames(4)
	await _shot("01_beam_reaching")

	await _frames(PULL_FRAMES)
	var gap_now: float = _chest(pony).distance_to(_beam.get_hold_point())
	var camera_gap: float = pony.global_position.distance_to(_camera().global_position)
	print("CAPTURE pull gap_at_grab=%.3f gap_now=%.3f moved=%.3f camera_clearance=%.3f hold_point=(%.2f, %.2f, %.2f)" % [
		gap_at_grab, gap_now, pony.global_position.distance_to(spawn_position), camera_gap,
		_beam.get_hold_point().x, _beam.get_hold_point().y, _beam.get_hold_point().z])

	_record("the held pony is reeled toward the hold point", gap_now < gap_at_grab * ARRIVE_RATIO)
	_record("...and arrives at it", gap_now < ARRIVE_TOLERANCE)
	_record("...having actually travelled from where she was standing",
		pony.global_position.distance_to(spawn_position) > 1.0)
	_record("...and does not clip into the camera", camera_gap > MIN_CAMERA_CLEARANCE)
	_record("she is still in HELD while the button is down",
		pony.state == PonyScript.State.HELD and _beam.is_holding())

	# THE CAPTURE CONTEST EXISTS. The reel has finished and she is floating at the hold
	# point -- and she is still not stowable, because SECURE_SECONDS has not elapsed. On
	# the pre-playtest build this was false: the pull-in WAS the capture, and letting go
	# here stored her. If SECURE_SECONDS were ever set below the pull-in, or the secure
	# gate removed from release(), this check goes red while every other one stays green.
	print("CAPTURE secure after_pull=%.2fs secure_needs=%.2fs secured=%s progress=%.2f" % [
		_beam.get_hold_seconds(), _beam.get_secure_seconds(), _beam.is_secured(),
		_beam.get_secure_progress()])
	_record("the reel finishing is not by itself a capture", not _beam.is_secured())

	await _shot("02_held_at_hold_point")

	var secured := await _wait_until_secured()
	_record("holding her long enough secures her", secured)
	await _shot("02b_secured")

	# The capture itself. WeakRef, so this variable cannot be what keeps her alive.
	var ghost: WeakRef = weakref(pony)
	var captured_instances: Array = []
	_beam.captured.connect(func(inst: PonyInstance) -> void: captured_instances.append(inst))

	_beam.release()
	_record("releasing over an empty bag stores her", _storage.count() == 1)
	_record("...and reports it", captured_instances.size() == 1
		and captured_instances[0] != null and captured_instances[0].data_id == &"rainbowdash")
	# Phase 1B Task 1: what goes in the bag is an INDIVIDUAL, not the shared character
	# record. The DISTINCT phase below is what proves two of them stay apart; this is the
	# narrower claim that one of them has an identity at all.
	_record("...as an individual with her own uid, not as the shared character record",
		captured_instances.size() == 1 and captured_instances[0] != null
		and PonyInstanceScript.serial_of(captured_instances[0].uid) > 0)
	_record("...and the beam is empty afterwards", not _beam.is_holding())

	await _frames(3)
	_record("the captured pony's node is gone from the world", ghost.get_ref() == null)
	print("CAPTURE stored count=%d/%d node_freed=%s" % [
		_storage.count(), _storage.capacity, ghost.get_ref() == null])

	await _shot("03_release_captured")


## DISTINCT + RELEASE. Phase 1B Task 1's whole reason for existing, driven end to end
## through the real beam rather than asserted about a container in isolation.
##
## Two catches of the SAME CHARACTER used to put two pointers to one shared PonyData in the
## bag -- a reviewer inspected it and saw `contents=[twilight, twilight]`. So: catch a
## second rainbowdash on top of the first and check the bag holds two INDIVIDUALS with
## different uids and independently movable state.
##
## Then let one back out. `Storage.release()` shipped with ZERO CALLERS -- the bag was a
## one-way trip -- and MagicBeam.release_stored() is the caller that retires that finding.
## The claim with teeth is not "a pony appeared" but "the pony who appeared is the SAME
## individual, with the state she went in with", so her happiness and nickname are set to
## values nothing else in this scene uses and read back off the live node. And then she is
## caught AGAIN, which must reuse her existing instance rather than mint a fresh one: a
## recapture that quietly reset her would be exactly the amnesia PonyInstance exists to
## prevent, and it is invisible to every other check here.
func _phase_distinct_and_release() -> void:
	var pony := _spawn_pony(&"rainbowdash", PONY_SPOT)
	await _aim_at_pony(pony, "second catch")
	_beam.grab()
	_record("a second pony of the same character can be caught too",
		await _wait_until_holding())
	await _frames(PULL_FRAMES)
	# The capture contest (see _phase_grab_and_capture) applies here too: PULL_FRAMES is
	# deliberately shorter than SECURE_SECONDS now, so releasing right after the pull-in
	# would be a SLIP, not a capture, and this phase would spend the rest of itself
	# asserting things about a pony who was never actually stored.
	_record("holding her long enough secures her too", await _wait_until_secured())
	_beam.release()

	var bag: Array = _storage.contents()
	var uid_a := String(bag[0].uid) if bag.size() > 1 else ""
	var uid_b := String(bag[1].uid) if bag.size() > 1 else ""
	print("CAPTURE distinct count=%d uids=[%s, %s] data_ids=[%s, %s]" % [
		_storage.count(), uid_a, uid_b,
		String(bag[0].data_id) if bag.size() > 1 else "-",
		String(bag[1].data_id) if bag.size() > 1 else "-"])

	_record("two catches of one character are two records, not one", _storage.count() == 2)
	_record("...of the same character", bag.size() == 2
		and bag[0].data_id == &"rainbowdash" and bag[1].data_id == &"rainbowdash")
	# Compared as String, never as StringName: Godot orders StringName by interned POINTER,
	# a footgun this project has already shipped once (game/world/spawner.gd's DETERMINISM
	# note). Equality is safe either way; doing it one way everywhere is what stops the next
	# reader reaching for sort() on a pile of uids.
	_record("...telling the two individuals apart by uid",
		bag.size() == 2 and not uid_a.is_empty() and uid_a != uid_b)

	# The state that had nowhere to live before this task.
	bag[0].happiness = 0.9
	bag[1].happiness = 0.1
	_record("...with state that moves independently",
		absf(_storage.contents()[0].happiness - 0.9) < 0.0001
		and absf(_storage.contents()[1].happiness - 0.1) < 0.0001)

	# --- and back out again ---------------------------------------------------------
	var stored: PonyInstance = _storage.peek()
	stored.happiness = 0.42
	stored.nickname = "Dashie"
	var stored_uid := String(stored.uid)

	var back: Node3D = _beam.release_stored()
	var alive: bool = back != null and is_instance_valid(back) and back.is_inside_tree()
	_record("a stored pony can be let back out into the world", alive)
	_record("...and is gone from the bag when she is", _storage.count() == 1)

	var out: PonyInstance = back.get_instance() if alive else null
	print("CAPTURE release uid=%s happiness=%s nickname=%s at=(%.2f, %.2f, %.2f)" % [
		String(out.uid) if out != null else "-",
		("%.3f" % out.happiness) if out != null else "-",
		out.nickname if out != null else "-",
		back.global_position.x if alive else 0.0,
		back.global_position.y if alive else 0.0,
		back.global_position.z if alive else 0.0])

	_record("...as the very same individual she went in as",
		out != null and String(out.uid) == stored_uid)
	_record("...carrying the state she went in with",
		out != null and absf(out.happiness - 0.42) < 0.0001 and out.nickname == "Dashie")
	# The mane/tail spring simulation is the whole reason PonyVisuals.build() is the only
	# sanctioned spawn path (docs/notes-hair-sim.md). A release that loaded the .glb some
	# other way would still produce a pony-shaped thing, and this is what tells them apart.
	_record("...rebuilt through the sanctioned visuals path, not a bare model load",
		alive and back.get_animation_player() != null)

	# She was set down slightly above the ground and has her own gravity back, so she comes
	# down and stands on it -- the same "not stranded mid-air" claim the teardown phase makes.
	await _frames(60)
	alive = back != null and is_instance_valid(back) and back.is_inside_tree()
	_record("...standing on the ground on her own hooves afterwards",
		alive and absf(back.global_position.y) < 0.05)

	await _shot("08_released_from_storage")

	# --- caught again: the same pony, not a fresh copy of her character ---------------
	if alive:
		back.global_position = PONY_SPOT
		await _aim_at_pony(back, "recapture")
		_beam.grab()
		_record("a released pony can be caught again", await _wait_until_holding())
		await _frames(PULL_FRAMES)
		# Same capture-contest requirement as the first catch above -- see the comment there.
		_record("...and securing her again takes the same SECURE_SECONDS",
			await _wait_until_secured())
		_beam.release()
		var again: PonyInstance = _storage.peek()
		print("CAPTURE recapture uid=%s happiness=%s count=%d" % [
			String(again.uid) if again != null else "-",
			("%.3f" % again.happiness) if again != null else "-", _storage.count()])
		_record("...and re-catching her reuses her identity rather than minting a new one",
			again != null and String(again.uid) == stored_uid)
		_record("...so her state survives the round trip out and back",
			again != null and absf(again.happiness - 0.42) < 0.0001)


## SLIP. The failure mode the capture contest is made of: let go before the beam has
## subdued her and you do not get her.
##
## THIS IS THE PHASE THAT FAILS ON THE BUILD THE OWNER PLAYED. There, release() stored
## whatever was in the beam the instant it was called, so a hold of two frames was a
## capture and the mechanic was point-and-click. Here the same two-frame hold must produce
## no store, an escaped() report, Loss.SLIPPED rather than Loss.STRUGGLED, and a live pony
## back in the world -- four separate ways for a half-done implementation to give itself
## away. A BOLD pony, so her own state machine is not moving her about while it happens.
func _phase_slip() -> void:
	var pony := _spawn_pony(&"rainbowdash", PONY_SPOT)
	var count_before: int = _storage.count()
	var escaped_bodies: Array = []
	var handler := func(body: Node3D) -> void: escaped_bodies.append(body)
	_beam.escaped.connect(handler)

	await _aim_at_pony(pony, "slip")
	_beam.grab()
	var acquired := await _wait_until_holding()
	_record("the beam picks her up before the slip", acquired)

	# Two frames of hold: far inside SECURE_SECONDS, and far inside the pull-in as well,
	# so she has not even arrived yet.
	await _frames(2)
	var held_for: float = _beam.get_hold_seconds()
	var ghost: WeakRef = weakref(pony)
	_beam.release()

	var alive: bool = ghost.get_ref() != null and is_instance_valid(pony) and pony.is_inside_tree()
	print("CAPTURE slip held_for=%.3fs secure_needs=%.2fs stored=%d/%d escaped=%d loss=%s alive=%s" % [
		held_for, MagicBeamScript.SECURE_SECONDS, _storage.count(), _storage.capacity,
		escaped_bodies.size(), _loss_name(_beam.get_last_loss()), alive])

	_record("letting go before she is secured does NOT store her",
		_storage.count() == count_before)
	_record("...and reports her as escaped()", escaped_bodies.size() == 1)
	_record("...for the right reason (slipped, not out-struggled)",
		_beam.get_last_loss() == MagicBeamScript.Loss.SLIPPED)
	_record("...and leaves her alive in the world", alive)
	_record("...and a slipped pony is out of HELD, steering herself again",
		alive and pony.state != PonyScript.State.HELD)

	_beam.escaped.disconnect(handler)
	await _shot("03b_slipped")
	if alive:
		_park(pony)

	# A slip cools the beam down exactly like a lost struggle does, so the next phase has
	# to wait it out -- see the note in the middle of _contest_one().
	await _frames(int(MagicBeamScript.ESCAPE_COOLDOWN * 60.0) + 6)


## CONTEST. What a capture actually costs, per personality, MEASURED.
##
## THIS IS THE PHASE THE SECOND PLAYTEST ASKED FOR. The owner's report was "Fluttershy
## always breaks out -- impossible to catch", against a build whose constants all looked
## reasonable and whose gate was green: nothing anywhere drove a capture against each
## personality and reported whether it could be won. So this does, twice for each of them:
##
##   1. Hold on and let her win. The loop times when the beam reported her SECURED and when
##      she broke free; the difference between those two IS the window the player gets, and
##      it is read off the running game rather than subtracted from two constants.
##   2. Take a fresh one and let go on the green ring. She must go in the bag.
##
## Together those are "you can lose this" and "you can win this", which are the two things
## a difficulty number is claiming and neither of which a constant can demonstrate.
##
## The measured windows are then checked AGAINST EACH OTHER for the ordering the second
## playtest inverted (BOLD is now the tight hold and SHY the comfortable one). Swapping two
## struggle times, or flipping the whole ordering back, fails that check even though every
## individual number would still look perfectly plausible on its own.
func _phase_contest() -> void:
	var windows := {}
	for id in [&"fluttershy", &"twilight", &"rainbowdash"]:
		var personality: int = await _contest_one(id)
		windows[personality] = id
	await _check_the_window_ordering(windows)


## One personality, both directions. Returns her personality value.
func _contest_one(id: StringName) -> int:
	var pony := _spawn_pony(id, PONY_SPOT)
	var personality: int = pony.get_data().personality
	var who: String = PonyDataScript.Personality.keys()[personality]
	var struggle: float = MagicBeamScript.struggle_seconds_for(personality)
	var promised: float = MagicBeamScript.capture_window_for(personality)
	var label := who.to_lower()

	# --- she wins -------------------------------------------------------------------
	var escaped_reported := [false]
	pony.escaped.connect(func() -> void: escaped_reported[0] = true)
	await _aim_at_pony(pony, "%s contest" % label)
	_beam.grab()
	var acquired := await _wait_until_holding()
	_record("%s: the beam picks her up" % who, acquired)

	var count_before: int = _storage.count()
	# TIMED IN PHYSICS FRAMES, NOT ON THE WALL CLOCK, and that is a bug fix rather than a
	# style choice. Both of the beam's clocks accumulate the PHYSICS delta
	# (MagicBeam._run_struggle), so a physics-frame count is the same clock they run on and
	# is exact. Time.get_ticks_msec() is not: this gate is also run OFFSCREEN under llvmpipe
	# (see the header), where rendering cannot hold 60 fps, physics falls behind real time,
	# and a 4.60 s struggle measures as 6.21 s of wall clock. Measured -- the first draft of
	# this phase used the wall clock, passed headless, and went red on every timing check the
	# moment it was rendered, which is a gate reporting the renderer's frame rate rather than
	# the mechanic. (The ESCAPE phase this replaced had the same flaw, on a wider window.)
	var frames := 0
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	var secured_at := -1.0
	var freed_at := -1.0
	for i in range(int((struggle + STRUGGLE_SLACK) / tick)):
		await get_tree().physics_frame
		frames += 1
		var now := float(frames) * tick
		if secured_at < 0.0 and _beam.is_secured():
			secured_at = now
		if not _beam.is_holding():
			freed_at = now
			break
	var measured := -1.0
	if secured_at >= 0.0 and freed_at >= 0.0:
		measured = freed_at - secured_at
	var alive: bool = is_instance_valid(pony) and pony.is_inside_tree()
	print("CAPTURE contest %s outcome=%s secured_at=%.2fs (needs %.2f) broke_free_at=%.2fs (struggle %.2f) window=%.2fs (promised %.2f)" % [
		who, "BROKE_FREE" if freed_at >= 0.0 else "STILL_HELD", secured_at,
		MagicBeamScript.SECURE_SECONDS, freed_at, struggle, measured, promised])

	_record("%s: the beam secures her" % who, secured_at >= 0.0)
	_record("%s: ...on the same secure clock as everyone else" % who,
		secured_at >= 0.0
		and absf(secured_at - MagicBeamScript.SECURE_SECONDS) <= SECURE_WINDOW)
	_record("%s: ...and she wins if you keep holding" % who, freed_at >= 0.0)
	_record("%s: ...on her own personality's clock, not another's" % who,
		freed_at >= 0.0 and absf(freed_at - struggle) <= STRUGGLE_WINDOW)
	_record("%s: ...leaving the window her personality promises" % who,
		measured >= 0.0 and absf(measured - promised) <= WINDOW_TOLERANCE)
	_record("%s: ...reported as escaped()" % who, escaped_reported[0])
	_record("%s: ...alive and steering herself again (no pony ever dies)" % who,
		alive and pony.state != PonyScript.State.HELD)
	_record("%s: ...and not in the bag" % who, _storage.count() == count_before)
	# The beam refuses to re-acquire for ESCAPE_COOLDOWN, so an escape means something.
	_record("%s: ...and the beam does not instantly re-grab her" % who, not _beam.is_holding())

	_beam.release()
	_park(pony)
	# ...and that refusal is deliberately NOT cleared by letting go of the button, or
	# tapping it again would undo every escape. So the win half has to wait it out.
	await _frames(int(MagicBeamScript.ESCAPE_COOLDOWN * 60.0) + 6)

	# --- the player wins ------------------------------------------------------------
	var fresh := _spawn_pony(id, PONY_SPOT)
	var before: int = _storage.count()
	var ghost: WeakRef = weakref(fresh)
	await _aim_at_pony(fresh, "%s capture" % label)
	_beam.grab()
	acquired = await _wait_until_holding()
	_record("%s: a second one can be picked up too" % who, acquired)
	var secured := await _wait_until_secured()
	var held_for: float = _beam.get_hold_seconds()
	_beam.release()
	await _frames(3)
	print("CAPTURE contest %s outcome=%s held=%.2fs window=%.2fs stored=%d/%d freed=%s" % [
		who, "SECURED" if _storage.count() > before else "LOST", held_for, promised,
		_storage.count(), _storage.capacity, ghost.get_ref() == null])

	_record("%s: holding to the green ring secures her" % who, secured)
	_record("%s: ...well inside the window her struggle allows" % who,
		held_for < struggle - 0.05)
	_record("%s: ...and letting go there stores her" % who, _storage.count() == before + 1)
	_record("%s: ...and her node leaves the world" % who, ghost.get_ref() == null)

	await _frames(4)
	return personality


## The measured windows, ordered against each other. See the phase comment: this is the
## check an accidental re-inversion of the second playtest's design decision fails.
func _check_the_window_ordering(windows: Dictionary) -> void:
	var shy: float = MagicBeamScript.capture_window_for(PonyDataScript.Personality.SHY)
	var curious: float = MagicBeamScript.capture_window_for(PonyDataScript.Personality.CURIOUS)
	var bold: float = MagicBeamScript.capture_window_for(PonyDataScript.Personality.BOLD)
	print("CAPTURE contest ordering measured_personalities=%d bold=%.2fs curious=%.2fs shy=%.2fs" % [
		windows.size(), bold, curious, shy])
	_record("all three personalities were actually contested",
		windows.size() == PonyDataScript.Personality.size())
	_record("a BOLD pony is the tightest hold and a SHY one the most comfortable",
		bold < curious and curious < shy)
	_record("...and she is the harder one to REACH in exchange",
		PonyScript.notice_radius_for(PonyDataScript.Personality.SHY, false)
		> PonyScript.notice_radius_for(PonyDataScript.Personality.BOLD, false))
	# NO SCREENSHOT HERE, deliberately. This scene has no HUD, so the two rings the contest
	# is about are not drawn in it -- the first draft took one and it was a photograph of a
	# pony standing next to a crate, which is a shot that proves nothing and costs a reader
	# the trouble of working out that it proves nothing. The struggle ring and the secure arc
	# are photographed where they actually exist, in game/world/ranch.gd's mechanic pass.


## FULL. With the bag full, a released pony is set down rather than stored -- or lost.
func _phase_full_storage() -> void:
	# BOUNDED, not `while not is_full()`. The unbounded version hung this gate for two
	# minutes when the failure proof broke is_full() into always returning false -- a gate
	# that hangs on a bug is a gate that reports nothing about it. The bound is capacity
	# plus a little, so a storage that refuses to fill runs out of attempts and the check
	# below goes red instead.
	var filler := 0
	for i in range(_storage.capacity + 4):
		if _storage.is_full():
			break
		if not _storage.store(PonyInstanceScript.create(StringName("filler%d" % filler))):
			break
		filler += 1
	_record("the bag can actually be filled", _storage.is_full())
	var count_before: int = _storage.count()

	var pony := _spawn_pony(&"twilight", PONY_SPOT)
	var refused := [false]
	_beam.capture_refused.connect(func(_body: Node3D) -> void: refused[0] = true)

	await _aim_at_pony(pony, "full")
	_beam.grab()
	var acquired := await _wait_until_holding()
	_record("a full bag does not stop the beam picking her up", acquired)
	await _frames(PULL_FRAMES)
	# Held long enough to be SECURED before the release, or this phase would be measuring
	# a slip rather than a refusal and its "the bag refused the store" check would pass for
	# entirely the wrong reason.
	var secured := await _wait_until_secured()
	_record("a full bag does not stop the beam securing her either", secured)
	await _shot("05_full_storage_held")

	var ghost: WeakRef = weakref(pony)
	_beam.release()
	_record("a full bag refuses the store", _storage.count() == count_before)
	_record("...and reports it as capture_refused()", refused[0])
	await _frames(3)
	# `alive` is computed once and every later clause is guarded by it. On a build that
	# WRONGLY freed her -- the exact bug this phase exists to catch -- the unguarded
	# version crashed on the next line instead of reporting, so a broken build produced a
	# short, confusing check list rather than a clear red one.
	var alive: bool = ghost.get_ref() != null and is_instance_valid(pony) and pony.is_inside_tree()
	_record("...and the pony is still in the world", alive)
	_record("...and out of HELD, steering herself again",
		alive and pony.state != PonyScript.State.HELD)

	# She was floating when she was let go; gravity is hers again, so she comes down.
	await _frames(45)
	alive = ghost.get_ref() != null and is_instance_valid(pony) and pony.is_inside_tree()
	print("CAPTURE full_bag count=%d/%d refused=%s pony_alive=%s landed_y=%s" % [
		_storage.count(), _storage.capacity, refused[0], alive,
		("%.3f" % pony.global_position.y) if alive else "<freed>"])
	_record("...and lands on the ground unharmed",
		alive and absf(pony.global_position.y) < 0.05)

	await _shot("06_full_storage_dropped")
	if alive:
		_park(pony)


## PROP. The part of the mechanic people play with for its own sake.
func _phase_prop() -> void:
	var start: Vector3 = crate.global_position
	await _aim_at(crate.global_position, "prop")
	_beam.grab()
	var acquired := await _wait_until_holding()
	_record("a loose rigid body can be dragged too", acquired)
	_record("...and it is the crate that got picked up", _beam.get_held_body() == crate)

	await _frames(PULL_FRAMES)
	var gap: float = crate.global_position.distance_to(_beam.get_hold_point())
	print("CAPTURE prop moved=%.3f gap=%.3f frozen=%s" % [
		crate.global_position.distance_to(start), gap, crate.freeze])
	_record("the crate is reeled to the hold point too", gap < ARRIVE_TOLERANCE)

	await _shot("07_prop_held")

	_beam.release()
	await _frames(30)
	_record("a released prop gets its physics back", not crate.freeze)
	_record("...and is still in the world", is_instance_valid(crate) and crate.is_inside_tree())


## TEARDOWN. The one exit from a hold that no other phase reaches: the beam going away
## while it still has hold of somebody. A pony in HELD runs no gravity and no steering, so
## a beam freed mid-hold leaves her suspended in the air with nothing left to release her.
## Runs last, because it removes the beam from the tree.
func _phase_teardown() -> void:
	var pony := _spawn_pony(&"rainbowdash", PONY_SPOT)
	await _aim_at_pony(pony, "teardown")
	_beam.grab()
	var acquired := await _wait_until_holding()
	_record("the beam has hold of her before the tree comes apart", acquired)
	await _frames(PULL_FRAMES)
	var held_at: Vector3 = pony.global_position

	# The beam vanishes out from under the hold -- a scene change, a despawned player.
	var parent := _beam.get_parent()
	parent.remove_child(_beam)
	await _frames(3)

	var alive: bool = is_instance_valid(pony) and pony.is_inside_tree()
	_record("a beam removed mid-hold lets go of her", alive and pony.state != PonyScript.State.HELD)
	_record("...leaving her alive in the world", alive)

	# The check with the teeth: HELD is precisely the state in which she does not fall, so
	# "she came down" is the difference between released and stranded.
	await _frames(60)
	alive = is_instance_valid(pony) and pony.is_inside_tree()
	print("CAPTURE teardown held_at_y=%.3f state=%s alive=%s now_y=%s" % [
		held_at.y, PonyScript.state_name(pony.state) if alive else "-", alive,
		("%.3f" % pony.global_position.y) if alive else "<freed>"])
	_record("...and falling under her own gravity again, not stranded mid-air",
		alive and held_at.y > 0.5 and absf(pony.global_position.y) < 0.05)

	# Put it back so the scene is not left with an orphaned node at quit. Re-entering the
	# tree does not re-run _ready(), so the storage and its contents survive.
	parent.add_child(_beam)


# --- aiming ---------------------------------------------------------------------------

## Drive the camera rig until get_aim_ray() points at `target`, then assert that it does.
##
## Iterative rather than analytic because the camera hangs off a SPRING ARM: changing the
## pitch moves the eye point the ray starts from, so the correction has to be re-derived
## from the new eye point. It converges in three or four steps; AIM_ITERATIONS is twelve.
##
## THE ASSERTION IS THE POINT. Nothing here hands the beam a target -- the beam runs its
## own cast along the same get_aim_ray() the loop below is steering, so if the rig's ray
## ever stopped agreeing with where the camera actually looks, this check goes red before
## a single capture is attempted.
func _aim_at(target: Vector3, label: String) -> void:
	for i in range(AIM_ITERATIONS):
		var ray = _rig.get_aim_ray()
		var want: Vector3 = (target - ray.origin).normalized()
		var have: Vector3 = ray.direction
		# add_look_delta's signs: positive yaw turns the view RIGHT (rotation.y -= yaw),
		# positive pitch looks DOWN (_look_pitch -= pitch). Both corrections are therefore
		# the negation of the error measured in the "view" sense.
		var yaw_error := wrapf(atan2(-want.x, -want.z) - atan2(-have.x, -have.z), -PI, PI)
		var pitch_error := asin(clampf(want.y, -1.0, 1.0)) - asin(clampf(have.y, -1.0, 1.0))
		_rig.add_look_delta(-yaw_error, -pitch_error)
		await get_tree().physics_frame

	var ray = _rig.get_aim_ray()
	var want: Vector3 = (target - ray.origin).normalized()
	var error_deg := rad_to_deg(acos(clampf(want.dot(ray.direction), -1.0, 1.0)))
	print("CAPTURE aim(%s) error=%.4f deg origin=(%.2f, %.2f, %.2f) dir=(%.3f, %.3f, %.3f)" % [
		label, error_deg, ray.origin.x, ray.origin.y, ray.origin.z,
		ray.direction.x, ray.direction.y, ray.direction.z])
	_record("the crosshair really is on the %s target" % label, error_deg <= AIM_TOLERANCE_DEG)


func _aim_at_pony(pony: CharacterBody3D, label: String) -> void:
	await _aim_at(_chest(pony), label)


## The centre of a pony's collision capsule -- what the crosshair should rest on, and what
## the hold point lines up with (MagicBeam.PONY_HOLD_LIFT).
func _chest(pony: Node3D) -> Vector3:
	return pony.global_position + Vector3(0.0, MagicBeamScript.PONY_HOLD_LIFT, 0.0)


# --- helpers --------------------------------------------------------------------------

## One pony at `at`. `reacts` decides whether she can see the player at all.
##
## DETECTION IS OFF BY DEFAULT HERE, AND THAT IS A DELIBERATE STATEMENT, not a shortcut.
## Pony.DETECTION_RADIUS now exceeds MagicBeam.REACH by construction (see _phase_warning),
## so every distance at which the beam can touch a pony is a distance at which she has
## already noticed the player -- there is no "stationary target" range left anywhere on
## the map, and there should not be. The phases that measure the BEAM would otherwise be
## silently measuring a chase as well: a SHY pony would bolt out of the crosshair between
## the aim loop and the grab, and a CURIOUS one would walk toward the player mid-aim, both
## making this gate flaky for reasons that have nothing to do with what it checks.
## Switching her senses off says so out loud, in one place, instead.
func _spawn_pony(id: StringName, at: Vector3, reacts := false) -> CharacterBody3D:
	var ponies: Dictionary = _roster
	if not ponies.has(id):
		push_error("capture_test: no PonyData with id '%s'" % id)
		return null
	var pony: CharacterBody3D = PonyScene.instantiate()
	pony.name = "Pony_%s" % id
	# Placed BEFORE add_child: _ready() records wherever she stands as her roam anchor.
	pony.position = at
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260827
	pony.set_rng(rng)
	if not reacts:
		# Before add_child, so the physics server's first broadphase pass never sees an
		# overlap to report in the first place.
		var detection := pony.get_node("DetectionArea") as Area3D
		detection.monitoring = false
		# ...and her ROUTINE is pinned too, for the same reason and by the same argument:
		# a roam radius of zero makes every wander target her own feet, so she stands where
		# she was put. She would otherwise amble up to 1.32 m/s in a direction of her own
		# choosing between the aim loop and the grab, which is a live race in every phase
		# (the aim is asserted to a tenth of a degree and then acted on a frame later) and
		# an outright wrong answer in the WARNING phase, where "the beam could not reach
		# her" is only meaningful if she is still standing where she was measured.
		pony.roam_radius = 0.0
	add_child(pony)
	pony.setup(ponies[id])
	return pony


## Park a finished pony well out of the next phase's way. Scene housekeeping only -- see
## PARK_SPOT.
func _park(pony: Node3D) -> void:
	if pony != null and is_instance_valid(pony):
		pony.global_position = PARK_SPOT


## Wait for the beam to acquire something (acquisition runs in the physics step after
## grab(), by design -- see MagicBeam.grab()). Returns false if it never does.
func _wait_until_holding() -> bool:
	for i in range(45):
		await get_tree().physics_frame
		if _beam.is_holding():
			return true
	return false


## Wait for the beam to report the current hold SECURED -- i.e. for letting go to have
## become a capture rather than a slip. Returns false if it never does, which is a real
## outcome (she out-struggled the secure time), not just a timeout.
func _wait_until_secured() -> bool:
	for i in range(SECURE_WAIT_FRAMES):
		if _beam.is_secured():
			return true
		await get_tree().physics_frame
	return _beam.is_secured()


func _loss_name(value: int) -> String:
	return MagicBeamScript.Loss.keys()[value] if value >= 0 \
		and value < MagicBeamScript.Loss.size() else "INVALID(%d)" % value


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _camera() -> Camera3D:
	return _rig.get_camera()


## Record one check's verdict under `label`.
##
## THE DUPLICATE GUARD IS NOT DEFENSIVE PROGRAMMING, IT IS A BUG FIX. `_checks` is keyed by
## label, so two checks sharing one meant the second silently OVERWROTE the first's verdict
## and the total count came out one short. It happened: the ESCAPE phase's "did escaped()
## fire?" and the FULL phase's "did capture_refused() fire?" were both labelled
## "...and says so", so deleting `escaped.emit()` from pony.gd outright left this gate
## printing CAPTURE_OK -- a green gate not measuring the thing it claimed to. Distinct
## labels fix that instance; this guard is what stops the next one, because the next
## "...and " continuation line is one copy-paste away and nothing else in the file would
## notice.
##
## A collision is recorded as a FAILURE in its own right (and the loser is kept under a
## suffixed key rather than dropped, so a run with a duplicate still reports both verdicts
## instead of hiding one).
func _record(label: String, passed: bool) -> void:
	if _checks.has(label):
		push_error("capture_test: DUPLICATE check label -- '%s'" % label)
		_duplicate_labels.append(label)
		var suffix := 2
		while _checks.has("%s [dup %d]" % [label, suffix]):
			suffix += 1
		_checks["%s [dup %d]" % [label, suffix]] = passed
		return
	_checks[label] = passed


## Save a PNG through the PLAYER'S OWN CAMERA -- the whole point is to see what the player
## would see. No-op headless, where there is nothing to render.
func _shot(shot_name: String) -> void:
	if _screenshot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path: String = _screenshot_dir.path_join("%s.png" % shot_name)
	image.save_png(path)
	_shot_index += 1
	var held: Node3D = _beam.get_held_body()
	print("SCREENSHOT_SAVED %s beam_active=%s holding=%s held=%s hold_point=(%.2f, %.2f, %.2f) storage=%d/%d" % [
		path, _beam.is_active(), _beam.is_holding(),
		held.name if held != null else "-",
		_beam.get_hold_point().x, _beam.get_hold_point().y, _beam.get_hold_point().z,
		_storage.count(), _storage.capacity])


func _finish() -> void:
	var all_ok := true
	for label in _checks:
		if not _checks[label]:
			push_error("capture_test: FAILED check -- %s" % label)
			all_ok = false

	# A duplicate label fails the gate outright, even if every verdict happened to be
	# true: a gate that cannot say how many checks it ran, or which result belongs to
	# which claim, is not reporting. See _record().
	if not _duplicate_labels.is_empty():
		push_error("capture_test: check labels must be unique -- duplicated: %s"
			% ", ".join(_duplicate_labels))
		all_ok = false

	print("CAPTURE checks=%d shots=%d duplicates=%d storage=%d/%d" % [
		_checks.size(), _shot_index, _duplicate_labels.size(), _storage.count(),
		_storage.capacity])
	print(("CAPTURE_OK " if all_ok else "CAPTURE_FAILED ") + "checks=%d" % _checks.size())
	get_tree().quit(0 if all_ok else 1)
